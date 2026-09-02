// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";

abstract contract FlagModule {
    uint256 internal constant MIN_ATTESTATIONS_FOR_AUTO_FLAG = 20;

    // Tracks which root identity has already flagged a given token
    mapping(uint256 => mapping(uint256 => bool)) internal _hasRootFlagged;

    // Tracks whether auto-flagging has already triggered for a token
    // (separate from manual flagCount so manual flags don't block auto-flagging)
    mapping(uint256 => bool) internal _autoFlagged;

    // Manual Flagging

    function flagToken(uint256 tokenId) external {
        uint256 callerRootId = _getCallerRootId();
        if (callerRootId == 0) revert Errors.NoRootIdentity();

        _requireTokenActive(tokenId);
        _requireNotSelfFlag(callerRootId, tokenId);

        if (_hasRootFlagged[callerRootId][tokenId]) revert Errors.AlreadyFlaggedByRoot();

        _hasRootFlagged[callerRootId][tokenId] = true;
        _incrementFlagCount(tokenId);

        emit Events.TokenFlagged(tokenId, msg.sender, _getFlagCount(tokenId));
    }

    // Auto-Flagging (attestation revocation threshold)

    function _checkFlaggingThresholdInternal(uint256 tokenId) internal {
        uint256 attestationCount = _getTotalAttestationCount(tokenId);

        if (attestationCount >= MIN_ATTESTATIONS_FOR_AUTO_FLAG && !_autoFlagged[tokenId]) {
            uint256 revokedCount = _countRevokedAttestations(tokenId);

            // Auto-flags if >= 1/3rd of original attestations are revoked
            if (revokedCount * 3 >= attestationCount) {
                _autoFlagged[tokenId] = true;
                _incrementFlagCount(tokenId);
                _setFlagged(tokenId, true);

                emit Events.TokenAutoFlagged(tokenId, "Attestation revocation threshold exceeded");
            }
        }
    }

    // Hooks

    function _getCallerRootId() internal view virtual returns (uint256);

    function _requireTokenActive(uint256 id) internal view virtual;

    function _countRevokedAttestations(uint256 tokenId) internal view virtual returns (uint256);

    function _incrementFlagCount(uint256 id) internal virtual;

    function _getFlagCount(uint256 id) internal view virtual returns (uint256);

    function _setFlagged(uint256 id, bool flagged) internal virtual;

    function _getTotalAttestationCount(uint256 id) internal view virtual returns (uint256);

    function _requireNotSelfFlag(uint256 callerRootId, uint256 tokenId) internal view virtual;
}
