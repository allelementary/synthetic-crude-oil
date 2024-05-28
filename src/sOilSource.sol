// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {sOIL} from "./sOIL.sol";
import {MessageSender} from "./ccip/Sender.sol";

/**
 * @title Synthetic Crude Oil Token (sOIL)
 * @author Mikhail Antonov
 * @notice sOIL contract for Source Chain that have access to the WTI Crude Oil price feed
 */
contract sOilSource is sOIL {
    error sOIL__ChainSelectorsAndMessageReceiversAmountsDontMatch();
    error sOIL__InvalidSenderAddress();

    address payable public s_sender;

    mapping(uint64 => address) s_messageReceivers;

    constructor(
        address _s_crudeOilUsdPriceFeed,
        address payable _s_sender,
        address[] memory collateralAddresses,
        address[] memory priceFeedAddresses,
        uint64[] memory chainSelectors,
        address[] memory _messageReceivers
    ) sOIL(_s_crudeOilUsdPriceFeed, collateralAddresses, priceFeedAddresses) {
        if (chainSelectors.length != _messageReceivers.length) {
            revert sOIL__ChainSelectorsAndMessageReceiversAmountsDontMatch();
        }
        if (_s_sender == address(0)) {
            revert sOIL__InvalidSenderAddress();
        }
        s_sender = _s_sender;
        for (uint256 i = 0; i < chainSelectors.length; i++) {
            s_messageReceivers[chainSelectors[i]] = _messageReceivers[i];
        }
    }

    /**
     * @dev Function to update the Crude Oil price on the destination chain
     * @param destinationChainSelector ChainSelector of the destination chain the price should be updated at
     */
    function updateCrudeOilPriceOnDestinationChain(uint64 destinationChainSelector) external payable {
        int256 price = getCrudeOilPrice();
        MessageSender(s_sender).send{value: msg.value}(
            destinationChainSelector, s_messageReceivers[destinationChainSelector], price
        );
    }

    /**
     * @dev Function estimates the fee amount for updating the Crude Oil price on the destination chain
     * @param destinationChainSelector ChainSelector of the destination chain the price should be updated at
     */
    function getEstimatedFeeAmount(uint64 destinationChainSelector) external view returns (uint256) {
        return MessageSender(s_sender).getEstimatedFeeAmount(
            destinationChainSelector, s_messageReceivers[destinationChainSelector], 0
        );
    }
}
