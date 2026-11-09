# Verify: Meeko (`tender`, source Elluna) and Sparkle (`mage`, source Joule) on main d255acbee (2026-11-09)

PARITY FIRST (briefs/DECISIONS.md 2026-11-07): the source decides; our ideas are suggestions below, not built. Read-only pass: no game code or data changed.

**Sources.** [D] `supervive_kits.md` (Elluna, Joule tooltips, level 1), [F] `hero-ref/mooshmoosh.md` and `vireo.md` (5 fps footage, 1 bh = 1.8 m, so ±0.1 s), [O] owner notes in DECISIONS (they win). Our side is read from code and JSON on main, not from the older hero docs.

**Verdicts.** `match`, `differ` (how), `owner` (an owner note overrides the source), `[?]` (no source settles it).

**Checks run on this tree (all green).**
`--mage-combo-check` 129 PASS, 0 FAIL. `--tender-combo-check` 87 PASS, 0 FAIL. `--archetype-check` 379 PASS, 0 FAIL. `tools/health.py --strict` OK. `tools/gen_wiki.py --check` OK. Combo checks assert our spec, not the source, so a pass is not parity proof. No GPU shots were taken: no look changed, and the in-flight VFX branches carry their own strips.

## Sparkle (`mage`, Joule)

| Row | Source | Ours on main (file) | Verdict |
|---|---|---|---|
| LMB cadence | 0.8 s, no magazine [D,F] | 0.648 s, mag 99 (`coilcaster.json`) | owner (items 70, 116) |
| LMB range, aim, speed | always to max range past the cursor, ~7.5 bh = 13.5 m, ~32 m/s [F] | 13 m, `"aim": "max"`, 37 m/s; stops on the first foe; 1 Static | match; speed 14% fast `[?]` |
| LMB damage | 90 [D] = Static 1 | 12; bolt is the unit the other numbers scale from | match (unit) |
| LMB walk slow | none shown (she stood still) [F] | `fire_slow` 0.9, a 10% slow while firing | differ: ours, source silent (rank 7) |
| LMB anim | alternating hands, torso twist [F] | `mage_lmb_l/_r`, asserted | match |
| RMB input | hold, release; 1.2 s press to throw [F] | hold, full at 1.0 s, auto at 1.2 s, min 0.33 s | match |
| RMB damage | 133 [D] = 1.48 bolts, one value (footage 472 vs 117 = 4 bolts) | 18 tap to 30 held (1.5 to 2.5 bolts) | differ: charge scaling is ours; [D] and [F] disagree (rank 6) |
| RMB knock | about 1 bh = 1.8 m; wall or foe = stun [D,F] | push [6, 9] measures **2.79 m**; stun 0.8 s wall/foe | differ: 1.55x too far (fix in flight, rank 1) |
| RMB orb and Static | 1 Static; orb at the impact, resets Surge [D,F] | 1 Static; orb 0.05 s after any foe hit, 4 s, resets Wirerun | match |
| RMB cooldown | 10 s [D] | 8 s | differ 0.8x (fix in flight, rank 2) |
| E place | press places at the cursor; hold and drag sets the pull direction [D]; chevron toward the cursor [F] | press drops the circle at the cursor (11 m); held E drags (`MageSky.drag_dir`); release commits one fixed vector | match |
| E tap | strikes the target location, pull or knockback [D] | a tap = release at once; default is away from her | match; default direction `[?]` |
| E hold | not limited in the sources | held up to 1.0 s (`drag_max`), then auto-commits; drag under 0.8 m = default | `[?]` the cap and the dead zone are ours |
| E countdown | 0.8 s (4 frames) [F] | 0.8 s, pillar narrows, committed arrow | match |
| E hit | 162 [D] = 1.8 bolts; 1 Static (info panel says 2); Grounded | 20 = 1.67 bolts; 1 Static; Grounded 1.5 s | match; Static owner (audit kept 1) |
| E slide | about 4 bh = 7.2 m over about 1 s [F] | 3.4 m over 1.1 s, eased (measured 3.2 m) | differ: half the footage; commit 2843e97d3 chose "modest" on purpose (rank 4) |
| E radius | disc about 2 bh across [F] = r 1.8 m | r 1.5 m (the audit cut it from 2.3 to the hit area) | differ 17%, within footage error |
| E orbs | flings orbs about 6 bh = 10.8 m; steals a rival's [F] | `fling_dist` 6 m; a rival's orb becomes hers; dragged toward her within 9 m it flies to her | differ: 55% as far (rank 4); steal match |
| E cooldown | 12 s [D] | 10.5 s | differ 0.875x (fix in flight, rank 2) |
| Shift press/hold | PRESS dash, 153 dmg; HOLD charges a longer dash [D]; full length about 13.5 m, 0.6 s charge [F] | tap 7.5 m, hold 0.6 s to 13 m, auto 0.9 s; cooldown spent on the press | match; length and hold have an owner note not on main (below) |
| Shift speed | ~32 m/s [F] | 40 m/s | owner (item 70) |
| Shift pass damage | 153 = 1.7 bolts [D] | 20 = 1.67 bolts | match |
| Shift Static payoff | 4-Static foe: massive bonus, resets the cooldown [D]; 1078 vs a 146 hit = 7.4 bolts [F] | double hit + Blowout 16 + 18% of health (about 5.7 bolts on a Light), resets | match in shape; payoff 0.6 to 0.8x the footage ratio `[?]` |
| Shift orb reset | through an orb resets it [D,F] | yes, plus walking over one | match (owner items 71, 74) |
| Shift invulnerable | ignores projectiles, INVULNERABLE tag [D,F] | phase while running | match; the word is in flight (rank 1) |
| Shift reset run | none in the source | a reset Wirerun goes 1.5x further and charges in 0.75x time | owner (item 116b) |
| Shift cooldown | 9 s [D] | 8 s | differ 0.89x (fix in flight, rank 2) |
| Shift arrival | gold ring burst on arrival [F] | none, dust puff only | owner (no bursts on dashes) |
| Shift interactions | no press inside Surge shown | `dash_flow/mage.json`: `[?]` rows (5 `keep`/`fire`, all "Not determinable") | `[?]` |
| Passive | 4 Static, dash payoff; decay not shown [D,F] | 4 max, 4.5 s refreshed per hit, sky bolt on the 4th | match; 4.5 s `[?]` |
| Kitefall input | PRESS launches, REACTIVATE crashes at the target location [D]; ring about 15 bh across, 0.4 s crouch, hangs 1.2 to 1.8 s [F] | 0.3 s crouch, hang up to 1.7 s, second press or attack at the cursor, ring 14.4 m (8 bh) radius | match; the auto-land at 1.7 s is ours `[?]` |
| Kitefall immunity | immune to projectiles [D]; INVULNERABLE tag [F] | invulnerable from take-off to strike | match |
| Kitefall damage | 72 = 0.8 bolts [D] (115 vs 146 = 0.79 [F]) | **22 = 1.83 bolts** | differ: 2.3x the source ratio (fix in flight, rank 2) |
| Kitefall Static | 1 Static; a struck target's stacks spread to nearby foes [D] | +1 each; every struck foe raised to the highest count among them first (arcs) | match (owner item 72) |
| Kitefall orb | spawns Lightning Orb(s) at the landing [F, info panel] | **none** (`MageKit._drop_mote` is only called from the Rod) | differ: missing (rank 3) |
| Kitefall knock | [D] lists none (an older wording says knockback) | push 8, lift 0.4 on everyone struck | `[?]` ours, low |
| Kitefall cooldown | 60 s [D] (37.5 s footage) | 42 s | differ 0.7x (fix in flight, rank 2) |
| Kitefall interactions | none in the sources | Shift or jump in the crouch combines; in the air Shift and jump do nothing (recorded exception) | `[?]` owner item 51 |
| Anim | footage poses | 16 moves on `ryzz.glb` | match on coverage; timing branches in flight |

