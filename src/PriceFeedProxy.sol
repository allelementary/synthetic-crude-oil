// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MessageReceiver} from "./ccip/Receiver.sol";
import {MessageSender} from "./ccip/Sender.sol";
import {ChainConfig} from "../script/ChainConfig.s.sol";

/**
 * @notice This contract would fetch WTI Crude Oil price. As the price is not available for all networks,
 * it would use different mechanisms depending on the network.
 * Chainlink Price Feeds on Optimism would be used as a price source.
 * For other networks the data would be transferred trough Chainlink CCIP.
 */
contract PriceFeedProxy is ChainConfig {
    error PriceFeedProxy__InvalidChainId();

    address private s_crudeOilUsdPriceFeed; // OP Sepolia
    address payable private s_sender; // OP Sepolia
    address private s_receiver; // Amoy/Fuji

    int256 public WTI_CRUDE_OIL_PRICE;

    constructor(address _crudeOilUsdPriceFeed, address payable _sender, address _receiver) {
        s_crudeOilUsdPriceFeed = _crudeOilUsdPriceFeed;
        s_sender = _sender;
        s_receiver = _receiver;
    }

    function getLatestPrice() external view returns (int256) {
        if (block.chainid == OPTIMISM_SEPOLIA_CHAIN_ID) {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(s_crudeOilUsdPriceFeed);
            (, int256 price,,,) = priceFeed.latestRoundData();
            return price;
        } else if (block.chainid == AVALANCHE_FUJI_CHAIN_ID) {
            return MessageReceiver(s_receiver).s_oilPrice();
        } else if (block.chainid == POLYGON_AMOY_CHAIN_ID) {
            return MessageReceiver(s_receiver).s_oilPrice();
        } else {
            revert PriceFeedProxy__InvalidChainId();
        }
    }

    /**
     * @notice run on Source Chain
     * @notice call message sender to request WTI Crude Oil price | OP Sepolia
     * function is available only on Optimism Sepolia (Source Chain)
     * @param destinationChainSelector ChainSelector of the destination chain the price should be updated at
     * @param payFeesIn LINK or Native, 0 for Native, 1 for LINK
     */
    function updatePrice(uint64 destinationChainSelector, MessageSender.PayFeesIn payFeesIn) external {
        if (block.chainid != OPTIMISM_SEPOLIA_CHAIN_ID) {
            revert PriceFeedProxy__InvalidChainId();
        }
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_crudeOilUsdPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        MessageSender(s_sender).send(destinationChainSelector, s_receiver, price, payFeesIn);
    }

    /**
     * @notice run on Source Chain
     * @notice call to get estimated fee amount for sending WTI Crude Oil price | OP Sepolia
     * @param destinationChainSelector ChainSelector of the destination chain the price should be updated at
     * @param payFeesIn LINK or Native, 0 for LINK, 1 for Native
     */
    function getEstimatedFeeAmount(uint64 destinationChainSelector, MessageSender.PayFeesIn payFeesIn)
        external
        view
        returns (uint256)
    {
        if (block.chainid != OPTIMISM_SEPOLIA_CHAIN_ID) {
            revert PriceFeedProxy__InvalidChainId();
        }
        return MessageSender(s_sender).getEstimatedFeeAmount(destinationChainSelector, s_receiver, 0, payFeesIn);
    }
}
