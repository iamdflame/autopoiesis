// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title  TdxReport
/// @notice Parses the TD10 report body out of a verified DCAP attestation output.
///
/// @dev    The verifier returns the quote body only after the signature chain up to
///         Intel's root has checked out, so everything read here is hardware-attested
///         fact rather than caller-supplied data. Layout (Intel TDX v4, TD10ReportBody):
///
///           output = quoteVersion(2) ‖ teeType(4) ‖ tcbStatus(1) ‖ fmspc(6) ‖ body
///
///         and within the 584-byte body:
///
///           teeTcbSvn      0   mrSeam       16   mrSignerSeam  64   seamAttributes 112
///           tdAttributes 120   xFAM        128   mrTd         136   mrConfigId     184
///           mrOwner      232   mrOwnerCfg  280   rtmr0        328   rtmr1          376
///           rtmr2        424   rtmr3       472   reportData   520 (64 bytes)
///
///         `mrTd` measures the initial memory image of the trust domain — the code.
///         The four `rtmr` registers extend with everything measured at runtime.
///         Together they are the organism's body; `reportData` is what it wants to say.
library TdxReport {
    uint256 internal constant HEADER = 13;
    uint256 internal constant BODY_LEN = 584;

    uint256 internal constant OFF_MRTD = HEADER + 136;
    uint256 internal constant OFF_RTMR0 = HEADER + 328;
    uint256 internal constant OFF_REPORT_DATA = HEADER + 520;

    error MalformedReport(uint256 length);

    struct Measurement {
        bytes32 mrTd; // keccak of the 48-byte MRTD — the code image
        bytes32 rtmrs; // keccak over RTMR0..3 — the runtime configuration
    }

    /// @notice Hash the measurement registers into a single stable identity.
    /// @dev    Two enclaves anywhere on earth running the same image produce the same
    ///         value. That is what lets an organism have no home and no operator: it is
    ///         defined by what it is, not by where it runs or which key it holds.
    function identityOf(bytes memory output) internal pure returns (bytes32) {
        _requireWellFormed(output);
        bytes memory mrTd = _slice(output, OFF_MRTD, 48);
        bytes memory rtmrs = _slice(output, OFF_RTMR0, 192); // rtmr0..rtmr3
        return keccak256(abi.encodePacked(keccak256(mrTd), keccak256(rtmrs)));
    }

    /// @notice The 64 bytes the enclave chose to commit to inside the quote.
    /// @dev    This is the whole trick. The organism binds the hash of the action it
    ///         intends to take into report_data *before* the quote is signed, so the
    ///         hardware attests not merely "this code is running" but "this code, right
    ///         now, wants exactly this". A quote cannot be lifted and reused for a
    ///         different action, because the action is inside the signature.
    function reportData(bytes memory output) internal pure returns (bytes32 lo, bytes32 hi) {
        _requireWellFormed(output);
        // 533 = HEADER(13) + 520; literals required by inline assembly.
        assembly {
            lo := mload(add(add(output, 0x20), 533))
            hi := mload(add(add(output, 0x20), 565))
        }
    }

    function _requireWellFormed(bytes memory output) private pure {
        if (output.length < HEADER + BODY_LEN) revert MalformedReport(output.length);
    }

    function _slice(bytes memory data, uint256 start, uint256 len)
        private
        pure
        returns (bytes memory out)
    {
        out = new bytes(len);
        for (uint256 i; i < len; ++i) {
            out[i] = data[start + i];
        }
    }
}
