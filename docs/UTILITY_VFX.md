# Belt item looks

Every belt item (`content/utility/*.json`) has a look that says, at the match camera, **where it works, what it
does to whoever it touches, and when it ends**. Parity: the source's readability (docs/SOURCE_UTILITIES.md), our own
shapes. A ground ring is drawn only where the area is gameplay (briefs/DECISIONS.md); nothing explodes unless the item
does (Shatter Charge, Skyfall Charge).

- **Data:** `content/vfx/belt/utility.json`. `"items"`: one entry per id with `area`, `does`, `ends` (the table below is
  that text). `"moves"`: HeroVfx recipes (docs/HERO_VFX.md layers, same caps) named `<id>` (used), `<id>_hit` (on
  each body or spot it acts on), `<id>_hold` (worn by a body while it lasts, particles only), `<id>_end` (it stops).
  No palette: colours are hex, or `"side"` for the body's colour as the viewer sees it (SideColor: you, ally, rival).
- **Moments:** `UtilityVfx` (`scripts/match/utility_vfx.gd`) plays them through the pooled HeroVfx (LOD, particle
  budget, quality preset, allies at `ALLY_K`, the shared cel pass). `used(h, id)` from UtilityUse, `play(h, id, "hit"/"end", at)`
  from the item code, `wear(x, id, secs, keep)` for a mark that follows a body until the effect ends. Local: each game
  plays them from its own sim (no Net change).
- **Ground looks that last:** `UtilityLook` (`scripts/match/utility_look.gd`): Skyfall fuse (fill + warhead on match
  time), Blight Flask edge, Twin Gate portals and link, Thorn Wall spikes, Warp Seed anomaly, Lookout Lantern watch
  ring, Toss Satchel bag, Bounty Banner flag. Each hangs on the node the game frees when the item ends.
- **Checks:** `--utility-vfx-check` (every id has an entry and its moments; each item used for real plays every moment,
  its ground look is up while it works and gone after, worn marks end with the effect; "side" reads you / rival).
  `--utility-vfx-shots --shots-dir=<dir>` (GPU, `jobq submit --needs gpu`): one shot of each item in use + captions.
- **Readable at the match camera:** a `_hold` that marks a body runs at the Hero kits' density (about 20 motes over a
  0.5-0.7 m disc, or a few 0.16 m stars); the first takes (3 to 8 motes of 5 cm) vanished at that distance.

