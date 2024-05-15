// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract TokenZ20 is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ERC20Permit {
    AggregatorV3Interface internal dataFeed;

    struct TokenOnMarket {
        uint256 id;
        uint256 assetId;
        string assetIdDB;
        address owner;
        uint256 quantity;
        uint256 addedTimestamp;
    }

    struct TokenOwner {
        address owner;
        uint256 quantity;
        uint256 assetId;
        string assetIdDB;
    }

    struct Asset {
        uint256 id;
        string assetIdDB;
        string name;
        address owner;
        uint256 tokenAmount;
        uint256 initialTokenPrice;
        uint256 currentTokenPrice;
        uint256 totalRent;
        uint256 addedTimestamp;
    }

    address private assetOwner;
    string public constant tokenCurrency = "USD";
    uint256 public constant initialTokenPrice = 1000;
    uint256 private constant minimumAmountToSell = 1;

    mapping(address => Asset[]) public assets;
    Asset[] public allAssets;

    mapping(address => TokenOwner[]) public tokenOwners;
    TokenOwner[] public allTokenOwners;

    mapping(address => TokenOnMarket[]) public tokensOnMarket;
    TokenOnMarket[] public allTokensOnMarket;

    constructor(
        address initialOwner
    ) ERC20("TokenZ", "TKZ") Ownable(initialOwner) ERC20Permit("TokenZ") {
        assetOwner = initialOwner;
        dataFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
    }

    modifier onlyAssetOrContractOwner() {
        require(
            msg.sender == assetOwner || msg.sender == owner(),
            "Unauthorized request."
        );
        _;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        (, int answer, , , ) = dataFeed.latestRoundData();
        return answer;
    }

    function updateTokenPrice(
        uint256 _assetId,
        uint256 _newValuation
    ) public onlyOwner {
        Asset storage asset = allAssets[_assetId];
        uint256 newTokenPrice = _newValuation / asset.tokenAmount;
        asset.currentTokenPrice = newTokenPrice;
    }

    function getAssetsByAssetIdDB(
        string memory _assetIdDB
    ) internal view returns (Asset[] memory) {
        Asset[] memory matchingAssets = new Asset[](allAssets.length);
        uint256 matchingAssetsCount = 0;

        for (uint256 i = 0; i < allAssets.length; i++) {
            if (
                keccak256(bytes(allAssets[i].assetIdDB)) ==
                keccak256(bytes(_assetIdDB))
            ) {
                matchingAssets[matchingAssetsCount] = allAssets[i];
                matchingAssetsCount++;
            }
        }
        assembly {
            mstore(matchingAssets, matchingAssetsCount)
        }
        return matchingAssets;
    }

    function getTokenOwnersByAssetIdDB(
        string memory _assetIdDB
    ) internal view returns (TokenOwner[] memory) {
        TokenOwner[] memory matchingTokenOwners = new TokenOwner[](
            allTokenOwners.length
        );
        uint256 matchingOwnersCount = 0;

        for (uint256 i = 0; i < allTokenOwners.length; i++) {
            if (
                keccak256(bytes(allTokenOwners[i].assetIdDB)) ==
                keccak256(bytes(_assetIdDB))
            ) {
                matchingTokenOwners[matchingOwnersCount] = allTokenOwners[i];
                matchingOwnersCount++;
            }
        }

        assembly {
            mstore(matchingTokenOwners, matchingOwnersCount)
        }

        return matchingTokenOwners;
    }

    function calculateTokensToGenerate(
        uint256 _assetValue
    ) internal view onlyOwner returns (uint256) {
        return _assetValue / initialTokenPrice;
    }

    // 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
    // new: 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    // new: 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
    // 663f965a7273af31468217aa
    // 185 Pandora Rd

    function putTokensOnMarket(
        uint256 _quantity,
        uint256 _assetId,
        string memory _assetIdDB,
        address _owner
    ) public {
        require(_quantity > 0, "The quantity must be at least 1");

        bool assetExistsAndOnMarket = false;
        for (uint256 i = 0; i < allTokensOnMarket.length; i++) {
            if (
                keccak256(bytes(allTokensOnMarket[i].assetIdDB)) ==
                keccak256(bytes(_assetIdDB)) &&
                allTokensOnMarket[i].owner == _owner
            ) {
                assetExistsAndOnMarket = true;
                break;
            }
        }
        require(
            assetExistsAndOnMarket == false,
            "The asset is already on the market"
        );

        TokenOnMarket memory newTokenOnMarket = TokenOnMarket({
            id: allTokensOnMarket.length,
            assetId: _assetId,
            assetIdDB: _assetIdDB,
            owner: _owner,
            quantity: _quantity,
            addedTimestamp: block.timestamp
        });
        tokensOnMarket[_owner].push(newTokenOnMarket);
        allTokensOnMarket.push(newTokenOnMarket);

        for (uint256 i = 0; i < allTokenOwners.length; i++) {
            if (
                allTokenOwners[i].owner == _owner &&
                keccak256(bytes(allTokenOwners[i].assetIdDB)) ==
                keccak256(bytes(_assetIdDB))
            ) {
                allTokenOwners[i].quantity -= _quantity;
                break;
            }
        }
        tokenOwners[_owner][_assetId].quantity -= _quantity;
    }

    function registerAsset(
        string memory _assetIdDB,
        address to,
        string memory _name,
        uint256 _percentageToSell,
        uint256 _assetValue,
        uint256 _totalRent
    ) public onlyOwner {
        require(
            _assetValue >= initialTokenPrice,
            "The asset value must be at least worth a 1000 ZAR"
        );
        uint256 _quantity = calculateTokensToGenerate(_assetValue);
        _mint(to, _quantity);

        uint256 assetId = allAssets.length;

        Asset memory newAsset = Asset({
            id: assetId,
            assetIdDB: _assetIdDB,
            owner: to,
            name: _name,
            tokenAmount: _quantity,
            initialTokenPrice: initialTokenPrice,
            currentTokenPrice: initialTokenPrice,
            totalRent: _totalRent,
            addedTimestamp: block.timestamp
        });

        uint256 amountForOnMarket = (_percentageToSell * _quantity) / 100;

        TokenOwner memory newTokenOwner = TokenOwner({
            owner: to,
            quantity: _quantity,
            assetId: assetId,
            assetIdDB: _assetIdDB
        });

        assets[to].push(newAsset);
        allAssets.push(newAsset);
        tokenOwners[to].push(newTokenOwner);
        allTokenOwners.push(newTokenOwner);

        putTokensOnMarket(amountForOnMarket, assetId, _assetIdDB, to);
    }

    function getTokensOnMarketByAssetIdDB(
        string memory _assetIdDB
    ) internal view returns (TokenOnMarket[] memory) {
        TokenOnMarket[] memory matchingTokens = new TokenOnMarket[](
            allTokensOnMarket.length
        );
        uint256 matchingTokensCount = 0;

        for (uint256 i = 0; i < allTokensOnMarket.length; i++) {
            if (
                keccak256(bytes(allTokensOnMarket[i].assetIdDB)) ==
                keccak256(bytes(_assetIdDB))
            ) {
                matchingTokens[matchingTokensCount] = allTokensOnMarket[i];
                matchingTokensCount++;
            }
        }
        assembly {
            mstore(matchingTokens, matchingTokensCount)
        }
        return matchingTokens;
    }

    function buyTokens(
        address _currentOwner,
        address _newOwner,
        uint256 _quantity,
        string memory _assetIdDB
    ) public payable {
        require(_quantity > 0, "The quantity must be at least 1");
        require(_currentOwner != _newOwner, "Redundant purchase.");

        TokenOnMarket[] memory tokens = getTokensOnMarketByAssetIdDB(
            _assetIdDB
        );
        require(
            tokens.length > 0 && tokens[0].quantity >= _quantity,
            "Insufficient tokens on the market"
        );

        Asset[] memory assetsByAssetIdDB = getAssetsByAssetIdDB(_assetIdDB);
        require(assetsByAssetIdDB.length > 0, "Asset not found");
        Asset memory assetByAssetIdDB = assetsByAssetIdDB[0];

        // uint256 totalAmount = _quantity * assetByAssetIdDB.currentTokenPrice;
        // require(msg.value >= totalAmount, "Insufficient payment");
        // payable(_currentOwner).transfer(totalAmount);

        payable(_currentOwner).transfer(msg.value);
        _transfer(_currentOwner, _newOwner, _quantity);

        // * Update the token ownership
        // * New Owner
        bool tokenOwnerExists = false;
        for (uint256 i = 0; i < tokenOwners[_newOwner].length; i++) {
            if (tokenOwners[_newOwner][i].assetId == assetByAssetIdDB.id) {
                tokenOwners[_newOwner][i].quantity += _quantity;
                tokenOwnerExists = true;
                break;
            }
        }
        if (!tokenOwnerExists) {
            tokenOwners[_newOwner].push(
                TokenOwner({
                    owner: _newOwner,
                    quantity: _quantity,
                    assetId: assetByAssetIdDB.id,
                    assetIdDB: _assetIdDB
                })
            );
        }
        tokenOwnerExists = false;
        for (uint256 i = 0; i < allTokenOwners.length; i++) {
            if (
                allTokenOwners[i].assetId == assetByAssetIdDB.id &&
                allTokenOwners[i].owner == _newOwner
            ) {
                allTokenOwners[i].quantity += _quantity;
                tokenOwnerExists = true;
                break;
            }
        }
        if (!tokenOwnerExists) {
            allTokenOwners.push(
                TokenOwner({
                    owner: _newOwner,
                    quantity: _quantity,
                    assetId: assetByAssetIdDB.id,
                    assetIdDB: _assetIdDB
                })
            );
        }

        // * Token on market
        for (uint256 i = 0; i < tokensOnMarket[_currentOwner].length; i++) {
            if (
                tokensOnMarket[_currentOwner][i].assetId == assetByAssetIdDB.id
            ) {
                tokensOnMarket[_currentOwner][i].quantity -= _quantity;
                break;
            }
        }
        for (uint256 i = 0; i < allTokensOnMarket.length; i++) {
            if (
                allTokensOnMarket[i].assetId == assetByAssetIdDB.id &&
                allTokensOnMarket[i].owner == _currentOwner
            ) {
                allTokensOnMarket[i].quantity -= _quantity;
                break;
            }
        }

        // Refund any excess payment
        // if (msg.value > totalAmount) {
        //     payable(msg.sender).transfer(msg.value - totalAmount);
        // }
    }

    function calculateRentPercentage(
        uint256 _assetId
    ) public view returns (TokenOwner[] memory) {
        Asset storage asset = allAssets[_assetId];
        string memory assetIdDB = asset.assetIdDB;

        TokenOwner[] memory ownersForAsset = getTokenOwnersByAssetIdDB(
            assetIdDB
        );

        uint256 totalTokenAmount = asset.tokenAmount;

        for (uint256 i = 0; i < ownersForAsset.length; i++) {
            //* Calculate the percentage of rent that this owner should receive
            uint256 rentPercentage = (ownersForAsset[i].quantity * 100) /
                totalTokenAmount;
            ownersForAsset[i].quantity = rentPercentage;
        }

        return ownersForAsset;
    }

    function distribute(uint256 _assetId) public payable onlyOwner {
        Asset storage asset = allAssets[_assetId];
        string memory assetIdDB = asset.assetIdDB;

        // Get all token owners for this asset
        TokenOwner[] memory ownersForAsset = getTokenOwnersByAssetIdDB(
            assetIdDB
        );

        // Calculate total token amount for the asset
        uint256 totalTokenAmount = asset.tokenAmount;

        // Calculate and distribute rent percentage to each owner
        for (uint256 i = 0; i < ownersForAsset.length; i++) {
            // Calculate the percentage of rent that this owner should receive
            uint256 rentPercentage = (ownersForAsset[i].quantity * 100) /
                totalTokenAmount;
            // Distribute rent to the owner
            uint256 rentAmount = (msg.value * rentPercentage) / 100;
            payable(ownersForAsset[i].owner).transfer(rentAmount);
        }
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}
