// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
 * 1. Only the contract owner is allowed to deploy the contract. ✅
 * 2. Owner register the asset and send its token to the owner's address. ✅
 * 2.1. Set storage through URI
 * 2.2. token URI content can be updated by asset owner and contract owner.
 * 3. Asset owner can put their token on the market to get offerings or withdraw it from the market.
 * 3.1. Only asset owner and contract owner can put token for sell or withdraw it from the market.
 * 4. When sold (on-chain or off-chain), the token gets sent to the new owner address.
 * 5. Add the possibility to burn token if the asset has been withdrawn. OwnerOnly
 */
contract AssetMarketplace is ERC721, Ownable {
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => bool) private _tokenOnMarket;

    constructor(
        address initialOwner
    ) ERC721("Just_a_Try", "JST") Ownable(initialOwner) {}

    function registerAsset(
        uint256 tokenId,
        string memory uri
    ) public onlyOwner {
        _tokenURIs[tokenId] = uri;
        _safeMint(msg.sender, tokenId);
    }

    function setTokenURI(uint256 tokenId, string memory uri) public {
        require(
            _ownerOf(tokenId) != address(0),
            "ERC721Metadata: URI set of nonexistent token"
        );
        require(
            // _isApprovedOrOwner(_msgSender(), tokenId),
            _isAuthorized(_ownerOf(tokenId), _msgSender(), tokenId),
            "ERC721Metadata: URI set not approved"
        );
        _tokenURIs[tokenId] = uri;
    }

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        require(
            _ownerOf(tokenId) != address(0),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory uri = _tokenURIs[tokenId];
        return uri;
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
}
