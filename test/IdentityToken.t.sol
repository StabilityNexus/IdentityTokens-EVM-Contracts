// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IdentityToken } from "../src/IdentityToken.sol";
import { Errors } from "../src/libraries/Errors.sol";
import { Events } from "../src/libraries/Events.sol";

contract IdentityTokenTest is Test {
    IdentityToken public identityToken;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    function setUp() public {
        identityToken = new IdentityToken();
    }

    /*//////////////////////////////////////////////////////////////
                            MINT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Mint() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        assertEq(tokenId, 1);
        assertEq(identityToken.ownerOf(1), alice);
        assertEq(identityToken.balanceOf(alice), 1);
    }

    /*//////////////////////////////////////////////////////////////
                        ATTRIBUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "name", bytes("Alice Nakamoto"));

        bytes32 keyHash = keccak256(abi.encodePacked("name"));
        bytes memory retrievedValue = identityToken.attributes(tokenId, keyHash);

        assertEq(string(retrievedValue), "Alice Nakamoto");
    }

    function test_RevertIf_NotOwnerSetsAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(bob);
        vm.expectRevert(Errors.NotTokenOwner.selector);
        identityToken.setAttribute(tokenId, "name", bytes("Hacker Bob"));
    }

    /*//////////////////////////////////////////////////////////////
                        ENDORSEMENT TESTS
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                    REVOKE ENDORSEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevokeEndorsement_Success() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        bytes32 connectionType = keccak256(abi.encodePacked("Colleague"));

        vm.prank(alice);
        identityToken.endorse(aliceId, bobId, connectionType, 0);

        vm.expectEmit(true, true, true, true);
        emit Events.EndorsementRevoked(aliceId, bobId, 0);

        vm.prank(alice);
        identityToken.revokeEndorsement(aliceId, bobId, 0);

        (,,,, uint256 revokedAt) = identityToken.endorsements(bobId, 0);

        assertGt(revokedAt, 0);
    }

    function test_RevertIf_NotEndorserRevokes() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        bytes32 connectionType = keccak256(abi.encodePacked("Colleague"));

        vm.prank(alice);
        identityToken.endorse(aliceId, bobId, connectionType, 0);

        vm.prank(bob);
        vm.expectRevert(Errors.NotEndorser.selector);
        identityToken.revokeEndorsement(bobId, bobId, 0);
    }

    function test_RevertIf_NotTokenOwnerRevokes() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        bytes32 connectionType = keccak256(abi.encodePacked("Colleague"));

        vm.prank(alice);
        identityToken.endorse(aliceId, bobId, connectionType, 0);

        vm.prank(charlie);
        vm.expectRevert(Errors.NotTokenOwner.selector);
        identityToken.revokeEndorsement(aliceId, bobId, 0);
    }

    function test_RevertIf_AlreadyRevoked() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        bytes32 connectionType = keccak256(abi.encodePacked("Colleague"));

        vm.prank(alice);
        identityToken.endorse(aliceId, bobId, connectionType, 0);

        vm.prank(alice);
        identityToken.revokeEndorsement(aliceId, bobId, 0);

        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyRevoked.selector);
        identityToken.revokeEndorsement(aliceId, bobId, 0);
    }

    function test_RevertIf_InvalidIndex() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        vm.prank(alice);
        vm.expectRevert(Errors.IndexOutOfBounds.selector);
        identityToken.revokeEndorsement(aliceId, bobId, 99);
    }

    /*//////////////////////////////////////////////////////////////
                        ATTRIBUTE DELETION
    //////////////////////////////////////////////////////////////*/

    function test_DeleteAttribute_Success() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "name", bytes("Alice"));

        vm.expectEmit(true, true, true, true);
        emit Events.AttributeDeleted(
            tokenId,
            keccak256(abi.encodePacked("name"))
        );

        vm.prank(alice);
        identityToken.deleteAttribute(tokenId, "name");

        bytes32 keyHash = keccak256(abi.encodePacked("name"));
        bytes memory value = identityToken.attributes(tokenId, keyHash);

        assertEq(value.length, 0);
    }

    function test_RevertIf_NotOwnerDeletesAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setAttribute(tokenId, "name", bytes("Alice"));

        vm.prank(bob);
        vm.expectRevert(Errors.NotTokenOwner.selector);
        identityToken.deleteAttribute(tokenId, "name");
    }

    function test_DeleteAttribute_NonExistentKey() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.deleteAttribute(tokenId, "nonexistent");

        bytes32 keyHash = keccak256(abi.encodePacked("nonexistent"));
        bytes memory value = identityToken.attributes(tokenId, keyHash);

        assertEq(value.length, 0);
    }
}