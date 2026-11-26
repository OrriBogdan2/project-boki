## Crowd control re-read: every stun, root, Ground, slow, Daze and knock effect in the 13 kits (main cc36e78ec, 2026-11-22)

Replaces the table "Crowd control" (main d255acbee, 2026-11-09). Re-measured headless by `--cc-measure-check`
(`tools/cc_measure_check.gd`): each row casts the kit's own ability on an idle dummy (a cliff behind it for a wall hit)
and reads the highest stun, root, slow (time and strength), Grounded and Daze the dummy reaches, one `CCM` line a row,
asserted against the **Ours** column to a frame and a half. Hunters by their names today (Kael was Zedran, Lace Hem,
Meeko Pip, Tenzo Tarek, Neve Claire, Motley Ostra, Sparkle Ryzz). **Source** is unchanged from the 11-09 table: the card
text gives no CC number except Motley's (Snap 0.8 to 1.8 s, Nightwell 3.5 s, orb 6% 1.5 s) and the upgrade steps; every
other source cell is a 5 fps footage read (about +-0.2 s) or only the word "Slow", "Stun", "Daze". Gil has no source.

| Hunter | Effect | Measured (ours) | 11-09 table | Verdict |
|---|---|---|---|---|
| Vex | Burr Charge cone | Daze 1.40 s, no slow | same | match |
| Vex | Burr cone into a wall | stun 0.90 s, Daze 2.0 s (1.4 + 0.6) | stun 0.7 s | **0.9, not 0.7**: the shove is a knock, and a knock into a wall at speed is the shared body slam (0.9 s floor, `Hunter.wslam_t`); the kit's own `wall_stun` 0.7 only wins when the shove is too slow to slam. Table corrected; data kept |
| Vex | Cinderfall zone | slow 30%, 0.58 s refreshed | 30%, 0.6 s | match |
| Kael | Meteor Drop core | stun 0.8 s | stun 0.8 s | match |
| Kael | Meteor Drop ring | stun 0.45 s (a knockdown), **no slow** | slow 40% 1.5 s | table stale, not a regression: the 11-10 owner spec made the air Smash a down slam that knocks down (`rmb.drop.down`); the ring slow went with it (7bb30c1afd5) |
| Kael | Chain Lunge, Haul Slam, Fireblast wave | no CC | no CC | match. A Chain Lunge stun is **not on main** (cast, 0 stun) |
| Lace | Heartpiercer into a wall | stun 1.20 s | 1.2 s | match |
| Lace | Rain of Arrows | slow 35%, 0.78 s refreshed | 35%, 0.8 s | match |
| Cinder | Cinder Shot | slow 30% 1.5 s | same | match |
| Cinder | Flue Flight carpet | slow 30%, 0.48 s refreshed | 30% 0.5 s | match |
| Meeko | Burrseed root | 1.08 s, rank 3: 1.38 s | 1.1 s, +0.3 | match |
| Tenzo | Quake Punch into a wall | stun 0.90 s | 0.9 s | match |
| Tenzo | Volcano slam centre | stun 0.47 s tap to 1.18 s full charge (full at 0.45 s) | 0.5 to 1.2 s | match |
| Tenzo | Basalt Spine | slow 35% 0.98 s | 35% 1.0 s | match |
| Tenzo | Rock Hop's rolling rock | slow 30% 1.5 s | same | match |
| Grimble | Anchor Drop | stun 1.08 s, rank 3: 1.48 s | 1.1 s (+0.1 a rank, +0.2 rank 3) | match |
| Grimble | Hook reel | foe stun 0.2 s refreshed; Grimble Grounded (up to 3.0 s, to the reel's end) | same | match |
| Neve | Ice Spear hit | slow 35% 0.78 s (**was 45%**, see Fixed) | 35% 0.6 to 0.8 s | **fixed** |
| Neve | Rink Wall touch, Shatter splinter | slow 30% 1.0 s, no slow | 30% 1 s, 30% 1.2 s | wall match; splinter slow cut since (PR #851, 11-24) |
| Neve | Rimelock | stun 0.73 s (an early crack is shorter), rink zone slow 35%, 0.18 s refreshed | 0.75 s, 35% | match |
| Motley | Shard Snap | stun 1.12 s at 5 m (0.8 to 1.8 s by flight) | 0.8 to 1.8 s | match |
| Motley | Tether Lantern orb | slow 6% 1.5 s | same | match |
| Motley | Nightwell | stun 3.47 s | 3.5 s | match |
| Albert | Crush (Shield Charge into a wall, any knock into a wall) | stun 1.00 s | 1.0 s | match |
| Albert | Faultline (ult) lane | strike stun 0.48 s, then slow 50% 1.48 s | not in the table | **added**: the table was written before the ult's riders; the 20% scar slow (10 s) is data (`x.scar_slow`), not cast |
| Albert | Shield Slam | gone (no Shield Slam in the kit) | stun 0.6 s | row retired |
| Sparkle | Storm Rod into a wall | stun 0.78 s | 0.8 s | match |
| Sparkle | Skycall | Grounded 1.5 s | 1.5 s | match |
| Sable | Bola, first foe | Grounded 1.5 s, slow 30% 1.48 s | same | match |
| Sable | Bola, a pair | stun 0.88 s, both Grounded | 0.9 s | match. A Bola wall stun is **not on main**: a lone foe against a cliff gets Ground and slow only |
| Sable | Shadow Knife | slow 50% 2.5 s | same | match |
| Gil | third thrust | slow 30% 0.5 s | not in the table | **added** |
| Gil | Ground Swim dash, E, ult | knock-up stun 0.48 s, 0.98 s, 0.98 s then slow 50% to 2.98 s (1 s up + 2 s) | not in the table | **added** |
| any | plain knock into a wall | stun 0.90 s (the shared body slam) | not in the table | **added** |

**Fixed (1).** A hit that staggers (`Oomph.react`: a big hit, a payoff, a stun) set the 45% stagger slow with
`slow_k = max(slow_k, 0.45)` whenever a slow was already running, so a heavy hit's own rider got 45% for its whole
length instead of its 35%: Neve's Ice Spear measured 0.78 s at 45%. The stagger now only sets its short 0.28 s slow when
no longer slow is running (`scripts/arch/oomph.gd`), asserted by `cc Neve: Ice Spear` (slow_k 0.35). No other row moved.

**Not cast (data only, no cheap dummy scenario):** Gil's passive stun 0.75 s (needs 3 hits in 5 s) and his Grab Bag
vials (Thunder stun 0.5 s, Slime slow 40% 1.5 s, Zeep knock-up 0.75 s); Albert's scar slow 20%.
