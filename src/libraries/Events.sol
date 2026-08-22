// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Events {
    //  Root Identity
    event RootIdentityCreated(uint256 indexed rootId, address indexed owner, string username);

    //  Profile
    event ProfileCreated(uint256 indexed tokenId, address indexed owner, string username);

    //  Token
    event TokenCreated(uint256 indexed tokenId, uint256 indexed rootId, string tokenName, string tokenType);

    event TokenTransferred(uint256 indexed tokenId, address indexed from, address indexed to);

    event TokenBurned(uint256 indexed tokenId, uint256 indexed rootId);

    //  Endorsement
    event EndorsementGiven(uint256 indexed endorserRootId, uint256 indexed tokenId, uint256 expiresAt);

    event EndorsementRevoked(uint256 indexed endorserRootId, uint256 indexed tokenId, uint256 endorsementIndex);

    //  Flag
    event TokenFlagged(uint256 indexed tokenId, address indexed flagger, uint256 flagCount);

    event TokenAutoFlagged(uint256 indexed tokenId, string reason);

    // Admin
    event ProfileSystemSet(address indexed profileSystem);
}
