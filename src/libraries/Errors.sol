// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Errors {
    // Transfer
    error RootNonTransferable();
    error UseTransferToken();
    error CannotTransferRoot();
    error SelfTransfer();
    error ZeroAddress();
    error NotHolder();

    // Identity
    error NoRootIdentity();
    error AlreadyHasRoot();
    error RootDeactivated();
    error InvalidExpiry();

    // Profile
    error AlreadyMintedProfile();
    error RecipientAlreadyHasProfile();
    error ProfileNameRequired();
    error ProfileUsernameRequired();
    error ProfileUsernameTaken();
    error ProfileUsernameTooShort();
    error ProfileUsernameTooLong();
    error InvalidProfileUsernameChar();

    // Token
    error NotToken();
    error TokenExpired();

    // Endorsement
    error CannotEndorseOwnToken();
    error AlreadyEndorsed();
    error NotYourEndorsement();
    error AlreadyRevoked();
    error EndorsementExpired();
    error TokenExpiresTooSoon();
    error NoActiveEndorsement();

    // Flag
    error AlreadyFlaggedByRoot();
    error CannotFlagOwnToken();

    // Admin
    error NotAdmin();
    error OnlyProfileSystem();
    error OnlyIdentitySystem();
    error ProfileSystemAlreadySet();
}
