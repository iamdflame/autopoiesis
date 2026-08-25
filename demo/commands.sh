#!/usr/bin/env bash
# Paste these ONE BLOCK AT A TIME while recording. Every one is pre-verified
# against 0G mainnet. Do not improvise on camera.

export RPC=https://evmrpc.0g.ai
export BIO=0x577B21214e6549044f9c2A58835713Dda0d849dE
export ENTRY=0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86
export P256=0xc2b78104907F722DABAc4C69f826a522B2754De4
export Z=0x0000000000000000000000000000000000000000

# ─── SHOT 1 · the failed theft ───────────────────────────────────────
# Type these one at a time. Let each revert sit on screen for a beat.
cast call $BIO "owner()(address)"      --rpc-url $RPC
cast call $BIO "admin()(address)"      --rpc-url $RPC
cast call $BIO "pause()"               --rpc-url $RPC
cast call $BIO "upgradeTo(address)" $Z --rpc-url $RPC

# ─── SHOT 3 · 0G can verify Intel hardware now ───────────────────────
# The second command prints plain English. That is the moment.
cast code $P256 --rpc-url $RPC | wc -c

cast call $ENTRY "verifyAndAttestOnChain(bytes)(bool,bytes)" 0x0400deadbeef \
  --rpc-url $RPC | tail -1 | xargs cast to-ascii

cast call $ENTRY "quoteVerifiers(uint16)(address)" 4 --rpc-url $RPC

# ─── SHOT 5 · the tests ──────────────────────────────────────────────
forge test --match-path contracts/test/Organism.t.sol

# ─── SHOT 6 · the empty biosphere ────────────────────────────────────
cast call $BIO "attestation()(address)"  --rpc-url $RPC
cast call $BIO "populationSize()(uint256)" --rpc-url $RPC
cast call $BIO "living()(uint256)"         --rpc-url $RPC
