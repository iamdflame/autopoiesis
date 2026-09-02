// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IDcapAttestation} from "../../src/tee/IDcapAttestation.sol";

/// @notice Stands in for the deployed DCAP entrypoint.
///
/// @dev    Deliberately built to be able to *disagree* with the parser.
///
///         The previous version of this mock laid bytes down at `13 + offset` — the same
///         magic number `TdxReport` was reading with. Mock and parser encoded the same
///         belief, so they agreed with each other and the suite passed while both were
///         two bytes wrong against the real chain. Textbook circular testing: the test
///         asserted the assumption instead of the behaviour.
///
///         This version encodes semantically, field by field, exactly as Automata's
///         `QuoteVerifierBase.serializeOutput` does:
///
///           quoteVersion ‖ quoteBodyType ‖ tcbStatus ‖ fmspcBytes ‖ quoteBody
///
///         and assembles the 584-byte TD10 body from its named parts. No offset constant
///         appears anywhere in this file. If `TdxReport.HEADER` drifts from upstream
///         again, these tests fail — which is the entire point of a test.
contract MockDcap is IDcapAttestation {
    bool public hardwareValid = true;
    mapping(uint16 => address) public verifiers;

    /// @notice Set by tests to prove the entrypoint really is state-changing, and that
    ///         an interface declaring it `view` would revert here under STATICCALL.
    uint256 public attestationCount;

    event AttestationSubmitted(bool success, uint8 zk, bytes output);

    function setHardwareValid(bool v) external {
        hardwareValid = v;
    }

    function setQuoteVerifier(uint16 version, address v) external {
        verifiers[version] = v;
    }

    function quoteVerifiers(uint16 version) external view returns (address) {
        return verifiers[version];
    }

    /// @dev Mirrors the real entrypoint: payable, state-changing, and it emits. The
    ///      emit is what makes a `view` interface fatal, so the mock must emit too.
    function verifyAndAttestOnChain(bytes calldata rawQuote)
        external
        payable
        returns (bool, bytes memory)
    {
        unchecked {
            ++attestationCount;
        }
        emit AttestationSubmitted(hardwareValid, 0, rawQuote);
        return (hardwareValid, rawQuote);
    }

    // -----------------------------------------------------------------
    // Structural encoders — no offsets, only field order
    // -----------------------------------------------------------------

    /// @notice Assemble a TD10 report body from its named fields, in spec order.
    function td10Body(bytes32 mrTdSeed, bytes32 rtmrSeed, bytes32 commitment)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _fill(bytes32("tcbsvn"), 16), // teeTcbSvn
            _fill(bytes32("mrseam"), 48), // mrSeam
            _fill(bytes32("mrsigner"), 48), // mrSignerSeam
            _fill(bytes32("seamattr"), 8), // seamAttributes
            _fill(bytes32("tdattr"), 8), // tdAttributes
            _fill(bytes32("xfam"), 8), // xFAM
            _fill(mrTdSeed, 48), // mrTd            ← identity
            _fill(bytes32("mrconfig"), 48), // mrConfigId
            _fill(bytes32("mrowner"), 48), // mrOwner
            _fill(bytes32("mrownercfg"), 48), // mrOwnerConfig
            _fill(rtmrSeed, 192), // rtmr0..rtmr3    ← identity
            abi.encodePacked(commitment, bytes32(0)) // reportData (64) ← action binding
        );
    }

    /// @notice Wrap a body exactly as `serializeOutput` does.
    function buildReport(bytes32 mrTdSeed, bytes32 rtmrSeed, bytes32 commitment)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint16(4), // quoteVersion
            uint16(2), // quoteBodyType (TD10)
            uint8(0), // tcbStatus
            bytes6(0x00906ea10000), // fmspcBytes
            td10Body(mrTdSeed, rtmrSeed, commitment)
        );
    }

    /// @notice A real TCB with advisories appends `abi.encode(string[])` after the body,
    ///         so valid output is often longer than the minimum. Parsers must not
    ///         require an exact length.
    function buildReportWithAdvisories(bytes32 mrTdSeed, bytes32 rtmrSeed, bytes32 commitment)
        external
        pure
        returns (bytes memory)
    {
        string[] memory ids = new string[](2);
        ids[0] = "INTEL-SA-00334";
        ids[1] = "INTEL-SA-00615";
        return abi.encodePacked(buildReport(mrTdSeed, rtmrSeed, commitment), abi.encode(ids));
    }

    /// @notice The identity a given image measures to.
    function identityFor(bytes32 mrTdSeed, bytes32 rtmrSeed) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(keccak256(_fill(mrTdSeed, 48)), keccak256(_fill(rtmrSeed, 192)))
        );
    }

    function _fill(bytes32 seed, uint256 len) private pure returns (bytes memory b) {
        b = new bytes(len);
        for (uint256 i; i < len; ++i) {
            b[i] = seed[i % 32];
        }
    }
}
