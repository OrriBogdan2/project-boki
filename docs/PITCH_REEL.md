# Pitch reel capture rig

Raw demo-reel footage played by scripts, 1920x1080 at 60 fps, from the newest trusted build. Game side: `tools/pitch_reel.gd`
(the recorder and the raid shots) and `tools/pitch_reel_farm.gd` (the farm shots), flag `--pitch-reel`. Tool side:
`pitch-reel` in boki-tools (build tree, GPU job, encode, checks, contact sheet, INDEX).

## Run
```
pitch-reel [--build REF] [--shots 1,2,4,6,8] [--takes N] [--hunter ID]
pitch-reel --when-live [--build REF]
```
`--when-live` is the full list (table below) once the new models are in a build. Output:
`~/meshy/pitch-reel/<stamp>/shot<N>_take<K>.mp4`, `contact.jpg`, `INDEX.md`.

## How a game shot is filmed
- One GPU job (`jobq submit --needs gpu`, Vulkan) runs `godot -- --pitch-reel --shots=<list> --takes=<n> --shots-dir=reel`.
  For each shot and take it starts a child Godot under the movie writer (`--write-movie`, `--fixed-fps 60`,
  `--rendering-driver vulkan`, 1920x1080): the writer hands the game exactly 1/60 s a frame, so the footage is smooth and
  looks real-time whatever the worker's speed. V-Sync is on. Recording mode "clean HUD" hides every debug overlay and tip.
- A child writes `shot<N>_take<K>.avi` (MJPEG, quality 0.85) and `.marks` (`PITCH_MARK <part> movie_frame=<n>`, then the
  first 300 lines of its log; a filter keeps its output small, one GPU child printed over 2 GB): the
  encoder starts each clip at its first mark, so the loading before the drop and the title are cut.
- The tool encodes H.264 (CRF 17, +faststart) and checks each clip: 1920x1080, 60 fps, black and frozen stretches.
  Debug text, FPS counters and watermarks are checked by eye on the frames.
- A shot a build cannot show (shot 3 until a form has art) prints `PITCH_FAIL`, exits 1 and is left out of the index.
- `godot --headless --path . -- --pitch-check` plays shots 2, 3, 6, 7 and 10 without the movie writer (a few minutes on
  a CPU box), so a game change that breaks a driver shows before a GPU job is spent on it.

## Shots
| # | Shot | Takes (full list) | Who | Driver |
|---|---|---|---|---|
| 1 | Website scroll, Bokidex 4 entries | 1 | agent | `web_shot.py`: headless Chromium, frame-stepped, 30 s |
| 2 | Egg hatch, reveal held | 3 | agent | real hatch screen, scripted knocks; takes pick other eggs |
| 3 | Evolution T1 -> T2 | 2 | agent | farm: a Boki one level short, the farm's own evolution scene; when the demo roster has no line with art, its first Boki becomes a species that has one |
| 4 | Farm loop, 60 s | 1 | agent | care preset: trough, pat, fetch, brush, drill pressed in the gold |
| 5 | Build process, 20 s | 1 | agent | `term_shot.py`: four terminal tiles, output scrubbed (emails, tokens, home paths, names in remotes) |
| 6 | Hunter select, 15 s | 1 | agent | the Hunters screen steps through all 12, lands on `--hunter` (default gunslinger) and picks it (the screen stays up) |
| 7 | Hunter kit | 5 | owner hands best; scripted backup | 1v1 vs a bot 4.5 m away on ground with no void within 10 m (the Hunter walks back when its dashes carry it off), attack held, right click, utility on a rota; each take another Hunter (or `--hunter`) |
| 8 | Extraction drop | 2 | agent | the real loading screen and drop; loading cut at the `drop` mark |
| 9 | Loot + fight, 3 min | 3 | owner / bot backup | autoplay match of three duos, no drop |
| 10 | Escape | 3 | owner / scripted backup | a Hunter at an uplink yard as it finishes charging walks in and rides out |

Shots 7, 9 and 10 are backups: the scripted Hunter plays plainly, so cut dumb bot moments and any death in the edit.
Takes differ by seed (egg, map roll, Hunter, foe).

## Limits
- Needs a GPU worker with a Vulkan display; the queue on `--needs gpu` can be hours long.
- Shot 3 needs a Boki species whose level evolution has art: on origin/main 53e2fe7f3 only caecilith and wisplet (T2) have
  art and their T1 forms (zipling, mothlet) are not Boki species yet, so shot 3 waits for the new models.
- Shots 7, 9 and 10 ran once on a real GPU (backups); shot 9 may not meet a fight in its 3 minutes.
- If the models land before this branch is merged, the tool applies the branch's diff to the build it films.
