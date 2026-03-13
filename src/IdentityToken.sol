// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { DataTypes } from "./libraries/DataTypes.sol";
import { Errors } from "./libraries/Errors.sol";
import { Events } from "./libraries/Events.sol";

contract IdentityToken is ERC721 {
    error NonTransferable();

    uint256 private _nextTokenId = 1;

    mapping(address => uint256) public ownerToTokenId;
    mapping(uint256 => DataTypes.IdentityState) public identityStates;
    mapping(uint256 => mapping(bytes32 => bytes)) public attributes;
    mapping(uint256 => DataTypes.Endorsement[]) public endorsements;

    modifier onlyTokenOwner(uint256 tokenId) {
        if (ownerOf(tokenId) != msg.sender) revert Errors.NotTokenOwner();
        _;
    }

    modifier notCompromised(uint256 tokenId) {
        if (identityStates[tokenId].isCompromised) revert Errors.IdentityCompromised();
        _;
    }

    constructor() ERC721("IdentityToken", "IDT") {}

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) revert NonTransferable();
        address prevOwner = super._update(to, tokenId, auth);
        if (from != address(0)) {
            delete ownerToTokenId[from];
        }
        if (to != address(0)) {
            ownerToTokenId[to] = tokenId;
        }
        return prevOwner;
    }

    /**
     * @dev Mints a new self-issued identity token to the caller.
     */
    function mint() external returns (uint256) {
        if (balanceOf(msg.sender) != 0) revert Errors.AlreadyHasIdentity();
        uint256 tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);
        ownerToTokenId[msg.sender] = tokenId;
        return tokenId;
    }

    /**
     * @dev Sets a metadata attribute for an identity.
     */
    function setAttribute(
        uint256 tokenId,
        string calldata key,
        bytes calldata value
    ) external onlyTokenOwner(tokenId) notCompromised(tokenId) {
        bytes32 keyHash = keccak256(abi.encodePacked(key));
        attributes[tokenId][keyHash] = value;
        emit Events.AttributeSet(tokenId, keyHash, value);
    }

    /**
     * @dev Deletes a metadata attribute entirely from an identity.
     */
    function deleteAttribute(
        uint256 tokenId,
        string calldata key
    ) external onlyTokenOwner(tokenId) notCompromised(tokenId) {
        bytes32 keyHash = keccak256(abi.encodePacked(key));
        delete attributes[tokenId][keyHash];
        emit Events.AttributeDeleted(tokenId, keyHash);
    }

    /**
     * @dev Allows an identity to endorse another identity.
     */
    function endorse(
        uint256 fromTokenId,
        uint256 toTokenId,
        bytes32 connectionType,
        uint256 validUntil
    ) external onlyTokenOwner(fromTokenId) notCompromised(fromTokenId) {
        if (fromTokenId == toTokenId) revert Errors.SelfEndorsement();
        if (_ownerOf(toTokenId) == address(0)) revert Errors.TargetInvalid();

        DataTypes.Endorsement[] storage list = endorsements[toTokenId];

        for (uint256 i = 0; i < list.length; i++) {
            DataTypes.Endorsement storage e = list[i];
            bool active = e.revokedAt == 0 && (e.validUntil == 0 || e.validUntil >= block.timestamp);
            if (active && e.endorserTokenId == fromTokenId && e.connectionType == connectionType) {
                revert Errors.DuplicateEndorsement();
            }
        }

        DataTypes.Endorsement memory newEndorsement = DataTypes.Endorsement({
            endorserTokenId: fromTokenId,
            connectionType: connectionType,
            timestamp: block.timestamp,
            validUntil: validUntil,
            revokedAt: 0
        });

        endorsements[toTokenId].push(newEndorsement);
        emit Events.EndorsementGiven(fromTokenId, toTokenId, connectionType, validUntil);
    }

    /**
     * @dev Allows an endorser to revoke an endorsement they created.
     */
    function revokeEndorsement(
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 endorsementIndex
    ) external onlyTokenOwner(fromTokenId) notCompromised(fromTokenId) {
        DataTypes.Endorsement[] storage list = endorsements[toTokenId];

        if (endorsementIndex >= list.length)
            revert Errors.IndexOutOfBounds();

        DataTypes.Endorsement storage e = list[endorsementIndex];

        if (e.endorserTokenId != fromTokenId) revert Errors.NotEndorser();

        if (e.revokedAt != 0) revert Errors.AlreadyRevoked();

        e.revokedAt = block.timestamp;

        emit Events.EndorsementRevoked(fromTokenId, toTokenId, endorsementIndex);
    }
}