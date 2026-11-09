# Kael the Unbroken (archetype id `juggernaut`, heavy)

Display name is the class title The Unbroken; the id, file names and code names stay `juggernaut`.

Branch history: kits2 ported the kit from the source hero, kits2-nor (Nov 2) removed its R, ext/kitfix-dancer-juggernaut matched it to the footage, and the ult pass (server update 6) gave him his own ultimate back on X. Player-facing
names and text are ours; the source is named only in this research section, in docs/ARCHETYPES.md and in
docs/wiki/Inspirations.md.

## Research summary

- **Source hero:** Brall, from SUPERVIVE (supervive.wiki.gg ability text, levels 2-4, patch history).
  Version chosen: the wiki's current page as read on Nov 1, with the patch notes' shapes where they differ.
- **Patches that shaped it:** *Leveling Rework + Big Balance Patch* (LMB hitbox -20%, sweet spot moved to the
  central tip, the 3rd/4th-hit bonus removed, Flame Step charges, R no longer resets on Wisp execution) and
  *Gold + Mobility + Discord Patch* (Adaptive Strike cast 0.35 -> 0.55s with a warning icon and free aim,
  Execution x2 -> x1.5 below 35%, the chain breaks on stun and cannot be thrown rooted or grounded, dash
  wind-down frames, turning restricted after RMB into Shift).
- **Disagreements:** two guides say "double damage" to the wounded and a "four-hit combo with later hits
  stronger"; both are pre-patch, so the wiki wins. The Flame Step cooldown is 13s in the header and 11/9/7/6 in
  the notes; we use the notes' shape.
- **Not reproduced:** mana, climbing double-height walls, dodges building Rage, Volcanic Rebuke sending a
  knocked hunter straight to the deathbox, the turn lock after RMB into the dash.

## Upgrade parity (rank 2 = source tier II, rank 3 = tiers II+III+IV)
Source: Brall, `Upg:` lines. Slots the source gives no cooldown or damage upgrade read 1.0 from `rank_cd` / `rank_dmg`.

| Slot | Source upgrade | Ours before (rank 2 / 3) | Ours after (rank 2 / 3) |
|---|---|---|---|
| RMB Smash | +20% damage x2; Meteor Drop rests 2.4s less at IV | cooldown 1.8s / 1.6s, damage +15% / +30% on top of Smash +20% / +40%; drop 7.2s / 4.8s | cooldown 2s flat, Smash damage +20% / +40%; drop 7.2s / 4.8s |
| Space Rampage | -1.6s recharge x2 (a 3rd charge), tier IV: a dodged shot feeds Rage | 8.8s / 7.3s (the old text said 9s -> 7.6s) | 8.8s / 6.4s; 3rd charge at 2, dodge feeds Rage at 3 |
| E Warchain | -1.6s cooldown x2, tier IV: -3.2s more | 11.2s / 8.0s in play (the text said 9.5s -> 8.3s / 5.9s), damage +15% / +30% | 11.2s / 8.0s, damage unchanged (source has none) |

## Scaling

