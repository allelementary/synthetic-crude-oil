// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {DeploysCrudeOil, HelperConfig} from "../../script/DeploysCrudeOil.s.sol";
import {sCrudeOil, AggregatorV3Interface} from "../../src/sCrudeOil.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract sCrudeOilTest is Test {
    sCrudeOil public sCrudeOilInstance;
    HelperConfig public helperConfig;

    address public wethUsdPriceFeed;
    address public daiUsdPriceFeed;
    address public crudeOilUsdPriceFeed;
    address public weth;
    address public dai;
    uint256 public deployerKey;

    address public user = makeAddr("User");
    address public liquidator = makeAddr("Liquidator");

    uint256 public constant STARTING_DAI_BALANCE = 75e18;
    uint256 public constant STARTING_WETH_BALANCE = 0.025 ether;
    uint256 public constant MINT_OIL_AMOUNT = 1e10;
    uint256 public constant HALF_MINT_OIL_AMOUNT = 0.5e18;

    function setUp() public {
        DeploysCrudeOil deployer = new DeploysCrudeOil();
        (sCrudeOilInstance, helperConfig) = deployer.run();
        (wethUsdPriceFeed, daiUsdPriceFeed, crudeOilUsdPriceFeed, weth, dai, deployerKey) =
            helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(user, STARTING_WETH_BALANCE);
        ERC20Mock(dai).mint(user, STARTING_DAI_BALANCE);
    }

    modifier depositAndMint() {
        vm.startPrank(user);
        // deposit weth and mint oil
        ERC20Mock(weth).approve(address(sCrudeOilInstance), STARTING_WETH_BALANCE);
        sCrudeOilInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        ERC20Mock(dai).approve(address(sCrudeOilInstance), STARTING_DAI_BALANCE);
        sCrudeOilInstance.depositAndMint(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);

        vm.stopPrank();
        _;
    }

    modifier depositAndMintHalf() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sCrudeOilInstance), STARTING_WETH_BALANCE);
        sCrudeOilInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        ERC20Mock(dai).approve(address(sCrudeOilInstance), STARTING_DAI_BALANCE);
        sCrudeOilInstance.depositCollateral(dai, STARTING_DAI_BALANCE);
        vm.stopPrank();
        _;
    }

    address[] public tokenAddresses;
    address[] public feedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(wethUsdPriceFeed);
        feedAddresses.push(daiUsdPriceFeed);

        vm.expectRevert(sCrudeOil.sCrudeOil__CollateralAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        new sCrudeOil(crudeOilUsdPriceFeed, tokenAddresses, feedAddresses);
    }

    function test_depositWethAndMint() public {
        // Arrange
        vm.startPrank(user);

        // Act
        ERC20Mock(weth).approve(address(sCrudeOilInstance), STARTING_WETH_BALANCE);
        sCrudeOilInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        // Assert
        assertEq(sCrudeOilInstance.s_collateralPerUser(user, weth), STARTING_WETH_BALANCE);
        assertEq(sCrudeOilInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sCrudeOilInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositWethAndMintTransferFailed() public {
        vm.startPrank(user);
        vm.expectRevert();
        sCrudeOilInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositWethAndMintBrokenHealthFactor() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(sCrudeOilInstance), STARTING_WETH_BALANCE);
        vm.expectRevert();
        sCrudeOilInstance.depositAndMint(weth, STARTING_WETH_BALANCE / 2, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositDaiAndMint() public {
        vm.startPrank(user);
        ERC20Mock(dai).approve(address(sCrudeOilInstance), STARTING_DAI_BALANCE);
        sCrudeOilInstance.depositAndMint(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);

        assertEq(sCrudeOilInstance.s_collateralPerUser(user, dai), STARTING_DAI_BALANCE);
        assertEq(sCrudeOilInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sCrudeOilInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositDaiAndMintTransferFailed() public {
        vm.startPrank(user);
        vm.expectRevert();
        sCrudeOilInstance.depositAndMint(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositWeth() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sCrudeOilInstance), STARTING_WETH_BALANCE);
        // sCrudeOilInstance.depositCollateral(weth, STARTING_WETH_BALANCE);
        sCrudeOilInstance.depositCollateral(weth, STARTING_WETH_BALANCE);

        assertEq(sCrudeOilInstance.s_collateralPerUser(user, weth), STARTING_WETH_BALANCE);
        assertEq(sCrudeOilInstance.s_oilMintedPerUser(user), 0);
        vm.stopPrank();
    }

    function test_depositDai() public {
        vm.startPrank(user);
        ERC20Mock(dai).approve(address(sCrudeOilInstance), STARTING_DAI_BALANCE);
        sCrudeOilInstance.depositCollateral(dai, STARTING_DAI_BALANCE);

        assertEq(sCrudeOilInstance.s_collateralPerUser(user, dai), STARTING_DAI_BALANCE);
        vm.stopPrank();
    }

    function test_mintOil() public {
        vm.startPrank(user);
        ERC20Mock(dai).approve(address(sCrudeOilInstance), STARTING_DAI_BALANCE);
        sCrudeOilInstance.depositCollateral(dai, STARTING_DAI_BALANCE);
        sCrudeOilInstance.mintOil(HALF_MINT_OIL_AMOUNT);

        assertEq(sCrudeOilInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sCrudeOilInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemWethAndBurn() public depositAndMint {
        vm.startPrank(user);
        sCrudeOilInstance.redeemAndBurn(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        assertEq(sCrudeOilInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sCrudeOilInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemWethAndBurnTransferFailed() public depositAndMint {
        vm.startPrank(user);
        vm.expectRevert();
        sCrudeOilInstance.redeemAndBurn(weth, STARTING_WETH_BALANCE * 2, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemWethAndBurnHealthFactorBroken() public depositAndMint {
        vm.startPrank(user);
        vm.expectRevert();
        sCrudeOilInstance.redeemAndBurn(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT * 4);
        vm.stopPrank();
    }

    function test_redeemDaiAndBurn() public depositAndMint {
        vm.startPrank(user);
        sCrudeOilInstance.redeemAndBurn(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);

        assertEq(sCrudeOilInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sCrudeOilInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_burn() public depositAndMint {
        vm.startPrank(user);
        uint256 startingHealthFactor = sCrudeOilInstance.getHealthFactor(user);
        sCrudeOilInstance.burn(HALF_MINT_OIL_AMOUNT);
        uint256 finishingHealthFactor = sCrudeOilInstance.getHealthFactor(user);

        assertEq(startingHealthFactor, 1.005e18);
        assertEq(sCrudeOilInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sCrudeOilInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        assertEq(finishingHealthFactor, 2.01e18);
        vm.stopPrank();
    }

    function test_redeemWeth() public depositAndMintHalf {
        vm.startPrank(user);
        sCrudeOilInstance.redeem(weth, STARTING_WETH_BALANCE);

        assertEq(sCrudeOilInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sCrudeOilInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemDai() public depositAndMintHalf {
        vm.startPrank(user);
        sCrudeOilInstance.redeem(dai, STARTING_DAI_BALANCE);

        assertEq(sCrudeOilInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sCrudeOilInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_liquidate() public depositAndMint {
        ERC20Mock(weth).mint(liquidator, STARTING_WETH_BALANCE * 4);
        ERC20Mock(dai).mint(liquidator, STARTING_DAI_BALANCE * 4);

        vm.startPrank(liquidator);
        // deposit weth and mint oil
        ERC20Mock(weth).approve(address(sCrudeOilInstance), STARTING_WETH_BALANCE * 4);
        sCrudeOilInstance.depositAndMint(weth, STARTING_WETH_BALANCE * 4, HALF_MINT_OIL_AMOUNT * 2);
        // deposit dai and mint oil
        ERC20Mock(dai).approve(address(sCrudeOilInstance), STARTING_DAI_BALANCE * 4);
        sCrudeOilInstance.depositAndMint(dai, STARTING_DAI_BALANCE * 4, HALF_MINT_OIL_AMOUNT * 2);

        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(2500e8);

        // liquidate
        sCrudeOilInstance.liquidate(user, weth, HALF_MINT_OIL_AMOUNT);
        uint256 userHealthFactor = sCrudeOilInstance.getHealthFactor(user);
        console2.log("Health Factor: %s", userHealthFactor);
        assert(userHealthFactor > 1e18);
        vm.stopPrank();
    }

    function test_getHealthFactor() public depositAndMint {
        // Arrange
        vm.startPrank(user);
        // Act
        uint256 healthFactor = sCrudeOilInstance.getHealthFactor(user);
        vm.stopPrank();
        // Assert
        assertEq(healthFactor, 1.005e18);
    }

    function test_getUsdAmountFromOil() public view {
        uint256 oilAmount = 1e18;
        uint256 usdAmount = sCrudeOilInstance.getUsdAmountFromOil(oilAmount);
        assertEq(usdAmount, 100e18);
    }

    function test_getUsdAmountFromWeth() public view {
        uint256 ethAmount = 1e18;
        uint256 usdAmount = sCrudeOilInstance.getUsdAmountFromToken(weth, ethAmount);
        assertEq(usdAmount, 3000e18);
    }

    function test_getUsdAmountFromDai() public view {
        uint256 daiAmount = 1e18;
        uint256 usdAmount = sCrudeOilInstance.getUsdAmountFromToken(dai, daiAmount);
        assertEq(usdAmount, 1e18);
    }

    function test_getWethAmountFromUsd() public view {
        uint256 usdAmount = 75e18;
        uint256 ethAmount = sCrudeOilInstance.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(ethAmount, 0.025e18);
    }

    function test_getDaiAmountFromUsd() public view {
        uint256 usdAmount = 75e18;
        uint256 daiAmount = sCrudeOilInstance.getTokenAmountFromUsd(dai, usdAmount);
        assertEq(daiAmount, 75e18);
    }

    function test_getAccountInformationValue() public depositAndMint {
        vm.startPrank(user);
        (uint256 totalOilMintedValueInUsd, uint256 totalCollateralValueUsd) =
            sCrudeOilInstance.getAccountInformationValue(user);
        vm.stopPrank();

        assertEq(totalOilMintedValueInUsd, 100e18);
        assertEq(totalCollateralValueUsd, 150e18);
    }
}
