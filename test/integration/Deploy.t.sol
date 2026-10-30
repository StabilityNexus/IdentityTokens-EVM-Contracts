// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Deploy } from "../../script/Deploy.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { IdentitySystem } from "../../src/IdentitySystem.sol";
import { ProfileSystem } from "../../src/ProfileSystem.sol";

contract DeployTest is Test {
    // Tests run on Anvil's chain id, so this uses the fixed local accounts
    function test_Deploy_Anvil() public {
        HelperConfig.NetworkConfig memory config = new HelperConfig().getAnvilConfig();

        (IdentitySystem identitySystem, ProfileSystem profileSystem) = new Deploy().run();

        assertEq(identitySystem.admin(), vm.addr(config.deployerKey));
        assertEq(identitySystem.dev(), config.dev);
        assertEq(identitySystem.devFeeReceiver(), config.devFeeReceiver);
        assertEq(identitySystem.devFee(), config.devFee);
        assertEq(identitySystem.profileSystem(), address(profileSystem));
        assertEq(address(profileSystem.identitySystem()), address(identitySystem));
    }

    // Any other chain reads the deployer key and dev-fee settings from the environment
    function test_HelperConfig_LiveChain() public {
        vm.chainId(61);
        vm.setEnv("PRIVATE_KEY", "0xa11ce");
        vm.setEnv("DEV", vm.toString(address(0xDE7)));
        vm.setEnv("DEV_FEE_RECEIVER", vm.toString(address(0xFEE)));
        vm.setEnv("DEV_FEE", "250");

        HelperConfig.NetworkConfig memory config = new HelperConfig().getConfig();

        assertEq(config.deployerKey, 0xa11ce);
        assertEq(config.dev, address(0xDE7));
        assertEq(config.devFeeReceiver, address(0xFEE));
        assertEq(config.devFee, 250);
    }
}
