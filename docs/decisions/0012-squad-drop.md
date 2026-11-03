# 0012: A higher drop, solo freefall and the squad comet

- **Status:** accepted
- **Date:** 2026-11-03
- **Area:** match flow / movement / networking

## Problem
The opening drop is short and low (the skyship at 40 m, about 5 s down) and the squad glides down in a formation behind its leader. The owner wants a drop worth watching: high enough to see the whole Hollow Crown, about 20 s from the ship to the ground, a freefall you steer like a battle royale's (dive or float), and squads that come down together in one burning comet that anyone can break away from (MAIN_TO_EXT 2026-11-02 13:20 and 13:22).

## Options
1. Raise the ship and tune the old dive and formation numbers. Cheap, but there's no dive/float choice, the formation is invisible as a group, and the slow followers still pile up at the end.
2. A freefall model (heading, dive or float) shared by solo divers and the comet, where the comet is the jumpmaster's body with the rest of the squad riding it, replacing the formation slots.

## Decision
Option 2. `SkyFall` (scripts/match/sky_fall.gd) holds the freefall: a heading you turn with the side keys, forward (W, along your heading) dives (fast and steep), letting go floats (slower fall, longer reach), back brakes. The camera turns with your heading during the freefall, as it already did on the ship, so W stays "forward". The glider opens itself `DEPLOY_H` over the ground below (or on Space), and from then on it is the normal glide (heat, the glide-handoff momentum rules) until a landing kick (dust ring, squash, thud) and the Boki leaping off your back (`KinFollow.hop_off`). `DropSquad` keeps planning, pings, the lead and "separate", and drops the formation: the leader's jump takes the squad into a comet that the jumpmaster steers with the same controls; the others ride it (glued to the jumpmaster, inside the orb). Space or Z breaks a member away into a solo freefall, never back in. Near the ground the comet bursts and everyone still in opens a glider towards their own spot, spread round the comet's ground point on solid ground (the comet is pulled away from the abyss when it gets low). Bots pick a break-off height when they jump. `DropFx` draws the comet, its trail, divers' contrails (seen by everyone), the cloud layer, speed lines and wind.

## Consequences
- hunter.gd: the old dive/drop glider branch and constants go to SkyFall; `drop_follow`/`drop_slot`/`drop_from` are replaced by `comet_lead` (the jumpmaster you ride with) and `drop_dive`; `drop_glide` marks the glide after a drop until the landing kick. match.gd: wiring only (ship height, camera branch, the "comet"/"cburst" events); `on_drop_landed` moves to SkyFall.
- Net: new "comet" (lead, riders) and "cburst" (lead, ground point) events and a dive bit in the hunter flags: the sync shape changes, so Net.VERSION needs a bump (left as a marked TODO for main to assign).
- `--drop-check` moves out of main.gd into tools/drop_check.gd (registry) and asserts the drop height, 18-22 s for an untouched drop, dive faster than float, the auto-deploy height, the comet holding together, break-offs, the burst landing on solid ground, bots breaking off and the Net round trip. `--move-feel-check`'s drop rows follow the new constants.
