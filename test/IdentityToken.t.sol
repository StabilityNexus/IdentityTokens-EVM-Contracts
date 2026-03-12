// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IdentityToken } from "../src/IdentityToken.sol";
import { DataTypes } from "../src/libraries/DataTypes.sol";
import { Errors } from "../src/libraries/Errors.sol";

contract IdentityTokenTest is Test {
    IdentityToken public identityToken;
    address public alice = address(0x1);
    address public bob = address(0x2);

    function setUp() public {
        identityToken = new IdentityToken();
    }

    function test_Mint() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        assertEq(tokenId, 1);
        assertEq(identityToken.ownerOf(1), alice);
        assertEq(identityToken.balanceOf(alice), 1);
    }

    function test_SetAttribute() public {
        // Alice mints a token
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        // Alice sets her name
        vm.prank(alice);
        identityToken.setAttribute(tokenId, "name", bytes("Alice Nakamoto"));

        bytes32 keyHash = keccak256(abi.encodePacked("name"));
        bytes memory retrievedValue = identityToken.attributes(tokenId, keyHash);

        assertEq(string(retrievedValue), "Alice Nakamoto");
    }

    function test_Endorse() public {
        // Mint tokens for Alice and Bob
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        // Alice endorses Bob as a "Colleague"
        bytes32 connectionType = keccak256(abi.encodePacked("Colleague"));
        uint256 validUntil = block.timestamp + 365 days;

        vm.prank(alice);
        identityToken.endorse(aliceId, bobId, connectionType, validUntil);

        // Fetch the endorsement from Bob's token
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

    function test_RevertIf_NotOwnerSetsAttribute() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(bob);
        vm.expectRevert(Errors.NotTokenOwner.selector);
        identityToken.setAttribute(tokenId, "name", bytes("Hacker Bob"));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // tokenURI tests
    // ──────────────────────────────────────────────────────────────────────────

    function test_SetAndGetTokenURI() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(alice);
        identityToken.setTokenURI(tokenId, "ipfs://QmTest/1");

        assertEq(identityToken.tokenURI(tokenId), "ipfs://QmTest/1");
    }

    function test_RevertIf_NonOwnerSetsTokenURI() public {
        vm.prank(alice);
        uint256 tokenId = identityToken.mint();

        vm.prank(bob);
        vm.expectRevert(Errors.NotTokenOwner.selector);
        identityToken.setTokenURI(tokenId, "ipfs://QmHack/1");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Reverse endorsement index tests
    // ──────────────────────────────────────────────────────────────────────────

    function test_GetEndorsementCount() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        assertEq(identityToken.getEndorsementCount(bobId), 0);
        assertEq(identityToken.getGivenEndorsementCount(aliceId), 0);

        bytes32 connType = keccak256(abi.encodePacked("Colleague"));
        vm.prank(alice);
        identityToken.endorse(aliceId, bobId, connType, 0);

        assertEq(identityToken.getEndorsementCount(bobId), 1);
        assertEq(identityToken.getGivenEndorsementCount(aliceId), 1);
    }

    function test_GetGivenEndorsements() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        bytes32 connType = keccak256(abi.encodePacked("Friend"));
        vm.prank(alice);
        identityToken.endorse(aliceId, bobId, connType, 0);

        DataTypes.GivenEndorsement[] memory given = identityToken.getGivenEndorsements(aliceId, 0, 1);
        assertEq(given.length, 1);
        assertEq(given[0].toTokenId, bobId);
        assertEq(given[0].endorsementIndex, 0);
    }

    function test_ReverseIndexConsistency() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        address carol = address(0x3);
        vm.prank(carol);
        uint256 carolId = identityToken.mint();

        bytes32 typeA = keccak256(abi.encodePacked("Friend"));
        bytes32 typeB = keccak256(abi.encodePacked("Colleague"));

        vm.startPrank(alice);
        identityToken.endorse(aliceId, bobId, typeA, 0);
        identityToken.endorse(aliceId, carolId, typeB, 0);
        vm.stopPrank();

        // alice gave 2 endorsements
        assertEq(identityToken.getGivenEndorsementCount(aliceId), 2);
        // bob and carol each received 1
        assertEq(identityToken.getEndorsementCount(bobId), 1);
        assertEq(identityToken.getEndorsementCount(carolId), 1);

        // verify forward and reverse agree
        DataTypes.GivenEndorsement[] memory given = identityToken.getGivenEndorsements(aliceId, 0, 2);
        (uint256 endorserTokenId, , , , ) = identityToken.endorsements(bobId, given[0].endorsementIndex);
        assertEq(endorserTokenId, aliceId);
    }

    function test_GetEndorsementsPaginated() public {
        vm.prank(alice);
        uint256 aliceId = identityToken.mint();

        vm.prank(bob);
        uint256 bobId = identityToken.mint();

        vm.startPrank(alice);
        for (uint256 i = 0; i < 5; i++) {
            identityToken.endorse(aliceId, bobId, bytes32(uint256(i + 1)), 0);
        }
        vm.stopPrank();

        DataTypes.Endorsement[] memory page = identityToken.getEndorsements(bobId, 0, 3);
        assertEq(page.length, 3);

        // end clamped to array length
        DataTypes.Endorsement[] memory page2 = identityToken.getEndorsements(bobId, 3, 100);
        assertEq(page2.length, 2);
    }
}
