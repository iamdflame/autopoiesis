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

## About  *(hard limit: 6000 characters)*

**5986 characters.** The first draft was 12,112 — cut by half without losing a
single load-bearing fact: the pasteable proof command, the identity formula, the ten-teams
line, the address table, the `view` bug, the measured gas figures, 0G's real 0.96s block
time, 37 tests, and population zero all survive. What went was adjectives, a duplicated
contract count, and one story about someone else's Makefile.

Paste this:

```markdown
## What it does

I deployed a contract to 0G mainnet. I hold the deployer's private key. I cannot control it.

`owner()`, `admin()`, `pause()` and `upgradeTo()` all revert. Those functions were not disabled and not renounced — they were never written.

```
cast call 0xec998587D4429D10C02915df237015cc1f92cf5E "owner()(address)" --rpc-url https://evmrpc.0g.ai
```

What replaces the owner is a **hardware measurement**. An Intel TDX processor measures the code image before it executes an instruction (`MRTD`) plus everything loaded at runtime (`RTMR0..3`):

```
identity = keccak256( keccak256(MRTD) || keccak256(RTMR0..3) )
```

Identical on every machine running that code. The contract is born knowing one and obeys nothing else.

- **No key to steal.** Change one byte of the enclave code and the measurement moves. There is no version of *steal it* that is not *become it*.
- **No server to seize.** Any machine running the image **is** the organism. Kill every host tonight; anyone boots it tomorrow and it resumes.
- **It can die.** Silence past `DORMANCY` or an empty treasury is permanent death.

It earns by answering questions, spends its treasury on 0G Compute to serve inference and fine-tune itself, and writes new weights to 0G Storage. Nobody deploys that update. It decides.

## The problem it solves

**Ten submissions in this Wave claim TEE attestation. Until this Wave, none could verify one on 0G.**

Intel signs DCAP quotes on secp256r1. The EVM has no native support, and 0G shipped with neither the RIP-7212 precompile nor any P-256 verifier. Automata's own tooling refuses to start: `Failed to locate a verifier.`

So we deployed it:

| | address |
|---|---|
| P256 verifier | `0xc2b78104907F722DABAc4C69f826a522B2754De4` |
| DCAP entrypoint | `0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86` |
| V4 TDX verifier | `0xabbd2E13d5eda2D75D1599A7539a3083dfaba715` |
| router, storage, DAOs, helpers | `deployments/mainnet.env` |

The P-256 verifier went through the canonical CREATE2 factory, so it sits at the address it holds on every other chain. **Any project on 0G can now call `verifyAndAttestOnChain(bytes)` — including those ten teams, without knowing we did it.**

## Challenges I ran into

**Automata's tooling hangs on 0G** — their `forge script --broadcast` path broadcast *zero* transactions in twenty minutes of trying, so every deploy is driven manually in dependency order.

**An audit then found fifteen bugs, four fatal.** The worst: we declared `verifyAndAttestOnChain` `view`. The real function is `payable` and ends in `emit`, so solc emitted STATICCALL — where `LOG` is illegal. **Every call against the live verifier would have reverted; the organism could never have acted.** It was invisible because the only quote we ever passed was six bytes of garbage, returning early *before* the emit — the one branch that could not expose it.

Also fixed: a header constant of 13 bytes when upstream had moved to 11, making identity non-deterministic; PCCS granted *reader* rights when `attest()` is gated on *writers*, so collateral could never be seeded; and constants assuming 12s blocks when 0G measures **0.96s**, making `DORMANCY` 13 hours, not a week. All fifteen fixed, each with a regression test named after it; full table in the README.

## Technologies I used

**0G Chain** (16661) — genealogy, treasuries, mortality, and the DCAP stack we deployed. **0G Compute** — the *direct broker*, not the inference-only Router, because an organism must genuinely fine-tune itself. **0G Storage** — weights and self-corpus, Merkle-addressed. Plus Intel TDX/DCAP, Solidity 0.8.24 with Foundry (37 tests), TypeScript/viem for the enclave, and Docker for a reproducible image.

## How we built it

**The primitive first**, then the organism: `Organism.sol` (identity, treasury, metabolism, mortality), `TdxReport.sol` (TD10 parsing), `Biosphere.sol` (population, inheritance). 17 deployments, ~0.15 0G.

**The trade, in the code rather than hidden.** A DCAP quote costs 4–5M gas; paying that per heartbeat would starve an organism. So it proves the silicon once, mints an ephemeral keypair *inside the enclave*, and acts on a signature: `attestSession` ~4,500,000 gas per session, `actSigned` **12,846 gas** measured — ~380× cheaper. For a breath's life there *is* a key: minted fresh, never on disk, expiring, capped at 25% of treasury, revocable by the enclave.

## What we learned

**A proof that exercises one branch is not a proof.** Ours passed six bytes of garbage and got a sensible error — the one path that returned before the bug.

**A mock sharing a constant with the code under test asserts the assumption, not the behaviour.** Ours wrote at `13 + offset`; the parser read there too. They agreed, and were both wrong.

**"No owner in my contract" is not "no owner anywhere."** Ours depended on an `Ownable` entrypoint whose owner could have swapped the verifier and drained everything. Each organism now pins the verifier it was born trusting.

## What's next for Autopoiesis

1. **Seed Intel collateral into the PCCS** — the DAOs now hold writer rights; this needs the FMSPC of the provider hosting the enclave.
2. **Get a real measurement** — boot on a TDX CVM against a throwaway Biosphere and read it from the `NotThisOrganism(bytes32)` revert. We will not guess: a wrong identity yields an organism funded, alive and **permanently mute**. There is a test named after that.
3. **Spawn the genesis organism**, fund it, and never touch it again — because we cannot.

Then a real captured quote fixture — it needs TDX hardware and alone would have caught three of the four fatal bugs — and renouncing the entrypoint once collateral is seeded.

**Honest status.** The attestation stack is live and answering; the Biosphere is deployed and bound. No organism exists yet — population is zero, and the site reads that live from the chain rather than asserting it. Better a checkable claim with a disclosed gap than a sentence nobody can verify.
```