Brall's scale (slash 20 with tip +20, Execution Slam 70, Lunge 45, Obsidian Slam 52, Spin 54, Flame Step 18
with tip 36, R 130) is kept as ratios: slash 8 (tip 16), Slam 26, Lunge 14 to 22, Meteor 18, Spin 18, Rampage 7
with tip 14, Gilded Riposte 34 (the footage's 396 against a 94 slash, 4.2x; its 21.7s cooldown is about 2.3 Tether
Chains, so ours is 22s against the Warchain's 9.5s). Rank 2 is the shared step (cooldown -10%, damage +15%); rank 3 carries the level 2-4
specials. Data pass (SERVER_UPDATE7): the Meteor Drop has its own 7.2s slot (9s against the Smash's 2.5s, kept as the
ratio 3.6x of our 2s), 2.4s shorter at rank 3 (the -3s as a third of its cooldown); the Rampage tip no longer stuns into
a wall; the Rampage starts on 2 charges and takes the third at rank 2; the Warchain loses its refund for the data's
-2s three times (12.5% of its cooldown each, merged: 12.5% at rank 2, 37.5% at rank 3); every Smash gets +20% at rank 2 and
again at rank 3.

## Per-slot table

Updated by ext/kitfix-dancer-juggernaut (server update 5) against the footage reference sheet
(`briefs/hero-ref/juggernaut.md`) and the owner's playtest notes.

| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Rage | none | Damage fills Rage (a Searing Wave 3x as fast); full = Enraged 6s: +15% damage, +12% dash recharge, +20% cooldown speed, a roar. A knock heals 20% of the knocked hunter's max health, with a green heal column and a red screen tint for you | Fighting Spirit: damage makes you Empowered; knocks heal | Duration is ours |
| LMB, Greatsword | tap, hold | Wide (175 degree) slashes of 8 every 0.34s, alternating, a two-tone crescent (magenta edge, flame-yellow fill), double at the tip with a white star; hold: a ring round the body fills, then a red crescent of flame (Searing Wave) flies past the cursor to max range (6 to 10m, 12 to 28) | Quick Attack: alternating 180 degree two-tone crescents, a tip star; hold: a red crescent bolt past the cursor | As the source |
| RMB tap, Finishing Slam | tap | A 0.6s aimed wind-up (blade cocked low behind) behind a short magenta strike lane everyone sees, then a 4m strike: 26, +50% under 35% (foes that low wear a red outline while the Smash is ready); its sweet spot is the far tip (2.4 to 4.2m within 18 degrees): knock that foe within 2s and the Gilded Riposte (X) is ready again | Execution Slam: red outline on executable foes, a short magenta lane, about 2.4 bh, a sweet-spot knock resets Retaliation | As the source; the crash fold is gone (see "Ult choice") |
| RMB hold, Lunge | hold, release | A crouched, coiled wind-up; a lane grows ahead (4.5 to 7.5m) with a fill and turns magenta with a flash and a ping at full (0.8s); a rising whine; the cursor ring fills; you can jump while charging; release flings you forward into the first foe: 14 to 20, a huge white burst and a red slash across them; striking nothing doubles the cooldown | Charge Dash: red lane growing, magenta at full, about 5m, 559 to 771 | Owner: fling far, so the length grows with the charge |
| RMB air, Meteor Drop | in the air | A purple disc under the cursor (5m at most) shows while it's ready. Press: a 0.2s hang (blade hauled overhead, knees tucked, one turn) sliding over a marker everyone sees (the 2.6m disc and the 1.2m stun core), a straight vertical slam down onto it with flame streaks (0.22 to 0.4s; owner 113.6), then the landing: a crouch onto the knees, cracks in the ground, a shock ring at the stun's edge, dust and debris, a shake and a deep boom; 18, slow 40%; the core +50% and stunned 0.8s. 0.5s recovery rising from the crouch (planted 0.2s; Shift or a jump moves him out of it at once). Its own 7.2s cooldown (4.8s at rank 3) | Air Slam: a disc at the cursor, ~0.85s airborne from the jump, ~0.5s recovery in a low crouch ([F] 412.0-413.9s) | As the source; press to impact 0.52s (the footage's apex to impact is ~0.55s) |
| RMB in the pull | during E | Cinder Spin, Haul Slam, Chain Lunge (below) | Anti-Heal Spin | As before |
| Dash, Rampage | Shift | 2 charges, a third at rank 2: a 0.07s dip, then 4.5m in 0.17s (x the global dash feel; owner 113.8: much shorter than the 0.15s + 0.3s it was), flat and stretched, and a low recovery with the blade dragging: 7 along it, the tip 14 and a big knock, orange flame streaks; rank 3: a shot dodged through it feeds Rage (+15) | Quick Dash: 3 charges, about 2 bh | As the source; sync62's slower heavy dash kept (0.3s) |
| E, Warchain | tap, recast | 13m (9.5s cooldown): a barbed hook on a wavy orange chain; hooked (foe, blighted) or a wall: a straight striped link chain that stays on as you move, 5s, paying out to 24 m and holding taut there; recast is an impulse in at 22 m/s that your input and facing curve and backing away slingshots; Shift or a jump breaks off; you arrive still moving. See "Warchain: the state machine" | Tether Chain: wavy in flight, striped links attached, 7 bh in 0.4s, pulled 5 bh in 0.4s, 9.4s | As the source, plus our exits |
| X, Gilded Riposte | tap (level 6) | A 0.65s guard: planted (no walk, jump or other button), blade upright, a gold glow and sparks; no damage and no crowd control get through, and each hit blocked (two at most, a metallic ting each) makes the answer 20% harder. A 1.8m x 3.6m strip ahead (it follows the aim) shows to everyone through the guard. Then he lunges 1.8m and cleaves up through it (an upward crescent in his gold, run hot at the edge, and a gold cloud): 34, he heals 80% of what it deals (less while blighted); a knock with it makes it ready at once. About 1.1s in all; 22s cooldown. Landing it on a rival hunter fills the bond | Retaliation: 0.65s invulnerable, then a heavy strike in a rectangle ahead (about 1 x 2 bh), heals 80%, reusable on a kill | As the source; our look (gold guard, upward gold cleave) replaces its red crescent |
| Merge (its own key, `ultimate`) | tap | The Boki Merge | (n/a) | The Merge is the same for every hero |

## Parity pass (owner 18:45, PARITY_BRIEF)

Source vs ours per slot, LMB first. [D] game data (supervive_kits.md), [F] footage (hero-ref/juggernaut.md, 10 fps
in the ability clips), [O] owner notes (MAIN_TO_EXT 17:05-17:12). Asserted in `tools/zedran_feel_check.gd`
("jug parity ...").

| Slot | Beat | Source | Ours | Status |
|---|---|---|---|---|
| LMB tap | animation | [F] 0023-0034: a step into each swing, ~1 frame wind-up and 1 frame swing, alternating right-left; the blade trails behind between swings | `jug_slash_r/_l`: coiled step (0.0), the cut at 0.1, follow-through to 0.24, settled by 0.45; alternating | matches |
| LMB tap | tracking | [F] he walks while swinging; the slash goes toward the aim (some swings look facing-led: unconfirmed) | each slash is aimed at the cursor at the swing; he keeps his full walk | matches (cursor kept: the facing read is unconfirmed) |
| LMB tap | cadence | [F] swings 0.3-0.4 s apart (0026, 0029, 0033) | one slash per 0.34 s | matches |
| LMB hold | charge | [F] 0.6-1.0 s, a thin white arc round him (0087); [O] it grows with the hold, shown while charging | tap 0.22 s, full 0.95 s; the ring round him fills, and now a lane on the ground grows as long (7 -> 14 m) and wide as the wave it would throw, gold-hot at full | changed (the preview is new) |
| LMB hold | projectile | [F] a red crescent bolt at ~20 bh/s (~36 m/s) flying past the cursor to max range; [D] tap 43, hold 107 (2.5x) | 36 m/s (was 20), 7 -> 14 m (was 6 -> 10), hit radius 0.3 -> 0.6 (it was stuck at the grammar default 0.2, so the hitbox never grew), 12 -> 20 (2.5x a slash; was 28), Rage per wave kept (wave_rage 4.2) | changed |
| RMB hold | pose | [O] item 113.3 (overrides the earlier "over his head"): the blade angled forward at the aim, ready to lunge | `jug_lunge_wind`: the blade levels forward at the aim on a loaded back leg; the release drives it straight out (`jug_lunge`) | changed |
| RMB hold | hold time | [O] holdable indefinitely, no auto-release | `rmb_auto_t` = INF (was full + 0.4 s) | changed |
| RMB hold | perfect release | [O] a release at the right moment goes a bit further, with a clear "now" cue and a distinct sound | at full, then once a second: the raised blade flashes white-hot with a ring (0.15 s window); let go in it: +20% distance, the cursor's perfect star, a bright metal ring | new |
| RMB tap / air / chain | all | [F]/[D] | unchanged (matched by the item 21/22 passes: see the per-slot table) | matches |
| Dash, E, X | all | [F]/[D] | unchanged (the item 21/22/51 passes) | matches |

## Audit (Nov 3 23:40)

Every row of briefs/specs/kit-audit/zedran_bjorn_pin.md for Zedran (it audited main 200effce): (a) already done on
this branch, (b) fixed now, (c) not applicable or we disagree. Checks are `--juggernaut-combo-check`.

| Row | Sev | Verdict | Where / why |
|---|---|---|---|
| E pull model (facing, input, slingshot) | HIGH | (a) | ext/zedran-warchain 1ae768d5: an impulse that input and facing curve, backing away slingshots; "jug chain pull: ..." asserts. Speed 22 m/s (footage 5 bh / 0.4 s) over the wiki's 19: the game data has none |
| E tether extend | MED | (a) | 1ae768d5 / 95c291c8: pays out to 24 m and holds there; the length is ours `[?]` (no data, no frame shows a limit; 24 m kept), see "Warchain" |
| E range / cooldown | MED | (b) | cooldown 12.8 s (the data's 16 s at the kit's 0.8x), ranks still -12.5% / -37.5% (8 s at rank 3 = 0.8 x the data's 10 s) |
| E pull exits | LOW | (a) | kept and re-asserted under the new model ("jug pull: Shift exits ...", "... a jump exits ...") |
| E hooked-foe blight | LOW | (b) | no Anti-Heal from the hook alone; the spin blights who it hits (the data's Scorching Spin). "juggernaut E: Warchain hooks (no blight ...)" |
| RMB hold auto-fire, perfect release | HIGH | (a) | ext/parity e6429ccb: held indefinitely, a perfect window at full then once a second (+20%); "jug parity rmb: ..." |
| RMB hold pose | HIGH | (a) | e6429ccb / 097cff7c: the sword over his head; owner 113.3 levels it forward |
| Slam resets X on any knock | MED | (b) | any Finishing Slam hit then a knock within 2 s readies the Riposte; the sweet spot now hits 40% harder (the data's "edge hits do more"). "juggernaut Smash: a knock after any Slam hit ..." |
| RMB tap numbers | - | (c) | fine per the audit |
| Meteor self-shake | MED | (c) | item 50 lands on ext/no-shake; nothing added here |
| RMB during pull / arrival | LOW | (a) | the RMB interaction rows pass under the new pull model (Cinder Spin, Haul Slam, Chain Lunge asserts) |
| LMB tip 2.0x | LOW | (b) | 1.6x (the footage's 151 / 94). "juggernaut LMB tap: a slash, 1.6x at the tip ..." |
| LMB hold Shift-cancel, self-release | MED | (a)+(b) | Shift keeps the charge (item 51, 53820b53); the self-release at full + 0.5 s is gone (the owner's hold scales; no data rule) |
| Shift numbers | LOW | (b) | 9 along it, tip 18 (the data's 49 = 1.14x a slash), cooldown 10.4 s (0.8 x 13) |
| Air dash shove | LOW | (b) | no shove (no source) |
| X cooldown / damage | MED | (b) | 36 s (0.8 x 45) and 43 (the data's 230 = 5.35x a slash) |
| X fx (guard ring, self-shake) | LOW | (b)+(c) | the guard-start ring is gone; the shake is ext/no-shake's |
| Passive / reset rings | MED | (b) | gone: Enrage rings, the Rage-spent ring, the "Riposte ready" ring (a reset), the chain-charge ring, the slam wind-up ring, the sweet-spot mark, the haul's inner ring. Kept: rings the size of a hit area (Meteor core, Haul and Spin radius, the Rampage tip) |
| Self-shake (all) | MED | (c) | ext/no-shake; none added |
| Passive numbers | - | (c) | fine |
| Tall-ledge climb doc | LOW | (b) | the "Not built" row now says built (hunter_move.json `climb_tall`) |
| Docs drift (steer 6 vs 7) | LOW | (a) | the Warchain table now matches the data (1ae768d5) |

## Warchain: the state machine

The owner's review (items 21 and 22) asked for the source's level of control on E. Sources, by precedence:
**[O]** the owner's notes (OWNER_REVIEW items 21/22, the 14:07 ET "small mechanics" note), **[D]** the game data
(`supervive-data/supervive_kits.md`: "Feysteel Chain (16s, 15): tether that attaches to enemies or walls, 30 dmg;
reactivate to pull yourself to the target. Upg: -2s CD x3"), **[W]** the wiki's ability page and patch notes
(https://supervive.wiki.gg/wiki/Brall: tether 5s; the pull is an impulse of 1900 uu/s; the cooldown starts on the
second press or when the chain breaks; a stun breaks it; no throw while rooted or Grounded), **[F]** the footage
notes (`hero-ref/juggernaut.md` E and RMB sections, frames 0301-0366).

**Range.** Neither [D] nor [W] lists one. [F]: on the wall test the chain flies about 7 bh in about 0.4 s
(0303-0305) and bites the wall there, so 7 bh is a floor, not the cap: 7 x 1.8 m = 12.6 m. Ours: **13 m** (was 10 m),
flying at 32 m/s (7 bh / 0.4 s = 31.5 m/s). The pull: [W] 1900 uu/s = 19 m/s at 1 uu = 1 cm; [F] about 5 bh in
0.4 s = 22.5 m/s. Ours: 22 m/s, not scaled by the global dash feel (the pull is not a dash).

**Tether length and the pull model (owner 23:00 UTC: "stays attached while he moves back, extending to a max
length; the pull depends on his facing and movement input: steer, curve, slingshot").** Neither [D] nor [W] gives a
maximum tether length, and the footage never shows one: in the frames (0306-0316) the chain stays on for ~2.5 s
while he moves about, but only ~5-6 bh (~10 m) long, and it is let go by 0320 without reaching a limit (the big
ring on screen there is centred on him: the throw's range, ~6.8 bh). Ours: the chain pays out to **24 m** (about
1.8x the 13 m throw, so backing off is a real choice) and holds there (no break: [W] breaks it only on a stun or
the 5 s). The 24 m is our pick; the owner can set it. [W] makes the pull an impulse (1900 uu/s), not a winch, so his own motion and input shape it:
the pull starts at the reel speed plus a slingshot from his speed away from the anchor (0.8 of it, up to +10 m/s),
his sideways speed carries in, and he flies a circular arc (at most 6 rad/s) to a point beside the anchor.

**The swing (owner item 57, 18:54 UTC Nov 4: "you fly somewhat in the direction you're facing").** Neither [D], [W]
nor [F] gives a steer limit (the footage's pulls are all straight), so the owner's description sets it. Looking 90
deg aside puts that point 36% of the chain's length beside the anchor (`swing`, up to `steer_max` 6 m; it follows the
input at `steer_rate` 24 m/s), which is an arc of about 40 deg at any length up to 16 m: 4.6 m aside at 13 m, about 3 m at
9 m, about 2 m at 6 m. A key held across stacks with the look (`face_k` 1.0: they count the same), still up to 6 m, and
a key against it cancels it. The speed never changes in the curve, and he arrives along it. The chain bows toward
the swing, and his own screen shows a faint predicted arc while he holds aside, hooked or in the pull.

The numbers live in `e` in content/archetypes/juggernaut.json; the code is `JuggernautChain`
(scripts/arch/kits/juggernaut_chain.gd).

| State | Event | Next state and result | Source |
|---|---|---|---|
| Ready | E | Throwing: the hook flies toward the cursor (13 m) | [D] [F] |
| Ready | E while rooted, Grounded, stunned or on cooldown | stays Ready, the deny buzz | [W] 05.02.25 |
| Ready | E with the Lunge charging (RMB held) | Throwing; the charge is kept (release once hooked = Chain Lunge) | ours |
| Throwing | hits a foe (hunter, monster or foe Boki) | Hooked to a foe: 8 damage, blighted while tethered (healing barely takes) | [D] [W] anti-heal |
| Throwing | hits a wall or a block | Hooked to a wall | [D] |
| Throwing | passes an ally or your own Boki | keeps flying (it only bites foes and walls) | [D] "enemies or walls" |
| Throwing | reaches 13 m, or drops into the abyss | Missed: "MISS", the cooldown starts | [W] 07.01.25 |
| Throwing | E pressed in flight | remembered for 0.12 s: if it hooks in that time, the pull starts on the hook | ours (buffer) |
| Throwing | stunned | Missed (the chain breaks), the cooldown starts | [W] 05.02.25 |
| Hooked (foe or wall) | time | the link chain stays on while you walk, jump, glide or dash, 5 s, then breaks; the cooldown starts | [W] 5 s; [F] 0305-0317 |
| Hooked | he backs away (or the foe walks off) | the chain pays out; the links pull straight and glow hotter past 85% of its length, a creak as it tightens | [F] 0305-0317 tension |
| Hooked | at its full length (24 m) | it holds: whoever is moving away (him, or a hooked foe) is stopped at the end of it, with a hard creak; it never breaks for length | [O] 23:00; [W] breaks only on a stun or the time; the length is ours (no data, no footage) |
| Hooked | E | Pulling (the cooldown starts): an impulse toward the anchor at 22 m/s | [D] [W] impulse |
| Hooked | E while moving away from the anchor | Pulling, slingshot: +0.8 of his speed away (up to +10 m/s) | [O] 23:00; [W] an impulse adds to his motion |
| Hooked | E while strafing | Pulling, swung out that way: his sideways speed carries into the start | [O] 23:00 |
| Hooked | E with the Lunge charging | Pulling with a Haul Slam armed for the arrival | ours |
| Hooked | he holds aside | the chain bows that way and his screen shows the predicted arc | [O] item 57 |
| Hooked | stunned, or the foe is downed or gone | Broken: "CHAIN BROKE", the cooldown starts | [W] 05.02.25 |
| Hooked | a Boki merge starts | Broken | ours |
| Pulling | each step | you fly at the pull's speed along a circular arc (at most 6 rad/s) to the anchor (a hooked foe is followed as it moves), height held, across gaps | [W] impulse; [F] 0333 |
| Pulling | facing aside (the cursor off the chain's line) | you swing out that way, 36% of the chain's length at 90 deg (up to 6 m): a ~40 deg arc that lands beside or past the anchor | [O] item 57 |
| Pulling | movement held across the pull | the same swing, stacked with the facing (still up to 6 m) | [O] 14:07 note, 23:00, item 57 |
| Pulling | Shift | the pull ends and the Rampage goes the way you dash (exit) | ours (no source footage) |
| Pulling | jump | the pull ends in a jump that keeps 70% of its speed (slingshot included) along the heading (a chain launch); the glider takes it too | ours |
| Pulling | E | ignored (no second pull, no stop) | ours |
| Pulling | stunned, rooted or knocked | the pull stops dead | [W] stun rule |
| Pulling | reaches the foe (contact) or the wall (0.7 m off it), passes it alongside within 3.5 m, or runs 0.5 s past its expected time | Arriving | [D] [F] |
| Arriving | (0.25 s window) | you keep 35% of the pull's speed (slingshot included) along your heading (momentum into the next move); an armed Haul Slam lands | [O] "arrival keeps momentum" |
| Arriving | over the abyss | you fall from the pull's height (the glider works) | ours |
| Arriving | window over | Ready again (on cooldown) | |

Ranks: the cooldown is 12.5% shorter at rank 2 and 37.5% at rank 3 (the data's -2s three times, as shares of our
9.5 s; [D]). The wiki's older rank 4 refund on a hooked foe is not in the data, so it's not built.

## RMB: the interaction table

What a Smash press does, by state. "Press" fires on the press; "tap" fires on a release under 0.3 s; "hold" on a
release after it. A press while a heavy move runs (the Slam's wind-up, a Lunge, a Meteor Drop and its recovery)
is held for 0.12 s before it ends and goes off when it does; earlier presses are ignored, never doubled.

| State | RMB | Result | Source |
|---|---|---|---|
| Ground | tap | Finishing Slam: 0.6 s wind-up behind a magenta lane, then the 4 m strike | [D] [F] 0154-0158 |
| Ground | hold, release | Lunge: the lane grows (magenta at full), fling 4.5 to 7.5 m | [D] [F] 0121-0146 |
| Ground, Lunge charging | jump, release | the Lunge goes from the air along the aim | ours (owner note) |
| In the air (a jump, a ledge, a chain launch) | press | Meteor Drop at the cursor (5 m reach): 0.2 s hang over the marker, the dive, the impact, 0.5 s recovery; its own cooldown | [D] [F] 0251-0300 |
| Throwing (chain in flight) | any | as on the ground or in the air; the throw goes on | ours |
| Hooked, on the ground | tap | Finishing Slam; the chain stays on | ours |
| Hooked | hold, release | Chain Lunge along the chain to its anchor (x1.25, a short stun on the foe); the chain is spent | ours |
| Hooked, Lunge charging | E | Pulling, then a Haul Slam on arrival (2.8 m, stun 0.25 to 0.6 s) | ours |
| Pulling | press | Cinder Spin at once (2.6 m, blights 4 s); the pull goes on | [D] "DURING Feysteel Chain pull" |
| Arriving (0.25 s) | press | Cinder Spin | [F] 0333-0336 (RMB on arrival) |
| Arrived, window over | tap / hold | Finishing Slam / Lunge from where you stand, with the carried speed | |
| Arrived beside a foe | tap | the Slam hits as a body hit (you're 1.2 m off, inside the 2.4 to 4.2 m sweet spot); a wall pull or a steered pull that leaves them 2.4 to 4.2 m ahead gets the sweet spot | no special rule (source: edge hits) |
| Jumped out of a pull | press | Meteor Drop | ours |
| Rampage (its crouch counts) | any | ground: fires mid-dash, the drive carrying him into it; air dash: ends the dash and the Meteor Drop begins | content/dash_flow/juggernaut.json (docs/heroes/dash_interactions.md) |
| Slam wind-up | Shift | a Slam Drive: the drive goes at once (no crouch) along the strike's aim, the Slam's overhead pose kept, and the Slam lands where it arrives | dash_flow `into_dash.rmb` ("RMB into Shift", turning restricted) |
| Meteor Drop hang | Shift | the air dash goes at once; the dive then comes down onto the marker from where it took him | dash_flow `into_dash.rmb` (item 51) |
| Lunge, Meteor Drop dive | Shift | each is a dash of its own: Shift goes the step it ends; the drop's recovery dashes (or jumps) at once | dash_flow `into_dash.rmb` |
| Searing Wave charging | Shift, jump | the charge waits through the Rampage or the air dash (and charges on in a jump); let go in it, the wave goes as the dash ends | dash_flow `hold.lmb` (item 51) |
| Gilded Riposte guard, cleave, a chain held | E | owner 113.7: the chain hauls him in with the guard up (it holds past 0.65 s while a hooked foe comes up); the cleave goes as they come into its reach. E in the cleave's own moment pulls as it lands | `jug 113.7` |
| Gilded Riposte guard, cleave | glide | owner 113.2: shut; the recovery (the last 0.35 s) is open, a glide there ends the rest of it | `jug 113.2` |
| RMB held | glide | owner 113.2: shut, a jump never opens the glider while RMB is held | `jug 113.2` |
| Finishing Slam wind-up | E | owner 113.5: both go: the hook flies at the cursor, the Slam strikes the way it was started | `jug 113.5` |
| Gilded Riposte guard, cleave | Shift / jump | Shift held to the step the cleave lands; no jump (planted, as the source); in the recovery after it either goes at once | dash_flow `into_dash.x`, `into_jump.x` |

Differences from the source, and why:
- **The Haul Slam and the Chain Lunge** are ours (the source has only the spin in the pull); they give the hold
  a meaning while chained instead of a plain Lunge away from the chain.
- **During the pull a press spins at once** (the source's Scorching Spin) rather than waiting to tell a tap from a
  hold; a held Smash only becomes a Haul Slam when it was already charging before the pull.
- **Exits:** the footage never shows a dash or a jump in the pull; we let Shift cancel it and a jump launch out of
  it, so it never locks you in.
- **The tether length** (24 m, held taut there) is ours `[?]`: neither the data nor the footage shows one. Re-checked 11-09
  (`supervive_kits.md` Brall rows, `kit_comparison.md`, `supervive_physics.md`, `hero-ref/juggernaut.md` 0301-0366): the
  only numbers are the throw (7 bh on the wall test, ~12.6 m, a floor; our 13 m) and the pull (5 bh in 0.4 s). The chain
  stays on while he walks ~2.5 s at ~3.9 m/s, so the leash is at least ~10 m; no frame shows it taut or breaking. Kept 24 m.
  Revisit when a frame shows the chain longer than the throw. Alternative not taken: leash = throw range would end the extend-on-retreat the owner asked for.

## Ult choice

The Boki Merge is the same for every hero, on its own key; the hero's own ultimate is on the `hunter_ult` key (default X).
kits2-nor had folded the old Doomfall (crash, heal, reset on a knock) into the Finishing Slam's sweet spot. With the
Gilded Riposte on X that fold duplicated the ultimate (a big hit that heals you, re-armed by a knock), so it is
unfolded: the crash is gone and the Slam is back to the source's Execution Slam, whose sweet-spot knock resets the
ultimate (now the X cooldown).

## Body and movement (hero sheet "Body, scale and movement feel")

- Model about 1.12 of a medium (`body.size` 0.95 on the heavy build), hunched: about 0.35 rad run lean;
  hit radius 0.428 (`body.hit_r`, docs/HITBOX_SIZE.md).
- Nameplate height 2.75 m (`body.plate`, `Arch.plate_y`).
- Rampage: a 0.07 s dip (planted), then 4.5 m in 0.17 s, then a short low recovery (owner 113.8)
  (keys end at 0.9 s). Its after-images are his own orange flame streaks.
- The Enraged look is embers and dark drips on his body; no ground disc or light under him.

## Assumptions (where the footage is silent; easy to change in content/archetypes/juggernaut.json)

1. **Quick Attack direction:** the slashes follow the aim (cursor), not the movement direction.
2. **0154-0158 was the tap** (Finishing Slam), not the hold on an executable target.
3. **Air Slam reach:** 5m from under you, clamped; height doesn't add damage.
4. **Empowered** is our Enraged (6s, the numbers above); the hold-blast range is 6 to 10m.
5. **Lunge length:** grows 4.5 to 7.5m with the charge (owner: release flings you far), against the footage's fixed 5m.
6. **Jumping while charging** keeps the charge, and the release lunges from the air along your aim.
8. **Retaliation, hit during the guard:** the strike still comes at the end of the 0.65s (no early strike); each
   hit blocked adds 20% to it, two at most. The footage's dummy deals no damage, so this is ours.
9. **The guard is committed:** no dash or other button cancels it; the strip follows the aim until the strike.
10. **The reset** counts a knock (down) on a rival hunter with the cleave; monsters don't reset it.
11. **Invulnerable means everything but the abyss:** a fall still counts; damage over time is blocked too.
12. **The bond:** paid when the cleave lands on a rival hunter (a hit, a knock or a kill, the best of the cast) by
    `HeroUlt.landed`, which calls the main session's `KinBond.from_ult` once it exists; a miss or a monster pays nothing.

## Small mechanics

From the wiki's ability page and patch notes (https://supervive.wiki.gg/wiki/Brall) and the owner's notes.
"Built" means it is in the kit and asserted in `--juggernaut-combo-check` / `--kit-combo-check`.

| Mechanic | Source | Footage | Ours |
|---|---|---|---|
| The tether pull can be steered sideways while you're pulled in | owner's playtest note, item 57 | not visible | Built: looking aside or a held key swings the arrival up to 6 m aside; asserted "jug swing: ..." (13 m: 4.6 m, 41 deg, full speed) |
| Chain cooldown starts on the pull or when the chain breaks, not on the throw | wiki patch 07.01.25 | n/a | Built (kits2), asserted |
| A stun on Brall breaks the tether; it can't be thrown rooted or Grounded | wiki patch 05.02.25 | n/a | Built (kits2), asserted |
| The chain's cooldown drops 2s three times | owner's game data | n/a | Built: 12.5% at rank 2, 37.5% at rank 3 (the hook refund is gone) |
| The tether stays attached while you walk (about 2.5s+) | footage 0305-0317; wiki 5s | yes | Built (5s), drawn as a link chain |
| The Fiery Lunge doubles its cooldown if nothing is struck | wiki RMB | n/a | Built, asserted |
| The Execution Slam aims freely during its cast, with a warning over the head | wiki patch 05.02.25 | yes (lane at 0157) | Built: free aim, and a strike lane everyone sees |
| Execution: x1.5 under 35% | wiki patch 05.02.25 | yes (red outline 0154) | Built, plus the red outline while the Smash is ready |
| The dash has wind-down frames: no glide straight out of it | wiki patch 05.02.25 | n/a | Built (kits2), asserted |
| A knock restores one dash charge (not all) | wiki Shift | n/a | Built |
| Flame Step's tip deals double | wiki Shift | yes (0401) | Built |
| Obsidian Slam's centre ring stuns and deals +50% | wiki RMB | yes | Built |
| The slam lands where you aim in the air | footage 0263, 0286 | yes | Built (5m reach), asserted |
| Brall climbs double-height walls by jumping while facing them | wiki passive; data bCanWallJump (supervive_physics.md:67) | no | Built on main: `climb_tall` in content/rules/hunter_move.json, read by hunter_move.gd |
| Dodging shots during the dash builds Empowered (top rank) | owner's game data | no | Built at rank 3: the perfect-dodge hook feeds 15 Rage |
| The Obsidian Slam has its own cooldown slot (9s, -3s at the top) | owner's game data | n/a | Built: 7.2s, 4.8s at rank 3; the Smash stays ready |
| The Flame Step tip does not stun into walls | owner's game data | n/a | Built: the wall stun is gone |
| Turning is restricted when the dash follows an RMB | wiki patch 05.02.25 | no | Not built (a turn lock reads as lag in our camera); Assumption 7 |
| The ult: 0.65s of invulnerability, then the strike | wiki R | yes (ult f33-f39) | Built: blocks every hit and its crowd control; asserted |
| The ult heals for a share of the damage dealt (80% on the newer card) | wiki R, in-game card | n/a | Built (80%); asserted |
| No heal while anti-healed | wiki patch 08.21.2024 | n/a | Built through blight (healing barely takes); asserted |
| No jumping during the ult | wiki patch 08.21.2024 | yes (planted f33-f38) | Built: planted, no jump; asserted |
| Killing a living enemy with the ult resets it (data: "Killing a living enemy with it resets its CD"; footage: reusable at once after the kill) | wiki R, in-game card | yes (ult f99-f101) | Built: the cleave's own hit takes a hunter down (our lethal hit is a knock, the source's kill): cooldown to 0 at once, no other window. A plain hit resets nothing; a hunter already down takes nothing from it; a monster or a wisp resets nothing. Shared path: `HeroUlt.landed` names the result, `HeroUlt.reset` clears the cooldown; asserted |
| A sweet-spot Execution Slam knock resets the ult | wiki RMB | n/a | Built (within 2s of the sweet spot); asserted |
| No reset from monsters or wisps | wiki patch 22.01.25 | n/a | Built: hunters only |
| He lunges about 1 bh into the strike | footage ult f39 | yes | Built (1.8m); asserted |

Assumption 7: the dash after an RMB turns freely; the pull keeps 35% of its speed as you arrive (the owner: "arrival keeps momentum").
Also ours (no footage): the pull exits (Shift, a jump) and the 0.12s input buffer are ours; the footage shows none of them.

## Cancels (ability to ability)

What a second press does during the first action's wind-up, active part and recovery: **cancels** it (the first
ends), **both** (the second goes now and the first runs on), **waits** (buffered, and for how long) or **ignored**.
Dash rows (Shift either way) are in [dash_interactions.md](dash_interactions.md), not repeated here. Sources: [D]
briefs/supervive-data/supervive_kits.md, [F] the footage sheet (5 fps: one frame is 0.2 s, so a buffer shorter than
that can't be seen), [W] the wiki page linked above, owner = DECISIONS / OWNER_REVIEW_1103. Ours is origin/main
d255acbee, read in the code and probed headless (cancel-matrix pass, 11-09). **Unsettled** means no frame, card
line or wiki line shows the pair: ours stays as it is and nothing was guessed. Any pair not in the table: both
(ArchKit has no shared cast lock), except that every press is ignored, not buffered, while stunned or downed,
and the attack key does nothing from a glide (`Hunter.can_fire`).

| First (phase) | Second | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|---|
| RMB Finishing Slam, wind-up (0.6 s) | LMB | not shown | both: the slash goes at once (the wind-up doesn't hold the blade) | unsettled | [W] gives a 0.55 s cast time, nothing on presses in it |
| Slam wind-up, Lunge, Meteor Drop and its 0.5 s recovery | RMB | not shown | waits: a press in the last 0.12 s goes when the move ends; earlier presses are ignored | unsettled | |
| Slam wind-up | E | not shown | both: the hook flies, the Slam strikes the way it was started | owner | `jug 113.5` |
| Slam wind-up | jump | not shown | both: a 0.8 m hop, the wind-up goes on | unsettled | |
| Slam wind-up | X | not shown | both: the guard starts and the wind-up runs on under it | unsettled (flagged below) | |
| RMB held (Lunge charge) | jump | not shown | the Lunge goes from the air along the aim | owner | interaction table |
| RMB held | glide | not shown | shut | owner | `jug 113.2` |
| RMB held, chain hooked | E | the source has only the spin in the pull | pull, then a Haul Slam on arrival | ours (flagged below) | [D] |
| Lunge, Meteor Drop (active) | LMB | not shown | waits 0.12 s, then the slash | unsettled | |
| Lunge end (wind-down) | glide | "winddown frames where Brall can't immediately enter a glider state" | shut for 0.35 s after the Lunge | match (the length is ours: the patch gives no number) | [W] patch 05.02.25 |
| E Warchain, pulling | RMB | Scorching Spin "DURING Feysteel Chain pull" | Cinder Spin at once, the pull goes on | match | [D] |
| E hooked | E | "reactivate to pull yourself to the target" | pulls | match | [D] |
| X Gilded Riposte, guard and cleave (0.65 s) | jump | "Brall can no longer jump while using Volcanic Rebuke" | ignored until the cleave lands; in the recovery a jump goes at once | match | [W] hotfix 08.21.2024; content/dash_flow `into_jump.x` |
| X guard and cleave | LMB, RMB | not shown | ignored (busy) | unsettled | [F] ult f33-f38 (planted) |
| X guard and cleave | E | not shown | ignored, except a held chain hauls him in | owner | `jug 113.7` |
| X guard and cleave | glide | not shown | shut; open in the last 0.35 s, which a glide ends | owner | `jug 113.2` |
| LMB slash, recovery (about 0.32 s) | LMB | not shown | waits 0.25 s, then the next slash | unsettled | |
| LMB slash recovery | RMB, E | not shown | both: the Slam or the hook goes at once | unsettled | |
| LMB held (Searing Wave charge) | jump | not shown | the charge goes on through the jump | ours | content/dash_flow `hold.lmb` |
| LMB held | RMB, E | not shown | both: the charge goes on | unsettled | |

Fixes made: none (every source line above already matches).

## Combinations

All are scripted in `--kit-combo-check` (also inside `--archetype-check`) and `--juggernaut-combo-check`
(tools/dancer_jug_check.gd).

| Sequence | Result | Check |
|---|---|---|
| E (hooked), E (pull), RMB tap | Cinder Spin | `combo jug: E > E > RMB tap = Cinder Spin` |
| E, hold RMB, let go | Chain Lunge along the chain | `combo jug: E > hold RMB = Chain Lunge` |
| E, hold RMB, E while holding | Haul Slam on arrival | `combo jug: E > hold RMB > E = Haul Slam on arrival` |
| E, E, hold RMB | the Cinder Spin on the press (no Haul Slam) | `combo jug: E > E > hold RMB = Cinder Spin on the press` |
| Every Warchain state and RMB row | as the two tables above | `jug chain:`, `jug pull:`, `jug RMB row:`, `jug buffer:`, `jug meteor:` (tools/zedran_feel_check.gd) |
| E attached, RMB tap | the normal Finishing Slam; the link chain stays drawn | `combo jug: E > RMB tap = Finishing Slam` |
| RMB sweet spot, then a knock on that foe (2s) | the Gilded Riposte is ready again; a heal; a Rampage charge back | `combo jug: RMB sweet spot > knock = Riposte reset + heal + a dash` |
| E, E (pulled in), X, their hit | blocked in the guard, then the cleave lands | `combo jug: E > E > X = pulled in, a hit blocked, the cleave lands` |
| X, two hits blocked | the cleave 40% harder | `juggernaut X small mechanic: two hits blocked make the answer 40% harder` |
| X knocks a hunter | ready again at once | `juggernaut X small mechanic: knocking a hunter with it resets it; ...` |
| X, then a merge | the guard drops, no cleave | `merge hold jug: the Riposte's guard drops, no cleave` |
| RMB hold, jump, full, release | lane, jump, flash, fling | `juggernaut RMB hold: you can jump while holding` and the lane/flash checks |
| RMB hold that strikes nothing | Smash cooldown doubles | `combo jug: RMB hold miss = cooldown x2` |
| In the air with the Smash ready, RMB | the disc at the cursor, the dive lands there | `juggernaut RMB air: Meteor Drop lands at the cursor (disc everyone sees)` |
| Rampage or Lunge, then glide | no glider for the wind-down | `combo jug: Rampage winds down (no instant glide)` |
| Rooted or Grounded, E | no chain | `combo jug: rooted = no Warchain`, `combo jug: Grounded = no Warchain` |
| A stun while chained | breaks the chain | `combo jug: stun breaks the Warchain` |
| Enraged | faster cooldowns | `combo jug: Enraged hastes the Smash` |

## Animation moves

`KMovesDJ` (scripts/match/kmoves_dj.gd): `jug_slash_r` / `jug_slash_l` (the body of each slash), `jug_wave_wind`
(held) / `jug_wave`, `jug_slam` (0.6s coiled wind-up, strike at 0.6, overshoot and settle), `jug_guard` (X: planted wide, the blade upright in front) / `jug_riposte` (the blade drops, then the lunge and
the upward cleave, settled by 0.45s),
`jug_lunge_wind` (held: sunk deep, blade dragged behind, coiled) / `jug_lunge`, `jug_meteor` (held: the hang's
gather and turn, then the dive) / `jug_meteor_land` (the crouch onto the knees and the 0.5s rise), `jug_dash`,
`jug_exdash` (his air dash: a hurled shoulder charge, knees tucked, blade trailing; no ground mark), `jug_chain` / `jug_reel`, `jug_spin`,
`jug_chainlunge`, `jug_haul_wind` / `jug_haulslam`, `jug_roar` (Enraged). Strips: `--arena-demo=anim_<move>`
(scripts/arch/dj_demo.gd).

## Look and sound (all ours)

His moments are recipes in content/vfx/juggernaut.json, played by the shared HeroVfx (docs/HERO_VFX.md): flame arcs, burning
ground that cools to fissures, walls of flame, mesh trails, GPU embers, smoke and debris, in his ember, magenta and gold.
The projectile looks that ride a shot and the Warchain itself stay in scripts/arch/kits/dj_fx.gd. Sounds: tools/gen_sfx_kael.py
(`jug_*`, `juggernaut_*`), played from the recipes.

## Originality

Two of our names (Execution Slam, Scorching Spin) had matched the source hero's exactly; they are now the
Finishing Slam and the Cinder Spin everywhere the player can read them (content, UI, fx words, wiki).

## Ground shapes (telegraph audit)

Rule (DECISIONS items 4, 8, 50, 96): a ring, disc or burst on the ground means gameplay, so every one drawn must be the true hit area. `tools/dancer_jug_check.gd` asserts drawn size = hit size, and that the move art in `content/vfx/juggernaut.json` carries no stretched size.

| Ability | Ground shape drawn | Hit | Seen by | Source read | Status |
|---|---|---|---|---|---|
| Greatsword (LMB) | sweep arc 175 deg, reach 3.1 m | arc 175, reach 3.1 | everyone | wide slash | fixed: art was 104 deg and 0.86x reach |
| Searing Wave (LMB hold) | lane growing to 14 m, 1.2 m wide; ring r 1.35 m on her | the wave 0.6 m radius | lane: her screen; ring: her screen | thin ring on the body while charging | lane ok; ring kept (source shows it), it is a charge meter, not an area |
| Smash tap (RMB) | cone r 4.0 m, 70 deg through the wind-up | slam 4.0 m, 70 deg | everyone | short strike lane | fixed: was a 4 m lane; now the true cone (owner rule over the source's lane) |
| Smash landing art | scorch + sweep, cone 70 deg | same | everyone | - | fixed: sweep was 74 deg |
| Smash hold (RMB) lunge | lane growing 4.5-7.5 m, width = body + 0.6 m each side | contact test uses the same width | her screen | lane along the dash | fixed: was 1.3 m against a 2.06 m test; both now share `lunge_w()` |
| Lunge art | scorch lane, width follows `lunge_w()` | same | everyone | - | fixed: was a fixed 1.3 m |
| Meteor Drop aim (air) | disc r 2.6 m under the cursor | damage radius 2.6 m | her screen | landing marker | ok, asserted |
| Meteor Drop marker | disc r 2.6 m filling, core ring 1.2 m | damage 2.6 m, stun core 1.2 m | everyone | magenta disc | ok, asserted |
| Meteor Drop landing art | scorch r 2.6 m, skirt at the core, shock ring 1.2 m | same | everyone | ground crack + ring | fixed: scorch and skirt were 1.05x and 1.15x |
| Warchain (E) | chain line to the target; steer reach 3.5 m | hook shot | everyone | chain | not an area; ok |
| Rampage (dash) | none | along the dash | - | none | fixed: removed a cosmetic 1.1 m scorch lane |
| Exec outline on wounded foes | red ring under the foe | marks who can be executed | her screen | red outline | kept, a marker not an area |
| Gilded Riposte (X) guard | lane 3.6 m x 1.8 m, filling over 0.65 s | strip 3.6 x 1.8 from where he stood | everyone | strip ahead | ok |

Decision: the Smash cone follows the owner's rule (true hit shape) where the source drew a short lane.

## Engine notes

- The Gilded Riposte lives in `scripts/arch/kits/juggernaut_ult.gd` (`JuggernautUlt`, owned by the kit); X
  reaches it through `ArchKit.cast_ult()` on the `hunter_ult` action. Numbers: `x` in
  content/archetypes/juggernaut.json; the shared X base (gate, cooldown `cd["x"]`, HUD slot, bond) is `HeroUlt`. Sounds: `jug_guard`, `jug_ting` (a blocked hit), `jug_riposte` (the cleave).
- The guard is `JuggernautKit.incoming` (every hit blocked while guarding), `move_k` (planted) and `busy`.
- Net: the kit move id rides the hunter snapshot from Net 0.15.0, so remote players see the slams and lunges.

## Starting a Boki merge

Pressing R to merge drops everything the Juggernaut was holding or winding up, and none of it fires or is
left over when the merge ends: the Searing Wave charge (`lmb_t`, `lmb_buf`, `mel_hold`), the Finishing Slam's
wind-up (`slam_w`), an armed Haul Slam (`haul`) and the held Smash (`rmb_down`, cleared by the merge itself), a Meteor Drop in its dive (`drop`), the Lunge's full flag (`lunge_full`) and a running Gilded Riposte
(`riposte.st`, its guard or cleave; the gold glow hides).
Scripted in `--kit-combo-check` as the `merge hold jug:` checks.
