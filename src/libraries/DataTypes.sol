// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DataTypes {
    struct Endorsement {
        uint256 endorserTokenId;
        bytes32 connectionType;
        uint256 timestamp;
        uint256 validUntil;
        uint256 revokedAt;
    }

    struct IdentityProfile {
        string name;
        string socialLinks;
        uint256 birthDate;
        string nationality;
        string residence;
    }

    struct IdentityState {
        bool isCompromised; // logic for recovery
        address backupWallet;
        address pendingBackupWallet;
        uint256 backupUnlockTime;
    }
}