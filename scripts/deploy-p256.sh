#!/usr/bin/env bash
# Deploy the Daimo P256 (secp256r1) verifier to its canonical address.
#
# Intel signs DCAP quotes with P-256. The EVM has no native secp256r1, so DCAP
# verification needs either the RIP-7212 precompile at 0x100 or a Solidity verifier.
# 0G mainnet has neither, so before any attestation can happen on 0G, this has to exist.
#
# Deployed through the canonical CREATE2 factory so it lands at the same address it has
# on every other chain — 0xc2b78104907F722DABAc4C69f826a522B2754De4 — which means anyone
# else on 0G can use it without knowing we deployed it.
set -euo pipefail

NET="${NET:-mainnet}"
RPC=$( [ "$NET" = "mainnet" ] && echo https://evmrpc.0g.ai || echo https://evmrpc-testnet.0g.ai )
FACTORY=0x4e59b44847b379578588920cA78FbF26c0B4956C
DAIMO=0xc2b78104907F722DABAc4C69f826a522B2754De4
: "${PRIVATE_KEY:?PRIVATE_KEY not set}"

existing=$(cast code "$DAIMO" --rpc-url "$RPC")
if [ "${#existing}" -gt 2 ]; then
  echo "already deployed at $DAIMO ($(( (${#existing}-2)/2 )) bytes)"; exit 0
fi

echo "deploying P256 verifier via CREATE2 factory on 0G $NET..."
cast send "$FACTORY" "$(cat "$(dirname "$0")/p256.calldata")" \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json | tee /tmp/p256.json | \
  python3 -c 'import json,sys; d=json.load(sys.stdin); print("  tx:", d["transactionHash"]); print("  gas used:", int(d["gasUsed"],16) if isinstance(d["gasUsed"],str) else d["gasUsed"])'

code=$(cast code "$DAIMO" --rpc-url "$RPC")
[ "${#code}" -gt 2 ] || { echo "FAILED: no code at $DAIMO"; exit 1; }
echo "  ✓ P256 verifier live at $DAIMO ($(( (${#code}-2)/2 )) bytes)"
