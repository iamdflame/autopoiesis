#!/usr/bin/env bash
# Checks everything that can be checked before money is spent, then tells you exactly
# what to fund and by how much. Nothing here sends a transaction.
set -euo pipefail

NET="${NET:-testnet}"
case "$NET" in
  testnet) RPC="https://evmrpc-testnet.0g.ai"; CHAIN=16602; FAUCET="https://faucet.0g.ai/" ;;
  mainnet) RPC="https://evmrpc.0g.ai";         CHAIN=16661; FAUCET="" ;;
  *) echo "NET must be testnet or mainnet" >&2; exit 1 ;;
esac

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
ok(){   printf "  \033[32m✓\033[0m %s\n" "$*"; }
bad(){  printf "  \033[31m✗\033[0m %s\n" "$*"; }

echo; bold "Preflight — 0G $NET (chain $CHAIN)"; echo

command -v forge >/dev/null && ok "foundry $(forge --version | head -1 | awk '{print $3}')" || { bad "foundry not installed"; exit 1; }

live=$(cast chain-id --rpc-url "$RPC" 2>/dev/null || echo "")
[ "$live" = "$CHAIN" ] && ok "rpc reachable, chain id $live" || { bad "rpc unreachable or wrong chain (got '${live:-none}')"; exit 1; }

GAS=$(cast gas-price --rpc-url "$RPC")
ok "gas price $(echo "scale=2; $GAS/1000000000" | bc) gwei"

if [ -z "${PRIVATE_KEY:-}" ]; then
  bad "PRIVATE_KEY not set"
  echo
  echo "  Generate a fresh key for this deployment (do not reuse a personal wallet):"
  echo "    cast wallet new"
  echo "    export PRIVATE_KEY=0x<the private key it prints>"
  echo
  exit 1
fi
ADDR=$(cast wallet address --private-key "$PRIVATE_KEY")
ok "deployer $ADDR"

# ---- what this will cost -------------------------------------------------
DCAP_GAS=23730000
OURS_GAS=7200000
TOTAL_GAS=$((DCAP_GAS + OURS_GAS))
BUFFER_GAS=$((TOTAL_GAS * 130 / 100))          # 30% headroom for reverts and retries
NEED_WEI=$(echo "$BUFFER_GAS * $GAS" | bc)
NEED=$(cast from-wei "$NEED_WEI")

BAL_WEI=$(cast balance "$ADDR" --rpc-url "$RPC")
BAL=$(cast from-wei "$BAL_WEI")

echo
bold "Cost"
printf "  %-34s %12s gas\n" "Automata PCCS + DCAP stack" "$(printf "%'d" $DCAP_GAS)"
printf "  %-34s %12s gas\n" "Biosphere + Organism + Cambrian" "$(printf "%'d" $OURS_GAS)"
printf "  %-34s %12s gas\n" "with 30% headroom" "$(printf "%'d" $BUFFER_GAS)"
printf "  %-34s %12s 0G\n" "→ fund the deployer with" "$NEED"
echo
printf "  %-34s %12s 0G\n" "current balance" "$BAL"

if [ "$(echo "$BAL_WEI >= $NEED_WEI" | bc)" -eq 1 ]; then
  echo; ok "funded — ready to deploy"
  echo; echo "  next:  make dcap NET=$NET"
  exit 0
fi

SHORT=$(cast from-wei "$(echo "$NEED_WEI - $BAL_WEI" | bc)")
echo; bad "underfunded by $SHORT 0G"
echo
bold "How to fund"
echo "  1. Send 0G to:  $ADDR"
echo "     on:          0G $NET (chain $CHAIN)"
echo "     amount:      $NEED 0G  (or more)"
if [ -n "$FAUCET" ]; then
echo
echo "     Testnet is free — paste the address into $FAUCET"
echo "     If the faucet gives less than you need, ask in the buildathon"
echo "     Telegram support channel; they top builders up on request."
else
echo
echo "     Mainnet 0G can be bought on any exchange listing 0G and withdrawn"
echo "     to the address above. Make sure the withdrawal network is 0G Chain,"
echo "     not an ERC-20 wrapper on Ethereum — those are different assets and"
echo "     a wrapped token sent here is not recoverable by this tooling."
fi
echo
echo "  2. Re-run:  make preflight NET=$NET"
exit 1
