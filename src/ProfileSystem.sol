// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DataTypes } from "./libraries/DataTypes.sol";
import { Errors } from "./libraries/Errors.sol";
import { Events } from "./libraries/Events.sol";

interface IIdentitySystem {
    function mintProfileToken(address to) external returns (uint256);
    function hasProfile(address user) external view returns (bool);
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract ProfileSystem {
    // State

    IIdentitySystem public immutable identitySystem;
    mapping(string => bool) public usernameTaken;
    mapping(address => bool) public hasMintedProfile;
    mapping(uint256 => DataTypes.ProfileMetadata) public profiles;
    mapping(string => uint256) public usernameToProfileTokenId;

    // Custom links live in fixed slots so editing one link rewrites only that slot
    uint8 public constant MAX_LINKS = 6;
    mapping(uint256 => DataTypes.ProfileLink[MAX_LINKS]) internal _links;

    // Constructor

    constructor(address _identitySystem) {
        identitySystem = IIdentitySystem(_identitySystem);
    }

    // Profile Creation

    /**
     * @notice Creates the caller's one-time profile and mints its profile token.
     * @param data Profile metadata; `name` and a valid, unique `username` are required.
     * @param links Initial custom links, one entry per slot (slot < MAX_LINKS).
     * @return The minted profile token id.
     */
    function createProfile(
        DataTypes.ProfileMetadata calldata data,
        DataTypes.LinkUpdate[] calldata links
    ) external returns (uint256) {
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
        _applyLinks(tokenId, links);

        // Store username → tokenId reverse lookup
        usernameToProfileTokenId[data.username] = tokenId;

        emit Events.ProfileCreated(tokenId, msg.sender, data.username);
        return tokenId;
    }

    // Profile Editing

    /**
     * @notice Edits only the given fields and link slots of a profile; untouched data is not rewritten.
     * @dev The username cannot be edited (ProfileField has no USERNAME member).
     * @param tokenId The profile token id; the caller must currently own it.
     * @param fields Fields to overwrite. Setting NAME to an empty string reverts.
     * @param links Link slots to overwrite; an empty url clears the slot.
     */
    function updateProfile(
        uint256 tokenId,
        DataTypes.FieldUpdate[] calldata fields,
        DataTypes.LinkUpdate[] calldata links
    ) external {
        DataTypes.ProfileMetadata storage profile = profiles[tokenId];
        // Every profile has a username, so an empty one means burned, never created, or not a profile token
        if (bytes(profile.username).length == 0) revert Errors.ProfileNotFound();
        if (identitySystem.ownerOf(tokenId) != msg.sender) revert Errors.NotProfileOwner();
        if (fields.length == 0 && links.length == 0) revert Errors.EmptyProfileUpdate();

        for (uint256 i = 0; i < fields.length; i++) {
            _setField(profile, fields[i].field, fields[i].value);
        }
        _applyLinks(tokenId, links);

        emit Events.ProfileUpdated(tokenId);
    }

    // Profile Burn Cleanup (called by IdentitySystem when a profile token is burned)

    function cleanupBurnedProfile(uint256 tokenId) external {
        if (msg.sender != address(identitySystem)) revert Errors.OnlyIdentitySystem();

        DataTypes.ProfileMetadata storage profile = profiles[tokenId];
        string memory username = profile.username;

        // Release the username reservation so it can be claimed by someone else
        if (bytes(username).length > 0) {
            delete usernameTaken[username];
            delete usernameToProfileTokenId[username];
        }

        // Clear metadata and links
        delete profiles[tokenId];
        delete _links[tokenId];

        // Note: hasMintedProfile stays true — permanent mint guard (user already used their one-time mint)
    }

    // View Functions

    function getProfile(uint256 tokenId) external view returns (DataTypes.ProfileMetadata memory) {
        return profiles[tokenId];
    }

    /**
     * @notice Returns all custom link slots of a profile; empty slots have an empty url.
     * @param tokenId The profile token id.
     */
    function getLinks(uint256 tokenId) external view returns (DataTypes.ProfileLink[MAX_LINKS] memory) {
        return _links[tokenId];
    }

    // Internal Helpers

    function _setField(
        DataTypes.ProfileMetadata storage profile,
        DataTypes.ProfileField field,
        string calldata value
    ) internal {
        if (field == DataTypes.ProfileField.NAME) {
            if (bytes(value).length == 0) revert Errors.ProfileNameRequired();
            profile.name = value;
        } else if (field == DataTypes.ProfileField.NATIONALITY) {
            profile.nationality = value;
        } else if (field == DataTypes.ProfileField.GITHUB) {
            profile.github = value;
        } else if (field == DataTypes.ProfileField.EMAIL) {
            profile.email = value;
        } else if (field == DataTypes.ProfileField.DISCORD) {
            profile.discord = value;
        } else if (field == DataTypes.ProfileField.X_DOT_COM) {
            profile.xDotCom = value;
        } else if (field == DataTypes.ProfileField.WEBSITE) {
            profile.websitePortfolioLink = value;
        } else if (field == DataTypes.ProfileField.ENS) {
            profile.ens = value;
        } else {
            profile.avatarId = value; // ProfileField.AVATAR
        }
    }

    function _applyLinks(uint256 tokenId, DataTypes.LinkUpdate[] calldata links) internal {
        for (uint256 i = 0; i < links.length; i++) {
            DataTypes.LinkUpdate calldata link = links[i];
            if (link.slot >= MAX_LINKS) revert Errors.InvalidLinkSlot();

            if (bytes(link.url).length == 0) {
                delete _links[tokenId][link.slot];
            } else {
                DataTypes.ProfileLink storage stored = _links[tokenId][link.slot];
                stored.label = link.label;
                stored.url = link.url;
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
            if (!valid) revert Errors.InvalidProfileUsernameChar();
        }
    }
}
