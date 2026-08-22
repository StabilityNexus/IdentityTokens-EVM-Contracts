// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { IdentitySystem } from "../src/IdentitySystem.sol";
import { ProfileSystem } from "../src/ProfileSystem.sol";
import { HelperConfig } from "./HelperConfig.s.sol";

contract Deploy is Script {
    function run() external returns (IdentitySystem, ProfileSystem) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.deployerKey);

        IdentitySystem identitySystem = new IdentitySystem();

        ProfileSystem profileSystem = new ProfileSystem(address(identitySystem));

        identitySystem.setProfileSystem(address(profileSystem));

        vm.stopBroadcast();

        return (identitySystem, profileSystem);
    }
}
