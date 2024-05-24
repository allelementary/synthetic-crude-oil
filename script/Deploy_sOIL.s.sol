// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MessageSender} from "../src/ccip/Sender.sol";
import {MessageReceiver} from "../src/ccip/Receiver.sol";
import {PriceFeedProxy} from "../src/PriceFeedProxy.sol";
import {sOIL} from "../src/sOIL.sol";
import {ChainConfig} from "./ChainConfig.s.sol";
import {MockPriceFeedProxy} from "../test/mocks/MockPriceFeedProxy.sol";

contract Deploy_sOIL is Script, ChainConfig {
    address[] public collateralAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (sOIL, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (
            address wethUsdPriceFeed,
            address daiUsdPriceFeed,
            address crudeOilUsdPriceFeed,
            address ccipRouter,
            uint64 ChainSelector,
            address weth,
            address dai,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        collateralAddresses = [weth, dai];
        priceFeedAddresses = [wethUsdPriceFeed, daiUsdPriceFeed];
        address payable messageSenderAddress = payable(address(0));
        address messageReceiverAddress = address(0);
        address priceFeedProxyAddress;

        vm.startBroadcast(deployerKey);
        // Deploy MessageSender on Source Chain
        if (block.chainid == OPTIMISM_SEPOLIA_CHAIN_ID) {
            MessageSender messageSender = new MessageSender(ccipRouter);
            messageSenderAddress = payable(address(messageSender));
        }

        // Deploy MessageReceiver on Destination Chains
        if (block.chainid == AVALANCHE_FUJI_CHAIN_ID || block.chainid == POLYGON_AMOY_CHAIN_ID) {
            MessageReceiver messageReceiver = new MessageReceiver(ccipRouter);
            messageReceiverAddress = address(messageReceiver);
        }

        if (block.chainid == ANVIL_CHAIN_ID) {
            MockPriceFeedProxy priceFeedProxy = new MockPriceFeedProxy();
            priceFeedProxyAddress = address(priceFeedProxy);
        } else {
            PriceFeedProxy priceFeedProxy =
                new PriceFeedProxy(crudeOilUsdPriceFeed, messageSenderAddress, messageReceiverAddress);
            priceFeedProxyAddress = address(priceFeedProxy);
        }

        sOIL sOil = new sOIL(priceFeedProxyAddress, collateralAddresses, priceFeedAddresses, ChainSelector);
        vm.stopBroadcast();
        return (sOil, helperConfig);
    }
}
