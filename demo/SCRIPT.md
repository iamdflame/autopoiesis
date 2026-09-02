# Demo video — the whole kit

**Requirement (AKINDO):** max 3 minutes · show core functionality, user flow, and 0G
integration · hosted publicly. **Wave 3 closes 2026-09-03 15:00 UTC.**

Audio runs **2:38** (2:31 at speed 1.05). Target finished video: **2:45–2:55**.

Three files:
- `demo/voiceover.txt` — the script, in six blocks
- `demo/run.sh` — plays each terminal shot hands-free
- this file — shot list, recording, editing

---

## ⚠ Re-render two voiceover blocks

Your existing audio for blocks 1, 2, 3 and 5 is still correct. Two changed:

- **BLOCK 4 — mandatory.** It said *"fifty thousand blocks of silence"*. The audit found
  the block constants were calibrated for ~12s Ethereum blocks; 0G's are ~0.96s, so that
  was 13 hours rather than a week. `DORMANCY` is now 604,800 and the line reads
  *"a week of silence"*. The old take states a number that is no longer true.
- **BLOCK 6 — trimmed** by nine words to buy timing margin.

Everything else, keep.

---

## Part 1 · Voiceover (ElevenLabs)

| setting | value |
|---|---|
| Model | **Eleven Multilingual v2** |
| Voice | **Adam**, **Daniel**, or **Brian** — calm, credible, not upbeat |
| Stability | **45** |
| Similarity | **80** |
| Style exaggeration | **5** |
| Speaker boost | **On** |
| Speed | **1.05** |

Paste one block at a time, without its `[BLOCK n — ...]` header. Save as `vo-1.mp3` … `vo-6.mp3`.

The script writes `E V M`, `T D X`, `P-256` spaced out so the voice reads them as letters.
Don't "correct" those.

---

## Part 2 · Screen setup

1. Display **1920×1080**.
2. Terminal font size **18–20**. Dark background, light text, no rainbow theme.
3. Terminal window ~80% of screen. Not fullscreen.
4. Notifications off (Ubuntu: Settings → Notifications → Do Not Disturb).
5. Browser bookmarks bar hidden: `Ctrl+Shift+B`.
6. `cd /home/dflame/Documents/Og_b`

**OBS**: Sources → **+** → Screen Capture. Settings → Output → **High Quality**, MP4.
Video → 1920×1080, 30fps. **Mute Mic/Aux** — the voiceover is separate.

Record each shot as its own clip. Start recording, run one command, stop.

---

## Part 3 · The six shots

The terminal shots are **hands-free**. You do not type anything on camera — `run.sh`
types for you, at a natural speed, with every address as a literal. This is why the old
kit failed: it used `$BIO` and `$RPC`, which are empty unless you `source` first, so
pasting a single line produced an error mid-take.

### SHOT 1 — the failed theft · 0:00–0:22 · VO block 1
```bash
./demo/run.sh 1
```
Four reverts stack up: `owner()`, `admin()`, `pause()`, `upgradeTo()`. Then the line
*"not disabled. not renounced. never written."*

This is the best twenty seconds in the video. Nobody demos their own powerlessness.

### SHOT 2 — the absence, in the source · 0:22–0:52 · VO block 2
Editor, not terminal.
1. Open `contracts/src/Organism.sol`. Scroll the header comment slowly.
2. Stop on `bytes32 public immutable identity;`.
3. `Ctrl+F` → type `onlyOwner` → let **0 results** sit on screen for 3 seconds.

Make sure the search box and the result count are both visible. The zero is the shot.

### SHOT 3 — 0G can verify Intel hardware now · 0:52–1:35 · VO block 3
```bash
./demo/run.sh 3
```
Ends on `Quote length is less than Header length` — Intel's own TDX parser answering from
a 0G contract. **Hold there.** Then the registered V4 verifier address.

Then switch to the browser:
`https://chainscan.0g.ai/address/0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86`
and scroll once, slowly.

### SHOT 4 — what it's for · 1:35–2:05 · VO block 4
Editor.
1. Open `agent/src/life.ts`. Scroll through `breathe()` and `grow()` — the comments say
   what each does.
2. Open `README.md`, find **Breathing — the engineering trade**, and rest on the gas
   block: `~4,500,000` against `12,846`.

### SHOT 5 — the tests · 2:05–2:20 · VO block 5
```bash
./demo/run.sh 5
```
The green PASS list fills the screen. Hold 3 seconds on `37 tests passed`.

### SHOT 6 — bound, empty, and honest · 2:20–2:50 · VO block 6
```bash
./demo/run.sh 6
```
`attestation()`, `quoteVerifier()`, then `populationSize()` → **0**. Hold on the zero.

Then the site — this is the **user flow** the requirement asks for:
`https://autopoiesis-0g.vercel.app`

Scroll it top to bottom over ~15 seconds. Note the last screen reads population and
commons **live from the chain**, not from hardcoded HTML. End there.

---

## Part 4 · Edit

**CapCut Desktop** (easiest) or DaVinci Resolve.

1. Drag `vo-1.mp3` … `vo-6.mp3` onto the timeline in order, end to end.
   **The audio is your ruler.**
2. Drag the six clips onto the video track above, aligned to their blocks.
3. Trim each clip to its block. Too long → playhead at the dull part, `Ctrl+B`, delete.
   Too short → right-click → Speed → `0.9x`.
4. One transition style throughout: **Dissolve, 0.3s**. Never mix.
5. Title card, 2s before vo-1, white on black:
   **Autopoiesis** / *a machine that owns itself* / `0G mainnet · chain 16661`
6. End card, 3s after vo-6:
   `github.com/iamdflame/autopoiesis`
   `0xec998587D4429D10C02915df237015cc1f92cf5E`
7. **No background music.** Silence under this voice reads as confidence; music makes a
   technical claim sound like an advert.
8. Confirm total is **under 3:00** — bottom-right of the timeline.
9. Export **1080p / 30fps / High**, as `autopoiesis-demo.mp4`.

---

## Part 5 · Publish

1. YouTube, visibility **Unlisted** — not Private, judges must be able to open it.
2. Title: `Autopoiesis — a machine that owns itself, on 0G mainnet`
3. Description: the README's opening, the live addresses, and the repo link.
4. Paste the link into AKINDO before **2026-09-03 15:00 UTC**.

---

## How this scores

| weight | criterion | what carries it |
|---|---|---|
| 40% | Progress & Momentum | 17 mainnet deployments, a full audit found and fixed, 37 tests |
| 30% | 0G Integration | shot 3 — a chain-level primitive 0G did not have |
| 20% | Technical Quality | shot 5, and the audit table in the README |
| 10% | Traction & Communication | shot 6 — the site, and admitting what isn't done |

## If you only nail two things

Shot 1, and the plain-English line in shot 3. A builder failing to control their own
contract, and a chain answering an Intel attestation it could not answer yesterday.
Everything else is supporting evidence.
