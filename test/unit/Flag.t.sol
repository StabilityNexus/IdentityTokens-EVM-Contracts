// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "../utils/BaseTest.sol";
import { Errors } from "../../src/libraries/Errors.sol";
import { Events } from "../../src/libraries/Events.sol";

contract FlagTest is BaseTest {
    function test_FlagToken_OnlyIncrementsFlagCount() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.flagToken(subId);

        (, , , , , , , , , , bool isFlagged, uint256 flagCount, ) = identitySystem.tokens(subId);
        assertFalse(isFlagged); // only auto-flag sets isFlagged
        assertEq(flagCount, 1);
    }

    function test_FlagToken_EmitsEvent() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();
        uint256 subId = _token(alice);

        vm.expectEmit(true, true, false, true);
        emit Events.TokenFlagged(subId, bob, 1);

        vm.prank(bob);
        identitySystem.flagToken(subId);
    }

    function test_FlagToken_MultipleFlaggers() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _root(charlie, "Charlie");
        _ageRoots();
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.flagToken(subId);

        vm.prank(charlie);
        identitySystem.flagToken(subId);

        (, , , , , , , , , , bool isFlagged, uint256 flagCount, ) = identitySystem.tokens(subId);
        assertFalse(isFlagged);
        assertEq(flagCount, 2);
    }

    function test_FlagToken_Profile() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();
        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile(_meta("Alice", "alice"), _noLinks());

        vm.prank(bob);
        identitySystem.flagToken(profileId);

        (, , , , , , , , , , , uint256 flagCount, ) = identitySystem.tokens(profileId);
        assertEq(flagCount, 1);
    }

    function test_RevertIf_FlagToken_AlreadyFlagged() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.flagToken(subId);

        vm.prank(bob);
        vm.expectRevert(Errors.AlreadyFlaggedByRoot.selector);
        identitySystem.flagToken(subId);
    }

    function test_RevertIf_FlagToken_NoRoot() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.prank(charlie);
        vm.expectRevert(Errors.NoRootIdentity.selector);
        identitySystem.flagToken(subId);
    }

    function test_RevertIf_FlagToken_NotToken() public {
        uint256 rootId = _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();

        vm.prank(bob);
        vm.expectRevert(Errors.NotToken.selector);
        identitySystem.flagToken(rootId);
    }

    function test_RevertIf_FlagToken_Expired() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _ageRoots();
        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", block.timestamp + 100);

        vm.warp(block.timestamp + 200);

        vm.prank(bob);
        vm.expectRevert(Errors.TokenExpired.selector);
        identitySystem.flagToken(subId);
    }

    function test_RevertIf_FlagToken_SelfFlag() public {
        _root(alice, "Alice");
        _ageRoots();
        uint256 subId = _token(alice);

        vm.prank(alice);
        vm.expectRevert(Errors.CannotFlagOwnToken.selector);
        identitySystem.flagToken(subId);
    }

    function test_RevertIf_FlagToken_RootTooNew() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        vm.expectRevert(Errors.RootTooNew.selector);
        identitySystem.flagToken(subId);

        _ageRoots();
        vm.prank(bob);
        identitySystem.flagToken(subId);

        (, , , , , , , , , , , uint256 flagCount, ) = identitySystem.tokens(subId);
        assertEq(flagCount, 1);
    }

    function test_AutoFlag_WhenThresholdExceeded() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        // 21 attesters, above the 20 that auto-flag needs
        _createAttesters(subId, 100, 21, 365 days);

        // 7 of 21 revoke: 7 * 3 >= 21, so the token is flagged
        for (uint256 i = 0; i < 7; i++) {
            address attester = address(uint160(100 + i));
            vm.prank(attester);
            identitySystem.revokeAttestation(subId);
        }

        (, , , , , , , , , , bool isFlagged, uint256 flagCount, ) = identitySystem.tokens(subId);
        assertTrue(isFlagged);
        assertEq(flagCount, 1);
    }

    function test_AutoFlag_SkippedBelowMinAttestations() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        // 3 attesters, below the 20 that auto-flag needs
        _createAttesters(subId, 200, 3, 365 days);

        // All 3 revoke: past the 1/3 ratio, but under the minimum
        for (uint256 i = 0; i < 3; i++) {
            address attester = address(uint160(200 + i));
            vm.prank(attester);
            identitySystem.revokeAttestation(subId);
        }

        (, , , , , , , , , , bool isFlagged, , ) = identitySystem.tokens(subId);
        assertFalse(isFlagged);
    }

    function test_AutoFlag_AfterManualFlag() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        _root(charlie, "Charlie");
        uint256 subId = _token(alice);

        // 20 attesters, exactly the minimum
        _createAttesters(subId, 300, 20, 365 days);

        vm.prank(charlie);
        identitySystem.flagToken(subId);

        (, , , , , , , , , , bool isFlaggedBefore, uint256 flagCountBefore, ) = identitySystem.tokens(subId);
        assertFalse(isFlaggedBefore);
        assertEq(flagCountBefore, 1);

        // 7 of 20 revoke: 7 * 3 >= 20, so auto-flag still fires
        for (uint256 i = 0; i < 7; i++) {
            address attester = address(uint160(300 + i));
            vm.prank(attester);
            identitySystem.revokeAttestation(subId);
        }

        (, , , , , , , , , , bool isFlaggedAfter, uint256 flagCountAfter, ) = identitySystem.tokens(subId);
        assertTrue(isFlaggedAfter);
        assertEq(flagCountAfter, 2); // 1 manual + 1 auto
    }

    function test_AutoFlag_IgnoresFreshRoots() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        // 20 roots made on the spot attest and 7 revoke: enough to flag if they counted
        for (uint160 i = 0; i < 20; i++) {
            vm.startPrank(address(0x500 + i));
            identitySystem.createRootIdentity("");
            identitySystem.attestToken(subId, 365 days);
            if (i < 7) identitySystem.revokeAttestation(subId);
            vm.stopPrank();
        }

        (, , , , , , , , uint256 totalCount, uint256 revokedCount, bool isFlagged, , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 0);
        assertEq(revokedCount, 0);
        assertFalse(isFlagged);
        // The attestations are still recorded and shown
        assertEq(identitySystem.getActiveAttestationCount(subId), 13);
    }

    function test_RevokeAttestation_NotCountedIfAttestedWhileNew() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);
        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);
        _ageRoots();

        vm.prank(bob);
        identitySystem.revokeAttestation(subId);

        (, , , , , , , , uint256 totalCount, uint256 revokedCount, , , ) = identitySystem.tokens(subId);
        assertEq(totalCount, 0);
        assertEq(revokedCount, 0);
    }
}
