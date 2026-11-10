# Animation quality audit

## Monsters at match zoom: every state on the body (Nov 10)

`scripts/match/mob.gd` telegraphs every attack on the ground; `mob_models.gd` sculpts the six common monsters
(the brute family includes the Watcher). Audited by reading the pivot code `Mob.render` drove before, state by state.
`ok` = a real move; `thin` = one small tweak (a lean, a flare); `static` = nothing but the shared body lean, so the
tell or the reaction did not read on the body. `n/a` = the kind cannot enter the state (no attack, never moves).

| kind | idle | walk / run | wind-up | strike | stagger | hit flinch | death |
|---|---|---|---|---|---|---|---|
| skitter | thin (legs shiver, jaw) | ok walk, run = walk | ok (jaws, legs splay) | thin (jaws only) | static | static (lean) | static (shared pop) |
| spitter | ok (leaf sway) | thin (bulb scale 3%) | ok (bulb swells, leaves lift) | thin (one tilt) | static | thin (leaves) | static |
| brute / warden | ok (breath, head turn) | ok walk, run = walk | ok (fists overhead) | ok (arms slam) | static | static | static |
| puffbomb | thin (hops while still) | ok | ok (swell, flap) | n/a (it bursts: death) | static | static | static |
| sentinel | ok (crystal spins) | n/a (shoves only: static) | ok (spin up) | static (spin just stops) | static | static | static |
| glimmerkin | thin (hops while still) | ok | n/a | n/a | static | static | static |

Cross-cutting gaps: **stagger and hit flinch were the shared lean for every kind** (nothing on the limbs, jaws, leaves or
crystal), **death was one swell-and-flatten for every kind**, **run was the walk**, and the **strike had no follow-through
on four of five attacking kinds**.

### What changed

`scripts/match/mob_anim.gd` (`MobAnim`) holds keyed moves per kind and state (tracks of pivots, channel and keys, baked
once into 32-sample curves), and `Mob.render` calls `MobAnim.pose` instead of the per-kind `match` block it replaces.
Every kind now has the table below; `check` runs on all of it.

| state | what plays | phase |
|---|---|---|
| idle | slow breathing / sway per kind, jaw chew, ear twitch, crystal spin | loop (`IDLE_S`, offset per monster) |
| walk | skitter tripod, brute stride and arm counter-swing, spitter root hop, puffbomb and glimmer bounds | gait distance (`Mob.anim`) |
| run | the walk at 1.4x amplitude (above 3.6 m/s) | same |
| wind-up | gather, coil, raise, inflate, spin up | `MobAnim.windup_k`: **the same fraction the ground telegraph fills with** |
| strike | the blow and its follow-through (jaw snap and leap, spit recoil, slam and heave, crystal kick) | blow + recovery, `RECOVER_S` |
| stagger | slack legs / drooping leaves and ears / bowed brute / dimmed crystal | loop, 2 s |
| flinch | a 0.12 s recoil along the hit flash | `FLASH_S` |
| death | per kind: legs curl, bulb wilts, brute topples, puff bursts, crystal cracks out, ears droop | `DEATH_S` (0.32 s) |

The wind-up cannot drift from the telegraph: `Mob.sim`, the proxy path (`_net_telegraph`) and `MobAnim.state_of` all use
`windup_k(st_t, windup)`, and `--mob-anim-check` steps the real sim and compares the two every frame.

### Proof

`godot -- --mob-anim-check` (registered in `tools/check_registry.gd`): every state a kind can enter has tracks that move
at least 0.02 and loops that close; every pivot named exists in the model; the wind-up fraction equals the telegraph's
shader progress on every frame, lasts the data's `windup` seconds to within one frame, and the first pivot sits on its
key at the end; 30 monsters pose in under 0.5 ms a frame. Numbers are in the commit message and the READY line.

Not covered: the old procedural models used only with `--art1` lose their per-kind wobble (they were hand-driven by the
removed block); pack-model (`.glb`) monsters keep their clips; bosses and Blight monsters have their own renderers.
