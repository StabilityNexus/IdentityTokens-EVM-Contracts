// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./libraries/DataTypes.sol";
import "./libraries/Events.sol";
import "./libraries/Errors.sol";

contract IdentityToken is ERC721, ERC721Enumerable {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 private _nextTokenId;

    // Token ID to Profile Metadata
    mapping(uint256 => DataTypes.IdentityProfile) public profiles;

    // Token ID to attribute key hash to value
    mapping(uint256 => mapping(bytes32 => bytes)) public attributes;

    // Graph mappings
    mapping(uint256 => EnumerableSet.UintSet) private _endorsedBy; // Who endorsed me
    mapping(uint256 => EnumerableSet.UintSet) private _endorsing;  // Who I endorsed

    mapping(uint256 => mapping(uint256 => DataTypes.Endorsement)) public endorsements;

    constructor() ERC721("IdentityToken", "IDT") {
        _nextTokenId = 1;
    }

    function mint() external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        return tokenId;
    }

    function setProfile(uint256 tokenId, DataTypes.IdentityProfile calldata profile) external {
        if (ownerOf(tokenId) != msg.sender) revert Errors.NotTokenOwner();
        profiles[tokenId] = profile;
        emit Events.ProfileUpdated(tokenId);
    }

    function setAttribute(uint256 tokenId, string calldata key, bytes calldata value) external {
        if (ownerOf(tokenId) != msg.sender) revert Errors.NotTokenOwner();
        bytes32 keyHash = keccak256(bytes(key));
        attributes[tokenId][keyHash] = value;
        emit Events.AttributeSet(tokenId, keyHash, value);
    }
    
    function endorse(uint256 endorserTokenId, uint256 endorsedTokenId, bytes32 connectionType, uint256 validUntil) external {
        if (ownerOf(endorserTokenId) != msg.sender) revert Errors.NotTokenOwner();
        if (endorserTokenId == endorsedTokenId) revert Errors.SelfEndorsement();
        
        // Ensure endorsed token exists
        _requireOwned(endorsedTokenId);

        // Update sets
        _endorsedBy[endorsedTokenId].add(endorserTokenId);
        _endorsing[endorserTokenId].add(endorsedTokenId);

        endorsements[endorserTokenId][endorsedTokenId] = DataTypes.Endorsement({
            endorserTokenId: endorserTokenId,
            connectionType: connectionType,
            timestamp: block.timestamp,
            validUntil: validUntil,
            revokedAt: 0
        });

        emit Events.EndorsementGiven(endorserTokenId, endorsedTokenId, connectionType, validUntil);
    }

    function revokeEndorsement(uint256 endorserTokenId, uint256 endorsedTokenId) external {
        if (ownerOf(endorserTokenId) != msg.sender) revert Errors.NotTokenOwner();
        
        if (!_endorsing[endorserTokenId].contains(endorsedTokenId)) {
             revert Errors.NotEndorser();
        }

        DataTypes.Endorsement storage endorsement = endorsements[endorserTokenId][endorsedTokenId];
        if (endorsement.revokedAt != 0) revert Errors.AlreadyRevoked();

        endorsement.revokedAt = block.timestamp;

        // Optionally remove from sets if we want "active" endorsements only in the set.
        // But usually history is preserved. 
        // For traversal efficiency of ACTIVE endorsements, we might want to remove.
        // Let's remove them from the set for this blueprint to keep "getEndorsers" returning active ones.
        _endorsedBy[endorsedTokenId].remove(endorserTokenId);
        _endorsing[endorserTokenId].remove(endorsedTokenId);

        emit Events.EndorsementRevoked(endorserTokenId, endorsedTokenId, 0); // index 0 as using sets
    }

    // Getters for arrays (graph traversal)
    function getEndorsers(uint256 tokenId) external view returns (uint256[] memory) {
        return _endorsedBy[tokenId].values();
    }
    
    function getEndorsing(uint256 tokenId) external view returns (uint256[] memory) {
        return _endorsing[tokenId].values();
    }

    // Required overrides for ERC721Enumerable
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
