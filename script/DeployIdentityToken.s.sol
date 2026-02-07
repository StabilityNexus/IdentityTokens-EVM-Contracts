// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/IdentityToken.sol";

contract DeployIdentityToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        IdentityToken token = new IdentityToken();
        console.log("IdentityToken deployed to:", address(token));

        vm.stopBroadcast();
    }
}
