// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IdentitySystem } from "../../src/IdentitySystem.sol";
import { ProfileSystem } from "../../src/ProfileSystem.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";

/// @dev Deploys and wires IdentitySystem and ProfileSystem, plus the helpers the unit tests share.
abstract contract BaseTest is Test {
    IdentitySystem public identitySystem;
    ProfileSystem public profileSystem;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    function setUp() public {
        identitySystem = new IdentitySystem(address(0xDE7), address(0xFEE), 100);
        profileSystem = new ProfileSystem(address(identitySystem));
        identitySystem.setProfileSystem(address(profileSystem));
    }

    /// @dev Creates a root identity for `user`; returns its id.
    function _root(address user, string memory displayName) internal returns (uint256) {
        vm.prank(user);
        return identitySystem.createRootIdentity(displayName);
    }

    /// @dev Creates a "GitHub" token with no expiry for `user`, who must have a root; returns its id.
    function _token(address user) internal returns (uint256) {
        vm.prank(user);
        return identitySystem.createToken("GitHub", "social", bytes(""), "", 0);
    }

    /// @dev Gives `user` a root and a minimal profile, both named `username`; returns the profile id.
    function _profile(address user, string memory username) internal returns (uint256) {
        _root(user, username);
        vm.prank(user);
        return profileSystem.createProfile(_meta(username, username), _noLinks());
    }

    /// @dev Profile metadata with only name and username set.
    function _meta(
        string memory name,
        string memory username
    ) internal pure returns (DataTypes.ProfileMetadata memory) {
        return
            DataTypes.ProfileMetadata({
                name: name,
                username: username,
                nationality: "",
                github: "",
                email: "",
                discord: "",
                xDotCom: "",
                websitePortfolioLink: "",
                ens: "",
                avatarId: ""
            });
    }

    /// @dev An empty link list for createProfile / updateProfile.
    function _noLinks() internal pure returns (DataTypes.LinkUpdate[] memory) {
        return new DataTypes.LinkUpdate[](0);
    }

    /// @dev `count` links "L0".."Ln", appended in order.
    function _numberedLinks(uint32 count) internal pure returns (DataTypes.LinkUpdate[] memory links) {
        links = new DataTypes.LinkUpdate[](count);
        for (uint32 i = 0; i < count; i++) {
            string memory n = vm.toString(i);
            links[i] = DataTypes.LinkUpdate(i, string.concat("L", n), string.concat("https://", n, ".dev"));
        }
    }

    /// @dev Every stored link of a profile, gaps included.
    function _storedLinks(uint256 profileId) internal view returns (DataTypes.ProfileLink[] memory links) {
        (links, ) = profileSystem.getLinks(profileId, 0, type(uint256).max);
    }

    /// @dev Moves time past MIN_ROOT_AGE so every root made so far is established.
    function _ageRoots() internal {
        vm.warp(block.timestamp + identitySystem.MIN_ROOT_AGE());
    }

    /// @dev Creates `count` roots from `startAddr` on, ages them so they count toward auto-flag,
    ///      and has each one attest `tokenId`.
    function _createAttesters(uint256 tokenId, uint160 startAddr, uint256 count, uint256 duration) internal {
        for (uint256 i = 0; i < count; i++) {
            _root(address(startAddr + uint160(i)), "");
        }
        _ageRoots();
        for (uint256 i = 0; i < count; i++) {
            vm.prank(address(startAddr + uint160(i)));
            identitySystem.attestToken(tokenId, duration);
        }
    }
}
