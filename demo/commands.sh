#!/usr/bin/env bash
# Paste these ONE BLOCK AT A TIME while recording. Every one is pre-verified
# against 0G mainnet. Do not improvise on camera.

# Prefer ./demo/run.sh — it plays each shot hands-free with no variables at all.
# These literals are here for reference and for pasting one line at a time.
#
#   RPC    https://evmrpc.0g.ai
#   BIO    0xec998587D4429D10C02915df237015cc1f92cf5E
#   ENTRY  0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86
#   P256   0xc2b78104907F722DABAc4C69f826a522B2754De4

# ─── SHOT 1 · the failed theft ───────────────────────────────────────
# Type these one at a time. Let each revert sit on screen for a beat.
cast call 0xec998587D4429D10C02915df237015cc1f92cf5E "owner()(address)"      --rpc-url https://evmrpc.0g.ai
cast call 0xec998587D4429D10C02915df237015cc1f92cf5E "admin()(address)"      --rpc-url https://evmrpc.0g.ai
cast call 0xec998587D4429D10C02915df237015cc1f92cf5E "pause()"               --rpc-url https://evmrpc.0g.ai
cast call 0xec998587D4429D10C02915df237015cc1f92cf5E "upgradeTo(address)" 0x0000000000000000000000000000000000000000 --rpc-url https://evmrpc.0g.ai

# ─── SHOT 3 · 0G can verify Intel hardware now ───────────────────────
# The second command prints plain English. That is the moment.
cast code 0xc2b78104907F722DABAc4C69f826a522B2754De4 --rpc-url https://evmrpc.0g.ai | wc -c

cast call 0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86 "verifyAndAttestOnChain(bytes)(bool,bytes)" 0x0400deadbeef --rpc-url https://evmrpc.0g.ai | tail -1 | xargs cast to-ascii

cast call 0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86 "quoteVerifiers(uint16)(address)" 4 --rpc-url https://evmrpc.0g.ai

# ─── SHOT 5 · the tests ──────────────────────────────────────────────
forge test

# ─── SHOT 6 · the empty biosphere ────────────────────────────────────
cast call 0xec998587D4429D10C02915df237015cc1f92cf5E "attestation()(address)"  --rpc-url https://evmrpc.0g.ai
cast call 0xec998587D4429D10C02915df237015cc1f92cf5E "populationSize()(uint256)" --rpc-url https://evmrpc.0g.ai
cast call 0xec998587D4429D10C02915df237015cc1f92cf5E "living()(uint256)"         --rpc-url https://evmrpc.0g.ai
