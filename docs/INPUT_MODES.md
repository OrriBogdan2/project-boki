# Input modes: how each slot is pressed, source against ours (12 Hunters, 2026-11-09)

PARITY FIRST (briefs/DECISIONS.md 2026-11-07): match the source; our own ideas are listed, not built. This is the one table of
how every Hunter's LMB, RMB, E, R and Shift is pressed, so that "a hold animation never shows without the hold input" and the
two-step (recast) rules of 2026-11-08 can be checked against one page. Read-only audit: no game code changed.

**Input words.** *press*: acts on the key down (or on release of a tap under the guard). *hold-auto*: held = fires again and again.
*hold-charge*: held = charges, release fires. *hold-drag*: held, the cursor sets a direction or angle, release commits.
*recast*: a second press of the same key while the first cast is still open (the window is given where known).

**Verdicts.** `match`: same input, within footage error. `match+`: same, and ours also accepts an input the source lacks (a harmless
extra, listed so nobody builds on it). `differ (owner #n)`: an owner item overrides the source (OWNER_REVIEW_1103 item n), so it
stays. `unsettled`: the sources disagree or are silent and I did not guess; it is a follow-up question, not a fix.

**Evidence.** [D] briefs/supervive-data/supervive_kits.md (game tooltips). [S:x] the footage sheet briefs/hero-ref/x.md (5 fps, 0.2 s a
frame). [W] our docs/heroes/<id>.md rows. [O n] OWNER_REVIEW_1103 item n. Trust order: owner > D > wiki > footage. Source files live
on `origin/ext/agent-briefs`. Ours is read from `content/archetypes/<id>.json` (card, `rmb.hold`, `dash`), `content/weapons/*.json`
and the `scripts/arch/kits/<id>_kit.gd` hooks (`fire_rmb`, `rmb_hold_tick`, `e_recast`, `ult_recast`, `lmb_override`). Not verified:
frame timings (not re-measured), the dash buffer, Q and G (ours only). `rmb.hold` is the tap/hold guard in seconds: 0 means the
press fires at once (`ArchKit.press_rmb`); above 0, the release fires and a quick tap fires on release.

