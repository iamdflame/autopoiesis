#!/usr/bin/env bash
# Report what can honestly be computed about an organism's identity from this machine,
# and refuse to invent the rest.
#
# An earlier version of this script printed
#     RTMR3 (app) : 0x$(sha256sum image.tar)
# and BOOTSTRAP.md told you that was your GENESIS_IDENTITY. Both were wrong:
#
#   · RTMR3 is a 48-byte SHA-384 register built by successive TDG.MR.RTMR.EXTEND
#     operations — RTMR_new = SHA384(RTMR_old ‖ SHA384(event)) — not the SHA-256 of a
#     tarball, which is 32 bytes and a different hash entirely.
#   · Tar archives are not byte-stable across builds anyway.
#   · MRTD and RTMR0..2 come from the CVM launch measurement — guest firmware, kernel,
#     cmdline — and are not derivable from a container image at all.
#
# Funding an organism whose identity was guessed produces something alive, funded, and
# mute forever. There is a test named after that. So this script no longer guesses.
set -euo pipefail

IMG="${1:-}"
if [ -n "$IMG" ] && [ -f "$IMG" ]; then
  echo "image digest (informational only, NOT a register):"
  echo "  sha256 $(sha256sum "$IMG" | awk '{print $1}')"
  echo
fi

cat <<'NOTE'
How to obtain a real GENESIS_IDENTITY
─────────────────────────────────────
The identity is keccak(keccak(MRTD) ‖ keccak(RTMR0..3)). Every one of those registers
is reported by the hardware, not computed here. The only trustworthy source is a quote
produced by the enclave you actually intend to fund.

  1. Boot the agent on a TDX CVM with the organism address pointed at a throwaway
     Biosphere you do not care about.

  2. Let it call attestSession once. It will be rejected, and the revert carries the
     measurement the hardware actually reported:

         NotThisOrganism(bytes32 presented)

  3. That `presented` value is the identity. Use it verbatim.

  4. Independently confirm it before funding: have a second party rebuild the CVM image
     from this repository, boot it, and check their quote reports the same registers.
     If two independent builds disagree, the image is not reproducible and the organism
     cannot prove it is itself after a restart — do not fund it.

See agent/MEASUREMENT.md for which register each layer controls.
NOTE
