// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { EndorsementModule } from "./modules/EndorsementModule.sol";
import { FlagModule } from "./modules/FlagModule.sol";
import { DataTypes } from "./libraries/DataTypes.sol";
import { Errors } from "./libraries/Errors.sol";
import { Events } from "./libraries/Events.sol";

/**
 * @title IdentitySystem
 * @notice Decentralised identity with soulbound roots, transferable
 *         tokens, time-based endorsements, revocation and flagging.
 *         Inheritance chain:
 *           ERC721 → EndorsementModule → FlagModule
 *         All abstract hooks from every module are resolved here.
 */
contract IdentitySystem is ERC721, EndorsementModule, FlagModule {
    uint256 private _nextTokenId = 1;

    // Admin & linked contracts
    address public admin;
    address public profileSystem;

    // Profile ownership tracking (one profile per wallet, persistent mint guard lives in ProfileSystem)
    mapping(address => bool) public hasProfile;

    // Root identity storage
    mapping(uint256 => DataTypes.RootIdentity) public rootIdentities;
    mapping(address => uint256) public ownerToRootId;

    // Token storage
    mapping(uint256 => DataTypes.Token) public tokens;
    mapping(uint256 => uint256[]) public rootToTokenIds;

    // Token type tracking  (TokenType.ROOT | TokenType.SUB | TokenType.PROFILE)
    mapping(uint256 => DataTypes.TokenType) public tokenTypes;

    // Transfer history per token
    mapping(uint256 => address[]) public transferHistory;

    // Wallet-level token index
    mapping(address => uint256[]) public walletTokens;

    // Transfer control flags — prevent raw ERC721 transfers
    bool private _internalTransferActive;

    constructor() ERC721("Decentralized-Identity-Tokens", "DIT") {
        admin = msg.sender;
    }

    // Admin

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Errors.NotAdmin();
        _;
    }

    function setProfileSystem(address _profileSystem) external onlyAdmin {
        if (_profileSystem == address(0)) revert Errors.ZeroAddress();
        if (profileSystem != address(0)) revert Errors.ProfileSystemAlreadySet();
        profileSystem = _profileSystem;
        emit Events.ProfileSystemSet(_profileSystem);
    }

    // Root Identity

    function createRootIdentity(string calldata displayName) external returns (uint256) {
        if (ownerToRootId[msg.sender] != 0) revert Errors.AlreadyHasRoot();

        uint256 rootId = _nextTokenId++;
        _mint(msg.sender, rootId);

        ownerToRootId[msg.sender] = rootId;
        tokenTypes[rootId] = DataTypes.TokenType.ROOT;

        rootIdentities[rootId] = DataTypes.RootIdentity({
            walletAddress: msg.sender,
            displayName: displayName,
            tokenId: rootId,
            createdAt: block.timestamp,
            isActive: true
        });

        emit Events.RootIdentityCreated(rootId, msg.sender, displayName);
        return rootId;
    }

    // Profile Token Minting (called by ProfileSystem)

    function mintProfileToken(address to) external returns (uint256) {
        if (msg.sender != profileSystem) revert Errors.OnlyProfileSystem();
        if (hasProfile[to]) revert Errors.RecipientAlreadyHasProfile();

        uint256 rootId = ownerToRootId[to];
        if (rootId == 0) revert Errors.NoRootIdentity();
        if (!rootIdentities[rootId].isActive) revert Errors.RootDeactivated();

        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);

        tokenTypes[tokenId] = DataTypes.TokenType.PROFILE;

        // Initialize a Token struct so endorsement/flagging hooks work seamlessly
        tokens[tokenId] = DataTypes.Token({
            tokenId: tokenId,
            parentRootId: rootId,
            tokenName: "Profile",
            tokenType: "PROFILE",
            tokenValue: "",
            about: "",
            validUntil: 0,
            createdAt: block.timestamp,
            totalEndorsementCount: 0,
            revokedCount: 0,
            isFlagged: false,
            flagCount: 0,
            transferCount: 0
        });

        rootToTokenIds[rootId].push(tokenId);
        walletTokens[to].push(tokenId);
        transferHistory[tokenId].push(to);

        hasProfile[to] = true;

        emit Events.TokenCreated(tokenId, rootId, "Profile", "PROFILE");
        return tokenId;
    }

    // Token

    function createToken(
        string calldata tokenName,
        string calldata tokenType,
        bytes calldata tokenValue,
        string calldata about,
        uint256 validUntil
    ) external returns (uint256) {
        uint256 rootId = ownerToRootId[msg.sender];
        if (rootId == 0) revert Errors.NoRootIdentity();
        if (!rootIdentities[rootId].isActive) revert Errors.RootDeactivated();
        if (validUntil != 0 && validUntil <= block.timestamp) revert Errors.InvalidExpiry();

        uint256 tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        tokenTypes[tokenId] = DataTypes.TokenType.SUB;

        tokens[tokenId] = DataTypes.Token({
            tokenId: tokenId,
            parentRootId: rootId,
            tokenName: tokenName,
            tokenType: tokenType,
            tokenValue: tokenValue,
            about: about,
            validUntil: validUntil,
            createdAt: block.timestamp,
            totalEndorsementCount: 0,
            revokedCount: 0,
            isFlagged: false,
            flagCount: 0,
            transferCount: 0
        });

        rootToTokenIds[rootId].push(tokenId);
        walletTokens[msg.sender].push(tokenId);
        transferHistory[tokenId].push(msg.sender);

        emit Events.TokenCreated(tokenId, rootId, tokenName, tokenType);
        return tokenId;
    }

    function transferToken(uint256 tokenId, address sendingTo) external {
        if (ownerOf(tokenId) != msg.sender) revert Errors.NotHolder();
        if (tokenTypes[tokenId] == DataTypes.TokenType.ROOT) revert Errors.CannotTransferRoot();
        if (sendingTo == msg.sender) revert Errors.SelfTransfer();
        if (sendingTo == address(0)) revert Errors.ZeroAddress();

        // enforce one-profile-per-wallet on the receiving end
        if (tokenTypes[tokenId] == DataTypes.TokenType.PROFILE) {
            if (hasProfile[sendingTo]) revert Errors.RecipientAlreadyHasProfile();
            hasProfile[sendingTo] = true;
            hasProfile[msg.sender] = false;
        } else {
            // SUB tokens: check expiry
            if (tokens[tokenId].validUntil != 0 && tokens[tokenId].validUntil < block.timestamp) {
                revert Errors.TokenExpired();
            }
        }

        // Record transfer
        transferHistory[tokenId].push(sendingTo);
        tokens[tokenId].transferCount++;

        // Update wallet indices
        _removeFromWalletList(msg.sender, tokenId);
        walletTokens[sendingTo].push(tokenId);

        // Execute controlled transfer
        _internalTransferActive = true;
        _transfer(msg.sender, sendingTo, tokenId);
        _internalTransferActive = false;

        emit Events.TokenTransferred(tokenId, msg.sender, sendingTo);
    }

    function burnToken(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert Errors.NotHolder();
        if (tokenTypes[tokenId] == DataTypes.TokenType.ROOT) revert Errors.NotToken();

        // If burning a profile token, clear the wallet's profile flag
        if (tokenTypes[tokenId] == DataTypes.TokenType.PROFILE) {
            hasProfile[msg.sender] = false;
        }

        uint256 rootId = tokens[tokenId].parentRootId;

        // Remove from wallet tracking
        _removeFromWalletList(msg.sender, tokenId);

        // Remove from root's token list
        _removeFromRootTokenList(rootId, tokenId);

        // Clear token data so burned tokens cannot be endorsed/flagged
        delete tokens[tokenId];
        delete tokenTypes[tokenId];

        // Burn the ERC721 token (permanent destruction)
        _burn(tokenId);

        emit Events.TokenBurned(tokenId, rootId);
    }

    // Transfer Control

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);

        // Allow mints (from = 0) and burns (to = 0) unconditionally
        if (from != address(0) && to != address(0)) {
            // Root tokens: NEVER transferable
            if (tokenTypes[tokenId] == DataTypes.TokenType.ROOT) {
                revert Errors.RootNonTransferable();
            }
            // Sub & Profile tokens: only via transferToken()
            if (!_internalTransferActive) {
                revert Errors.UseTransferToken();
            }
        }

        return super._update(to, tokenId, auth);
    }

    //  Abstract Hook Implementations

    // Shared (EndorsementModule + FlagModule)
    function _getCallerRootId() internal view override(EndorsementModule, FlagModule) returns (uint256) {
        return ownerToRootId[msg.sender];
    }

    // EndorsementModule hooks
    function _requireTokenActive(uint256 id) internal view override(EndorsementModule, FlagModule) {
        if (tokenTypes[id] == DataTypes.TokenType.ROOT) revert Errors.NotToken();
        if (tokens[id].validUntil != 0 && tokens[id].validUntil < block.timestamp) {
            revert Errors.TokenExpired();
        }
    }

    function _requireNotSelfEndorsement(uint256 endorserRootId, uint256 tokenId) internal view override {
        if (endorserRootId == tokens[tokenId].parentRootId) revert Errors.CannotEndorseOwnToken();
    }

    function _incrementTotalEndorsementCount(uint256 tokenId) internal override {
        tokens[tokenId].totalEndorsementCount++;
    }

    function _incrementRevokedCount(uint256 tokenId) internal override {
        tokens[tokenId].revokedCount++;
    }

    function _getTokenValidUntil(uint256 id) internal view override returns (uint256) {
        return tokens[id].validUntil;
    }

    // bridges EndorsementModule and FlagModule
    function _checkFlaggingThreshold(uint256 tokenId) internal override(EndorsementModule) {
        _checkFlaggingThresholdInternal(tokenId);
    }

    // FlagModule shared hook
    function _countRevokedEndorsements(uint256 tokenId) internal view override(FlagModule) returns (uint256) {
        return tokens[tokenId].revokedCount;
    }

    // FlagModule hooks

    function _incrementFlagCount(uint256 id) internal override {
        tokens[id].flagCount++;
    }

    function _getFlagCount(uint256 id) internal view override returns (uint256) {
        return tokens[id].flagCount;
    }

    function _setFlagged(uint256 id, bool flagged) internal override {
        tokens[id].isFlagged = flagged;
    }

    function _getTotalEndorsementCount(uint256 id) internal view override returns (uint256) {
        return tokens[id].totalEndorsementCount;
    }

    function _requireNotSelfFlag(uint256 callerRootId, uint256 tokenId) internal view override {
        if (callerRootId == tokens[tokenId].parentRootId) revert Errors.CannotFlagOwnToken();
    }

    // Internal Helpers

    function _removeFromWalletList(address wallet, uint256 tokenId) internal {
        uint256[] storage list = walletTokens[wallet];
        uint256 len = list.length;
        for (uint256 i = 0; i < len; i++) {
            if (list[i] == tokenId) {
                list[i] = list[len - 1];
                list.pop();
                return;
            }
        }
    }

    function _removeFromRootTokenList(uint256 rootId, uint256 tokenId) internal {
        uint256[] storage list = rootToTokenIds[rootId];
        uint256 len = list.length;
        for (uint256 i = 0; i < len; i++) {
            if (list[i] == tokenId) {
                list[i] = list[len - 1];
                list.pop();
                return;
            }
        }
    }

    // View Functions

    function getTokensForRoot(uint256 rootId) external view returns (uint256[] memory) {
        return rootToTokenIds[rootId];
    }

    function getWalletTokens(address wallet) external view returns (uint256[] memory) {
        return walletTokens[wallet];
    }

    function getTransferHistory(uint256 tokenId) external view returns (address[] memory) {
        return transferHistory[tokenId];
    }

    function getRootIdentityView(uint256 rootId) external view returns (DataTypes.RootIdentityView memory) {
        DataTypes.RootIdentity storage r = rootIdentities[rootId];
        return
            DataTypes.RootIdentityView({
                tokenId: r.tokenId,
                walletAddress: r.walletAddress,
                displayName: r.displayName,
                createdAt: r.createdAt,
                isActive: r.isActive,
                tokenCount: rootToTokenIds[rootId].length
            });
    }
}
