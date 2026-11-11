# 0061: The drop is a squad mini rocket

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** match flow / movement / networking

## Problem
Owner 11-11: the drop showed all three hunters jumping out of the ship and gliding in a formation. The owner wants one mini rocket per squad that the leader steers (doing nothing lands the squad together), an early jump-out any member can take (a free fall slower than the rocket, the glider any time after), a higher start and a skydive camera.

## Options
1. Keep the jump-out and only restyle it: no shared ride, the formation code stays.
2. A rocket per squad launched from the skyship (`DropRocket`), riders stay `riding` inside it; jump-out reuses the existing dive and glider.

## Decision
Option 2. The skyship, the planning phase and the leader stay; the launch replaces the jump. The rocket is one small object per squad: its riders keep `riding` (not hittable) and follow its position, drawn clinging on to the hull in the shared ride pose (amended 2026-11-11, ext/anim-skydive: they were hidden). The free fall and the glider are the drop's existing dive and canopy (`Hunter.DIVE_FALL` 13 m/s vs the rocket's 24 m/s). With no keys over the abyss the rocket heads for the nearest island. `SHIP_Y` 70 -> 100 m.

## Consequences
- New `scripts/match/drop_rocket.gd`; `DropSquad` loses the formation (slots, follow, separate); `DropLaunch` and `--drop-launch-check` are deleted; `--drop-rocket-check` added.
- Online: the leader's machine (the host for a bot) flies the rocket; others follow the leader's synced position. Launch is the new `"rkt"` event (replaces `"dsep"`); jump-out and the glider ride the existing hunter flags. Net.VERSION bumped.
- Camera: `Cam.skydive` (behind the launch heading, ~50 degree pitch) for the rocket, the free fall and the glide; it turns back north-up in the last 8 m.
- No save change.
