// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IdentitySystem } from "../src/IdentitySystem.sol";
import { ProfileSystem } from "../src/ProfileSystem.sol";
import { DataTypes } from "../src/libraries/DataTypes.sol";
import { Errors } from "../src/libraries/Errors.sol";
import { Events } from "../src/libraries/Events.sol";

contract IdentitySystemTest is Test {
    IdentitySystem public identitySystem;
    ProfileSystem public profileSystem;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    function setUp() public {
        identitySystem = new IdentitySystem();
        profileSystem = new ProfileSystem(address(identitySystem));
        identitySystem.setProfileSystem(address(profileSystem));
    }

    /// @dev Helper: creates `count` fresh root identities (starting at `startAddr`)
    ///      and has each one attest `tokenId` with the given duration.
    function _createAttesters(
        uint256 tokenId,
        uint160 startAddr,
        uint256 count,
        uint256 duration
    ) internal returns (uint160 nextAddr) {
        for (uint256 i = 0; i < count; i++) {
            address attester = address(startAddr + uint160(i));
            vm.prank(attester);
            identitySystem.createRootIdentity("");
            vm.prank(attester);
            identitySystem.attestToken(tokenId, duration);
        }
        return startAddr + uint160(count);
    }

    // =========================================================================
    // Root Identity
    // =========================================================================

    function test_CreateRootIdentity() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("Alice Nakamoto");

        assertEq(rootId, 1);
        assertEq(identitySystem.ownerOf(1), alice);
        assertEq(identitySystem.ownerToRootId(alice), 1);
        assertEq(uint8(identitySystem.tokenTypes(1)), uint8(DataTypes.TokenType.ROOT));
    }

    function test_CreateRootIdentity_WithEmptyDisplayName() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("");

        assertEq(rootId, 1);
    }

    function test_RevertIf_CreateRootIdentity_AlreadyHasRoot() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyHasRoot.selector);
        identitySystem.createRootIdentity("Alice2");
    }

    // =========================================================================
    // Token
    // =========================================================================

    function test_CreateToken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken(
            "GitHub",
            "social",
            bytes("https://github.com/alice"),
            "My GitHub",
            0
        );

        assertEq(subId, 2);
        assertEq(identitySystem.ownerOf(2), alice);
        assertEq(uint8(identitySystem.tokenTypes(2)), uint8(DataTypes.TokenType.SUB));

        uint256[] memory subIds = identitySystem.getTokensForRoot(1);
        assertEq(subIds.length, 1);
        assertEq(subIds[0], 2);
    }

    function test_RevertIf_CreateToken_NoRoot() public {
        vm.prank(alice);
        vm.expectRevert(Errors.NoRootIdentity.selector);
        identitySystem.createToken("GitHub", "social", bytes(""), "", 0);
    }

    // =========================================================================
    // Attestation (time-based validity)
    // =========================================================================

    function test_AttestToken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations.length, 1);
        assertEq(attestations[0].attesterTokenId, 2);
        assertEq(attestations[0].expiresAt, block.timestamp + 365 days);

        // Verify cached counter
        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);

        // Verify dynamic count
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);
    }

    function test_AttestToken_3YearDuration() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(subId, 3 * 365 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations[0].expiresAt, block.timestamp + 3 * 365 days);
    }

    function test_AttestToken_CustomDuration_60Days() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(subId, 60 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations[0].expiresAt, block.timestamp + 60 days);
    }

    function test_RevertIf_AttestToken_NoRoot() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(charlie);
        vm.expectRevert(Errors.NoRootIdentity.selector);
        identitySystem.attestToken(subId, 365 days);
    }

    function test_RevertIf_AttestToken_SelfAttestation() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        vm.expectRevert(Errors.CannotAttestOwnToken.selector);
        identitySystem.attestToken(subId, 365 days);
    }

    function test_RevertIf_AttestToken_AlreadyAttested() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.prank(bob);
        vm.expectRevert(Errors.AlreadyAttested.selector);
        identitySystem.attestToken(subId, 365 days);
    }

    // =========================================================================
    // Attestation clamping to token validity
    // =========================================================================

    function test_AttestationClamped_ToTokenValidity() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

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
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        // Token valid for only 5 days — less than MIN_ATTESTATION_DURATION
        vm.prank(alice);
        uint256 subId = identitySystem.createToken("Temp", "credential", bytes(""), "", block.timestamp + 5 days);

        // Bob tries to attest for 30 days — clamping will silently set to 5 days
        vm.prank(bob);
        identitySystem.attestToken(subId, 30 days);

        DataTypes.Attestation[] memory attestations = identitySystem.getAttestations(subId);
        assertEq(attestations[0].expiresAt, block.timestamp + 5 days);
    }

    // =========================================================================
    // Attestation expiry
    // =========================================================================

    function test_AttestationExpires_AfterValidity() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        // Still active before expiry
        assertTrue(identitySystem.hasAttested(2, subId));
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);

        // Warp past the 1-year validity
        vm.warp(block.timestamp + 366 days);

        // Attestation has expired — lazy evaluation
        assertFalse(identitySystem.hasAttested(2, subId));
        assertEq(identitySystem.getActiveAttestationCount(subId), 0);

        DataTypes.Attestation[] memory active = identitySystem.getActiveAttestations(subId);
        assertEq(active.length, 0);
    }

    function test_ReAttest_AfterExpiry() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        // Bob attests with 1-year validity
        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        // Warp past expiry
        vm.warp(block.timestamp + 366 days);

        // Bob can re-attest after expiry
        vm.prank(bob);
        identitySystem.attestToken(subId, 3 * 365 days);

        assertTrue(identitySystem.hasAttested(2, subId));
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);

        // totalAttestationCount should still be 1 (same attester, not inflated)
        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);
    }

    function test_ReAttest_AfterRevocation() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        // Bob attests
        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        // Bob revokes
        vm.prank(bob);
        identitySystem.revokeAttestation(subId);

        // Bob can re-attest after revoking
        vm.prank(bob);
        identitySystem.attestToken(subId, 3 * 365 days);

        assertTrue(identitySystem.hasAttested(2, subId));

        // totalAttestationCount should still be 1 (re-attestation doesn't inflate)
        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 1);
    }

    // =========================================================================
    // Attest-revoke loop exploit prevention (Bug #2)
    // =========================================================================

    function test_AttestRevokeLoop_DoesNotInflateTotalCount() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

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

    // =========================================================================
    // Revocation (no attestationIndex parameter)
    // =========================================================================

    function test_RevokeAttestation() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

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
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        // Bob has not attested — revoke should fail
        vm.prank(bob);
        vm.expectRevert(Errors.NoActiveAttestation.selector);
        identitySystem.revokeAttestation(subId);
    }

    function test_RevertIf_RevokeAttestation_AlreadyRevoked() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.prank(bob);
        identitySystem.revokeAttestation(subId);

        vm.prank(bob);
        vm.expectRevert(Errors.NoActiveAttestation.selector);
        identitySystem.revokeAttestation(subId);
    }

    function test_RevertIf_RevokeAttestation_NonAttester() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(charlie);
        identitySystem.createRootIdentity("Charlie");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        // Charlie never attested — trying to revoke should fail
        vm.prank(charlie);
        vm.expectRevert(Errors.NoActiveAttestation.selector);
        identitySystem.revokeAttestation(subId);
    }

    function test_RevertIf_RevokeAttestation_Expired() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        // Warp past expiry
        vm.warp(block.timestamp + 366 days);

        // Can't revoke an already-expired attestation
        vm.prank(bob);
        vm.expectRevert(Errors.AttestationExpired.selector);
        identitySystem.revokeAttestation(subId);
    }

    // =========================================================================
    // View functions — attestations
    // =========================================================================

    function test_GetActiveAttestations() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        DataTypes.Attestation[] memory active = identitySystem.getActiveAttestations(subId);
        assertEq(active.length, 1);

        vm.prank(bob);
        identitySystem.revokeAttestation(subId);

        active = identitySystem.getActiveAttestations(subId);
        assertEq(active.length, 0);
    }

    function test_GetActiveAttestationCount() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(charlie);
        identitySystem.createRootIdentity("Charlie");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        // Two attestations
        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);
        vm.prank(charlie);
        identitySystem.attestToken(subId, 3 * 365 days);

        assertEq(identitySystem.getActiveAttestationCount(subId), 2);

        // Bob's 1-year attestation expires
        vm.warp(block.timestamp + 366 days);
        assertEq(identitySystem.getActiveAttestationCount(subId), 1); // only Charlie's 3-year remains

        // Charlie's 3-year attestation expires
        vm.warp(block.timestamp + 3 * 365 days);
        assertEq(identitySystem.getActiveAttestationCount(subId), 0);
    }

    function test_GetAttestationsByAttester() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        uint256[] memory attested = identitySystem.getAttestationsByAttester(2);
        assertEq(attested.length, 1);
        assertEq(attested[0], subId);
    }

    function test_GetAttestationsByAttester_ExcludesExpired() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        // Warp past expiry
        vm.warp(block.timestamp + 366 days);

        uint256[] memory attested = identitySystem.getAttestationsByAttester(2);
        assertEq(attested.length, 0);
    }

    function test_HasAttested() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        assertFalse(identitySystem.hasAttested(2, subId));

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        assertTrue(identitySystem.hasAttested(2, subId));
    }

    // =========================================================================
    // Transfer (controlled) — attestations persist
    // =========================================================================

    function test_TransferToken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        identitySystem.transferToken(subId, bob);

        assertEq(identitySystem.ownerOf(subId), bob);

        address[] memory history = identitySystem.getTransferHistory(subId);
        assertEq(history.length, 2);
        assertEq(history[1], bob);
    }

    function test_TransferToken_PreservesAttestations() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        // Bob attests with 3-year validity
        vm.prank(bob);
        identitySystem.attestToken(subId, 3 * 365 days);

        // Before transfer: 1 active attestation
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);
        assertTrue(identitySystem.hasAttested(2, subId));

        // Transfer — attestations persist (passport model)
        vm.prank(alice);
        identitySystem.transferToken(subId, charlie);

        // After transfer: attestation still active
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);
        assertTrue(identitySystem.hasAttested(2, subId));

        DataTypes.Attestation[] memory active = identitySystem.getActiveAttestations(subId);
        assertEq(active.length, 1);
        assertEq(active[0].attesterTokenId, 2);
    }

    function test_RevertIf_TransferToken_NotHolder() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        vm.expectRevert(Errors.NotHolder.selector);
        identitySystem.transferToken(subId, bob);
    }

    function test_RevertIf_TransferRootToken() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        vm.expectRevert(Errors.CannotTransferRoot.selector);
        identitySystem.transferToken(rootId, bob);
    }

    function test_RevertIf_TransferToken_SelfTransfer() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        vm.expectRevert(Errors.SelfTransfer.selector);
        identitySystem.transferToken(subId, alice);
    }

    function test_RevertIf_TransferToken_ZeroAddress() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        vm.expectRevert(Errors.ZeroAddress.selector);
        identitySystem.transferToken(subId, address(0));
    }

    function test_RevertIf_TransferToken_Expired() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", block.timestamp + 100);

        vm.warp(block.timestamp + 200);

        vm.prank(alice);
        vm.expectRevert(Errors.TokenExpired.selector);
        identitySystem.transferToken(subId, bob);
    }

    // =========================================================================
    // Burn Token
    // =========================================================================

    function test_BurnToken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        vm.expectRevert();
        identitySystem.ownerOf(subId);
    }

    function test_BurnToken_EmitsEvent() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.expectEmit(true, true, false, true);
        emit Events.TokenBurned(subId, 1);

        vm.prank(alice);
        identitySystem.burnToken(subId);
    }

    function test_BurnedTokenCannotBeAttested() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        vm.prank(bob);
        vm.expectRevert(Errors.NotToken.selector);
        identitySystem.attestToken(subId, 365 days);
    }

    function test_BurnToken_RemovesFromWalletList() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        uint256[] memory walletBefore = identitySystem.getWalletTokens(alice);
        assertEq(walletBefore.length, 1);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        uint256[] memory walletAfter = identitySystem.getWalletTokens(alice);
        assertEq(walletAfter.length, 0);
    }

    function test_RevertIf_BurnToken_NotHolder() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        vm.expectRevert(Errors.NotHolder.selector);
        identitySystem.burnToken(subId);
    }

    function test_RevertIf_BurnToken_NotToken() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        vm.expectRevert(Errors.NotToken.selector);
        identitySystem.burnToken(rootId);
    }

    function test_RevertIf_BurnToken_AlreadyBurned() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        vm.prank(alice);
        vm.expectRevert();
        identitySystem.burnToken(subId);
    }

    function test_BurnToken_RemovesFromRootTokenList() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId1 = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        uint256 subId2 = identitySystem.createToken("Twitter", "social", bytes(""), "", 0);

        uint256[] memory subsBefore = identitySystem.getTokensForRoot(1);
        assertEq(subsBefore.length, 2);

        vm.prank(alice);
        identitySystem.burnToken(subId1);

        uint256[] memory subsAfter = identitySystem.getTokensForRoot(1);
        assertEq(subsAfter.length, 1);
        assertEq(subsAfter[0], subId2);

        DataTypes.RootIdentityView memory rootView = identitySystem.getRootIdentityView(1);
        assertEq(rootView.tokenCount, 1);
    }

    function test_BurnToken_RemovesFromRootTokenList_SingleToken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        uint256[] memory subsAfter = identitySystem.getTokensForRoot(1);
        assertEq(subsAfter.length, 0);

        DataTypes.RootIdentityView memory rootView = identitySystem.getRootIdentityView(1);
        assertEq(rootView.tokenCount, 0);
    }

    // =========================================================================
    // View functions — root & wallet
    // =========================================================================

    function test_GetRootIdentityView() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice Nakamoto");

        DataTypes.RootIdentityView memory rootView = identitySystem.getRootIdentityView(1);

        assertEq(rootView.tokenId, 1);
        assertEq(rootView.walletAddress, alice);
        assertEq(rootView.displayName, "Alice Nakamoto");
        assertTrue(rootView.isActive);
        assertEq(rootView.tokenCount, 0);
    }

    function test_GetWalletTokens() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        uint256[] memory walletToks = identitySystem.getWalletTokens(alice);
        assertEq(walletToks.length, 1);
        assertEq(walletToks[0], subId);
    }

    // =========================================================================
    // Flag Module (auto-flagging — only auto-flag sets isFlagged)
    // =========================================================================

    function test_AutoFlag_WhenThresholdExceeded() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        // 21 attestations from 21 different users — exceeds MIN_ATTESTATIONS_FOR_AUTO_FLAG (20)
        _createAttesters(subId, 100, 21, 365 days);

        // Revoke 7 of the 21 attestations → 7*3 = 21 >= 21 → triggers auto-flag
        for (uint256 i = 0; i < 7; i++) {
            address attester = address(uint160(100 + i));
            vm.prank(attester);
            identitySystem.revokeAttestation(subId);
        }

        (, , , , , , , , , , bool isFlagged, uint256 flagCount, ) = identitySystem.tokens(subId);
        assertTrue(isFlagged);
        assertEq(flagCount, 1);
    }

    function test_AutoFlag_DoesNotTrigger_BelowMinAttestations() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        // Only 3 attestations — below the MIN_ATTESTATIONS_FOR_AUTO_FLAG (20)
        _createAttesters(subId, 200, 3, 365 days);

        // Revoke all 3 — would exceed 1/3 threshold, but floor blocks it
        for (uint256 i = 0; i < 3; i++) {
            address attester = address(uint160(200 + i));
            vm.prank(attester);
            identitySystem.revokeAttestation(subId);
        }

        (, , , , , , , , , , bool isFlagged, , ) = identitySystem.tokens(subId);
        assertFalse(isFlagged);
    }

    // =========================================================================
    // Manual Flag — increments flagCount but does NOT set isFlagged
    // =========================================================================

    function test_FlagToken_IncrementsFlagCount_ButNotIsFlagged() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.flagToken(subId);

        (, , , , , , , , , , bool isFlagged, uint256 flagCount, ) = identitySystem.tokens(subId);
        assertFalse(isFlagged); // Manual flag does NOT set isFlagged
        assertEq(flagCount, 1); // But flagCount is incremented for analytics
    }

    function test_FlagToken_EmitsEvent() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.expectEmit(true, true, false, true);
        emit Events.TokenFlagged(subId, bob, 1);

        vm.prank(bob);
        identitySystem.flagToken(subId);
    }

    function test_FlagToken_MultipleFlaggers() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(charlie);
        identitySystem.createRootIdentity("Charlie");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.flagToken(subId);

        vm.prank(charlie);
        identitySystem.flagToken(subId);

        (, , , , , , , , , , bool isFlagged, uint256 flagCount, ) = identitySystem.tokens(subId);
        assertFalse(isFlagged); // Still not flagged — manual only
        assertEq(flagCount, 2);
    }

    function test_RevertIf_FlagToken_DuplicateByRoot() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.flagToken(subId);

        vm.prank(bob);
        vm.expectRevert(Errors.AlreadyFlaggedByRoot.selector);
        identitySystem.flagToken(subId);
    }

    function test_RevertIf_FlagToken_NoRoot() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(charlie);
        vm.expectRevert(Errors.NoRootIdentity.selector);
        identitySystem.flagToken(subId);
    }

    function test_RevertIf_FlagToken_NotToken() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(bob);
        vm.expectRevert(Errors.NotToken.selector);
        identitySystem.flagToken(rootId);
    }

    function test_RevertIf_FlagToken_Expired() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", block.timestamp + 100);

        vm.warp(block.timestamp + 200);

        vm.prank(bob);
        vm.expectRevert(Errors.TokenExpired.selector);
        identitySystem.flagToken(subId);
    }

    function test_RevertIf_FlagToken_SelfFlag() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        vm.expectRevert(Errors.CannotFlagOwnToken.selector);
        identitySystem.flagToken(subId);
    }

    function test_ManualFlag_DoesNotBlock_AutoFlag() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(charlie);
        identitySystem.createRootIdentity("Charlie");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        // 20 attestations from 20 different users (meets minimum floor)
        _createAttesters(subId, 300, 20, 365 days);

        // Charlie manually flags (flagCount = 1, isFlagged = false)
        vm.prank(charlie);
        identitySystem.flagToken(subId);

        (, , , , , , , , , , bool isFlaggedBefore, uint256 flagCountBefore, ) = identitySystem.tokens(subId);
        assertFalse(isFlaggedBefore); // Manual flag does NOT set isFlagged
        assertEq(flagCountBefore, 1);

        // Revoke 7 of 20 → 7*3 = 21 >= 20 → auto-flag triggers (flagCount = 2, isFlagged = true)
        for (uint256 i = 0; i < 7; i++) {
            address attester = address(uint160(300 + i));
            vm.prank(attester);
            identitySystem.revokeAttestation(subId);
        }

        (, , , , , , , , , , bool isFlaggedAfter, uint256 flagCountAfter, ) = identitySystem.tokens(subId);
        assertTrue(isFlaggedAfter); // NOW isFlagged is true (auto-flag consensus)
        assertEq(flagCountAfter, 2); // manual (1) + auto (1) = 2
    }

    // =========================================================================
    // Cached counter verification
    // =========================================================================

    function test_CachedCounters_TrackAttestationsAccurately() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(charlie);
        identitySystem.createRootIdentity("Charlie");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

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

    // =========================================================================
    // Token expiry
    // =========================================================================

    function test_RevertIf_CreateToken_InvalidExpiry() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.warp(1000);

        vm.prank(alice);
        vm.expectRevert(Errors.InvalidExpiry.selector);
        identitySystem.createToken("GitHub", "social", bytes(""), "", block.timestamp - 1);
    }

    // =========================================================================
    // Profile System
    // =========================================================================

    function test_CreateProfile() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice Nakamoto",
            username: "alice",
            nationality: "US",
            github: "https://github.com/alice",
            email: "alice@example.com",
            discord: "alice#1234",
            xDotCom: "@alice",
            websitePortfolioLink: "https://alice.dev",
            ens: "alice.eth"
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta);

        assertEq(identitySystem.ownerOf(profileId), alice);
        assertEq(uint8(identitySystem.tokenTypes(profileId)), uint8(DataTypes.TokenType.PROFILE));
        assertTrue(identitySystem.hasProfile(alice));
        assertTrue(profileSystem.usernameTaken("alice"));
        assertTrue(profileSystem.hasMintedProfile(alice));
    }

    function test_CreateProfile_MinimalFields() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "alice",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta);

        assertEq(identitySystem.ownerOf(profileId), alice);
    }

    function test_RevertIf_CreateProfile_NoName() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "",
            username: "alice",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileNameRequired.selector);
        profileSystem.createProfile(meta);
    }

    function test_RevertIf_CreateProfile_UsernameTooShort() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "ab",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileUsernameTooShort.selector);
        profileSystem.createProfile(meta);
    }

    // =========================================================================
    // Profile System tests continued
    // =========================================================================

    function test_RevertIf_CreateProfile_UsernameTooLong() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "abcdefghijklmnopqrstuvwxyz0123456789",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileUsernameTooLong.selector);
        profileSystem.createProfile(meta);
    }

    function test_RevertIf_CreateProfile_InvalidUsernameChar() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "alice!",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        vm.expectRevert(Errors.InvalidProfileUsernameChar.selector);
        profileSystem.createProfile(meta);
    }

    function test_RevertIf_CreateProfile_UsernameTaken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "alice",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        profileSystem.createProfile(meta);

        meta.name = "Bob";
        // same username "alice"

        vm.prank(bob);
        vm.expectRevert(Errors.ProfileUsernameTaken.selector);
        profileSystem.createProfile(meta);
    }

    function test_RevertIf_CreateProfile_AlreadyMinted() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "alice",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        profileSystem.createProfile(meta);

        meta.username = "alice2";

        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyMintedProfile.selector);
        profileSystem.createProfile(meta);
    }

    function test_ProfileTransfer_PreventsRecipientDuplicateProfile() public {
        // Alice creates root + profile
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        DataTypes.ProfileMetadata memory metaAlice = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "alice",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        DataTypes.ProfileMetadata memory metaBob = DataTypes.ProfileMetadata({
            name: "Bob",
            username: "bob_x",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        uint256 aliceProfileId = profileSystem.createProfile(metaAlice);

        vm.prank(bob);
        uint256 bobProfileId = profileSystem.createProfile(metaBob);

        // Alice tries to transfer her profile to Bob who already has one
        vm.prank(alice);
        vm.expectRevert(Errors.RecipientAlreadyHasProfile.selector);
        identitySystem.transferToken(aliceProfileId, bob);
    }

    function test_ProfileTransfer_Success() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "alice",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta);

        // Transfer to bob (who has no profile)
        vm.prank(alice);
        identitySystem.transferToken(profileId, bob);

        assertEq(identitySystem.ownerOf(profileId), bob);
        assertFalse(identitySystem.hasProfile(alice));
        assertTrue(identitySystem.hasProfile(bob));

        // Alice's hasMintedProfile remains true — she can never mint again
        assertTrue(profileSystem.hasMintedProfile(alice));
    }

    function test_ProfileMintGuard_PersistsAfterTransfer() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "alice",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta);

        // Transfer away
        vm.prank(alice);
        identitySystem.transferToken(profileId, bob);

        // Alice tries to mint a new profile — should be permanently blocked
        meta.username = "alice2";

        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyMintedProfile.selector);
        profileSystem.createProfile(meta);

        // Bob tries to mint a profile — should be blocked because he already holds one
        meta.username = "bob";
        vm.prank(bob);
        vm.expectRevert(Errors.AlreadyMintedProfile.selector);
        profileSystem.createProfile(meta);
    }

    function test_ProfileAttestation() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "alice",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta);

        // Bob can attest Alice's profile token
        vm.prank(bob);
        identitySystem.attestToken(profileId, 365 days);

        assertEq(identitySystem.getActiveAttestationCount(profileId), 1);
        assertTrue(identitySystem.hasAttested(2, profileId));
    }

    function test_ProfileFlagging() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "alice",
            nationality: "",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta);

        // Bob can flag Alice's profile token
        vm.prank(bob);
        identitySystem.flagToken(profileId);

        (, , , , , , , , , , , uint256 flagCount, ) = identitySystem.tokens(profileId);
        assertEq(flagCount, 1);
    }

    function test_GetProfile() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice Nakamoto",
            username: "alice",
            nationality: "US",
            github: "https://github.com/alice",
            email: "alice@example.com",
            discord: "alice#1234",
            xDotCom: "@alice",
            websitePortfolioLink: "https://alice.dev",
            ens: "alice.eth"
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta);

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
    }
}
