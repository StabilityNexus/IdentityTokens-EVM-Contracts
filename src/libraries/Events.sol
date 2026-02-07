// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Events {
    event ProfileUpdated(uint256 indexed tokenId);
    event AttributeSet(uint256 indexed tokenId, bytes32 indexed keyHash, bytes value);
    event EndorsementGiven(uint256 indexed fromId, uint256 indexed toId, bytes32 typeHash, uint256 expiry);
    event EndorsementRevoked(uint256 indexed fromId, uint256 indexed toId, uint256 index);
    event IdentityCompromised(uint256 indexed tokenId);
    event BackupUpdateInitiated(uint256 indexed tokenId, address newBackup, uint256 unlockTime);
    event BackupUpdated(uint256 indexed tokenId, address newBackup);
    event IdentityRecovered(uint256 indexed tokenId, address newOwner);
}