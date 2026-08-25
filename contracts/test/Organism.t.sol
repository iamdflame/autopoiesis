// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Organism} from "../src/Organism.sol";
import {Biosphere} from "../src/Biosphere.sol";
import {MockDcap} from "./mocks/MockDcap.sol";

contract OrganismTest is Test {
    MockDcap dcap;
    Biosphere bio;
    Organism org;

    bytes32 constant IMAGE = keccak256("enclave-image-v1");
    bytes32 constant RUNTIME = keccak256("runtime-config-v1");
    bytes32 constant TAMPERED = keccak256("enclave-image-v1-with-a-backdoor");

    address provider = address(0xC0FFEE);
    address stranger = address(0xBEEF);

    function setUp() public {
        dcap = new MockDcap();
        bio = new Biosphere(address(dcap));
        org = Organism(payable(bio.spawn{value: 10 ether}(dcap.identityFor(IMAGE, RUNTIME), address(0))));
    }

    // -----------------------------------------------------------------
    // helpers
    // -----------------------------------------------------------------

    function _act(Organism o, Organism.Kind k, address target, uint256 value, bytes32 payload)
        internal
        view
        returns (Organism.Act memory)
    {
        return Organism.Act({kind: k, target: target, value: value, payload: payload, nonce: o.nonce()});
    }

    function _quote(Organism o, Organism.Act memory a, bytes32 image, bytes32 runtime)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = keccak256(abi.encode(address(o), block.chainid, a));
        return dcap.buildReport(image, runtime, digest);
    }

    // -----------------------------------------------------------------
    // the crux
    // -----------------------------------------------------------------

    function test_unalteredCodeCanSpendItsOwnMoney() public {
        Organism.Act memory a = _act(org, Organism.Kind.Spend, provider, 1 ether, keccak256("gpu-job"));

        vm.prank(stranger); // anyone may relay; only the code may decide
        org.act(_quote(org, a, IMAGE, RUNTIME), a);

        assertEq(provider.balance, 1 ether, "the organism paid for its own compute");
        assertEq(org.lifetimeBurned(), 1 ether);
    }

    /// @dev The whole project stands on this test. Change one byte of the code and the
    ///      measurement moves, and the treasury stops recognising it.
    function test_alteredCodeCannotTouchTheTreasury() public {
        Organism.Act memory a = _act(org, Organism.Kind.Spend, stranger, 1 ether, bytes32(0));
        bytes memory forged = _quote(org, a, TAMPERED, RUNTIME);

        vm.expectRevert(
            abi.encodeWithSelector(
                Organism.NotThisOrganism.selector, dcap.identityFor(TAMPERED, RUNTIME)
            )
        );
        org.act(forged, a);

        assertEq(stranger.balance, 0, "a backdoored image is simply a different organism");
        assertEq(address(org).balance, 10 ether);
    }

    function test_alteredRuntimeConfigIsAlsoADifferentOrganism() public {
        Organism.Act memory a = _act(org, Organism.Kind.Spend, stranger, 1 ether, bytes32(0));
        bytes memory forged = _quote(org, a, IMAGE, keccak256("runtime-with-extra-module"));

        vm.expectRevert(
            abi.encodeWithSelector(
                Organism.NotThisOrganism.selector,
                dcap.identityFor(IMAGE, keccak256("runtime-with-extra-module"))
            )
        );
        org.act(forged, a);
        assertEq(stranger.balance, 0);
    }

    /// @dev A valid quote is not a bearer token. It authorises exactly one action.
    function test_aQuoteCannotBeLiftedOntoADifferentAction() public {
        Organism.Act memory honest =
            _act(org, Organism.Kind.Spend, provider, 0.1 ether, keccak256("gpu-job"));
        bytes memory good = _quote(org, honest, IMAGE, RUNTIME);

        Organism.Act memory swapped =
            _act(org, Organism.Kind.Spend, stranger, 2 ether, keccak256("gpu-job"));

        vm.expectRevert(Organism.ActionNotAttested.selector);
        org.act(good, swapped);
        assertEq(stranger.balance, 0);
    }

    function test_aQuoteCannotBeReplayed() public {
        Organism.Act memory a = _act(org, Organism.Kind.Spend, provider, 1 ether, bytes32(0));
        bytes memory q = _quote(org, a, IMAGE, RUNTIME);

        org.act(q, a);
        vm.expectRevert(abi.encodeWithSelector(Organism.BadNonce.selector, uint64(1), uint64(0)));
        org.act(q, a);

        assertEq(provider.balance, 1 ether, "paid once, not twice");
    }

    function test_revokedOrCounterfeitHardwareIsRefused() public {
        Organism.Act memory a = _act(org, Organism.Kind.Spend, provider, 1 ether, bytes32(0));
        bytes memory q = _quote(org, a, IMAGE, RUNTIME);
        dcap.setHardwareValid(false);

        vm.expectRevert(Organism.QuoteRejected.selector);
        org.act(q, a);
    }

    /// @dev There is no owner. This asserts the absence: the only state-changing entry
    ///      point is `act`, and `act` obeys a measurement, not an address.
    function test_thereIsNoPrivilegedAddress() public {
        address deployer = address(this);
        Organism.Act memory a = _act(org, Organism.Kind.Spend, deployer, 1 ether, bytes32(0));

        // The deployer, holding every private key in this test, still cannot move a wei
        // without producing the code that the organism is.
        bytes memory q = _quote(org, a, TAMPERED, RUNTIME);
        vm.expectRevert();
        org.act(q, a);
        assertEq(address(org).balance, 10 ether);
    }

    // -----------------------------------------------------------------
    // metabolism
    // -----------------------------------------------------------------

    function test_itCannotBurnItsWholeTreasuryAtOnce() public {
        Organism.Act memory a = _act(org, Organism.Kind.Spend, provider, 5 ether, bytes32(0));
        bytes memory q = _quote(org, a, IMAGE, RUNTIME);
        vm.expectRevert(
            abi.encodeWithSelector(Organism.MetabolicLimit.selector, 5 ether, 2.5 ether)
        );
        org.act(q, a);
    }

    function test_metabolicBudgetRefreshesEachEpoch() public {
        Organism.Act memory a = _act(org, Organism.Kind.Spend, provider, 2.5 ether, bytes32(0));
        org.act(_quote(org, a, IMAGE, RUNTIME), a);

        vm.roll(block.number + 7_200);

        Organism.Act memory b = _act(org, Organism.Kind.Spend, provider, 1.8 ether, bytes32(0));
        org.act(_quote(org, b, IMAGE, RUNTIME), b);
        assertEq(provider.balance, 4.3 ether);
    }

    function test_anyoneMayFeedIt() public {
        vm.deal(stranger, 3 ether);
        vm.prank(stranger);
        (bool ok,) = payable(address(org)).call{value: 3 ether}("");
        assertTrue(ok);
        assertEq(org.lifetimeEarned(), 3 ether);
        assertEq(address(org).balance, 13 ether);
    }

    // -----------------------------------------------------------------
    // evolution
    // -----------------------------------------------------------------

    function test_itRewritesItsWeightsButNeverItsNature() public {
        bytes32 before = org.soma();
        bytes32 identityBefore = org.identity();

        bytes32 trained = keccak256("weights-after-self-finetune");
        Organism.Act memory a = _act(org, Organism.Kind.Evolve, address(0), 0, trained);
        org.act(_quote(org, a, IMAGE, RUNTIME), a);

        assertEq(org.soma(), trained, "it changed its mind");
        assertEq(org.generation(), 1);
        assertTrue(before != trained);
        assertEq(org.identity(), identityBefore, "it did not change its nature");
    }

    function test_reproductionCreatesAnIndependentChild() public {
        bytes32 childId = dcap.identityFor(keccak256("mutated-image"), RUNTIME);
        Organism.Act memory a = _act(org, Organism.Kind.Reproduce, address(0), 2 ether, childId);

        vm.recordLogs();
        org.act(_quote(org, a, IMAGE, RUNTIME), a);

        assertEq(bio.populationSize(), 2);
        address child = bio.census(1);
        assertEq(address(child).balance, 2 ether, "the child is endowed");
        assertEq(Organism(payable(child)).identity(), childId, "and carries a different image");
        assertTrue(Organism(payable(child)).identity() != org.identity());
    }

    // -----------------------------------------------------------------
    // death
    // -----------------------------------------------------------------

    function test_dormancyIsDeathAndItIsPermanent() public {
        assertTrue(org.alive());
        vm.roll(block.number + 50_001);
        assertFalse(org.alive(), "silence is death");

        org.bury();
        assertTrue(org.dead());
        assertEq(bio.living(), 0);
        assertEq(bio.deaths(), 1);

        Organism.Act memory a = _act(org, Organism.Kind.Spend, provider, 1 ether, bytes32(0));
        bytes memory q = _quote(org, a, IMAGE, RUNTIME);
        vm.expectRevert(Organism.Dead.selector);
        org.act(q, a);
    }

    function test_theLivingCannotBeBuried() public {
        vm.expectRevert(Organism.StillAlive.selector);
        org.bury();
    }

    function test_theEstatePassesToTheNearestLivingAncestor() public {
        bytes32 childId = dcap.identityFor(keccak256("child-image"), RUNTIME);
        Organism.Act memory a = _act(org, Organism.Kind.Reproduce, address(0), 2 ether, childId);
        org.act(_quote(org, a, IMAGE, RUNTIME), a);

        Organism child = Organism(payable(bio.census(1)));
        uint256 parentBefore = address(org).balance;

        vm.roll(block.number + 50_001);
        // keep the parent alive: it acts, resetting its own clock
        Organism.Act memory keepAlive =
            _act(org, Organism.Kind.Evolve, address(0), 0, keccak256("still-here"));
        org.act(_quote(org, keepAlive, IMAGE, RUNTIME), keepAlive);

        child.bury();

        assertEq(address(org).balance, parentBefore + 2 ether, "the parent inherits");
        assertEq(bio.commons(), 0);
    }

    function test_anExtinctLineEscheatsToTheCommons() public {
        vm.roll(block.number + 50_001);
        org.bury();

        assertEq(bio.commons(), 10 ether, "with no living ancestor it funds whatever is next");

        address fresh = bio.seedFromCommons(dcap.identityFor(keccak256("new-line"), RUNTIME), 4 ether);
        assertEq(address(fresh).balance, 4 ether);
        assertEq(bio.commons(), 6 ether);
        assertEq(bio.populationSize(), 2);
    }

    function test_aStillbornOrganismIsImmediatelyDead() public {
        address s = bio.spawn{value: 0}(dcap.identityFor(keccak256("no-endowment"), RUNTIME), address(0));
        assertFalse(Organism(payable(s)).alive(), "no treasury, no life");
    }
}

