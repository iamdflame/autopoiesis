// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IDcapAttestation} from "../../src/tee/IDcapAttestation.sol";

/// @notice Stands in for the on-chain DCAP verifier, reproducing the exact byte layout a
///         real Intel TDX quote verification returns so the parser is exercised for real
///         rather than around.
contract MockDcap is IDcapAttestation {
    bool public hardwareValid = true;

    function setHardwareValid(bool v) external {
        hardwareValid = v;
    }

    function verifyAndAttestOnChain(bytes calldata rawQuote)
        external
        view
        returns (bool, bytes memory)
    {
        return (hardwareValid, rawQuote);
    }

    /// @notice Assemble a TD10 report body at the offsets the library reads.
    function buildReport(bytes32 mrTdSeed, bytes32 rtmrSeed, bytes32 commitment)
        public
        pure
        returns (bytes memory out)
    {
        out = new bytes(13 + 584);
        bytes memory mrTd = _expand(mrTdSeed, 48);
        bytes memory rtmrs = _expand(rtmrSeed, 192);

        for (uint256 i; i < 48; ++i) out[13 + 136 + i] = mrTd[i];
        for (uint256 i; i < 192; ++i) out[13 + 328 + i] = rtmrs[i];
        for (uint256 i; i < 32; ++i) out[13 + 520 + i] = commitment[i];
    }

    /// @notice The identity a given image measures to.
    function identityFor(bytes32 mrTdSeed, bytes32 rtmrSeed) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(keccak256(_expand(mrTdSeed, 48)), keccak256(_expand(rtmrSeed, 192)))
        );
    }

    function _expand(bytes32 seed, uint256 len) private pure returns (bytes memory b) {
        b = new bytes(len);
        for (uint256 i; i < len; ++i) {
            b[i] = seed[i % 32];
        }
    }
}
