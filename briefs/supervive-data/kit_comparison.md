# Project Boki kits vs SUPERVIVE hunters (rules and usage)

Source of truth: /home/claude/supervive_kits.md (in-game tooltips, Nov 2 2026). Boki paths are relative to /home/claude/project-boki. "JSON" means content/archetypes/<id>.json, where the numbers live. Anything that already matches is left out. R rows are low priority, since R is becoming the Boki merge.

## Mapping

| Boki hero (id) | SUPERVIVE hunter | Confidence | Evidence |
|---|---|---|---|
| juggernaut | Brall | Certain | Designer's statement; docs/ARCHETYPES.md:1217; docs/heroes/juggernaut.md:9 |
| thief | Shiv | Certain | Designer's statement; ARCHETYPES.md:1216; heroes/thief.md:9 |
| archer | Myth | Certain | ARCHETYPES.md:1218 "Inspired by" table; bow, wall-stun heavy shot, rain of arrows, injured-reveal passive |
| bulwark | Oath | Certain | ARCHETYPES.md:1219; thrown and recalled hammer, front shield, spin dash, field at the hammer |
| mage (Vireo) | Joule | Certain | ARCHETYPES.md:1220; 4-stack Static, dash-through reset, spear with an orb |
| gunslinger (Marlowe) | Ghost | Certain | ARCHETYPES.md:1221; 10-round front-loaded rifle, sticky grenade, slide, railgun |
| ashwick | Felix | Certain | ARCHETYPES.md:1222; flamethrower, 2-level Ignite, pull plus shield E |
| dredge | Kingpin | Certain | ARCHETYPES.md:1223; 7-slug shotgun with bloom, arm grab, max-HP stacks on knocks |
| tender (Linnet) | Elluna | Certain | ARCHETYPES.md:1224; carries downed allies, delayed-root shot, throwable heal zone |
| rimewright (Tamsin) | Celeste | Certain | ARCHETYPES.md:1225; Chill/Shatter, homing darts, 2-charge spear, skate, sliding wall |
| dolm | Tetra | Certain | ARCHETYPES.md:1226; tap boulder / hold punch, rocks, three-rock wall |
| ostra | Void | Certain | ARCHETYPES.md:1227; empowered state, charged orb, shard stun, swap lob, growing bomb |

## Per hero

### Juggernaut (Brall)
1. **The air slam shares the Smash cooldown.** At juggernaut_kit.gd:441, `spend_rmb()` runs for every variant, Meteor Drop included (:448). SUPERVIVE gives Obsidian Slam its own 9s slot, so the air slam is usable right after a ground Smash. Its rank IV upgrade (-3s on the Air Slam) is also missing.
2. **The dash tip stuns into walls.** At JSON:15 (`tip_stun 0.8`) and juggernaut_kit.gd:403, the Rampage tip stuns 0.8s against a wall. Flame Step has no stun.
3. **Rank paths.** Flame Step gets +1 charge at rank II in SUPERVIVE; Boki gives it at rank 3 (JSON:30). Feysteel's upgrades are -2s three times; Boki's rank 3 refunds 33% on hooking a foe instead (JSON:30, juggernaut_kit.gd:703), which comes from old patch notes. Execution Slam gets +20% damage at both II and III; Boki applies +20% once, at rank 3 (juggernaut_kit.gd:435).
4. **Cooldown ratios.** Flame Step is 9s in Boki against 13s (0.7x). Chain is 13s against 16s. Both are acceptable.
5. **R (low priority):** Volcanic Rebuke (invulnerable, strike back, resets on a kill) is folded into the rank-3 sweet-spot crash. The invulnerability is gone.

Verdict: very close. The only real rule bug is the shared air-slam cooldown.

### Thief (Shiv)
1. **Weapon type.** JSON:9 sets `signature: twin_blades` (melee), with SMG as the alternative. Arcslinger is a ranged pistol bolt. The whole stack-and-empower loop is supposed to be played at range.
2. **The passive gained a new payoff.** Jackpot fires automatically on the fifth Mark (thief_kit.gd:61, :550; JSON:12). It is made from the R, and SUPERVIVE has no cap and no stack trigger. Stacks are also +8% per Mark (JSON:10) where SUPERVIVE gives a flat +16 per hit. That is a fine translation, but uncapped is the source rule.
3. **The knife's Vault reset is in the wrong slot.** thief_kit.gd:457 gates "knife in a foe resets Vault" on dash rank 3. In SUPERVIVE it is Farstep Dagger rank IV. Quickflip's own last upgrade (+50% move-speed boost) is missing; Boki's dash rank 3 gives Primed +20% instead.
4. **Farstep cooldown.** 18s in Boki (JSON:21) against about 28s base in SUPERVIVE (20s at IV after -8s), roughly 0.65x. The forced teleport comes at 5s instead of 6s. The tooltip lists no slow on the dagger, but Boki slows 50% (JSON:21), taken from the wiki.
5. **R (low priority):** Fusillade became Jackpot (see item 2).

