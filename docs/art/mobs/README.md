# Enemy mob art pass, step 1: design sheets (2026-11-10)

**Gate:** design cards, spec and prompts only. No image gens or Meshy spend for mobs until the owner approves hunters, then mobs (briefs/DECISIONS.md 2026-11-09). No game code changed.

## Files
- `TURNAROUND_SPEC.md`: the one sheet format (canvas, views, line/shade, mob world rules, post step, prompt blocks, refs, checks). Read first.
- One card per mob, each with design card + turnaround prompt card: `skitter.md`, `spitter.md`, `brute.md`, `warden.md`, `bomber.md`, `sentinel.md`, `glimmer.md`.
- `renders/<mob>_views.png`: the current Godot models, front | 3/4 | side | back (from the mob gallery's model build, flat light, 1024 x 256).
- `renders/match_far.png`: all 7 at the match camera (0,30,20), fov 35, on the meadow floor. `renders/lineup.png`: closer lineup for size comparison.

## The 7 directions (one line each)
| Mob | Direction | Keywords | Size |
|---|---|---|---|
| Skitter | "Thornback": low arrowhead beetle, forward ram horn, six splayed legs; rears and lunges | wedge, splayed, barbed | 0.45 H |
| Spitter | the only tall-thin mob: teardrop pod on an S-coiled stalk over a root base; coils back, throat glows | teardrop, coiled, rooted | 0.75 H |
| Brute | "Stonehide": top-heavy trapezoid, sunken head, stone-club fists; fists up, cracks glow | trapezoid, slab, sunken | 1.15 H |
| The Watcher | full redesign: walking stone gate, one chest eye, crown-ring of 5 gold-banded standing stones | monolithic, crowned, gate | 1.7 H |
| Puffbomb | puffer-toad whose belly sac is the bomb, ember vents instead of a fuse; inflates 1.5x | round, swelling, spiked | 0.5 H |
| Sentinel | living rune-obelisk that leans toward its aim, one crystal eye, three shard fins | vertical, faceted, aimed | 0.85 H |
| Glimmerkin | cream treasure critter with crystal-spike ears and a gem saddle; friendly eyes, flees | round, glittering, skittish | 0.55 H |

Silhouette families are all different: arrow (skitter), stalk (spitter), trapezoid (brute), tall gate + halo (Watcher), ball on legs (bomber), leaning column (sentinel), ball with spikes up (Glimmerkin). Sizes are estimated from the gallery; re-measure before modelling.

## Weakest now
1. **The Watcher (warden):** a recoloured brute, same silhouette; the champion does not read as a champion.
2. **Sentinel:** rotationally symmetric stone tower with no facing; reads as a prop.

Runner-up: Glimmerkin (IP risk: round, yellow, long ears). Puffbomb also has IP risk (round bomb with a lit fuse); both are fixed in their cards.

## What the current renders show
- At match zoom all 7 already separate by size and colour; the dark legs and masses carry them against the lime meadow. Keep that: every redesign keeps a large dark mass on the silhouette (spec section 4).
- Skitter and Glimmerkin are glossy; the canon is matte. Spitter's maw is only visible from the front. Brute's pale belly is its biggest shape.

## SUPERVIVE PvE study (function and readability only; no designs, names or art)
Sources: supervive.wiki.gg/wiki/Creeps (flagged outdated by the wiki), sportskeeda.com "how to farm monsters in Supervive" and "11 beginner tips".
- **Camps, not wanderers:** a camp is about 3 small creatures plus 1 elite, themed per biome, respawning on a timer. The camp reads as one unit from far away; the elite is the visual anchor (larger, distinct).
- **Clear threat tiers:** small creeps, elites, biome leaders (mini-bosses), soul/major bosses. Each tier step is a clear jump in size and silhouette, so players judge a fight before committing.
- **Stagger window:** elites and bosses periodically become weak and take big bonus damage; the cue sits on the creature and is very loud. Ours already does this (purple ring + stars, x2.5) on brute, sentinel, Glimmerkin, Watcher.
- **Ground telegraphs carry the danger;** creature bodies carry identity. Bodies stay readable but quieter than hunters and ability effects, so PvP never gets lost in PvE.
- **Shared world:** creeps are farmed and also used as bait/cover between teams. Mobs must never be mistaken for hunters: no humanoid mobs, no hunter-like colours.

What we take: camp structure, tier jumps by size, loud stagger cue, quiet bodies. What we do not take: any creature design, name, colour scheme or art.

## Proposed extra or different archetypes (one-line reason each)
- **Bulwark** (shield-front armoured crawler, weak at the back): the roster has no positioning test; rewards flanking and teamwork.
- **Burrower** (ambusher under the floor, ring telegraph before it erupts): nothing threatens a hunter who stands still in a "safe" spot.
- **Mender** (camp totem that heals or shields its camp): gives a focus-fire priority read inside a camp.
- **Swooper** (low flyer with a line dive): every mob is ground-bound; a dive adds a vertical read without new tech beyond the volley rect.
- **Splitter** (optional; dies into 2 to 3 skitter-sized pieces): rewards area damage and makes the skitter family a mini-tier.
- **Camp rule:** build camps as 3 smalls + 1 elite (brute or sentinel) of one biome theme, so a camp reads as one unit at match zoom.

## Alternatives noted (decided without waiting)
- Finish: flat cel (STYLE_CANON_V2) rather than the hunters' painted finish, so mobs never need a restyle; only `MOB_RENDER` changes if the owner wants painted.
- Scale column and palette strip are drawn locally after the gen, not by the model (models garble text and swatches).
- Glimmerkin body fixed cream instead of biome-repainted (needs a small code change later, outside this job).
