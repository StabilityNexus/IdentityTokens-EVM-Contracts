// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IdentitySystem } from "../src/IdentitySystem.sol";
import { ProfileSystem } from "../src/ProfileSystem.sol";

// Ethereum Classic stops at Shanghai, so the deployed code must not use the opcodes Cancun added.
// OpenZeppelin needs evm_version = cancun to compile, which is fine while the optimizer leaves them out.
contract EvmCompatTest is Test {
    function test_RuntimeCode_NoCancunOpcodes() public {
        IdentitySystem identitySystem = new IdentitySystem(address(1), address(1), 100);
        ProfileSystem profileSystem = new ProfileSystem(address(identitySystem));

        _assertNoCancunOpcodes(address(identitySystem).code);
        _assertNoCancunOpcodes(address(profileSystem).code);
    }

    function _assertNoCancunOpcodes(bytes memory code) internal pure {
        // The CBOR metadata at the end is data, not code; its length is in the last two bytes
        uint256 metadataLength = (uint256(uint8(code[code.length - 2])) << 8) | uint8(code[code.length - 1]);
        uint256 end = code.length - 2 - metadataLength;

        for (uint256 i; i < end; i++) {
            uint8 op = uint8(code[i]);
            // BLOBHASH, BLOBBASEFEE, TLOAD, TSTORE, MCOPY
            assertTrue(op != 0x49 && op != 0x4a && (op < 0x5c || op > 0x5e), "Cancun opcode in runtime code");
            // Skip the data bytes of PUSH1..PUSH32
            if (op >= 0x60 && op <= 0x7f) i += op - 0x5f;
        }
    }
}
