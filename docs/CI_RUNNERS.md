# CI runners and the public releases repo

The source repo goes private. Two things depend on that: Actions minutes (pr-checks, release and itch ran about 3,100
runner-minutes on 11-27; GitHub Pro includes 3,000 a MONTH) and anything that read the repo anonymously (player auto-update).

## Where the workflows run
`pr-checks.yml`, `release.yml` and `itch.yml` use
`runs-on: ${{ vars.RUNNER == 'self-hosted' && fromJSON('["self-hosted","linux","boki"]') || 'ubuntu-latest' }}`.
Repo variable `RUNNER` unset (or anything but `self-hosted`) = GitHub-hosted, as before. `RUNNER=self-hosted` = our Linux
runners (labels `self-hosted,linux,boki`), installed by `runner-setup.sh` (coordinator, coord/private-repo) as user `boki`, user-level systemd, no sudo.
Self-hosted runners are registered only after the repo is private: on a public repo a fork PR would run code on our boxes.

Both kinds of runner use the same steps, so nothing else changes:
- `tools/ci/ci_env.sh [--templates]` installs Godot (and export templates) into `~/.cache/boki-ci` (flock'd, shared by the
  runners on one box), puts it first on PATH (ahead of any `godot` wrapper on the box), and gives the job its own
  `XDG_DATA_HOME`. It never needs sudo and never touches the box user's `~/.local/share/godot`.
- `tools/ci/shim/unzip` stands in for `unzip` on boxes without it; `tools/ci/zipdir.py` replaces `zip`.
- `tools/check.sh` falls back to `uv venv` when `python3 -m venv` is unavailable (no `python3-venv` package).
- Self-hosted keeps the lint venv per runner (`BOKI_LINT_VENV`), the cache steps run on GitHub-hosted only.

## Releases repo
`release.yml` publishes every release to this repo only. `ship-release.sh` (hetzner, box gh auth, no extra secret or token)
then mirrors the release assets to the public repo `OrriBogdan2/project-boki-releases` (builds only, no source), so Actions needs
no cross-repo token. A release made without ship-release.sh must be mirrored by hand with `gh release download` + `gh release create -R`.
`launcher/launcher_config.json` and `launcher.gd` read the latest
release from there (`cfg["repo"]`), and `deploy/setup_server.sh` / the relay `update.sh` do too. `setup_server.sh` is attached
to each release so `curl .../releases/latest/download/setup_server.sh | bash` keeps working.
Launchers already in players' hands still point at the old repo: they cannot update once it is private. Players need the new
launcher once (itch page or the releases repo).
