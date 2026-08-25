// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Cambrian} from "../src/Cambrian.sol";

/// @notice Deploys Cambrian to 0G. Mainnet chain id is 16661.
/// forge script contracts/script/Deploy.s.sol --rpc-url og_mainnet --broadcast
contract Deploy is Script {
    function run() external returns (Cambrian c) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        string memory baseURI = vm.envOr("BASE_URI", string("https://cambrian.wtf/api/node/"));
        address verifier = vm.envOr("VERIFIER", address(0));

        vm.startBroadcast(pk);
        c = new Cambrian(baseURI, verifier);
        vm.stopBroadcast();

        console.log("Cambrian deployed at:", address(c));
        console.log("chain id:", block.chainid);
        console.log("explorer: https://chainscan.0g.ai/address/%s", address(c));
    }
}