| id | area | does | ends | moments |
|---|---|---|---|---|
| `tonic` | self: the drinker, rising green motes while they drink | heals the drinker 42 after a 1 s open drink | a green flash as the heal lands; the motes stop if a hit spills it | use, hit, hold |
| `deep_draught` | self: the drinker, slow blue drops and motes for the 5 s drink | heals the drinker to full; they crawl while drinking | a big blue flash at full health; the drops stop if a hit spills it | use, hit, hold |
| `lostway_scroll` | self: pages turn round the reader for the 4 s read | sends the reader to a random spot on the map | a lilac ghost where they stood and a flash where they land (_put); the pages stop if a hit spills it | use, hit, hold |
| `omen_draught` | self while drinking; then a ring pulses on each Blight Warden for the squad | shows the drinker's squad every Blight Warden for 30 s | the warden rings stop pulsing after 30 s | use, hit, hold |
| `armor_kit` | self: steel sparks round the body for the 1.6 s repair | repairs the user's armor; they are open and slow while repairing | a white-steel flash as the armor comes back; the sparks stop if a hit spills it | use, hit, hold |
| `medkit` | self: one green rise | heals 40 and adds 20 armor at once | at once: the rise is the whole of it | use |
| `smoke` | the cloud itself (3.6 m, the gameplay edge of who it hides) | hides everyone inside it | the cloud shrinks away over its last second (8 s) | use |
| `jump_pad` | the pad (its top sits low until it arms after 2 s, then pulses) | launches whoever steps on it, keeping their speed | it blinks for its last 1.5 s (30 s, or 10 s after its first launch), then a puff | use, hit, end |
| `gust_fan` | the fan pad (its top pulses while it stands) | throws whoever steps on it high up and along | it blinks for its last 1.5 s (60 s), then a puff | use, hit, end |
| `hawk_whistle` | its reach (120 m) flashes once as a ring round the user; each rival found wears a mark | shows every rival in reach for 4 s | the mark over each rival goes when the 4 s reveal ends | use, hold, end |
| `scanner` | its reach (26 m) flashes once as a ring round the user; each rival found wears a mark | shows every rival within 26 m for 3 s | the mark over each rival goes when the 3 s reveal ends | use, hold, end |
| `lookout_lantern` | the lantern totem and a faint ring in the owner's colour at its 14 m watch edge (gameplay) | shows every rival inside the ring; a rival inside wears a mark | the totem shrinks away after 60 s, with a puff | use, hold, end |
| `toss_satchel` | the satchel sitting in its 1.4 m patch (gameplay: step in to take it) | the first hurt body to step in heals 60% of its health over 5 s (a hit stops it) | taken: a green rise and the patch shrinks; untaken it shrinks away after 30 s | use, hit, end |
| `twin_gate` | two upright portals, their 2 m patches (gameplay) and a lit link between them | after 8 s everyone in each patch swaps to the other | a lilac ghost where each body stood, a flash where it lands, and both portals close with a flash | use, hit, end |
| `warp_seed` | the anomaly over its 1.6 m patch (gameplay) | a body that stays in it 1.5 s is thrown to a random spot; while held, lilac motes pull in round it | the anomaly shrinks away after 30 s | use, hit, hold, end |
| `bounty_banner` | a flag on a tall pole over the carrier, seen by everyone, and their 1 m ring | shows the carrier to every rival for 2 min; live through it and the squad returns, plus gems | the flag goes with a burst of gold coins (kept) or a red puff (fell) | use, end |
| `pilfer_pouch` | a 4 m ring at the aim (gameplay) | takes half the gems of every rival inside; coins fly off each one robbed | at once: the ring flashes and fades | use, hit |
| `hearth_lamp` | the lamp beacon where it is set (its own model and 3 m ring, Beacons) | stands a revive beacon your squad can use | it stays until a squad uses it; the beacon's own look shows the revive | use |
| `revive_ember` | the beacon it lights at your feet (Beacons) | wakes every fallen squadmate where you stand | at once: the beacon's revive look plays | use |
| `chest_key` | the chest it opens (or a ping on the nearest locked one) | opens a locked chest beside you | at once: a gold glint at the lock, then the chest's own opening | use |
| `blight_flask` | the patch (4.5 m, gameplay) with a dark band and lime bubbles at its edge | hurts the rivals inside while it lasts | the patch shrinks away after 25 s | use |
| `cloud_raft` | the raft of cloud tiles itself | makes walkable ground over the void for 30 s | it blinks for its last 1.5 s, then drops away | use |
| `shatter_charge` | a 3 m ring where it bursts (gameplay) | a charge that bursts and hurts the rivals in it (it truly explodes) | at once: the burst | use |
| `shield_cell` | the user's shield shell (ShieldLook) | shields the user for 8 s | the shell goes when the shield breaks or runs out | use |
| `skyfall_charge` | a 6 m ring at the aim that fills, a hot disc and a falling warhead (gameplay) | after the 5 s fuse it blasts the rivals inside (it truly explodes) | the fill reaches the rim as the warhead lands; the ring goes after the blast | use |
| `stim` | self: speed streaks at the feet while it runs | makes the user faster for 6 s | the streaks stop when the haste ends, with a last puff | use, hold, end |
| `thorn_wall` | the wall with spikes along the top and out of both faces | blocks the way for 20 s | it goes after 20 s | use |
