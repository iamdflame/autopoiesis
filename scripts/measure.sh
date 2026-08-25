#!/usr/bin/env bash
# Derive the application-layer measurement (RTMR3) from a built OCI image.
#
# Honest scope: this covers the container layer only. MRTD and RTMR0-2 are set by the
# CVM image — guest firmware, kernel, cmdline — and come from whoever launches the
# confidential VM. See agent/MEASUREMENT.md. A full identity needs all of them.
set -euo pipefail
IMG="${1:?usage: scripts/measure.sh <image.tar>}"
DIGEST=$(sha256sum "$IMG" | awk '{print $1}')
echo "image sha256 : $DIGEST"
echo "RTMR3 (app)  : 0x$DIGEST"
echo
echo "This is one of five registers. Obtain MRTD and RTMR0-2 from the CVM launch"
echo "measurement of your TDX host, then:"
echo "  GENESIS_IDENTITY = keccak256(keccak256(MRTD) || keccak256(RTMR0..3))"
echo
echo "The organism's own first quote reports all five. The safe path is to boot it"
echo "once against a throwaway Biosphere, read the identity out of the rejection"
echo "error, and use that value for the real deployment."
