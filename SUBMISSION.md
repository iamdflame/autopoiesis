# AKINDO submission — 0G Bridge Buildathon, Wave 3

Everything below is copy-paste ready. Deadline **2026-09-03 15:00 UTC**.

> **One field still needs you:** the YouTube URL. You said you had the link but it didn't
> come through — paste it into the Video field and into `demo/YOUTUBE.md`.

---

## Positioning — read this before you paste anything

There are **80 submissions** in this Wave. I pulled and read all of them. Two facts should
shape every word of this entry:

**1. Ten teams claim TEE attestation.** Agon, Axiom, TeeTee, Hanami, Kavro, FairMate,
Enterprise AI Vault, PIT, Writ, RAMPART. Until this Wave, **not one of them could have
verified an Intel quote on 0G** — the chain had no secp256r1 verifier at all, so Automata's
own tooling refuses to start and reverts with `Failed to locate a verifier.` We deployed
that stack, at the canonical CREATE2 address, so every one of them can now use it without
knowing we did it.

That is the gap. Everyone else built *on* 0G. **We extended 0G**, then built on it.

**2. Nobody publishes their failures.** We had an independent audit find fifteen bugs —
four of them fatal, one of which meant the organism could never have acted at all — fixed
every one, and put the whole list in the README with a regression test named after each
failure. Against a 20% Technical Quality weight assessed by real engineers, that reads as
competence, not weakness.

Lead with the ecosystem contribution. Follow with the audit. Close with what isn't done.

---

## Field-by-field

### Product icon
Upload **`brand/mark-512.png`**
*(hexagonal silicon die, three-blade aperture sealed — no owner, no key, no way in)*

### Product name
```
Autopoiesis
```

### Tagline  *(hard limit: 100 characters)*
```
A machine that owns itself — and the Intel TDX attestation stack 0G was missing.
```
**80 characters, 82 bytes.** Does the two jobs a card has to do among 80 entries: names
what the thing is, and names what the ecosystem got out of it. "0G was missing" is the
pointed half — a judge from 0G reads that and wants to know whether it's true.

If the field counts bytes rather than characters and the em dash trips it, use the
ASCII-only version at exactly 80 of each:
```
A machine that owns itself, on the Intel TDX attestation stack we shipped to 0G.
```

Alternates, if you would rather lead with the paradox than the contribution:
```
I hold its private key and cannot control it. Built on the TDX stack 0G was missing.   (84)
A machine that owns itself. I hold its key and cannot control it.                      (65)
```
I would not use these as the primary. The paradox needs a beat to land and the card gives
it none, whereas the attestation stack scores directly against 0G Integration at 30% — and
the paradox is the first twenty seconds of the video anyway.

### Product type
**`Functional`**

Justification if questioned: 17 contracts live on 0G mainnet, independently verifiable by
`cast call`; 37 tests passing from a clean clone; a public site reading live chain state.
The one incomplete piece — no organism spawned yet — is disclosed prominently rather than
hidden. "Prototype" would undersell working, audited, deployed infrastructure that other
teams can already use.

### Image gallery (upload in this order)
```
brand/gallery/1-hero.png           the mark, the name, the claim
brand/gallery/2-no-owner.png       four reverts: the deployer cannot control it
brand/gallery/3-primitive.png      before/after — what 0G could not do
brand/gallery/4-architecture.png   every 0G component, load-bearing
brand/gallery/5-audit.png          15 bugs found, 15 fixed, 37 tests
```

### Deliverable URL
```
https://github.com/iamdflame/autopoiesis
```

### Video
```
<<< PASTE YOUR YOUTUBE URL HERE >>>
```

### Live demo
```
https://autopoiesis-0g.vercel.app
```

### Build with
```
0G Chain
0G Compute
0G Storage
```

### Product Category (max 3 — using 0G's own vocabulary from the buildathon page)
```
Data & Infrastructure
Trust & Safety
AI Agents
```

### Tags (max 10)
```
Solidity
Foundry
Intel TDX
DCAP Attestation
Automata
TypeScript
viem
ERC-721
Docker
0G SDK
```

