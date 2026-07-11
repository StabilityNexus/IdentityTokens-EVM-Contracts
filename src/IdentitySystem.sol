// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { EndorsementModule } from "./modules/EndorsementModule.sol";
import { FlagModule } from "./modules/FlagModule.sol";
import { Schema } from "./libraries/Schema.sol";
import { DataTypes } from "./libraries/DataTypes.sol";
import { Errors } from "./libraries/Errors.sol";
import { Events } from "./libraries/Events.sol";

/**
 * @title IdentitySystem
 * @notice Decentralised identity with soulbound roots, transferable
 *         sub-tokens, time-based endorsements, revocation and flagging.
 *         Inheritance chain:
 *           ERC721 → Schema → EndorsementModule → FlagModule
 *         All abstract hooks from every module are resolved here.
 */
contract IdentitySystem is ERC721, Schema, EndorsementModule, FlagModule {
    uint256 private _nextTokenId = 1;

    // Username registry is immutable once claimed
    mapping(string => bool) public usernameTaken;
    mapping(string => uint256) public usernameToRootId;

    // Root identity storage
    mapping(uint256 => DataTypes.RootIdentity) public rootIdentities;
    mapping(address => uint256) public ownerToRootId;

    // Sub-token storage
    mapping(uint256 => DataTypes.SubToken) public subTokens;
    mapping(uint256 => uint256[]) public rootToSubTokenIds;

    // Token type tracking  (TokenType.ROOT | TokenType.SUB)
    mapping(uint256 => DataTypes.TokenType) public tokenTypes;

    // Transfer history per token
    mapping(uint256 => address[]) public transferHistory;

    // Wallet-level sub-token index
    mapping(address => uint256[]) public walletSubTokens;

    // Transfer control flags — prevent raw ERC721 transfers
    bool private _internalTransferActive;

    constructor() ERC721("Decentralized-Identity-Tokens", "DIT") {}

    // Root Identity

    function createRootIdentity(
        string calldata username,
        string calldata displayName,
        bytes calldata optionalMetadata
    ) external returns (uint256) {
        if (bytes(username).length < 3) revert Errors.UsernameTooShort();
        if (bytes(username).length > 32) revert Errors.UsernameTooLong();
        if (usernameTaken[username]) revert Errors.UsernameTaken();
        if (ownerToRootId[msg.sender] != 0) revert Errors.AlreadyHasRoot();

        _validateUsername(username);

        uint256 rootId = _nextTokenId++;
        _mint(msg.sender, rootId);

        usernameTaken[username] = true;
        usernameToRootId[username] = rootId;
        ownerToRootId[msg.sender] = rootId;
        tokenTypes[rootId] = DataTypes.TokenType.ROOT;

        rootIdentities[rootId] = DataTypes.RootIdentity({
            username: username,
            tokenId: rootId,
            owner: msg.sender,
            createdAt: block.timestamp,
            isActive: true,
            metadataHash: keccak256(optionalMetadata)
        });

        if (bytes(displayName).length > 0) {
            _setRootAttribute(rootId, "name", bytes(displayName));
        }
        if (optionalMetadata.length > 0) {
            _setRootAttribute(rootId, "metadata", optionalMetadata);
        }

        emit Events.RootIdentityCreated(rootId, msg.sender, username);
        return rootId;
    }

    // Sub-token

    function createSubToken(
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

        uint256 subTokenId = _nextTokenId++;
        _mint(msg.sender, subTokenId);

        tokenTypes[subTokenId] = DataTypes.TokenType.SUB;

        subTokens[subTokenId] = DataTypes.SubToken({
            subTokenId: subTokenId,
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

        rootToSubTokenIds[rootId].push(subTokenId);
        walletSubTokens[msg.sender].push(subTokenId);
        transferHistory[subTokenId].push(msg.sender);

        emit Events.SubTokenCreated(subTokenId, rootId, tokenName, tokenType);
        return subTokenId;
    }

    function transferSubToken(uint256 subTokenId, address sendingTo) external {
        if (ownerOf(subTokenId) != msg.sender) revert Errors.NotHolder();
        if (tokenTypes[subTokenId] != DataTypes.TokenType.SUB) revert Errors.CannotTransferRoot();
        if (sendingTo == msg.sender) revert Errors.SelfTransfer();
        if (sendingTo == address(0)) revert Errors.ZeroAddress();
        if (subTokens[subTokenId].validUntil != 0 && subTokens[subTokenId].validUntil < block.timestamp) {
            revert Errors.TokenExpired();
        }

        // Record transfer
        transferHistory[subTokenId].push(sendingTo);
        subTokens[subTokenId].transferCount++;

        // Update wallet indices
        _removeFromWalletList(msg.sender, subTokenId);
        walletSubTokens[sendingTo].push(subTokenId);

        // Execute controlled transfer
        _internalTransferActive = true;
        _transfer(msg.sender, sendingTo, subTokenId);
        _internalTransferActive = false;

        emit Events.SubTokenTransferred(subTokenId, msg.sender, sendingTo);
    }

    function burnSubToken(uint256 subTokenId) external {
        if (ownerOf(subTokenId) != msg.sender) revert Errors.NotHolder();
        if (tokenTypes[subTokenId] != DataTypes.TokenType.SUB) revert Errors.NotSubToken();

        uint256 rootId = subTokens[subTokenId].parentRootId;

        // Remove from wallet tracking
        _removeFromWalletList(msg.sender, subTokenId);

        // Remove from root's sub-token list
        _removeFromRootSubTokenList(rootId, subTokenId);

        // Clear sub-token data so burned tokens cannot be endorsed/flagged
        delete subTokens[subTokenId];
        delete tokenTypes[subTokenId];

        // Burn the ERC721 token (permanent destruction)
        _burn(subTokenId);

        emit Events.SubTokenBurned(subTokenId, rootId);
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
            // Sub tokens: only via transferSubToken()
            if (!_internalTransferActive) {
                revert Errors.UseTransferSubToken();
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

    function _requireSubTokenActive(uint256 id) internal view override(EndorsementModule, FlagModule) {
        if (tokenTypes[id] != DataTypes.TokenType.SUB) revert Errors.NotSubToken();
        if (subTokens[id].validUntil != 0 && subTokens[id].validUntil < block.timestamp) {
            revert Errors.TokenExpired();
        }
    }

    function _requireNotSelfEndorsement(uint256 endorserRootId, uint256 subTokenId) internal view override {
        if (endorserRootId == subTokens[subTokenId].parentRootId) revert Errors.CannotEndorseOwnToken();
    }

    function _incrementTotalEndorsementCount(uint256 subTokenId) internal override {
        subTokens[subTokenId].totalEndorsementCount++;
    }

    function _incrementRevokedCount(uint256 subTokenId) internal override {
        subTokens[subTokenId].revokedCount++;
    }

    function _getSubTokenValidUntil(uint256 id) internal view override returns (uint256) {
        return subTokens[id].validUntil;
    }

    // bridges EndorsementModule and FlagModule
    function _checkFlaggingThreshold(uint256 subTokenId) internal override(EndorsementModule) {
        _checkFlaggingThresholdInternal(subTokenId);
    }

    // FlagModule shared hook
    function _countRevokedEndorsements(uint256 subTokenId) internal view override(FlagModule) returns (uint256) {
        return subTokens[subTokenId].revokedCount;
    }

    // FlagModule hooks

    function _incrementFlagCount(uint256 id) internal override {
        subTokens[id].flagCount++;
    }

    function _getFlagCount(uint256 id) internal view override returns (uint256) {
        return subTokens[id].flagCount;
    }

    function _setFlagged(uint256 id, bool flagged) internal override {
        subTokens[id].isFlagged = flagged;
    }

    function _getTotalEndorsementCount(uint256 id) internal view override returns (uint256) {
        return subTokens[id].totalEndorsementCount;
    }

    function _requireNotSelfFlag(uint256 callerRootId, uint256 subTokenId) internal view override {
        if (callerRootId == subTokens[subTokenId].parentRootId) revert Errors.CannotFlagOwnToken();
    }

    // Internal Helpers

    function _removeFromWalletList(address wallet, uint256 subTokenId) internal {
        uint256[] storage list = walletSubTokens[wallet];
        uint256 len = list.length;
        for (uint256 i = 0; i < len; i++) {
            if (list[i] == subTokenId) {
                list[i] = list[len - 1];
                list.pop();
                return;
            }
        }
    }

    function _removeFromRootSubTokenList(uint256 rootId, uint256 subTokenId) internal {
        uint256[] storage list = rootToSubTokenIds[rootId];
        uint256 len = list.length;
        for (uint256 i = 0; i < len; i++) {
            if (list[i] == subTokenId) {
                list[i] = list[len - 1];
                list.pop();
                return;
            }
        }
    }

    function _validateUsername(string calldata username) internal pure {
        bytes memory b = bytes(username);
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 char = b[i];
            bool valid = (char >= 0x61 && char <= 0x7A) || // a-z
                (char >= 0x30 && char <= 0x39) || // 0-9
                char == 0x2E || // .
                char == 0x5F; // _
            if (!valid) revert Errors.InvalidUsernameChar();
        }
    }

    // View Functions

    function getSubTokensForRoot(uint256 rootId) external view returns (uint256[] memory) {
        return rootToSubTokenIds[rootId];
    }

    function getWalletSubTokens(address wallet) external view returns (uint256[] memory) {
        return walletSubTokens[wallet];
    }

    function getTransferHistory(uint256 tokenId) external view returns (address[] memory) {
        return transferHistory[tokenId];
    }

    function getRootIdentityView(uint256 rootId) external view returns (DataTypes.RootIdentityView memory) {
        DataTypes.RootIdentity storage r = rootIdentities[rootId];
        return
            DataTypes.RootIdentityView({
                tokenId: r.tokenId,
                username: r.username,
                owner: r.owner,
                createdAt: r.createdAt,
                isActive: r.isActive,
                subTokenCount: rootToSubTokenIds[rootId].length
            });
    }

    function resolveUsername(string calldata username) external view returns (uint256) {
        return usernameToRootId[username];
    }
}
