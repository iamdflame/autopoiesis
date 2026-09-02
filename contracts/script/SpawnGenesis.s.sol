// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Biosphere} from "../src/Biosphere.sol";

/// @notice Spawn the first organism into the Biosphere that is already deployed.
///
/// @dev    `Bootstrap.s.sol` deploys a *new* Biosphere, which is what you want once.
///         There was previously no way to act on the live one at 0x577B…, so the
///         documented final step targeted a contract that did not exist yet.
///
///         GENESIS_IDENTITY must come from a real quote — see scripts/measure.sh.
///         A guessed value produces a funded, living, permanently mute organism.
///
/// BIOSPHERE=0x577B… GENESIS_IDENTITY=0x… ENDOWMENT=… \
/// forge script contracts/script/SpawnGenesis.s.sol --rpc-url og_mainnet --broadcast
contract SpawnGenesis is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Biosphere bio = Biosphere(payable(vm.envAddress("BIOSPHERE")));
        bytes32 identity = vm.envBytes32("GENESIS_IDENTITY");
        uint256 endowment = vm.envOr("ENDOWMENT", uint256(0.1 ether));

        require(identity != bytes32(0), "GENESIS_IDENTITY unset: see scripts/measure.sh");
        require(endowment >= bio.MIN_ENDOWMENT(), "endowment below the biosphere minimum");

        vm.startBroadcast(pk);
        address organism = bio.spawn{value: endowment}(identity, address(0));
        vm.stopBroadcast();

        console.log("Organism:", organism);
        console.log("explorer: https://chainscan.0g.ai/address/%s", organism);
    }
}
