// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";
import {ChainConfig} from "./ChainConfig.s.sol";

contract HelperConfig is Script, ChainConfig {
    NetworkConfig public activeNetworkConfig;
    DestinationChainConfig public destinationChainConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant WETH_USD_PRICE = 3000e8;
    int256 public constant DAI_USD_PRICE = 1e8;
    int256 public constant CRUDE_OIL_USD_PRICE = 100e8;

    struct NetworkConfig {
        address wethUsdPriceFeed;
        address daiUsdPriceFeed;
        address crudeOilUsdPriceFeed;
        address ccipRouter;
        address weth;
        address dai;
        uint256 deployerKey;
    }

    struct DestinationChainConfig {
        uint64 avalancheFujiChainSelector;
        uint64 polygonAmoyChainSelector;
        address avalancheFujiReceiver;
        address polygonAmoyReceiver;
    }

    uint256 private DEFAULT_ANVIL_PRIVATE_KEY = vm.envUint("DEFAULT_ANVIL_PRIVATE_KEY");

    constructor() {
        destinationChainConfig = getDestinationChainConfig();
        if (block.chainid == POLYGON_AMOY_CHAIN_ID) {
            activeNetworkConfig = getAmoyConfig();
        } else if (block.chainid == AVALANCHE_FUJI_CHAIN_ID) {
            activeNetworkConfig = getFujiConfig();
        } else if (block.chainid == OPTIMISM_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getOptimismSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getOptimismSepoliaConfig() public view returns (NetworkConfig memory optimismSepoliaNetworkConfig) {
        optimismSepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x61Ec26aA57019C486B10502285c5A3D4A4750AD7,
            daiUsdPriceFeed: 0x4beA21743541fE4509790F1606c37f2B2C312479,
            crudeOilUsdPriceFeed: 0x43B6b749Ec83a69Bb87FD9E2c2998b4a083BC4f4,
            ccipRouter: 0x114A20A10b43D4115e5aeef7345a1A71d2a60C57,
            weth: 0x387FD5E4Ea72cF66f8eA453Ed648e64908f64104, // mock deployed
            dai: 0xaf9B15aA0557cff606a0616d9B76B94887423022, // mock deployed
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getDestinationChainConfig() public pure returns (DestinationChainConfig memory config) {
        config = DestinationChainConfig({
            avalancheFujiChainSelector: 14767482510784806043,
            polygonAmoyChainSelector: 16281711391670634445,
            avalancheFujiReceiver: 0xd6a80097825cB7957bD8bdA9676f8aDae35265BC,
            polygonAmoyReceiver: 0x98243Ace02e8bF668f7a565b5bc6E79BF584a768
        });
    }

    function getAmoyConfig() public view returns (NetworkConfig memory amoyNetworkConfig) {
        amoyNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0xF0d50568e3A7e8259E16663972b11910F89BD8e7,
            daiUsdPriceFeed: 0x1896522f28bF5912dbA483AC38D7eE4c920fDB6E,
            crudeOilUsdPriceFeed: address(0), // 0xF8e2648F3F157D972198479D5C7f0D721657Af67, // solana price feed instead
            ccipRouter: 0x9C32fCB86BF0f4a1A8921a9Fe46de3198bb884B2,
            weth: 0x387FD5E4Ea72cF66f8eA453Ed648e64908f64104, // mock deployed
            dai: 0xaf9B15aA0557cff606a0616d9B76B94887423022, // mock deployed
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getFujiConfig() public view returns (NetworkConfig memory fujiNetworkConfig) {
        fujiNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x86d67c3D38D2bCeE722E601025C25a575021c6EA,
            daiUsdPriceFeed: 0x7898AcCC83587C3C55116c5230C17a6Cd9C71bad, // USDT used, cause there is no DAI for testnet
            crudeOilUsdPriceFeed: address(0),
            ccipRouter: 0xF694E193200268f9a4868e4Aa017A0118C9a8177,
            weth: 0x9991D14b93CD58fE8dD1A5a901608f18664225Ff,
            dai: 0xC49E3c2b119026500cC442DA8D7c34316a1D3cF1,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator wethUsdPriceFeed = new MockV3Aggregator(DECIMALS, WETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 0);

        MockV3Aggregator daiUsdPriceFeed = new MockV3Aggregator(DECIMALS, DAI_USD_PRICE);
        ERC20Mock daiMock = new ERC20Mock("DAI", "DAI", msg.sender, 0);

        MockV3Aggregator crudeOilUsdPriceFeed = new MockV3Aggregator(DECIMALS, CRUDE_OIL_USD_PRICE);

        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: address(wethUsdPriceFeed),
            daiUsdPriceFeed: address(daiUsdPriceFeed),
            crudeOilUsdPriceFeed: address(crudeOilUsdPriceFeed),
            ccipRouter: address(0),
            weth: address(wethMock),
            dai: address(daiMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
