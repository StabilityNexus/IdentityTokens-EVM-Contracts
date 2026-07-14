// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Events } from "./Events.sol";

/**
 * @title Schema
 * @notice Abstract attribute store for root identities.
 *         Stores arbitrary key → value pairs per root token,
 *         enabling extensible metadata without struct changes.
 */
abstract contract Schema {
    // rootId → keyHash → value
    mapping(uint256 => mapping(bytes32 => bytes)) internal _rootAttributes;

    // ── Internal Mutations ───────────────────────────────────

    function _setRootAttribute(uint256 rootId, string memory key, bytes memory value) internal {
        bytes32 keyHash = keccak256(bytes(key));
        _rootAttributes[rootId][keyHash] = value;
        emit Events.RootAttributeSet(rootId, key, value);
    }

    function _deleteRootAttribute(uint256 rootId, string memory key) internal {
        bytes32 keyHash = keccak256(bytes(key));
        delete _rootAttributes[rootId][keyHash];
        emit Events.RootAttributeSet(rootId, key, "");
    }

    // ── Internal Views ───────────────────────────────────────

    function _getRootAttribute(uint256 rootId, string memory key) internal view returns (bytes memory) {
        return _rootAttributes[rootId][keccak256(bytes(key))];
    }

    function _hasRootAttribute(uint256 rootId, string memory key) internal view returns (bool) {
        return _rootAttributes[rootId][keccak256(bytes(key))].length > 0;
    }

    // ── Public Views ─────────────────────────────────────────

    function getRootAttribute(uint256 rootId, string calldata key) external view returns (bytes memory) {
        return _rootAttributes[rootId][keccak256(bytes(key))];
    }
}
