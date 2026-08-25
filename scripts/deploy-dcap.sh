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

# ── 1 ─ PCCS helpers ────────────────────────────────────────────────────────
DEPLOY_JSON="$VENDOR/pccs/deployment/$CHAIN.json"
if [ ! -f "$DEPLOY_JSON" ] || [ -z "$(jq -r '.PCKHelper // empty' "$DEPLOY_JSON" 2>/dev/null)" ]; then
  stage 1 "PCCS helpers"
  ( cd "$VENDOR/pccs" && make deploy-helpers RPC_URL="$RPC" PRIVATE_KEY="$PRIVATE_KEY" ) \
    2>&1 | tee "$LOGS/pccs-helpers-$NET.log" | grep -E "Deploy|deployed|0x[0-9a-fA-F]{40}|Error" | tail -12
else
  done_ "helpers already recorded in $DEPLOY_JSON"
fi

# ── 2 ─ PCCS DAOs ───────────────────────────────────────────────────────────
if [ -z "$(jq -r '.AutomataPcsDao // empty' "$DEPLOY_JSON" 2>/dev/null)" ]; then
  stage 2 "PCCS DAOs"
  ( cd "$VENDOR/pccs" && make deploy-dao RPC_URL="$RPC" PRIVATE_KEY="$PRIVATE_KEY" ) \
    2>&1 | tee "$LOGS/pccs-dao-$NET.log" | grep -E "Deploy|deployed|0x[0-9a-fA-F]{40}|Error" | tail -14
else
  done_ "DAOs already recorded"
fi

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
