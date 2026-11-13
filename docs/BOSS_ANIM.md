# Boss animation (scripts/match/boss_anim.gd)

Each lair boss (colossus, serpent, brood) has keyed moves for every state: sleep, wake, idle, walk, stagger, phase change and death, plus a `<attack>_windup` and `<attack>_strike` for each attack. `Boss.render` calls `BossAnim.pose()` once a frame.

- **Wind-up = the tell.** A wind-up move runs 0..1 over `BossAnim.hit_t(boss)`, the seconds the ground telegraph takes to fill, so the body has gathered the frame the tell is full. The strike move starts on that frame (a step in `Boss.steps` fires the blow there). `--boss-anim-check` asserts both against the live attack code, enraged and not.
- **Overhead camera.** The match camera looks almost straight down, so the big moves also turn (`ry`), swell (`s`) and shift (`pz`); lean and rise alone barely show.
- **Colossus** is a rigged pack model: its moves also pick the clip and which stretch plays (`CLIP`); the wind-up stops on the clip's own hit frame. Serpent and brood are posed pivots; the serpent's coils still follow `Boss.trail`.
- **Death** runs `DEATH_S`, then the body holds its last pose until `Boss.DEATH_FADE_S` (the shared dissolve, ext/vfx-mob-death, replaces that fade when merged).
- Not synced: `atk`, `dormant` and `phase` do not travel over Net, so a remote client's boss shows idle, walk, stagger and death only.
- Checks: `--boss-anim-check`; GPU strips: `--boss-anim-shots --boss=<id> --shots-dir=<dir>` through `jobq submit --needs gpu`.
