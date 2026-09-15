// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DataTypes } from "../libraries/DataTypes.sol";
import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";

abstract contract AttestationModule {
    // Attestation storage: tokenId → array of all attestations
    mapping(uint256 => DataTypes.Attestation[]) internal _attestations;

    // Quick lookup: attesterRootId → tokenId → index in _attestations array
    mapping(uint256 => mapping(uint256 => uint256)) internal _activeAttestationIndex;

    // Whether the attester currently has a non-revoked, non-expired attestation
    mapping(uint256 => mapping(uint256 => bool)) internal _hasActiveAttestation;

    // Reverse index: attesterRootId → list of tokenIds they've ever attested
    mapping(uint256 => uint256[]) internal _attesterTokenIds;

    // Whether the attester has ever attested this token (for dedup of reverse index)
    mapping(uint256 => mapping(uint256 => bool)) internal _attesterTracked;

    mapping(uint256 => mapping(uint256 => bool)) internal _attesterCounted;

    mapping(uint256 => mapping(uint256 => bool)) internal _revokerCounted;

    // External Functions

    function attestToken(uint256 tokenId, uint256 duration) external {
        uint256 attesterRootId = _getCallerRootId();
        if (attesterRootId == 0) revert Errors.NoRootIdentity();

        _requireTokenActive(tokenId);
        _requireNotSelfAttestation(attesterRootId, tokenId);

        if (_hasActiveAttestation[attesterRootId][tokenId]) {
            DataTypes.Attestation storage prev = _attestations[tokenId][
                _activeAttestationIndex[attesterRootId][tokenId]
            ];
            if (_isAttestationActive(prev)) revert Errors.AlreadyAttested();
        }

        uint256 expiresAt = block.timestamp + duration;
        uint256 tokenValidUntil = _getTokenValidUntil(tokenId);
        if (tokenValidUntil != 0 && expiresAt > tokenValidUntil) {
            expiresAt = tokenValidUntil;
        }

        uint256 newIndex = _attestations[tokenId].length;

        _attestations[tokenId].push(
            DataTypes.Attestation({
                attesterTokenId: attesterRootId,
                attesterAddress: msg.sender,
                timestamp: block.timestamp,
                revokedAt: 0,
                expiresAt: expiresAt
            })
        );

        _activeAttestationIndex[attesterRootId][tokenId] = newIndex;
        _hasActiveAttestation[attesterRootId][tokenId] = true;

        // Track in reverse index (only once per attester-token pair)
        if (!_attesterTracked[attesterRootId][tokenId]) {
            _attesterTokenIds[attesterRootId].push(tokenId);
            _attesterTracked[attesterRootId][tokenId] = true;
        }

        if (!_attesterCounted[attesterRootId][tokenId]) {
            _attesterCounted[attesterRootId][tokenId] = true;
            _incrementTotalAttestationCount(tokenId);
        }

        emit Events.AttestationGiven(attesterRootId, tokenId, expiresAt);
    }

    function revokeAttestation(uint256 tokenId) external {
        uint256 attesterRootId = _getCallerRootId();
        if (attesterRootId == 0) revert Errors.NoRootIdentity();

        if (!_hasActiveAttestation[attesterRootId][tokenId]) revert Errors.NoActiveAttestation();

        uint256 attestationIndex = _activeAttestationIndex[attesterRootId][tokenId];
        DataTypes.Attestation storage e = _attestations[tokenId][attestationIndex];

        // Verify the cached attestation is actually still active
        if (e.attesterTokenId != attesterRootId) revert Errors.NotYourAttestation();
        if (e.revokedAt != 0) revert Errors.AlreadyRevoked();
        if (e.expiresAt <= block.timestamp) revert Errors.AttestationExpired();

        e.revokedAt = block.timestamp;

        _hasActiveAttestation[attesterRootId][tokenId] = false;

        if (!_revokerCounted[attesterRootId][tokenId]) {
            _revokerCounted[attesterRootId][tokenId] = true;
            _incrementRevokedCount(tokenId);
        }

        emit Events.AttestationRevoked(attesterRootId, tokenId, attestationIndex);

        _checkFlaggingThreshold(tokenId);
    }

    // View Functions
    function getAttestations(uint256 tokenId) external view returns (DataTypes.Attestation[] memory) {
        return _attestations[tokenId];
    }

    function getActiveAttestations(uint256 tokenId) external view returns (DataTypes.Attestation[] memory) {
        DataTypes.Attestation[] storage all = _attestations[tokenId];

        uint256 activeCount = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (_isAttestationActive(all[i])) {
                activeCount++;
            }
        }

        DataTypes.Attestation[] memory result = new DataTypes.Attestation[](activeCount);
        uint256 j = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (_isAttestationActive(all[i])) {
                result[j++] = all[i];
            }
        }
        return result;
    }

    function getActiveAttestationCount(uint256 tokenId) external view returns (uint256) {
        DataTypes.Attestation[] storage all = _attestations[tokenId];
        uint256 activeCount = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (_isAttestationActive(all[i])) {
                activeCount++;
            }
        }
        return activeCount;
    }

    function getAttestationsByAttester(uint256 attesterRootId) external view returns (uint256[] memory tokenIds) {
        uint256[] storage allIds = _attesterTokenIds[attesterRootId];

        uint256 count = 0;
        for (uint256 i = 0; i < allIds.length; i++) {
            uint256 subId = allIds[i];
            if (_hasActiveAttestation[attesterRootId][subId]) {
                DataTypes.Attestation storage e = _attestations[subId][_activeAttestationIndex[attesterRootId][subId]];
                if (_isAttestationActive(e)) {
                    count++;
                }
            }
        }

        tokenIds = new uint256[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < allIds.length; i++) {
            uint256 subId = allIds[i];
            if (_hasActiveAttestation[attesterRootId][subId]) {
                DataTypes.Attestation storage e = _attestations[subId][_activeAttestationIndex[attesterRootId][subId]];
                if (_isAttestationActive(e)) {
                    tokenIds[j++] = allIds[i];
                }
            }
        }
    }

    function getAttestationsPaged(
        uint256 tokenId,
        uint256 offset,
        uint256 limit
    ) external view returns (DataTypes.Attestation[] memory page, uint256 total) {
        DataTypes.Attestation[] storage all = _attestations[tokenId];
        total = all.length;

        if (offset >= total || limit == 0) return (new DataTypes.Attestation[](0), total);

        uint256 remaining = total - offset;
        uint256 size = limit < remaining ? limit : remaining;

        page = new DataTypes.Attestation[](size);
        for (uint256 i = 0; i < size; i++) {
            page[i] = all[offset + i];
        }
    }

    function hasAttested(uint256 attesterRootId, uint256 tokenId) external view returns (bool) {
        if (!_hasActiveAttestation[attesterRootId][tokenId]) return false;
        DataTypes.Attestation storage e = _attestations[tokenId][_activeAttestationIndex[attesterRootId][tokenId]];
        return _isAttestationActive(e);
    }

    // Internal Helpers

    function _isAttestationActive(DataTypes.Attestation storage attestation) internal view returns (bool) {
        return attestation.revokedAt == 0 && attestation.expiresAt > block.timestamp;
    }

    // Abstract Hooks

    function _getCallerRootId() internal view virtual returns (uint256);

    function _requireTokenActive(uint256 id) internal view virtual;

    function _requireNotSelfAttestation(uint256 attesterRootId, uint256 tokenId) internal view virtual;

    function _incrementTotalAttestationCount(uint256 tokenId) internal virtual;

    function _checkFlaggingThreshold(uint256 tokenId) internal virtual;

    function _incrementRevokedCount(uint256 tokenId) internal virtual;

    function _getTokenValidUntil(uint256 id) internal view virtual returns (uint256);
}
