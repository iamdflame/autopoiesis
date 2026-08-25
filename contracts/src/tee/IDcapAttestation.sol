// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice On-chain Intel DCAP quote verification (Automata-compatible).
/// @dev    Verifies the full certificate chain from the quote up to Intel's root,
///         against collateral held in an on-chain PCCS. No off-chain oracle, no
///         trusted attestation service — the chain itself checks the hardware.
interface IDcapAttestation {
    function verifyAndAttestOnChain(bytes calldata rawQuote)
        external
        view
        returns (bool success, bytes memory output);
}
