# Concordance

**A launcher for macOS that finds things by what they mean.**

Press a shortcut, describe what you're looking for — *"the invoice for the tyres"*, *"a photo of a person"*, *"turn
off the sound"* — and Concordance returns it: an app, a setting, a command, a document, a screenshot. It runs
[EmbeddingGemma 2](https://huggingface.co/EverPaper/embeddinggemma-2-coreai) on your Mac's Neural Engine through
Apple's Core AI. Everything stays on this computer.

Concordance is a sibling of [Everpaper](https://everpaper.app) — the private daybook of your work and meetings — and
borrows its palette, its type and its embedding model. **Want more like this? Check
[everpaper.app](https://everpaper.app) as well.**

![macOS 27](https://img.shields.io/badge/macOS-27-black) ![Apple silicon](https://img.shields.io/badge/Apple-silicon-black) ![License](https://img.shields.io/badge/license-Apache--2.0-green)

## How it works

1. **Type what you want, not what it's called.** Concordance mixes ordinary name matching with meaning: your query
   and every item on your Mac become points in one shared space (768 dimensions, text and images alike), and a
   result wins by standing out for *this* query — see *Ranking* below.
2. **It searches** applications, ~40 System Settings panes, built-in commands (Lock, Sleep, Empty Trash, Dark Mode,
   Mute, Eject, Screenshot, Restart/Shut Down/Log Out), files and folders with their contents (text, code, PDF,
   Word/RTF), images and screenshots through the vision encoder, and your clipboard history. There is an inline
   calculator and a web-search fallback.
3. **Everything is local.** The index lives in `~/Library/Application Support/Concordance/`. Nothing you search or
   index leaves the Mac; the model downloads once, from Hugging Face, with every file SHA-256-checked.

## Ranking

Raw similarity scores don't work here: in EmbeddingGemma's space every item scores 0.5–0.6 against every query, and
a handful of "hub" files score high against everything. Concordance's semantic score instead:

- measures each item against the item's *own* baseline over 40 unrelated probe queries (hubness correction), then
- z-scores it against the rest of the catalog for the current query, separately for images and text, and
- keeps only items above z ≈ 3.3, ranking them with a soft saturation that preserves order among strong matches.

On top of that: the higher of lexical and semantic scores, a small bonus per kind, frecency, and recency.
`concordance-cli cosines "a logo"` prints the numbers behind a query.

## Install

Download **Concordance-…-macOS-arm64.dmg** from [Releases](../../releases), open it, and drag the app to
Applications. (A zip of the same notarized app is there too, for scripted installs.) macOS will ask once for Desktop,
Documents and Downloads access. The first launch opens a short setup: it fetches the model (≈1 GB, one time),
prepares it for your Neural Engine (a few minutes, once per Mac), helps you pick a free shortcut, and lets you
choose which folders to index. [Everpaper](https://everpaper.app) users: Concordance notices when its sibling is
installed.

Requirements: macOS 27 on Apple silicon.

## Build from source

```sh
scripts/fetch-model.sh          # model + Swift package (~1.2 GB, git-ignored)
scripts/build-app.sh --run      # build, sign with a local identity, launch
```

Or with Xcode: `open Package.swift`. The CLI shares the app's index and ranking:

```sh
swift build -c release --product concordance-cli
.build/release/concordance-cli query "a photo of a person"
.build/release/concordance-cli cosines "a logo"
```

## Keyboard

| Key | Action |
|---|---|
| ⌥⇧Space (configurable) | Open the launcher anywhere |
| ↑ ↓ or ⌃N ⌃P | Move through results |
| ↵ | Open · ⌘↵ reveals in Finder |
| Esc | Clear, then close |

## What Concordance is not

It is not a port of Raycast's extension ecosystem: no store, no extensions, no window management, no snippets, no
AI chat. It is the *search* part, done with meaning, privately.

## Credits

- [EmbeddingGemma 2](https://huggingface.co/google/embeddinggemma-2) by Google, converted to Apple's Core AI by
  [Everpaper](https://huggingface.co/EverPaper) — the text, vision and audio encoders in one 768-d space.
- Palette and type: [Everpaper](https://everpaper.app)'s "Daybook" design language (Newsreader and iA Writer Mono,
  both SIL OFL; licenses in the app bundle).
- Icon: paper, fold and ribbon reinterpreted as a magnifying glass — a tribute to Everpaper's mark.

Apache-2.0. Concordance is an independent open-source project by the author of Everpaper.
