# Demo video — everything you need

**Target: 2 minutes 51 seconds.** Hard cap is 3:00.

Three files:
- `demo/voiceover.txt` — paste into ElevenLabs
- `demo/commands.sh` — the exact commands, all pre-verified against mainnet
- this file — shot list, recording, editing

---

## Part 1 · Make the voiceover (do this FIRST)

The voiceover is the skeleton. You record screens to fit *it*, never the other way round.

### ElevenLabs settings

| setting | value | why |
|---|---|---|
| Model | **Eleven Multilingual v2** | best quality for English narration; don't use Turbo for the final |
| Voice | **Adam**, **Daniel**, or **Brian** | deep, calm, credible. Avoid anything bright or upbeat |
| Stability | **45** | low enough to breathe, high enough not to wobble |
| Similarity | **80** | |
| Style exaggeration | **5** | keep near zero — this is a proof, not a trailer |
| Speaker boost | **On** | |
| Speed | **1.0** | only raise to 1.05 if you overrun 3:00 |

### Steps

1. Go to elevenlabs.io → **Text to Speech**.
2. Set the settings in the table above.
3. Open `demo/voiceover.txt`. **Do one BLOCK at a time.** Do not paste all six at once.
4. Copy the text of BLOCK 1 only — *not* the `[BLOCK 1 — ...]` header line.
5. Click Generate. Listen.
6. If a word sounds wrong, regenerate that block only. That is why they're split.
7. Download each block. You'll have six files. Name them `vo-1.mp3` … `vo-6.mp3`.

> **Pronunciation:** the script already spells out `E V M`, `T D X`, and `P-256` so the
> voice says them as letters. Don't "fix" those into EVM/TDX or it will mispronounce them.

---

## Part 2 · Set up your screen

Do this before recording anything. It is the difference between amateur and professional.

1. **Set your screen to 1920×1080.** Settings → Display → Resolution.
2. **Make the terminal font big.** In your terminal: Preferences → Font → size **18–20**.
   A judge watching on a phone must be able to read it.
3. **Terminal colours:** dark background, white text. No rainbow themes.
4. **Make the terminal window big** — about 80% of the screen. Not fullscreen.
5. **Clean your desktop.** Close Slack, email, everything. Turn off notifications.
   (Ubuntu: Settings → Notifications → Do Not Disturb **on**.)
6. **Hide your bookmarks bar** in the browser: `Ctrl+Shift+B`.
7. Open a terminal and run:
   ```bash
   cd /home/dflame/Documents/Og_b
   source demo/commands.sh
   clear
   ```
   That loads the addresses so you can paste short commands on camera.

---

## Part 3 · Record the screen

**Tool: OBS Studio** (free — `sudo apt install obs-studio`).

### One-time OBS setup
1. Open OBS. If a wizard appears, choose **Optimise for recording**.
2. Settings → Output → Recording Quality: **High Quality**. Format: **MP4**.
3. Settings → Video → Base and Output resolution: **1920×1080**. FPS: **30**.
4. In the **Sources** box, click **+** → **Screen Capture** → OK → OK.
5. Close settings. You should see your screen inside OBS.

### The rule
**Record each shot as its own clip.** Press *Start Recording*, do one shot, press
*Stop Recording*. Six clips. If you fluff a shot, delete it and redo just that one.

Do **not** record audio from your microphone — the voiceover is separate. In OBS,
mute *Mic/Aux* by clicking the speaker icon next to it.

---

## Part 4 · The six shots

Type commands **slowly and deliberately**. Let each result sit on screen for 2 seconds
before you move on. Dead air is fine — you'll trim it.

### SHOT 1 — the failed theft · ~22s
Terminal, cleared. Run these one at a time, pausing after each:
```
cast call $BIO "owner()(address)"      --rpc-url $RPC
cast call $BIO "admin()(address)"      --rpc-url $RPC
cast call $BIO "pause()"               --rpc-url $RPC
cast call $BIO "upgradeTo(address)" $Z --rpc-url $RPC
```
Four reverts stacked on screen. **Do not clear between them** — the stack is the point.

