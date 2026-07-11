// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Events {
    //  Root Identity
    event RootIdentityCreated(uint256 indexed rootId, address indexed owner, string username);

    event RootAttributeSet(uint256 indexed rootId, string key, bytes value);

    //  Sub-token
    event SubTokenCreated(uint256 indexed subTokenId, uint256 indexed rootId, string tokenName, string tokenType);

    event SubTokenTransferred(uint256 indexed subTokenId, address indexed from, address indexed to);

    event SubTokenBurned(uint256 indexed subTokenId, uint256 indexed rootId);

    //  Endorsement
    event EndorsementGiven(uint256 indexed endorserRootId, uint256 indexed subTokenId, uint256 expiresAt);

    event EndorsementRevoked(uint256 indexed endorserRootId, uint256 indexed subTokenId, uint256 endorsementIndex);

    //  Flag
    event SubTokenFlagged(uint256 indexed subTokenId, address indexed flagger, uint256 flagCount);

    event SubTokenAutoFlagged(uint256 indexed subTokenId, string reason);
}
