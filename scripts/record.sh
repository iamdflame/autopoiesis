#!/usr/bin/env bash
# scripts/record.sh <net> <KEY> <value> — pin a deployed address into deployments/<net>.env
set -euo pipefail
NET="$1"; KEY="$2"; VAL="$3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; OUT="$ROOT/deployments/$NET.env"
mkdir -p "$ROOT/deployments"; touch "$OUT"
grep -v "^$KEY=" "$OUT" > "$OUT.tmp" 2>/dev/null || true; mv -f "$OUT.tmp" "$OUT"
echo "$KEY=$VAL" >> "$OUT"
echo "recorded $KEY=$VAL in deployments/$NET.env"
