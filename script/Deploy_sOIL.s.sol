// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {sOIL} from "../src/sOIL.sol";

contract Deploy_sOIL is Script {
    address[] public collateralAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (sOIL, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (
            address wethUsdPriceFeed,
            address daiUsdPriceFeed,
            address crudeOilUsdPriceFeed,
            address weth,
            address dai,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        collateralAddresses = [weth, dai];
        priceFeedAddresses = [wethUsdPriceFeed, daiUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        sOIL sOil = new sOIL(crudeOilUsdPriceFeed, collateralAddresses, priceFeedAddresses);
        vm.stopBroadcast();
        return (sOil, helperConfig);
    }
}
