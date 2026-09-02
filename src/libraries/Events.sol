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

    //  Attestation
    event AttestationGiven(uint256 indexed attesterRootId, uint256 indexed tokenId, uint256 expiresAt);

    event AttestationRevoked(uint256 indexed attesterRootId, uint256 indexed tokenId, uint256 attestationIndex);

    //  Flag
    event TokenFlagged(uint256 indexed tokenId, address indexed flagger, uint256 flagCount);

    event TokenAutoFlagged(uint256 indexed tokenId, string reason);

    // Admin
    event ProfileSystemSet(address indexed profileSystem);
}
