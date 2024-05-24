// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

/**
 * @notice send WTI Crude Oil price to Destination Chain (Amoy/Fuji)
 */
contract MessageSender {
    address immutable i_router;

    event MessageSent(bytes32 messageId);

    constructor(address router) {
        i_router = router;
    }

    receive() external payable {}

    function send(uint64 destinationChainSelector, address receiver, int256 oilPrice)
        external
        payable
        returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(oilPrice),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_router).getFee(destinationChainSelector, message);

        messageId = IRouterClient(i_router).ccipSend{value: fee}(destinationChainSelector, message);

        emit MessageSent(messageId);
    }

    function getEstimatedFeeAmount(uint64 destinationChainSelector, address receiver, int256 oilPrice)
        external
        view
        returns (uint256)
    {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(oilPrice),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(0)
        });

        return IRouterClient(i_router).getFee(destinationChainSelector, message);
    }
}
