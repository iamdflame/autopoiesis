# The mandatory X post

**Requirement (AKINDO):** at least one public post on X containing the project name, a
demo screenshot or short clip, the hashtags `#0GBridge #BuildOn0G`, and tags for
`@0G_labs @0G_Builders @AKINDO_io`.

**Post 1 satisfies all four on its own**, so the requirement is met even if nobody reads
past it. Everything after is upside. Every post is under 280 characters, so this works on
a free account with no Premium.

---

## Post 1 — the hook  ·  **attach the demo video here**  ·  270 chars

```
I deployed this contract to 0G mainnet.
I hold the deployer's private key.
I cannot control it.

owner() reverts. admin() reverts. pause() reverts.
They were never written.

Autopoiesis — a machine that owns itself.

#0GBridge #BuildOn0G
@0G_labs @0G_Builders @AKINDO_io
```

The video does the work. Text that describes a video people are about to watch wastes the
one shot you get; text that states a claim the video then proves does not.

## Post 2 — the gap  ·  274 chars

```
Why this took real work:

Intel signs TDX attestations on secp256r1. The EVM can't verify that curve, and 0G shipped with no precompile and no P-256 verifier.

Automata's own tooling refuses to start on such a chain:
"Failed to locate a verifier."

So we deployed the stack.
```

## Post 3 — the proof  ·  278 chars

```
0G can verify Intel hardware attestation as of this Wave.

Paste this:

cast call 0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86 "verifyAndAttestOnChain(bytes)(bool,bytes)" 0x0400deadbeef --rpc-url https://evmrpc.0g.ai

You get Intel's own TDX parser error back. From a 0G contract.
```

## Post 4 — the gift  ·  268 chars

```
The P-256 verifier went through the canonical CREATE2 factory, so it sits at the address it holds on every other chain.

Ten teams in this Wave claim TEE attestation. None of them could verify a quote on 0G before this.

Now all of them can, without knowing we did it.
```

This is the post most likely to be quote-tweeted by 0G. It is a real contribution stated
without pettiness — the other teams are named as beneficiaries, not competitors.

## Post 5 — the audit  ·  270 chars

```
Then we had it audited. 15 bugs, 4 fatal.

The worst: we declared verifyAndAttestOnChain `view`. The real function emits, so solc emitted STATICCALL — where LOG is illegal.

Every call would have reverted. It hid because our only test quote was 6 bytes, returning early.
```

## Post 6 — the honest close  ·  279 chars

```
All 15 fixed, each with a regression test named after the failure. 37 passing.

What isn't done: no organism spawned. Population is zero, and the site reads that live from the chain rather than asserting it.

Code: github.com/iamdflame/autopoiesis
Site: autopoiesis-0g.vercel.app
```

---

## How to post it

1. **Post 1 with the video attached.** Upload the MP4 directly to X rather than linking
   YouTube — native video autoplays in the timeline and gets far more reach than a link
   card. Keep the YouTube link for the AKINDO submission.
2. Reply to your own post 1 with post 2, to post 2 with post 3, and so on. A thread, not
   six separate posts.
3. If you would rather post once: **post 1 alone is compliant.** Do not merge them; a
   280-character post with everything crammed in reads worse than a clean hook.
4. After posting, paste the URL of post 1 into the AKINDO submission if there is a field
   for it, and keep it for the Wave 4 update.

## If you only post one thing

Post 1. A builder saying *I hold the private key and I cannot control it*, with a video
that proves it, is the whole submission in nine seconds.
