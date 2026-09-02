#!/usr/bin/env bash
# Deploy the PCCS DAOs — the on-chain store for Intel's attestation collateral.
#
# Uses `forge create` rather than Automata's `make deploy-dao`. Their Makefile drives
# `forge script --broadcast --skip-simulation`, which hangs indefinitely against 0G's
# RPC without ever broadcasting (verified: two 10-minute runs, zero transactions).
# `forge create` against the same endpoint returns in seconds, so we drive the
# dependency order ourselves.
set -euo pipefail

RPC=https://evmrpc.0g.ai
PCCS="$(cd "$(dirname "$0")/../.vendor/pccs" && pwd)"
OUT="$PCCS/deployment/16661.json"
: "${PRIVATE_KEY:?PRIVATE_KEY not set}"
OWNER=$(cast wallet address --private-key "$PRIVATE_KEY")

P256=0xc2b78104907F722DABAc4C69f826a522B2754De4
X509=$(jq -r .PCKHelper "$OUT")
CRL=$(jq -r .X509CRLHelper "$OUT")
ENCLAVE=$(jq -r .EnclaveIdentityHelper "$OUT")
FMSPC=$(jq -r .FmspcTcbHelper "$OUT")

cd "$PCCS"

# deploy <jsonKey> <path:Contract> [ctor args...]
deploy() {
  local key="$1" target="$2"; shift 2
  local existing
  existing=$(jq -r --arg k "$key" '.[$k] // empty' "$OUT")
  if [ -n "$existing" ]; then
    printf "  \033[32m✓\033[0m %-30s %s (already)\n" "$key" "$existing"
    echo "$existing"; return
  fi

  local args=()
  [ $# -gt 0 ] && args=(--constructor-args "$@")

  local out addr
  out=$(forge create "$target" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
        --broadcast "${args[@]}" 2>&1)
  addr=$(echo "$out" | awk '/Deployed to:/ {print $3}')
  if [ -z "$addr" ]; then
    echo "FAILED deploying $key:" >&2; echo "$out" | tail -12 >&2; exit 1
  fi
  jq --arg k "$key" --arg v "$addr" '.[$k]=$v' "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
  printf "  \033[32m✓\033[0m %-30s %s\n" "$key" "$addr" >&2
  echo "$addr"
}

echo "Deploying PCCS DAOs to 0G mainnet (owner $OWNER)"

STORAGE=$(deploy AutomataDaoStorage \
  src/automata_pccs/shared/AutomataDaoStorage.sol:AutomataDaoStorage "$OWNER")

PCS=$(deploy AutomataPcsDao \
  src/automata_pccs/AutomataPcsDao.sol:AutomataPcsDao "$STORAGE" "$P256" "$X509" "$CRL")

PCK=$(deploy AutomataPckDao \
  src/automata_pccs/AutomataPckDao.sol:AutomataPckDao "$STORAGE" "$P256" "$PCS" "$X509" "$CRL")

EID=$(deploy AutomataEnclaveIdentityDao \
  src/automata_pccs/AutomataEnclaveIdentityDao.sol:AutomataEnclaveIdentityDao \
  "$STORAGE" "$P256" "$PCS" "$ENCLAVE" "$X509" "$CRL")

TCB=$(deploy AutomataFmspcTcbDao \
  src/automata_pccs/AutomataFmspcTcbDao.sol:AutomataFmspcTcbDao \
  "$STORAGE" "$P256" "$PCS" "$FMSPC" "$X509" "$CRL")

echo
echo "Authorising the DAOs..."
# Two different permissions, and only one of them is the one that matters.
#
#   setCallerAuthorization -> _setAuthorizedReader
#   grantDao               -> _setAuthorizedWriter
#
# `attest()` and `readAttestation()` are both gated on the WRITER set (`onlyDao`), so a
# deployment that only calls setCallerAuthorization looks configured and cannot accept a
# single byte of Intel collateral. That is exactly what shipped here first, and it was
# invisible because the failures were sent to /dev/null and reported as a warning.
#
# Errors are no longer swallowed: a failed authorisation aborts.
for d in "$PCS" "$PCK" "$EID" "$TCB"; do
  cast send "$STORAGE" "grantDao(address)" "$d" \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" >/dev/null
  printf "  \033[32m✓\033[0m writer %s\n" "$d"

  cast send "$STORAGE" "setCallerAuthorization(address,bool)" "$d" true \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" >/dev/null
  printf "  \033[32m✓\033[0m reader %s\n" "$d"
done

echo
echo "PCCS live:"
jq -r 'to_entries[] | "  \(.key) = \(.value)"' "$OUT"
