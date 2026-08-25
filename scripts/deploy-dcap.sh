#!/usr/bin/env bash
# Brings on-chain Intel DCAP attestation to 0G.
#
# This deploys third-party infrastructure (Automata's PCCS + DCAP contracts) that 0G
# does not have yet. Once it exists, anyone on 0G can verify SGX and TDX quotes on
# chain — we happen to be its first user.
#
# Everything here is idempotent-ish: addresses are recorded to deployments/<net>.env
# as they are produced, so a failed run can be resumed rather than restarted.
set -euo pipefail

NET="${NET:-testnet}"
case "$NET" in
  testnet) RPC="https://evmrpc-testnet.0g.ai"; CHAIN=16602 ;;
  mainnet) RPC="https://evmrpc.0g.ai";         CHAIN=16661 ;;
  *) echo "NET must be testnet or mainnet" >&2; exit 1 ;;
esac
: "${PRIVATE_KEY:?run 'make preflight NET=$NET' first}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/.vendor"
OUT="$ROOT/deployments/$NET.env"
mkdir -p "$VENDOR" "$ROOT/deployments"
touch "$OUT"; . "$OUT" 2>/dev/null || true

step(){ printf "\n\033[1m▸ %s\033[0m\n" "$*"; }
save(){ grep -v "^$1=" "$OUT" > "$OUT.tmp" 2>/dev/null || true; mv -f "$OUT.tmp" "$OUT" 2>/dev/null || true
        echo "$1=$2" >> "$OUT"; printf "  \033[32m✓\033[0m %s=%s\n" "$1" "$2"; }

clone(){ # repo dir
  if [ ! -d "$VENDOR/$2" ]; then
    step "fetching $2"
    git clone --depth 1 "$1" "$VENDOR/$2"
    ( cd "$VENDOR/$2" && forge install 2>/dev/null || true )
  fi
}

# ---------------------------------------------------------------------------
step "0G $NET — chain $CHAIN, deployer $(cast wallet address --private-key "$PRIVATE_KEY")"

clone https://github.com/automata-network/automata-on-chain-pccs pccs
clone https://github.com/automata-network/automata-dcap-attestation dcap

# --- 1. on-chain PCCS: where Intel collateral lives ------------------------
if [ -z "${PCCS_STORAGE:-}" ]; then
  step "deploying on-chain PCCS (collateral store + DAOs)"
  ( cd "$VENDOR/pccs" && PRIVATE_KEY="$PRIVATE_KEY" RPC_URL="$RPC" \
      forge script script/DeployAll.s.sol --rpc-url "$RPC" --broadcast --slow -vv \
      2>&1 | tee "$ROOT/deployments/pccs-$NET.log" )
  echo
  echo "  Read the addresses out of deployments/pccs-$NET.log and record them:"
  echo "    scripts/record.sh $NET PCCS_STORAGE 0x..."
  echo "    scripts/record.sh $NET PCS_DAO 0x...  (and the other DAOs)"
  echo
  echo "  Then re-run: make dcap NET=$NET"
  exit 0
fi

# --- 2. DCAP router + entrypoint + verifiers -------------------------------
if [ -z "${DCAP_ROUTER:-}" ]; then
  step "deploying PCCS router"
  ( cd "$VENDOR/dcap/evm" && PRIVATE_KEY="$PRIVATE_KEY" \
      make deploy-router RPC_URL="$RPC" 2>&1 | tee "$ROOT/deployments/router-$NET.log" )
  echo "  record with: scripts/record.sh $NET DCAP_ROUTER 0x..."
  exit 0
fi

if [ -z "${DCAP_VERIFIER:-}" ]; then
  step "deploying attestation entrypoint"
  ( cd "$VENDOR/dcap/evm" && PRIVATE_KEY="$PRIVATE_KEY" \
      make deploy-attestation RPC_URL="$RPC" 2>&1 | tee "$ROOT/deployments/attestation-$NET.log" )
  echo "  record with: scripts/record.sh $NET DCAP_VERIFIER 0x..."
  exit 0
fi

step "deploying V4 quote verifier (TDX) and registering it"
( cd "$VENDOR/dcap/evm" && PRIVATE_KEY="$PRIVATE_KEY" \
    make deploy-verifier RPC_URL="$RPC" QUOTE_VERIFIER_VERSION=4 && \
    make config-verifier RPC_URL="$RPC" QUOTE_VERIFIER_VERSION=4 )

step "seeding Intel collateral into on-chain PCCS"
cat <<'NOTE'
  This is the step that most often needs a human. The PCCS must hold Intel's root
  CA, the TCBInfo for the provider's FMSPC, and the QEIdentity, or every quote
  verifies to false and the organism can never draw a breath.

  Automata's upsert scripts pull these from Intel's PCS API. The FMSPC you need is
  the one belonging to the actual 0G Compute provider whose CVM will run the
  organism — you cannot know it until you have a quote from that provider.

  So the order is: get one quote from the 0G provider, read its FMSPC, seed that
  collateral, then verify. See:
    .vendor/pccs/README.md   (upsert-* targets)
NOTE

step "done — DCAP_VERIFIER=${DCAP_VERIFIER}"
echo "  next:  make biosphere NET=$NET"
