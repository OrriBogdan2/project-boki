# Contributing and licensing

Project Boki is open source. The full rules are in the repo root: `CONTRIBUTING.md`, `LICENSE`,
`LICENSE-ASSETS`, `NOTICE` and `CLA.md`. This page is the summary; where they differ, those files win.

## What is licensed how

| What | License |
|---|---|
| Code: GDScript, shaders, `tools/` scripts, and the code that builds models, sounds and music | GNU GPL v3 (`LICENSE`) |
| Game data: `content/` (Boki, abilities, rules, items), `translations/` | GNU GPL v3. Community Boki designs live here and stay open |
| Assets: `art/` (except `art/vendor/`), `audio/`, and future key art, logos, textures, meshes, animations and recorded or composed audio | Project Boki Asset License (`LICENSE-ASSETS`), for versions published from Nov 1, 2026 |
| `art/vendor/` (KayKit packs) | CC0 1.0 |
| `fonts/` (Lilita One, Rubik, Noto Sans Symbols 2) | SIL Open Font License 1.1 |
| The name "Project Boki" and its logo | Not licensed; forks use their own name and branding |

Everything published before Nov 1, 2026, assets included, stays available under the GPL v3 in those
versions. Hunters, Boki, gear and bosses are built by GPL code, so their look is part of the code.
Generated audio comes from GPL generators: anyone can regenerate similar sounds, but our files
themselves can't be redistributed outside the official game.

**The asset license in short:** use the assets in official builds, while developing contributions,
and in fan content (videos, streams, guides, fan art, mods and Boki designs for the official game) as
long as it isn't sold as a standalone product and doesn't claim to be official. Don't redistribute
them outside the official build or repo (forks included), don't sell them, and don't use the name or
logo to suggest a fork is official. A distributed fork must replace the art, audio and branding.
(`LICENSE-ASSETS` is a draft pending legal review.)

## The CLA

Before your first pull request is merged, agree to the Contributor License Agreement (`CLA.md`) by
adding `I agree to the Project Boki CLA` to the pull request description. You keep your copyright and
grant the project owner a broad license (including to relicense), so the code/asset split can be kept
and adjusted. Without a signed CLA, only GPL code can be accepted: no art or audio. (`CLA.md` is also a
draft pending legal review.)

## How to contribute

1. Fork the repo, install Godot 4.6.2 stable (standard build), import `project.godot`.
2. Branch, keep each pull request to one thing (one Boki, one fix, one feature).
3. Run the checks: `--check` and `--simtest --seed=5`, plus `--grammar-check` if you touched Boki or
   abilities (see [Checks](Checks.md)). If you changed data the wiki shows, run `python3 tools/gen_wiki.py`.
4. Open a pull request against `main`: what it changes, how you tested it, a clip or screenshot for
   anything visible. Use the issue templates for bugs, features and Boki ideas.

Most content (Boki, abilities, items, maps) is JSON under `content/`: see `CONTENT.md` and
`docs/KIN_GRAMMAR.md`.

## Rules

- **No assets from other games.** No models, textures, sounds, music or data files taken from SUPERVIVE
  or any other game. Reference values from public sources (wikis, patch notes, measured footage) are
  fine and go in `docs/`. Mechanics may be inspired by other games ([Inspirations](Inspirations.md));
  names, art, sound and text must be our own.
- **Only add assets you have the right to share**, and list third-party ones in `docs/ASSET_CREDITS.md`.
- **Boki definitions are data, never script**, so community content can't run code on players' machines.
- **No selling power.** Boki and Boki power are never sold. Don't add anything that does.
- Be decent to each other.
