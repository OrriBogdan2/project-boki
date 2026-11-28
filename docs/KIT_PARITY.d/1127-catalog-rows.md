## Catalog 11-27: every gap the reference catalog lists, read against the kit code (main c78b7cba288, 2026-11-28, ext/kit-parity-catalog-rows)

Source: `/home/boki/meshy/sv-refs/source-notes/CATALOG-13-1127.md` (13 hero sections, 15 cross-hunter patterns, top 5). The catalog read
kit text only (its own caveat 2: "real tuning numbers live in game code, which I did not read"). This table reads the code. No code, data or
number changed in this pass (docs only; no Net or save change). It feeds the next parity tasks: the `missing` and `differ` rows are the work list.

Verdicts:
- **match**: main already does what the catalog calls a gap (proof in the cell).
- **differ**: built, but a different number, trigger or model than the reference.
- **missing**: not built on main.
- **owner**: an owner line settles it; no build. DECISIONS wins over the catalog (`briefs/DECISIONS.md` 2026-11-07 "parity calls on invented kit extras": cut the Guard meter and Shield Slam, no ours-only riders: Neve's Chill 15% slow, Sable's empowered Shred, Meeko's carrier shield; 2026-11-27 catalog rule: Gil is made different on purpose, borrow feel and numbers only).

Proofs are `file:line` on main c78b7cba288. Hunters use their ids in paths (Lace `archer`, Cinder `ashwick`, Albert `bulwark`, Tenzo `dolm`, Grimble `dredge`, Vex `gunslinger`, Kael `juggernaut`, Sparkle `mage`, Motley `ostra`, Neve `rimewright`, Meeko `tender`, Sable `thief`, Gil `gil`); `K/` = `scripts/arch/kits/`, `A/` = `content/archetypes/`.

### 1. Lace (Myth)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| L1 | Draw has one timing window; reference has two stages with different damage and range | match | `K/pin_draw.gd:6,58` stages (tap shot, Empowered at 0.6 s: 30 dmg to 12 m, Supercharged at 1.15 s: 60 dmg to 16 m, `content/weapons/longbow.json:18`); overdraw halves it (`pin_draw.gd:22`, `longbow.json:38-39`) | the catalog read the hint text ("the flash") only |
| L2 | Phase Walk: damage ends it | match | `K/archer_kit.gd:178-180` `on_take` calls `spirit.end("hit")` | |
| L3 | Phase Walk: wall orb shares the phase | match | `K/pin_spirit.gd:96` `_drop_orb`, `:106-120` orbs give allies and foes the walk | |
| L4 | Phase Walk: ending inside a wall teleports out | match | `K/pin_spirit.gd:7` put back where she last stood clear, counted `:23` `snap_backs`. The 30-mana penalty has no counterpart (no mana, see P2) | |
| L5 | Phase Walk 2.8 s against 5.5 s | differ | `A/archer.json:43` `time` 2.8, rank 3 +0.5 s (`time_rank3`), cooldown 9.5 | duration is the only gap; reference L4 is 7.5 s |
| L6 | Heavy Shot is not hold-charged, stun does not scale with charge | differ | charged: `K/archer_kit.gd:274-281` (hold to full 1.1 s), damage 16 to 30 and push 8 to 12 by charge `:335-336`. Wall stun is a flat 1.2 s (`A/archer.json` `pin.stun`, `archer_kit.gd:370`) | the 1.2 s equals the reference value; only the charge scaling of the stun is missing |
| L7 | Rain of Arrows: check it persists and ticks | match | `K/archer_kit.gd:432-460` a wall of rain, 5 damage every 0.5 s (`A/archer.json` `e.every`, `dmg`), 35% slow, blight (healing barely takes), 4.4 s; burning plus knocked extra `archer_kit.gd:355` (cremate) | |
| L8 | Ult: 6 s window | match | `K/pin_ult.gd:26,57` `window` 6.0, 3 shots, third `final_dmg` and 12% execute `:144` | |
| L9 | Ult: pierces terrain, explosive | missing | arrows pierce every foe (`pin_ult.gd:118` `pierce`) and knock 2 m (`kb`), but the shot stops at blockers (`scripts/match/match.gd:2723-2728`); no blast anywhere in `pin_ult.gd` | one number each: terrain pierce, small blast |
| L10 | Passive: wall climb | match | `scripts/match/hunter_move.gd:135` `climbs_tall`, `content/rules/hunter_move.json:82` `"archer"` `climb_tall` | text in `A/archer.json:33` |
| L11 | Passive: fog vision under half health | match | `A/archer.json` `resource.sense_hp` 0.5, `sense_r` 22; `K/hawk_sense.gd` | |
| L12 | Feel: perfect release cuts the self-slow | match | `K/archer_kit.gd:213-218` `perfect_slow` 0.85 against `draw_slow` 0.7 | |

### 2. Cinder (Felix)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| C1 | Dash: flaming dash with knockback and a 1 s stun | differ | `A/ashwick.json` `dash` kb 7, recoil 3.5, 18 damage, 17 Char; no stun (`K/ashwick_kit.gd` has no dash stun; its only "stun" is the cast-cancel comment `:479`) | catalog also lists +75 speed at L4: not built |
| C2 | Ignite two levels, spread, % max HP | match | levels `K/ashwick_kit.gd:143-163` (`dps1` 0.5%, `dps2` 1%); spread to foes within 4 m `:551-558`; % max HP burn `:156,435`; closed (FINDINGS 2026-11-27 12:22Z, `parity-lace-cinder-1127`) | |
| C3 | Heat Shield scales per enemy and per ignited enemy | differ | per enemy: `ashwick_kit.gd:737` 6.4% plus 5.1% a foe; no extra term for ignited foes | |
| C4 | Heat Shield: a knock resets the cooldown | match | `ashwick_kit.gd:187-196` `on_knock` resets E | |
| C5 | Heat Shield: self-slow while spinning | missing | Furnace Cloak is a press blast with a pull (`ashwick_kit.gd:701-740`), no spin and no self-slow | |
| C6 | Embry Bolt: slow 0.5x for 1.5 s, 0.75 s cooldown | differ | `A/ashwick.json` `rmb`: slow 0.3 for 1.5 s, cooldown 7.0, 2 charges at rank 3 (`ashwick_kit.gd:327`) | cooldown rows are owner calls (`cooldowns-1122.md`) |
| C7 | Flight: reactivate to end, 4 s trail | differ | reactivate lands early `K/ashwick_jet.gd:50`; trail 5.2 s (`A/ashwick.json` `x.trail_t`) | |
| C8 | Cooldown-refund loop (L4 ignite refund 10% / 25%) | missing | knock reset of E is in (C4); the ignite refund was skipped on purpose (`1127-refund-loops.md` last line) | needs levels, see P1 |

### 3. Albert (Oath)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| A1 | Shield energy pool, break penalty (long lockout) | owner | DECISIONS 2026-11-07 cut the Guard meter and Shield Slam; closed 2026-11-20 (`docs/KIT_PARITY.md:15`, `b2e942eb4`). What stands is the source shield's own pool: 160 HP, regenerates, 3 s lockout on break (`A/bulwark.json:115`, `K/bulwark_kit.gd:137-141`) | no new meter |
| A2 | Shield blocks all damage | differ | `A/bulwark.json` `rmb.shield` arc 140, "blocks shots from the front" (`bulwark_kit.gd:108`) | the 0.425 s 0.6x slow on break is not built either (`bulwark_kit.gd:138-146` only locks) |
| A3 | Shield Bash (dash while guarding) and block lowers dash cooldown | match | Shield Charge on the dash key with the aegis up (`A/bulwark.json` `dash`: 4.2 m, push 11, invulnerable, own 6 s cooldown); block feeds the dash `K/bulwark_kit.gd:122-129` (`1127-refund-loops.md`) | |
| A4 | Hammer on the ground gives allies vision | match | `K/bulwark_kit.gd:616-618` `vision_r` 4.5 reveals foes near the hammer to the team | |
| A5 | Smash full charge 1.25 s, hold threshold 0.24 s | differ | full 1.25 s match (`A/bulwark.json:44`); tap window 0.2 s (`:43`) | 0.04 s |
| A6 | Heal zone: delayed burst, wisp revive | match | `K/bulwark_kit.gd:847` mend, burst 18 plus aegis 60 (`A/bulwark.json` `e`), downed ally +0.35 `bulwark_kit.gd:898` | |
| A7 | Ult: fissure with eruptions and slow | match | `K/bjorn_ult.gd`, `A/bulwark.json:189` cells (4 cells of 4 m, strike stun 0.5, lift, slow 0.5 for 1.5 s, scar) | slow 1.5 s against 2 s |
| A8 | Passive: wall or enemy knock stuns | match | `K/bulwark_kit.gd:280-296` Crushed, stun 1.0 s, 8 damage (`A/bulwark.json` `resource.crush_stun`) | reference "short stun" |

### 4. Tenzo (Tetra)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| T1 | Shield: one 175 HP / 3.5 s, ours stacks 4 | differ | `A/dolm.json:19` Shardskin 18 per punch, 4 stacks, 6 s; matched to the game data in `docs/KIT_PARITY.md:573` | catalog reads a different model; leave until footage settles |
| T2 | Dash makes a rock and launches it | differ | Rock Hop: 3 hops off a fresh rock each; the last one crashes and its rock rolls on (`K/breah_hop.gd:7`, `A/dolm.json` `dash`) | rock tie-in exists on the last hop |
| T3 | Slam: charge scaling, leap, reset on a knock | match | `K/breah_slam.gd:59,68-72` charge, stun 0.5 to 1.2 s (`A/dolm.json` `rmb.slam.stun`), jump leap `leap` 3.2; reset `K/dolm_kit.gd:203` (`1127-refund-loops.md`); over the abyss `void_drop` `dolm_kit.gd:281` | |
| T4 | Rock hits: armor shred and slow stack | match | `K/dolm_kit.gd:164-199` shred 15% for 3 s, slow 0.15 for 0.8 s, repeat 0.7 (`A/dolm.json:24`); closed in #1133 (`21a358f9b96`) | |
| T5 | Wall health 500 to 777 | differ | rock `hp` 45 (`A/dolm.json:24`) in our health scale | |
| T6 | Allies hop over the rocks | match | rocks are stand-on and climb low walls (`K/dolm_kit.gd:6`, `scripts/arch/stone_stand.gd`); DECISIONS 2026-11-07 default "Tenzo's allies can hop his rocks" | |
| T7 | Stonesight sneak cone | match | `K/dolm_kit.gd:307-350`, 18 to 25 m, 25 to 40 degrees (`docs/KIT_PARITY.md:241`) | |
| T8 | Ult aimable by drag, temporary terrain over the abyss | match | `A/dolm.json:44` `drag_min`, `aim_max`; `:45` `floor_time` 6 s | |

### 5. Grimble (Kingpin)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| G1 | Dash: cooldown model with an air variant, ours 3 charges | differ | `A/dredge.json:20-21` 3 charges at 10 s; the air pounce has its own 12.5 s | |
| G2 | Hook grounds (not stuns), grabs allies, self-lock while pulling | match | Grounded 0.9 s on arrival `K/dredge_kit.gd:537`; ally and wisp `:451`; self Grounded while reeling `:465`; closed #1133 (`21a358f9b96`) | **stale text**: `A/dredge.json` `rmb.variants.tap` still says "reeled to you, stunned" |
| G3 | Spread bloom, armor shred on no-spread shots | differ | volley is always tight (`content/weapons/shotgun.json:10` `fan_deg` 6), so every volley takes the extra armor wear (`K/dredge_kit.gd:133-155`); no bloom | |
| G4 | Slam: dunk over the abyss, stun grows, pulls him down | match | rank 3 double damage over the abyss `dredge_kit.gd:642-651`; dive 28 (`A/dredge.json` `e.dive`); stun 1.1 s (+0.2 at rank 3) | |
| G5 | Passive cap 10, lose one on death | match | `K/dredge_kit.gd:109,201`; `A/dredge.json` `resource.max` 10 | |

### 6. Vex (Ghost)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| V1 | Rifle front-loaded, loses half over 10 rounds | owner | shape in: `content/weapons/quill_rifle.json:19,23` (`sustain_loss` 0.2, rest 0.35 s, drum refills) | owner 11-24 playtest kept a fifth, not a half (`1126-vex-recheck.md` rows 1-2) |
| V2 | Daze boosts several abilities | match | `A/gunslinger.json:25` rifle +76%, Coin Blast, Palm Lance and Cinderfall +20% (`rattle_k`); `1127-vex-daze.md`, `--vex-daze-check` | closed on main |
| V3 | Coin wall stun 1.2 s | match | `A/gunslinger.json:71` `wall_stun` 1.2; `K/gunslinger_kit.gd:735-738` | closed on main |
| V4 | Cooldown refunds: cone hit, railgun hit | missing | none (`--gunslinger-combo-check` asserts none; `1127-vex-daze.md` "Not changed, still open"); the slide reset on a knock is in | |
| V5 | Slide: hold = longer, longer cooldown; +90 speed | differ | hold 7 m, 40% longer cooldown (`A/gunslinger.json:45-47`); speed buff only at rank 3 (`rank3_speed` 0.25) | |
| V6 | Railgun: 12 s, pierces, +20% on Dazed | match | Palm Lance 11.5 s, 0.6 s stand-still charge (`A/gunslinger.json:94`), through cover and everything, +20% Dazed | stand-still charge is the one tighter cost |
| V7 | Passive omnivamp after an ability hit | match | Fever: 6% lifesteal for 3.5 s after an ability lands (`K/gunslinger_kit.gd:111,260`, `A/gunslinger.json:25`) | catalog said "missing sustain loop" |
| V8 | Ult: +50% centre, slow, 3 s zone | match | `A/gunslinger.json:124` `core_k` 0.5, 30% slow, 3 s; `K/gunslinger_ult.gd:53` | delay 1.6 s |

### 7. Kael (Brall)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| K1 | Ult: a knock is an instant elimination | differ | knock or kill resets the cooldown (`K/juggernaut_ult.gd:195-217`); no elimination; 0.65 s guard then cleave and 80% heal (`A/juggernaut.json` `x`) | |
| K2 | Heavy tap 1.5x below 35% health | match | `A/juggernaut.json:29` `low` 0.35, `low_k` 0.5; `K/juggernaut_kit.gd:811` | |
| K3 | Airborne slam and chain-pull spin | match | Meteor Drop `K/juggernaut_kit.gd:51`, `K/juggernaut_drop.gd`, Cinder Spin `juggernaut_kit.gd:17,61`, `K/juggernaut_chain.gd` | |
| K4 | Sweet-spot hits at slash edge and tip | match | tip hits 2x (`A/juggernaut.json:20` `tip` 0.6), slam sweet band `:29`, Rampage tip 12 `:25` | |
| K5 | Heal on knock, haste while empowered | match | `K/juggernaut_kit.gd:166,221` (`heal_knock` 20%, dash haste 12%, ability haste 20%, +15% damage) | |
| K6 | 4-step combo | differ | alternating slash chain that resets after 1 s (`K/juggernaut_kit.gd:36`); no 4-step selector | |

### 8. Sparkle (Joule)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| S1 | Dash: projectile immunity and reduced damage taken | differ | the run itself lets shots pass (`K/mage_kit.gd:456` `invuln`, `phase`); the charge hold and the reduced-damage rule are not built. **Branch `ext/parity-sparkle-meeko-1127` (8edc3d30, 9 commits, not merged)** adds shots passing during the charge and halved hits | dash is an aimed lane, the reference's is a press |
| S2 | Lightning orbs reset the dash | match | `K/mage_kit.gd:325,795` (`grant_reset`, `_tick_motes`), `A/mage.json:82-84` | |
| S3 | Ult spreads Static, immune while airborne | match | `K/mage_ult.gd:31,365` `spreads`, `:6` invulnerable in the air | |
| S4 | Strike aimed by hold-drag | match | `K/mage_sky.gd:5`, `A/mage.json` `e` (toward you pulls, away throws, up to 1 s) | |
| S5 | Mana refund, % max HP on the payoff | match | % max HP: `K/mage_kit.gd:568` `blow_pct` 0.18, plus 16 flat. Mana refund: no counterpart (P2) | |

### 9. Motley (Void)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| M1 | Passive: 10x faster vs hunters, scales four abilities | match | `K/ostra_kit.gd:125` `hunter_k` 10; Snap +44%, seed bigger and faster, Trade 1.25 s (`A/ostra.json` passive, `dash.time_swollen`) | |
| M2 | Passive: no footstep noise | missing | no footstep rule in `K/ostra_kit.gd`; only the float over ground hazards (`:18,127-131`) | |
| M3 | Swap: lob and swap with anything | match | lob, swaps foes, allies and Boki in 1.9 m (`A/ostra.json:55`, `K/ostra_kit.gd:479`) | |
| M4 | Swap: swapped enemy slowed 0.6x for 3 s, disoriented | missing | no slow or disorient on the swapped foe. Ours-only extra: allies get a shield (`A/ostra.json:56` `ally_shield` 0.326) | the shield is not in the catalog: check it against DECISIONS 11-07 "ours-only riders: keep NONE" |
| M5 | Orbs pass terrain only when charged | match | `K/ostra_kit.gd:220` (owner 11-26: only the void orb passes walls) | |
| M6 | Bomb up to 3.5x, grounds | differ | 3.5x in (`A/ostra.json:119` `dmg_max_k`); no ground state | |
| M7 | Snap: self speed +50 on cast, +100 on impact | match | `K/ostra_kit.gd:147-152` `_boost`, rank 3 only (`A/ostra.json` `rmb.snap.boost`) | rank 1 has none |

### 10. Neve (Celeste)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| N1 | Burst finisher of 3 big darts | match | `K/rimewright_kit.gd:6`, `content/weapons/hoar_fan.json:27` (`heavy` n 3, 2x damage) | |
| N2 | Skate early release refunds cooldown | match | `K/rimewright_kit.gd:617-618` | |
| N3 | Skate: abyss islands | missing | no island code in `K/rimewright_kit.gd` | |
| N4 | Chill 4 s, shatter on a knock or minion kill | match | `K/rimewright_kit.gd:104,155` (hunter or Mob felled), `:64` radius; `A/rimewright.json` passive 37 to 3 m, 54 on 8 darts | |
| N5 | Chill gives a 15% slow | owner | DECISIONS 2026-11-07 cut it; `add_chill` (`rimewright_kit.gd:104-113`) applies no slow | do not rebuild |
| N6 | Ult: early reactivate (67%) and 3.5 s | match | `A/rimewright.json:177-179` hold 3.3 s, late 0.75 s, `late_k` 0.67 | 3.3 against 3.5 |
| N7 | Cryo Spear: 2 charges, slow by proximity, damage by range | differ | 2 charges in (`A/rimewright.json:80`); flat slow 0.35 (`:89`) and flat 18 damage | |
| N8 | Barricade: HP and pushes | match | `A/rimewright.json:115,119` 200 HP (+40 rank 3), push 5 | |

### 11. Meeko (Elluna)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| E1 | Carry shield, stun on break, drop rule | owner | DECISIONS 2026-11-07 cut Meeko's carrier shield; `K/tender_kit.gd:310-312` any damage or a stun drops them, 4 s lock (`A/tender.json:50`). **Branch `ext/parity-sparkle-meeko-1127` (`dc4dc8cb001`, `90994ca81d2`, not merged) puts the shield back: it reverses that cut, owner to rule** | |
| E2 | Carry: one ally and 0.7x slow | differ | up to 2 (`A/tender.json:47`); no slow (`docs/heroes/tender.md:10`, game data says up to 2 and no slow) | catalog and game data disagree; footage check first |
| E3 | Heal: 500% on wisps, +50% on throw | match | `K/care_util.gd:34-43`, `A/tender.json:128` `wisp_k` 5; throw boost `K/tender_kit.gd:795-796` | |
| E4 | Heal: 33% effective on self | missing | no self penalty (`tender_kit.gd:800-840` heals everyone inside alike) | |
| E5 | Dash through allies refunds cooldown | match | built 2026-11-27: `K/tender_kit.gd:377-389`, `1127-refund-loops.md` | |
| E6 | Empowered shot after a pause | match | `K/tender_kit.gd:167` (wait 1.0 s, range x1.25, size x1.5); Kindle winds Hearthlight back 0.2 s (`:147`). Mana return: P2 | |
| E7 | Root: 2 s delay, then damage and root to nearby | differ | `A/tender.json:94` seed builds 2 s, burst 2.2 m, 32 damage, root 1.1 s; but only while the foe stays within 15 m (`K/tender_kit.gd:552-564`) | reference roots after 2 s whatever the foe does |
| E8 | Ult: teleport revived wisp, castable while channeling | match | `A/tender.json` `x` (pulled to her side and stood up; she keeps walking and casting) | |

### 12. Sable (Shiv)

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| B1 | Bola grounds on the first hit, stun 1 s | match | Grounded 1.5 s plus 30% slow (`A/thief.json:25`, `K/thief_kit.gd:708,719`); pair stun 0.9 s (`:826`) | pair stun is `[?]` in the source rows |
| B2 | Dagger: forced teleport, slow 0.5x for 4 s, cooldown cut on stick | differ | auto-blink at 6 s (`A/thief.json:29`); slow 0.5 for 2.5 s; cooldown cut 50% foe, 25% wall (`K/thief_kit.gd:907`) | slow is 1.5 s short |
| B3 | Passive heals on knock and assist | match | `K/thief_kit.gd:650`, `A/thief.json` `resource.heal_knock` 20%, `heal_assist` 25% | catalog said "ours only adds damage" |
| B4 | Ult refreshes the dash, LMB allowed, outer-ring anti-heal | match | `K/thief_ult.gd:8,68` (Vault back, keeps shooting), `A/thief.json` `x.rim_blight` 6 | |
| B5 | Empowered shot only past half range | differ | always empowered, 2.34x (`K/thief_kit.gd:382`, `EMP_RANGE_K` `:38`) | |
| B6 | Empowered armor shred | owner | DECISIONS 2026-11-07 cut Sable's empowered Shred | do not rebuild |

### 13. Gil (Beebo): different on purpose, so all rows are owner

| # | Catalog gap | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| I1 | Random ammo, manual cycle, 1% jackpot | owner | shuffled bag, next vial always shown (`K/gil_kit.gd:48-77`, `A/gil.json:32`); no cycle; Geyser is 1 of 9, no 3x | borrow feel only |
| I2 | Each ammo has a utility (ally heal, terrain) | owner | five vials, none heals an ally (`A/gil.json` `rmb.vials`) | |
| I3 | Charged swing, stacking slow, wall stun | owner | charged lunge and wall stun in (`K/gil_kit.gd:162-223`); third thrust slows once, no stack to 3 | |
| I4 | Ult as a vehicle with wall-crash payoff | owner | Tidal Wave: ride, knock-up, slow (`A/gil.json:47`), cooldown 90 s against 40/30/30 | |
| I5 | Mobility 2 charges, lava immunity | owner | Ground Swim 8 s (`A/gil.json:27`); no hazard rule in `K/gil_kit.gd` | |
| I6 | Bomb growth, ally speed aura | owner | Riptide is instant (`A/gil.json` `e`) | |

### Cross-hunter patterns (catalog numbering)

| # | Pattern | Verdict | Ours on main (proof) | Note |
|---|---|---|---|---|
| P1 | Four ability levels (ult 3) | differ | three ranks per slot, chosen on level-up: `A/archer.json` `rank_cd`, `rank_dmg`, `rank2`, `rank3`; `docs/decisions/0110-ult-ranks.md`. Not four, extras differ per hero | the catalog said "text-only" |
| P2 | Mana cost and mana return | missing | no mana resource in the game (`grep mana scripts` hits only `scripts/ui/squad_frames.gd`); skipped on purpose in `1127-refund-loops.md`; no DECISIONS line | owner call before any build |
| P3 | Hit-based cooldown refunds | differ | built: Tenzo, Albert, Meeko, Cinder, Kael, Sparkle, Sable, Neve (`1127-refund-loops.md`); missing: Vex cone and railgun (V4) | |
| P4 | Contextual swaps of one slot | match | Albert aegis up (`A/bulwark.json` `dash`), Kael air Drop and chain-pull Spin (K3), Tenzo and Grimble air slams, Meeko and Grimble air dash, Albert Shield Surf | |
| P5 | CC grammar: Grounded separate, wall stun 0.4 to 1.2 s | match | Grounded: `K/dredge_kit.gd:537`, `A/mage.json:115`, `A/thief.json:25`, `scripts/match/status_edge.gd:13`; wall stun in every kit (`--wall-stun-check`, `docs/KIT_PARITY.md` "Crowd control") | stun scaled by charge: Tenzo, Lace partly (L6) |
| P6 | Self-slow while shooting or charging, back-damage | match | Lace hold 0.38x (`K/archer_kit.gd:220`), Albert 0.6x aegis, Meeko 0.5x wind-up (`K/tender_kit.gd:470`), Grimble 0.3x charge, Sparkle 0.18 rod; back hit +50% (`A/dredge.json` `resource.back_k`). Missing: carrying slow (E2) | |
| P7 | Empower after a pause | match | Meeko `K/tender_kit.gd:167`, Motley `K/ostra_kit.gd:220-271`, Lace quick draw `K/pin_draw.gd:17` | |
| P8 | Two-level stacking debuffs | match | Cinder Char to Ablaze to Flashover (`ashwick_kit.gd:143`), Neve Chill (`rimewright_kit.gd:104`), Sparkle Static 4, Meeko Kindle 5, Sable Marks | |
| P9 | Wisps targetable by hooks, heals, strikes | match | hook scoops wisps (`dredge_kit.gd:451`), heal x5 (`care_util.gd:34`), Albert and Meeko revive | |
| P10 | Execute and lock-in thresholds | match | Kael 35% (`juggernaut_kit.gd:811`), Lace 12% finisher (`pin_ult.gd:144`), Kael and Tenzo reset on a knock (`juggernaut_ult.gd:216`, `dolm_kit.gd:203`) | |
| P11 | Abyss interaction: dunk, temporary terrain | differ | Tenzo floor and ridge (`A/dolm.json:45`), Grimble dunk (`dredge_kit.gd:651`), Motley hover; Neve islands missing (N3) | |
| P12 | Projectile immunity on dashes and ults | match | Sparkle run (S1) and Kitefall, Albert Shield Charge, Kael guard 0.65 s, Neve statue, Sable Vault, Gil wave; gaps are S1 only | |
| P13 | Front-loaded weapon damage; random-effect ammo | differ | Vex shape in, a fifth not a half (V1, owner); Gil random bag (I1, owner) | |
| P14 | One Daze boosts several abilities | match | `1127-vex-daze.md`, `--vex-daze-check` | closed on main |
| P15 | Vehicle or carry ults that scale on a wall crash | owner | Gil only (I4); Gil is different on purpose | |

### Top 5 (catalog) mapped to the rows

1. Refund and reset loops: mostly built (P3). Open: V4 (Vex cone and railgun refunds), C8 (ignite refund, needs levels).
2. Levels and mana: levels exist as 3 ranks (P1, differ); mana does not exist (P2, missing, owner call).
3. CC grammar: Grounded and wall stun are in (P5, match); open: stun scaled by charge on Lace's Heavy Shot (L6), swapped foe slow (M4), Motley bomb grounding (M6).
4. Context variants and weapon rhythm: variants are in (P4); open: Kael 4-step combo (K6), Albert broken-shield slow (A2).
5. Two-tier stack payoffs: Ignite, Chill, Static all built (P8); open: shield per ignited foe (C3), Cinder self-slow (C5). Chill slow and Sable Shred stay cut (N5, B6).

### Work list for the next parity tasks (missing or differ, no owner row)

Smallest first: Lace ult terrain pierce and blast (L9), stun scaling on Heavy Shot (L6); Meeko self-heal 33% (E4) and root trigger (E7); Motley swapped-foe slow 0.6x/3 s (M4) and bomb ground state (M6); Neve Spear proximity slow (N7) and islands (N3); Vex refunds (V4); Cinder dash stun (C1), per-ignited shield term (C3); Sable dagger slow 4 s (B2); Kael ult elimination (K1); Sparkle dash immunity and halved hits (S1, branch exists). Text fix with no number change: `A/dredge.json` `rmb.variants.tap` says the hook "stunned" the foe; main Grounds it (G2).
Owner rulings needed: Meeko carrier shield (branch `ext/parity-sparkle-meeko-1127` reverses the 11-07 cut), mana economy, Motley's ours-only ally shield.
