# Expedition pick screen, simplified (owner 11-08)

Before/after at 1920x1080 and 2560x1440, fresh save (Vex open, 11 locked) and all Hunters open.
Files: `before_<h>_<fresh|all>.jpg`, `after_<h>_<fresh|all>.jpg`. Rendered with `--expedition-shots=<dir>`
(local xvfb/opengl3: the GPU queue was 16 deep and stalled; a `jobq --needs gpu` job was also submitted).

| item | status | what I tested |
|---|---|---|
| Remove ability strip, signature weapon, stat line from the expedition panel | done | class-unlock check asserts no LMB/RMB text; arena check asserts no `KitCard.strip(`; shots |
| Hunter cards: portrait, name (not title), role, big targets | done | shots at 1080p and 1440p, fresh and all-open |
| Locked Hunters: desaturated, lock icon, not selectable, how-to-unlock on hover | done | class-unlock check: locked cards' tooltip == requirement, no pick callback; shots |
| Ability explanations kept on hunter screen, codex, tutorial | done | KitCard code untouched; arena check 102/0 |
| One clear call to action | done | Start expedition is the only primary |
| Tuning file | n/a | no movement/feel numbers; UI sizes are named consts |