## Vex (`gunslinger`, source Ghost, sheet venator)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | hold-auto | hold-auto, 0.12 s a round, 30-round drum | match | D "HOLD to fire"; S:venator 36 |
| RMB | D silent on input; footage shows the lane up 0.6-1.0 s then the throw (sheet cannot tell hold-release from quick-cast) | press only: fires at once, holding adds nothing (`rmb.hold` 0) | differ (owner #112) | O 112 "TAP ONLY"; S:venator 58, 223 |
| E | press, 0.6 s cast bar standing, beam | press, 0.6 s charge standing still, beam | match | S:venator 102; json `e.charge` 0.6 |
| R | press, cursor-placed area, no recast | tap, shell lands on the cursor 1.6 s later, no recast | match | D; S:venator 118 |
| Shift | press = short slide, hold = longer slide | tap (<0.18 s) skid 4.8 m, hold slide 7 m, fires through both | match | D "PRESS ... HOLD"; json `dash.tap_t` |

## Kael (`juggernaut`, source Brall, sheet juggernaut)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | press = melee series, hold-charge = ranged fireblast | press = slashes, hold = Searing Wave that grows with the hold (`lmb_override`) | match | D; S:juggernaut 18; greatsword `charge_time` 1.0 |
| RMB | press slam, hold-charge lunge (release), air press = air slam, during chain = spin | same four contexts; guard 0.3 s, held with no cap (`rmb_auto_t` INF), perfect-release flash is ours | match (perfect release is owner) | D; DECISIONS "Kael: RMB held indefinitely" |
| E | press throws, recast pulls you in | press throws, recast hauls you; the chain holds 5 s | match; window unsettled (source tether lifetime not read) | D; S:juggernaut 21, 103 |
| R | press, guard then automatic strike, no recast | press, guard 0.65 s then lunge, no recast | match | D; S:juggernaut 198 |
| Shift | press, several charges | press, 2 charges (3rd at rank 2) | match (count is not input) | D; S:juggernaut 20 |

## Lace (`archer`, source Myth, sheet pin)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | hold-charge, release, two stages, perfect-release window | same, Empowered then Supercharged, perfect release speeds the next draw | match | D; S:pin 20; W archer.md |
| RMB | D: hold-charge, release. Footage sheet: a tap fires uncharged | hold-charge, release; a tap before 0.15 s does nothing and costs nothing; auto-looses 3 s after full | unsettled (D against footage; W settles for D) | D "HOLD to charge, RELEASE"; S:pin 21; W archer.md row RMB |
| E | press | press | match | D; S:pin 23 |
| R | press, then the next 3 charged shots need no charge, 6 s | press, next 3 LMB presses nock 0.5 s then loose a piercing arrow, 6 s window | match | D; S:pin 251 ff; W archer.md Starpiercer |
| Shift | press = roll then Phase Walk | press = roll then Spirit Walk 2.8 s | match | D; S:pin 22 |

## Cinder (`ashwick`, source Felix, sheet linwick)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | hold-auto | hold-auto stream (`ashwick_hose.gd`) | match | D; S:linwick 15 |
| RMB | D silent; footage: press, a lane shows, then it fires | hold (guard 0.15 s) shows the lane, release fires; a tap fires at once | match | S:linwick 16; json `rmb.hold` 0.15 |
| E | press | press | match | D; S:linwick 18 |
| R | press, flies; footage: ends at the end of the flight or on a recast | press, flies 1.8 s, press again lands early (`ult_recast`) | match; window 1.8 s ours, flight length source unread | S:linwick 226 |
| Shift | press, 2 charges | press, 2 charges | match | D; S:linwick 17 |

## Meeko (`tender`, source Elluna, sheet mooshmoosh)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | hold-auto / tap | hold-auto, alternating hands | match | S:mooshmoosh 25 |
| RMB | footage: hold to aim with a telegraph, release fires | press, then a fixed 1 s wind-up with a short lane, throws by itself; not holdable (`rmb.hold` absent) | differ (owner #118) | O 118, 118b; S:mooshmoosh 62 |
| E | press (ring on you), recast throws it to the cursor | press, E again throws to the cursor (up to 9 m) while the 2.5 s ring is up | match; window 2.5 s both | D "zone 2.5s ... reactivate to throw"; S:mooshmoosh 92 |
| R | press with an ally under the cursor, ~5 s channel, walk freely, no recast | same, 5 s tether, press while it runs is swallowed (`ult_recast` true) | match | D; S:mooshmoosh 221 |
| Shift | press, own air-dash slot | press hop, air press = long glide on its own 14 s cooldown | match | D |

## Tenzo (`dolm`, source Tetra, sheet breah)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | tap = boulder, hold-charge + release = punch | same (`lmb_override`, tap threshold in json) | match | D; S:breah 23-24 |
| RMB | hold-charge, release slam; jump while charging leaps | tap = small immediate slam, short hold (capped, auto-fires) = hop then slam, jump while holding leaps further | differ (owner #61) | O 61; D |
| E | press | press | match | D; S:breah 27 |
| R | tap, or hold-drag to set the angle | tap, or hold the key and drag, release casts | match | D "TAP ... HOLD and drag"; S:breah 28 |
| Shift | press, one dash with a rock | Rock Hop: press, then press again within 0.6 s of each take-off, up to 3 hops | differ (owner #111) | O 111; DECISIONS 2026-11-08 lists it as a recast |

## Grimble (`dredge`, source Kingpin, sheet dredge)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | hold-auto / tap | hold-auto, one shot per 0.5 s | match | S:dredge 49 |
| RMB | tap, line hook | tap (`rmb.hold` 0) | match | S:dredge 25 |
| E | press (slam) | press; in the air smashes straight down | match | D; S:dredge 118 |
| R | footage: one press, two waves 0.6 s apart, he stands planted | press, 1.1 s fan charge, two waves; he may walk slowly | match in input; walking differs (owner #36) | S:dredge 143 correction, 254; O 36 |
| Shift | press | press, 3 chained charges, air pounce own slot | match | D |

## Neve (`rimewright`, source Celeste, sheet tamsin)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | hold-auto | hold-auto barrage | match | D; S:tamsin 17 |
| RMB | tap, lands at the cursor | tap fires at the cursor; holding past 0.2 s shows the landing ring and release throws | match+ | S:tamsin 18; W rimewright.md row RMB; json `rmb.hold` 0.2 |
| E | press, recast freezes it | press, E again while it slides freezes it 6 s | match; window = the 4.5 s slide, source not read | D; W |
| R | press; recast any time cancels, a late recast stuns | press; recast breaks the shell with no stun until the last 0.75 s of 3.5 s, then it cracks early at 0.67 damage | match in shape; window unsettled (ours last 0.75 s, footage "about 3.2-3.5 s") | D "Reactivate early to cancel"; S:tamsin 222 |
| Shift | hold-drag skate, release stops; air press skates in the air | hold skate (11.5 m/s, 1.6 s cap), release stops, air press skates at once | match | D "HOLD to skate"; S:tamsin 19 |

## Albert (`bulwark`, source Oath, sheet bjorn)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | tap throws the hammer, tap again recalls; hold-charge swing, release | same; the hold spins the hammer; a release on the flash launches him | match (spin and launch are owner) | D; O 49, 59; S:bjorn 22-23 |
| RMB | hold = shield up | hold (guard 0.1 s) | match | D; S:bjorn 24 |
| E | press, at the planted hammer (on you if it is in hand) | press, light on the hammer or on you, 1 s delay | match | D; S:bjorn 26 |
| R | press | press; plant, raise 0.4 s, slam | match | D; S:bjorn 27 |
| Shift | press; with the shield up it is Shield Bash | press 360 Smash; with the aegis up a Shield Charge on its own cooldown | match | D; S:bjorn 25 |

## Motley (`ostra`, source Void, sheet ostra)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | tap / hold-auto; the wait between shots charges the next orb | hold-auto; the wait since the last shot builds size and damage | match | O 60; S:ostra 16 |
| RMB | tap, shard cluster | press, short wind-up, shards (json still Shard Snap) | unsettled: owner #136 replaces it with a card flurry, not built | S:ostra 17; O 136 |
| E | press, recast after 0.3 s or more detonates | press, E again from 0.3 s (`min_recast`) pops it; unpopped for 10 s at full size it fizzles | match; the fizzle is ours (source auto-detonate unread) | D; S:ostra 19, 193, 211 |
| R | tap, cursor-placed | tap, dome at the cursor 1 s, then the well | match | D; S:ostra 20 |
| Shift | press, lob lands at the cursor | tap lobs at once; hold shows both ends, release lobs | match+ | S:ostra 18; O 135 keeps the mechanic |

## Sparkle (`mage`, source Joule, sheet vireo)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | tap / hold-auto | hold-auto, 0.65 s a bolt | match | S:vireo 26, 53 |
| RMB | hold-charge, release throws | hold-charge, release; the guard `min_t` 0.33 s; throws by itself at 1.2 s | match; the auto-throw is unsettled (source: "may be automatic at full charge") | D; S:vireo 27, 88, 378 |
| E | press places, hold-drag sets the direction, release commits | same; a tap drags away from you | match | D "HOLD AND DRAG"; S:vireo 29 |
| R | press launches, reactivate (or click) crashes down | press; press again or attack lands; lands alone after 2 s | match; auto-land unsettled (source open question) | D; S:vireo 397 |
| Shift | press = short dash, hold-charge = longer dash | press-and-hold charges the lane (0.6 s, auto at 0.9 s), release streaks; a tap is a short zap | match | D; json `dash.hold` 0.6 |

## Sable (`thief`, source Shiv, sheet dancer)

| Slot | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| LMB | D: bolt (no hold said); footage hold-auto | hold-auto, 0.45 s | match | S:dancer 25 |
| RMB | footage: press, lane 0.4-0.6 s, then the throw | press, short wind-up with the lane, throws by itself (`rmb.hold` 0) | match | S:dancer 26 |
| E | press throws, recast teleports; forced after 6 s | press throws, E again blinks; steps there alone after 6 s | match | D "after 6s ... MUST teleport"; json `e.time` 6 |
| R | press | press, ring 2 s | match | D; S:dancer 362 |
| Shift | press | press cartwheel | match | D; S:dancer 27 |

## Recast windows in one place (the 2026-11-08 two-step rule)

| Recast | Source window | Ours | Verdict |
|---|---|---|---|
| Void E, Motley | from 0.3 s, bomb grows 6.5 s [S:ostra] | from 0.3 s, grows 6.5 s, fizzles 10 s at full | match, fizzle ours |
| Shiv E, Sable | until 6 s [D] | 6 s | match |
| Elluna E, Meeko | while the 2.5 s zone is up [D] | 2.5 s ring | match |
| Celeste R, Neve | any time cancels; late stuns [D, S] | any time; late stun in the last 0.75 s | unsettled (window) |
| Brall E, Kael | while attached, lifetime unread | 5 s | unsettled |
| Joule R, Sparkle | second press lands, hover 1.6-2.0 s seen | 2 s then auto-lands | unsettled (auto-land) |
| Felix R, Cinder | ends on a recast [S:linwick 226] | 1.8 s flight, recast lands early | match |
| Tetra Shift, Tenzo | none (plain dash) | 0.6 s per hop, 3 hops | differ (owner #111) |
| Oath LMB, Albert | hammer stays planted until recalled [D] | until recalled | match |

## Result

60 rows (12 Hunters x 5 slots): 52 match, 2 match+, 4 differ with an owner item (Vex RMB, Meeko RMB, Tenzo RMB, Tenzo Shift), 2 unsettled
(Lace RMB, Motley RMB). Five more rows are marked match but carry an unsettled recast window or auto-end (Kael E, Neve R, Sparkle RMB and R, Cinder R); see the recast table.
I found no input-mode mismatch that is clear and not already covered by an owner note, so no game code
changed and no combo check was added: a row marked match is asserted by the Hunter's existing `--<id>-combo-check`.

**Follow-ups (not built, owner or a source read decides).**
1. Lace RMB: a tap that fires uncharged (footage) against "a tap does nothing" (ours, data wins). Needs the owner's call; a change is `rmb.hold` handling in `archer_kit.gd` `fire_rmb`.
2. Vex RMB: the footage lane-while-held against owner #112 TAP ONLY; stays tap-only unless the owner reverses it.
3. Neve R late-recast window (0.75 s ours against about 0.3-0.5 s in the footage) and Sparkle R / RMB auto-land and auto-throw: read the source for a hard maximum.
4. Kael E tether lifetime: the source never says; ours is 5 s.
5. Motley RMB: json and card still say Shard Snap while owner #136 asks for a card flurry; settle which is current.
6. Neve RMB and Motley Shift accept a hold the source does not have (match+). Harmless, and each hold animation is gated on that hold, so nothing shows without its input.