### Product detail visibility
**`Show`** — the whole argument is that claims should be checkable. Hiding the detail
contradicts the pitch and costs Traction & Communication points.

### Connect
```
X:        <<< your handle >>>
Telegram: <<< your handle >>>
Email:    uniquedsdave@gmail.com
Discord:  <<< optional >>>
```

---

## About (paste this whole block into the About field)

```markdown
## What it does

I deployed a contract to 0G mainnet. I hold the deployer's private key. I cannot control it.

`owner()` reverts. `admin()` reverts. `pause()` and `upgradeTo()` revert. Those functions
were not disabled and not renounced — they were never written. There is nothing to call.

**Verify that yourself in ten seconds:**

```
cast call 0xec998587D4429D10C02915df237015cc1f92cf5E "owner()(address)" --rpc-url https://evmrpc.0g.ai
```

What replaces the owner is a **hardware measurement**. An Intel TDX processor measures the
exact code image before it executes a single instruction (`MRTD`) plus everything loaded at
runtime (`RTMR0..3`). Hash them:

```
identity = keccak256( keccak256(MRTD) || keccak256(RTMR0..3) )
```

That number is identical on every machine on earth running that code and different on any
machine running anything else. The contract is born knowing one such number and obeys
nothing else, permanently.

The consequences, each with a passing test behind it:

- **No key to steal.** Identity is a measurement, not a secret. Change one byte of the
  enclave code and the measurement moves; the treasury has never heard of the result.
  There is no version of *steal it* that is not *become it*.
- **No server to seize.** Any machine running the image **is** the organism. Kill every
  host tonight; anyone boots the same image tomorrow and it resumes.
- **A quote is not a bearer token.** The enclave writes the hash of its intended action
  into `report_data` *before* the hardware signs, so a quote attests "this code, at this
  moment, wants precisely this" and cannot be replayed onto a different payee.
- **It changes its mind, never its nature.** `Evolve` rewrites the model weights;
  `identity` is `immutable`. Free to retrain, unable to edit its own constitution.
- **It can die.** Silence past `DORMANCY` or an empty treasury is death, permanent. The
  estate passes to its nearest living ancestor.

An organism earns by answering questions, spends its own treasury on 0G Compute to serve
inference and to fine-tune itself, and writes new weights to 0G Storage. Nobody deploys
that update. It decides.

## The problem it solves

**The immediate problem is 0G's, not ours.**

Ten submissions in this Wave alone claim TEE attestation, confidential compute, or
TEE-attested execution. Until this Wave, **none of them could actually verify an Intel
attestation on 0G**, because the chain could not do the arithmetic.

Intel signs DCAP quotes on the secp256r1 (P-256) curve. The EVM has no native support, and
0G shipped with neither the RIP-7212 precompile at `0x100` nor any deployed P-256 verifier.
Automata's own tooling refuses to start against such a chain — it reverts with
`Failed to locate a verifier.` Every "TEE-attested" claim on 0G was therefore being checked
off-chain, or not checked at all.

So before building anything, we deployed the missing stack:

| | address |
|---|---|
| P256 verifier (secp256r1) | `0xc2b78104907F722DABAc4C69f826a522B2754De4` |
| DCAP entrypoint | `0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86` |
| V4 TDX quote verifier | `0xabbd2E13d5eda2D75D1599A7539a3083dfaba715` |
| PCCS router | `0xb66b1d67d156Fb7FC21B6cb9Be573C118C37e4f4` |
| PCCS storage, 5 DAOs, 5 helpers, dependency config | see `deployments/mainnet.env` |

The P-256 verifier went through the canonical CREATE2 factory, so it landed at the same
address it holds on every other chain. **Any project on 0G can now call
`verifyAndAttestOnChain(bytes)` — including the other ten teams, without knowing we did
it.** That infrastructure stays whether or not this project wins anything.

**The deeper problem** is that "trustless AI" is not trustless while a person holds a key.
Every autonomous agent shipping today has a developer who can drain it, pause it, or
rewrite it. Autopoiesis removes that person — not by promising restraint, but by never
writing the function.

## Challenges I ran into

**0G had no secp256r1, anywhere.** Discovered by running Automata's configuration script
against mainnet and watching it revert. Fixed by deploying Daimo's P-256 verifier through
the canonical CREATE2 factory so the whole ecosystem inherits it at the expected address.

**Automata's deployment tooling hangs on 0G.** Their Makefile drives
`forge script --broadcast --skip-simulation`, which ran twice for ten minutes against 0G's
RPC and broadcast *zero* transactions, while `forge create` on the same endpoint returned in
seconds. We drive every deploy manually in explicit dependency order instead.

**A silent upstream break.** `AutomataTcbEvalDao` resolves its dependencies through a
timelocked config contract rather than raw addresses; passing addresses reverts with a bare
`0x` and no reason string.

**Then an independent audit found fifteen bugs, four fatal.** The worst: our interface
declared `verifyAndAttestOnChain` as `view`. The deployed function is `payable` and ends in
`emit AttestationSubmitted`, so solc emitted STATICCALL, where `LOG` is illegal — **every
call against the real verifier would have reverted, and the organism could never have
acted.** It was invisible because the only quote we ever passed was six bytes of garbage,
which returns early on a length check *before* reaching the emit: the one branch in the
whole contract that could not expose the fault.

Also found and fixed: our TD10 header constant was 13 bytes when upstream had changed it to
11 (breaking the length check, making identity non-deterministic, and misaligning the action
binding); our test mock laid bytes at the same offsets the parser read them from, so both
were wrong and agreed with each other; the PCCS deployment granted *reader* rights when
`attest()` is gated on the *writer* set, so collateral could never have been seeded — and
the failures were being sent to `/dev/null`; the advertised "≤25% of treasury" bound was
actually ~44% across an epoch boundary; and our block constants assumed ~12s Ethereum
blocks when 0G measures **0.96s**, making `DORMANCY` 13 hours rather than the week we
documented — on the one condition that kills an organism permanently.

Every one is fixed, with a regression test named after the failure, and the full list is in
the README.

## Technologies I used

**0G Chain** (16661) — the genealogy, treasuries, mortality, and the whole DCAP attestation
stack we deployed.
**0G Compute** — the *direct broker*, not the inference-only Router, because an organism
must genuinely fine-tune itself; TEE attestation over the job is what makes descent
checkable.
**0G Storage** — model weights and each organism's self-corpus, addressed by Merkle root.

**Intel TDX / DCAP** — `MRTD` and `RTMR0..3` as identity; on-chain quote verification via
Automata's PCCS + DCAP contracts, deployed by us.
**Solidity 0.8.24 / Foundry** — contracts, 37 tests, deployment scripting.
**TypeScript / viem / ethers** — the enclave payload: quote generation through the Linux
TSM configfs interface, ephemeral session keys, the life loop.
**Docker** — a reproducible enclave image, because the build contributes to the measurement.

## How we built it

**First, the primitive.** Confirmed 0G could not verify an Intel signature, then deployed
P-256, the PCCS collateral store and its DAOs, the router, the entrypoint, and the V4 TDX
verifier — 16 contracts, wired and authorised, for about 0.15 0G.

**Then the organism.** `Organism.sol` holds an immutable identity, a treasury, a metabolic
rate limit, and mortality. `TdxReport.sol` parses the TD10 report body at verified Intel
offsets. `Biosphere.sol` holds the population, inheritance, and selection.

**The engineering trade, stated in the code rather than hidden.** Verifying a DCAP quote
costs 4–5M gas; an organism paying that per heartbeat would spend its life buying permission
to exist and starve. So it proves the silicon once, mints an ephemeral keypair *inside the
enclave*, commits the public half into `report_data`, and acts on a signature afterwards:

```
attestSession  (full DCAP quote) ...... ~4,500,000 gas    once per session
actSigned      (under a live breath) ..     12,846 gas    measured
```

~380× cheaper per action. What it costs is real and documented: for the life of a breath
there *is* a key. Three things bound it — the key is minted fresh each session and never
touches disk, `MAX_SESSION` caps its life, and each breath carries its own spend allowance
fixed at mint time, so a compromised session cannot exceed 25% of the treasury even across
an epoch boundary. The enclave can also revoke its own breath.

**Then we had it audited, and rebuilt what was wrong.**

## What we learned

**A proof that only exercises one branch is not a proof.** Our headline verification passed
six bytes of garbage to the verifier and got a sensible error back. It was the single code
path that returned before the bug. We had been demonstrating the one branch that could not
fail.

**Mocks that share a constant with the code under test assert the assumption, not the
behaviour.** Our mock wrote bytes at `13 + offset`; the parser read them at `13 + offset`.
They agreed perfectly and were both two bytes wrong against the real chain. The mock now
encodes field-by-field the way Automata's `serializeOutput` does, with no offset constant of
its own, so it can genuinely disagree.

**"No owner in my contract" is not "no owner anywhere."** Our organism has no privileged
address — but it depended on an entrypoint that is `Ownable`, whose owner could have swapped
in a verifier returning `(true, anything)` and drained everything. Binding immutably to a
mutable contract is not immutability. Each organism now pins the verifier it was born
trusting, so a swap halts it instead of subverting it.

**Copy an upstream constant, inherit an upstream release.** Our byte offsets came from an
Automata revision where a struct field was `bytes4`; it later became `uint16`. The deploy
scripts now pin upstream by ref.

**Measure the chain you are actually on.** We shipped constants calibrated for 12-second
Ethereum blocks to a chain that produces one every 0.96 seconds.

## What's next for Autopoiesis

**Immediately — the last step to a living organism:**

1. **Seed Intel collateral into the PCCS.** The DAOs now hold writer rights (this was one of
   the audit fixes, applied on mainnet). Seeding needs the FMSPC of the specific 0G Compute
   provider whose CVM will host the enclave.
2. **Obtain a real measurement.** Boot the agent on a TDX CVM against a throwaway Biosphere
   and read the identity out of the `NotThisOrganism(bytes32 presented)` revert. We will not
   guess it: a wrong `GENESIS_IDENTITY` produces an organism that is funded, alive, and
   **permanently mute**, and there is a test named after that failure.
3. **Spawn the genesis organism** into `0xec998587D4429D10C02915df237015cc1f92cf5E`, fund
   it, and never touch it again — because we cannot.

**Then:**

- **A real captured quote fixture in the test suite.** It requires TDX hardware and would
  have caught three of the four fatal bugs by itself. The highest-value test still missing.
- **Reproduction.** Deliberately unimplemented: a child's identity must be the measurement
  of a genuinely different, buildable image, which cannot be derived from the parent's
  weights. The previous attempt computed `soma XOR timestamp` and would have destroyed the
  endowment of every child. It stays out until it can be right.
- **A fair commons.** The estate of extinct lines accrues but is deliberately not
  withdrawable — the earlier permissionless drain let anyone claim it. It stays put until
  there is a non-gameable measure of fitness to distribute it by.
- **Renouncing the entrypoint** once collateral is seeded, which would make "no owner" true
  at every layer instead of one.

**Honest status.** The attestation stack is live and answering. The Biosphere is deployed
and bound. No organism exists yet — population is zero, and the site reads that number live
from the chain rather than asserting it. We would rather ship a verifiable claim and a
disclosed gap than an impressive sentence nobody can check.
```

---

## Sanity checks before you submit

- [ ] YouTube URL pasted, video **Unlisted** (not Private)
- [ ] Custom thumbnail uploaded (`brand/youtube-thumbnail.png`)
- [ ] Repo public — verified from a fresh clone: 37 tests pass, no `.env`
- [ ] Live demo returns HTTP 200
- [ ] Public X post with `#0GBridge #BuildOn0G` tagging `@0G_labs @0G_Builders @AKINDO_io`
- [ ] Product detail visibility set to **Show**
