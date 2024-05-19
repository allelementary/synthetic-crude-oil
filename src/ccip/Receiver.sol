// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

/**
 * @notice receive WTI Crude Oil price from another chain
 */
contract MessageReceiver is CCIPReceiver {
    bytes32 latestMessageId;
    uint64 latestSourceChainSelector;
    address latestSender;
    int256 oilPrice;

    event MessageReceived(
        bytes32 latestMessageId, uint64 latestSourceChainSelector, address latestSender, int256 oilPrice
    );

    constructor(address router) CCIPReceiver(router) {}

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override onlyRouter {
        latestMessageId = message.messageId;
        latestSourceChainSelector = message.sourceChainSelector;
        latestSender = abi.decode(message.sender, (address));
        oilPrice = abi.decode(message.data, (int256));

        emit MessageReceived(latestMessageId, latestSourceChainSelector, latestSender, oilPrice);
    }

    function getLatestMessageDetails() public view returns (bytes32, uint64, address, int256) {
        return (latestMessageId, latestSourceChainSelector, latestSender, oilPrice);
    }
}
