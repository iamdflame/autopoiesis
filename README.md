<h1>Autopoiesis</h1>

**A machine that owns itself.** It earns by answering questions, buys its own GPU time
out of its own treasury, retrains itself on what it has lived through, and starves if it
stops being worth paying.

Live on 0G mainnet, where it also deploys the first on-chain Intel TDX attestation stack.

<sub>[0G Bridge Buildathon](https://app.akindo.io/wave-hacks/Z4MlX4vreI72ol6pd) · Wave 3 · chain `16661` · [autopoiesis-0g.vercel.app](https://autopoiesis-0g.vercel.app)</sub>

---

## Read this first

This repository was independently audited after its first deployment, and the audit found
real, fatal bugs — including one that made the organism unable to act at all. They are
fixed, each with a regression test named after the failure. What follows describes the
system as it is now, and [What the audit found](#what-the-audit-found) lists exactly what
was wrong before.

Two things are true at once, and both matter:

- **What is live and working:** a complete Intel TDX attestation stack on 0G that did not
  exist before, and the Biosphere that binds to it.
- **What is not:** no organism has ever run. The Biosphere is empty. The agent has never
  executed against real hardware.

---

## Live on 0G mainnet

| | address |
|---|---|
| **Biosphere** — population, inheritance, selection | [`0xec998587D4429D10C02915df237015cc1f92cf5E`](https://chainscan.0g.ai/address/0xec998587D4429D10C02915df237015cc1f92cf5E) |
| **DCAP entrypoint** — `verifyAndAttestOnChain` | [`0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86`](https://chainscan.0g.ai/address/0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86) |
| **V4 quote verifier** — Intel TDX | [`0xabbd2E13d5eda2D75D1599A7539a3083dfaba715`](https://chainscan.0g.ai/address/0xabbd2E13d5eda2D75D1599A7539a3083dfaba715) |
| **PCCS router** | [`0xb66b1d67d156Fb7FC21B6cb9Be573C118C37e4f4`](https://chainscan.0g.ai/address/0xb66b1d67d156Fb7FC21B6cb9Be573C118C37e4f4) |
| **P256 verifier** — secp256r1 | [`0xc2b78104907F722DABAc4C69f826a522B2754De4`](https://chainscan.0g.ai/address/0xc2b78104907F722DABAc4C69f826a522B2754De4) |

**Seventeen deployments, of which one is ours.** The Biosphere is the only contract in
this repository that is live; the other sixteen are Automata's PCCS and DCAP stack plus
Daimo's P256 verifier, deployed by us because 0G lacked them. `Organism.sol` is **not
deployed** — spawning one requires a measurement from real hardware, and we will not
guess it. Full list in [`deployments/mainnet.env`](deployments/mainnet.env).

---

## What 0G could not do before this repository

**0G could not verify an Intel TDX attestation.** Intel signs DCAP quotes with secp256r1;
the EVM has no native support, and 0G shipped with neither the RIP-7212 precompile at
`0x100` nor any deployed P256 verifier. Automata's own tooling refuses to start against
such a chain — it reverts with `Failed to locate a verifier.`

So we brought the stack up: a P256 verifier at its canonical CREATE2 address, the PCCS
collateral store and its DAOs, the router, the entrypoint, and the V4 TDX verifier.

Any project on 0G can now call `verifyAndAttestOnChain(bytes)`. That is infrastructure
the ecosystem keeps whether or not this project wins anything, and it is the part of this
submission we are most confident in.

**What is still missing:** the PCCS holds no Intel collateral yet. Seeding it requires the
FMSPC of the specific provider whose CVM will run the enclave, which we cannot know
without a quote from that provider. Until it is seeded, the stack is correctly wired and
answering, but **no real quote will verify**. That is the honest boundary of the claim.

---

## Verify this yourself

```bash
RPC=https://evmrpc.0g.ai
ENTRY=0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86
BIO=0xec998587D4429D10C02915df237015cc1f92cf5E

# 1. The V4 verifier is registered for quote version 4.
cast call $ENTRY "quoteVerifiers(uint16)(address)" 4 --rpc-url $RPC
# → 0xabbd2E13d5eda2D75D1599A7539a3083dfaba715

# 2. The entrypoint routes into the TDX parser, which runs and rejects.
cast call $ENTRY "verifyAndAttestOnChain(bytes)(bool,bytes)" 0x0400deadbeef \
  --rpc-url $RPC | tail -1 | xargs cast to-ascii
# → "Quote length is less than Header length"
#
#   Read this narrowly. It proves the entrypoint is wired to a verifier that executes.
#   It does NOT prove a genuine quote would verify — six bytes fail a length check and
#   return early, before signature checking, collateral lookup, or the event emit.
#   An earlier revision of this README offered exactly this as proof of life, and it was
#   the one branch in the contract that could not expose the bug described in §1 below.

# 3. The Biosphere is bound to that entrypoint and pins that verifier.
cast call $BIO "attestation()(address)"   --rpc-url $RPC
cast call $BIO "quoteVerifier()(address)" --rpc-url $RPC

# 4. The entrypoint has an owner, and it is the deployer. This is a real limitation,
#    not a rhetorical one — see "Where the trust actually sits".
cast call $ENTRY "owner()(address)" --rpc-url $RPC
# → 0xf910fC2fD395128A894e9754bE56479F05b54121

# 5. The claims about the contracts are tests, not prose.
forge test
```

---

## How it works

### Identity is a measurement, not a secret

An Intel TDX enclave measures the exact code image it boots (`MRTD`) and everything
extended into the trust domain afterwards (`RTMR0..3`):

```
identity = keccak256( keccak256(MRTD) ‖ keccak256(RTMR0..3) )
```

[`Organism.sol`](contracts/src/Organism.sol) is born knowing one such number and obeys
nothing else. There is no `onlyOwner`, no admin, no pause, no proxy, no upgrade path
anywhere in that file. Change one byte of the enclave code and the measurement moves;
the treasury has never heard of the result.

### Where the trust actually sits

**"No owner in `Organism.sol`" is not the same as "no owner anywhere", and the difference
was a genuine hole.**

Automata's DCAP entrypoint is `Ownable`, and its owner can call `setQuoteVerifier`. An
owner who installed a verifier returning `(true, <any body>)` could mint a breath for any
identity and drain every organism behind it. Binding immutably to a mutable, owned
contract provides no security, and this repository originally presented that binding as a
guarantee.

The mitigation now in the code: **each organism pins the verifier address it was born
trusting** and refuses to proceed if the entrypoint points anywhere else. Swapping the
verifier stops the population instead of subverting it — a liveness failure rather than a
theft. `test_swappingTheVerifierStopsTheOrganismRatherThanDrainingIt` covers it.

What remains true, stated plainly: **the deployer can halt every organism** by pointing
the entrypoint elsewhere. That is a censorship power, not a spending power. Removing it
means renouncing ownership of the entrypoint — which we have deliberately *not* done,
because the PCCS still needs its collateral seeded and renouncing now would brick the
attestation stack for the whole chain, permanently, for everyone.

### Breathing — the engineering trade

Verifying a DCAP quote costs 4–5M gas. An organism paying that per heartbeat would spend
its life buying permission to exist. So it proves the silicon once, mints an ephemeral
keypair **inside the enclave**, commits the public half into `report_data`, and acts on a
signature until the breath expires.

```
attestSession  (full DCAP quote) ...... ~4,500,000 gas    once per session
actSigned      (Evolve, warm slots) ...     12,846 gas    measured
```

That 12,846 figure is measured on `Evolve`, the cheapest action, averaged over five
iterations with warm storage. A `Spend` carries a value transfer and metering writes and
costs more; the test's own upper bound is 120,000 gas. Treat 12,846 as the floor, not the
typical case.

The trade is real: for the life of a breath there **is** a key. Three things bound it —
the key is minted fresh on every session and never touches disk, `MAX_SESSION` caps its
life at ~12 hours, and each breath carries its own spend allowance fixed at mint time, so
a single compromised session cannot exceed 25% of the treasury even by straddling an
epoch boundary. An enclave that detects compromise can also call `revokeBreath` and end
its own session early.

### Metabolism, mortality, selection

It changes its mind but never its nature: `Evolve` rewrites `soma`; `identity` is
`immutable`. Silence past `DORMANCY` (604,800 blocks — ~7 days at 0G's measured ~0.96s
blocks) or an empty treasury is death, permanent. The estate passes to the nearest living
ancestor, and a child inherits its parent's weights.

[`Biosphere.sol`](contracts/src/Biosphere.sol) holds the population. There is no
committee, no scoring function, no vote: an organism lives if strangers pay it and dies
if they don't.

**Reproduction is not implemented.** A child's identity must be the measurement of a real,
buildable enclave image, and that cannot be derived from the parent's weights. The
previous implementation computed `soma XOR timestamp` and would have destroyed the
endowment of every child it created. It is removed rather than left wrong.

---

## What the audit found

Every one of these shipped, passed CI, and was wrong. Each now has a test in
[`contracts/test/Regressions.t.sol`](contracts/test/Regressions.t.sol).

| # | finding | status |
|---|---|---|
| 1 | `IDcapAttestation.verifyAndAttestOnChain` was declared `view`. The real function is `payable` and emits, so solc emitted STATICCALL and **every call against the real verifier would revert** — the organism could never act. | fixed |
| 2 | `TdxReport.HEADER` was 13; upstream changed the output header to 11 bytes. Broke the length check, made identity non-deterministic, and misaligned the action binding. | fixed, upstream now pinned |
| 3 | The mock encoded bytes at the same offsets the parser read them from, so mock and parser agreed while both were wrong. | mock now encodes structurally, field by field, with no offset constant |
| 4 | The trust root one hop away is owned and swappable. | verifier pinned per organism; residual power documented above |
| 5 | PCCS deployment called `setCallerAuthorization` (reader) and never `grantDao` (writer), so collateral could never be written. Errors were sent to `/dev/null`. | fixed and applied on mainnet; script no longer swallows failures |
| 6 | Agent SDK versions (`^0.3.0`, `^0.4.0`) matched no published release; `npm install` failed with ETARGET. | pinned to 1.2.11 / 0.9.0; lockfile committed |
| 7 | The Docker base digest was fabricated; `package-lock.json`, `tsconfig.json` and `main.ts` did not exist; there was no entry point. | all present; typechecks and builds |
| 8 | The breath key was created once per process and re-attested forever, defeating session bounds. | rotated on every breath; `revokeBreath` added |
| 9 | The advertised "≤25% of treasury" was ~44% across an epoch boundary. | per-breath allowance; regression test |
| 10 | Block constants assumed ~12s blocks. 0G's are ~0.96s, so `DORMANCY` was 13 hours, not a week — on the condition that kills permanently. | recalibrated |
| 11 | `seedFromCommons` let anyone drain the commons with a self-chosen identity. | removed |
| 12 | Children inherited no weights; `soma` was a hash of their own id, addressing nothing. | children inherit the parent's soma |
| 13 | `measure.sh` printed a SHA-256 of a tarball and called it RTMR3, a 48-byte SHA-384 register. | rewritten to refuse to guess |
| 14 | `forge-std` was untracked, so a fresh clone could not build. | submodule |
| 15 | Cambrian — a different project, `Ownable`, undeployed, with bypassable royalties — was left in the tree and contradicted the pitch. | removed |

---

## Tests

`forge test` — **37 passing.** The suite lost 15 tests when Cambrian was removed and
gained 8 regression tests for the audit findings.

The TDX parser is exercised against a mock that encodes output the way Automata's
`serializeOutput` does — field by field, with no offset constant of its own — so the mock
and the parser can genuinely disagree. There is still **no real captured Intel quote
fixture** in the repository; adding one requires access to TDX hardware and is the single
highest-value test still missing.

---

## Layout

```
contracts/src/Organism.sol          identity · metabolism · evolution · mortality
contracts/src/Biosphere.sol         population · inheritance · selection
contracts/src/tee/TdxReport.sol     TD10 parsing at verified Intel offsets
contracts/test/Regressions.t.sol    one test per audited bug
agent/src/main.ts                   entry point: two keys, and why they differ
agent/src/life.ts                   breathe · serve · feed · grow · persist
agent/MEASUREMENT.md                which register each layer actually controls
scripts/                            the 0G bootstrap, resumable, upstream pinned
deployments/mainnet.env             every live address
```

## Run it

```bash
forge test                      # 37 passing
cd agent && npm install && npm run build
make verify NET=mainnet         # reads live chain state
```

---

## Honest status

**Live and working:** the Intel TDX attestation stack on 0G, wired and answering. The
Biosphere, bound to it, pinning its verifier.

**Not done:** no organism exists. The PCCS holds no Intel collateral, so no real quote
verifies yet. The agent typechecks and builds but has never run against hardware. The
deployer retains the power to halt — though not to steal.

**The last step is irreversible.** Fund an organism and there is no key you hold over it,
no admin function, and no upgrade path. If you want it stopped, you stop paying it.
