# Brand

## The mark

A hexagonal silicon die with a three-blade aperture that is **closed**. Every element is
load-bearing:

- **Hexagon** — a die, not a badge. The subject is silicon, and the identity of the whole
  system is a measurement taken by a processor.
- **Three blades, sealed** — an aperture with no opening. The machine has no owner, no
  key, and no way in. The blades are rotationally symmetric, which gives it the quality of
  a seal or stamp rather than an icon.
- **Vermillion `#F03C02`** — hot, alive, urgent. Not the muted terracotta that generated
  brands default to, and not the near-black-and-acid-green that every crypto project uses.

Two directions were built and discarded before this one: a rounded square with a centre
void, which turned out to be the Instagram logo almost exactly, and a stack of five bars
representing the measurement registers, which read as a loading skeleton. Both are worth
knowing about so nobody re-proposes them.

`mark.svg` is the source of truth. The PNGs are rendered from the same geometry.

## Files

```
mark.svg              source of truth, 1024 viewBox, mask-based
mark.png              1024, transparent
mark-{512,256,128,64,32}.png
mark-ink.png          near-black, for light grounds
mark-paper.png        bone, for dark grounds
lockup-dark.png       mark + wordmark, dark ground
lockup-light.png      mark + wordmark, light ground
youtube-thumbnail.png 1280x720, verified legible at 320x180
```

## Palette

| token | hex | use |
|---|---|---|
| vermillion | `#F03C02` | the accent, and only the accent |
| ink | `#0C0D0F` | near-black ground, faint cool bias |
| paper | `#EAEBED` | cool near-white, never cream |
| dim | `#8A8D94` | secondary text |

## Type

- **Archivo**, weight 900, width 125 — display and wordmark
- **Space Mono** — addresses, figures, labels

Both are on Google Fonts and are what the site already loads.

## Clear space and minimum size

Keep clear space of at least half the mark's width on every side. Minimum legible size is
**24px**; below that the blades close up and it reads as a solid hexagon.
