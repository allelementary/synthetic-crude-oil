// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MessageSender} from "./ccip/Sender.sol";

/**
 * @title Synthetic Crude Oil Token (sOIL)
 * @author Mikhail Antonov
 * @notice sOIL contract for Source Chain that have access to the WTI Crude Oil price feed
 */
contract sOIL is ERC20, ReentrancyGuard {
    error sOIL__CollateralAddressesAndPriceFeedAddressesAmountsDontMatch();
    error sOIL__TransferFailed();
    error sOIL__HealthFactorOk();
    error sOIL__TokenNotAllowed(address token);
    error sOIL__NeedsMoreThanZero();
    error sOIL__BreaksHealthFactor(uint256 healthFactor);

    address private s_crudeOilUsdPriceFeed;

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
        address _s_crudeOilUsdPriceFeed,
        address[] memory collateralAddresses,
        address[] memory priceFeedAddresses
    ) ERC20("Synthetic Crude Oil", "sOIL") {
        if (collateralAddresses.length != priceFeedAddresses.length) {
            revert sOIL__CollateralAddressesAndPriceFeedAddressesAmountsDontMatch();
        }

        s_crudeOilUsdPriceFeed = _s_crudeOilUsdPriceFeed;
        for (uint256 i = 0; i < collateralAddresses.length; i++) {
            s_priceFeeds[collateralAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(collateralAddresses[i]);
        }
    }

    /**
     * @notice Deposits a specified amount of collateral and mints the Synthetic Crude Oil tokens
     * @param collateral The address of the collateral token
     * @param amountCollateral The amount of collateral to deposit
     * @param amountToMint The amount of Synthetic Crude Oil tokens to mint
     */
    function depositAndMint(address collateral, uint256 amountCollateral, uint256 amountToMint)
        external
        isAllowedToken(collateral)
    {
        depositCollateral(collateral, amountCollateral);
        mintOil(amountToMint);
        emit CollateralDeposited(msg.sender, collateral, amountCollateral);
    }

    /**
     * @notice Deposits a specified amount of collateral into the contract
     * @dev It can be used to improve the health factor of the user's position
     * @param collateral The address of the collateral token
     * @param amount The amount of collateral to deposit
     */
    function depositCollateral(address collateral, uint256 amount) public isAllowedToken(collateral) nonReentrant {
        s_collateralPerUser[msg.sender][collateral] += amount;
        bool success = IERC20(collateral).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert sOIL__TransferFailed();
        }

        emit CollateralDeposited(msg.sender, collateral, amount);
    }

    /**
     * @notice Mints a specified amount of Synthetic Crude Oil tokens
     * @dev This function increases the minted token balance for the user and checks the health factor to ensure it is not broken
     * @param amountToMint The amount of Synthetic Crude Oil tokens to mint
     */
    function mintOil(uint256 amountToMint) public {
        s_oilMintedPerUser[msg.sender] += amountToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        _mint(msg.sender, amountToMint);

        emit OilMinted(msg.sender, amountToMint);
    }

    /**
     * @notice Redeems a specified amount of collateral and burns the specified amount of Synthetic Crude Oil tokens
     * @param collateral The address of the collateral token
     * @param amountCollateralToRedeem The amount of collateral to redeem
     * @param amountOilToBurn The amount of Synthetic Crude Oil tokens to burn
     */
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

    /**
     * @notice Redeems a specified amount of collateral without burning any Synthetic Crude Oil tokens
     * @dev This function can be used to free up extra collateral assets
     * @param collateral The address of the collateral token
     * @param amountCollateralToRedeem The amount of collateral to redeem
     */
    function redeem(address collateral, uint256 amountCollateralToRedeem)
        external
        isAllowedToken(collateral)
        moreThanZero(amountCollateralToRedeem)
        nonReentrant
    {
        _redeem(msg.sender, msg.sender, collateral, amountCollateralToRedeem);
    }

    /**
     * @notice Redeems a specified amount of collateral
     * @param from The address from which the collateral is redeemed
     * @param to The address to which the redeemed collateral is transferred
     * @param collateral The address of the collateral token
     * @param amountCollateralToRedeem The amount of collateral to redeem
     */
    function _redeem(address from, address to, address collateral, uint256 amountCollateralToRedeem) private {
        s_collateralPerUser[from][collateral] -= amountCollateralToRedeem;
        revertIfHealthFactorIsBroken(from);
        bool success = IERC20(collateral).transfer(to, amountCollateralToRedeem);
        if (!success) {
            revert sOIL__TransferFailed();
        }
    }

    /**
     * @notice Burns a specified amount of Synthetic Crude Oil tokens without redeeming any collateral
     * @dev This function can be used to improve the health factor of the user's position
     * @param amountOilToBurn The amount of Synthetic Crude Oil tokens to burn
     */
    function burn(uint256 amountOilToBurn) public moreThanZero(amountOilToBurn) {
        _burnOil(msg.sender, msg.sender, amountOilToBurn);
        revertIfHealthFactorIsBroken(msg.sender);

        emit OilBurned(msg.sender, amountOilToBurn);
    }

    /**
     * @notice Burns a specified amount of Synthetic Crude Oil tokens from a user's balance
     * @dev This private function decreases the minted token balance for the user and burns
     *      the specified amount of tokens from the liquidator's balance
     * @param user The address of the user whose minted balance will be decreased
     * @param liquidator The address from whose balance the tokens will be burned
     * @param amountOilToBurn The amount of Synthetic Crude Oil tokens to burn
     */
    function _burnOil(address user, address liquidator, uint256 amountOilToBurn) private {
        s_oilMintedPerUser[user] -= amountOilToBurn;
        _burn(liquidator, amountOilToBurn);
    }

    /**
     * @notice Liquidates a user's position if their health factor is below the minimum threshold
     * @dev liquidator receives 10% bonus of underlying collateral assets
     * @param user The address of the user whose position is to be liquidated
     * @param collateral The address of the collateral token
     * @param oilAmountToCover The amount of Synthetic Crude Oil tokens to cover the debt
     */
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
        uint256 oilUsdToCover = getUsdAmountFromOil(oilAmountToCover);
        uint256 bonusCollateral = (oilUsdToCover * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 amountCollateralToRedeem = getTokenAmountFromUsd(collateral, oilUsdToCover + bonusCollateral);
        _burnOil(user, msg.sender, oilAmountToCover);
        _redeem(user, msg.sender, collateral, amountCollateralToRedeem);

        emit PositionLiquidated(msg.sender, user, collateral, amountCollateralToRedeem, oilAmountToCover);
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

    /**
     * @notice WTI crude oil has 8 decimals For consistency the result would have 18 decimals
     */
    function getUsdAmountFromOil(uint256 amountOilInWei) public view virtual returns (uint256) {
        int256 price = getCrudeOilPrice();
        return (amountOilInWei * (uint256(price) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function getCrudeOilPrice() public view virtual returns (int256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_crudeOilUsdPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
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
     * @notice Calculate the health factor of a user in USD, by adding collateral in ETH and DAI and dividing by the minted oil in USD
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
}
