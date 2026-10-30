// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "../utils/BaseTest.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { Errors } from "../../src/libraries/Errors.sol";

contract TokenIdsTest is BaseTest {
    // Pinned values: dit/lib/tokenId.ts mirrors this formula and checks the same ids
    function test_TokenIds_PerTypeSerials() public {
        uint256 profileId = _profile(alice, "alice");
        uint256 subId = _token(alice);
        uint256 bobRootId = _root(bob, "Bob");

        assertEq(identitySystem.ownerToRootId(alice), 16180339887);
        assertEq(bobRootId, 12360679774);
        assertEq(subId, 29321932540);
        assertEq(profileId, 32463525193);
        assertEq(identitySystem.minted(uint256(DataTypes.TokenType.ROOT)), 2);
        assertEq(identitySystem.minted(uint256(DataTypes.TokenType.SUB)), 1);
        assertEq(identitySystem.minted(uint256(DataTypes.TokenType.PROFILE)), 1);
    }

    function test_FormatTokenId() public view {
        assertEq(identitySystem.formatTokenId(16180339887), "id-6180339887");
        assertEq(identitySystem.formatTokenId(10901699435), "id-0901699435");
        assertEq(identitySystem.formatTokenId(29321932540), "tk-9321932540");
        assertEq(identitySystem.formatTokenId(32463525193), "pf-2463525193");
    }

    function test_TokenURI() public {
        uint256 profileId = _profile(alice, "alice");
        string memory json = '{"name":"DIT Profile pf-2463525193"}';

        assertEq(
            identitySystem.tokenURI(profileId),
            string.concat("data:application/json;base64,", Base64.encode(bytes(json)))
        );
        assertEq(
            identitySystem.tokenURI(identitySystem.ownerToRootId(alice)),
            string.concat(
                "data:application/json;base64,",
                Base64.encode(bytes('{"name":"DIT Root Identity id-6180339887"}'))
            )
        );
    }

    function test_RevertIf_TokenTypeOf_InvalidId() public {
        vm.expectRevert(Errors.InvalidTokenId.selector);
        identitySystem.tokenTypeOf(0);
        vm.expectRevert(Errors.InvalidTokenId.selector);
        identitySystem.tokenTypeOf(5);
        vm.expectRevert(Errors.InvalidTokenId.selector);
        identitySystem.tokenTypeOf(4e10);
    }

    function test_RevertIf_AttestToken_UnknownId() public {
        _root(bob, "Bob");

        vm.prank(bob);
        vm.expectRevert(Errors.NotToken.selector);
        identitySystem.attestToken(5, 365 days);

        vm.prank(bob);
        vm.expectRevert(Errors.NotToken.selector);
        identitySystem.attestToken(29999999999, 365 days);
    }
}
