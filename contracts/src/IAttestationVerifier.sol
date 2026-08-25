// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IAttestationVerifier
/// @notice Verifies that a fine-tuning job actually ran inside a TEE on 0G Compute,
///         binding the parent weights, the training dataset and the produced weights
///         into a single statement that cannot be forged by the submitter.
/// @dev    0G Compute signs provider responses with a TEE-held key. An implementation
///         of this interface recovers that signature and checks it against the set of
///         registered provider attestation keys.
interface IAttestationVerifier {
    /// @param parentsDigest keccak256 over the ordered (parentId, weightsRoot) pairs
    /// @param datasetRoot   0G Storage Merkle root of the training corpus
    /// @param outputRoot    0G Storage Merkle root of the produced weights / LoRA delta
    /// @param proof         TEE attestation payload (provider signature + quote digest)
    /// @return ok           true when the statement is authentic
    function verifyTraining(
        bytes32 parentsDigest,
        bytes32 datasetRoot,
        bytes32 outputRoot,
        bytes calldata proof
    ) external view returns (bool ok);
}