## Meeko (`tender`, Elluna)

| Row | Source | Ours on main (file) | Verdict |
|---|---|---|---|
| LMB | 0.4 s, flies to max range (7 to 8 bh = 12.6 to 14.4 m) past the cursor, ramp 64, 66, 84, 93, 93 (+45%), Empowered after a pause [D,F] | 0.4 s, 12 m past the cursor, Kindle +0.72 per stack to 5 (+45%), Empowered after 1 s idle; no magazine, no firing slow | match; range 12 vs 12.6+ (5% short) |
| LMB Empowered | the source does not say what it adds | +40% range, double wind-back (`emp_range` 1.4) | `[?]` ours (removal in flight, rank 5) |
| RMB input | hold to aim, release to fire [F] | press, fixed 1.0 s wind-up at half speed, throws itself (item 118) | owner |
| RMB shot | fast orb about 20 bh/s; area shows at once, roots about 0.6 s later, root over 1 s [F] | 30 m/s, disc at once, root at 0.7 s for 1.1 s, r 2.2 m (footage 1.2 bh = 2.2 m) | match |
| RMB damage | 49 on hit, then root [D] | 9 on hit + 32 burst = 41 | match within `[?]` (no level-1 ember to ratio against) |
| RMB cooldown | 11.5 s [D] | 10.5 s | differ 0.91x (fix in flight, rank 2) |
| RMB motion | a small hop with both arms pushed [F] | hop form, wind-up 1.0 s | `[?]` (motion branch in flight, rank 5) |
| E | 2.5 s zone, burst at the end, reactivate throws it near-instant, attaches to the first ally passed [D,F] | 2.5 s, r 2.6 m (footage 1.3 to 1.5 bh = 2.3 to 2.7 m), burst 22, throw 45 m/s to 9 m, thrown disc r 2.9 m, latch 1.0 m | match |
| E cooldown | 12 s [D] | 11 s | differ 0.92x (fix in flight, rank 2) |
| E healing | wisp x5, self x0.33 [wiki] | wisp_k 5, self_k 0.33 | `[?]` self_k is wiki-only (removal in flight, rank 5) |
| X | channel 5 s on an ally or Wisp, she walks; pulls and revives a knocked ally at the end; cancels on stun, knock or too far [D,F] | tether 5 s, 7 bh = 12.6 m ring, heals 7/s, walks and casts; downed mate pulled and stood up; breaks on stun, range | match; ring 7 bh (footage said both 7 and 8) |
| X cooldown | 60 s [D] | 46 s | differ 0.77x (fix in flight, rank 2) |
| Passive carry | carries allied Wisps; **too much damage or a stun** drops them, 4 s no re-pick [D] | carry 2 (`max`), no slow, no shield; `tender_kit.gd:215` drops on stun, **root, Hex**; `:241` drops on **any** damage; lock 4 s | differ: root and Hex are ours, "too much" is not traced (fix in flight, rank 5) |
| Passive cap | not stated | 2 carried | `[?]` |
| Shift ground | short dash, never shown cleanly (the dashes seen follow a jump); other hunters 1.5 to 2.5 bh in about 0.2 s [F]; cooldown 7 s [D] | 4.2 m x 0.85 feel = 3.64 m in 0.20 s (measured), cooldown 7 s per charge | match as far as the source goes; distance `[?]` |
| Shift air | 11 to 15 m over 0.8 to 1.1 s (mean 13.3 m / 0.93 s), flat burst 19 to 22 m/s for 0.4 to 0.6 s, float at 40 to 65%, held up about 0.6 s; cooldown 14 s separate [D,F] | 13.3 m / 0.95 s (measured 13.9 m), burst 17.1 m/s for 0.4 s, eases to 45%, sink 0, cooldown 14 s separate, glide only airborne, steer 3 rad/s | match on distance, time, height, cooldown; **burst 10 to 20% slow** (rank 4) |
| Shift direction | movement direction, not the cursor [F] | movement direction | match |
| Shift through an ally | refunds half the cooldown and 1 s of E (footage summary, "Super" version) [F]; [D] has only "air dash refreshes on picking up a wisp" | rank 3 refreshes the air dash on a pickup; no ally bonus (data pass removed it) | match [D]; [F] disagrees `[?]` (rank 6) |
| Dash interactions | footage: embers while moving | `dash_flow/tender.json`: ember fires mid-dash, RMB buffers after the hop, hold rows `keep` | match; 3 `keep` rows `[?]` (partly sourced in flight) |
| Anim | footage poses | 16 moves on `pip.glb` | match on coverage; timing branches in flight |

