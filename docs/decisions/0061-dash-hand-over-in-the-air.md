# 0061: A dash hands over at run speed in the air too

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** movement

## Problem
Owner 11-11 on the release build: "a jump dash on Vex went super far". A Shift that ended in the air kept its
full speed (owner 11-08, decision 0053: "air drag bleeds it"), and `Loco.air_step` bleeds speed over the run cap at only
2/s. A 20-25 m/s dash then flew on for 5-12 m: Vex's jump dash with no charge left (the long dash) landed 18.5 m
from a high start, Gil's 19.8 m, Mage's handed over 34.8 m/s. A jump out of a ground dash kept 75% of the dash
(14 m/s for Vex), and some kits set their own speed after the dash (Bulwark's spin +6 m/s, Ashwick's poof, the
Rink Run's air end, Thief's long dash on the ground slid 6 m on).

## Options
1. Raise the air drag. Every launch, knock and pad would bleed faster too, and the dash would still overshoot.
2. End every dash the same way: `HunterMove.dash_exit` (at most the run speed) on the ground and in the air,
   with `dash_rest` so it still covers its own distance; a jump out of a dash and a kit's own end go through it.

## Decision
Option 2 (owner 11-11: "after a dash, carried-over speed is clamped to the normal max run/air speed"). The one
hand-over left is a held glider opening the step the dash ends (item 4, `dashglide_*` in --move-feel-check): the
glide's own carry rules (`glide_carry`) take that speed, as a glide pressed mid-dash already did.

## Consequences
hunter.gd +3 lines. The long dash-jump is gone: `dash.jump_keep` now only matters at a dash's slow tail.
Heroes whose air Shift is its own move (Ashwick's poof, Tender's glide, Dredge's pounce, Gil's long dash, the
Rink Run) keep their distance but hand over at run speed. `--dash-momentum-check` holds it. No Net or save change.