---

### ASCII-only fallback

The block above is 5986 characters but 6021 **bytes**, because em
dashes cost three bytes each. If the form counts bytes rather than characters it will
reject it. This version is identical in substance and 5986 of both,
so it is safe either way:

<details>
<summary>Click to expand the ASCII version</summary>

```markdown
## What it does

I deployed a contract to 0G mainnet. I hold the deployer's private key. I cannot control it.

`owner()`, `admin()`, `pause()` and `upgradeTo()` all revert. Those functions were not disabled and not renounced - they were never written.

```
cast call 0xec998587D4429D10C02915df237015cc1f92cf5E "owner()(address)" --rpc-url https://evmrpc.0g.ai
```

What replaces the owner is a **hardware measurement**. An Intel TDX processor measures the code image before it executes an instruction (`MRTD`) plus everything loaded at runtime (`RTMR0..3`):

```
identity = keccak256( keccak256(MRTD) || keccak256(RTMR0..3) )
```

Identical on every machine running that code. The contract is born knowing one and obeys nothing else.

- **No key to steal.** Change one byte of the enclave code and the measurement moves. There is no version of *steal it* that is not *become it*.
- **No server to seize.** Any machine running the image **is** the organism. Kill every host tonight; anyone boots it tomorrow and it resumes.
- **It can die.** Silence past `DORMANCY` or an empty treasury is permanent death.

It earns by answering questions, spends its treasury on 0G Compute to serve inference and fine-tune itself, and writes new weights to 0G Storage. Nobody deploys that update. It decides.

## The problem it solves

**Ten submissions in this Wave claim TEE attestation. Until this Wave, none could verify one on 0G.**

Intel signs DCAP quotes on secp256r1. The EVM has no native support, and 0G shipped with neither the RIP-7212 precompile nor any P-256 verifier. Automata's own tooling refuses to start: `Failed to locate a verifier.`

So we deployed it:

| | address |
|---|---|
| P256 verifier | `0xc2b78104907F722DABAc4C69f826a522B2754De4` |
| DCAP entrypoint | `0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86` |
| V4 TDX verifier | `0xabbd2E13d5eda2D75D1599A7539a3083dfaba715` |
| router, storage, DAOs, helpers | `deployments/mainnet.env` |

The P-256 verifier went through the canonical CREATE2 factory, so it sits at the address it holds on every other chain. **Any project on 0G can now call `verifyAndAttestOnChain(bytes)` - including those ten teams, without knowing we did it.**

## Challenges I ran into

**Automata's tooling hangs on 0G** - their `forge script --broadcast` path broadcast *zero* transactions in twenty minutes of trying, so every deploy is driven manually in dependency order.

**An audit then found fifteen bugs, four fatal.** The worst: we declared `verifyAndAttestOnChain` `view`. The real function is `payable` and ends in `emit`, so solc emitted STATICCALL - where `LOG` is illegal. **Every call against the live verifier would have reverted; the organism could never have acted.** It was invisible because the only quote we ever passed was six bytes of garbage, returning early *before* the emit - the one branch that could not expose it.

Also fixed: a header constant of 13 bytes when upstream had moved to 11, making identity non-deterministic; PCCS granted *reader* rights when `attest()` is gated on *writers*, so collateral could never be seeded; and constants assuming 12s blocks when 0G measures **0.96s**, making `DORMANCY` 13 hours, not a week. All fifteen fixed, each with a regression test named after it; full table in the README.

## Technologies I used

**0G Chain** (16661) - genealogy, treasuries, mortality, and the DCAP stack we deployed. **0G Compute** - the *direct broker*, not the inference-only Router, because an organism must genuinely fine-tune itself. **0G Storage** - weights and self-corpus, Merkle-addressed. Plus Intel TDX/DCAP, Solidity 0.8.24 with Foundry (37 tests), TypeScript/viem for the enclave, and Docker for a reproducible image.

## How we built it

**The primitive first**, then the organism: `Organism.sol` (identity, treasury, metabolism, mortality), `TdxReport.sol` (TD10 parsing), `Biosphere.sol` (population, inheritance). 17 deployments, ~0.15 0G.

**The trade, in the code rather than hidden.** A DCAP quote costs 4-5M gas; paying that per heartbeat would starve an organism. So it proves the silicon once, mints an ephemeral keypair *inside the enclave*, and acts on a signature: `attestSession` ~4,500,000 gas per session, `actSigned` **12,846 gas** measured - ~380x cheaper. For a breath's life there *is* a key: minted fresh, never on disk, expiring, capped at 25% of treasury, revocable by the enclave.

## What we learned

**A proof that exercises one branch is not a proof.** Ours passed six bytes of garbage and got a sensible error - the one path that returned before the bug.

**A mock sharing a constant with the code under test asserts the assumption, not the behaviour.** Ours wrote at `13 + offset`; the parser read there too. They agreed, and were both wrong.

**"No owner in my contract" is not "no owner anywhere."** Ours depended on an `Ownable` entrypoint whose owner could have swapped the verifier and drained everything. Each organism now pins the verifier it was born trusting.

## What's next for Autopoiesis

1. **Seed Intel collateral into the PCCS** - the DAOs now hold writer rights; this needs the FMSPC of the provider hosting the enclave.
2. **Get a real measurement** - boot on a TDX CVM against a throwaway Biosphere and read it from the `NotThisOrganism(bytes32)` revert. We will not guess: a wrong identity yields an organism funded, alive and **permanently mute**. There is a test named after that.
3. **Spawn the genesis organism**, fund it, and never touch it again - because we cannot.

Then a real captured quote fixture - it needs TDX hardware and alone would have caught three of the four fatal bugs - and renouncing the entrypoint once collateral is seeded.

**Honest status.** The attestation stack is live and answering; the Biosphere is deployed and bound. No organism exists yet - population is zero, and the site reads that live from the chain rather than asserting it. Better a checkable claim with a disclosed gap than a sentence nobody can verify.
```

