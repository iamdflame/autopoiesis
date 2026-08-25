# What the identity actually covers

`Organism.identity` is `keccak(MRTD ‖ RTMR0..3)`. Be precise about what those registers
measure, because overstating it would be the same failure as having no attestation at all.

| register | measures | set by |
|---|---|---|
| `MRTD` | the initial memory image of the trust domain — firmware, kernel, initrd, cmdline | the CVM image build, **not** the Dockerfile alone |
| `RTMR0-1` | virtual hardware configuration and boot chain | the hypervisor's CVM launch parameters |
| `RTMR2` | kernel / initrd measurements extended at boot | the guest boot sequence |
| `RTMR3` | application layer — the container image digest | `agent/Dockerfile` |

So the Dockerfile determines part of the identity, not all of it. Reproducing the
organism means reproducing the **whole CVM image**: the same guest firmware, the same
kernel, the same cmdline, and the same application layer. That is what a runner must
publish for anyone to independently confirm that the address they are paying is running
the code they read.

The practical consequence: **publish the full measurement set alongside the source.**
An organism whose image cannot be independently rebuilt to the same registers is asking
to be trusted rather than proving anything, which is precisely the thing this design
exists to avoid.

## Verifying an organism yourself

```bash
# 1. rebuild the image from source
docker buildx build --no-cache --output type=oci,dest=organism.tar agent/

# 2. derive RTMR3 from the image digest
./scripts/measure.sh organism.tar

# 3. compare against what the chain believes
cast call $ORGANISM "identity()(bytes32)" --rpc-url https://evmrpc.0g.ai
```

If those disagree, the thing running is not the thing you read. Do not fund it.
