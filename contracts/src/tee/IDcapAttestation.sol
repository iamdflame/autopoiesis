// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice On-chain Intel DCAP quote verification (Automata-compatible).
/// @dev    Verifies the full certificate chain from the quote up to Intel's root,
///         against collateral held in an on-chain PCCS. No off-chain oracle, no
///         trusted attestation service — the chain itself checks the hardware.
interface IDcapAttestation {
    /// @dev NOT `view`, and this matters more than it looks.
    ///
    ///      The deployed entrypoint is `payable` and its body ends with
    ///      `emit AttestationSubmitted(...)`. Declaring this `view` makes solc emit
    ///      STATICCALL, and LOG is illegal in a static context — so every call
    ///      against the real verifier reverts, and the organism can never act.
    ///
    ///      An earlier revision of this repo declared it `view`. The bug was invisible
    ///      because the only quote ever passed to it was six bytes of garbage, which
    ///      returns early on a length check *before* reaching the emit. That is the one
    ///      branch in the whole contract that cannot expose the fault.
    ///
    ///      Fee is read from the entrypoint's basis points, currently zero on 0G, so a
    ///      zero-value call is accepted. If that ever changes, callers must forward it.
    function verifyAndAttestOnChain(bytes calldata rawQuote)
        external
        payable
        returns (bool success, bytes memory output);

    /// @notice Which verifier contract handles a given quote version.
    /// @dev    Owner-swappable on the entrypoint, which is why `Organism` pins the
    ///         address it expects and refuses to proceed if it changes.
    function quoteVerifiers(uint16 quoteVersion) external view returns (address);
}
