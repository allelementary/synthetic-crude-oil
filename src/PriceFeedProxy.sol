// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MessageReceiver} from "./ccip/Receiver.sol";
import {MessageSender} from "./ccip/Sender.sol";

/**
 * @notice This contract would fetch WTI Crude Oil price. As the price is not available for all networks,
 * it would use different mechanisms depending on the network.
 * Chainlink Price Feeds on Optimism would be used as a price source.
 * For other networks the data would be transferred trough Chainlink CCIP.
 */
contract PriceFeedProxy {
    error PriceFeedProxy__InvalidChainId();

    address private crudeOilUsdPriceFeed; // OP Sepolia
    address payable private sender; // OP Sepolia
    address private receiver; // Amoy/Fuji

    int256 public WTI_CRUDE_OIL_PRICE;

    constructor(address _crudeOilUsdPriceFeed, address payable _sender, address _receiver) {
        crudeOilUsdPriceFeed = _crudeOilUsdPriceFeed;
        sender = _sender;
        receiver = _receiver;
    }

    function getLatestPrice() external view returns (int256) {
        // todo: extract chainIds into constants
        if (block.chainid == 11155420) {
            // Optimism Sepolia
            AggregatorV3Interface priceFeed = AggregatorV3Interface(crudeOilUsdPriceFeed);
            (, int256 price,,,) = priceFeed.latestRoundData();
            return price;
        } else if (block.chainid == 43113) {
            // Avalanche Fuji
            return WTI_CRUDE_OIL_PRICE;
        } else if (block.chainid == 80002) {
            // Polygon Amoy
            return WTI_CRUDE_OIL_PRICE;
        } else {
            return WTI_CRUDE_OIL_PRICE; // Anvil
        }
    }

    /**
     * @notice call message sender to request WTI Crude Oil price | OP Sepolia
     * function is available only on Optimism Sepolia (Source Chain)
     * @param destinationChainSelector ChainSelector of the destination chain the price should be updated at
     * @param payFeesIn LINK or Native, 0 for LINK, 1 for Native
     */
    function requestPrice(uint64 destinationChainSelector, MessageSender.PayFeesIn payFeesIn) external {
        if (block.chainid != 11155420) {
            revert PriceFeedProxy__InvalidChainId();
        }
        AggregatorV3Interface priceFeed = AggregatorV3Interface(crudeOilUsdPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        MessageSender(sender).send(destinationChainSelector, receiver, price, payFeesIn);
    }

    /**
     * @notice call message receiver and update WTI Crude Oil price | Amoy/Fuji
     * function is available only on Avalanche Fuji and Polygon Amoy (Destination Chains)
     */
    function updatePrice() external {
        if (block.chainid != 43113 && block.chainid != 80002) {
            revert PriceFeedProxy__InvalidChainId();
        }
        (,,, int256 oilPrice) = MessageReceiver(receiver).getLatestMessageDetails();
        WTI_CRUDE_OIL_PRICE = oilPrice;
    }
}
