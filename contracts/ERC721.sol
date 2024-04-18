// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract TokenZ is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Pausable,
    Ownable,
    ERC721Burnable
{
    mapping(uint256 => bool) private _tokenOnMarket;
    mapping(uint256 => string) private _tokenURIs;

    uint256 private _nextTokenId;

    constructor(
        address initialOwner
    ) ERC721("TokenZ", "TKZ") Ownable(initialOwner) {}

    function _baseURI() internal pure override returns (string memory) {
        return "http://localhost:3001/";
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function putOnMarket(uint256 tokenId) public {
        require(
            _isAuthorized(_ownerOf(tokenId), _msgSender(), tokenId),
            "AssetMarketplace: caller is not owner nor approved"
        );
        _tokenOnMarket[tokenId] = true;
    }

    function withdrawFromMarket(uint256 tokenId) public {
        require(
            _isAuthorized(_ownerOf(tokenId), _msgSender(), tokenId),
            "AssetMarketplace: caller is not owner nor approved"
        );
        _tokenOnMarket[tokenId] = false;
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function buyToken(uint256 tokenId) public payable {
        require(
            _tokenOnMarket[tokenId],
            "AssetMarketplace: token is not on market"
        );
        address tokenOwner = ownerOf(tokenId);
        require(
            msg.value >= 1 ether, // adjust this value as needed
            "AssetMarketplace: insufficient payment"
        );
        payable(tokenOwner).transfer(msg.value);
        _transfer(tokenOwner, msg.sender, tokenId);
        _tokenOnMarket[tokenId] = false;
    }

    function burnToken(uint256 tokenId) public onlyOwner {
        require(
            _ownerOf(tokenId) != address(0),
            "ERC721: operator query for nonexistent token"
        );
        _burn(tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721, ERC721Enumerable, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