Verdict: close in structure. The melee weapon and the auto-trigger change how it plays.

### Archer (Myth)
1. **The dash is a different ability.** archer_kit.gd:299 and JSON:12 give a Grapple Arrow (zip to a ledge, or hop back), 7s. Phase Walk is a dodge roll toward the cursor that lets you walk through terrain, 9.5s. Its upgrades (-1s twice; +0.5s duration, move speed in terrain, allies also get it) are absent; Boki's rank 3 is "the hop refunds 40%". The docs attribute this to heightmap limits (heroes/archer.md:23).
2. **RMB tap is an invented snare on a much shorter cooldown.** JSON:13 and archer_kit.gd:408 add a tap root snare and Tripwire on a 9s, 2-charge pool shared with the Heavy Shot. Heartpiercer is hold-only, 16s, 1 charge. That is about 3.5x more casts.
3. **Rank-3 RMB.** Boki gives "max 3 Tripwires" (JSON:16). SUPERVIVE gives more range and a dash charge on a wall stun.
4. **The passive gained a resource.** The Focus meter (standing still, sneaking, high ground, Deadeye; JSON:10) is not in SUPERVIVE. Spectral Hunter is only the injured-hunter vision plus climbing tall ledges, and ledge climbing is missing. The extra air RMB "Plunge" (archer_kit.gd:485) is also invented.
5. **Rain of Arrows shape.** SUPERVIVE fires a cone from you. Boki drops a 6m line lobbed up to 9m (JSON:14). Damage over time, slow and anti-heal all match.
6. **R (low priority):** three empowered no-charge shots, now roughly covered by Deadeye.

Verdict: loose. LMB and E match; RMB, Shift and the passive have different rules.

### Bulwark (Oath)
1. **E is a single burst instead of a zone.** bulwark_kit.gd:514 and JSON:15 fire a burst 1s later at the mace or the aim point. Regen Field is a lasting healing zone around the hammer that also bursts. Cooldown is 16s against about 12s base (8s at IV after -4s at III). The rank-III -4s is missing; Boki's rank 3 is +0.5m and +10 healing. Boki also slows foes in it, which SUPERVIVE does not.
2. **The passive stun is narrower and adds a heal.** bulwark_kit.gd:156-174 (`_try_crush`) stuns only on Bash, Shield Charge or a full Crushing Blow, and also heals 24. SUPERVIVE stuns on any knock into a wall, Spin Dash included, with no heal. The Guard meter and Shield Slam (JSON:10-11) are invented.
3. **The bash is in two places.** RMB release or tap bashes (bulwark_kit.gd:412-450) on top of Shift-with-shield. SUPERVIVE only bashes with Shift while shielding.
4. **The bash has no cooldown of its own.** Shield Bash has its own 6s cooldown in SUPERVIVE. Boki's Shield Charge spends a dash charge (bulwark_kit.gd:462). The shared rank-IV rule "dash hits refund the Shield Bash cooldown" is missing; Boki's rank 3 is +1m (JSON:17).
5. **Shield upgrades.** Faster repair and regen is missing; Boki only has +60 shield HP.
6. **R (low priority):** Abyssalbreaker (stunning fissure, then AoEs with heavy slow) was dropped.

Verdict: medium. LMB and the shield match; E, the passive and the bash routing differ.

### Gunslinger / Marlowe (Ghost)
1. **The slide's hold rule is reversed.** gunslinger_kit.gd:108-112 and JSON:46 make the hold slide cost the normal cooldown and refund 30% on an early release. In SUPERVIVE, holding gives a longer dash on a longer cooldown, with no refund.
2. **Lifesteal stacks to 8.** JSON:22-24 allow up to 8 stacks of 6% (48% vamp), and the grenade counts twice. The tooltip gives a flat +6% omnivamp for 3.5s.
3. **Railgun refund.** The base cut is 30% per hunter hit (JSON:98, gunslinger_kit.gd:372); SUPERVIVE's is 20%. Boki also adds a 0.8s stand-and-charge with a 55% self-slow (JSON:92-93), which the tooltip does not mention.
4. **Grenade.** A wall stun cuts the grenade cooldown 40% (gunslinger_kit.gd:273-274). That rule is invented.
5. **Knock heal.** A knock heals 25% (JSON:26). The tooltip only says knocks reset the slide.
6. **R (low priority):** Napalm was dropped.

Verdict: close. Fix the slide hold rule.

