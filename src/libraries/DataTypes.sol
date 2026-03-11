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

    /// @notice Tracks an endorsement given by a token (reverse index).
    /// @dev Stored in `_givenEndorsements[fromId]` to enable efficient
    ///      "which identities has fromId endorsed?" queries required by DIT spec.
    struct GivenEndorsement {
        uint256 toTokenId;
        uint256 endorsementIndex; // index in _endorsements[toTokenId]
    }

    struct IdentityState {
        bool isCompromised;
        address backupWallet;
        address pendingBackupWallet;
        uint256 backupUnlockTime;
    }
}
