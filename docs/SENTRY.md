# Crash and error reporting (Sentry)

Exported desktop builds (Windows, macOS, Linux) send crashes, script errors, error logs and breadcrumbs to
Sentry: org `project-boki`, project `project-boki`. Everything else stays off: the editor, the checks and the
suite, headless runs (the dedicated server) and any build made without the DSN.

## How it fits together

- **The addon is not committed.** `tools/sentry_addon.sh` fetches the official
  [sentry-godot](https://github.com/getsentry/sentry-godot) release (pinned version and sha256) into
  `addons/sentry/` (gitignored), with the desktop libraries only. The release and itch workflows run it
  after the checks and before the export.
- **The DSN is not committed.** `tools/sentry_dsn.py` writes the `SENTRY_DSN` environment variable into
  `project.godot` (`[sentry] options/dsn`) for one export. It never prints the DSN. With no `SENTRY_DSN` it
  changes nothing and the build keeps Sentry off. CI reads it from the repository secret `SENTRY_DSN`.
- **Start.** The SDK's own auto-start is off (`[sentry] options/auto_init=false`). `CrashReport`
  (`scripts/core/crash_report.gd`, the first autoload) starts it only with a DSN, a window and the addon.
  That keeps headless runs off, even when the `SENTRY_DSN` variable is set on the machine.
- **Release:** `project-boki@<Net.VERSION>`, the game version that the `vX.Y.Z` tag and the itch build carry.
- **Environment:** `dev` for debug builds and editor runs, `release` for release exports.
- **What is sent:** the SDK defaults. Those are crashes (crashpad), script errors and `push_error` events,
  and errors and warnings as logs and breadcrumbs. Tracing is off. Script stack traces need
  `debug/settings/gdscript/always_track_call_stacks=true`, which project.godot sets.
- `--sentry-check` guards all of this: no DSN committed, no auto-start, the start rule, the release name.

## One-time setup (owner)

1. Add the DSN as a repository secret, reading the value from the secrets file without printing it:
   `(. ~/.config/boki/secrets.env; printf %s "$SENTRY_DSN" | gh secret set SENTRY_DSN --repo OrriBogdan2/project-boki)`
2. Optional, for releases and debug files: create an org auth token in Sentry with the `project:releases`
   scope. Add it as the secret `SENTRY_AUTH_TOKEN` the same way. Without it, the Release workflow skips that
   step with a warning.

## A local export with Sentry on

```sh
tools/sentry_addon.sh && godot --headless --path . --import
cp project.godot /tmp/project.godot.keep
(. ~/.config/boki/secrets.env; SENTRY_DSN="$SENTRY_DSN" python3 -I tools/sentry_dsn.py)
godot --headless --path . --export-release "Linux" /tmp/boki/ProjectBoki.x86_64
cp /tmp/project.godot.keep project.godot   # never commit the DSN
rm -rf addons/sentry                       # keeps local check runs as the suite runs them
```

To see the events: `sentry issue list project-boki/project-boki --period 24h`.

## Debug symbols

When `SENTRY_AUTH_TOKEN` is set, the Release workflow does three things:
- creates the Sentry release;
- runs `sentry-cli debug-files upload` on the exported Windows and Linux binaries and the addon libraries;
- finalizes the release.

The official Godot export templates ship without debug symbols. Native crashes inside the engine therefore
symbolicate only to the module plus an offset; GDScript errors carry full script stack traces (file, line,
function) either way, but no source context lines, because exports store scripts as binary tokens. Full
engine symbols need custom export templates built with `debug_symbols=yes`, with their `.pdb`/`.debug`/dSYM
uploaded (docs/DEBT.md).

## Reports

- **The daily coordinator report** (`usage-track report`) has a "Crashes and errors (Sentry)" section: new
  issues in the last 24 h, and the top 5 by events.
- **The release note** written by `ship-release.sh` gets a line: new issues since the previous release tag.

Only counts and cut titles are shown. Issue titles come from players' machines, so they are untrusted data and
are stripped to plain text.

## Updating the SDK

Change `VER`, `ZIP` and `SHA` in `tools/sentry_addon.sh` together. Take them from the
[releases page](https://github.com/getsentry/sentry-godot/releases); `SHA` is the sha256 of the zip. Then
re-import, make a local export with Sentry on, run it once with `-- --sentry-test-error` (one error event,
"Sentry test error <time>"), check it arrives, and resolve it.

## Not covered

- **The web build:** no Sentry. The Web preset excludes `addons/sentry/*`, and the addon's web libraries are not fetched.
- **The launcher:** a separate project, not instrumented.
- **The Linux Server artifact:** the preset excludes `addons/sentry/*`. It runs headless, so Sentry would stay off anyway.