### Mage / Vireo (Joule)
1. **E has no hold-and-drag aim and no pull option.** Skycall is tap-only and always flings along your aim (JSON:92-106, mage_kit.gd:382-402). Lightning Strike is press to pull or knock back, or hold and drag to aim the knockback direction. Boki's added Grounded 1.2s is not in the tooltip (it comes from the wiki).
2. **Spear rank 3.** Boki gives +20% (JSON:126); SUPERVIVE's rank IV gives +50% damage.
3. **R (low priority):** Thunderstorm (launch up immune to projectiles, crash down, spread Static) was dropped. It is the only other Static source.

Verdict: very close.

### Ashwick (Felix)
1. **No bonus damage against Ignited foes.** Felix's Ignite makes LMB and RMB deal bonus damage, and the flamethrower also deals % max HP. Boki has no `outgoing` bonus; ashwick_kit.gd:268-270 instead halves Char build on a burning foe. This is the core payoff, and it is missing.
2. **Cinder Shot (Embry Bolt).** No slow (ashwick_kit.gd:282-283). Rank 3 is +60% damage and a 25% refund (JSON:24); SUPERVIVE's IV is +1 charge. The spread to foes within 4m (ashwick_kit.gd:297-301) is not in the tooltip.
3. **Spark Leap (Pyro Pounce).** Knockback is 3, a nudge (JSON:14); Felix knocks back properly. SUPERVIVE's rank IV (+40 damage, +75 move speed and a 150 shield on hit) is replaced by the R's fire trail.
4. **R (low priority):** Firefox flight folded into the leap trail.

Verdict: medium. The shapes are right, but the Ignite damage bonus is gone.

### Dredge (Kingpin)
1. **The grab stops at walls and only takes foes.** dredge_kit.gd:113-135 and JSON:17. Abyssal Grasp pierces terrain and pulls the first target hit, ally or enemy, and scoops up Wisps. Rank 3 refunds 33% (JSON:16); SUPERVIVE's IV gives -50% cooldown on an enemy hit. Boki's added "lands Grounded" is not in the tooltip.
2. **Primal Slam's abyss upgrade became a height bonus.** dredge_kit.gd:236-241 gives up to +75% by your height above ground. SUPERVIVE's rank IV is +100% damage against enemies over the Abyss and +0.2s stun. The base spike (dredge_kit.gd:248) is fine.
3. **The dash.** Barge shoves for 5 (JSON:13, dredge_kit.gd:286); Brute Dash does no damage. The air dash shares one charge pool instead of a separate 12.5s slot. Bloom reset on a dash is base in Boki but a rank-IV upgrade in SUPERVIVE.
4. **R (low priority):** Slugwave (two anti-heal waves) was dropped. SUPERVIVE has no anti-heal source left in this kit.

Verdict: medium-close. The grab's terrain pierce and ally pull are the main rule gaps.

### Tender / Linnet (Elluna)
1. **Invented carry penalties.** Carrying slows you 30% (tender_kit.gd:108), and dropping a teammate stuns you 0.6s (tender_kit.gd:171). Soulpack has neither: the drop only locks re-pickup for 4s.
2. **A stun puts Hearthlight out** (tender_kit.gd:343-345). Moonlight Blessing has no such rule; in SUPERVIVE only the R channel is canceled by a stun.
3. **Relay Step bonus.** Passing through a teammate refunds half a dash and 1s of Hearthlight (JSON:11). That is invented.
4. **Binding rank II.** SUPERVIVE bundles +40% damage, +0.3s root and 200% detonation radius. Boki only adds +0.3s root (tender_kit.gd:268); the radius increase is missing. On Hearthlight, SUPERVIVE's IV doubles the post-throw healing amount, while Boki doubles its duration (tender_kit.gd:301).
5. **R (low priority):** the channel heal with revive-and-pull was folded into the rank-3 flare.

Verdict: close. Remove the invented penalties.

### Rimewright / Tamsin (Celeste)
1. **Cryo Spear cooldown.** 4.5s with 2 charges (JSON:23), against 12s with 2 charges in SUPERVIVE: 2.7x more spears. Rank 3 is +45% burst radius (rimewright_kit.gd:257); SUPERVIVE's is +45% explosion damage.
2. **Skate.** Releasing early refunds up to 60% (rimewright_kit.gd:220), and the fan does double damage while skating. Neither is in SUPERVIVE. The rank-III ice islands over the Abyss are a visual puff only (rimewright_kit.gd:205-208), so the abyss utility is missing.
3. **Wall.** Teammates who touch it get a frost shield (rimewright_kit.gd:338). That is invented. Fine as a design choice.
4. **R (low priority):** Chilling Finale (invulnerable slowing zone that stacks Shatter, then stuns) was dropped.