## Ranked fixes (nothing built here; files and effort)

Most of the top rows already have a READY branch. Merge those first; do not rebuild them.

| # | Gap | Fix | Files | Effort |
|---|---|---|---|---|
| 1 | Rod knock 2.79 m vs 1.8 m; no INVULNERABLE word on Wirerun | merge `ext/sparkle-rmb-knock` (push [4.4, 6.6]) | `content/archetypes/mage.json`, `tools/hero_combo_check.gd` | S, in flight |
| 2 | Cooldowns 0.7x to 0.92x of [D] on both heroes: Sparkle RMB 8/10, Shift 8/9, E 10.5/12, X 42/60; Meeko RMB 10.5/11.5, E 11/12, X 46/60; Kitefall damage 22 vs ratio 9.6 | merge `ext/cooldown-parity-verify` (sets all seven) and `ext/damage-ratio-audit` (Kitefall 22 to 9). Owner call: this makes both kits slower than the pace they play at today | `mage.json`, `tender.json` | S, in flight, owner |
| 3 | Kitefall drops no Lightning Orb on landing (footage info panel says it spawns orbs) | call `MageKit._drop_mote` at the landing spot in `MageUlt._strike`, assert it | `scripts/arch/kits/mage_ult.gd`, `tools/hero_combo_check.gd` | S |
| 4 | Footage numbers we hold lower: Skycall slide 3.4 m vs 7.2 m and orb fling 6 m vs 10.8 m (commit 2843e97d3 chose "modest" on purpose), Skycall r 1.5 vs 1.8 m, Meeko glide burst 17.1 vs 19 to 22 m/s | owner call; if kept, mark `[?]`. If raised: `slide_dist`, `fling_dist`, `radius`, Meeko `dash.air` burst | `mage.json`, `tender.json` | S, owner |
| 5 | Meeko ours-only rules: Empowered +40% range and self_k 0.33; root and Hex drop a carry; RMB motion | merge `ext/parity-no-riders-meeko`, `ext/meeko-carry-drop-rebased`, `ext/meeko-rmb-motion-rebased-rebased-rebased` | `tender_kit.gd`, `tender.json`, `docs/heroes/tender.md` | S to M, in flight |
| 6 | Source conflicts to settle: Rod damage (133 [D] vs 472 [F]) and its charge scaling; Meeko dash-through-ally refund [F] vs none [D] | owner call on which source wins | `mage.json`, `tender_kit.gd` | S, owner |
| 7 | Sparkle LMB slows her 10% while firing (`fire_slow` 0.9); sources silent, Vex and Meeko have none | set 1.0 if the owner wants no ours-only rules | `content/weapons/coilcaster.json` | S, owner |

