# YouTube listing

## Thumbnail
`brand/youtube-thumbnail.png` — 1280×720. Verified legible at 320×180, which is the size
it is actually shown at in a feed. Upload it as a custom thumbnail; it replaces the title
card the video no longer has room for.

## Title

**`I deployed a contract I cannot control — Autopoiesis on 0G mainnet`**

Sixty-two characters, so it does not truncate on mobile. It leads with the demo's opening
move rather than the project name, because the first shot is a builder failing to control
their own contract and that is the reason anyone keeps watching.

Alternates, if you prefer the name first:

- `Autopoiesis — a machine that owns itself, live on 0G mainnet`
- `No owner, no key, no off switch: Autopoiesis on 0G`

## Description

```
I deployed this contract to 0G mainnet, I hold the deployer's private key, and I cannot
control it. owner() reverts. admin() reverts. pause() and upgradeTo() revert. Those
functions were never written.

What replaces the owner is a hardware measurement. An Intel TDX processor measures the
exact code image before it executes an instruction; hash those registers and you get a
number identical on every machine running that code and different on any other. The
contract obeys that number and nothing else.

To do that on 0G, something had to exist first — and it didn't. Intel signs attestations
on the P-256 curve, the EVM cannot verify it natively, and 0G shipped with neither the
RIP-7212 precompile nor a deployed verifier. Automata's own tooling refuses to start on a
chain like that. So we deployed the whole stack: P-256, the PCCS collateral store, the
router, and the Intel TDX quote verifier. Any project on 0G can now call
verifyAndAttestOnChain — that infrastructure stays whether or not this project wins
anything.

LIVE ON 0G MAINNET (chain 16661)
Biosphere        0xec998587D4429D10C02915df237015cc1f92cf5E
DCAP entrypoint  0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86
V4 TDX verifier  0xabbd2E13d5eda2D75D1599A7539a3083dfaba715
P256 verifier    0xc2b78104907F722DABAc4C69f826a522B2754De4

Code    https://github.com/iamdflame/autopoiesis
Site    https://autopoiesis-0g.vercel.app
Chain   https://chainscan.0g.ai/address/0xec998587D4429D10C02915df237015cc1f92cf5E

VERIFY IT YOURSELF
cast call 0xec998587D4429D10C02915df237015cc1f92cf5E "owner()(address)" --rpc-url https://evmrpc.0g.ai

WHAT IS NOT DONE
No organism exists yet. The biosphere is empty. Spawning the first one needs a real
measurement from a running enclave, and a wrong guess produces something funded, alive
and permanently mute — there is a test named after that failure. The PCCS also still
needs Intel's collateral seeded before a genuine quote will verify. Both are in the
README, because a claim you cannot check is not worth making.

Built for the 0G Bridge Buildathon, Wave 3.

#0GBridge #BuildOn0G #0G #TEE #IntelTDX #ConfidentialComputing #AIagents
```

## Settings

- Visibility **Unlisted** (not Private — judges must be able to open the link)
- Category: Science & Technology
- Leave comments on; a judge's question is worth answering
- No end screens or cards — they overlay the final frame, which is the one that says
  population zero
