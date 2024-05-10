// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant WETH_USD_PRICE = 3000e8;
    int256 public constant DAI_USD_PRICE = 1e8;
    int256 public constant CRUDE_OIL_USD_PRICE = 100e8;

    struct NetworkConfig {
        address wethUsdPriceFeed;
        address daiUsdPriceFeed;
        address crudeOilUsdPriceFeed;
        address weth;
        address dai;
        uint256 deployerKey;
    }

    uint256 private DEFAULT_ANVIL_PRIVATE_KEY = vm.envUint("DEFAULT_ANVIL_PRIVATE_KEY");

    constructor() {
        if (block.chainid == 80002) {
            // polygon amoy
            activeNetworkConfig = getAmoyConfig();
        } else if (block.chainid == 43113) {
            // avalanche fuji
            activeNetworkConfig = getFujiConfig();
        } else if (block.chainid == 11155111) {
            // ethereum sepolia
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getAmoyConfig() public view returns (NetworkConfig memory amoyNetworkConfig) {
        amoyNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0xF0d50568e3A7e8259E16663972b11910F89BD8e7,
            daiUsdPriceFeed: 0x1896522f28bF5912dbA483AC38D7eE4c920fDB6E,
            crudeOilUsdPriceFeed: 0xF8e2648F3F157D972198479D5C7f0D721657Af67, // solana price feed instead
            weth: 0x387FD5E4Ea72cF66f8eA453Ed648e64908f64104, // mock deployed
            dai: 0xaf9B15aA0557cff606a0616d9B76B94887423022, // mock deployed
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getFujiConfig() public view returns (NetworkConfig memory fujiNetworkConfig) {
        fujiNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x86d67c3D38D2bCeE722E601025C25a575021c6EA,
            daiUsdPriceFeed: 0x7898AcCC83587C3C55116c5230C17a6Cd9C71bad, // USDT cause there is no DAI for testnet
            crudeOilUsdPriceFeed: 0xFC90B9AC95f933713E0eb3fA134582a05627C669, // comp price feed instead
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            dai: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            daiUsdPriceFeed: 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19,
            crudeOilUsdPriceFeed: 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea, // XAU / USD
            weth: 0x005f96B2EA3438B6D7830cF7f6f0F3FF48F35BB2, // mock deployed
            dai: 0x8b3c590D364e7bB9bfe8F94B985297D53D07824a, // mock deployed
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
            weth: address(wethMock),
            daiUsdPriceFeed: address(daiUsdPriceFeed),
            dai: address(daiMock),
            crudeOilUsdPriceFeed: address(crudeOilUsdPriceFeed),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