**Not fixed here.** No row was both a plain number and clearly sourced and absent from a READY branch: every clear mismatch (knock, cooldowns, Kitefall damage, carry drop) already has a branch that touches the same lines, and a second edit would only conflict.

## READY branches that touch these two heroes and are not on main

Found by diffing each READY line's sha against `origin/main` for the hero's kit, JSON, dash-flow, sfx, warden_anim and doc files. Gameplay or numbers first; the rest are looks, animation and docs.

**Sparkle, gameplay.** `ext/sparkle-dash-feel` 8876174f9 (owner 11-08 playtest: Wirerun hold 0.9 s, length 7 to 11 m, speed 34, Rod self-slow 18%, no carried momentum, Shift never fires the class tumble: main still has 0.6 s, 7.5 to 13 m, 40 m/s, so **the owner's latest Wirerun note is not on main**), `ext/sparkle-rmb-knock` 4696270ed, `ext/damage-ratio-audit` a89a84bed, `ext/cooldown-parity-verify` 2be9877c2, `ext/flow-hold-rows` 125245956, `ext/gaps-mage` ac71b638a (docs).

**Meeko, gameplay.** `ext/meeko-carry-drop-rebased` 5851463ad, `ext/parity-no-riders-meeko` 0d6177875, `ext/meeko-ult-cancels` d4b9d81fd, `ext/meeko-rmb-verify-rebased` 7c1762cf5, `ext/meeko-rmb-motion-rebased-rebased-rebased` 14f79f40d, `ext/flow-rows-source` dd2c83be5, `ext/gaps-tender` 025ef9ffa (docs), `ext/cooldown-parity-verify` (shared).

**Both.** `ext/kit-text-numbers` 9cc9fe9ff, `ext/kit-number-sources` eb424bbb1, `ext/recast-buffer-expired` 83bed4bc3, `ext/cursor-clamp-parity` f506a47c4, `ext/glide-cast-rules` f8f23597f, `ext/parity-passives-a` 2d4ecc486, `ext/parity-iframes` 583b7cfd4, `ext/parity-cc-lockouts` 123ec0cb8, `ext/parity-interrupts-a` a65a3b102, `ext/bot-kit-use-b` a2dc282d1, `ext/combo-marks-a` 08dfc092f (Static tag), `ext/combo-marks-b` 0bd68fb6d (Kindle tag), `ext/reset-cue-rebased` 0fc62a451.

**Looks, animation, sound.** `ext/vfx-sparkle-storm` e5680b9c2, `ext/vfx-meeko-weight` 9c4ad7800, `ext/anim-time-sparkle` 4c7b70c9c, `ext/anim-time-meeko` bc9a71dc7, `ext/anim-arm-sparkle` 816d94052, `ext/anim-mantle-1` 218d107f8 and `-3` c55ef02ea, `ext/anim-stomp-drink-2` 197cb1d63 and `-3` fb4769a73, `ext/sfx-kit-placeholders` 7725b94da.

Many of these are stacked on each other or carry the old integration lines; merge in the order the READY notes give.
