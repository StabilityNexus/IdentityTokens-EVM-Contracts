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

    /// @dev Helper: an empty link list for createProfile / updateProfile.
    function _noLinks() internal pure returns (DataTypes.LinkUpdate[] memory) {
        return new DataTypes.LinkUpdate[](0);
    }

    /// @dev Helper: an empty field list for updateProfile.
    function _noFields() internal pure returns (DataTypes.FieldUpdate[] memory) {
        return new DataTypes.FieldUpdate[](0);
    }

    /// @dev Helper: a single-field update list.
    function _field(
        DataTypes.ProfileField field,
        string memory value
    ) internal pure returns (DataTypes.FieldUpdate[] memory fields) {
        fields = new DataTypes.FieldUpdate[](1);
        fields[0] = DataTypes.FieldUpdate(field, value);
    }

    /// @dev Helper: a single-slot link update list.
    function _link(
        uint8 slot,
        string memory label,
        string memory url
    ) internal pure returns (DataTypes.LinkUpdate[] memory links) {
        links = new DataTypes.LinkUpdate[](1);
        links[0] = DataTypes.LinkUpdate(slot, label, url);
    }

    /// @dev Helper: profile metadata with only name and username set.
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

    /// @dev Helper: gives `user` a root identity and a minimal profile; returns the profile token id.
    function _createProfile(address user, string memory username) internal returns (uint256) {
        vm.prank(user);
        identitySystem.createRootIdentity(username);
        vm.prank(user);
        return profileSystem.createProfile(_meta(username, username), _noLinks());
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

    function test_HasAttested_FalseAfterBurn() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");
        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");
        uint256 bobRootId = identitySystem.ownerToRootId(bob);

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);
        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);
        assertTrue(identitySystem.hasAttested(bobRootId, subId));

        vm.prank(alice);
        identitySystem.burnToken(subId);

        assertFalse(identitySystem.hasAttested(bobRootId, subId));
    }

    function test_GetAttestationsByAttester_SkipsBurned() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");
        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");
        uint256 bobRootId = identitySystem.ownerToRootId(bob);

        vm.prank(alice);
        uint256 keptId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);
        vm.prank(alice);
        uint256 burnedId = identitySystem.createToken("Twitter", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.attestToken(keptId, 365 days);
        vm.prank(bob);
        identitySystem.attestToken(burnedId, 365 days);

        vm.prank(alice);
        identitySystem.burnToken(burnedId);

        uint256[] memory attested = identitySystem.getAttestationsByAttester(bobRootId);
        assertEq(attested.length, 1);
        assertEq(attested[0], keptId);
    }

    function test_RevertIf_RevokeAttestation_BurnedToken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");
        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);
        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        vm.prank(bob);
        vm.expectRevert(Errors.NotToken.selector);
        identitySystem.revokeAttestation(subId);
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
            ens: "alice.eth",
            avatarId: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta, _noLinks());

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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta, _noLinks());

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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileNameRequired.selector);
        profileSystem.createProfile(meta, _noLinks());
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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileUsernameTooShort.selector);
        profileSystem.createProfile(meta, _noLinks());
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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileUsernameTooLong.selector);
        profileSystem.createProfile(meta, _noLinks());
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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        vm.expectRevert(Errors.InvalidProfileUsernameChar.selector);
        profileSystem.createProfile(meta, _noLinks());
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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        profileSystem.createProfile(meta, _noLinks());

        meta.name = "Bob";
        // same username "alice"

        vm.prank(bob);
        vm.expectRevert(Errors.ProfileUsernameTaken.selector);
        profileSystem.createProfile(meta, _noLinks());
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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        profileSystem.createProfile(meta, _noLinks());

        meta.username = "alice2";

        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyMintedProfile.selector);
        profileSystem.createProfile(meta, _noLinks());
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
            ens: "",
            avatarId: ""
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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        uint256 aliceProfileId = profileSystem.createProfile(metaAlice, _noLinks());

        vm.prank(bob);
        uint256 bobProfileId = profileSystem.createProfile(metaBob, _noLinks());

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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta, _noLinks());

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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta, _noLinks());

        // Transfer away
        vm.prank(alice);
        identitySystem.transferToken(profileId, bob);

        // Alice tries to mint a new profile — should be permanently blocked
        meta.username = "alice2";

        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyMintedProfile.selector);
        profileSystem.createProfile(meta, _noLinks());

        // Bob tries to mint a profile — should be blocked because he already holds one
        meta.username = "bob";
        vm.prank(bob);
        vm.expectRevert(Errors.AlreadyMintedProfile.selector);
        profileSystem.createProfile(meta, _noLinks());
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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta, _noLinks());

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
            ens: "",
            avatarId: ""
        });

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta, _noLinks());

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

    // =========================================================================
    // Profile Editing (per-field and per-link-slot updates)
    // =========================================================================

    function test_CreateProfile_WithLinks() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.LinkUpdate[] memory links = new DataTypes.LinkUpdate[](2);
        links[0] = DataTypes.LinkUpdate(0, "Farcaster", "https://warpcast.com/alice");
        links[1] = DataTypes.LinkUpdate(3, "Blog", "https://alice.blog");

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), links);

        DataTypes.ProfileLink[6] memory stored = profileSystem.getLinks(profileId);
        assertEq(stored[0].label, "Farcaster");
        assertEq(stored[0].url, "https://warpcast.com/alice");
        assertEq(stored[3].label, "Blog");
        assertEq(stored[3].url, "https://alice.blog");
        assertEq(stored[1].url, "");
        assertEq(stored[5].url, "");
    }

    function test_UpdateProfile_SingleField() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

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
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");
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
        links[1] = DataTypes.LinkUpdate(5, "Blog", "https://alice.blog");

        vm.prank(alice);
        profileSystem.updateProfile(profileId, fields, links);

        DataTypes.ProfileMetadata memory stored = profileSystem.getProfile(profileId);
        assertEq(stored.name, "Alice Nakamoto");
        assertEq(stored.nationality, "JP");
        assertEq(stored.xDotCom, "alice");

        DataTypes.ProfileLink[6] memory storedLinks = profileSystem.getLinks(profileId);
        assertEq(storedLinks[0].label, "Warpcast");
        assertEq(storedLinks[0].url, "https://warpcast.com/alice.eth");
        assertEq(storedLinks[5].label, "Blog");
        assertEq(storedLinks[5].url, "https://alice.blog");
    }

    function test_UpdateProfile_ClearLinkSlot() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        DataTypes.LinkUpdate[] memory links = new DataTypes.LinkUpdate[](3);
        links[0] = DataTypes.LinkUpdate(0, "One", "https://one.dev");
        links[1] = DataTypes.LinkUpdate(1, "Two", "https://two.dev");
        links[2] = DataTypes.LinkUpdate(2, "Three", "https://three.dev");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), links);

        vm.prank(alice);
        profileSystem.updateProfile(profileId, _noFields(), _link(1, "", ""));

        DataTypes.ProfileLink[6] memory stored = profileSystem.getLinks(profileId);
        assertEq(stored[1].label, "");
        assertEq(stored[1].url, "");
        assertEq(stored[0].url, "https://one.dev");
        assertEq(stored[2].url, "https://three.dev");
    }

    function test_UpdateProfile_EmitsEvent() public {
        uint256 profileId = _createProfile(alice, "alice");

        vm.expectEmit(true, false, false, true);
        emit Events.ProfileUpdated(profileId);

        vm.prank(alice);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.GITHUB, "alice"), _noLinks());
    }

    function test_UpdateProfile_UsernameUnchanged() public {
        uint256 profileId = _createProfile(alice, "alice");

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
        uint256 profileId = _createProfile(alice, "alice");

        vm.prank(alice);
        identitySystem.transferToken(profileId, bob);

        vm.prank(bob);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.NAME, "Bob"), _noLinks());
        assertEq(profileSystem.getProfile(profileId).name, "Bob");

        vm.prank(alice);
        vm.expectRevert(Errors.NotProfileOwner.selector);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.NAME, "Alice"), _noLinks());
    }

    function test_BurnProfile_ClearsLinks() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(
            _meta("Alice", "alice"),
            _link(2, "Blog", "https://alice.blog")
        );

        vm.prank(alice);
        identitySystem.burnToken(profileId);

        DataTypes.ProfileLink[6] memory stored = profileSystem.getLinks(profileId);
        assertEq(stored[2].label, "");
        assertEq(stored[2].url, "");
        assertEq(profileSystem.getProfile(profileId).username, "");
        assertFalse(profileSystem.usernameTaken("alice"));
    }

    function test_RevertIf_UpdateProfile_NotOwner() public {
        uint256 profileId = _createProfile(alice, "alice");

        vm.prank(bob);
        vm.expectRevert(Errors.NotProfileOwner.selector);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.NAME, "Mallory"), _noLinks());
    }

    function test_RevertIf_UpdateProfile_EmptyName() public {
        uint256 profileId = _createProfile(alice, "alice");

        vm.prank(alice);
        vm.expectRevert(Errors.ProfileNameRequired.selector);
        profileSystem.updateProfile(profileId, _field(DataTypes.ProfileField.NAME, ""), _noLinks());
    }

    function test_RevertIf_UpdateProfile_InvalidLinkSlot() public {
        uint256 profileId = _createProfile(alice, "alice");

        vm.prank(alice);
        vm.expectRevert(Errors.InvalidLinkSlot.selector);
        profileSystem.updateProfile(profileId, _noFields(), _link(6, "Blog", "https://alice.blog"));
    }

    function test_RevertIf_UpdateProfile_NoProfile() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");
        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        // A SUB token the caller owns is not a profile
        vm.prank(alice);
        vm.expectRevert(Errors.ProfileNotFound.selector);
        profileSystem.updateProfile(subId, _field(DataTypes.ProfileField.NAME, "Alice"), _noLinks());

        // Neither is a token id that was never minted
        vm.prank(alice);
        vm.expectRevert(Errors.ProfileNotFound.selector);
        profileSystem.updateProfile(999, _field(DataTypes.ProfileField.NAME, "Alice"), _noLinks());
    }

    function test_RevertIf_UpdateProfile_BurnedProfile() public {
        uint256 profileId = _createProfile(alice, "alice");

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
        uint256 profileId = _createProfile(alice, "alice");

        RawFieldUpdate[] memory fields = new RawFieldUpdate[](1);
        fields[0] = RawFieldUpdate(9, "username-takeover"); // one past ProfileField.AVATAR

        vm.prank(alice);
        (bool ok, ) = address(profileSystem).call(
            abi.encodeWithSelector(ProfileSystem.updateProfile.selector, profileId, fields, _noLinks())
        );
        assertFalse(ok);
        assertEq(profileSystem.getProfile(profileId).username, "alice");
    }

    // =========================================================================
    // Attestation Views (paging + attester detail)
    // =========================================================================

    function _attestedToken(uint256 count) internal returns (uint256 tokenId) {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");
        vm.prank(alice);
        tokenId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);
        _createAttesters(tokenId, uint160(0x100), count, 365 days);
    }

    function test_GetAttestationsPaged() public {
        uint256 tokenId = _attestedToken(5);

        (DataTypes.Attestation[] memory page, uint256 total) = identitySystem.getAttestationsPaged(tokenId, 1, 2);

        assertEq(total, 5);
        assertEq(page.length, 2);
        assertEq(page[0].attesterAddress, address(uint160(0x101)));
        assertEq(page[1].attesterAddress, address(uint160(0x102)));
    }

    function test_GetAttestationsPaged_TailPageIsShort() public {
        uint256 tokenId = _attestedToken(5);

        (DataTypes.Attestation[] memory page, uint256 total) = identitySystem.getAttestationsPaged(tokenId, 3, 10);

        assertEq(total, 5);
        assertEq(page.length, 2);
    }

    function test_GetAttestationsPaged_HugeLimitDoesNotOverflow() public {
        uint256 tokenId = _attestedToken(3);

        (DataTypes.Attestation[] memory page, uint256 total) = identitySystem.getAttestationsPaged(
            tokenId,
            0,
            type(uint256).max
        );

        assertEq(total, 3);
        assertEq(page.length, 3);
    }

    function test_GetAttestationsPaged_OffsetPastEndReturnsEmpty() public {
        uint256 tokenId = _attestedToken(2);

        (DataTypes.Attestation[] memory page, uint256 total) = identitySystem.getAttestationsPaged(tokenId, 9, 5);

        assertEq(total, 2);
        assertEq(page.length, 0);
    }

    function test_GetAttestersDetailed_ResolvesRootIdentity() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");
        vm.prank(alice);
        uint256 tokenId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob The Attester");
        vm.prank(bob);
        identitySystem.attestToken(tokenId, 365 days);

        (DataTypes.AttesterView[] memory page, uint256 total) = identitySystem.getAttestersDetailed(
            tokenId,
            true,
            0,
            10
        );

        assertEq(total, 1);
        assertEq(page[0].attestation.attesterAddress, bob);
        assertEq(page[0].displayName, "Bob The Attester");
        assertEq(page[0].attestation.attesterTokenId, identitySystem.ownerToRootId(bob));
        assertEq(page[0].attestation.expiresAt, block.timestamp + 365 days);
        assertEq(page[0].attestation.revokedAt, 0);
    }

    /// @dev A profile is optional and separate from attesting. Whether the
    ///      attester holds one must make no difference to what this view
    ///      returns -- the name shown is always the root display name.
    function test_GetAttestersDetailed_IgnoresAttesterProfile() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");
        vm.prank(alice);
        uint256 tokenId = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.createRootIdentity("Bob");
        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Bob Profile Name",
            username: "bob",
            nationality: "US",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: "",
            avatarId: ""
        });
        vm.prank(bob);
        profileSystem.createProfile(meta, _noLinks());

        vm.prank(bob);
        identitySystem.attestToken(tokenId, 365 days);

        (DataTypes.AttesterView[] memory page, ) = identitySystem.getAttestersDetailed(tokenId, true, 0, 10);

        assertEq(page[0].displayName, "Bob");
        assertEq(page[0].attestation.attesterAddress, bob);
    }

    function test_GetAttestersDetailed_ActiveOnlyExcludesRevoked() public {
        uint256 tokenId = _attestedToken(3);

        address revoker = address(uint160(0x100));
        vm.prank(revoker);
        identitySystem.revokeAttestation(tokenId);

        (, uint256 activeTotal) = identitySystem.getAttestersDetailed(tokenId, true, 0, 10);
        (DataTypes.AttesterView[] memory allPage, uint256 allTotal) = identitySystem.getAttestersDetailed(
            tokenId,
            false,
            0,
            10
        );

        assertEq(activeTotal, 2);
        assertEq(allTotal, 3);
        assertEq(allPage[0].attestation.attesterAddress, revoker);
        assertTrue(allPage[0].attestation.revokedAt > 0);
    }

    function test_GetAttestersDetailed_ActiveOnlyExcludesExpired() public {
        uint256 tokenId = _attestedToken(2);

        vm.warp(block.timestamp + 366 days);

        (, uint256 activeTotal) = identitySystem.getAttestersDetailed(tokenId, true, 0, 10);
        (, uint256 allTotal) = identitySystem.getAttestersDetailed(tokenId, false, 0, 10);

        assertEq(activeTotal, 0);
        assertEq(allTotal, 2);
    }

    function test_GetAttestersDetailed_PagesOverFilteredSet() public {
        uint256 tokenId = _attestedToken(4);

        vm.prank(address(uint160(0x100)));
        identitySystem.revokeAttestation(tokenId);

        (DataTypes.AttesterView[] memory page, uint256 total) = identitySystem.getAttestersDetailed(
            tokenId,
            true,
            0,
            2
        );

        assertEq(total, 3);
        assertEq(page.length, 2);
        assertEq(page[0].attestation.attesterAddress, address(uint160(0x101)));
        assertEq(page[1].attestation.attesterAddress, address(uint160(0x102)));
    }

    function test_GetAttestersDetailed_OffsetPastEndReturnsEmpty() public {
        uint256 tokenId = _attestedToken(2);

        (DataTypes.AttesterView[] memory page, uint256 total) = identitySystem.getAttestersDetailed(
            tokenId,
            true,
            5,
            10
        );

        assertEq(total, 2);
        assertEq(page.length, 0);
    }

    /// @dev The attesters list has to carry enough to open an attester's wallet
    ///      view: the address it returns must resolve to that wallet's own
    ///      tokens and root identity, without touching their profile.
    function test_GetAttestersDetailed_WalletResolvesToAttestersOwnTokens() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");
        vm.prank(alice);
        uint256 aliceToken = identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.createRootIdentity("John");
        vm.prank(bob);
        uint256 bobToken = identitySystem.createToken("Twitter", "social", bytes(""), "", 0);
        vm.prank(bob);
        identitySystem.attestToken(aliceToken, 365 days);

        (DataTypes.AttesterView[] memory page, ) = identitySystem.getAttestersDetailed(aliceToken, true, 0, 10);

        address attesterWallet = page[0].attestation.attesterAddress;
        assertEq(attesterWallet, bob);
        assertEq(page[0].displayName, "John");

        uint256[] memory attesterTokens = identitySystem.getWalletTokens(attesterWallet);
        assertEq(attesterTokens.length, 1);
        assertEq(attesterTokens[0], bobToken);

        DataTypes.RootIdentityView memory root = identitySystem.getRootIdentityView(
            identitySystem.ownerToRootId(attesterWallet)
        );
        assertEq(root.displayName, "John");
        assertEq(root.walletAddress, bob);
    }

    function test_GetProfileTokenId() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");

        assertEq(identitySystem.getProfileTokenId(alice), 0);

        DataTypes.ProfileMetadata memory meta = DataTypes.ProfileMetadata({
            name: "Alice",
            username: "alice",
            nationality: "US",
            github: "",
            email: "",
            discord: "",
            xDotCom: "",
            websitePortfolioLink: "",
            ens: "",
            avatarId: ""
        });
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(meta, _noLinks());

        assertEq(identitySystem.getProfileTokenId(alice), profileId);
    }

    function test_GetProfileTokenId_IgnoresRootAndSubTokens() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("Alice");
        vm.prank(alice);
        identitySystem.createToken("GitHub", "social", bytes(""), "", 0);

        assertEq(identitySystem.getProfileTokenId(alice), 0);
    }
}
