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
        address owner;
        uint256 amount;
        uint256 addedTimestamp;
    }

    struct TokenOwner {
        address owner;
        uint256 amount;
        uint256 assetId;
    }

    struct Asset {
        uint256 id;
        string name;
        address owner;
        uint256 tokenAmount;
        uint256 initialTokenPrice;
        uint256 currentTokenPrice;
        uint256 addedTimestamp;
    }

    address private assetOwner;
    uint256 public constant initialTokenPrice = 1000;
    string public constant tokenCurrency = "USD";
    uint256 private constant minimumAmountToSell = 1;

    mapping(address => TokenOnMarket[]) public tokensOnMarket;
    TokenOnMarket[] public allTokensOnMarket;

    mapping(address => Asset[]) public assets;
    Asset[] public allAssets;

    mapping(address => TokenOwner[]) public tokenOwners;

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

    function calculateTokensToGenerate(
        uint256 _assetValue
    ) internal view onlyOwner returns (uint256) {
        return _assetValue / initialTokenPrice;
    }

    function registerAsset(
        address to,
        string memory _name,
        uint256 _assetValue
    ) public onlyOwner {
        require(
            _assetValue >= initialTokenPrice,
            "The asset value must be at least worth a 1000 ZAR"
        );
        uint256 amount = calculateTokensToGenerate(_assetValue);
        _mint(to, amount);

        uint256 assetId = allAssets.length;

        Asset memory newAsset = Asset({
            id: assetId,
            owner: to,
            name: _name,
            tokenAmount: amount,
            initialTokenPrice: initialTokenPrice,
            currentTokenPrice: initialTokenPrice,
            addedTimestamp: block.timestamp
        });

        TokenOwner memory newTokenOwner = TokenOwner({
            owner: to,
            amount: amount,
            assetId: assetId
        });

        assets[to].push(newAsset);
        allAssets.push(newAsset);
        tokenOwners[to].push(newTokenOwner);
    }

    function putTokensOnMarket(
        uint256 _amount,
        uint256 _assetId,
        address _owner
    ) external {
        require(_amount > 0, "The amount must be at least 1");
        require(_amount <= balanceOf(_owner), "Insufficient balance");

        bool assetExistsAndOnMarket = false;
        for (uint256 i = 0; i < allTokensOnMarket.length; i++) {
            if (
                allTokensOnMarket[i].assetId == _assetId &&
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
            owner: _owner,
            amount: _amount,
            addedTimestamp: block.timestamp
        });

        tokensOnMarket[_owner].push(newTokenOnMarket);
        allTokensOnMarket.push(newTokenOnMarket);

        tokenOwners[_owner][_assetId].amount -= _amount;
    }

    function adjustTokensOnMarket(
        address _owner,
        uint256 _assetId,
        uint256 _newAmount
    ) public {
        require(_newAmount <= balanceOf(_owner), "Insufficient balance");

        uint256 previousAmount;

        for (uint256 i = 0; i < allTokensOnMarket.length; i++) {
            if (
                allTokensOnMarket[i].assetId == _assetId &&
                allTokensOnMarket[i].owner == _owner
            ) {
                previousAmount = allTokensOnMarket[i].amount;
                allTokensOnMarket[i].amount = _newAmount;
                break;
            }
        }
        tokensOnMarket[_owner][_assetId].amount = _newAmount;

        tokenOwners[_owner][_assetId].amount += previousAmount - _newAmount;
    }

    // ! NEXT
    /*
     * Anyone can buy a new token.
     * Before buying tokens, make sure that it's on the market.
     * Make sure that the maximum amount of tokens bought, is the same amount put on the market.
     * When bought, reduce the number of tokens on the market
     * Transfer tokens to new address.
     */
    function buyTokens(
        address _currentOwner,
        address _newOwner,
        uint256 _amount,
        uint256 _assetId
    ) public payable {
        require(_amount > 0, "Amount must be greater than zero");
        require(
            _amount <= tokensOnMarket[_currentOwner][_assetId].amount,
            "The amount requested is higher than the current amount."
        );

        (, int price, , , ) = dataFeed.latestRoundData();
        uint256 tokenPriceInEther = (initialTokenPrice * uint256(price)) / 1e8;
        require(msg.value >= tokenPriceInEther, "Insufficient payment");

        payable(_currentOwner).transfer(msg.value);

        _transfer(_currentOwner, _newOwner, _amount);

        TokenOwner memory newTokenOwner = TokenOwner({
            owner: _newOwner,
            amount: _amount,
            assetId: _assetId
        });
        tokenOwners[_newOwner].push(newTokenOwner);

        tokensOnMarket[_currentOwner][_assetId].amount -= _amount;
        for (uint256 i = 0; i < allTokensOnMarket.length; i++) {
            if (
                allTokensOnMarket[i].assetId == _assetId &&
                allTokensOnMarket[i].owner == _currentOwner
            ) {
                allTokensOnMarket[i].amount -= _amount;
                break;
            }
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
