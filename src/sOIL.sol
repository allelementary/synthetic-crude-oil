// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceFeedProxy} from "./PriceFeedProxy.sol";
import {MessageSender} from "./ccip/Sender.sol";

contract sOIL is ERC20, ReentrancyGuard {
    error sOIL__CollateralAddressesAndPriceFeedAddressesAmountsDontMatch();
    error sOIL__TransferFailed();
    error sOIL__HealthFactorOk();
    error sOIL__TokenNotAllowed(address token);
    error sOIL__NeedsMoreThanZero();
    error sOIL__BreaksHealthFactor(uint256 healthFactor);

    address private s_priceFeedProxy;
    uint64 public s_chainSelector;

    uint256 private constant LIQUIDATION_TRESHOLD = 67; // For 150% overcollateralized | 80 for 125%
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you'll get assets with 10% discount when liquidating
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => uint256 oilMinted) public s_oilMintedPerUser;
    mapping(address user => mapping(address collateral => uint256 amountCollateral)) public s_collateralPerUser;

    address[] private s_collateralTokens;

    ///////////////////
    // Events
    ///////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount);
    event PositionLiquidated(
        address indexed liquidator,
        address indexed user,
        address addressCollateral,
        uint256 amountCollateral,
        uint256 amountOilCovered
    );
    event OilBurned(address indexed user, uint256 amount);
    event OilMinted(address indexed user, uint256 amount);

    ///////////////////
    // Modifiers
    ///////////////////

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert sOIL__TokenNotAllowed(token);
        }
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert sOIL__NeedsMoreThanZero();
        }
        _;
    }

    constructor(
        address _priceFeedProxy,
        address[] memory collateralAddresses,
        address[] memory priceFeedAddresses,
        uint64 _chainSelector
    ) ERC20("Synthetic Crude Oil", "sOIL") {
        if (collateralAddresses.length != priceFeedAddresses.length) {
            revert sOIL__CollateralAddressesAndPriceFeedAddressesAmountsDontMatch();
        }

        s_priceFeedProxy = _priceFeedProxy;
        s_chainSelector = _chainSelector;
        for (uint256 i = 0; i < collateralAddresses.length; i++) {
            s_priceFeeds[collateralAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(collateralAddresses[i]);
        }
    }

    function depositAndMint(address collateral, uint256 amountCollateral, uint256 amountToMint)
        external
        isAllowedToken(collateral)
    {
        depositCollateral(collateral, amountCollateral);
        mintOil(amountToMint);
        emit CollateralDeposited(msg.sender, collateral, amountCollateral);
    }

    // just deposit without minting oil
    function depositCollateral(address collateral, uint256 amount) public isAllowedToken(collateral) nonReentrant {
        s_collateralPerUser[msg.sender][collateral] += amount;
        bool success = IERC20(collateral).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert sOIL__TransferFailed();
        }

        emit CollateralDeposited(msg.sender, collateral, amount);
    }

    function mintOil(uint256 amountToMint) public {
        s_oilMintedPerUser[msg.sender] += amountToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        _mint(msg.sender, amountToMint);

        emit OilMinted(msg.sender, amountToMint);
    }

    function redeemAndBurn(address collateral, uint256 amountCollateralToRedeem, uint256 amountOilToBurn)
        external
        isAllowedToken(collateral)
        moreThanZero(amountCollateralToRedeem)
        nonReentrant
    {
        _burnOil(msg.sender, msg.sender, amountOilToBurn);
        _redeem(msg.sender, msg.sender, collateral, amountCollateralToRedeem);

        emit OilBurned(msg.sender, amountOilToBurn);
    }

    // maybe just run redeem with 0 amount to burn
    function redeem(address collateral, uint256 amountCollateralToRedeem)
        external
        isAllowedToken(collateral)
        moreThanZero(amountCollateralToRedeem)
        nonReentrant
    {
        _redeem(msg.sender, msg.sender, collateral, amountCollateralToRedeem);
    }

    function _redeem(address from, address to, address collateral, uint256 amountCollateralToRedeem) private {
        s_collateralPerUser[from][collateral] -= amountCollateralToRedeem;
        revertIfHealthFactorIsBroken(from);
        bool success = IERC20(collateral).transfer(to, amountCollateralToRedeem);
        if (!success) {
            revert sOIL__TransferFailed();
        }
    }

    function burn(uint256 amountOilToBurn) public moreThanZero(amountOilToBurn) {
        _burnOil(msg.sender, msg.sender, amountOilToBurn);
        revertIfHealthFactorIsBroken(msg.sender);

        emit OilBurned(msg.sender, amountOilToBurn);
    }

    function _burnOil(address user, address liquidator, uint256 amountOilToBurn) private {
        s_oilMintedPerUser[user] -= amountOilToBurn;
        _burn(liquidator, amountOilToBurn);
    }

    function liquidate(address user, address collateral, uint256 oilAmountToCover)
        external
        isAllowedToken(collateral)
        moreThanZero(oilAmountToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = getHealthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert sOIL__HealthFactorOk();
        }
        uint256 oilUsdToCover = getUsdAmountFromOil(oilAmountToCover); // 0.5 oil == $50
        uint256 bonusCollateral = (oilUsdToCover * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION; // $5

        uint256 amountCollateralToRedeem = getTokenAmountFromUsd(collateral, oilUsdToCover + bonusCollateral); // $55 of weth
        _burnOil(user, msg.sender, oilAmountToCover);
        _redeem(user, msg.sender, collateral, amountCollateralToRedeem);

        emit PositionLiquidated(msg.sender, user, collateral, amountCollateralToRedeem, oilAmountToCover);
    }

    /**
     *
     * @param destinationChainSelector ChainSelector of the destination chain the price should be updated at
     * @param payFeesIn LINK or Native, 0 for Native, 1 for LINK
     */
    function updateCrudeOilPriceOnDestinationChain(uint64 destinationChainSelector, MessageSender.PayFeesIn payFeesIn)
        public
    {
        PriceFeedProxy(s_priceFeedProxy).updatePrice(destinationChainSelector, payFeesIn);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE
    //////////////////////////////////////////////////////////////*/

    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = getHealthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert sOIL__BreaksHealthFactor(healthFactor);
        }
    }

    function getHealthFactor(address user) public view returns (uint256) {
        (uint256 totalOilMintedValueInUsd, uint256 totalCollateralValueInUsd) = getAccountInformationValue(user);
        return _calculateHealthFactor(totalOilMintedValueInUsd, totalCollateralValueInUsd);
    }

    // WTI crude oil has 8 decimals
    // For consistency the result would have 18 decimals
    function getUsdAmountFromOil(uint256 amountOilInWei) public view returns (uint256) {
        int256 price = PriceFeedProxy(s_priceFeedProxy).getLatestPrice();
        return (amountOilInWei * (uint256(price) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function getCrudeOilPrice() public view returns (int256) {
        return PriceFeedProxy(s_priceFeedProxy).getLatestPrice();
    }

    function getUsdAmountFromToken(address collateral, uint256 tokenAmountInWei)
        public
        view
        isAllowedToken(collateral)
        returns (uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[collateral]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (tokenAmountInWei * (uint256(price) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function getTokenAmountFromUsd(address collateral, uint256 usdAmountInWei)
        public
        view
        isAllowedToken(collateral)
        returns (uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[collateral]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountInformationValue(address user)
        public
        view
        returns (uint256 totalOilMintedValueUsd, uint256 totalCollateralValueUsd)
    {
        totalOilMintedValueUsd = getUsdAmountFromOil(s_oilMintedPerUser[user]);
        totalCollateralValueUsd = getAccountCollateralValue(user);
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint256 amount = s_collateralPerUser[user][token];
            totalCollateralValueInUsd += getUsdAmountFromToken(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getAccountCollateralAmount(address user, address collateral)
        public
        view
        isAllowedToken(collateral)
        returns (uint256)
    {
        return s_collateralPerUser[user][collateral];
    }

    /**
     * @dev Calculate the health factor of a user in USD, by adding collateral in ETH and DAI and dividing by the minted oil in USD
     */
    function _calculateHealthFactor(uint256 oilMintedValueUsd, uint256 totalCollateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (oilMintedValueUsd == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold =
            (totalCollateralValueInUsd * LIQUIDATION_TRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / oilMintedValueUsd;
    }

    function getEstimatedFeeAmount(uint64 destinationChainSelector, MessageSender.PayFeesIn payFeesIn)
        external
        view
        returns (uint256)
    {
        return PriceFeedProxy(s_priceFeedProxy).getEstimatedFeeAmount(destinationChainSelector, payFeesIn);
    }
}
