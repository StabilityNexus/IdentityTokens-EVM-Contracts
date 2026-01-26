// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MiniDIT.sol";

contract MiniDITTest is Test {
    MiniDIT dit;
    address alice = address(1);
    address bob   = address(2);

    function setUp() public {
        dit = new MiniDIT();
    }

    function testMintIdentity() public {
        vm.prank(alice);
        dit.mintIdentity("ipfs://alice");
        assertEq(dit.ownerOf(0), alice);
    }

    function testEndorsementFlow() public {
        vm.prank(alice);
        dit.mintIdentity("ipfs://alice");

        vm.prank(bob);
        dit.mintIdentity("ipfs://bob");

        vm.prank(alice);
        dit.endorse(0, 1, "worked-with");

        (uint256 fromToken,, bool revoked) = dit.endorsements(1,0);
        assertEq(fromToken, 0);
        assertFalse(revoked);
    }

    function testRevokeEndorsement() public {
        vm.prank(alice);
        dit.mintIdentity("ipfs://alice");

        vm.prank(bob);
        dit.mintIdentity("ipfs://bob");

        vm.prank(alice);
        dit.endorse(0, 1, "worked-with");

        vm.prank(alice);
        dit.revokeEndorsement(1,0);

        (, , bool revoked) = dit.endorsements(1,0);
        assertTrue(revoked);
    }

    function testMarkCompromised() public {
        vm.prank(alice);
        dit.mintIdentity("ipfs://alice");

        vm.prank(alice);
        dit.markCompromised(0);

        (, bool compromised) = dit.identities(0);
        assertTrue(compromised);
    }

    function testTransferIdentity() public {
        vm.prank(alice);
        dit.mintIdentity("ipfs://alice");

        vm.prank(alice);
        dit.transferFrom(alice, bob, 0);

        assertEq(dit.ownerOf(0), bob);
    }
}
