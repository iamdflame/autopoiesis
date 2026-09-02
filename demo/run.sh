#!/usr/bin/env bash
# Plays one shot of the demo, hands-free.
#
#   ./demo/run.sh 1     the failed theft
#   ./demo/run.sh 3     0G can verify Intel hardware now
#   ./demo/run.sh 5     the tests
#   ./demo/run.sh 6     the empty biosphere
#
# Every address is a literal. Nothing to source, nothing to export, no $VARS that
# silently expand to empty and produce a confusing error mid-take. Start recording,
# run one of these, stop recording. Do not type anything on camera.
set -uo pipefail

RPC=https://evmrpc.0g.ai
BIO=0xec998587D4429D10C02915df237015cc1f92cf5E
ENTRY=0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86
P256=0xc2b78104907F722DABAc4C69f826a522B2754De4
ZERO=0x0000000000000000000000000000000000000000

SPEED="${SPEED:-1}"          # SPEED=2 to rehearse at double time
pause(){ sleep "$(python3 -c "print($1/$SPEED)")"; }

# Type a command out like a person, then run it.
type_run(){
  printf '\033[1;32m$\033[0m '
  local c="$1"
  for ((i=0; i<${#c}; i++)); do printf '%s' "${c:$i:1}"; sleep "$(python3 -c "print(0.018/$SPEED)")"; done
  printf '\n'
  pause 0.35
  eval "$c"
  pause 1.1
}

banner(){ printf '\033[2J\033[H\033[1;38;5;208m%s\033[0m\n\n' "$1"; pause 0.9; }

case "${1:-}" in

1) banner "// I hold the deployer's key. Watch me fail to control it."
   type_run "cast call $BIO \"owner()(address)\" --rpc-url $RPC"
   type_run "cast call $BIO \"admin()(address)\" --rpc-url $RPC"
   type_run "cast call $BIO \"pause()\" --rpc-url $RPC"
   type_run "cast call $BIO \"upgradeTo(address)\" $ZERO --rpc-url $RPC"
   printf '\n\033[1;38;5;208m// not disabled. not renounced. never written.\033[0m\n'
   pause 3
   ;;

3) banner "// 0G had no way to verify an Intel signature. Now it does."
   printf '\033[38;5;244m// secp256r1 verifier, at its canonical CREATE2 address\033[0m\n'
   type_run "cast code $P256 --rpc-url $RPC | wc -c"
   printf '\n\033[38;5;244m// hand the entrypoint a malformed quote\033[0m\n'
   type_run "cast call $ENTRY \"verifyAndAttestOnChain(bytes)(bool,bytes)\" 0x0400deadbeef --rpc-url $RPC | tail -1 | xargs cast to-ascii"
   printf '\n\033[1;38;5;208m// that is Intel'\''s own TDX parser, answering from a 0G contract.\033[0m\n'
   pause 3.5
   type_run "cast call $ENTRY \"quoteVerifiers(uint16)(address)\" 4 --rpc-url $RPC"
   pause 2
   ;;

5) banner "// 37 tests, including the ones that would embarrass us."
   type_run "forge test"
   pause 3
   ;;

6) banner "// the biosphere is bound, and empty."
   type_run "cast call $BIO \"attestation()(address)\" --rpc-url $RPC"
   type_run "cast call $BIO \"quoteVerifier()(address)\" --rpc-url $RPC"
   type_run "cast call $BIO \"populationSize()(uint256)\" --rpc-url $RPC"
   printf '\n\033[1;38;5;208m// nothing is alive yet. it stays empty until the silicon speaks.\033[0m\n'
   pause 3.5
   ;;

*) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
