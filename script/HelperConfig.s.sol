// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    /* VRF Mock Value */
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    address public constant FOUNDRY_DEFAULT_SENDER =
        0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337; // Local Anvil chain ID
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 subscriptionId;
        bytes32 gasLane;
        uint256 interval;
        uint256 entranceFee;
        uint32 callbackGasLimit;
        address vrfCoodininator;
        address link;
        address account;
    }
// 用于配置和管理网络参数的部分。具体来说，这些代码的目的是为了定义一个网络配置结构以及与不同区块链网络的链 ID 相关的配置映射。
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    // 该构造函数的作用是将一个网络配置存储到一个名为 networkConfigs 的映射中，使用一个常量 ETH_SEPOLIA_CHAIN_ID 作为键，并将 getSepoliaEthConfig() 函数的返回值作为对应的值。通过这个构造函数，合约在部署时会将 Sepolia 测试网络的配置存储到 networkConfigs 映射中。这样一来，合约在运行时可以方便地根据不同的网络配置进行操作。这是一种常见的模式，使合约能够灵活应对不同的网络环境，允许开发者在不同的上下文中重用同一份代码而无需修改。
    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoodininator != address(0)) {  // 在 Solidity 中，address(0) 是一个特殊的地址，表示空地址。通常用于检查某个地址是否有效（即，是否已被重新赋值或初始化）。
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                subscriptionId: 89243532882676294538749616156956555885880706825493057877730550955810708870550, // metamask-Colinssolidity created. If left as 0, our scripts will create one!
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae
                interval: 30, // 30 seconds
                entranceFee: 0.01 ether, // 1e16
                callbackGasLimit: 500000, // 50,000
                vrfCoodininator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // https://docs.chain.link/vrf/v2-5/supported-networks
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account:0xCc65351A2ea7eBbE5772735a82556f2D451607d5
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // check to see if we set an active network config
        if (localNetworkConfig.vrfCoodininator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mocks and such
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMork = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, // 1e16
            interval: 30, // 30 seconds
            vrfCoodininator: address(vrfCoordinatorMork),
            // doesn't matter
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // doesn't matter
            callbackGasLimit: 500000, // 500,000 gas
            subscriptionId: 0, // might have to fix this
            link: address(linkToken),
            account: FOUNDRY_DEFAULT_SENDER
        });

        return localNetworkConfig;
    }
}
