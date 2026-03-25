// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IdentityToken } from "../src/IdentityToken.sol";
import { DataTypes } from "../src/libraries/DataTypes.sol";
import { Errors } from "../src/libraries/Errors.sol";
import { Events } from "../src/libraries/Events.sol";
import { StdStorage, stdStorage } from "forge-std/Test.sol";
import { Schema } from "../src/libraries/Schema.sol";

contract IdentityTokenTest is Test {
    using stdStorage for StdStorage;
    IdentityToken public identityToken;
    address public alice = address(0x1);
    address public bob = address(0x2);

    function setUp() public {
        identityToken = new IdentityToken();
    }

    // -------------------------------------------------------------------------
    // Mint
    // -------------------------------------------------------------------------

    function test_Mint() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        assertEq(tokenId, 1);
        assertEq(identityToken.ownerOf(1), alice);
        assertEq(identityToken.balanceOf(alice), 1);
    }

    // -------------------------------------------------------------------------
    // setAttribute / getAttribute
    // -------------------------------------------------------------------------

    function test_SetAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "name", bytes("Alice Nakamoto"));

        bytes32 keyHash = keccak256(abi.encodePacked("name"));
        bytes memory retrievedValue = identityToken.attributes(tokenId, keyHash);

        assertEq(string(retrievedValue), "Alice Nakamoto");
    }

    function test_GetAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "name", bytes("Alice Nakamoto"));

        assertEq(string(identityToken.getAttribute(tokenId, "name")), "Alice Nakamoto");
    }

    function test_GetAttribute_MatchesRawMapping() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "github", bytes("https://github.com/alice"));

        assertEq(
            string(identityToken.getAttribute(tokenId, "github")),
            string(identityToken.attributes(tokenId, Schema.GITHUB))
        );
    }

    function test_SetAttribute_SocialLinks() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "github", bytes("https://github.com/alice"));
        vm.prank(alice);
        identityToken.setAttribute(tokenId, "linkedin", bytes("https://linkedin.com/in/alice"));
        vm.prank(alice);
        identityToken.setAttribute(tokenId, "twitter", bytes("https://twitter.com/alice"));

        assertEq(string(identityToken.getAttribute(tokenId, "github")), "https://github.com/alice");
        assertEq(string(identityToken.getAttribute(tokenId, "linkedin")), "https://linkedin.com/in/alice");
        assertEq(string(identityToken.getAttribute(tokenId, "twitter")), "https://twitter.com/alice");
    }

    function test_OverwriteAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "name", bytes("Alice"));
        vm.prank(alice);
        identityToken.setAttribute(tokenId, "name", bytes("Alice Nakamoto"));

        assertEq(string(identityToken.getAttribute(tokenId, "name")), "Alice Nakamoto");
    }

    function test_SetAttribute_EmptyValue() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "name", bytes(""));

        assertEq(identityToken.getAttribute(tokenId, "name").length, 0);
    }

    function test_SetAttribute_LongURL() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        string memory url = "https://www.linkedin.com/in/alice-nakamoto-very-long-profile-url-example-1234567890";
        vm.prank(alice);
        identityToken.setAttribute(tokenId, "linkedin", bytes(url));

        assertEq(string(identityToken.getAttribute(tokenId, "linkedin")), url);
    }

    // -------------------------------------------------------------------------
    // Typed helper setters
    // -------------------------------------------------------------------------

    function test_SetName() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setName(tokenId, "Alice Nakamoto");

        assertEq(string(identityToken.attributes(tokenId, Schema.NAME)), "Alice Nakamoto");
    }

    function test_SetGithub() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setGithub(tokenId, "https://github.com/alice");

        assertEq(string(identityToken.attributes(tokenId, Schema.GITHUB)), "https://github.com/alice");
    }

    // -------------------------------------------------------------------------
    // Batch setter
    // -------------------------------------------------------------------------

    function test_SetAttributesBatch() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        string[] memory keys = new string[](4);
        keys[0] = "name";
        keys[1] = "github";
        keys[2] = "nationality";
        keys[3] = "residence";

        bytes[] memory values = new bytes[](4);
        values[0] = bytes("Alice Nakamoto");
        values[1] = bytes("https://github.com/alice");
        values[2] = bytes("Japanese");
        values[3] = bytes("Tokyo");

        vm.prank(alice);
        identityToken.setAttributesBatch(tokenId, keys, values);

        assertEq(string(identityToken.getAttribute(tokenId, "name")), "Alice Nakamoto");
        assertEq(string(identityToken.getAttribute(tokenId, "github")), "https://github.com/alice");
        assertEq(string(identityToken.getAttribute(tokenId, "nationality")), "Japanese");
        assertEq(string(identityToken.getAttribute(tokenId, "residence")), "Tokyo");
    }

    function test_SetAttributesBatch_SingleEntry() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        string[] memory keys = new string[](1);
        keys[0] = "age";

        bytes[] memory values = new bytes[](1);
        values[0] = bytes("30");

        vm.prank(alice);
        identityToken.setAttributesBatch(tokenId, keys, values);

        assertEq(string(identityToken.getAttribute(tokenId, "age")), "30");
    }

    // -------------------------------------------------------------------------
    // Access control
    // -------------------------------------------------------------------------

    function test_RevertIf_NotOwnerSetsAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(bob);
        vm.expectRevert(Errors.NotTokenOwner.selector);
        identityToken.setAttribute(tokenId, "name", bytes("Hacker Bob"));
    }

    function test_RevertIf_NotOwnerBatchSetsAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        string[] memory keys = new string[](1);
        keys[0] = "name";
        bytes[] memory values = new bytes[](1);
        values[0] = bytes("Hacker Bob");

        vm.prank(bob);
        vm.expectRevert(Errors.NotTokenOwner.selector);
        identityToken.setAttributesBatch(tokenId, keys, values);
    }

    function test_RevertIf_NotOwnerUsesSetName() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(bob);
        vm.expectRevert(Errors.NotTokenOwner.selector);
        identityToken.setName(tokenId, "Hacker Bob");
    }

    function test_RevertIf_BatchLengthMismatch() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        string[] memory keys = new string[](2);
        keys[0] = "name";
        keys[1] = "github";
        bytes[] memory values = new bytes[](1);
        values[0] = bytes("Alice Nakamoto");

        vm.prank(alice);
        vm.expectRevert(Errors.ArrayLengthMismatch.selector);
        identityToken.setAttributesBatch(tokenId, keys, values);
    }

    // -------------------------------------------------------------------------
    // Schema constants
    // -------------------------------------------------------------------------

    function test_SchemaConstants() public pure {
        assertEq(Schema.NAME, keccak256(abi.encodePacked("name")));
        assertEq(Schema.AGE, keccak256(abi.encodePacked("age")));
        assertEq(Schema.NATIONALITY, keccak256(abi.encodePacked("nationality")));
        assertEq(Schema.RESIDENCE, keccak256(abi.encodePacked("residence")));
        assertEq(Schema.GITHUB, keccak256(abi.encodePacked("github")));
        assertEq(Schema.LINKEDIN, keccak256(abi.encodePacked("linkedin")));
        assertEq(Schema.TWITTER, keccak256(abi.encodePacked("twitter")));
        assertEq(Schema.PHONE, keccak256(abi.encodePacked("phone")));
        assertEq(Schema.EMAIL, keccak256(abi.encodePacked("email")));
    }

    // -------------------------------------------------------------------------
    // Endorsement (unchanged)
    // -------------------------------------------------------------------------

    function test_Endorse() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        bytes32 connectionType = keccak256(abi.encodePacked("Colleague"));
        uint256 validUntil = block.timestamp + 365 days;

        vm.prank(alice);
        identityToken.endorse(aliceId, bobId, connectionType, validUntil);

        (
            uint256 endorserTokenId,
            bytes32 storedConnectionType,
            ,
            uint256 storedValidUntil,
            uint256 revokedAt
        ) = identityToken.endorsements(bobId, 0);

        assertEq(endorserTokenId, aliceId);
        assertEq(storedConnectionType, connectionType);
        assertEq(storedValidUntil, validUntil);
        assertEq(revokedAt, 0);
    }

    // --- deleteAttribute ---

    function test_DeleteAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "email", bytes("alice@example.com"));

        vm.prank(alice);
        identityToken.deleteAttribute(tokenId, "email");

        bytes32 keyHash = keccak256(abi.encodePacked("email"));
        bytes memory value = identityToken.attributes(tokenId, keyHash);

        assertEq(value.length, 0);
    }

    function test_DeleteAttribute_EmitsEvent() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "email", bytes("alice@example.com"));

        bytes32 keyHash = keccak256(abi.encodePacked("email"));

        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit Events.AttributeDeleted(tokenId, keyHash);
        identityToken.deleteAttribute(tokenId, "email");
    }

    function test_RevertIf_NotOwnerDeletesAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "email", bytes("alice@example.com"));

        vm.prank(bob);
        vm.expectRevert(Errors.NotTokenOwner.selector);
        identityToken.deleteAttribute(tokenId, "email");
    }

    function test_DeleteAttribute_NeverSet_DoesNotRevert() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.deleteAttribute(tokenId, "nonexistent");

        bytes32 keyHash = keccak256(abi.encodePacked("nonexistent"));
        bytes memory value = identityToken.attributes(tokenId, keyHash);

        assertEq(value.length, 0);
    }

    function test_DeleteAttribute_Twice_DoesNotRevert() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "email", bytes("alice@example.com"));

        vm.prank(alice);
        identityToken.deleteAttribute(tokenId, "email");

        vm.prank(alice);
        identityToken.deleteAttribute(tokenId, "email");
    }

    function test_DeleteAttribute_ThenReSet() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "email", bytes("alice@example.com"));

        vm.prank(alice);
        identityToken.deleteAttribute(tokenId, "email");

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "email", bytes("new@example.com"));

        bytes32 keyHash = keccak256(abi.encodePacked("email"));
        bytes memory value = identityToken.attributes(tokenId, keyHash);

        assertEq(string(value), "new@example.com");
    }

    function test_RevertIf_CompromisedIdentityDeletesAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        // Use stdStorage to set isCompromised without hardcoding a slot
        stdstore.target(address(identityToken)).sig("identityStates(uint256)").with_key(tokenId).depth(0).checked_write(
            true
        ); // isCompromised is the first field in IdentityState

        vm.prank(alice);
        vm.expectRevert(Errors.IdentityCompromised.selector);
        identityToken.deleteAttribute(tokenId, "email");
    }
    // --- hasIdentity ---

    function test_HasIdentity_True() public {
        vm.prank(alice);
        identityToken.mint();
        assertTrue(identityToken.hasIdentity(alice));
    }

    function test_HasIdentity_False() public view {
        assertFalse(identityToken.hasIdentity(alice));
    }

    // --- getIdentity ---

    function test_GetIdentity_ReturnsCorrectFields() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        DataTypes.Identity memory identity = identityToken.getIdentity(tokenId);

        assertEq(identity.tokenId, tokenId);
        assertEq(identity.owner, alice);
        assertFalse(identity.isCompromised);
        assertEq(identity.validUntil, 0);
        assertEq(identity.endorsementCount, 0);
    }

    function test_GetIdentity_EndorsementCountUpdates() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        bytes32 connectionType = keccak256(abi.encodePacked("Colleague"));
        vm.prank(alice);
        identityToken.endorse(aliceId, bobId, connectionType, 0);

        DataTypes.Identity memory identity = identityToken.getIdentity(bobId);
        assertEq(identity.endorsementCount, 1);
    }

    function test_GetIdentity_RevertsForNonexistentToken() public {
        vm.expectRevert();
        identityToken.getIdentity(999);
    }

    // --- getIdentityByOwner ---

    function test_GetIdentityByOwner_ReturnsTokenId() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        uint256[] memory result = identityToken.getIdentityByOwner(alice);

        assertEq(result.length, 1);
        assertEq(result[0], tokenId);
    }

    function test_GetIdentityByOwner_ReturnsEmptyIfNoToken() public view {
        uint256[] memory result = identityToken.getIdentityByOwner(alice);
        assertEq(result.length, 0);
    }

    // --- isVerified ---

    function test_IsVerified_FalseWithNoEndorsements() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();
        assertFalse(identityToken.isVerified(tokenId));
    }

    function test_IsVerified_TrueWithActiveEndorsement() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        bytes32 connectionType = keccak256(abi.encodePacked("Colleague"));
        vm.prank(alice);
        identityToken.endorse(aliceId, bobId, connectionType, 0);

        assertTrue(identityToken.isVerified(bobId));
    }

    function test_IsVerified_FalseWithExpiredEndorsement() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        bytes32 connectionType = keccak256(abi.encodePacked("Colleague"));
        uint256 validUntil = block.timestamp + 1 days;

        vm.prank(alice);
        identityToken.endorse(aliceId, bobId, connectionType, validUntil);

        vm.warp(block.timestamp + 2 days);

        assertFalse(identityToken.isVerified(bobId));
    }

    // --- isExpired ---

    function test_IsExpired_FalseWhenNoValidUntil() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();
        assertFalse(identityToken.isExpired(tokenId));
    }

    function test_IsExpired_FalseBeforeExpiry() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        stdstore.target(address(identityToken)).sig("identityStates(uint256)").with_key(tokenId).depth(4).checked_write(
            block.timestamp + 1 days
        );

        assertFalse(identityToken.isExpired(tokenId));
    }

    function test_IsExpired_TrueAfterExpiry() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        uint256 expiry = block.timestamp + 1 days;

        stdstore.target(address(identityToken)).sig("identityStates(uint256)").with_key(tokenId).depth(4).checked_write(
            expiry
        );

        vm.warp(expiry + 1);

        assertTrue(identityToken.isExpired(tokenId));
    }

    // -------------------------------------------------------------------------
    // MAX_ENDORSEMENTS (DoS prevention)
    // -------------------------------------------------------------------------

    /// @notice The 50th endorsement (at the limit) must succeed.
    function test_Endorse_AtMaxLimit() public {
        // Target identity that will receive all endorsements
        vm.prank(alice);
        uint256 targetId = identityToken.mint();

        bytes32 connectionType = keccak256(abi.encodePacked("Colleague"));
        uint256 maxEndorsements = identityToken.MAX_ENDORSEMENTS(); // 50

        // Mint 50 unique endorsers and have each endorse the target
        for (uint256 i = 0; i < maxEndorsements; i++) {
            address endorser = address(uint160(1000 + i));
            vm.prank(endorser);
            uint256 endorserId = identityToken.mint();

            vm.prank(endorser);
            identityToken.endorse(endorserId, targetId, connectionType, 0);
        }

        // Verify the target has exactly MAX_ENDORSEMENTS endorsements
        DataTypes.Identity memory identity = identityToken.getIdentity(targetId);
        assertEq(identity.endorsementCount, maxEndorsements);

        // Verify the target is considered verified
        assertTrue(identityToken.isVerified(targetId));
    }

    /// @notice The 51st endorsement must revert with MaxEndorsementsReached.
    function test_RevertIf_MaxEndorsementsReached() public {
        // Target identity that will receive all endorsements
        vm.prank(alice);
        uint256 targetId = identityToken.mint();

        bytes32 connectionType = keccak256(abi.encodePacked("Colleague"));
        uint256 maxEndorsements = identityToken.MAX_ENDORSEMENTS(); // 50

        // Fill up to the maximum
        for (uint256 i = 0; i < maxEndorsements; i++) {
            address endorser = address(uint160(2000 + i));
            vm.prank(endorser);
            uint256 endorserId = identityToken.mint();

            vm.prank(endorser);
            identityToken.endorse(endorserId, targetId, connectionType, 0);
        }

        // The 51st endorsement must revert
        address extraEndorser = address(uint160(9999));
        vm.prank(extraEndorser);
        uint256 extraId = identityToken.mint();

        vm.prank(extraEndorser);
        vm.expectRevert(Errors.MaxEndorsementsReached.selector);
        identityToken.endorse(extraId, targetId, connectionType, 0);
    }

    /// @notice MAX_ENDORSEMENTS constant is exposed and equals 50.
    function test_MAX_ENDORSEMENTS_Constant() public view {
        assertEq(identityToken.MAX_ENDORSEMENTS(), 50);
    }
}
