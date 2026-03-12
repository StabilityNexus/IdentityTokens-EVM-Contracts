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

    /// @notice Tracks an endorsement given BY a token (reverse index).
    /// @dev Stored in `_givenEndorsements[fromTokenId]` to satisfy the DIT spec
    ///      requirement: "efficient to retrieve which identities have been endorsed
    ///      by a given identity".
    struct GivenEndorsement {
        uint256 toTokenId;         // the identity that was endorsed
        uint256 endorsementIndex;  // index in endorsements[toTokenId]
    }

    struct IdentityState {
        bool isCompromised;
        address backupWallet;
        address pendingBackupWallet;
        uint256 backupUnlockTime;
    }
}
