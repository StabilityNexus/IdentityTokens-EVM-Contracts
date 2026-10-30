// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "../utils/BaseTest.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { Errors } from "../../src/libraries/Errors.sol";

contract AttestationTest is BaseTest {
    function test_AttestToken() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations.length, 1);
        assertEq(attestations[0].attesterTokenId, identitySystem.ownerToRootId(bob));
        assertEq(attestations[0].expiresAt, block.timestamp + 365 days);

        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);
    }

    function test_AttestToken_3YearDuration() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 3 * 365 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations[0].expiresAt, block.timestamp + 3 * 365 days);
    }

    function test_AttestToken_60DayDuration() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 60 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations[0].expiresAt, block.timestamp + 60 days);
    }

    function test_AttestToken_Profile() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _noLinks());

        vm.prank(bob);
        identitySystem.attestToken(profileId, 365 days);

        assertEq(identitySystem.getActiveAttestationCount(profileId), 1);
        assertTrue(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), profileId));
    }

    function test_AttestToken_ClampedToTokenValidity() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        vm.prank(alice);
        uint256 subId = identitySystem.createToken(
            "Education",
            "credential",
            bytes(""),
            "",
            block.timestamp + 2 * 365 days
        );

        // Asks for 5 years, gets the token's 2
        vm.prank(bob);
        identitySystem.attestToken(subId, 5 * 365 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations[0].expiresAt, block.timestamp + 2 * 365 days);
    }

    function test_AttestToken_ClampedToShortValidity() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        vm.prank(alice);
        uint256 subId = identitySystem.createToken("Temp", "credential", bytes(""), "", block.timestamp + 5 days);

        // Asks for 30 days, gets the token's 5
        vm.prank(bob);
        identitySystem.attestToken(subId, 30 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations[0].expiresAt, block.timestamp + 5 days);
    }

    function test_AttestToken_ExpiresAfterDuration() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        assertTrue(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);

        // Expiry is checked lazily, so no transaction is needed
        vm.warp(block.timestamp + 366 days);

        assertFalse(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));
        assertEq(identitySystem.getActiveAttestationCount(subId), 0);

        DataTypes.Attestation[] memory active = identitySystem.getActiveAttestations(subId);
        assertEq(active.length, 0);
    }

    function test_AttestToken_AgainAfterExpiry() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.warp(block.timestamp + 366 days);

        vm.prank(bob);
        identitySystem.attestToken(subId, 3 * 365 days);

        assertTrue(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);

        // Same attester, so the total is not inflated
        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);
    }

    function test_AttestToken_AgainAfterRevoke() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.prank(bob);
        identitySystem.revokeAttestation(subId);

        vm.prank(bob);
        identitySystem.attestToken(subId, 3 * 365 days);

        assertTrue(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));

        // Same attester, so the total is not inflated
        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);
    }

    function test_AttestToken_RevokeLoopCountsOnce() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();
        uint256 subId = _token(alice);

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(bob);
            identitySystem.attestToken(subId, 365 days);

            vm.prank(bob);
            identitySystem.revokeAttestation(subId);
        }

        // One attester counts once, not once per cycle
        (, , , , , , , , uint256 totalCount, uint256 revokedCount, , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);
        assertEq(revokedCount, 1);

        // 1 attestation is below the 20 that auto-flag needs
        (, , , , , , , , , , bool isFlagged, , ) = identitySystem.tokens(subId);
        assertFalse(isFlagged);
    }

    function test_CachedCounters_TrackAttestAndRevoke() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _root(charlie, "Charlie");
        _ageRoots();
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        (, , , , , , , , uint256 totalCount, uint256 revokedCount, , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);
        assertEq(revokedCount, 0);
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);

        vm.prank(charlie);
        identitySystem.attestToken(subId, 3 * 365 days);

        (, , , , , , , , totalCount, revokedCount, , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 2);
        assertEq(revokedCount, 0);
        assertEq(identitySystem.getActiveAttestationCount(subId), 2);

        vm.prank(bob);
        identitySystem.revokeAttestation(subId);

        (, , , , , , , , totalCount, revokedCount, , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 2);
        assertEq(revokedCount, 1);
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);
    }

    function test_RevertIf_AttestToken_NoRoot() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.prank(charlie);
        vm.expectRevert(Errors.NoRootIdentity.selector);
        identitySystem.attestToken(subId, 365 days);
    }

    function test_RevertIf_AttestToken_SelfAttestation() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.prank(alice);
        vm.expectRevert(Errors.CannotAttestOwnToken.selector);
        identitySystem.attestToken(subId, 365 days);
    }

    function test_RevertIf_AttestToken_CreatorWhileParked() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        // Parked on a wallet without a root
        vm.prank(alice);
        identitySystem.transferToken(subId, charlie);

        vm.prank(alice);
        vm.expectRevert(Errors.CannotAttestOwnToken.selector);
        identitySystem.attestToken(subId, 365 days);

        // Parked on a wallet with a root
        vm.prank(charlie);
        identitySystem.transferToken(subId, bob);

        vm.prank(alice);
        vm.expectRevert(Errors.CannotAttestOwnToken.selector);
        identitySystem.attestToken(subId, 365 days);
    }

    function test_RevertIf_AttestToken_AlreadyAttested() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.prank(bob);
        vm.expectRevert(Errors.AlreadyAttested.selector);
        identitySystem.attestToken(subId, 365 days);
    }

    function test_RevertIf_AttestToken_Burned() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        vm.prank(bob);
        vm.expectRevert(Errors.NotToken.selector);
        identitySystem.attestToken(subId, 365 days);
    }

    function test_RevokeAttestation() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.prank(bob);
        identitySystem.revokeAttestation(subId);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertGt(attestations[0].revokedAt, 0);

        (, , , , , , , , , uint256 revokedCount, , , ) = identitySystem.tokens(subId);
        assertEq(revokedCount, 1);
        assertEq(identitySystem.getActiveAttestationCount(subId), 0);
    }

    function test_RevertIf_RevokeAttestation_NoActiveAttestation() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        vm.expectRevert(Errors.NoActiveAttestation.selector);
        identitySystem.revokeAttestation(subId);
    }

    function test_RevertIf_RevokeAttestation_AlreadyRevoked() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.prank(bob);
        identitySystem.revokeAttestation(subId);

        vm.prank(bob);
        vm.expectRevert(Errors.NoActiveAttestation.selector);
        identitySystem.revokeAttestation(subId);
    }

    function test_RevertIf_RevokeAttestation_NonAttester() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _root(charlie, "Charlie");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.prank(charlie);
        vm.expectRevert(Errors.NoActiveAttestation.selector);
        identitySystem.revokeAttestation(subId);
    }

    function test_RevertIf_RevokeAttestation_Expired() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.warp(block.timestamp + 366 days);

        vm.prank(bob);
        vm.expectRevert(Errors.AttestationExpired.selector);
        identitySystem.revokeAttestation(subId);
    }

    function test_RevertIf_RevokeAttestation_Burned() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        vm.prank(bob);
        vm.expectRevert(Errors.NotToken.selector);
        identitySystem.revokeAttestation(subId);
    }
}
