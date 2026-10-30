// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "../utils/BaseTest.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { Errors } from "../../src/libraries/Errors.sol";

contract ProfileTest is BaseTest {
    function test_CreateProfile() public {
        _root(alice, "Alice");
        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice Nakamoto",
            username: "alice",
            nationality: "US",
            github: "https://github.com/alice",
            email: "alice@example.com",
            discord: "alice#1234",
            xDotCom: "@alice",
            websitePortfolioLink: "https://alice.dev",
            ens: "alice.eth",
            avatarId: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta, _noLinks());

        assertEq(identitySystem.ownerOf(profileId), alice);
        assertEq(uint8(identitySystem.tokenTypeOf(profileId)), uint8(DataTypes.TokenType.PROFILE));
        assertTrue(identitySystem.hasProfile(alice));
        assertTrue(profileSystem.usernameTaken("alice"));
        assertTrue(profileSystem.hasMintedProfile(alice));
    }

    function test_CreateProfile_MinimalFields() public {
        _root(alice, "Alice");

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _noLinks());

        assertEq(identitySystem.ownerOf(profileId), alice);
    }

    function test_CreateProfile_WithLinks() public {
        _root(alice, "Alice");
        DataTypes.LinkUpdate[] memory links = new DataTypes.LinkUpdate[](2);
        links[0] = DataTypes.LinkUpdate(0, "Farcaster", "https://warpcast.com/alice");
        links[1] = DataTypes.LinkUpdate(1, "Blog", "https://alice.blog");

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), links);

        DataTypes.ProfileLink[] memory stored = _storedLinks(profileId);
        assertEq(stored.length, 2);
        assertEq(stored[0].label, "Farcaster");
        assertEq(stored[0].url, "https://warpcast.com/alice");
        assertEq(stored[1].label, "Blog");
        assertEq(stored[1].url, "https://alice.blog");
    }

    function test_CreateProfile_MoreThanSixLinks() public {
        _root(alice, "Alice");

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _numberedLinks(10));

        DataTypes.ProfileLink[] memory stored = _storedLinks(profileId);
        assertEq(stored.length, 10);
        assertEq(stored[0].label, "L0");
        assertEq(stored[9].label, "L9");
        assertEq(stored[9].url, "https://9.dev");
    }

    function test_RevertIf_CreateProfile_NoName() public {
        _root(alice, "Alice");

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileNameRequired.selector);
        profileSystem.createProfile(_meta("", "alice"), _noLinks());
    }

    function test_RevertIf_CreateProfile_UsernameTooShort() public {
        _root(alice, "Alice");

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileUsernameTooShort.selector);
        profileSystem.createProfile(_meta("Alice", "ab"), _noLinks());
    }

    function test_RevertIf_CreateProfile_UsernameTooLong() public {
        _root(alice, "Alice");

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileUsernameTooLong.selector);
        profileSystem.createProfile(_meta("Alice", "abcdefghijklmnopqrstuvwxyz0123456789"), _noLinks());
    }

    function test_RevertIf_CreateProfile_InvalidUsernameChar() public {
        _root(alice, "Alice");

        vm.prank(alice);
        vm.expectRevert(Errors.InvalidProfileUsernameChar.selector);
        profileSystem.createProfile(_meta("Alice", "alice!"), _noLinks());
    }

    function test_RevertIf_CreateProfile_UsernameTaken() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        vm.prank(alice);
        profileSystem.createProfile(_meta("Alice", "alice"), _noLinks());

        // Same username as Alice
        vm.prank(bob);
        vm.expectRevert(Errors.ProfileUsernameTaken.selector);
        profileSystem.createProfile(_meta("Bob", "alice"), _noLinks());
    }

    function test_RevertIf_CreateProfile_AlreadyMinted() public {
        _root(alice, "Alice");
        vm.prank(alice);
        profileSystem.createProfile(_meta("Alice", "alice"), _noLinks());

        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyMintedProfile.selector);
        profileSystem.createProfile(_meta("Alice", "alice2"), _noLinks());
    }

    function test_TransferToken_Profile() public {
        _root(alice, "Alice");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _noLinks());

        // Bob has no profile yet
        vm.prank(alice);
        identitySystem.transferToken(profileId, bob);

        assertEq(identitySystem.ownerOf(profileId), bob);
        assertFalse(identitySystem.hasProfile(alice));
        assertTrue(identitySystem.hasProfile(bob));

        // Alice can never mint again
        assertTrue(profileSystem.hasMintedProfile(alice));
    }

    function test_RevertIf_TransferToken_RecipientHasProfile() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        vm.prank(alice);
        uint256 aliceProfileId = profileSystem.createProfile(_meta("Alice", "alice"), _noLinks());
        vm.prank(bob);
        profileSystem.createProfile(_meta("Bob", "bob_x"), _noLinks());

        vm.prank(alice);
        vm.expectRevert(Errors.RecipientAlreadyHasProfile.selector);
        identitySystem.transferToken(aliceProfileId, bob);
    }

    function test_RevertIf_CreateProfile_AfterTransfer() public {
        _root(alice, "Alice");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _noLinks());

        vm.prank(alice);
        identitySystem.transferToken(profileId, bob);

        // Alice gave hers away, but the mint guard is permanent
        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyMintedProfile.selector);
        profileSystem.createProfile(_meta("Alice", "alice2"), _noLinks());

        // Bob now holds one
        vm.prank(bob);
        vm.expectRevert(Errors.AlreadyMintedProfile.selector);
        profileSystem.createProfile(_meta("Alice", "bob"), _noLinks());
    }

    function test_GetProfile() public {
        _root(alice, "Alice");
        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice Nakamoto",
            username: "alice",
            nationality: "US",
            github: "https://github.com/alice",
            email: "alice@example.com",
            discord: "alice#1234",
            xDotCom: "@alice",
            websitePortfolioLink: "https://alice.dev",
            ens: "alice.eth",
            avatarId: "a07"
        });
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta, _noLinks());

        DataTypes.ProfileMetadata memory stored = profileSystem.getProfile(profileId);

        assertEq(stored.name, "Alice Nakamoto");
        assertEq(stored.username, "alice");
        assertEq(stored.nationality, "US");
        assertEq(stored.github, "https://github.com/alice");
        assertEq(stored.email, "alice@example.com");
        assertEq(stored.discord, "alice#1234");
        assertEq(stored.xDotCom, "@alice");
        assertEq(stored.websitePortfolioLink, "https://alice.dev");
        assertEq(stored.ens, "alice.eth");
        assertEq(stored.avatarId, "a07");
    }

    function test_GetProfileTokenId() public {
        _root(alice, "Alice");

        assertEq(identitySystem.getProfileTokenId(alice), 0);

        DataTypes.ProfileMetadata memory meta = _meta("Alice", "alice");
        meta.nationality = "US";
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta, _noLinks());

        assertEq(identitySystem.getProfileTokenId(alice), profileId);
    }

    function test_GetProfileTokenId_IgnoresRootAndSubTokens() public {
        _root(alice, "Alice");
        _token(alice);

        assertEq(identitySystem.getProfileTokenId(alice), 0);
    }

    function test_BurnToken_ProfileHidesLinks() public {
        _root(alice, "Alice");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _numberedLinks(3));

        vm.prank(alice);
        identitySystem.burnToken(profileId);

        (DataTypes.ProfileLink[] memory stored, uint256 total) = profileSystem.getLinks(profileId, 0, 10);
        assertEq(stored.length, 0);
        assertEq(total, 0);
        assertEq(profileSystem.getProfile(profileId).username, "");
        assertFalse(profileSystem.usernameTaken("alice"));
    }
}
