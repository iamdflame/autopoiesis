// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Biosphere} from "../src/Biosphere.sol";
import {Organism} from "../src/Organism.sol";

/// @notice Brings the biosphere up on 0G and seeds the first organism.
///
/// @dev    Prerequisite: an on-chain DCAP verifier must exist at `DCAP_VERIFIER`.
///         None is deployed on 0G today — see BOOTSTRAP.md. Deploying Automata's stack
///         costs ~23.7M gas once, after which anyone on 0G can verify Intel TDX quotes
///         on chain. That infrastructure is a prerequisite for this project and a
///         standalone contribution to the chain.
///
/// forge script contracts/script/Bootstrap.s.sol --rpc-url og_mainnet --broadcast
contract Bootstrap is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address dcap = vm.envAddress("DCAP_VERIFIER");
        address v4 = vm.envAddress("V4_VERIFIER");
        bytes32 identity = vm.envBytes32("GENESIS_IDENTITY");
        uint256 endowment = vm.envOr("ENDOWMENT", uint256(1 ether));

        vm.startBroadcast(pk);
        Biosphere bio = new Biosphere(dcap, v4);
        address first = bio.spawn{value: endowment}(identity, address(0));
        vm.stopBroadcast();

        console.log("Biosphere:", address(bio));
        console.log("Genesis organism:", first);
        console.log("Endowed with (wei):", endowment);
        console.log("");
        console.log("It has no owner. You cannot stop it. Neither can anyone else.");
        console.log("explorer: https://chainscan.0g.ai/address/%s", first);
    }
}