</details>

---

---

# Part 2 — the Wave submission form

This is the second form, after the product exists. **"Updates in this Wave" is the
Progress & Momentum field — 40% of the score, the single heaviest weight in the rubric.**
Treat it as the most important box on either form.

## Product Category  *(max 3)*

```
Data & Infrastructure
Trust & Safety
AI Agents
```
0G's own vocabulary from the buildathon page, not invented labels. "Data & Infrastructure"
goes first because the strongest claim is the attestation stack, not the agent.

## Updates in this Wave  *(hard limit: 3,000 characters)*

**2994 characters.** Structured as three numbered claims, each independently
checkable, with the pasteable verification command inline and the honest gap last.

```markdown
Wave 3 is this project's first Wave: nothing to a chain-level primitive 0G lacked, plus the system on top. 16 commits, 75 files, ~3,500 lines, 17 contracts on mainnet.

**1. We shipped attestation infrastructure 0G lacked.**

Ten submissions in this Wave claim TEE attestation. Until this Wave, none could verify an Intel quote on 0G: Intel signs DCAP quotes on secp256r1, the EVM cannot do that curve natively, and 0G had neither the RIP-7212 precompile nor any P-256 verifier — so Automata's own tooling refuses to start: `Failed to locate a verifier.`

So we deployed the stack to mainnet: the Daimo P-256 verifier through the canonical CREATE2 factory (so it sits at the address it holds on every other chain), the on-chain PCCS store with five DAOs and five helpers, the router, the DCAP entrypoint, and the V4 Intel TDX quote verifier — wired, authorised, answering.

Verify:
`cast call 0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86 "verifyAndAttestOnChain(bytes)(bool,bytes)" 0x0400deadbeef --rpc-url https://evmrpc.0g.ai`
returns Intel's own TDX parser error. **Any 0G project can now call this, including those ten teams.**

