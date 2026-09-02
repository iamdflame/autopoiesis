// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Biosphere} from "../src/Biosphere.sol";
import {Organism} from "../src/Organism.sol";
import {MockDcap} from "./mocks/MockDcap.sol";

/// @notice Replays the exact sequence Bootstrap.s.sol performs, so a mainnet run is not
///         the first time this ordering has ever executed. Deliberately does not import
///         the Script contract: pulling forge-std/Script through the via-IR pipeline
///         exhausts memory on ordinary machines, and the sequence is what matters.
contract BootstrapTest is Test {
    address constant V4 = address(0x4444);
    function test_theDeploymentSequenceProducesALivingOrganism() public {
        // 1. the verifier must already exist — `attestation` is immutable, so there is
        //    no deploy-now-repoint-later path. This ordering is load-bearing.
        MockDcap dcap = new MockDcap();
        dcap.setQuoteVerifier(4, V4);
        bytes32 identity =
            dcap.identityFor(keccak256("enclave-image-v1"), keccak256("runtime-config-v1"));

        // 2. biosphere
        Biosphere bio = new Biosphere(address(dcap), V4);
        assertEq(bio.populationSize(), 0);

        // 3. genesis organism, endowed
        address first = bio.spawn{value: 1 ether}(identity, address(0));
        Organism o = Organism(payable(first));

        assertEq(bio.populationSize(), 1, "one organism exists");
        assertEq(bio.living(), 1);
        assertEq(o.identity(), identity, "it is the image we measured");
        assertEq(address(o).balance, 1 ether, "and it is funded");
        assertTrue(o.alive(), "and alive");
        assertFalse(o.breathing(), "but not breathing yet - the enclave must speak first");
        assertEq(address(o.attestation()), address(dcap), "bound to its verifier, immutably");
        assertEq(o.generation(), 0);

        console.log("Biosphere       ", address(bio));
        console.log("Genesis organism", first);
        console.log("identity        ", vm.toString(identity));
    }

    /// @dev The failure a real deployment is most likely to hit: seeding the genesis
    ///      identity from the wrong image. It does not error — it produces an organism
    ///      that no enclave on earth can ever breathe into. Worth seeing once.
    function test_aWrongIdentityProducesAPermanentlyMuteOrganism() public {
        MockDcap dcap = new MockDcap();
        dcap.setQuoteVerifier(4, V4);
        Biosphere bio = new Biosphere(address(dcap), V4);

        bytes32 wrong = dcap.identityFor(keccak256("some-other-image"), keccak256("runtime-config-v1"));
        Organism o = Organism(payable(bio.spawn{value: 1 ether}(wrong, address(0))));

        // the real enclave attests honestly, and is refused forever
        bytes32 real = dcap.identityFor(keccak256("enclave-image-v1"), keccak256("runtime-config-v1"));
        bytes32 digest = keccak256(abi.encode(address(o), block.chainid, address(0xE4C1A7E), uint64(7_200), o.nonce()));
        bytes memory q = dcap.buildReport(keccak256("enclave-image-v1"), keccak256("runtime-config-v1"), digest);

        vm.expectRevert(abi.encodeWithSelector(Organism.NotThisOrganism.selector, real));
        o.attestSession(q, address(0xE4C1A7E), 7_200);

        assertTrue(o.alive(), "funded and alive");
        assertFalse(o.breathing(), "but mute forever - measure twice before funding");
    }
}
