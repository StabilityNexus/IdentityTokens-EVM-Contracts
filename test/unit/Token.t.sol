// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "../utils/BaseTest.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { Errors } from "../../src/libraries/Errors.sol";
import { Events } from "../../src/libraries/Events.sol";

contract TokenTest is BaseTest {
    function test_CreateToken() public {
        _root(alice, "Alice");

        vm.prank(alice);
        uint256 subId = identitySystem.createToken(
            "GitHub",
            "social",
            bytes("https://github.com/alice"),
            "My GitHub",
            0
        );

        assertEq(subId, 29321932540); // first token: tk-9321932540
        assertEq(identitySystem.ownerOf(subId), alice);
        assertEq(uint8(identitySystem.tokenTypeOf(subId)), uint8(DataTypes.TokenType.SUB));

        uint256[] memory subIds = identitySystem.getTokensForRoot(identitySystem.ownerToRootId(alice));
        assertEq(subIds.length, 1);
        assertEq(subIds[0], subId);
    }

    function test_RevertIf_CreateToken_NoRoot() public {
        vm.prank(alice);
        vm.expectRevert(Errors.NoRootIdentity.selector);
        identitySystem.createToken("GitHub", "social", bytes(""), "", 0);
    }

    function test_RevertIf_CreateToken_InvalidExpiry() public {
        _root(alice, "Alice");
        vm.warp(1000);

        vm.prank(alice);
        vm.expectRevert(Errors.InvalidExpiry.selector);
        identitySystem.createToken("GitHub", "social", bytes(""), "", block.timestamp - 1);
    }

    function test_GetWalletTokens() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        uint256[] memory walletTokens = identitySystem.getWalletTokens(alice);

        assertEq(walletTokens.length, 1);
        assertEq(walletTokens[0], subId);
    }

    function test_TransferToken() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.prank(alice);
        identitySystem.transferToken(subId, bob);

        assertEq(identitySystem.ownerOf(subId), bob);

        address[] memory history = identitySystem.getTransferHistory(subId);
        assertEq(history.length, 2);
        assertEq(history[1], bob);
    }

    function test_TransferToken_PreservesAttestations() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 3 * 365 days);

        assertEq(identitySystem.getActiveAttestationCount(subId), 1);
        assertTrue(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));

        // Attestations stay with the token (passport model)
        vm.prank(alice);
        identitySystem.transferToken(subId, charlie);

        assertEq(identitySystem.getActiveAttestationCount(subId), 1);
        assertTrue(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));

        DataTypes.Attestation[] memory active = identitySystem.getActiveAttestations(subId);
        assertEq(active.length, 1);
        assertEq(active[0].attesterTokenId, identitySystem.ownerToRootId(bob));
    }

    function test_RevertIf_TransferToken_NotHolder() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.prank(bob);
        vm.expectRevert(Errors.NotHolder.selector);
        identitySystem.transferToken(subId, bob);
    }

    function test_RevertIf_TransferToken_Root() public {
        uint256 rootId = _root(alice, "Alice");

        vm.prank(alice);
        vm.expectRevert(Errors.CannotTransferRoot.selector);
        identitySystem.transferToken(rootId, bob);
    }

    function test_RevertIf_TransferToken_SelfTransfer() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.prank(alice);
        vm.expectRevert(Errors.SelfTransfer.selector);
        identitySystem.transferToken(subId, alice);
    }

    function test_RevertIf_TransferToken_ZeroAddress() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.prank(alice);
        vm.expectRevert(Errors.ZeroAddress.selector);
        identitySystem.transferToken(subId, address(0));
    }

    function test_RevertIf_TransferToken_Expired() public {
        _root(alice, "Alice");
        vm.prank(alice);
        uint256 subId = identitySystem.createToken("GitHub", "social", bytes(""), "", block.timestamp + 100);

        vm.warp(block.timestamp + 200);

        vm.prank(alice);
        vm.expectRevert(Errors.TokenExpired.selector);
        identitySystem.transferToken(subId, bob);
    }

    function test_BurnToken() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        vm.expectRevert();
        identitySystem.ownerOf(subId);
    }

    function test_BurnToken_EmitsEvent() public {
        uint256 rootId = _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.expectEmit(true, true, false, true);
        emit Events.TokenBurned(subId, rootId);

        vm.prank(alice);
        identitySystem.burnToken(subId);
    }

    function test_BurnToken_RemovesFromWalletList() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        uint256[] memory walletBefore = identitySystem.getWalletTokens(alice);
        assertEq(walletBefore.length, 1);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        uint256[] memory walletAfter = identitySystem.getWalletTokens(alice);
        assertEq(walletAfter.length, 0);
    }

    function test_BurnToken_RemovesFromRootTokenList() public {
        _root(alice, "Alice");
        uint256 burnedId = _token(alice);
        vm.prank(alice);
        uint256 keptId = identitySystem.createToken("Twitter", "social", bytes(""), "", 0);

        uint256[] memory subsBefore = identitySystem.getTokensForRoot(identitySystem.ownerToRootId(alice));
        assertEq(subsBefore.length, 2);

        vm.prank(alice);
        identitySystem.burnToken(burnedId);

        uint256[] memory subsAfter = identitySystem.getTokensForRoot(identitySystem.ownerToRootId(alice));
        assertEq(subsAfter.length, 1);
        assertEq(subsAfter[0], keptId);

        DataTypes.RootIdentityView memory rootView = identitySystem.getRootIdentityView(
            identitySystem.ownerToRootId(alice)
        );
        assertEq(rootView.tokenCount, 1);
    }

    function test_BurnToken_EmptiesRootTokenList() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        uint256[] memory subsAfter = identitySystem.getTokensForRoot(identitySystem.ownerToRootId(alice));
        assertEq(subsAfter.length, 0);

        DataTypes.RootIdentityView memory rootView = identitySystem.getRootIdentityView(
            identitySystem.ownerToRootId(alice)
        );
        assertEq(rootView.tokenCount, 0);
    }

    function test_RevertIf_BurnToken_NotHolder() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.prank(bob);
        vm.expectRevert(Errors.NotHolder.selector);
        identitySystem.burnToken(subId);
    }

    function test_RevertIf_BurnToken_NotToken() public {
        uint256 rootId = _root(alice, "Alice");

        vm.prank(alice);
        vm.expectRevert(Errors.NotToken.selector);
        identitySystem.burnToken(rootId);
    }

    function test_RevertIf_BurnToken_AlreadyBurned() public {
        _root(alice, "Alice");
        uint256 subId = _token(alice);

        vm.prank(alice);
        identitySystem.burnToken(subId);

        vm.prank(alice);
        vm.expectRevert();
        identitySystem.burnToken(subId);
    }
}
