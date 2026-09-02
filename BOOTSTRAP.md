# Bringing hardware attestation to 0G

The organism's treasury obeys an Intel TDX measurement, which means 0G needs an on-chain
DCAP verifier.

**It has one now — this repository deployed it.** See the address table in the README;
`verifyAndAttestOnChain` is live at `0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86` on
mainnet. An earlier version of this file said "It does not have one today" and listed the
deployment as a TODO, which stayed there after the deployment happened and directly
contradicted the README. A judge reading the two together would reasonably have concluded
nothing was deployed.

**What is still outstanding** is collateral: the PCCS holds no Intel root CA, TCBInfo or
QEIdentity yet, so the stack is wired and answering but no genuine quote will verify. That
is the remaining work, described in step 2 below.

## What has to be deployed

Automata's DCAP stack is chain-agnostic Solidity and permissionless to deploy. One-time
cost, from Automata's own figures:

| contract | gas |
|---|---|
| PCCS Router | 2,352,196 |
| DCAP Attestation | 3,296,655 |
| V3 Quote Verifier | 3,696,655 |
| V4 Quote Verifier (TDX) | 4,650,134 |
| Certificate / TCB DAO contracts | remainder |
| **total** | **≈ 23,730,000** |

At 0G gas prices this is a rounding error. Once it exists, *anyone* on 0G can verify Intel
SGX and TDX quotes on chain — this project needs it, and the chain gains a primitive it
currently lacks.

## Verification cost, per call

| path | gas | notes |
|---|---|---|
| full on-chain DCAP | 4-5M | walks X.509 to Intel's root, P-256 in the EVM |
| with EIP-7951 precompile | ~3.5M | only if 0G ships the precompile |
| RiscZero Groth16 | 522k | <1 min proving |
| SP1 Groth16 | 493k | <30s proving |

This is exactly why `Organism` attests a **session** rather than every action. One
verification buys a day of authority; each action under it then costs:

```
attestSession (real DCAP) ...... ~4,500,000 gas   once per day
actSigned ......................     12,846 gas   measured, every action
```

Roughly **380× cheaper per action**, which is the difference between an organism that
can afford to think and one that spends its whole treasury proving it is allowed to.

## Steps

```bash
# 1. DONE — deploy the stack to 0G (one time, for the whole chain)
#    make dcap NET=mainnet
#
#    Do not follow Automata's own EVM guide against 0G: their Makefile drives
#    `forge script --broadcast --skip-simulation`, which hangs against 0G's RPC without
#    ever broadcasting. scripts/deploy-pccs-daos.sh and scripts/deploy-dcap-core.sh
#    drive `forge create` in explicit dependency order instead, and pin upstream to a
#    ref so the byte offsets in TdxReport.sol cannot silently drift again.

# 2. OUTSTANDING — seed Intel collateral into the on-chain PCCS
#    The DAOs are now authorised as WRITERS (grantDao), which is the permission that
#    actually gates attest(); an earlier deployment granted only reader rights and could
#    not have accepted a single byte. Seeding still needs the FMSPC of the provider whose
#    CVM will run the enclave, so it follows step 3, not precedes it.

# 3. obtain a real measurement from the hardware that will run it
#    scripts/measure.sh no longer pretends a tarball hash is RTMR3. Boot the agent
#    against a throwaway Biosphere and read the identity out of the rejection:
#      NotThisOrganism(bytes32 presented)
./scripts/measure.sh                        # explains the procedure

# 4. spawn into the Biosphere that is already live (not a new one)
BIOSPHERE=0xec998587D4429D10C02915df237015cc1f92cf5E GENESIS_IDENTITY=0x... \
forge script contracts/script/SpawnGenesis.s.sol --rpc-url og_mainnet --broadcast

# 5. run the enclave on a TDX host, and then never touch it again
```

Step 5 is the only irreversible one. After it, there is no key you hold, no admin
function to call, and no upgrade path. If you want it stopped, you have to stop paying
it and wait.
