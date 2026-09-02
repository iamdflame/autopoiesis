#!/usr/bin/env bash
# Brings on-chain Intel DCAP attestation to 0G, stage by stage.
#
# 0G has none of this today. Each stage records its addresses to deployments/<net>.env
# so a failure is resumable rather than a restart. Run it repeatedly; completed stages
# are skipped.
#
# Stages:
#   0  P256 verifier      Intel signs with secp256r1; the EVM cannot verify it natively
#   1  PCCS helpers       X509 / CRL / TCB / enclave-identity parsers
#   2  PCCS DAOs          the on-chain store for Intel's collateral
#   3  DCAP router        reads collateral out of PCCS
#   4  DCAP entrypoint    verifyAndAttestOnChain lives here
#   5  V4 quote verifier  TDX, registered against the entrypoint
set -euo pipefail

NET="${NET:-mainnet}"
case "$NET" in
  mainnet) RPC="https://evmrpc.0g.ai";         CHAIN=16661 ;;
  testnet) RPC="https://evmrpc-testnet.0g.ai"; CHAIN=16602 ;;
  *) echo "NET must be mainnet or testnet" >&2; exit 1 ;;
esac
: "${PRIVATE_KEY:?PRIVATE_KEY not set}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/.vendor"; LOGS="$ROOT/deployments"; OUT="$LOGS/$NET.env"
mkdir -p "$LOGS"; touch "$OUT"; . "$OUT" 2>/dev/null || true
export RPC_URL="$RPC" PRIVATE_KEY
OWNER=$(cast wallet address --private-key "$PRIVATE_KEY")
export OWNER

stage(){ printf "\n\033[1m▸ stage %s — %s\033[0m\n" "$1" "$2"; }
done_(){ printf "  \033[32m✓\033[0m %s\n" "$*"; }

# ── 0 ─ P256 ────────────────────────────────────────────────────────────────
stage 0 "P256 verifier"
NET="$NET" "$ROOT/scripts/deploy-p256.sh"

# ── 1+2 ─ PCCS helpers and DAOs ─────────────────────────────────────────────
# Driven by our own script, not Automata's `make deploy-helpers` / `make deploy-dao`.
# Those wrap `forge script --broadcast --skip-simulation`, which against 0G's RPC hangs
# without ever broadcasting — verified twice at ten minutes, zero transactions — while
# `forge create` on the same endpoint returns in seconds. An earlier version of this
# orchestrator called the hanging path and never invoked the working one, so following
# the documented bootstrap could not have worked.
stage "1+2" "PCCS helpers, DAOs, and authorisation"
NET="$NET" PRIVATE_KEY="$PRIVATE_KEY" "$ROOT/scripts/deploy-pccs-daos.sh"

DEPLOY_JSON="$VENDOR/pccs/deployment/$CHAIN.json"
[ -f "$DEPLOY_JSON" ] && { echo; echo "  PCCS addresses:"; jq -r 'to_entries[] | "    \(.key) = \(.value)"' "$DEPLOY_JSON"; }

# ── 3-5 ─ DCAP ──────────────────────────────────────────────────────────────
cd "$VENDOR/dcap/evm"
if [ -z "${DCAP_ROUTER:-}" ]; then
  stage 3 "DCAP PCCS router"
  make deploy-router RPC_URL="$RPC" PRIVATE_KEY="$PRIVATE_KEY" 2>&1 \
    | tee "$LOGS/router-$NET.log" | grep -E "0x[0-9a-fA-F]{40}|Error" | tail -6
  echo "  record it:  scripts/record.sh $NET DCAP_ROUTER 0x..."
  exit 0
fi
if [ -z "${DCAP_VERIFIER:-}" ]; then
  stage 4 "DCAP attestation entrypoint"
  make deploy-attestation RPC_URL="$RPC" PRIVATE_KEY="$PRIVATE_KEY" 2>&1 \
    | tee "$LOGS/attestation-$NET.log" | grep -E "0x[0-9a-fA-F]{40}|Error" | tail -6
  echo "  record it:  scripts/record.sh $NET DCAP_VERIFIER 0x..."
  exit 0
fi
stage 5 "V4 quote verifier (TDX)"
make deploy-verifier RPC_URL="$RPC" PRIVATE_KEY="$PRIVATE_KEY" QUOTE_VERIFIER_VERSION=4 2>&1 | tail -6
make config-verifier RPC_URL="$RPC" PRIVATE_KEY="$PRIVATE_KEY" QUOTE_VERIFIER_VERSION=4 2>&1 | tail -6
done_ "DCAP live — DCAP_VERIFIER=$DCAP_VERIFIER"
echo "  next: make biosphere NET=$NET"
