// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DataTypes } from "./libraries/DataTypes.sol";
import { Errors } from "./libraries/Errors.sol";
import { Events } from "./libraries/Events.sol";

interface IIdentitySystem {
    function mintProfileToken(address to) external returns (uint256);
    function hasProfile(address user) external view returns (bool);
}

contract ProfileSystem {
    // State

    IIdentitySystem public immutable identitySystem;
    mapping(string => bool) public usernameTaken;
    mapping(address => bool) public hasMintedProfile;
    mapping(uint256 => DataTypes.ProfileMetadata) public profiles;

    // Constructor

    constructor(address _identitySystem) {
        identitySystem = IIdentitySystem(_identitySystem);
    }

    // Profile Creation

    function createProfile(DataTypes.ProfileMetadata calldata data) external returns (uint256) {
        if (bytes(data.name).length == 0) revert Errors.ProfileNameRequired();
        if (bytes(data.username).length < 3) revert Errors.ProfileUsernameTooShort();
        if (bytes(data.username).length > 32) revert Errors.ProfileUsernameTooLong();

        _validateUsername(data.username);

        // Uniqueness check
        if (usernameTaken[data.username]) revert Errors.ProfileUsernameTaken();
        if (hasMintedProfile[msg.sender] || identitySystem.hasProfile(msg.sender)) {
            revert Errors.AlreadyMintedProfile();
        }

        // State update
        usernameTaken[data.username] = true;
        hasMintedProfile[msg.sender] = true;

        // Mint via IdentitySystem
        uint256 tokenId = identitySystem.mintProfileToken(msg.sender);

        // Store metadata
        profiles[tokenId] = data;

        emit Events.ProfileCreated(tokenId, msg.sender, data.username);
        return tokenId;
    }

    // View Functions

    function getProfile(uint256 tokenId) external view returns (DataTypes.ProfileMetadata memory) {
        return profiles[tokenId];
    }

    // Internal Helpers

    function _validateUsername(string calldata username) internal pure {
        bytes memory b = bytes(username);
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 char = b[i];
            bool valid = (char >= 0x61 && char <= 0x7A) || // a-z
                (char >= 0x30 && char <= 0x39) || // 0-9
                char == 0x2E || // .
                char == 0x5F; // _
            if (!valid) revert Errors.InvalidProfileUsernameChar();
        }
    }
}
