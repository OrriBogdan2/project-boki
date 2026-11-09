# Build and ship

## Godot version

**Godot 4.6.2 stable, standard build (not .NET).** Use exactly this version: another one re-saves
project files and makes diffs noisy, and the owner keeps copies on a Windows PC and a MacBook. The
renderer is Forward+ on desktop and Compatibility on mobile and web (`project.godot`).

For headless work in the build container, the binary is
`/home/claude/godot/Godot_v4.6.2-stable_linux.x86_64` (a copy for quick runs lives in
`/home/claude/gq`). Give each run its own `XDG_DATA_HOME` temp dir so runs don't share a shader cache
or user data:

```
XDG_DATA_HOME=$(mktemp -d) godot --headless --path . -- --check
```

After pulling changes that add scripts or resources, run `godot --headless --import` once so the
class cache and `.uid` files are up to date.

## Branches and worktrees

Work happens on feature branches, each in its own git worktree next to the main checkout, so
several agents or people can build and test at once without stepping on each other:

```
cd /home/claude/kinfall-integ36
git worktree add -b <branch> ../kinfall-<branch> <base>
```

- `main` is what ships; it lives in `/home/claude/kinfall-godot` and is pushed to
  `OrriBogdan2/project-boki`.
- `integNN` branches are integration branches: main plus the feature branches being merged together
  for the next build (`integ36`: main plus the newest Thief and Juggernaut kits and abyss/Boki tweaks).
- `ux-pass` (worktree `kinfall-ux`) is the staging branch that ship.sh fast-forwards before main.
- `design` holds design documents that aren't built yet (see [Design docs](Design-Docs.md)).
- Don't commit in another branch's worktree, and don't merge into `main` except through the ship step.

## ship.sh

`/home/claude/ship.sh <worktree> <branch> <syncN> [extra checks...]` (outside the repo, in the build
container) does the whole release from a feature branch:

1. Imports the project headless and commits any new `.uid` files on the branch.
2. Runs `--check`, the extra checks you passed, then `--mantle-check`, `--drop-check`,
   `--extract-check`, `--boss-check`, `--duel-check`, `--revive-check`, `--life-check`,
   `--economy-check`, `--home-build-check` and `--simtest --seed=5`, logging to `/tmp/<branch>.log`.
3. Stops with **NOT SHIPPED** if the log has any `FAIL`, `SCRIPT ERROR` or non-zero failure count.
4. Fast-forwards `ux-pass` to the branch, then `main` to `ux-pass`, and pushes `main`.
5. Exports the **Windows** and **macOS** presets to `../build/win` and `../build/mac`.
6. Puts the builds in the session's outputs folder (the Windows exe split into 20 MB parts) with a
   `kinfall-sync<N>.tgz` source archive of `main`.

`ship_only.sh <branch> <syncN>` does steps 4-6 when the checks already passed. Not in ship.sh yet:
`python3 tools/gen_wiki.py --check` (add it so a stale wiki blocks a ship).

## Export presets

`export_presets.cfg` has **Web** (`../build/web/index.html`), **Windows**
(`../build/win/ProjectBoki.exe`), **macOS** (`../build/mac/ProjectBoki.zip`) and **Linux**
(`../build/linux/ProjectBoki.x86_64`). ship.sh passes its own output paths. The web build is for
prototyping only (`tools/build_web.sh` wraps it with `tools/shell.html`).

## Releases for playtesters

`.github/workflows/release.yml` builds the game (Windows, macOS, Linux) and the launcher (Windows,
macOS) and publishes a GitHub Release when you push a `v*` tag (or run it by hand). The tag must
match `Net.VERSION` in `scripts/core/net.gd`, or the workflow fails. To ship a playtest build:

1. Bump `VERSION` in `scripts/core/net.gd` (players on different versions can't play together).
2. `git tag v<VERSION> && git push origin v<VERSION>`.

The launcher (`launcher/`) downloads the latest release (`ProjectBoki-<platform>.zip`). CI fills in
its Discord client id and server address from the repository variables `DISCORD_CLIENT_ID` and `BOKI_SERVER`.

## The relay server

`deploy/setup_server.sh` sets up the relay on a fresh Ubuntu 24.04 machine as a `boki-relay` systemd
service, with its settings in `/etc/boki/relay.env`. See [Networking](Networking.md).
