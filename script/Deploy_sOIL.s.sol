// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MessageSender} from "../src/ccip/Sender.sol";
import {MessageReceiver} from "../src/ccip/Receiver.sol";
import {PriceFeedProxy} from "../src/PriceFeedProxy.sol";
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
            address ccipRouter,
            uint64 ChainSelector,
            address link,
            address weth,
            address dai,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        collateralAddresses = [weth, dai];
        priceFeedAddresses = [wethUsdPriceFeed, daiUsdPriceFeed];
        address payable messageSenderAddress = payable(address(0));
        address messageReceiverAddress = address(0);

        vm.startBroadcast(deployerKey);
        // Deploy MessageSender on Source Chain
        if (block.chainid == 11155420) {
            MessageSender messageSender = new MessageSender(ccipRouter, link);
            messageSenderAddress = payable(address(messageSender));
        }

        // Deploy MessageReceiver on Destination Chains
        if (block.chainid == 43113 || block.chainid == 80002) {
            MessageReceiver messageReceiver = new MessageReceiver(ccipRouter);
            messageReceiverAddress = address(messageReceiver);
        }

        PriceFeedProxy priceFeedProxy =
            new PriceFeedProxy(crudeOilUsdPriceFeed, messageSenderAddress, messageReceiverAddress);
        sOIL sOil = new sOIL(address(priceFeedProxy), collateralAddresses, priceFeedAddresses, ChainSelector);
        vm.stopBroadcast();
        return (sOil, helperConfig);
    }
}
