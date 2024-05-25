// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MessageSender} from "../src/ccip/Sender.sol";
import {MessageReceiver} from "../src/ccip/Receiver.sol";
import {sOIL} from "../src/sOIL.sol";
import {sOilSource} from "../src/sOilSource.sol";
import {sOilDestination} from "../src/sOilDestination.sol";
import {ChainConfig} from "./ChainConfig.s.sol";

contract Deploy_sOIL is Script, ChainConfig {
    address[] public collateralAddresses;
    address[] public priceFeedAddresses;
    uint64[] public chainSelectors;
    address[] public messageReceivers;

    function run() external returns (sOIL _sOil, HelperConfig _helperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (
            address wethUsdPriceFeed,
            address daiUsdPriceFeed,
            address crudeOilUsdPriceFeed,
            address ccipRouter,
            address weth,
            address dai,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        collateralAddresses = [weth, dai];
        priceFeedAddresses = [wethUsdPriceFeed, daiUsdPriceFeed];

        vm.startBroadcast(deployerKey);

        if (block.chainid == OPTIMISM_SEPOLIA_CHAIN_ID) {
            return deployOptimismSepolia(helperConfig, crudeOilUsdPriceFeed, ccipRouter);
        }

        if (block.chainid == AVALANCHE_FUJI_CHAIN_ID || block.chainid == POLYGON_AMOY_CHAIN_ID) {
            return deployDestinationChains(helperConfig, ccipRouter);
        }

        if (block.chainid == ANVIL_CHAIN_ID) {
            return deployAnvil(helperConfig, crudeOilUsdPriceFeed);
        }

        vm.stopBroadcast();
    }

    function deployOptimismSepolia(HelperConfig helperConfig, address crudeOilUsdPriceFeed, address ccipRouter)
        internal
        returns (sOilSource, HelperConfig)
    {
        (
            uint64 avalancheFujiChainSelector,
            uint64 polygonAmoyChainSelector,
            address avalancheFujiReceiver,
            address polygonAmoyReceiver
        ) = helperConfig.destinationChainConfig();
        MessageSender messageSender = new MessageSender(ccipRouter);
        address payable messageSenderAddress = payable(address(messageSender));

        chainSelectors = [avalancheFujiChainSelector, polygonAmoyChainSelector];
        messageReceivers = [avalancheFujiReceiver, polygonAmoyReceiver];
        sOilSource sOil = new sOilSource(
            crudeOilUsdPriceFeed,
            messageSenderAddress,
            collateralAddresses,
            priceFeedAddresses,
            chainSelectors,
            messageReceivers
        );
        vm.stopBroadcast();
        return (sOil, helperConfig);
    }

    function deployDestinationChains(HelperConfig helperConfig, address ccipRouter)
        internal
        returns (sOIL, HelperConfig)
    {
        MessageReceiver messageReceiver = new MessageReceiver(ccipRouter);
        address messageReceiverAddress = address(messageReceiver);

        sOilDestination sOil = new sOilDestination(messageReceiverAddress, collateralAddresses, priceFeedAddresses);
        vm.stopBroadcast();
        return (sOil, helperConfig);
    }

    function deployAnvil(HelperConfig helperConfig, address crudeOilUsdPriceFeed)
        internal
        returns (sOIL, HelperConfig)
    {
        sOIL sOil = new sOIL(crudeOilUsdPriceFeed, collateralAddresses, priceFeedAddresses);
        vm.stopBroadcast();
        return (sOil, helperConfig);
    }
}
