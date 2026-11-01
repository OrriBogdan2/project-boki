# Contributing to Project Boki

Project Boki is open source and built in the open. Anyone can fork it, mod it, and send changes back.

## Getting set up

1. Fork this repo (button at the top right on GitHub), then clone your fork.
2. Install **Godot 4.6.2 stable, standard build** (not .NET). Use exactly this version: a different one re-saves the project files and makes diffs noisy.
3. In Godot, choose **Import**, pick `project.godot`, and press **F5**.

## What you can work on

- **New kin, abilities, items and maps.** Most content is plain JSON under `content/`, no code needed. See [CONTENT.md](CONTENT.md) and [docs/KIN_GRAMMAR.md](docs/KIN_GRAMMAR.md).
- **Bugs and feel.** Combat, movement, camera, netcode. Check the open issues first.
- **Art and audio.** Original work only (see the rules below).

Not sure where to start? Look for issues labelled `good first issue`, or ask in the Discord.

## How to send a change

1. Make a branch on your fork: `git checkout -b my-change`.
2. Keep each pull request to one thing (one kin, one fix, one feature).
3. Run the checks before you push:
   ```
   godot --headless --path . -- --check            # compile every script
   godot --headless --path . -- --simtest --seed=5  # a whole match on autopilot
   godot --headless --path . -- --mapcheck          # map generation sanity check
   ```
   If you touched kin or abilities, also run `godot --headless --path . -- --grammar-check`.
4. Open a pull request against `main` and say what it changes and how you tested it. A short clip or screenshot helps for anything you can see in game.

## Rules

- **No assets from other games.** No models, textures, sounds, music or data files ripped from Supervive or any other commercial game. Pull requests with them get closed. Reference values gathered from public sources (wiki, patch notes, measured footage) are fine, and go in `docs/`.
- **Only add assets you have the right to share.** Your own work, or assets with a license that allows it (CC0, CC-BY, OFL, etc.). Add anything third-party to [docs/ASSET_CREDITS.md](docs/ASSET_CREDITS.md) with its source and license.
- **Kin definitions are data, never script.** Kin and ability files must stay pure JSON so community content can't run code on players' machines.
- **No selling power.** Kinfall will never sell kin or kin power. Don't add anything that does.
- Be decent to each other.

## License

Project Boki's **code and game data are licensed under the [GNU GPL v3](LICENSE)**. Forks are welcome, and forks you share have to stay open source under the GPL too.

**Art, audio, music and branding are under the [Project Boki Asset License](LICENSE-ASSETS)** for versions published from Nov 1, 2026: they can be used in official builds and fan content, but a distributed fork must ship its own art, audio and name. [NOTICE](NOTICE) lists exactly which files fall under which license. Third-party assets in `art/vendor/` (CC0) and `fonts/` (OFL) keep their own licenses.

**Contributor License Agreement.** Before your first pull request is merged, please agree to the [CLA](CLA.md) (add "I agree to the Project Boki CLA" to the pull request). It lets the project keep this code/asset split. Without it we can only accept code under the GPL v3, and can't accept art or audio.
