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
        address ccipRouter;
        uint64 ChainSelector;
        address link;
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
        } else if (block.chainid == 11155420) {
            // optimism sepolia
            activeNetworkConfig = getOptimismSepoliaConfig();
        } else if (block.chainid == 11155111) {
            // ethereum sepolia
            activeNetworkConfig = getEthSepoliaConfig();
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
            ChainSelector: 5224473277236331295,
            link: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
            weth: 0x387FD5E4Ea72cF66f8eA453Ed648e64908f64104, // mock deployed
            dai: 0xaf9B15aA0557cff606a0616d9B76B94887423022, // mock deployed
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAmoyConfig() public view returns (NetworkConfig memory amoyNetworkConfig) {
        amoyNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0xF0d50568e3A7e8259E16663972b11910F89BD8e7,
            daiUsdPriceFeed: 0x1896522f28bF5912dbA483AC38D7eE4c920fDB6E,
            crudeOilUsdPriceFeed: address(0), // 0xF8e2648F3F157D972198479D5C7f0D721657Af67, // solana price feed instead
            ccipRouter: 0x9C32fCB86BF0f4a1A8921a9Fe46de3198bb884B2,
            ChainSelector: 16281711391670634445,
            link: 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904,
            weth: 0x387FD5E4Ea72cF66f8eA453Ed648e64908f64104, // mock deployed
            dai: 0xaf9B15aA0557cff606a0616d9B76B94887423022, // mock deployed
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getFujiConfig() public view returns (NetworkConfig memory fujiNetworkConfig) {
        fujiNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x86d67c3D38D2bCeE722E601025C25a575021c6EA,
            daiUsdPriceFeed: 0x7898AcCC83587C3C55116c5230C17a6Cd9C71bad, // USDT cause there is no DAI for testnet
            crudeOilUsdPriceFeed: address(0), //0xFC90B9AC95f933713E0eb3fA134582a05627C669, // comp price feed instead
            ccipRouter: 0xF694E193200268f9a4868e4Aa017A0118C9a8177,
            ChainSelector: 14767482510784806043,
            link: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            dai: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getEthSepoliaConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            daiUsdPriceFeed: 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19,
            crudeOilUsdPriceFeed: address(0), //0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea, // XAU / USD
            ccipRouter: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            ChainSelector: 16015286601757825753,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
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

        ERC20Mock linkMock = new ERC20Mock("LINK", "LINK", msg.sender, 0);

        MockV3Aggregator crudeOilUsdPriceFeed = new MockV3Aggregator(DECIMALS, CRUDE_OIL_USD_PRICE);
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: address(wethUsdPriceFeed),
            daiUsdPriceFeed: address(daiUsdPriceFeed),
            crudeOilUsdPriceFeed: address(crudeOilUsdPriceFeed),
            ccipRouter: address(0),
            ChainSelector: 0,
            link: address(linkMock),
            weth: address(wethMock),
            dai: address(daiMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