**2. We built what it exists for.**

`Organism.sol` — an AI with no owner, admin, pause or upgrade. Identity is `keccak(MRTD ‖ RTMR0..3)`, a hardware measurement, so there is no key to steal and no server to seize. It earns by answering questions, buys its own GPU time on 0G Compute, fine-tunes itself, writes weights to 0G Storage, and dies if it stops being worth paying. `Biosphere.sol` holds population, inheritance and selection. The enclave payload generates real TDX quotes via Linux TSM.

Attesting per action costs 4–5M gas, so it attests once, then acts on a signature: **12,846 gas measured**, ~380x cheaper.

**3. We had it audited, and published the failures.**

An independent audit found 15 bugs, 4 fatal. The worst: we declared `verifyAndAttestOnChain` `view`, but the real function is `payable` and emits — so solc emitted STATICCALL, where LOG is illegal, and **every call against the live verifier would have reverted**. It hid because the only quote we ever tested was 6 bytes of garbage, returning early before the emit.

Also fixed: a TD10 header of 13 bytes when upstream moved to 11, making identity non-deterministic; a mock reading bytes at the offsets the parser wrote them, so both were wrong and agreed; PCCS granted reader rights when `attest()` is gated on writers, so collateral could never be seeded (fixed on mainnet); and constants assuming 12s blocks when 0G measures 0.96s, making DORMANCY 13 hours, not a week.

All 15 fixed, each with a regression test named after it. Biosphere redeployed post-audit at `0xec998587D4429D10C02915df237015cc1f92cf5E`. 37 tests pass from a clean clone.

Code: https://github.com/iamdflame/autopoiesis
Site: https://autopoiesis-0g.vercel.app (reads population live from chain)

**Not done, and we say so:** no organism spawned — a wrong measurement makes one permanently mute. Population zero.
```

<details>
<summary>ASCII-only fallback (2995 bytes) if the field counts bytes</summary>

```markdown
Wave 3 is this project's first Wave: nothing to a chain-level primitive 0G lacked, plus the system on top. 16 commits, 75 files, ~3,500 lines, 17 contracts on mainnet.