### SHOT 2 — the code · ~30s
1. Open `contracts/src/Organism.sol` in your editor.
2. Scroll slowly through the top comment block, then to `bytes32 public immutable identity;`.
3. Then: `Ctrl+F`, search `onlyOwner`. Let **0 results** sit on screen for 3 seconds.

That "no results" is the shot. Make sure the search box and result count are visible.

### SHOT 3 — 0G can verify hardware now · ~43s
Back in the terminal, cleared:
```
cast code $P256 --rpc-url $RPC | wc -c
```
Then the important one — this prints readable English:
```
cast call $ENTRY "verifyAndAttestOnChain(bytes)(bool,bytes)" 0x0400deadbeef \
  --rpc-url $RPC | tail -1 | xargs cast to-ascii
```
→ `Quote length is less than Header length`

**Hold on that line for 3 full seconds.** It is the best moment in the video.

Then open a browser to
`https://chainscan.0g.ai/address/0x51Be618E3CA0b0B19FA0cC6c10960fF62783Da86`
and scroll gently once.

### SHOT 4 — the life loop · ~30s
1. Open `agent/src/life.ts`. Scroll slowly through `breathe()` and `grow()`.
2. Then open `README.md` and show the **Measured, not estimated** block.

### SHOT 5 — the tests · ~15s
Terminal, cleared:
```
forge test --match-path contracts/test/Organism.t.sol
```
Let the green PASS list fill the screen. Hold 3 seconds on the final count.

### SHOT 6 — the empty biosphere · ~30s
```
cast call $BIO "attestation()(address)"    --rpc-url $RPC
cast call $BIO "populationSize()(uint256)" --rpc-url $RPC
```
Hold on the `0`. Then open the site:
`https://autopoiesis-8fk1aaznc-david-praises-projects.vercel.app`
and scroll it slowly, top to bottom, over about 15 seconds. End on the last screen.

---

## Part 5 · Edit it together

**Tool: CapCut Desktop** (free, easiest). DaVinci Resolve if you already know it.

1. Open CapCut → **New Project**.
2. Drag `vo-1.mp3` … `vo-6.mp3` onto the timeline, in order, end to end.
   **The audio is now your ruler.** Everything else fits around it.
3. Drag your six screen clips onto the video track above the audio.
4. Line up clip 1 so it starts with vo-1, clip 2 with vo-2, and so on.
5. **Trim each clip to match its block's length.** Grab the clip edge and drag.
   If a clip is too short, slow it: right-click → Speed → `0.9x`.
   If too long, cut the dead air: put the playhead where the boring part starts,
   press `Ctrl+B` to split, click the dead piece, press `Delete`.
6. Add **one** transition style between shots: click between two clips → Transitions →
   **Dissolve**, 0.3s. Use the same one every time. Do not mix transitions.
7. Add a title card at the very start (2 seconds, before vo-1):
   Text → big, white on black:
   **Autopoiesis** / *a machine that owns itself* / `0G mainnet · chain 16661`
8. Add an end card (3 seconds after vo-6), white on black:
   `github.com/<your-repo>` and the Biosphere address
   `0x577B21214e6549044f9c2A58835713Dda0d849dE`
9. **No background music.** Silence under a voice like this is stronger, and music makes
   a technical claim sound like an advert.
10. Check total length is **under 3:00**. Bottom-right of the CapCut timeline.
11. Export: **1080p, 30fps, High quality**. Save as `autopoiesis-demo.mp4`.

---

## Part 6 · Publish

1. Upload to YouTube. Set visibility to **Unlisted** (not Private — judges must open it).
2. Title: `Autopoiesis — a machine that owns itself, on 0G mainnet`
3. Description: paste the top of the README plus the live addresses.
4. Copy the link into the AKINDO submission.

---

## If you only get one thing right

Shot 1 and the plain-English line in Shot 3.

A builder failing to control their own contract, and a chain answering an Intel
attestation it could not answer yesterday. Everything else is supporting evidence.
