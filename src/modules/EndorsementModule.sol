// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DataTypes } from "../libraries/DataTypes.sol";
import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";

abstract contract EndorsementModule {
    // Endorsement storage: tokenId → array of all endorsements
    mapping(uint256 => DataTypes.Endorsement[]) internal _endorsements;

    // Quick lookup: endorserRootId → tokenId → index in _endorsements array
    mapping(uint256 => mapping(uint256 => uint256)) internal _activeEndorsementIndex;

    // Whether the endorser currently has a non-revoked, non-expired endorsement
    mapping(uint256 => mapping(uint256 => bool)) internal _hasActiveEndorsement;

    // Reverse index: endorserRootId → list of tokenIds they've ever endorsed
    mapping(uint256 => uint256[]) internal _endorserTokenIds;

    // Whether the endorser has ever endorsed this token (for dedup of reverse index)
    mapping(uint256 => mapping(uint256 => bool)) internal _endorserTracked;

    mapping(uint256 => mapping(uint256 => bool)) internal _endorserCounted;

    mapping(uint256 => mapping(uint256 => bool)) internal _revokerCounted;

    // External Functions

    function endorseToken(uint256 tokenId, uint256 duration) external {
        uint256 endorserRootId = _getCallerRootId();
        if (endorserRootId == 0) revert Errors.NoRootIdentity();

        _requireTokenActive(tokenId);
        _requireNotSelfEndorsement(endorserRootId, tokenId);

        if (_hasActiveEndorsement[endorserRootId][tokenId]) {
            DataTypes.Endorsement storage prev = _endorsements[tokenId][
                _activeEndorsementIndex[endorserRootId][tokenId]
            ];
            if (prev.revokedAt == 0 && prev.expiresAt > block.timestamp) revert Errors.AlreadyEndorsed();
        }

        uint256 expiresAt = block.timestamp + duration;
        uint256 tokenValidUntil = _getTokenValidUntil(tokenId);
        if (tokenValidUntil != 0 && expiresAt > tokenValidUntil) {
            expiresAt = tokenValidUntil;
        }

        uint256 newIndex = _endorsements[tokenId].length;

        _endorsements[tokenId].push(
            DataTypes.Endorsement({
                endorserTokenId: endorserRootId,
                endorserAddress: msg.sender,
                timestamp: block.timestamp,
                revokedAt: 0,
                expiresAt: expiresAt
            })
        );

        _activeEndorsementIndex[endorserRootId][tokenId] = newIndex;
        _hasActiveEndorsement[endorserRootId][tokenId] = true;

        // Track in reverse index (only once per endorser-token pair)
        if (!_endorserTracked[endorserRootId][tokenId]) {
            _endorserTokenIds[endorserRootId].push(tokenId);
            _endorserTracked[endorserRootId][tokenId] = true;
        }

        if (!_endorserCounted[endorserRootId][tokenId]) {
            _endorserCounted[endorserRootId][tokenId] = true;
            _incrementTotalEndorsementCount(tokenId);
        }

        emit Events.EndorsementGiven(endorserRootId, tokenId, expiresAt);
    }

    function revokeEndorsement(uint256 tokenId) external {
        uint256 endorserRootId = _getCallerRootId();
        if (endorserRootId == 0) revert Errors.NoRootIdentity();

        if (!_hasActiveEndorsement[endorserRootId][tokenId]) revert Errors.NoActiveEndorsement();

        uint256 endorsementIndex = _activeEndorsementIndex[endorserRootId][tokenId];
        DataTypes.Endorsement storage e = _endorsements[tokenId][endorsementIndex];

        // Verify the cached endorsement is actually still active
        if (e.endorserTokenId != endorserRootId) revert Errors.NotYourEndorsement();
        if (e.revokedAt != 0) revert Errors.AlreadyRevoked();
        if (e.expiresAt <= block.timestamp) revert Errors.EndorsementExpired();

        e.revokedAt = block.timestamp;

        _hasActiveEndorsement[endorserRootId][tokenId] = false;

        if (!_revokerCounted[endorserRootId][tokenId]) {
            _revokerCounted[endorserRootId][tokenId] = true;
            _incrementRevokedCount(tokenId);
        }

        emit Events.EndorsementRevoked(endorserRootId, tokenId, endorsementIndex);

        _checkFlaggingThreshold(tokenId);
    }

    // View Functions
    function getEndorsements(uint256 tokenId) external view returns (DataTypes.Endorsement[] memory) {
        return _endorsements[tokenId];
    }

    function getActiveEndorsements(uint256 tokenId) external view returns (DataTypes.Endorsement[] memory) {
        DataTypes.Endorsement[] storage all = _endorsements[tokenId];

        uint256 activeCount = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].revokedAt == 0 && all[i].expiresAt > block.timestamp) {
                activeCount++;
            }
        }

        DataTypes.Endorsement[] memory result = new DataTypes.Endorsement[](activeCount);
        uint256 j = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].revokedAt == 0 && all[i].expiresAt > block.timestamp) {
                result[j++] = all[i];
            }
        }
        return result;
    }

    function getActiveEndorsementCount(uint256 tokenId) external view returns (uint256) {
        DataTypes.Endorsement[] storage all = _endorsements[tokenId];
        uint256 activeCount = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].revokedAt == 0 && all[i].expiresAt > block.timestamp) {
                activeCount++;
            }
        }
        return activeCount;
    }

    function getEndorsementsByEndorser(uint256 endorserRootId) external view returns (uint256[] memory tokenIds) {
        uint256[] storage allIds = _endorserTokenIds[endorserRootId];

        uint256 count = 0;
        for (uint256 i = 0; i < allIds.length; i++) {
            uint256 subId = allIds[i];
            if (_hasActiveEndorsement[endorserRootId][subId]) {
                DataTypes.Endorsement storage e = _endorsements[subId][_activeEndorsementIndex[endorserRootId][subId]];
                if (e.revokedAt == 0 && e.expiresAt > block.timestamp) {
                    count++;
                }
            }
        }

        tokenIds = new uint256[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < allIds.length; i++) {
            uint256 subId = allIds[i];
            if (_hasActiveEndorsement[endorserRootId][subId]) {
                DataTypes.Endorsement storage e = _endorsements[subId][_activeEndorsementIndex[endorserRootId][subId]];
                if (e.revokedAt == 0 && e.expiresAt > block.timestamp) {
                    tokenIds[j++] = allIds[i];
                }
            }
        }
    }

    function hasEndorsed(uint256 endorserRootId, uint256 tokenId) external view returns (bool) {
        if (!_hasActiveEndorsement[endorserRootId][tokenId]) return false;
        DataTypes.Endorsement storage e = _endorsements[tokenId][
            _activeEndorsementIndex[endorserRootId][tokenId]
        ];
        return e.revokedAt == 0 && e.expiresAt > block.timestamp;
    }

    // Abstract Hooks

    function _getCallerRootId() internal view virtual returns (uint256);

    function _requireTokenActive(uint256 id) internal view virtual;

    function _requireNotSelfEndorsement(uint256 endorserRootId, uint256 tokenId) internal view virtual;

    function _incrementTotalEndorsementCount(uint256 tokenId) internal virtual;

    function _checkFlaggingThreshold(uint256 tokenId) internal virtual;

    function _incrementRevokedCount(uint256 tokenId) internal virtual;

    function _getTokenValidUntil(uint256 id) internal view virtual returns (uint256);
}
