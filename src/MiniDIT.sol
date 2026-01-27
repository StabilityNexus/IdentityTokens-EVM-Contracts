// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MiniDIT is ERC721 {

    uint256 public nextTokenId;

    struct Identity {
        string metadataURI;
        bool compromised;
    }

    struct Endorsement {
        uint256 fromTokenId;
        string tag;
        bool revoked;
    }

    mapping(uint256 => Identity) public identities;
    mapping(uint256 => Endorsement[]) public endorsements;

    event IdentityMinted(address owner, uint256 tokenId);
    event Endorsed(uint256 fromTokenId, uint256 toTokenId, string tag);
    event EndorsementRevoked(uint256 fromTokenId, uint256 toTokenId);
    event IdentityCompromised(uint256 tokenId);

    constructor() ERC721("MiniDIT", "DIT") {}

    function mintIdentity(string calldata metadataURI) external {
        uint256 tokenId = nextTokenId++;
        _mint(msg.sender, tokenId);
        identities[tokenId] = Identity(metadataURI, false);
        emit IdentityMinted(msg.sender, tokenId);
    }

    function endorse(
        uint256 fromTokenId,
        uint256 toTokenId,
        string calldata tag
    ) external {
        require(ownerOf(fromTokenId) == msg.sender, "Not owner of fromToken");

        // ownerOf(toTokenId) will revert automatically if token doesn't exist
        ownerOf(toTokenId);

        require(!identities[fromTokenId].compromised, "From identity compromised");

        endorsements[toTokenId].push(
            Endorsement(fromTokenId, tag, false)
        );

        emit Endorsed(fromTokenId, toTokenId, tag);
    }

    function revokeEndorsement(uint256 toTokenId, uint256 index) external {
        Endorsement storage e = endorsements[toTokenId][index];
        require(ownerOf(e.fromTokenId) == msg.sender, "Not endorser");
        e.revoked = true;
        emit EndorsementRevoked(e.fromTokenId, toTokenId);
    }

    function markCompromised(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        identities[tokenId].compromised = true;
        emit IdentityCompromised(tokenId);
    }
}
