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

        // Verify cached counter
        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);

        // Verify dynamic count
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

    function test_AttestToken_CustomDuration_60Days() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 60 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations[0].expiresAt, block.timestamp + 60 days);
    }

    function test_ProfileAttestation() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _noLinks());

        // Bob can attest Alice's profile token
        vm.prank(bob);
        identitySystem.attestToken(profileId, 365 days);

        assertEq(identitySystem.getActiveAttestationCount(profileId), 1);
        assertTrue(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), profileId));
    }

    function test_AttestationClamped_ToTokenValidity() public {
        _root(alice, "Alice");
        _root(bob, "Bob");

        // Token valid for 2 years
        vm.prank(alice);
        uint256 subId = identitySystem.createToken(
            "Education",
            "credential",
            bytes(""),
            "",
            block.timestamp + 2 * 365 days
        );

        // Bob attests for 5 years — should be clamped to 2 years (token validity)
        vm.prank(bob);
        identitySystem.attestToken(subId, 5 * 365 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations[0].expiresAt, block.timestamp + 2 * 365 days);
    }

    function test_AttestationClamped_TokenExpiresTooSoon() public {
        _root(alice, "Alice");
        _root(bob, "Bob");

        // Token valid for only 5 days — less than MIN_ATTESTATION_DURATION
        vm.prank(alice);
        uint256 subId = identitySystem.createToken("Temp", "credential", bytes(""), "", block.timestamp + 5 days);

        // Bob tries to attest for 30 days — clamping will silently set to 5 days
        vm.prank(bob);
        identitySystem.attestToken(subId, 30 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations[0].expiresAt, block.timestamp + 5 days);
    }

    function test_AttestationExpires_AfterValidity() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        // Still active before expiry
        assertTrue(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);

        // Warp past the 1-year validity
        vm.warp(block.timestamp + 366 days);

        // Attestation has expired — lazy evaluation
        assertFalse(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));
        assertEq(identitySystem.getActiveAttestationCount(subId), 0);

        DataTypes.Attestation[] memory active = identitySystem.getActiveAttestations(subId);
        assertEq(active.length, 0);
    }

    function test_ReAttest_AfterExpiry() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        // Bob attests with 1-year validity
        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        // Warp past expiry
        vm.warp(block.timestamp + 366 days);

        // Bob can re-attest after expiry
        vm.prank(bob);
        identitySystem.attestToken(subId, 3 * 365 days);

        assertTrue(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);

        // totalAttestationCount should still be 1 (same attester, not inflated)
        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);
    }

    function test_ReAttest_AfterRevocation() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();
        uint256 subId = _token(alice);

        // Bob attests
        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        // Bob revokes
        vm.prank(bob);
        identitySystem.revokeAttestation(subId);

        // Bob can re-attest after revoking
        vm.prank(bob);
        identitySystem.attestToken(subId, 3 * 365 days);

        assertTrue(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));

        // totalAttestationCount should still be 1 (re-attestation doesn't inflate)
        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);
    }

    function test_AttestRevokeLoop_DoesNotInflateTotalCount() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();
        uint256 subId = _token(alice);

        // Bob does 5 attest-revoke cycles
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(bob);
            identitySystem.attestToken(subId, 365 days);

            vm.prank(bob);
            identitySystem.revokeAttestation(subId);
        }

        // totalAttestationCount should be 1, not 5 (only counted once per attester)
        (, , , , , , , , uint256 totalCount, uint256 revokedCount, , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);
        // revokedCount should ALSO be 1, not 5 (only counted once per attester)
        assertEq(revokedCount, 1);

        // But auto-flag should NOT trigger: totalAttestationCount=1 < MIN_ATTESTATIONS_FOR_AUTO_FLAG=20
        (, , , , , , , , , , bool isFlagged, , ) = identitySystem.tokens(subId);
        assertFalse(isFlagged);
    }

    function test_CachedCounters_TrackAttestationsAccurately() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _root(charlie, "Charlie");
        _ageRoots();
        uint256 subId = _token(alice);

        // Bob attests
        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        (, , , , , , , , uint256 totalCount, uint256 revokedCount, , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);
        assertEq(revokedCount, 0);
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);

        // Charlie attests
        vm.prank(charlie);
        identitySystem.attestToken(subId, 3 * 365 days);

        (, , , , , , , , totalCount, revokedCount, , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 2);
        assertEq(revokedCount, 0);
        assertEq(identitySystem.getActiveAttestationCount(subId), 2);

        // Bob revokes
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

    function test_BurnedTokenCannotBeAttested() public {
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

        // Verify cached counters updated
        (, , , , , , , , , uint256 revokedCount, , , ) = identitySystem.tokens(subId);
        assertEq(revokedCount, 1);

        // Verify dynamic count
        assertEq(identitySystem.getActiveAttestationCount(subId), 0);
    }

    function test_RevertIf_RevokeAttestation_NoActiveAttestation() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        // Bob has not attested — revoke should fail
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

        // Charlie never attested — trying to revoke should fail
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

        // Warp past expiry
        vm.warp(block.timestamp + 366 days);

        // Can't revoke an already-expired attestation
        vm.prank(bob);
        vm.expectRevert(Errors.AttestationExpired.selector);
        identitySystem.revokeAttestation(subId);
    }

    function test_RevertIf_RevokeAttestation_BurnedToken() public {
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
