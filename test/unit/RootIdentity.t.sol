// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "../utils/BaseTest.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { Errors } from "../../src/libraries/Errors.sol";

contract RootIdentityTest is BaseTest {
    function test_CreateRootIdentity() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("Alice Nakamoto");

        assertEq(rootId, 16180339887); // first root: id-6180339887
        assertEq(identitySystem.ownerOf(rootId), alice);
        assertEq(identitySystem.ownerToRootId(alice), rootId);
        assertEq(uint8(identitySystem.tokenTypeOf(rootId)), uint8(DataTypes.TokenType.ROOT));
    }

    function test_CreateRootIdentity_WithEmptyDisplayName() public {
        vm.prank(alice);
        uint256 rootId = identitySystem.createRootIdentity("");

        assertEq(identitySystem.ownerOf(rootId), alice);
    }

    function test_RevertIf_CreateRootIdentity_AlreadyHasRoot() public {
        _root(alice, "Alice");

        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyHasRoot.selector);
        identitySystem.createRootIdentity("Alice2");
    }

    function test_GetRootIdentityView() public {
        _root(alice, "Alice Nakamoto");

        DataTypes.RootIdentityView memory rootView = identitySystem.getRootIdentityView(
            identitySystem.ownerToRootId(alice)
        );

        assertEq(rootView.tokenId, identitySystem.ownerToRootId(alice));
        assertEq(rootView.walletAddress, alice);
        assertEq(rootView.displayName, "Alice Nakamoto");
        assertTrue(rootView.isActive);
        assertEq(rootView.tokenCount, 0);
    }
}
