// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {sOIL} from "./sOIL.sol";
import {MessageReceiver} from "./ccip/Receiver.sol";

/**
 * @title Synthetic Crude Oil Token (sOIL)
 * @author Mikhail Antonov
 * @notice sOIL contract for Destination Chains that doesn't have access to the WTI Crude Oil price feed
 * and would need to rely on the Source Chain to update the price
 */
contract sOilDestination is sOIL {
    error sOIL__InvalidReceiverAddress();
    error sOIL__OilPriceHasToBeUpdated();

    address public s_receiver;

    constructor(address _receiver, address[] memory collateralAddresses, address[] memory priceFeedAddresses)
        sOIL(address(0), collateralAddresses, priceFeedAddresses)
    {
        if (_receiver == address(0)) {
            revert sOIL__InvalidReceiverAddress();
        }
        s_receiver = _receiver;
    }

    /**
     * @notice WTI crude oil has 8 decimals For consistency the result would have 18 decimals
     */
    function getUsdAmountFromOil(uint256 amountOilInWei) public view override(sOIL) returns (uint256) {
        int256 price = getCrudeOilPrice();
        if (price == 0) {
            revert sOIL__OilPriceHasToBeUpdated();
        }
        return (amountOilInWei * (uint256(price) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function getCrudeOilPrice() public view override(sOIL) returns (int256) {
        return MessageReceiver(s_receiver).s_oilPrice();
    }
}
