// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "../utils/BaseTest.sol";
import { ProfileSystem } from "../../src/ProfileSystem.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { Errors } from "../../src/libraries/Errors.sol";
import { Events } from "../../src/libraries/Events.sol";

contract ProfileEditTest is BaseTest {
    /// @dev An empty field list for updateProfile.
    function _noFields() internal pure returns (DataTypes.FieldUpdate[] memory) {
        return new DataTypes.FieldUpdate[](0);
    }

    /// @dev A single-field update list.
    function _field(
        DataTypes.ProfileField field,
        string memory value
    ) internal pure returns (DataTypes.FieldUpdate[] memory fields) {
        fields = new DataTypes.FieldUpdate[](1);
        fields[0] = DataTypes.FieldUpdate(field, value);
    }

    /// @dev A single-link update list.
    function _link(
        uint32 index,
        string memory label,
        string memory url
    ) internal pure returns (DataTypes.LinkUpdate[] memory links) {
        links = new DataTypes.LinkUpdate[](1);
        links[0] = DataTypes.LinkUpdate(index, label, url);
    }

    function test_UpdateProfile_SingleField() public {
        _root(alice, "Alice");
        DataTypes.ProfileMetadata memory meta = _meta("Alice", "alice");
        meta.github = "https://github.com/alice";
        meta.discord = "alice#1234";
        meta.ens = "alice.eth";
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta, _noLinks());

        vm.prank(alice);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.DISCORD, "alice_new"), _noLinks());

        DataTypes.ProfileMetadata memory stored = profileSystem.getProfile(profileId);
        assertEq(stored.discord, "alice_new");
        assertEq(stored.name, "Alice");
        assertEq(stored.username, "alice");
        assertEq(stored.github, "https://github.com/alice");
        assertEq(stored.ens, "alice.eth");
    }

    function test_UpdateProfile_MultipleFieldsAndLinks() public {
        _root(alice, "Alice");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(
            _meta("Alice", "alice"),
            _link(0, "Farcaster", "https://warpcast.com/alice")
        );

        DataTypes.FieldUpdate[] memory fields = new DataTypes.FieldUpdate[](3);
        fields[0] = DataTypes.FieldUpdate(DataTypes.ProfileField.NAME, "Alice Nakamoto");
        fields[1] = DataTypes.FieldUpdate(DataTypes.ProfileField.NATIONALITY, "JP");
        fields[2] = DataTypes.FieldUpdate(DataTypes.ProfileField.X_DOT_COM, "alice");

        DataTypes.LinkUpdate[] memory links = new DataTypes.LinkUpdate[](2);
        links[0] = DataTypes.LinkUpdate(0, "Warpcast", "https://warpcast.com/alice.eth");
        links[1] = DataTypes.LinkUpdate(1, "Blog", "https://alice.blog");

        vm.prank(alice);
        profileSystem.updateProfile(profileId, fields, links);

        DataTypes.ProfileMetadata memory stored = profileSystem.getProfile(profileId);
        assertEq(stored.name, "Alice Nakamoto");
        assertEq(stored.nationality, "JP");
        assertEq(stored.xDotCom, "alice");

        DataTypes.ProfileLink[] memory storedLinks = _storedLinks(profileId);
        assertEq(storedLinks.length, 2);
        assertEq(storedLinks[0].label, "Warpcast");
        assertEq(storedLinks[0].url, "https://warpcast.com/alice.eth");
        assertEq(storedLinks[1].label, "Blog");
        assertEq(storedLinks[1].url, "https://alice.blog");
    }

    function test_UpdateProfile_EmitsEvent() public {
        uint256 profileId = _profile(alice, "alice");

        vm.expectEmit(true, false, false, true);
        emit Events.ProfileUpdated(profileId);

        vm.prank(alice);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.GITHUB, "alice"), _noLinks());
    }

    function test_UpdateProfile_UsernameUnchanged() public {
        uint256 profileId = _profile(alice, "alice");

        // Touch every editable field; none of them may affect the username
        DataTypes.FieldUpdate[] memory fields = new DataTypes.FieldUpdate[](9);
        for (uint8 i = 0; i < 9; i++) {
            fields[i] = DataTypes.FieldUpdate(DataTypes.ProfileField(i), "changed");
        }
        vm.prank(alice);
        profileSystem.updateProfile(profileId, fields, _noLinks());

        assertEq(profileSystem.getProfile(profileId).username, "alice");
        assertEq(profileSystem.getProfile(profileId).name, "changed");
        assertEq(profileSystem.getProfile(profileId).avatarId, "changed");
        assertTrue(profileSystem.usernameTaken("alice"));
        assertEq(profileSystem.usernameToProfileTokenId("alice"), profileId);
    }

    function test_UpdateProfile_AfterTransfer() public {
        uint256 profileId = _profile(alice, "alice");
        vm.prank(alice);
        identitySystem.transferToken(profileId, bob);

        vm.prank(bob);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.NAME, "Bob"), _noLinks());
        assertEq(profileSystem.getProfile(profileId).name, "Bob");

        vm.prank(alice);
        vm.expectRevert(Errors.NotProfileOwner.selector);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.NAME, "Alice"), _noLinks());
    }

    function test_UpdateProfile_ClearMiddleLinkLeavesGap() public {
        _root(alice, "Alice");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _numberedLinks(3));

        vm.prank(alice);
        profileSystem.updateProfile(profileId, _noFields(), _link(1, "", ""));

        DataTypes.ProfileLink[] memory stored = _storedLinks(profileId);
        assertEq(stored.length, 3);
        assertEq(stored[1].label, "");
        assertEq(stored[1].url, "");
        assertEq(stored[0].url, "https://0.dev");
        assertEq(stored[2].url, "https://2.dev");
    }

    function test_UpdateProfile_FillGap() public {
        _root(alice, "Alice");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _numberedLinks(3));
        vm.prank(alice);
        profileSystem.updateProfile(profileId, _noFields(), _link(1, "", ""));

        vm.prank(alice);
        profileSystem.updateProfile(profileId, _noFields(), _link(1, "Blog", "https://alice.blog"));

        DataTypes.ProfileLink[] memory stored = _storedLinks(profileId);
        assertEq(stored.length, 3);
        assertEq(stored[1].label, "Blog");
        assertEq(stored[1].url, "https://alice.blog");
    }

    function test_UpdateProfile_FillGapAndAppend() public {
        _root(alice, "Alice");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _numberedLinks(3));
        vm.prank(alice);
        profileSystem.updateProfile(profileId, _noFields(), _link(1, "", ""));

        // What the frontend sends when two links are added to [L0, gap, L2]
        DataTypes.LinkUpdate[] memory links = new DataTypes.LinkUpdate[](2);
        links[0] = DataTypes.LinkUpdate(1, "D", "https://d.dev");
        links[1] = DataTypes.LinkUpdate(3, "E", "https://e.dev");
        vm.prank(alice);
        profileSystem.updateProfile(profileId, _noFields(), links);

        DataTypes.ProfileLink[] memory stored = _storedLinks(profileId);
        assertEq(stored.length, 4);
        assertEq(stored[1].label, "D");
        assertEq(stored[2].url, "https://2.dev");
        assertEq(stored[3].label, "E");
    }

    function test_UpdateProfile_ClearTailTrimsTrailingGaps() public {
        _root(alice, "Alice");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _numberedLinks(3));

        // Index 1 becomes a gap, then clearing index 2 drops both
        vm.prank(alice);
        profileSystem.updateProfile(profileId, _noFields(), _link(1, "", ""));
        vm.prank(alice);
        profileSystem.updateProfile(profileId, _noFields(), _link(2, "", ""));

        (DataTypes.ProfileLink[] memory stored, uint256 total) = profileSystem.getLinks(profileId, 0, 10);
        assertEq(total, 1);
        assertEq(stored.length, 1);
        assertEq(stored[0].url, "https://0.dev");
    }

    function test_RevertIf_UpdateProfile_NotOwner() public {
        uint256 profileId = _profile(alice, "alice");

        vm.prank(bob);
        vm.expectRevert(Errors.NotProfileOwner.selector);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.NAME, "Mallory"), _noLinks());
    }

    function test_RevertIf_UpdateProfile_EmptyName() public {
        uint256 profileId = _profile(alice, "alice");

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileNameRequired.selector);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.NAME, ""), _noLinks());
    }

    function test_RevertIf_UpdateProfile_LinkIndexPastEnd() public {
        uint256 profileId = _profile(alice, "alice");

        // Appends must land exactly at the end of the list
        vm.prank(alice);
        vm.expectRevert(Errors.InvalidLinkIndex.selector);
        profileSystem.updateProfile(profileId, _noFields(), _link(1, "Blog", "https://alice.blog"));
    }

    function test_RevertIf_UpdateProfile_AppendEmptyLink() public {
        uint256 profileId = _profile(alice, "alice");

        vm.prank(alice);
        vm.expectRevert(Errors.InvalidLinkIndex.selector);
        profileSystem.updateProfile(profileId, _noFields(), _link(0, "Blog", ""));
    }

    function test_RevertIf_UpdateProfile_AppendsOutOfOrder() public {
        _root(alice, "Alice");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _numberedLinks(3));

        // Appends must arrive in ascending order: index 4 comes before 3 exists
        DataTypes.LinkUpdate[] memory links = new DataTypes.LinkUpdate[](2);
        links[0] = DataTypes.LinkUpdate(4, "E", "https://e.dev");
        links[1] = DataTypes.LinkUpdate(3, "D", "https://d.dev");
        vm.prank(alice);
        vm.expectRevert(Errors.InvalidLinkIndex.selector);
        profileSystem.updateProfile(profileId, _noFields(), links);
    }

    function test_RevertIf_UpdateProfile_NoProfile() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        // A SUB token the caller owns is not a profile
        vm.prank(alice);
        vm.expectRevert(Errors.ProfileNotFound.selector);
        profileSystem.updateProfile(subId, _field(DataTypes.ProfileField.NAME, "Alice"), _noLinks());

        // Neither is a token id that was never minted
        vm.prank(alice);
        vm.expectRevert(Errors.ProfileNotFound.selector);
        profileSystem.updateProfile(999, _field(DataTypes.ProfileField.NAME, "Alice"), _noLinks());
    }

    function test_RevertIf_UpdateProfile_Burned() public {
        uint256 profileId = _profile(alice, "alice");
        vm.prank(alice);
        identitySystem.burnToken(profileId);

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileNotFound.selector);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.NAME, "Alice"), _noLinks());
    }

    /// @dev Same ABI shape as DataTypes.FieldUpdate, but lets the test send an out-of-range enum value.
    struct RawFieldUpdate {
        uint8 field;
        string value;
    }

    function test_RevertIf_UpdateProfile_InvalidField() public {
        uint256 profileId = _profile(alice, "alice");
        RawFieldUpdate[] memory fields = new RawFieldUpdate[](1);
        fields[0] = RawFieldUpdate(9, "username-takeover"); // one past ProfileField.AVATAR

        vm.prank(alice);
        (bool ok, ) = address(profileSystem).call(
            abi.encodeWithSelector(ProfileSystem.updateProfile.selector, profileId, fields, _noLinks())
        );

        assertFalse(ok);
        assertEq(profileSystem.getProfile(profileId).username, "alice");
    }

    function test_GetLinks_Pagination() public {
        _root(alice, "Alice");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _numberedLinks(5));

        (DataTypes.ProfileLink[] memory page, uint256 total) = profileSystem.getLinks(profileId, 1, 2);
        assertEq(total, 5);
        assertEq(page.length, 2);
        assertEq(page[0].label, "L1");
        assertEq(page[1].label, "L2");

        // The last page is cut at the end of the list
        (page, ) = profileSystem.getLinks(profileId, 4, 10);
        assertEq(page.length, 1);
        assertEq(page[0].label, "L4");

        // A huge limit must not overflow
        (page, ) = profileSystem.getLinks(profileId, 2, type(uint256).max);
        assertEq(page.length, 3);

        (page, total) = profileSystem.getLinks(profileId, 5, 1);
        assertEq(page.length, 0);
        assertEq(total, 5);

        (page, ) = profileSystem.getLinks(profileId, 0, 0);
        assertEq(page.length, 0);
    }

    function test_GetLinks_UnknownProfile() public view {
        (DataTypes.ProfileLink[] memory page, uint256 total) = profileSystem.getLinks(12345, 0, 10);

        assertEq(page.length, 0);
        assertEq(total, 0);
    }
}
