// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/DataTypes.sol";
import "./libraries/Errors.sol";
import "./libraries/Events.sol";

contract TNT is ERC721, Ownable {
    uint256 private _nextTokenId;
    mapping(uint256 => address) public tokenIssuers;
    mapping(uint256 => mapping(bytes32 => bytes)) private _attributes;
    mapping(uint256 => DataTypes.IdentityState) public identityState;
    mapping(uint256 => DataTypes.Endorsement[]) private _endorsements;
    
    uint256 public constant MAX_ATTRIBUTE_SIZE = 1024;
    uint256 public constant MAX_PAGE_SIZE = 100;

    constructor() ERC721("Trust Network Token", "TNT") Ownable(msg.sender) {}

    modifier onlyTokenOwner(uint256 tokenId) {
        if (ownerOf(tokenId) != msg.sender) revert Errors.NotTokenOwner();
        _;
    }

    modifier notCompromised(uint256 tokenId) {
        if (identityState[tokenId].isCompromised) revert Errors.IdentityCompromised();
        _;
    }

    function issueToken(address to) external onlyOwner {
        if (to == address(0)) revert Errors.TargetInvalid();
        _nextTokenId++;
        uint256 tokenId = _nextTokenId;
        tokenIssuers[tokenId] = msg.sender;
        _safeMint(to, tokenId);
        emit Events.IdentityCreated(tokenId, to);
    }

    function setAttribute(uint256 tokenId, bytes32 keyHash, bytes calldata value) external onlyTokenOwner(tokenId) notCompromised(tokenId) {
        if (value.length > MAX_ATTRIBUTE_SIZE) revert Errors.PageTooLarge(); // re-using error or could use a new one, but let's stick to size guard
        _attributes[tokenId][keyHash] = value;
        emit Events.AttributeSet(tokenId, keyHash, value);
    }

    function getAttribute(uint256 tokenId, bytes32 keyHash) external view returns (bytes memory) {
        return _attributes[tokenId][keyHash];
    }

    function getIdentityState(uint256 tokenId) external view returns (DataTypes.IdentityState memory) {
        return identityState[tokenId];
    }

    function giveEndorsement(uint256 fromId, uint256 toId, bytes32 typeHash, uint256 expiry) external onlyTokenOwner(fromId) notCompromised(fromId) notCompromised(toId) {
        if (fromId == toId) revert Errors.SelfEndorsement();
        
        // Check already endorsed
        DataTypes.Endorsement[] storage endorsements = _endorsements[toId];
        for (uint256 i = 0; i < endorsements.length; i++) {
            if (endorsements[i].endorserTokenId == fromId &&
                endorsements[i].connectionType == typeHash &&
                endorsements[i].revokedAt == 0 &&
                (endorsements[i].validUntil == 0 || endorsements[i].validUntil > block.timestamp)) {
                revert Errors.AlreadyEndorsed();
            }
        }

        endorsements.push(DataTypes.Endorsement({
            endorserTokenId: fromId,
            connectionType: typeHash,
            timestamp: block.timestamp,
            validUntil: expiry,
            revokedAt: 0
        }));

        emit Events.EndorsementGiven(fromId, toId, typeHash, expiry);
    }

    function revokeEndorsement(uint256 fromId, uint256 toId, uint256 index) external onlyTokenOwner(fromId) {
        DataTypes.Endorsement[] storage endorsements = _endorsements[toId];
        if (index >= endorsements.length) revert Errors.IndexOutOfBounds();
        if (endorsements[index].endorserTokenId != fromId) revert Errors.NotEndorser();
        if (endorsements[index].revokedAt != 0) revert Errors.AlreadyRevoked();

        endorsements[index].revokedAt = block.timestamp;
        emit Events.EndorsementRevoked(fromId, toId, index);
    }

    function isEndorsementActive(uint256 fromId, uint256 toId, uint256 index) external view returns (bool) {
        DataTypes.Endorsement[] storage endorsements = _endorsements[toId];
        if (index >= endorsements.length) return false;
        if (endorsements[index].endorserTokenId != fromId) return false;
        if (endorsements[index].revokedAt != 0) return false;
        if (endorsements[index].validUntil != 0 && endorsements[index].validUntil <= block.timestamp) return false;
        
        // Also check if endorser is compromised
        if (identityState[fromId].isCompromised) return false;

        return true;
    }

    function getEndorsements(uint256 tokenId, uint256 start, uint256 end) external view returns (DataTypes.Endorsement[] memory) {
        DataTypes.Endorsement[] storage allEndorsements = _endorsements[tokenId];
        if (start > allEndorsements.length) revert Errors.IndexOutOfBounds();
        if (end > allEndorsements.length) {
            end = allEndorsements.length;
        }
        if (end < start) revert Errors.IndexOutOfBounds();

        uint256 count = end - start;
        if (count > MAX_PAGE_SIZE) revert Errors.PageTooLarge();

        DataTypes.Endorsement[] memory result = new DataTypes.Endorsement[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = allEndorsements[start + i];
        }
        return result;
    }

    function burn(uint256 tokenId) external onlyTokenOwner(tokenId) {
        _burn(tokenId);
        // Note: Graph entries might be explicitly handled off-chain,
        // but token is burned making it invalid.
    }

    function initiateBackupUpdate(uint256 tokenId, address newBackup) external onlyTokenOwner(tokenId) {
        identityState[tokenId].pendingBackupWallet = newBackup;
        identityState[tokenId].backupUnlockTime = block.timestamp + 2 days;
        emit Events.BackupUpdateInitiated(tokenId, newBackup, identityState[tokenId].backupUnlockTime);
    }

    function confirmBackupUpdate(uint256 tokenId) external onlyTokenOwner(tokenId) {
        if (identityState[tokenId].backupUnlockTime == 0) revert Errors.NoPendingUpdate();
        if (block.timestamp < identityState[tokenId].backupUnlockTime) revert Errors.TimelockActive();

        address newBackup = identityState[tokenId].pendingBackupWallet;
        identityState[tokenId].backupWallet = newBackup;
        identityState[tokenId].pendingBackupWallet = address(0);
        identityState[tokenId].backupUnlockTime = 0;

        emit Events.BackupUpdated(tokenId, newBackup);
    }

    function recoverIdentity(uint256 tokenId, address newOwner) external {
        if (msg.sender != identityState[tokenId].backupWallet) revert Errors.NotBackupWallet();
        if (newOwner == address(0)) revert Errors.TargetInvalid();

        identityState[tokenId].isCompromised = false;
        _transfer(ownerOf(tokenId), newOwner, tokenId);
        emit Events.IdentityRecovered(tokenId, newOwner);
        emit Events.IdentityCompromiseCleared(tokenId);
    }

    function markCompromised(uint256 tokenId) external onlyOwner {
        identityState[tokenId].isCompromised = true;
        emit Events.IdentityCompromised(tokenId);
    }

    // Soulbound token enforcement
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        // Allow minting (from zero) and burning (to zero)
        if (from != address(0) && to != address(0)) {
            // Also allow recovery from backup wallet. This is handled dynamically via _transfer.
            // But wait, the standard ERC721 _update is called by _transfer.
            // If we revert here, _transfer will revert.
            // We only want to block `transferFrom` and `safeTransferFrom` called by users directly.
            // If msg.sender is recovering, it uses recoverIdentity which calls _transfer.
            // To differentiate, we can check if auth == address(0) for internal transfers maybe?
            // Wait, in OpenZeppelin 5.0, `auth` is the address that initiated the transfer.
            // But let's check a standard way to make soulbound unless called by specific function.
            // We can just revert. But how does recoverIdentity work if we revert here?
            // In recoverIdentity, we can set a flag or we can check if `msg.sender == backupWallet`.
            if (msg.sender != identityState[tokenId].backupWallet) {
                revert("Soulbound: Transfer failed");
            }
        }
        return super._update(to, tokenId, auth);
    }
}
