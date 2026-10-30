// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "../utils/BaseTest.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";

contract AttestationViewsTest is BaseTest {
    /// @dev Alice's token, attested by `count` aged roots at 0x100, 0x101, ...
    function _attestedToken(uint256 count) internal returns (uint256 tokenId) {
        _root(alice, "Alice");
        tokenId = _token(alice);
        _createAttesters(tokenId, uint160(0x100), count, 365 days);
    }

    function test_GetActiveAttestations() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

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
        _root(alice, "Alice");
        _root(bob, "Bob");
        _root(charlie, "Charlie");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);
        vm.prank(charlie);
        identitySystem.attestToken(subId, 3 * 365 days);

        assertEq(identitySystem.getActiveAttestationCount(subId), 2);

        // Bob's 1-year attestation expires, Charlie's 3-year one remains
        vm.warp(block.timestamp + 366 days);
        assertEq(identitySystem.getActiveAttestationCount(subId), 1);

        // Charlie's expires too
        vm.warp(block.timestamp + 3 * 365 days);
        assertEq(identitySystem.getActiveAttestationCount(subId), 0);
    }

    function test_HasAttested() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        assertFalse(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        assertTrue(identitySystem.hasAttested(identitySystem.ownerToRootId(bob), subId));
    }

    function test_HasAttested_FalseAfterBurn() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 bobRootId = identitySystem.ownerToRootId(bob);
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);
        assertTrue(identitySystem.hasAttested(bobRootId, subId));

        vm.prank(alice);
        identitySystem.burnToken(subId);

        assertFalse(identitySystem.hasAttested(bobRootId, subId));
    }

    function test_GetAttestationsByAttester() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        uint256[] memory attested = identitySystem.getAttestationsByAttester(identitySystem.ownerToRootId(bob));
        assertEq(attested.length, 1);
        assertEq(attested[0], subId);
    }

    function test_GetAttestationsByAttester_ExcludesExpired() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 subId = _token(alice);

        vm.prank(bob);
        identitySystem.attestToken(subId, 365 days);

        vm.warp(block.timestamp + 366 days);

        uint256[] memory attested = identitySystem.getAttestationsByAttester(identitySystem.ownerToRootId(bob));
        assertEq(attested.length, 0);
    }

    function test_GetAttestationsByAttester_SkipsBurned() public {
        _root(alice, "Alice");
        _root(bob, "Bob");
        uint256 bobRootId = identitySystem.ownerToRootId(bob);
        uint256 keptId = _token(alice);
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
        _root(alice, "Alice");
        uint256 tokenId = _token(alice);
        _root(bob, "Bob The Attester");
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

    /// @dev A profile is optional and separate from attesting, so the name shown is always
    ///      the root display name.
    function test_GetAttestersDetailed_IgnoresAttesterProfile() public {
        _root(alice, "Alice");
        uint256 tokenId = _token(alice);
        _root(bob, "Bob");
        DataTypes.ProfileMetadata memory meta = _meta("Bob Profile Name", "bob");
        meta.nationality = "US";
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

    /// @dev The address in the list must be enough to open the attester's wallet view:
    ///      their own tokens and root identity, without their profile.
    function test_GetAttestersDetailed_ResolvesAttesterWallet() public {
        _root(alice, "Alice");
        uint256 aliceToken = _token(alice);
        _root(bob, "John");
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
}
