// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library DataTypes {
    enum TokenType {
        ROOT,
        SUB
    }

    struct RootIdentity {
        string username;
        uint256 tokenId;
        address owner;
        uint256 createdAt;
        bool isActive;
        bytes32 metadataHash;
    }

    struct SubToken {
        uint256 subTokenId;
        uint256 parentRootId;
        string tokenName;
        string tokenType;
        bytes tokenValue;
        string about;
        uint256 validUntil;
        uint256 createdAt;
        uint256 totalEndorsementCount;
        uint256 revokedCount;
        bool isFlagged;
        uint256 flagCount;
        uint256 transferCount;
    }

    struct RootIdentityView {
        uint256 tokenId;
        string username;
        address owner;
        uint256 createdAt;
        bool isActive;
        uint256 subTokenCount;
    }

    struct Endorsement {
        uint256 endorserTokenId;
        address endorserAddress;
        uint256 timestamp;
        uint256 revokedAt;
        uint256 expiresAt;
    }
}