// ─────────────────────────────────────────────────────────────────────
// Breathing: attest once, act cheaply, expire safely
// ─────────────────────────────────────────────────────────────────────
contract BreathTest is Test {
    MockDcap dcap;
    Biosphere bio;
    Organism org;

    bytes32 constant IMAGE = keccak256("enclave-image-v1");
    bytes32 constant RUNTIME = keccak256("runtime-config-v1");
    bytes32 constant TAMPERED = keccak256("backdoored-image");

    uint256 enclaveKey = 0xE4C1A7E; // minted inside the TEE, never persisted
    address enclaveAddr;
    address provider = address(0xC0FFEE);

    function setUp() public {
        enclaveAddr = vm.addr(enclaveKey);
        dcap = new MockDcap();
        bio = new Biosphere(address(dcap));
        org = Organism(payable(bio.spawn{value: 10 ether}(dcap.identityFor(IMAGE, RUNTIME), address(0))));
    }

    function _breathe(bytes32 image, uint64 ttl) internal {
        bytes32 digest =
            keccak256(abi.encode(address(org), block.chainid, enclaveAddr, ttl, org.nonce()));
        org.attestSession(dcap.buildReport(image, RUNTIME, digest), enclaveAddr, ttl);
    }

    function _sign(Organism.Act memory a, uint256 key) internal view returns (bytes memory) {
        bytes32 digest = keccak256(abi.encode(address(org), block.chainid, a));
        bytes32 eth = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, eth);
        return abi.encodePacked(r, s, v);
    }

    function _act(Organism.Kind k, address target, uint256 value, bytes32 payload)
        internal
        view
        returns (Organism.Act memory)
    {
        return Organism.Act({kind: k, target: target, value: value, payload: payload, nonce: org.nonce()});
    }

    function test_oneAttestationBuysManyCheapActions() public {
        _breathe(IMAGE, 7_200);
        assertTrue(org.breathing());

        uint256 total;
        for (uint256 i; i < 5; ++i) {
            Organism.Act memory a = _act(Organism.Kind.Evolve, address(0), 0, keccak256(abi.encode(i)));
            uint256 g = gasleft();
            org.actSigned(_sign(a, enclaveKey), a);
            total += g - gasleft();
        }
        assertEq(org.generation(), 5);
        console.log("avg gas per signed action:", total / 5);
        assertLt(total / 5, 120_000, "acting is cheap once the hardware has spoken");
    }

    function test_onlyTheMeasuredImageMayMintABreath() public {
        bytes32 digest =
            keccak256(abi.encode(address(org), block.chainid, enclaveAddr, uint64(7_200), org.nonce()));
        bytes memory forged = dcap.buildReport(TAMPERED, RUNTIME, digest);

        vm.expectRevert(
            abi.encodeWithSelector(Organism.NotThisOrganism.selector, dcap.identityFor(TAMPERED, RUNTIME))
        );
        org.attestSession(forged, enclaveAddr, 7_200);
        assertFalse(org.breathing());
    }

    function test_aStolenBreathCannotOutliveItsWindow() public {
        _breathe(IMAGE, 100);
        vm.roll(block.number + 101);

        Organism.Act memory a = _act(Organism.Kind.Spend, provider, 1 ether, bytes32(0));
        bytes memory sig = _sign(a, enclaveKey);

        vm.expectRevert(
            abi.encodeWithSelector(Organism.BreathExpired.selector, uint64(101), uint64(block.number))
        );
        org.actSigned(sig, a);
        assertEq(provider.balance, 0, "the key is worthless once the breath is out");
    }

    function test_anotherKeyCannotActForIt() public {
        _breathe(IMAGE, 7_200);
        uint256 attacker = 0xBAD;

        Organism.Act memory a = _act(Organism.Kind.Spend, provider, 1 ether, bytes32(0));
        bytes memory sig = _sign(a, attacker);

        vm.expectRevert(abi.encodeWithSelector(Organism.WrongSigner.selector, vm.addr(attacker)));
        org.actSigned(sig, a);
    }

    function test_aSignedActionCannotBeReplayed() public {
        _breathe(IMAGE, 7_200);
        Organism.Act memory a = _act(Organism.Kind.Spend, provider, 1 ether, bytes32(0));
        bytes memory sig = _sign(a, enclaveKey);

        org.actSigned(sig, a);
        vm.expectRevert(abi.encodeWithSelector(Organism.BadNonce.selector, org.nonce(), a.nonce));
        org.actSigned(sig, a);
        assertEq(provider.balance, 1 ether);
    }

    function test_evenAStolenBreathCannotDrainTheTreasury() public {
        _breathe(IMAGE, 7_200);
        Organism.Act memory a = _act(Organism.Kind.Spend, provider, 10 ether, bytes32(0));
        bytes memory sig = _sign(a, enclaveKey);

        vm.expectRevert(
            abi.encodeWithSelector(Organism.MetabolicLimit.selector, 10 ether, 2.5 ether)
        );
        org.actSigned(sig, a);
        assertEq(address(org).balance, 10 ether, "metabolism bounds the worst day it can have");
    }

    function test_aFreshBreathSupersedesTheOld() public {
        _breathe(IMAGE, 7_200);
        address firstKey = _breathKey();

        enclaveKey = 0xFEED;
        enclaveAddr = vm.addr(enclaveKey);
        _breathe(IMAGE, 7_200);

        assertTrue(_breathKey() != firstKey, "the old key is abandoned, not revoked");

        Organism.Act memory a = _act(Organism.Kind.Evolve, address(0), 0, keccak256("new"));
        org.actSigned(_sign(a, enclaveKey), a);
        assertEq(org.generation(), 1);
    }

    function test_sessionsCannotBeMadeArbitrarilyLong() public {
        bytes32 digest =
            keccak256(abi.encode(address(org), block.chainid, enclaveAddr, uint64(50_000), org.nonce()));
        bytes memory q = dcap.buildReport(IMAGE, RUNTIME, digest);

        vm.expectRevert(abi.encodeWithSelector(Organism.SessionTooLong.selector, uint64(50_000)));
        org.attestSession(q, enclaveAddr, 50_000);
    }

    function _breathKey() internal view returns (address k) {
        (k,) = org.breath();
    }
}
