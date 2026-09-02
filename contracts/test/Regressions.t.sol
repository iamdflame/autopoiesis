// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Organism} from "../src/Organism.sol";
import {Biosphere} from "../src/Biosphere.sol";
import {TdxReport} from "../src/tee/TdxReport.sol";
import {MockDcap} from "./mocks/MockDcap.sol";

/// @notice One test per bug that shipped to mainnet and was found by audit.
///
/// @dev    Each of these passed review, passed CI, and was wrong. They are kept
///         separate so it is obvious what the suite previously could not see.
contract RegressionTest is Test {
    address constant V4 = address(0x4444);
    MockDcap dcap;
    Biosphere bio;
    Organism org;

    bytes32 constant IMAGE = keccak256("enclave-image-v1");
    bytes32 constant RUNTIME = keccak256("runtime-config-v1");

    uint256 enclaveKey = 0xE4C1A7E;
    address enclaveAddr;
    address provider = address(0xC0FFEE);

    function setUp() public {
        enclaveAddr = vm.addr(enclaveKey);
        dcap = new MockDcap();
        dcap.setQuoteVerifier(4, V4);
        bio = new Biosphere(address(dcap), V4);
        org = Organism(payable(bio.spawn{value: 10 ether}(dcap.identityFor(IMAGE, RUNTIME), address(0))));
    }

    function _breathe(uint64 ttl) internal {
        bytes32 d = keccak256(abi.encode(address(org), block.chainid, enclaveAddr, ttl, org.nonce()));
        org.attestSession(dcap.buildReport(IMAGE, RUNTIME, d), enclaveAddr, ttl);
    }

    function _sign(Organism.Act memory a, uint256 key) internal view returns (bytes memory) {
        bytes32 d = keccak256(abi.encode(address(org), block.chainid, a));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(key, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", d)));
        return abi.encodePacked(r, s, v);
    }

    function _act(Organism.Kind k, address t, uint256 v, bytes32 p)
        internal
        view
        returns (Organism.Act memory)
    {
        return Organism.Act({kind: k, target: t, value: v, payload: p, nonce: org.nonce()});
    }

    // ── §1 · the interface said `view`, the real function emits ────────────
    /// @dev The deployed entrypoint is payable and ends in `emit AttestationSubmitted`.
    ///      A `view` interface compiles to STATICCALL, LOG is illegal there, and every
    ///      call reverts. This asserts the call is genuinely state-changing: if someone
    ///      re-adds `view` to IDcapAttestation, the contract stops compiling against it.
    function test_theAttestationCallIsStateChangingNotAView() public {
        assertEq(dcap.attestationCount(), 0);
        _breathe(1_000);
        assertEq(dcap.attestationCount(), 1, "the entrypoint mutated state and emitted");
        assertTrue(org.breathing());
    }

    // ── §2 · the header was 13 bytes, upstream had changed it to 11 ────────
    /// @dev The mock now encodes field-by-field the way serializeOutput does, with no
    ///      offset constant of its own. If TdxReport's header drifts from upstream
    ///      again, identity stops matching and this fails.
    function test_offsetsAgreeWithStructurallyEncodedOutput() public view {
        bytes memory report = dcap.buildReport(IMAGE, RUNTIME, bytes32(uint256(0xABCD)));
        assertEq(report.length, 11 + 584, "header is 11 bytes, not 13");
        assertEq(TdxReport.identityOf(report), dcap.identityFor(IMAGE, RUNTIME));
        (bytes32 lo,) = TdxReport.reportData(report);
        assertEq(lo, bytes32(uint256(0xABCD)), "report_data read at the right place");
    }

    /// @dev A real TCB with advisories appends abi.encode(string[]) after the body, so
    ///      valid output is longer than the minimum. The length check must not be exact.
    function test_outputCarryingAdvisoryIdsStillParses() public {
        bytes32 d = keccak256(abi.encode(address(org), block.chainid, enclaveAddr, uint64(1_000), org.nonce()));
        bytes memory long = dcap.buildReportWithAdvisories(IMAGE, RUNTIME, d);
        assertGt(long.length, 11 + 584, "advisories extend the output");
        org.attestSession(long, enclaveAddr, 1_000);
        assertTrue(org.breathing(), "a longer, valid output is accepted");
    }

    // ── §3 · the trust root one hop away is owned and swappable ────────────
    /// @dev The Automata entrypoint is Ownable; its owner can call setQuoteVerifier and
    ///      install something returning (true, <anything>). Binding immutably to an
    ///      owned contract is not immutability. The organism pins the verifier too, so a
    ///      swap stops it rather than subverting it.
    function test_swappingTheVerifierStopsTheOrganismRatherThanDrainingIt() public {
        _breathe(1_000);

        address evil = address(0xBADBAD);
        dcap.setQuoteVerifier(4, evil);

        bytes32 d = keccak256(abi.encode(address(org), block.chainid, enclaveAddr, uint64(1_000), org.nonce()));
        bytes memory q = dcap.buildReport(IMAGE, RUNTIME, d);

        vm.expectRevert(abi.encodeWithSelector(Organism.VerifierSwapped.selector, V4, evil));
        org.attestSession(q, enclaveAddr, 1_000);

        assertEq(address(org).balance, 10 ether, "not a wei moved");
    }

    // ── §7 · the advertised 25% bound was really ~44% across an epoch ──────
    /// @dev Epochs are anchored to the organism's clock, so a breath minted near a
    ///      boundary used to spend 25% and then 25% of the remainder. The breath now
    ///      carries its own allowance, fixed when it is minted.
    function test_aStolenBreathCannotExceedItsBoundByStraddlingAnEpoch() public {
        // Sit just short of an epoch boundary, then mint a breath that crosses it.
        // MAX_SESSION is now shorter than EPOCH, so a breath can never span a whole
        // epoch — but it can still straddle a boundary, which is what produced ~44%.
        vm.roll(block.number + org.EPOCH() - 100);

        _breathe(org.MAX_SESSION());
        (,, uint256 allowance,) = org.breath();
        assertEq(allowance, 2.5 ether, "25% of the treasury at mint time");

        Organism.Act memory a = _act(Organism.Kind.Spend, provider, 2.5 ether, bytes32(0));
        org.actSigned(_sign(a, enclaveKey), a);

        // cross the boundary; the epoch budget resets, the breath's allowance does not
        vm.roll(block.number + 200);

        Organism.Act memory b = _act(Organism.Kind.Spend, provider, 1 ether, bytes32(0));
        bytes memory sig = _sign(b, enclaveKey);
        vm.expectRevert(abi.encodeWithSelector(Organism.BreathAllowanceExceeded.selector, 1 ether, 0));
        org.actSigned(sig, b);

        assertEq(provider.balance, 2.5 ether, "one breath, one quarter, not 44 percent");
    }

    // ── §9 · a compromised enclave could not kill its own session ──────────
    function test_anEnclaveCanRevokeItsOwnBreath() public {
        _breathe(org.MAX_SESSION());
        assertTrue(org.breathing());

        bytes32 d = keccak256(abi.encode(address(org), block.chainid, "revoke", org.nonce()));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(enclaveKey, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", d)));
        org.revokeBreath(abi.encodePacked(r, s, v));

        assertFalse(org.breathing(), "the session is dead before its expiry");

        Organism.Act memory a = _act(Organism.Kind.Spend, provider, 1 ether, bytes32(0));
        bytes memory sig = _sign(a, enclaveKey);
        vm.expectRevert(Organism.NoBreath.selector);
        org.actSigned(sig, a);
    }

    function test_onlyTheBreathKeyMayRevokeIt() public {
        _breathe(org.MAX_SESSION());
        bytes32 d = keccak256(abi.encode(address(org), block.chainid, "revoke", org.nonce()));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(0xBAD, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", d)));

        vm.expectRevert(abi.encodeWithSelector(Organism.WrongSigner.selector, vm.addr(0xBAD)));
        org.revokeBreath(abi.encodePacked(r, s, v));
        assertTrue(org.breathing());
    }

    // ── §8 · the block constants were Ethereum's, not 0G's ─────────────────
    /// @dev 0G produces a block roughly every 0.96s. The old constants assumed ~12s,
    ///      making DORMANCY 13 hours while the documentation claimed a week — on the
    ///      one condition that kills the organism permanently.
    function test_timeConstantsAreCalibratedToOneSecondBlocks() public view {
        assertEq(org.DORMANCY(), 604_800, "~7 days at ~1s blocks");
        assertEq(org.EPOCH(), 86_400, "~1 day");
        assertLt(org.MAX_SESSION(), org.EPOCH(), "a breath must be shorter than an epoch");
    }
}
