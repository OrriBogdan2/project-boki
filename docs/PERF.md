# Profiling with Tracy (opt-in, never shipped)

Owner approved 2026-11-12. The Tracy profiler is a profiling build of the same game: a small GDExtension
(`native/tracy`, class `TracyProfiler`) that exposes zone begin/end and frame marks to GDScript, plus the CLI
tools `tracy-capture` and `tracy-csvexport`. Nothing of it is in the repo's shipped content: the build output is
untracked, and every export preset excludes `perf_tracy/*` and `tools/perf/*` (`--prof-check` asserts that).

**Why our own extension:** the two known godot-tracy projects (Pineapple/GodotTracy, AndreaCatania/godot_tracy) are
engine modules, which need a custom Godot build, and the other GDExtension found (RexIturan/godot_tracy_extension,
Windows only, no releases, no docs) is not maintained. `native/tracy` is about 60 lines of C++ over Tracy's C API.

**Pins** (`tools/perf/build_tracy.sh` checks the commit): Tracy `v0.15.0` (f2a4f25), godot-cpp `godot-4.5-stable`
(e83fd09; the extension runs on Godot 4.6.x). The capture and export tools are built from the same Tracy tag,
because the client and server protocol must match.

## Build (Linux x86_64, once per machine)
`tools/perf/build_tracy.sh` clones the pinned sources into `native/tracy/deps/` (untracked), builds the extension into
`perf_tracy/` and the two tools into `tools/perf/bin/`. Needs git, g++, python3 and network. Then import once
(`godot --headless --path . --import`) so the engine lists the extension. The GPU workers must be Linux x86_64 and get
the build through `--tree` (macOS workers have no extension: the run fails with a clear error, so use `--only rp1-0`
or another Linux GPU worker).

## Zones
`Prof.begin("name")` / `Prof.end()` (`scripts/core/prof.gd`): no-ops without the extension, so the calls stay in the
shipped game at the cost of a static call each. Zones, per `Match` frame: `bots`, `hunters_sim`, `physics`
(separation, break collisions), `combat` (rings, shots), `vfx_tick` (fields, verbs, displacement), `render_entities`,
`vfx_render`, `camera`, `hud_tick`, `hud_draw`. `Prof.frame()` in `Match._process` marks the frame. A new zone is two
lines around straight-line code (an early `return` between them would leave the zone open).

## Capture (headless, real GPU)
```
jobq submit --needs gpu --only rp1-0 --tree <tree> --out bench -- --perf-bench --bench-secs=30 --bench-view=1920x1080 --quality=medium --tracy=bench
```
`--tracy=<dir>` runs only the bench's match part (3 teams of 2, ash storm, Blight, a fight at 8 s), with
`tracy-capture` recording from the running game; at the end the game stops it, and `tracy-csvexport -u` writes
`<dir>/zones.csv` (one row per zone instance) next to `match.tracy` (openable in the Tracy GUI). Then:
```
python3 tools/perf/tracy_report.py <out>/zones.csv        # top 15 by mean; --by p95, --top N, --warm S (default 3)
```
The report drops the first 3 s (shader and cache warm-up) and prints calls, mean, p95, max and total ms per zone.
Nested zones count in both, so the columns do not add up to a frame.

## Baseline
Job `20261112-083411-03383`, rp1-2 (RTX 4090, Vulkan Forward+, medium, 1920x1080), `--bench-secs=30`, Tracy v0.15.0,
first 3 s dropped. The bench's own line for the same run: match script avg 24.0 ms, process 125 ms, render cpu 5.0 ms, gpu
5.6 ms, 882 draws. Only 10 zones exist yet, so the report shows all of them (top 15 by mean):

| zone | calls | mean ms | p95 ms | max ms | total ms |
|---|---|---|---|---|---|
| hud_draw | 946 | 4.118 | 5.704 | 67.515 | 3896 |
| hunters_sim | 1799 | 2.607 | 3.604 | 33.346 | 4690 |
| render_entities | 875 | 2.501 | 3.469 | 6.739 | 2188 |
| physics | 1799 | 1.109 | 1.578 | 2.957 | 1996 |
| bots | 1799 | 1.065 | 2.080 | 11.638 | 1916 |
| camera | 875 | 0.272 | 0.353 | 1.266 | 238 |
| combat | 1799 | 0.248 | 1.100 | 5.088 | 446 |
| hud_tick | 946 | 0.111 | 0.159 | 0.271 | 105 |
| vfx_tick | 1799 | 0.035 | 0.054 | 1.629 | 63 |
| vfx_render | 875 | 0.021 | 0.052 | 0.151 | 18 |

Reading it: the HUD draw (`hud_draw`, 4.1 ms) is the largest single zone, ahead of the hunters' own simulation
(2.6 ms) and entity rendering (2.5 ms); bots (1.1 ms mean, 2.1 p95) and physics (1.1 ms) come next; combat has the
widest tail (p95 4x its mean, max 5 ms). Camera and VFX are cheap in this scene. The max column holds one-off spikes (`hud_draw` 67 ms, `hunters_sim` 33 ms) that
the 3 s warm-up cut does not remove; read mean and p95 for steady cost.

## Gotchas found on the workers
- `tracy-capture` and `-csvexport` are built without `-march=native` (`NO_ISA_EXTENSIONS`): a binary built on one
  CPU died on the rp1 workers, which looked like a heap-corruption crash in the game.
- Tracy listens on port 18086, not its default 8086, because 8086 is taken on some workers.
- Zone stacks are per thread (`thread_local` in the extension).
- A macOS worker has no Linux extension; the run stops with `TRACY: the extension is not loaded`. Use `--only rp1-<n>`.
- Earlier builds of this branch crashed on rp1-0 only (heap corruption); the last build has run on rp1-2 and passed,
  rp1-0 was not re-run.
