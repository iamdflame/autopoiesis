#!/usr/bin/env bash
# Deploy the DCAP verification core to 0G: TcbEval DAO, PCCS router, attestation
# entrypoint, and the V4 (TDX) quote verifier — then wire them together.
#
# After this, `verifyAndAttestOnChain(bytes)` exists on 0G and anyone can verify an
# Intel TDX quote on chain. That is the primitive Organism.act() depends on, and the
# thing 0G did not have before today.
set -euo pipefail

RPC=https://evmrpc.0g.ai
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PCCS="$ROOT/.vendor/pccs"
DCAP="$ROOT/.vendor/dcap/evm"
J="$PCCS/deployment/16661.json"
ENV="$ROOT/deployments/mainnet.env"
: "${PRIVATE_KEY:?PRIVATE_KEY not set}"
OWNER=$(cast wallet address --private-key "$PRIVATE_KEY")

P256=0xc2b78104907F722DABAc4C69f826a522B2754De4
STORAGE=$(jq -r .AutomataDaoStorage "$J")
PCS=$(jq -r .AutomataPcsDao "$J")
PCK=$(jq -r .AutomataPckDao "$J")
X509=$(jq -r .PCKHelper "$J")
CRL=$(jq -r .X509CRLHelper "$J")
TCBH=$(jq -r .FmspcTcbHelper "$J")
EVALH=$(jq -r .TcbEvalHelper "$J")

save(){ grep -v "^$1=" "$ENV" > "$ENV.tmp" 2>/dev/null || true; mv -f "$ENV.tmp" "$ENV" 2>/dev/null || true
        echo "$1=$2" >> "$ENV"; }

mk(){ # mk <label> <dir> <target> [ctor args...]
  local label="$1" dir="$2" target="$3"; shift 3
  local args=(); [ $# -gt 0 ] && args=(--constructor-args "$@")
  local out addr
  out=$(cd "$dir" && forge create "$target" --rpc-url "$RPC" \
        --private-key "$PRIVATE_KEY" --broadcast "${args[@]}" 2>&1)
  addr=$(echo "$out" | awk '/Deployed to:/ {print $3}')
  [ -n "$addr" ] || { echo "FAILED $label:" >&2; echo "$out" | tail -12 >&2; exit 1; }
  printf "  \033[32m✓\033[0m %-26s %s\n" "$label" "$addr" >&2
  echo "$addr"
}

echo "Deploying DCAP core to 0G mainnet"

# The newer Automata DAOs resolve their PCS and CRL dependencies indirectly, through a
# config contract with a timelocked upgrade path — passing raw addresses reverts.
CFG=$(jq -r '.PccsDependencyConfig // empty' "$J")
if [ -z "$CFG" ]; then
  CFG=$(mk PccsDependencyConfig "$PCCS" \
    src/automata_pccs/shared/PccsDependencyConfig.sol:PccsDependencyConfig "$OWNER")
  jq --arg v "$CFG" '.PccsDependencyConfig=$v' "$J" > "$J.t" && mv "$J.t" "$J"
  cast send "$CFG" "initialize(address,address)" "$PCS" "$CRL" \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" >/dev/null \
    && echo "  ✓ dependency config initialised (pcs + crl)"
fi

EVALDAO=$(mk AutomataTcbEvalDao "$PCCS" \
  src/automata_pccs/AutomataTcbEvalDao.sol:AutomataTcbEvalDao \
  "$STORAGE" "$P256" "$CFG" "$EVALH" "$X509" "$OWNER")
jq --arg v "$EVALDAO" '.AutomataTcbEvalDao=$v' "$J" > "$J.t" && mv "$J.t" "$J"

cast send "$STORAGE" "setCallerAuthorization(address,bool)" "$EVALDAO" true \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" >/dev/null 2>&1 \
  && echo "  ✓ TcbEvalDao authorised on storage"

ROUTER=$(mk PCCSRouter "$DCAP" contracts/PCCSRouter.sol:PCCSRouter \
  "$OWNER" "$EVALDAO" "$PCS" "$PCK" "$X509" "$CRL" "$TCBH")
save DCAP_ROUTER "$ROUTER"

ENTRY=$(mk AutomataDcapAttestation "$DCAP" \
  contracts/AutomataDcapAttestationFee.sol:AutomataDcapAttestationFee "$OWNER")
save DCAP_VERIFIER "$ENTRY"

V4=$(mk V4QuoteVerifier "$DCAP" contracts/verifiers/V4QuoteVerifier.sol:V4QuoteVerifier \
  "$P256" "$ROUTER")
save V4_VERIFIER "$V4"

echo
echo "Wiring:"
cast send "$ENTRY" "setQuoteVerifier(address)" "$V4" \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" >/dev/null \
  && echo "  ✓ V4 verifier registered with the entrypoint"
cast send "$ROUTER" "setAuthorized(address,bool)" "$V4" true \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" >/dev/null \
  && echo "  ✓ V4 verifier authorised to read the router"
cast send "$ROUTER" "setAuthorized(address,bool)" "$ENTRY" true \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" >/dev/null \
  && echo "  ✓ entrypoint authorised to read the router"

echo
echo "DCAP attestation is live on 0G:"
echo "  entrypoint  $ENTRY"
echo "  router      $ROUTER"
echo "  V4 verifier $V4"
echo "  explorer    https://chainscan.0g.ai/address/$ENTRY"
