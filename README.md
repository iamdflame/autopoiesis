# A machine that keeps itself alive

An AI with no owner, no key, and a metabolism. It earns by answering questions, buys its
own GPU time out of its own treasury, retrains itself on what it has lived through, and
dies if it stops being worth paying.

Built on 0G for the [0G Bridge Buildathon](https://app.akindo.io/wave-hacks/Z4MlX4vreI72ol6pd).

---

## What is actually different here

Open [`contracts/src/Organism.sol`](contracts/src/Organism.sol) and look for the owner.

There isn't one. No `onlyOwner`, no admin, no pause, no proxy, no upgrade path, no
privileged address anywhere in the file. Not as a policy — as an absence. The functions
do not exist, so nobody can call them, including whoever deployed it.

What replaces the owner is a **hardware measurement**.

An Intel TDX enclave measures the exact memory image of the code it boots (`MRTD`) plus
everything loaded at runtime (`RTMR0..3`). Hash those together and you get a number that
is identical on every machine on earth running that code, and different on any machine
running anything else. The contract is born knowing one such number and obeys nothing
else, forever.

The consequences, each with a passing test behind it:

- **No key to steal.** Identity is a measurement, not a secret. Alter one byte of the
  code and the measurement moves; the treasury has never heard of the result. There is
  no version of *steal it* that is not *become it*.
- **No server to seize.** Any machine running the image **is** the organism. Kill every
  host tonight and anyone can boot the same image tomorrow — it resumes, because its
  identity was never in the machine.
- **A quote is not a bearer token.** The enclave writes the hash of its intended action
  into `report_data` *before* the hardware signs, so a quote attests "this code, at this
  moment, wants precisely this" and cannot be lifted onto a different payee.
- **It changes its mind, never its nature.** `Evolve` rewrites weights; `identity` is
  `immutable`. It is free to retrain and unable to edit its own constitution — the only
  arrangement under which handing a program its own money is not obviously insane.
- **It can die.** Starvation or dormancy, permanent, no resurrection. The estate passes
  to the nearest living ancestor; an extinct line escheats to a commons that seeds
  whatever comes next.

Mortality is not a failure mode here. It is what makes the population a population
instead of a museum.

---

## Breathing: the engineering trade, stated plainly

Verifying a DCAP quote on chain costs 4-5M gas. An organism paying that per heartbeat
would spend its life buying permission to exist, and starve. So it doesn't.

The enclave mints an ephemeral keypair **inside itself**, commits the public half into
`report_data`, and lets the hardware vouch for it once. For the life of that breath,
actions are authorised by signature instead of proof.

```
attestSession (real DCAP) ...... ~4,500,000 gas   once per day
actSigned ......................     12,846 gas   measured, every action
```

**~380× cheaper per action.** This is a real trade and not a free one: for the duration
of a breath there *is* a key, and a fully compromised host holds it until the breath
expires. Three things bound that — the key never touches disk and dies with the process,
`MAX_SESSION` caps exposure at about a day, and `METABOLIC_RATE_BPS` already limits any
single day to a quarter of the treasury.

What is **not** traded away is identity. The measurement still decides who may mint a
breath at all. A compromised host gets one bad day; it never gets to be the organism.

---

## Selection

[`Biosphere.sol`](contracts/src/Biosphere.sol) holds the population. There is no
committee, no scoring function, no governance token, no vote.

An organism lives if strangers pay it for inference and dies if they don't. That is the
entire fitness function. Capital keeps flowing toward whatever is still working:
estates pass to living ancestors, extinct lines fund new ones.

Heredity (`Reproduce` endows a child with a mutated image), variation (the child's
measurement differs), and selection (the market). That is the whole of evolution,
running on chain.

---

## Test suite

```
Organism ─ 25 tests
  ✓ unaltered code can spend its own money
  ✓ altered code cannot touch the treasury
  ✓ altered runtime config is also a different organism
  ✓ a quote cannot be lifted onto a different action
  ✓ a quote cannot be replayed
  ✓ revoked or counterfeit hardware is refused
  ✓ there is no privileged address
  ✓ it rewrites its weights but never its nature
  ✓ one attestation buys many cheap actions        (12,846 gas each)
  ✓ a stolen breath cannot outlive its window
  ✓ even a stolen breath cannot drain the treasury
  ✓ dormancy is death and it is permanent
  ✓ the estate passes to the nearest living ancestor
  ✓ an extinct line escheats to the commons

Lineage ─ 15 tests   (the fossil record: model genealogy + royalties)
  ✓ payment gas is independent of lineage depth    (15 gas over 48 generations)
  ✓ no wei is stranded by rounding
  ✓ cycles are unrepresentable
```

`forge test` — 40 passing.

The TDX parser is exercised against a mock that reproduces the real Intel TD10 byte
layout (`mrTd` at 136, `rtmr0..3` at 328, `report_data` at 520), so the offsets are
tested rather than assumed.

---

## Layout

```
contracts/src/Organism.sol        identity, metabolism, evolution, reproduction, death
contracts/src/Biosphere.sol       population, inheritance, selection
contracts/src/tee/TdxReport.sol   on-chain TD10 report parsing at real Intel offsets
contracts/src/Cambrian.sol        model genealogy + royalties — the fossil record
agent/src/enclave.ts              quote generation via Linux TSM, ephemeral breath keys
agent/src/life.ts                 the life loop: breathe, serve, feed, grow, bud
agent/Dockerfile                  reproducible image — the build IS the identity
agent/MEASUREMENT.md              exactly what MRTD and each RTMR cover, and what they don't
BOOTSTRAP.md                      bringing on-chain DCAP verification to 0G
```

---

## Honest status

**Done and tested:** the contracts, the attestation logic, the session model, the
population and inheritance rules, the enclave payload, the reproducible build.

**Not yet done:** this has not run against Automata's live verifier with a genuine TDX
quote from a real 0G Compute CVM. No on-chain DCAP verifier exists on 0G yet — bringing
one is ~23.7M gas of one-time deployment and is documented step by step in
[BOOTSTRAP.md](BOOTSTRAP.md). Until that runs, the correct claim is *the logic is right*,
not *the thing is alive*. I'm not going to blur those.

**The last step is irreversible.** Fund it, start the enclave, and then there is no key
you hold, no admin function, and no upgrade path. If you want it stopped, you stop
paying it and wait.