**1. We shipped attestation infrastructure 0G lacked.**

Ten submissions in this Wave claim TEE attestation. Until this Wave, none could verify an Intel quote on 0G: Intel signs DCAP quotes on secp256r1, the EVM cannot do that curve natively, and 0G had neither the RIP-7212 precompile nor any P-256 verifier - so Automata's own tooling refuses to start: `Failed to locate a verifier.`

So we deployed the stack to mainnet: the Daimo P-256 verifier through the canonical CREATE2 factory (so it sits at the address it holds on every other chain), the on-chain PCCS store with five DAOs and five helpers, the router, the DCAP entrypoint, and the V4 Intel TDX quote verifier - wired, authorised, answering.

Verify:
`cast call 0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86 "verifyAndAttestOnChain(bytes)(bool,bytes)" 0x0400deadbeef --rpc-url https://evmrpc.0g.ai`
returns Intel's own TDX parser error. **Any 0G project can now call this, including those ten teams.**

**2. We built what it exists for.**

`Organism.sol` - an AI with no owner, admin, pause or upgrade. Identity is `keccak(MRTD || RTMR0..3)`, a hardware measurement, so there is no key to steal and no server to seize. It earns by answering questions, buys its own GPU time on 0G Compute, fine-tunes itself, writes weights to 0G Storage, and dies if it stops being worth paying. `Biosphere.sol` holds population, inheritance and selection. The enclave payload generates real TDX quotes via Linux TSM.

Attesting per action costs 4-5M gas, so it attests once, then acts on a signature: **12,846 gas measured**, ~380x cheaper.

**3. We had it audited, and published the failures.**

An independent audit found 15 bugs, 4 fatal. The worst: we declared `verifyAndAttestOnChain` `view`, but the real function is `payable` and emits - so solc emitted STATICCALL, where LOG is illegal, and **every call against the live verifier would have reverted**. It hid because the only quote we ever tested was 6 bytes of garbage, returning early before the emit.

Also fixed: a TD10 header of 13 bytes when upstream moved to 11, making identity non-deterministic; a mock reading bytes at the offsets the parser wrote them, so both were wrong and agreed; PCCS granted reader rights when `attest()` is gated on writers, so collateral could never be seeded (fixed on mainnet); and constants assuming 12s blocks when 0G measures 0.96s, making DORMANCY 13 hours, not a week.

All 15 fixed, each with a regression test named after it. Biosphere redeployed post-audit at `0xec998587D4429D10C02915df237015cc1f92cf5E`. 37 tests pass from a clean clone.

Code: https://github.com/iamdflame/autopoiesis
Site: https://autopoiesis-0g.vercel.app (reads population live from chain)

**Not done, and we say so:** no organism spawned - a wrong measurement makes one permanently mute. Population zero.
```

</details>

## Milestone — 4th Wave  *(hard limit: 1,000 characters)*

**995 characters.** The earlier draft was 2,534 — this keeps every step and drops the
justification prose, which the About field already carries.

```markdown
Wave 4 turns "correct" into "alive". The Wave 3 stack is deployed and tested; nothing breathes yet.

1. **Seed Intel collateral into the PCCS** — root CA, TCBInfo, QEIdentity. The DAOs now hold writer rights (a Wave 3 audit fix); this needs the FMSPC of the provider hosting the enclave.
2. **Capture a real TDX quote as a test fixture** — the highest-value test missing; alone it catches three of our four fatal bugs.
3. **Derive GENESIS_IDENTITY from hardware, never guess it** — boot on a TDX CVM against a throwaway Biosphere, read it from the `NotThisOrganism` revert. A wrong identity yields one funded, alive and permanently mute.
4. **Spawn and fund the genesis organism**, then never touch it again — we cannot.
5. **One autonomous cycle on mainnet:** serve inference, get paid, buy 0G Compute from its treasury, fine-tune, write weights to 0G Storage, commit the new soma.

