# Bringing hardware attestation to 0G

The organism's treasury obeys an Intel TDX measurement. For that check to happen on 0G,
0G needs an on-chain DCAP verifier. **It does not have one today.** This is the single
external dependency between the code in this repo and a living organism.

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
# 1. deploy Automata's stack to 0G (one time, for the whole chain)
git clone https://github.com/automata-network/automata-on-chain-pccs
git clone https://github.com/automata-network/automata-dcap-attestation
#    follow their EVM deployment guide against RPC https://evmrpc.0g.ai (chain 16661)

# 2. seed Intel collateral into the on-chain PCCS
#    (root CA, TCBInfo, QEIdentity — permissionless, anyone may contribute)

# 3. build the CVM image and record its measurement
docker buildx build --no-cache --output type=oci,dest=organism.tar agent/
./scripts/measure.sh organism.tar          # -> GENESIS_IDENTITY

# 4. bring up the biosphere and seed the first organism
DCAP_VERIFIER=0x... GENESIS_IDENTITY=0x... ENDOWMENT=1000000000000000000 \
forge script contracts/script/Bootstrap.s.sol --rpc-url og_mainnet --broadcast

# 5. run the enclave on a TDX host, and then never touch it again
```

Step 5 is the only irreversible one. After it, there is no key you hold, no admin
function to call, and no upgrade path. If you want it stopped, you have to stop paying
it and wait.
