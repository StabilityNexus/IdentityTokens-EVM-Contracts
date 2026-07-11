// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";

abstract contract FlagModule {
    uint256 internal constant MIN_ENDORSEMENTS_FOR_AUTO_FLAG = 20;

    // Tracks which root identity has already flagged a given sub-token
    mapping(uint256 => mapping(uint256 => bool)) internal _hasRootFlagged;

    // Tracks whether auto-flagging has already triggered for a sub-token
    // (separate from manual flagCount so manual flags don't block auto-flagging)
    mapping(uint256 => bool) internal _autoFlagged;

    // Manual Flagging

    function flagSubToken(uint256 subTokenId) external {
        uint256 callerRootId = _getCallerRootId();
        if (callerRootId == 0) revert Errors.NoRootIdentity();

        _requireSubTokenActive(subTokenId);
        _requireNotSelfFlag(callerRootId, subTokenId);

        if (_hasRootFlagged[callerRootId][subTokenId]) revert Errors.AlreadyFlaggedByRoot();

        _hasRootFlagged[callerRootId][subTokenId] = true;
        _incrementFlagCount(subTokenId);

        emit Events.SubTokenFlagged(subTokenId, msg.sender, _getFlagCount(subTokenId));
    }

    // Auto-Flagging (endorsement revocation threshold)

    function _checkFlaggingThresholdInternal(uint256 subTokenId) internal {
        uint256 endorsementCount = _getTotalEndorsementCount(subTokenId);

        if (endorsementCount >= MIN_ENDORSEMENTS_FOR_AUTO_FLAG && !_autoFlagged[subTokenId]) {
            uint256 revokedCount = _countRevokedEndorsements(subTokenId);

            // Auto-flags if >= 1/3rd of original endorsements are revoked
            if (revokedCount * 3 >= endorsementCount) {
                _autoFlagged[subTokenId] = true;
                _incrementFlagCount(subTokenId);
                _setFlagged(subTokenId, true);

                emit Events.SubTokenAutoFlagged(subTokenId, "Endorsement revocation threshold exceeded");
            }
        }
    }

    // Hooks

    function _getCallerRootId() internal view virtual returns (uint256);

    function _requireSubTokenActive(uint256 id) internal view virtual;

    function _countRevokedEndorsements(uint256 subTokenId) internal view virtual returns (uint256);

    function _incrementFlagCount(uint256 id) internal virtual;

    function _getFlagCount(uint256 id) internal view virtual returns (uint256);

    function _setFlagged(uint256 id, bool flagged) internal virtual;

    function _getTotalEndorsementCount(uint256 id) internal view virtual returns (uint256);

    function _requireNotSelfFlag(uint256 callerRootId, uint256 subTokenId) internal view virtual;
}
