// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IdentitySystem } from "../src/IdentitySystem.sol";
import { DataTypes } from "../src/libraries/DataTypes.sol";
import { Errors } from "../src/libraries/Errors.sol";
import { Events } from "../src/libraries/Events.sol";
import { Schema } from "../src/libraries/Schema.sol";

contract IdentitySystemTest is Test {
    IdentitySystem public identitySystem;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    function setUp() public {
        identitySystem = new IdentitySystem();
    }

    /// @dev Helper: creates `count` fresh root identities (starting at `startAddr`)
    ///      and has each one endorse `subTokenId` with the given duration.
    function _createEndorsers(
        uint256 subTokenId,
        uint160 startAddr,
        uint256 count,
        uint256 duration
    ) internal returns (uint160 nextAddr) {
        for (uint256 i = 0; i < count; i++) {
            address endorser = address(startAddr + uint160(i));
            vm.prank(endorser);
            identitySystem.createRootIdentity(
                string(abi.encodePacked("e", vm.toString(startAddr + uint160(i)))),
                "",
                bytes("")
            );
            vm.prank(endorser);
            identitySystem.endorseSubToken(subTokenId, duration);
        }
        return startAddr + uint160(count);
    }

    // =========================================================================
    // Root Identity
    // =========================================================================

    function test_CreateRootIdentity() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("alice", "Alice Nakamoto", bytes("metadata"));

        assertEq(rootId, 1);
        assertEq(identitySystem.ownerOf(1), alice);
        assertTrue(identitySystem.usernameTaken("alice"));
        assertEq(identitySystem.usernameToRootId("alice"), 1);
        assertEq(identitySystem.ownerToRootId(alice), 1);
        assertEq(uint8(identitySystem.tokenTypes(1)), uint8(DataTypes.TokenType.ROOT));
    }

    function test_CreateRootIdentity_WithEmptyDisplayName() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("alice", "", bytes(""));

        assertEq(rootId, 1);
    }

    function test_RevertIf_CreateRootIdentity_TooShort() public {
        vm.expectRevert(Errors.UsernameTooShort.selector);
        vm.prank(alice);
        identitySystem.createRootIdentity("ab", "A", bytes(""));
    }

    function test_RevertIf_CreateRootIdentity_TooLong() public {
        vm.prank(alice);
        vm.expectRevert(Errors.UsernameTooLong.selector);
        identitySystem.createRootIdentity("abcdefghijklmnopqrstuvwxyz0123456789", "A", bytes(""));
    }

    function test_RevertIf_CreateRootIdentity_Taken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        vm.expectRevert(Errors.UsernameTaken.selector);
        identitySystem.createRootIdentity("alice", "Bob", bytes(""));
    }

    function test_RevertIf_CreateRootIdentity_AlreadyHasRoot() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyHasRoot.selector);
        identitySystem.createRootIdentity("alice2", "Alice2", bytes(""));
    }

    function test_RevertIf_CreateRootIdentity_InvalidChar() public {
        vm.prank(alice);
        vm.expectRevert(Errors.InvalidUsernameChar.selector);
        identitySystem.createRootIdentity("alice!", "Alice", bytes(""));
    }

    // =========================================================================
    // Sub-token
    // =========================================================================

    function test_CreateSubToken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken(
            "GitHub",
            "social",
            bytes("https://github.com/alice"),
            "My GitHub",
            0
        );

        assertEq(subId, 2);
        assertEq(identitySystem.ownerOf(2), alice);
        assertEq(uint8(identitySystem.tokenTypes(2)), uint8(DataTypes.TokenType.SUB));

        uint256[] memory subIds = identitySystem.getSubTokensForRoot(1);
        assertEq(subIds.length, 1);
        assertEq(subIds[0], 2);
    }

    function test_RevertIf_CreateSubToken_NoRoot() public {
        vm.prank(alice);
        vm.expectRevert(Errors.NoRootIdentity.selector);
        identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);
    }

    // =========================================================================
    // Endorsement (time-based validity)
    // =========================================================================

    function test_EndorseSubToken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        DataTypes.Endorsement[] memory endorsements = identitySystem.getEndorsements(subId);
        assertEq(endorsements.length, 1);
        assertEq(endorsements[0].endorserTokenId, 2);
        assertEq(endorsements[0].expiresAt, block.timestamp + 365 days);

        // Verify cached counter
        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.subTokens(subId);
        assertEq(totalCount, 1);

        // Verify dynamic count
        assertEq(identitySystem.getActiveEndorsementCount(subId), 1);
    }

    function test_EndorseSubToken_3YearDuration() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 3 * 365 days);

        DataTypes.Endorsement[] memory endorsements = identitySystem.getEndorsements(subId);
        assertEq(endorsements[0].expiresAt, block.timestamp + 3 * 365 days);
    }

    function test_EndorseSubToken_CustomDuration_60Days() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 60 days);

        DataTypes.Endorsement[] memory endorsements = identitySystem.getEndorsements(subId);
        assertEq(endorsements[0].expiresAt, block.timestamp + 60 days);
    }

    function test_RevertIf_EndorseSubToken_NoRoot() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(charlie);
        vm.expectRevert(Errors.NoRootIdentity.selector);
        identitySystem.endorseSubToken(subId, 365 days);
    }

    function test_RevertIf_EndorseSubToken_SelfEndorsement() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        vm.expectRevert(Errors.CannotEndorseOwnToken.selector);
        identitySystem.endorseSubToken(subId, 365 days);
    }

    function test_RevertIf_EndorseSubToken_AlreadyEndorsed() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        vm.prank(bob);
        vm.expectRevert(Errors.AlreadyEndorsed.selector);
        identitySystem.endorseSubToken(subId, 365 days);
    }

    // =========================================================================
    // Endorsement clamping to sub-token validity
    // =========================================================================

    function test_EndorsementClamped_ToSubTokenValidity() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        // Sub-token valid for 2 years
        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken(
            "Education",
            "credential",
            bytes(""),
            "",
            block.timestamp + 2 * 365 days
        );

        // Bob endorses for 5 years — should be clamped to 2 years (sub-token validity)
        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 5 * 365 days);

        DataTypes.Endorsement[] memory endorsements = identitySystem.getEndorsements(subId);
        assertEq(endorsements[0].expiresAt, block.timestamp + 2 * 365 days);
    }

    function test_EndorsementClamped_SubTokenExpiresTooSoon() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        // Sub-token valid for only 5 days — less than MIN_ENDORSEMENT_DURATION
        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("Temp", "credential", bytes(""), "", block.timestamp + 5 days);

        // Bob tries to endorse for 30 days — clamping will silently set to 5 days
        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 30 days);

        DataTypes.Endorsement[] memory endorsements = identitySystem.getEndorsements(subId);
        assertEq(endorsements[0].expiresAt, block.timestamp + 5 days);
    }

    // =========================================================================
    // Endorsement expiry
    // =========================================================================

    function test_EndorsementExpires_AfterValidity() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        // Still active before expiry
        assertTrue(identitySystem.hasEndorsed(2, subId));
        assertEq(identitySystem.getActiveEndorsementCount(subId), 1);

        // Warp past the 1-year validity
        vm.warp(block.timestamp + 366 days);

        // Endorsement has expired — lazy evaluation
        assertFalse(identitySystem.hasEndorsed(2, subId));
        assertEq(identitySystem.getActiveEndorsementCount(subId), 0);

        DataTypes.Endorsement[] memory active = identitySystem.getActiveEndorsements(subId);
        assertEq(active.length, 0);
    }

    function test_ReEndorse_AfterExpiry() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        // Bob endorses with 1-year validity
        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        // Warp past expiry
        vm.warp(block.timestamp + 366 days);

        // Bob can re-endorse after expiry
        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 3 * 365 days);

        assertTrue(identitySystem.hasEndorsed(2, subId));
        assertEq(identitySystem.getActiveEndorsementCount(subId), 1);

        // totalEndorsementCount should still be 1 (same endorser, not inflated)
        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.subTokens(subId);
        assertEq(totalCount, 1);
    }

    function test_ReEndorse_AfterRevocation() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        // Bob endorses
        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        // Bob revokes
        vm.prank(bob);
        identitySystem.revokeEndorsement(subId);

        // Bob can re-endorse after revoking
        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 3 * 365 days);

        assertTrue(identitySystem.hasEndorsed(2, subId));

        // totalEndorsementCount should still be 1 (re-endorsement doesn't inflate)
        (, , , , , , , , uint256 totalCount, , , , ) = identitySystem.subTokens(subId);
        assertEq(totalCount, 1);
    }

    // =========================================================================
    // Endorse-revoke loop exploit prevention (Bug #2)
    // =========================================================================

    function test_EndorseRevokeLoop_DoesNotInflateTotalCount() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        // Bob does 5 endorse-revoke cycles
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(bob);
            identitySystem.endorseSubToken(subId, 365 days);

            vm.prank(bob);
            identitySystem.revokeEndorsement(subId);
        }

        // totalEndorsementCount should be 1, not 5 (only counted once per endorser)
        (, , , , , , , , uint256 totalCount, uint256 revokedCount, , , ) = identitySystem.subTokens(subId);
        assertEq(totalCount, 1);
        // revokedCount should ALSO be 1, not 5 (only counted once per endorser)
        assertEq(revokedCount, 1);

        // But auto-flag should NOT trigger: totalEndorsementCount=1 < MIN_ENDORSEMENTS_FOR_AUTO_FLAG=20
        (, , , , , , , , , , bool isFlagged, , ) = identitySystem.subTokens(subId);
        assertFalse(isFlagged);
    }

    // =========================================================================
    // Revocation (no endorsementIndex parameter)
    // =========================================================================

    function test_RevokeEndorsement() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        vm.prank(bob);
        identitySystem.revokeEndorsement(subId);

        DataTypes.Endorsement[] memory endorsements = identitySystem.getEndorsements(subId);
        assertGt(endorsements[0].revokedAt, 0);

        // Verify cached counters updated
        (, , , , , , , , , uint256 revokedCount, , , ) = identitySystem.subTokens(subId);
        assertEq(revokedCount, 1);

        // Verify dynamic count
        assertEq(identitySystem.getActiveEndorsementCount(subId), 0);
    }

    function test_RevertIf_RevokeEndorsement_NoActiveEndorsement() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        // Bob has not endorsed — revoke should fail
        vm.prank(bob);
        vm.expectRevert(Errors.NoActiveEndorsement.selector);
        identitySystem.revokeEndorsement(subId);
    }

    function test_RevertIf_RevokeEndorsement_AlreadyRevoked() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        vm.prank(bob);
        identitySystem.revokeEndorsement(subId);

        vm.prank(bob);
        vm.expectRevert(Errors.NoActiveEndorsement.selector);
        identitySystem.revokeEndorsement(subId);
    }

    function test_RevertIf_RevokeEndorsement_NonEndorser() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(charlie);
        identitySystem.createRootIdentity("charlie", "Charlie", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        // Charlie never endorsed — trying to revoke should fail
        vm.prank(charlie);
        vm.expectRevert(Errors.NoActiveEndorsement.selector);
        identitySystem.revokeEndorsement(subId);
    }

    function test_RevertIf_RevokeEndorsement_Expired() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        // Warp past expiry
        vm.warp(block.timestamp + 366 days);

        // Can't revoke an already-expired endorsement
        vm.prank(bob);
        vm.expectRevert(Errors.EndorsementExpired.selector);
        identitySystem.revokeEndorsement(subId);
    }

    // =========================================================================
    // View functions — endorsements
    // =========================================================================

    function test_GetActiveEndorsements() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        DataTypes.Endorsement[] memory active = identitySystem.getActiveEndorsements(subId);
        assertEq(active.length, 1);

        vm.prank(bob);
        identitySystem.revokeEndorsement(subId);

        active = identitySystem.getActiveEndorsements(subId);
        assertEq(active.length, 0);
    }

    function test_GetActiveEndorsementCount() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(charlie);
        identitySystem.createRootIdentity("charlie", "Charlie", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        // Two endorsements
        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);
        vm.prank(charlie);
        identitySystem.endorseSubToken(subId, 3 * 365 days);

        assertEq(identitySystem.getActiveEndorsementCount(subId), 2);

        // Bob's 1-year endorsement expires
        vm.warp(block.timestamp + 366 days);
        assertEq(identitySystem.getActiveEndorsementCount(subId), 1); // only Charlie's 3-year remains

        // Charlie's 3-year endorsement expires
        vm.warp(block.timestamp + 3 * 365 days);
        assertEq(identitySystem.getActiveEndorsementCount(subId), 0);
    }

    function test_GetEndorsementsByEndorser() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        uint256[] memory endorsed = identitySystem.getEndorsementsByEndorser(2);
        assertEq(endorsed.length, 1);
        assertEq(endorsed[0], subId);
    }

    function test_GetEndorsementsByEndorser_ExcludesExpired() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        // Warp past expiry
        vm.warp(block.timestamp + 366 days);

        uint256[] memory endorsed = identitySystem.getEndorsementsByEndorser(2);
        assertEq(endorsed.length, 0);
    }

    function test_HasEndorsed() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        assertFalse(identitySystem.hasEndorsed(2, subId));

        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        assertTrue(identitySystem.hasEndorsed(2, subId));
    }

    // =========================================================================
    // Transfer (controlled) — endorsements persist
    // =========================================================================

    function test_TransferSubToken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        identitySystem.transferSubToken(subId, bob);

        assertEq(identitySystem.ownerOf(subId), bob);

        address[] memory history = identitySystem.getTransferHistory(subId);
        assertEq(history.length, 2);
        assertEq(history[1], bob);
    }

    function test_TransferSubToken_PreservesEndorsements() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        // Bob endorses with 3-year validity
        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 3 * 365 days);

        // Before transfer: 1 active endorsement
        assertEq(identitySystem.getActiveEndorsementCount(subId), 1);
        assertTrue(identitySystem.hasEndorsed(2, subId));

        // Transfer — endorsements persist (passport model)
        vm.prank(alice);
        identitySystem.transferSubToken(subId, charlie);

        // After transfer: endorsement still active
        assertEq(identitySystem.getActiveEndorsementCount(subId), 1);
        assertTrue(identitySystem.hasEndorsed(2, subId));

        DataTypes.Endorsement[] memory active = identitySystem.getActiveEndorsements(subId);
        assertEq(active.length, 1);
        assertEq(active[0].endorserTokenId, 2);
    }

    function test_RevertIf_TransferSubToken_NotHolder() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        vm.expectRevert(Errors.NotHolder.selector);
        identitySystem.transferSubToken(subId, bob);
    }

    function test_RevertIf_TransferRootToken() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        vm.expectRevert(Errors.CannotTransferRoot.selector);
        identitySystem.transferSubToken(rootId, bob);
    }

    function test_RevertIf_TransferSubToken_SelfTransfer() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        vm.expectRevert(Errors.SelfTransfer.selector);
        identitySystem.transferSubToken(subId, alice);
    }

    function test_RevertIf_TransferSubToken_ZeroAddress() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        vm.expectRevert(Errors.ZeroAddress.selector);
        identitySystem.transferSubToken(subId, address(0));
    }

    function test_RevertIf_TransferSubToken_Expired() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", block.timestamp + 100);

        vm.warp(block.timestamp + 200);

        vm.prank(alice);
        vm.expectRevert(Errors.TokenExpired.selector);
        identitySystem.transferSubToken(subId, bob);
    }

    // =========================================================================
    // Burn Sub-token
    // =========================================================================

    function test_BurnSubToken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        identitySystem.burnSubToken(subId);

        vm.expectRevert();
        identitySystem.ownerOf(subId);
    }

    function test_BurnSubToken_EmitsEvent() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.expectEmit(true, true, false, true);
        emit Events.SubTokenBurned(subId, 1);

        vm.prank(alice);
        identitySystem.burnSubToken(subId);
    }

    function test_BurnedTokenCannotBeEndorsed() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        identitySystem.burnSubToken(subId);

        vm.prank(bob);
        vm.expectRevert(Errors.NotSubToken.selector);
        identitySystem.endorseSubToken(subId, 365 days);
    }

    function test_BurnSubToken_RemovesFromWalletList() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        uint256[] memory walletBefore = identitySystem.getWalletSubTokens(alice);
        assertEq(walletBefore.length, 1);

        vm.prank(alice);
        identitySystem.burnSubToken(subId);

        uint256[] memory walletAfter = identitySystem.getWalletSubTokens(alice);
        assertEq(walletAfter.length, 0);
    }

    function test_RevertIf_BurnSubToken_NotHolder() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        vm.expectRevert(Errors.NotHolder.selector);
        identitySystem.burnSubToken(subId);
    }

    function test_RevertIf_BurnSubToken_NotSubToken() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        vm.expectRevert(Errors.NotSubToken.selector);
        identitySystem.burnSubToken(rootId);
    }

    function test_RevertIf_BurnSubToken_AlreadyBurned() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        identitySystem.burnSubToken(subId);

        vm.prank(alice);
        vm.expectRevert();
        identitySystem.burnSubToken(subId);
    }

    function test_BurnSubToken_RemovesFromRootSubTokenList() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId1 = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        uint256 subId2 = identitySystem.createSubToken("Twitter", "social", bytes(""), "", 0);

        uint256[] memory subsBefore = identitySystem.getSubTokensForRoot(1);
        assertEq(subsBefore.length, 2);

        vm.prank(alice);
        identitySystem.burnSubToken(subId1);

        uint256[] memory subsAfter = identitySystem.getSubTokensForRoot(1);
        assertEq(subsAfter.length, 1);
        assertEq(subsAfter[0], subId2);

        DataTypes.RootIdentityView memory rootView = identitySystem.getRootIdentityView(1);
        assertEq(rootView.subTokenCount, 1);
    }

    function test_BurnSubToken_RemovesFromRootSubTokenList_SingleToken() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        identitySystem.burnSubToken(subId);

        uint256[] memory subsAfter = identitySystem.getSubTokensForRoot(1);
        assertEq(subsAfter.length, 0);

        DataTypes.RootIdentityView memory rootView = identitySystem.getRootIdentityView(1);
        assertEq(rootView.subTokenCount, 0);
    }

    // =========================================================================
    // View functions — root & wallet
    // =========================================================================

    function test_GetRootIdentityView() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice Nakamoto", bytes("metadata"));

        DataTypes.RootIdentityView memory rootView = identitySystem.getRootIdentityView(1);

        assertEq(rootView.tokenId, 1);
        assertEq(rootView.username, "alice");
        assertEq(rootView.owner, alice);
        assertTrue(rootView.isActive);
        assertEq(rootView.subTokenCount, 0);
    }

    function test_ResolveUsername() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        assertEq(identitySystem.resolveUsername("alice"), 1);
        assertEq(identitySystem.resolveUsername("bob"), 0);
    }

    function test_GetWalletSubTokens() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        uint256[] memory walletTokens = identitySystem.getWalletSubTokens(alice);
        assertEq(walletTokens.length, 1);
        assertEq(walletTokens[0], subId);
    }

    // =========================================================================
    // Username validation
    // =========================================================================

    function test_Username_AllowedChars() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice_007", "Alice", bytes(""));
        assertTrue(identitySystem.usernameTaken("alice_007"));
    }

    function test_RevertIf_Username_InvalidDash() public {
        vm.prank(alice);
        vm.expectRevert(Errors.InvalidUsernameChar.selector);
        identitySystem.createRootIdentity("alice-bob", "Alice", bytes(""));
    }

    function test_RevertIf_Username_InvalidSpace() public {
        vm.prank(alice);
        vm.expectRevert(Errors.InvalidUsernameChar.selector);
        identitySystem.createRootIdentity("alice bob", "Alice", bytes(""));
    }

    // =========================================================================
    // Flag Module (auto-flagging — only auto-flag sets isFlagged)
    // =========================================================================

    function test_AutoFlag_WhenThresholdExceeded() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        // 21 endorsements from 21 different users — exceeds MIN_ENDORSEMENTS_FOR_AUTO_FLAG (20)
        _createEndorsers(subId, 100, 21, 365 days);

        // Revoke 7 of the 21 endorsements → 7*3 = 21 >= 21 → triggers auto-flag
        for (uint256 i = 0; i < 7; i++) {
            address endorser = address(uint160(100 + i));
            vm.prank(endorser);
            identitySystem.revokeEndorsement(subId);
        }

        (, , , , , , , , , , bool isFlagged, uint256 flagCount, ) = identitySystem.subTokens(subId);
        assertTrue(isFlagged);
        assertEq(flagCount, 1);
    }

    function test_AutoFlag_DoesNotTrigger_BelowMinEndorsements() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        // Only 3 endorsements — below the MIN_ENDORSEMENTS_FOR_AUTO_FLAG (20)
        _createEndorsers(subId, 200, 3, 365 days);

        // Revoke all 3 — would exceed 1/3 threshold, but floor blocks it
        for (uint256 i = 0; i < 3; i++) {
            address endorser = address(uint160(200 + i));
            vm.prank(endorser);
            identitySystem.revokeEndorsement(subId);
        }

        (, , , , , , , , , , bool isFlagged, , ) = identitySystem.subTokens(subId);
        assertFalse(isFlagged);
    }

    // =========================================================================
    // Manual Flag — increments flagCount but does NOT set isFlagged
    // =========================================================================

    function test_FlagSubToken_IncrementsFlagCount_ButNotIsFlagged() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.flagSubToken(subId);

        (, , , , , , , , , , bool isFlagged, uint256 flagCount, ) = identitySystem.subTokens(subId);
        assertFalse(isFlagged); // Manual flag does NOT set isFlagged
        assertEq(flagCount, 1); // But flagCount is incremented for analytics
    }

    function test_FlagSubToken_EmitsEvent() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.expectEmit(true, true, false, true);
        emit Events.SubTokenFlagged(subId, bob, 1);

        vm.prank(bob);
        identitySystem.flagSubToken(subId);
    }

    function test_FlagSubToken_MultipleFlaggers() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(charlie);
        identitySystem.createRootIdentity("charlie", "Charlie", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.flagSubToken(subId);

        vm.prank(charlie);
        identitySystem.flagSubToken(subId);

        (, , , , , , , , , , bool isFlagged, uint256 flagCount, ) = identitySystem.subTokens(subId);
        assertFalse(isFlagged); // Still not flagged — manual only
        assertEq(flagCount, 2);
    }

    function test_RevertIf_FlagSubToken_DuplicateByRoot() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(bob);
        identitySystem.flagSubToken(subId);

        vm.prank(bob);
        vm.expectRevert(Errors.AlreadyFlaggedByRoot.selector);
        identitySystem.flagSubToken(subId);
    }

    function test_RevertIf_FlagSubToken_NoRoot() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(charlie);
        vm.expectRevert(Errors.NoRootIdentity.selector);
        identitySystem.flagSubToken(subId);
    }

    function test_RevertIf_FlagSubToken_NotSubToken() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(bob);
        vm.expectRevert(Errors.NotSubToken.selector);
        identitySystem.flagSubToken(rootId);
    }

    function test_RevertIf_FlagSubToken_Expired() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", block.timestamp + 100);

        vm.warp(block.timestamp + 200);

        vm.prank(bob);
        vm.expectRevert(Errors.TokenExpired.selector);
        identitySystem.flagSubToken(subId);
    }

    function test_RevertIf_FlagSubToken_SelfFlag() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        vm.prank(alice);
        vm.expectRevert(Errors.CannotFlagOwnToken.selector);
        identitySystem.flagSubToken(subId);
    }

    function test_ManualFlag_DoesNotBlock_AutoFlag() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(charlie);
        identitySystem.createRootIdentity("charlie", "Charlie", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        // 20 endorsements from 20 different users (meets minimum floor)
        _createEndorsers(subId, 300, 20, 365 days);

        // Charlie manually flags (flagCount = 1, isFlagged = false)
        vm.prank(charlie);
        identitySystem.flagSubToken(subId);

        (, , , , , , , , , , bool isFlaggedBefore, uint256 flagCountBefore, ) = identitySystem.subTokens(subId);
        assertFalse(isFlaggedBefore); // Manual flag does NOT set isFlagged
        assertEq(flagCountBefore, 1);

        // Revoke 7 of 20 → 7*3 = 21 >= 20 → auto-flag triggers (flagCount = 2, isFlagged = true)
        for (uint256 i = 0; i < 7; i++) {
            address endorser = address(uint160(300 + i));
            vm.prank(endorser);
            identitySystem.revokeEndorsement(subId);
        }

        (, , , , , , , , , , bool isFlaggedAfter, uint256 flagCountAfter, ) = identitySystem.subTokens(subId);
        assertTrue(isFlaggedAfter); // NOW isFlagged is true (auto-flag consensus)
        assertEq(flagCountAfter, 2); // manual (1) + auto (1) = 2
    }

    // =========================================================================
    // Cached counter verification
    // =========================================================================

    function test_CachedCounters_TrackEndorsementsAccurately() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.prank(bob);
        identitySystem.createRootIdentity("bob", "Bob", bytes(""));

        vm.prank(charlie);
        identitySystem.createRootIdentity("charlie", "Charlie", bytes(""));

        vm.prank(alice);
        uint256 subId = identitySystem.createSubToken("GitHub", "social", bytes(""), "", 0);

        // Bob endorses
        vm.prank(bob);
        identitySystem.endorseSubToken(subId, 365 days);

        (, , , , , , , , uint256 totalCount, uint256 revokedCount, , , ) = identitySystem.subTokens(subId);
        assertEq(totalCount, 1);
        assertEq(revokedCount, 0);
        assertEq(identitySystem.getActiveEndorsementCount(subId), 1);

        // Charlie endorses
        vm.prank(charlie);
        identitySystem.endorseSubToken(subId, 3 * 365 days);

        (, , , , , , , , totalCount, revokedCount, , , ) = identitySystem.subTokens(subId);
        assertEq(totalCount, 2);
        assertEq(revokedCount, 0);
        assertEq(identitySystem.getActiveEndorsementCount(subId), 2);

        // Bob revokes
        vm.prank(bob);
        identitySystem.revokeEndorsement(subId);

        (, , , , , , , , totalCount, revokedCount, , , ) = identitySystem.subTokens(subId);
        assertEq(totalCount, 2);
        assertEq(revokedCount, 1);
        assertEq(identitySystem.getActiveEndorsementCount(subId), 1);
    }

    // =========================================================================
    // Sub-token expiry
    // =========================================================================

    function test_RevertIf_CreateSubToken_InvalidExpiry() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice", "Alice", bytes(""));

        vm.warp(1000);

        vm.prank(alice);
        vm.expectRevert(Errors.InvalidExpiry.selector);
        identitySystem.createSubToken("GitHub", "social", bytes(""), "", block.timestamp - 1);
    }
}
