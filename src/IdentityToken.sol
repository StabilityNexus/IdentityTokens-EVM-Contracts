// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { DataTypes } from "./libraries/DataTypes.sol";
import { Errors } from "./libraries/Errors.sol";
import { Events } from "./libraries/Events.sol";

contract IdentityToken is ERC721 {
    error NonTransferable();

    uint256 private _nextTokenId = 1;

    // wallet => tokenId (enforce one identity per wallet)
    mapping(address => uint256) public ownerToTokenId;

    // tokenId => IdentityState
    mapping(uint256 => DataTypes.IdentityState) public identityStates;

    // tokenId => attribute keyHash => attribute value
    mapping(uint256 => mapping(bytes32 => bytes)) public attributes;

    // tokenId => array of Endorsements (forward index: who endorsed toTokenId)
    mapping(uint256 => DataTypes.Endorsement[]) public endorsements;

    // reverse index: toTokenId entries given BY fromTokenId
    mapping(uint256 => DataTypes.GivenEndorsement[]) private _givenEndorsements;

    // tokenId => tokenURI string
    mapping(uint256 => string) private _tokenURIs;

    uint256 public constant MAX_PAGE_SIZE = 100;

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

        // prevent transfers (only mint or burn allowed)
        if (from != address(0) && to != address(0)) revert NonTransferable();

        address prevOwner = super._update(to, tokenId, auth);

        // maintain ownerToTokenId mapping
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
     * @dev Sets a metadata attribute (e.g., name, social link) for an identity.
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

        // prevent duplicate active endorsements
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

        // populate reverse index so callers can efficiently query "which identities
        // has fromTokenId endorsed?" — required by DIT spec.
        _givenEndorsements[fromTokenId].push(
            DataTypes.GivenEndorsement({
                toTokenId: toTokenId,
                endorsementIndex: endorsements[toTokenId].length - 1
            })
        );

        emit Events.EndorsementGiven(fromTokenId, toTokenId, connectionType, validUntil);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // tokenURI support
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * @dev Sets the ERC-721 metadata URI for a token.
     *      Allows wallets and the frontend integration layer to resolve metadata.
     */
    function setTokenURI(
        uint256 tokenId,
        string calldata uri
    ) external onlyTokenOwner(tokenId) notCompromised(tokenId) {
        _tokenURIs[tokenId] = uri;
        emit Events.TokenURISet(tokenId, uri);
    }

    /**
     * @dev Returns the metadata URI for a token (ERC-721 standard override).
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _tokenURIs[tokenId];
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Endorsement helpers — forward + reverse indexes
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * @dev Returns the total number of endorsements received by tokenId.
     */
    function getEndorsementCount(uint256 tokenId) external view returns (uint256) {
        return endorsements[tokenId].length;
    }

    /**
     * @dev Returns a paginated slice of endorsements received by tokenId.
     *      start is inclusive, end is exclusive. end is clamped to array length.
     */
    function getEndorsements(
        uint256 tokenId,
        uint256 start,
        uint256 end
    ) external view returns (DataTypes.Endorsement[] memory) {
        DataTypes.Endorsement[] storage all = endorsements[tokenId];
        if (start > all.length) revert Errors.IndexOutOfBounds();
        if (end > all.length) end = all.length;
        if (end < start) revert Errors.IndexOutOfBounds();

        uint256 count = end - start;
        if (count > MAX_PAGE_SIZE) revert Errors.PageTooLarge();

        DataTypes.Endorsement[] memory result = new DataTypes.Endorsement[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = all[start + i];
        }
        return result;
    }

    /**
     * @dev Returns the total number of endorsements given BY tokenId.
     */
    function getGivenEndorsementCount(uint256 tokenId) external view returns (uint256) {
        return _givenEndorsements[tokenId].length;
    }

    /**
     * @dev Returns a paginated slice of endorsements given BY tokenId.
     *      Satisfies DIT spec reverse-lookup requirement.
     */
    function getGivenEndorsements(
        uint256 tokenId,
        uint256 start,
        uint256 end
    ) external view returns (DataTypes.GivenEndorsement[] memory) {
        DataTypes.GivenEndorsement[] storage all = _givenEndorsements[tokenId];
        if (start > all.length) revert Errors.IndexOutOfBounds();
        if (end > all.length) end = all.length;
        if (end < start) revert Errors.IndexOutOfBounds();

        uint256 count = end - start;
        if (count > MAX_PAGE_SIZE) revert Errors.PageTooLarge();

        DataTypes.GivenEndorsement[] memory result = new DataTypes.GivenEndorsement[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = all[start + i];
        }
        return result;
    }
}
