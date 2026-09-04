// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library DataTypes {
    enum TokenType {
        ROOT,
        SUB,
        PROFILE
    }

    struct RootIdentity {
        address walletAddress;
        string displayName;
        uint256 tokenId;
        uint256 createdAt;
        bool isActive;
    }

    struct Token {
        uint256 tokenId;
        uint256 parentRootId;
        string tokenName;
        string tokenType;
        bytes tokenValue;
        string about;
        uint256 validUntil;
        uint256 createdAt;
        uint256 totalAttestationCount;
        uint256 revokedCount;
        bool isFlagged;
        uint256 flagCount;
        uint256 transferCount;
    }

    struct RootIdentityView {
        uint256 tokenId;
        address walletAddress;
        string displayName;
        uint256 createdAt;
        bool isActive;
        uint256 tokenCount;
    }

    struct Attestation {
        uint256 attesterTokenId;
        address attesterAddress;
        uint256 timestamp;
        uint256 revokedAt;
        uint256 expiresAt;
    }

    struct AttesterView {
        uint256 rootId;
        address wallet;
        string displayName;
        uint256 profileTokenId;
        uint256 timestamp;
        uint256 revokedAt;
        uint256 expiresAt;
    }

    struct ProfileMetadata {
        string name;
        string username;
        string nationality;
        string github;
        string email;
        string discord;
        string xDotCom;
        string websitePortfolioLink;
        string ens;
    }
}
