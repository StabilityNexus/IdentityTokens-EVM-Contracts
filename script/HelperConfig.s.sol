// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Script } from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 deployerKey;
        address dev;
        address devFeeReceiver;
        uint256 devFee;
    }

    // AOSSIE's wallet, the initial dev and donation receiver
    address public constant AOSSIE = 0xda4772b474C4490D482094e836Dcae1979e0d6d4;

    // Percent of each transaction's gas fee: 100 means the donation equals the gas fee
    uint256 public constant DEFAULT_DEV_FEE = 100;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 31337) {
            activeNetworkConfig = getAnvilConfig();
        } else {
            activeNetworkConfig = getLiveConfig();
        }
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getAnvilConfig() public pure returns (NetworkConfig memory) {
        // Anvil default account #0 deploys; #1 is dev and #2 receives donations
        return
            NetworkConfig({
                deployerKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80,
                dev: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
                devFeeReceiver: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
                devFee: DEFAULT_DEV_FEE
            });
    }

    // Any live chain (Ethereum, Ethereum Classic, testnets): the chain comes from --rpc-url, the rest from .env
    function getLiveConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                deployerKey: vm.envUint("PRIVATE_KEY"),
                dev: vm.envOr("DEV", AOSSIE),
                devFeeReceiver: vm.envOr("DEV_FEE_RECEIVER", AOSSIE),
                devFee: vm.envOr("DEV_FEE", DEFAULT_DEV_FEE)
            });
    }
}
