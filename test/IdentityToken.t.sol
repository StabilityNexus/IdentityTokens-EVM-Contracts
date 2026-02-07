// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/IdentityToken.sol";
import "../src/libraries/DataTypes.sol";

contract IdentityTokenTest is Test {
    IdentityToken public token;
    address public user1 = address(1);
    address public user2 = address(2);

    function setUp() public {
        token = new IdentityToken();
    }

    function testMint() public {
        vm.startPrank(user1);
        uint256 tokenId = token.mint();
        assertEq(token.ownerOf(tokenId), user1);
        assertEq(tokenId, 1);
        vm.stopPrank();
    }

    function testSetProfile() public {
        vm.startPrank(user1);
        uint256 tokenId = token.mint();
        
        DataTypes.IdentityProfile memory profile = DataTypes.IdentityProfile({
            name: "Alice",
            socialLinks: "twitter.com/alice",
            birthDate: 1000,
            nationality: "Wonderland",
            residence: "Rabbit Hole"
        });

        token.setProfile(tokenId, profile);
        
        (string memory name,,,,) = token.profiles(tokenId);
        assertEq(name, "Alice");
        vm.stopPrank();
    }

    function testEndorse() public {
        vm.startPrank(user1);
        uint256 tokenId1 = token.mint();
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 tokenId2 = token.mint();
        
        // User2 endorses User1
        bytes32 connectionType = keccak256("friend");
        token.endorse(tokenId2, tokenId1, connectionType, 0);
        
        uint256[] memory endorsers = token.getEndorsers(tokenId1);
        assertEq(endorsers.length, 1);
        assertEq(endorsers[0], tokenId2);
        vm.stopPrank();
    }
}
