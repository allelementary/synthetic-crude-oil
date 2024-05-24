// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {Deploy_sOIL, HelperConfig} from "../../script/Deploy_sOIL.s.sol";
import {sOIL, AggregatorV3Interface} from "../../src/sOIL.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract sOILTest is Test {
    sOIL sOILInstance;
    HelperConfig helperConfig;

    address wethUsdPriceFeed;
    address daiUsdPriceFeed;
    address crudeOilUsdPriceFeed;
    address link;
    address weth;
    address dai;
    uint256 deployerKey;

    address user = makeAddr("User");
    address liquidator = makeAddr("Liquidator");

    uint256 constant STARTING_DAI_BALANCE = 75e18;
    uint256 constant STARTING_WETH_BALANCE = 0.025 ether;
    uint256 constant MINT_OIL_AMOUNT = 1e10;
    uint256 constant HALF_MINT_OIL_AMOUNT = 0.5e18;

    function setUp() public {
        Deploy_sOIL deployer = new Deploy_sOIL();
        (sOILInstance, helperConfig) = deployer.run();
        (wethUsdPriceFeed, daiUsdPriceFeed, crudeOilUsdPriceFeed,,, weth, dai, deployerKey) =
            helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(user, STARTING_WETH_BALANCE);
        ERC20Mock(dai).mint(user, STARTING_DAI_BALANCE);
    }

    modifier depositAndMint() {
        vm.startPrank(user);
        // deposit weth and mint oil
        ERC20Mock(weth).approve(address(sOILInstance), STARTING_WETH_BALANCE);
        sOILInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        ERC20Mock(dai).approve(address(sOILInstance), STARTING_DAI_BALANCE);
        sOILInstance.depositAndMint(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);

        vm.stopPrank();
        _;
    }

    modifier depositAndMintHalf() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sOILInstance), STARTING_WETH_BALANCE);
        sOILInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        ERC20Mock(dai).approve(address(sOILInstance), STARTING_DAI_BALANCE);
        sOILInstance.depositCollateral(dai, STARTING_DAI_BALANCE);
        vm.stopPrank();
        _;
    }

    address[] public tokenAddresses;
    address[] public feedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(wethUsdPriceFeed);
        feedAddresses.push(daiUsdPriceFeed);

        vm.expectRevert(sOIL.sOIL__CollateralAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        new sOIL(makeAddr("priceFeedProxy"), tokenAddresses, feedAddresses, 0);
    }

    function test_depositWethAndMint() public {
        // Arrange
        vm.startPrank(user);

        // Act
        ERC20Mock(weth).approve(address(sOILInstance), STARTING_WETH_BALANCE);
        sOILInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        // Assert
        assertEq(sOILInstance.s_collateralPerUser(user, weth), STARTING_WETH_BALANCE);
        assertEq(sOILInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sOILInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositWethAndMintTransferFailed() public {
        vm.startPrank(user);
        vm.expectRevert();
        sOILInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositWethAndMintBrokenHealthFactor() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(sOILInstance), STARTING_WETH_BALANCE);
        vm.expectRevert();
        sOILInstance.depositAndMint(weth, STARTING_WETH_BALANCE / 2, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositDaiAndMint() public {
        vm.startPrank(user);
        ERC20Mock(dai).approve(address(sOILInstance), STARTING_DAI_BALANCE);
        sOILInstance.depositAndMint(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);

        assertEq(sOILInstance.s_collateralPerUser(user, dai), STARTING_DAI_BALANCE);
        assertEq(sOILInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sOILInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositDaiAndMintTransferFailed() public {
        vm.startPrank(user);
        vm.expectRevert();
        sOILInstance.depositAndMint(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositWeth() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sOILInstance), STARTING_WETH_BALANCE);
        sOILInstance.depositCollateral(weth, STARTING_WETH_BALANCE);

        assertEq(sOILInstance.s_collateralPerUser(user, weth), STARTING_WETH_BALANCE);
        assertEq(sOILInstance.s_oilMintedPerUser(user), 0);
        vm.stopPrank();
    }

    function test_depositDai() public {
        vm.startPrank(user);
        ERC20Mock(dai).approve(address(sOILInstance), STARTING_DAI_BALANCE);
        sOILInstance.depositCollateral(dai, STARTING_DAI_BALANCE);

        assertEq(sOILInstance.s_collateralPerUser(user, dai), STARTING_DAI_BALANCE);
        vm.stopPrank();
    }

    function test_mintOil() public {
        vm.startPrank(user);
        ERC20Mock(dai).approve(address(sOILInstance), STARTING_DAI_BALANCE);
        sOILInstance.depositCollateral(dai, STARTING_DAI_BALANCE);
        sOILInstance.mintOil(HALF_MINT_OIL_AMOUNT);

        assertEq(sOILInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sOILInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemWethAndBurn() public depositAndMint {
        vm.startPrank(user);
        sOILInstance.redeemAndBurn(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        assertEq(sOILInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sOILInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemWethAndBurnTransferFailed() public depositAndMint {
        vm.startPrank(user);
        vm.expectRevert();
        sOILInstance.redeemAndBurn(weth, STARTING_WETH_BALANCE * 2, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemWethAndBurnHealthFactorBroken() public depositAndMint {
        vm.startPrank(user);
        vm.expectRevert();
        sOILInstance.redeemAndBurn(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT * 4);
        vm.stopPrank();
    }

    function test_redeemDaiAndBurn() public depositAndMint {
        vm.startPrank(user);
        sOILInstance.redeemAndBurn(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);

        assertEq(sOILInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sOILInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_burn() public depositAndMint {
        vm.startPrank(user);
        uint256 startingHealthFactor = sOILInstance.getHealthFactor(user);
        sOILInstance.burn(HALF_MINT_OIL_AMOUNT);
        uint256 finishingHealthFactor = sOILInstance.getHealthFactor(user);

        assertEq(startingHealthFactor, 1.005e18);
        assertEq(sOILInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sOILInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        assertEq(finishingHealthFactor, 2.01e18);
        vm.stopPrank();
    }

    function test_redeemWeth() public depositAndMintHalf {
        vm.startPrank(user);
        sOILInstance.redeem(weth, STARTING_WETH_BALANCE);

        assertEq(sOILInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sOILInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemDai() public depositAndMintHalf {
        vm.startPrank(user);
        sOILInstance.redeem(dai, STARTING_DAI_BALANCE);

        assertEq(sOILInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(sOILInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_liquidate() public depositAndMint {
        ERC20Mock(weth).mint(liquidator, STARTING_WETH_BALANCE * 4);
        ERC20Mock(dai).mint(liquidator, STARTING_DAI_BALANCE * 4);

        vm.startPrank(liquidator);
        // deposit weth and mint oil
        ERC20Mock(weth).approve(address(sOILInstance), STARTING_WETH_BALANCE * 4);
        sOILInstance.depositAndMint(weth, STARTING_WETH_BALANCE * 4, HALF_MINT_OIL_AMOUNT * 2);
        // deposit dai and mint oil
        ERC20Mock(dai).approve(address(sOILInstance), STARTING_DAI_BALANCE * 4);
        sOILInstance.depositAndMint(dai, STARTING_DAI_BALANCE * 4, HALF_MINT_OIL_AMOUNT * 2);

        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(2500e8);

        // liquidate
        sOILInstance.liquidate(user, weth, HALF_MINT_OIL_AMOUNT);
        uint256 userHealthFactor = sOILInstance.getHealthFactor(user);
        console2.log("Health Factor: %s", userHealthFactor);
        assert(userHealthFactor > 1e18);
        vm.stopPrank();
    }

    function test_getHealthFactor() public depositAndMint {
        // Arrange
        vm.startPrank(user);
        // Act
        uint256 healthFactor = sOILInstance.getHealthFactor(user);
        vm.stopPrank();
        // Assert
        assertEq(healthFactor, 1.005e18);
    }

    function test_getUsdAmountFromOil() public view {
        uint256 oilAmount = 1e18;
        uint256 usdAmount = sOILInstance.getUsdAmountFromOil(oilAmount);
        assertEq(usdAmount, 100e18);
    }

    function test_getUsdAmountFromWeth() public view {
        uint256 ethAmount = 1e18;
        uint256 usdAmount = sOILInstance.getUsdAmountFromToken(weth, ethAmount);
        assertEq(usdAmount, 3000e18);
    }

    function test_getUsdAmountFromDai() public view {
        uint256 daiAmount = 1e18;
        uint256 usdAmount = sOILInstance.getUsdAmountFromToken(dai, daiAmount);
        assertEq(usdAmount, 1e18);
    }

    function test_getWethAmountFromUsd() public view {
        uint256 usdAmount = 75e18;
        uint256 ethAmount = sOILInstance.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(ethAmount, 0.025e18);
    }

    function test_getDaiAmountFromUsd() public view {
        uint256 usdAmount = 75e18;
        uint256 daiAmount = sOILInstance.getTokenAmountFromUsd(dai, usdAmount);
        assertEq(daiAmount, 75e18);
    }

    function test_getAccountInformationValue() public depositAndMint {
        vm.startPrank(user);
        (uint256 totalOilMintedValueInUsd, uint256 totalCollateralValueUsd) =
            sOILInstance.getAccountInformationValue(user);
        vm.stopPrank();

        assertEq(totalOilMintedValueInUsd, 100e18);
        assertEq(totalCollateralValueUsd, 150e18);
    }
}
