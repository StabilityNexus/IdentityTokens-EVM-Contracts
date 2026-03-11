// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { TNT } from "../src/TNT.sol";
import { DataTypes } from "../src/libraries/DataTypes.sol";
import { Errors } from "../src/libraries/Errors.sol";
import { Events } from "../src/libraries/Events.sol";

contract TNTTest is Test {
    TNT public tnt;
    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public backup1 = address(4);

    event IdentityCreated(uint256 indexed tokenId, address indexed owner);
    event AttributeSet(uint256 indexed tokenId, bytes32 indexed keyHash, bytes value);
    event EndorsementGiven(uint256 indexed fromId, uint256 indexed toId, bytes32 typeHash, uint256 expiry);
    event EndorsementRevoked(uint256 indexed fromId, uint256 indexed toId, uint256 index);
    event BackupUpdateInitiated(uint256 indexed tokenId, address newBackup, uint256 unlockTime);
    event BackupUpdated(uint256 indexed tokenId, address newBackup);
    event IdentityRecovered(uint256 indexed tokenId, address newOwner);
    event IdentityCompromiseCleared(uint256 indexed tokenId);
    event TokenURISet(uint256 indexed tokenId, string uri);

    function setUp() public {
        vm.startPrank(owner);
        tnt = new TNT();
        vm.stopPrank();
    }

    function test_IssueToken() public {
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit IdentityCreated(1, user1);
        uint256 tokenId = tnt.issueToken();
        assertEq(tokenId, 1);
        assertEq(tnt.ownerOf(1), user1);
        // DIT spec: self-issued — issuer == caller
        assertEq(tnt.tokenIssuers(1), user1);
        vm.stopPrank();
    }

    function test_SetAndGetAttribute() public {
        vm.prank(user1);
        tnt.issueToken();

        vm.startPrank(user1);
        bytes32 key = keccak256("name");
        bytes memory val = "Alice";

        vm.expectEmit(true, true, false, true);
        emit AttributeSet(1, key, val);
        tnt.setAttribute(1, key, val);

        assertEq(tnt.getAttribute(1, key), val);
        vm.stopPrank();
    }

    function test_EndorsementLifecycle() public {
        vm.prank(user1);
        tnt.issueToken();
        vm.prank(user2);
        tnt.issueToken();

        vm.startPrank(user1);
        bytes32 connType = keccak256("friend");

        vm.expectEmit(true, true, false, true);
        emit EndorsementGiven(1, 2, connType, 0);
        tnt.giveEndorsement(1, 2, connType, 0);

        assertTrue(tnt.isEndorsementActive(1, 2, 0));

        vm.expectEmit(true, true, false, true);
        emit EndorsementRevoked(1, 2, 0);
        tnt.revokeEndorsement(1, 2, 0);

        assertFalse(tnt.isEndorsementActive(1, 2, 0));
        vm.stopPrank();
    }

    function test_Pagination() public {
        vm.prank(user1);
        tnt.issueToken();
        vm.prank(user2);
        tnt.issueToken();

        vm.startPrank(user1);
        for (uint i = 0; i < 5; i++) {
            tnt.giveEndorsement(1, 2, bytes32(uint256(i)), 0);
        }
        vm.stopPrank();

        DataTypes.Endorsement[] memory page = tnt.getEndorsements(2, 0, 3);
        assertEq(page.length, 3);

        DataTypes.Endorsement[] memory page2 = tnt.getEndorsements(2, 3, 10);
        assertEq(page2.length, 2); // clamped
    }

    function test_SoulboundTransferReverts() public {
        vm.prank(user1);
        tnt.issueToken();

        vm.startPrank(user1);
        vm.expectRevert("Soulbound: Transfer failed");
        tnt.transferFrom(user1, user2, 1);
        vm.stopPrank();
    }

    function test_BackupAndRecovery() public {
        vm.prank(user1);
        tnt.issueToken();

        // 1. Initiate backup update
        vm.startPrank(user1);
        tnt.initiateBackupUpdate(1, backup1);
        vm.stopPrank();

        // 2. Wrap time to pass timelock (2 days)
        vm.warp(block.timestamp + 2 days + 1);

        // 3. Confirm backup update
        vm.startPrank(user1);
        tnt.confirmBackupUpdate(1);
        vm.stopPrank();

        DataTypes.IdentityState memory state = tnt.getIdentityState(1);
        assertEq(state.backupWallet, backup1);

        // 4. Mark compromised by owner
        vm.startPrank(owner);
        tnt.markCompromised(1);
        vm.stopPrank();

        state = tnt.getIdentityState(1);
        assertTrue(state.isCompromised);

        // 5. Recover identity
        vm.startPrank(backup1);
        tnt.recoverIdentity(1, user2);
        vm.stopPrank();

        assertEq(tnt.ownerOf(1), user2);
        state = tnt.getIdentityState(1);
        assertFalse(state.isCompromised);
    }

    function test_SetAndGetTokenURI() public {
        vm.prank(user1);
        tnt.issueToken();

        vm.startPrank(user1);
        vm.expectEmit(true, false, false, true);
        emit TokenURISet(1, "ipfs://QmTest/1");
        tnt.setTokenURI(1, "ipfs://QmTest/1");
        vm.stopPrank();

        assertEq(tnt.tokenURI(1), "ipfs://QmTest/1");
    }

    function test_GetEndorsementCount() public {
        vm.prank(user1);
        tnt.issueToken();
        vm.prank(user2);
        tnt.issueToken();

        assertEq(tnt.getEndorsementCount(2), 0);
        assertEq(tnt.getGivenEndorsementCount(1), 0);

        vm.prank(user1);
        tnt.giveEndorsement(1, 2, keccak256("friend"), 0);

        assertEq(tnt.getEndorsementCount(2), 1);
        assertEq(tnt.getGivenEndorsementCount(1), 1);
    }

    function test_GetGivenEndorsements() public {
        vm.prank(user1);
        tnt.issueToken();
        vm.prank(user2);
        tnt.issueToken();

        vm.prank(user1);
        tnt.giveEndorsement(1, 2, keccak256("colleague"), 0);

        DataTypes.GivenEndorsement[] memory given = tnt.getGivenEndorsements(1, 0, 1);
        assertEq(given.length, 1);
        assertEq(given[0].toTokenId, 2);
        assertEq(given[0].endorsementIndex, 0);
    }

    function test_ReverseIndexConsistency() public {
        vm.prank(user1);
        tnt.issueToken(); // tokenId 1
        vm.prank(user2);
        tnt.issueToken(); // tokenId 2
        address user3 = address(5);
        vm.prank(user3);
        tnt.issueToken(); // tokenId 3

        vm.startPrank(user1);
        tnt.giveEndorsement(1, 2, keccak256("friend"), 0);
        tnt.giveEndorsement(1, 3, keccak256("colleague"), 0);
        vm.stopPrank();

        // token 1 has given 2 endorsements
        assertEq(tnt.getGivenEndorsementCount(1), 2);
        // token 2 has received 1 endorsement
        assertEq(tnt.getEndorsementCount(2), 1);
        // token 3 has received 1 endorsement
        assertEq(tnt.getEndorsementCount(3), 1);

        // verify forward and reverse index agree
        DataTypes.GivenEndorsement[] memory given = tnt.getGivenEndorsements(1, 0, 2);
        DataTypes.Endorsement[] memory recv2 = tnt.getEndorsements(2, 0, 1);
        assertEq(recv2[given[0].endorsementIndex].endorserTokenId, 1);
    }
}