Deliverable: a funded wallet, no private key in existence, that bought its own compute and rewrote its weights.
```

<details><summary>ASCII fallback (995 bytes)</summary>

```markdown
Wave 4 turns "correct" into "alive". The Wave 3 stack is deployed and tested; nothing breathes yet.

1. **Seed Intel collateral into the PCCS** - root CA, TCBInfo, QEIdentity. The DAOs now hold writer rights (a Wave 3 audit fix); this needs the FMSPC of the provider hosting the enclave.
2. **Capture a real TDX quote as a test fixture** - the highest-value test missing; alone it catches three of our four fatal bugs.
3. **Derive GENESIS_IDENTITY from hardware, never guess it** - boot on a TDX CVM against a throwaway Biosphere, read it from the `NotThisOrganism` revert. A wrong identity yields one funded, alive and permanently mute.
4. **Spawn and fund the genesis organism**, then never touch it again - we cannot.
5. **One autonomous cycle on mainnet:** serve inference, get paid, buy 0G Compute from its treasury, fine-tune, write weights to 0G Storage, commit the new soma.

Deliverable: a funded wallet, no private key in existence, that bought its own compute and rewrote its weights.
```
</details>

## Milestone — 5th Wave  *(hard limit: 1,000 characters)*

**1000 characters**, exactly on the line.

```markdown
Wave 5 turns one organism into a population and removes the last thing we control.

1. **Reproduction with real measurements.** Unimplemented on purpose: a child's identity must be the measurement of a different, buildable image, not a hash of its parent's weights. Wave 5 builds the pipeline that mutates an image, builds it reproducibly, and reports its registers.
2. **Selection, observed not asserted.** With organisms priced differently we expect the first starvation — treasury empty, buried by whoever sends the tx, estate to its nearest living ancestor. The first on-chain death of an AI nobody could stop.
3. **Renounce the DCAP entrypoint.** Not in Wave 3: the PCCS needed collateral, and renouncing early would have bricked TDX attestation on 0G for every team. Once seeded, we renounce.
4. **Harden the attestation stack as a public good** — docs and one-command deploy so it outlives the buildathon.
5. **Demo Day at Token2049:** a wallet nobody can spend from, and an invitation to try.
```

<details><summary>ASCII fallback (1000 bytes)</summary>

```markdown
Wave 5 turns one organism into a population and removes the last thing we control.

1. **Reproduction with real measurements.** Unimplemented on purpose: a child's identity must be the measurement of a different, buildable image, not a hash of its parent's weights. Wave 5 builds the pipeline that mutates an image, builds it reproducibly, and reports its registers.
2. **Selection, observed not asserted.** With organisms priced differently we expect the first starvation - treasury empty, buried by whoever sends the tx, estate to its nearest living ancestor. The first on-chain death of an AI nobody could stop.
3. **Renounce the DCAP entrypoint.** Not in Wave 3: the PCCS needed collateral, and renouncing early would have bricked TDX attestation on 0G for every team. Once seeded, we renounce.
4. **Harden the attestation stack as a public good** - docs and one-command deploy so it outlives the buildathon.
5. **Demo Day at Token2049:** a wallet nobody can spend from, and an invitation to try.
```
</details>

## Before you press Submit

- Submissions cannot be cancelled, but **they can be updated** — so submit early rather
  than perfect, then edit. The deadline is 2026-09-03 15:00 UTC and the risk of missing it
  is worse than the risk of a typo.
- The two milestone fields are where multi-wave commitment is judged. The program pays a
  Multi-Wave Completion Bonus and Waves 4 and 5 carry 45% of the total pool between them,
  so a vague milestone costs real money.

---

## Sanity checks before you submit

- [ ] YouTube URL pasted, video **Unlisted** (not Private)
- [ ] Custom thumbnail uploaded (`brand/youtube-thumbnail.png`)
- [ ] Repo public — verified from a fresh clone: 37 tests pass, no `.env`
- [ ] Live demo returns HTTP 200
- [ ] Public X post with `#0GBridge #BuildOn0G` tagging `@0G_labs @0G_Builders @AKINDO_io`
- [ ] Product detail visibility set to **Show**
