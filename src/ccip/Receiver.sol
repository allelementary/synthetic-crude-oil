// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

/**
 * @notice receive WTI Crude Oil price from Source Chain (OP Sepolia)
 */
contract MessageReceiver is CCIPReceiver {
    bytes32 s_latestMessageId;
    uint64 s_latestSourceChainSelector;
    address s_latestSender;
    int256 public s_oilPrice;

    event MessageReceived(
        bytes32 latestMessageId, uint64 latestSourceChainSelector, address latestSender, int256 oilPrice
    );

    constructor(address router) CCIPReceiver(router) {}

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override onlyRouter {
        s_latestMessageId = message.messageId;
        s_latestSourceChainSelector = message.sourceChainSelector;
        s_latestSender = abi.decode(message.sender, (address));
        s_oilPrice = abi.decode(message.data, (int256));

        emit MessageReceived(s_latestMessageId, s_latestSourceChainSelector, s_latestSender, s_oilPrice);
    }
}