Verdict: close in shape. The spear cooldown is way off.

### Dolm (Tetra)
1. **The core passive is missing.** Molten Guard ("hitting your Rocks with Quake Punch grants a shield") is not in the base kit: the JSON:11 passive is only Tremor Sense. A shield appears only at RMB rank 3, from slams (dolm_kit.gd:360-364, JSON:25). SUPERVIVE's RMB rank IV adds Molten Guard stacks from slams on top of the base punch rule.
2. **Invented slam reset.** A slam that knocks or kills resets Quakefall (dolm_kit.gd:352, :372-375). Volcano Crusher has no reset.
3. **Jump while charging.** SUPERVIVE leaps forward if you jump while charging. Boki replaces this with an air-press dive (heroes/dolm.md:36).
4. **Landslide.** The +1 charge (SUPERVIVE rank III) is missing; Boki's rank 3 is only +33% distance (dolm_kit.gd:264). Base cooldown is 9s against about 12s.
5. **Rockwave.** Allies cannot hop over the rocks (heroes/dolm.md:39).
6. **R (low priority):** Tetraform's slowing wall and drag-to-angle were dropped; its terrain-over-the-abyss part became the rank-3 bridge.

Verdict: close for LMB and E; the passive needs work.

### Ostra (Void)
1. **The swap only moves foes.** ostra_kit.gd:182 uses `foes_in`, so only foes at the landing spot are moved. SUPERVIVE's Swap moves all units caught, allies included.
2. **The bomb auto-pops and Grounds.** The seed pops by itself at full growth (JSON:22, ostra_kit.gd:326), and the pop Grounds everyone for 1s. Unstable Anomaly detonates on reactivation, and the tooltip lists no ground. The rank-III -2s is missing; the overlap damage-over-time is covered by the rank-3 burn.
3. **Void Snap.** The move-speed upgrade on cast and impact is missing (JSON:18 `boost 0.0`). Its stun scaling with distance is not in the tooltip (it comes from the wiki).
4. **Passive.** A knock heals 20% (JSON:12), which is not in the tooltip. The floating part of Hands of Fate (no footsteps, avoids ground hazards) is not built.
5. **R (low priority):** Singularity's pull was folded into the seed's rank 3.

Verdict: close.

## Top 10 fixes across the roster

1. **Archer:** remove the RMB tap snare and Tripwire, and make Heavy Shot hold-only, 1 charge, about 1.8x the current cooldown (JSON:13; archer_kit.gd:394-440).
2. **Archer:** replace Grapple with a phase dodge roll toward the cursor (through rocks and walls, with brief passability), or at least a cursor-directed roll (archer_kit.gd:299).
3. **Ashwick:** add bonus LMB and RMB damage against Ignited foes plus a % max-HP tick on the flamethrower, and drop the halved Char build on burning foes (ashwick_kit.gd:268-270).
4. **Rimewright:** set the Sleet Lance cooldown to about 12s with 2 charges, and make rank 3 +45% burst damage rather than radius (JSON:23; rimewright_kit.gd:257).
5. **Dolm:** make "punching your rocks grants a shield" the base passive; RMB rank 3 then adds stacks from slams. Remove the slam reset on knock (dolm_kit.gd:352, :372).
6. **Juggernaut:** give Meteor Drop its own cooldown slot (about 3x the Smash cooldown, with -3s at rank 3) instead of `spend_rmb` (juggernaut_kit.gd:441-449).
7. **Thief:** make the default weapon a ranged pistol-style shot. Move "knife in a foe resets Vault" to E rank 3, and give Vault rank 3 the +50% speed boost (JSON:9; thief_kit.gd:457).
8. **Bulwark:** make Mending Ground a lasting zone at the mace with an end burst on about a 12s cooldown, -4s at rank 3. Let any knock into a wall stun, and give Shield Charge its own cooldown, refunded by Whirl hits at rank 3 (bulwark_kit.gd:156, :462, :514).
9. **Gunslinger:** make the hold slide a longer dash on a longer cooldown with no early-release refund. Cap Fever at a single 6% stack, or a low cap (gunslinger_kit.gd:108-112; JSON:22).
10. **Dredge:** let the Grapnel pierce terrain and pull allies, with -50% cooldown on an enemy hit at rank 3. Replace the Anchor's height bonus with +100% against foes over the abyss (dredge_kit.gd:113-160, :236-241).

Smaller ones worth doing on the same pass: remove the Tender's carry slow, drop-stun and stun-kills-Hearthlight rules (tender_kit.gd:108, :171, :343); let Ostra's Trade move allies (ostra_kit.gd:182); remove the Juggernaut's dash-tip wall stun (JSON:15).
