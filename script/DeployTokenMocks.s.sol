// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {WethMock, DaiMock} from "../test/mocks/TokenMocks.sol";

contract DeployTokenMocks is Script {
    function run() external returns (WethMock, DaiMock) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        WethMock weth = new WethMock();
        DaiMock dai = new DaiMock();
        vm.stopBroadcast();
        return (weth, dai);
    }
}

contract DeployWethMock is Script {
    function run() external returns (WethMock) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        WethMock weth = new WethMock();
        vm.stopBroadcast();
        return weth;
    }
}

contract DeployDaiMock is Script {
    function run() external returns (DaiMock) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        DaiMock dai = new DaiMock();
        vm.stopBroadcast();
        return dai;
    }
}
