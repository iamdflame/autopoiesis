// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title  TdxReport
/// @notice Parses the TD10 report body out of a verified DCAP attestation output.
///
/// @dev    Layout is dictated by `QuoteVerifierBase.serializeOutput`, which packs:
///
///           quoteVersion(uint16) ‖ quoteBodyType(uint16) ‖ tcbStatus(uint8)
///           ‖ fmspcBytes(bytes6) ‖ quoteBody ‖ [abi.encode(advisoryIDs)]
///
///         so the header is **11 bytes**, not 13.
///
///         An earlier revision of this file used 13, copied from an Automata revision
///         where the second field was `bytes4 tee` rather than `uint16 quoteBodyType`.
///         Upstream changed it; these offsets did not. Two bytes of drift moved every
///         read: the length check rejected valid output, the RTMR slice ran two bytes
///         into `report_data` — making the "stable" identity change on every quote,
///         since report_data carries a fresh action digest each time — and the action
///         binding compared the wrong 32 bytes. Three separate permanent failures from
///         one stale constant.
///
///         The deploy scripts now pin Automata to a commit for exactly this reason.
///         Offsets copied from an unpinned dependency are a bug waiting for an upgrade.
///
///         Within the 584-byte TD10 body:
///
///           teeTcbSvn      0   mrSeam       16   mrSignerSeam  64   seamAttributes 112
///           tdAttributes 120   xFAM        128   mrTd         136   mrConfigId     184
///           mrOwner      232   mrOwnerCfg  280   rtmr0        328   rtmr1          376
///           rtmr2        424   rtmr3       472   reportData   520 (64 bytes)
library TdxReport {
    /// @dev quoteVersion(2) + quoteBodyType(2) + tcbStatus(1) + fmspcBytes(6)
    uint256 internal constant HEADER = 11;
    uint256 internal constant BODY_LEN = 584;

    uint256 internal constant OFF_MRTD = HEADER + 136; // 147
    uint256 internal constant OFF_RTMR0 = HEADER + 328; // 339
    uint256 internal constant OFF_REPORT_DATA = HEADER + 520; // 531

    error MalformedReport(uint256 length);

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
        // 531 = HEADER(11) + 520; literals required by inline assembly.
        assembly {
            lo := mload(add(add(output, 0x20), 531))
            hi := mload(add(add(output, 0x20), 563))
        }
    }

    /// @dev Length is checked as a minimum, never an equality: when the TCB carries
    ///      advisory IDs the verifier appends `abi.encode(string[])` after the body, so
    ///      a valid output is frequently longer than 595 bytes.
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
