// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract MockPriceFeedProxy {
    function getLatestPrice() external pure returns (int256) {
        return 100e8;
    }

    function requestPrice(uint64, uint8) external pure {
        // do nothing
    }

    function updatePrice(int256) external pure {
        // do nothing
    }

    function getEstimatedFeeAmount(uint64, uint8) external pure returns (int256) {
        return 0.001e18;
    }
}
