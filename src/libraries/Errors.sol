// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Errors {
    // Transfer
    error RootNonTransferable();
    error UseTransferSubToken();
    error CannotTransferRoot();
    error SelfTransfer();
    error ZeroAddress();
    error NotHolder();

    // Identity
    error NoRootIdentity();
    error AlreadyHasRoot();
    error UsernameTaken();
    error UsernameTooShort();
    error UsernameTooLong();
    error InvalidUsernameChar();
    error RootDeactivated();
    error InvalidExpiry();

    // Sub-token
    error NotSubToken();
    error TokenExpired();

    // Endorsement
    error CannotEndorseOwnToken();
    error AlreadyEndorsed();
    error NotYourEndorsement();
    error AlreadyRevoked();
    error EndorsementExpired();
    error SubTokenExpiresTooSoon();
    error NoActiveEndorsement();

    // Flag
    error AlreadyFlaggedByRoot();
    error CannotFlagOwnToken();
}
