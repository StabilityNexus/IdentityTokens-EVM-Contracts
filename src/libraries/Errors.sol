// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Errors {
    error NotTokenOwner();
    error TargetInvalid();
    error SelfEndorsement();
    error EndorserCompromised();
    error IdentityCompromised();
    error IndexOutOfBounds();
    error NotEndorser();
    error AlreadyRevoked();
    error TimelockActive();
    error NoPendingUpdate();
    error NotBackupWallet();
    error AlreadyHasIdentity();
    error DuplicateEndorsement();
    error ArrayLengthMismatch();
    error MaxEndorsementsReached();
}
