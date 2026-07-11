// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DataTypes } from "../libraries/DataTypes.sol";
import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";

abstract contract EndorsementModule {
    // Endorsement storage: subTokenId → array of all endorsements
    mapping(uint256 => DataTypes.Endorsement[]) internal _endorsements;

    // Quick lookup: endorserRootId → subTokenId → index in _endorsements array
    mapping(uint256 => mapping(uint256 => uint256)) internal _activeEndorsementIndex;

    // Whether the endorser currently has a non-revoked, non-expired endorsement
    mapping(uint256 => mapping(uint256 => bool)) internal _hasActiveEndorsement;

    // Reverse index: endorserRootId → list of subTokenIds they've ever endorsed
    mapping(uint256 => uint256[]) internal _endorserSubTokenIds;

    // Whether the endorser has ever endorsed this subToken (for dedup of reverse index)
    mapping(uint256 => mapping(uint256 => bool)) internal _endorserTracked;

    mapping(uint256 => mapping(uint256 => bool)) internal _endorserCounted;

    mapping(uint256 => mapping(uint256 => bool)) internal _revokerCounted;

    // External Functions

    function endorseSubToken(uint256 subTokenId, uint256 duration) external {
        uint256 endorserRootId = _getCallerRootId();
        if (endorserRootId == 0) revert Errors.NoRootIdentity();

        _requireSubTokenActive(subTokenId);
        _requireNotSelfEndorsement(endorserRootId, subTokenId);

        if (_hasActiveEndorsement[endorserRootId][subTokenId]) {
            DataTypes.Endorsement storage prev = _endorsements[subTokenId][
                _activeEndorsementIndex[endorserRootId][subTokenId]
            ];
            if (prev.revokedAt == 0 && prev.expiresAt > block.timestamp) revert Errors.AlreadyEndorsed();
        }

        uint256 expiresAt = block.timestamp + duration;
        uint256 subTokenValidUntil = _getSubTokenValidUntil(subTokenId);
        if (subTokenValidUntil != 0 && expiresAt > subTokenValidUntil) {
            expiresAt = subTokenValidUntil;
        }

        uint256 newIndex = _endorsements[subTokenId].length;

        _endorsements[subTokenId].push(
            DataTypes.Endorsement({
                endorserTokenId: endorserRootId,
                endorserAddress: msg.sender,
                timestamp: block.timestamp,
                revokedAt: 0,
                expiresAt: expiresAt
            })
        );

        _activeEndorsementIndex[endorserRootId][subTokenId] = newIndex;
        _hasActiveEndorsement[endorserRootId][subTokenId] = true;

        // Track in reverse index (only once per endorser-subToken pair)
        if (!_endorserTracked[endorserRootId][subTokenId]) {
            _endorserSubTokenIds[endorserRootId].push(subTokenId);
            _endorserTracked[endorserRootId][subTokenId] = true;
        }

        if (!_endorserCounted[endorserRootId][subTokenId]) {
            _endorserCounted[endorserRootId][subTokenId] = true;
            _incrementTotalEndorsementCount(subTokenId);
        }

        emit Events.EndorsementGiven(endorserRootId, subTokenId, expiresAt);
    }

    function revokeEndorsement(uint256 subTokenId) external {
        uint256 endorserRootId = _getCallerRootId();
        if (endorserRootId == 0) revert Errors.NoRootIdentity();

        if (!_hasActiveEndorsement[endorserRootId][subTokenId]) revert Errors.NoActiveEndorsement();

        uint256 endorsementIndex = _activeEndorsementIndex[endorserRootId][subTokenId];
        DataTypes.Endorsement storage e = _endorsements[subTokenId][endorsementIndex];

        // Verify the cached endorsement is actually still active
        if (e.endorserTokenId != endorserRootId) revert Errors.NotYourEndorsement();
        if (e.revokedAt != 0) revert Errors.AlreadyRevoked();
        if (e.expiresAt <= block.timestamp) revert Errors.EndorsementExpired();

        e.revokedAt = block.timestamp;

        _hasActiveEndorsement[endorserRootId][subTokenId] = false;

        if (!_revokerCounted[endorserRootId][subTokenId]) {
            _revokerCounted[endorserRootId][subTokenId] = true;
            _incrementRevokedCount(subTokenId);
        }

        emit Events.EndorsementRevoked(endorserRootId, subTokenId, endorsementIndex);

        _checkFlaggingThreshold(subTokenId);
    }

    // View Functions
    function getEndorsements(uint256 subTokenId) external view returns (DataTypes.Endorsement[] memory) {
        return _endorsements[subTokenId];
    }

    function getActiveEndorsements(uint256 subTokenId) external view returns (DataTypes.Endorsement[] memory) {
        DataTypes.Endorsement[] storage all = _endorsements[subTokenId];

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

    function getActiveEndorsementCount(uint256 subTokenId) external view returns (uint256) {
        DataTypes.Endorsement[] storage all = _endorsements[subTokenId];
        uint256 activeCount = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].revokedAt == 0 && all[i].expiresAt > block.timestamp) {
                activeCount++;
            }
        }
        return activeCount;
    }

    function getEndorsementsByEndorser(uint256 endorserRootId) external view returns (uint256[] memory subTokenIds) {
        uint256[] storage allIds = _endorserSubTokenIds[endorserRootId];

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

        subTokenIds = new uint256[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < allIds.length; i++) {
            uint256 subId = allIds[i];
            if (_hasActiveEndorsement[endorserRootId][subId]) {
                DataTypes.Endorsement storage e = _endorsements[subId][_activeEndorsementIndex[endorserRootId][subId]];
                if (e.revokedAt == 0 && e.expiresAt > block.timestamp) {
                    subTokenIds[j++] = allIds[i];
                }
            }
        }
    }

    function hasEndorsed(uint256 endorserRootId, uint256 subTokenId) external view returns (bool) {
        if (!_hasActiveEndorsement[endorserRootId][subTokenId]) return false;
        DataTypes.Endorsement storage e = _endorsements[subTokenId][
            _activeEndorsementIndex[endorserRootId][subTokenId]
        ];
        return e.revokedAt == 0 && e.expiresAt > block.timestamp;
    }

    // Abstract Hooks

    function _getCallerRootId() internal view virtual returns (uint256);

    function _requireSubTokenActive(uint256 id) internal view virtual;

    function _requireNotSelfEndorsement(uint256 endorserRootId, uint256 subTokenId) internal view virtual;

    function _incrementTotalEndorsementCount(uint256 subTokenId) internal virtual;

    function _checkFlaggingThreshold(uint256 subTokenId) internal virtual;

    function _incrementRevokedCount(uint256 subTokenId) internal virtual;

    function _getSubTokenValidUntil(uint256 id) internal view virtual returns (uint256);
}
