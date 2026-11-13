# Steal counterplay: last-hit kills made readable and answerable

Owner call 2026-11-10: a monster's XP and kill bonus go to the squad that lands the last hit. A rival who lands it takes both. Make that readable and give the victim an answer. Mechanics only; no new abilities.

## 1. What the source does (from our notes: SUPERVIVE_DATA.md sections 4, 7, 9, 10 and the kit tables)
- **Kill credit:** XP is paid to the killer and to teammates close by. Our notes record no damage-share rule for monsters. The owner's call is last hit takes all.
- **Boss buff ownership:** our notes record no buff that a boss kill grants and then owns. Night bosses, Soul Bosses (3 phases) and the Major Monster exist; their rewards are not published. Treat as a gap.
- **Execute / smite:** the only execute is the finisher on a downed Hunter's wisp (about 3 s). Nothing in the notes finishes a monster. There is no smite-like tool.
- **Burst windows it does have:** a staggered monster is stunned for several seconds and takes 3x damage; Vulnerable is 2x for 5 s on monsters; elites and bosses open stagger windows with a visible cue; monsters ignore sneaking players unless close.
- **Boss health visibility to other squads:** not published (gap). Fog and ping rules are also gaps. In our game every Hunter sees any monster bar in view (`hud_plate.gd`).
- Not found: footage notes on lair-fight kill credit. We design from the mechanics above.

## 2. What our code does today
- `Mob.hurt` keeps `last_hit_by`; `Boss.damage_by` records damage per team; `Mob._stagger` gives 2.2 s (bosses, wardens) or 3.0 s at 2.5x damage, and opens a 3 s ring every 9-13 s (`mob.gd`).
- `Match.on_mob_dead` credits `by` (a Boki's owner counts). Damage XP is 0.35 per damage today; the early-camps spec (ext/spec-early-camps) replaces it with kill XP to the last hit's squad within 30 m.
- A lair boss pays 260 XP by share; the killer gets the gems, perk orbs and egg (`lairs.gd` around 700). The kill feed says "X felled Y".
- Bots already burst into an open stagger ring within 7 m (`bot.gd` around 562).

## 3. Callout (same in every option)
When the killer squad is not the squad with the most damage on that monster, and that top squad dealt at least 40% of its max HP, it is a **steal**. Everyone in 40 m sees a one-line banner in the thief side's colour (SideColor, colour-vision safe): "STOLEN: <thief> took <monster> from <victim squad>  +<xp>". The victim squad gets "Your kill was taken". The feed logs it. Normal kills keep today's "felled" line. Needs the top team on the `mobdead` event: Net.VERSION bump.

## 4. Options
**A. Tell only.** At 30% HP the monster's ring pulses in the top-damage squad's colour. Boss and mob bars show a damage chip per squad. No rule change. Counterplay is awareness: you see the steal coming and hold your burst. Cost: small (`hud_plate.gd`, `mob.gd` tell flag). Weakness: a squad with no burst left still loses.

**B. Finale window (default).** At 20% HP, once, any monster that already staggers (elites, wardens, bosses) staggers for its normal 2.2 s at 2.5x damage, with the existing purple stars and a horn cue. Small mobs just die. Both squads see the same window, so the kill is a burst race: the squad that held cooldowns wins it, and the defender chooses the moment by pushing the monster to 20%. Includes A's tell at 30%. Cost: moderate. Code: `mob.gd` (a `finale_done` flag calling `_stagger`), `boss.gd` (no phase clash: skip if a phase stagger is running), `lairs.gd` (steal test and callout), `xp_rules.gd` and `content/rules/xp.json` (`finale_hp 0.2`, `tell_hp 0.3`, `steal_min_share 0.4`), `hud.gd` wiring only, `net.gd` (mobdead field).

**C. Snipe split.** A last hit from a squad that dealt under 15% of the monster's max HP (10% for bosses) pays that squad 50% of the XP and the top-damage squad the other 50%. The kill bundle still goes to the last hit. Real thieves who fought still take it all. Cost: moderate; needs damage per team on every monster (`mob.gd`) and a split in `xp_rules.gd`. Weakness: more rules to read, and it weakens the owner's "steal and take it" call.

**Default: B.** It keeps the owner's rule whole, uses a stagger the game already has, and turns the steal into a timing fight both sides can see coming. C is the fallback if playtests still feel unfair after B.

## 5. Bots
- The top-damage bot squad holds its ultimate and Boki burst until the finale window opens (no spending above 30% HP).
- A bot within 12 m of a monster at or under 30% HP that is not the top-damage squad commits to the steal only if its burst is ready; difficulty sets how often (Easy never, Normal half the time, Hard always). They never cross 40 m for it.
- Bots read the same callout rules, so a bot steal shows the same banner.

## 6. Build jobs (each under 2 hours; depend on the kill-XP rule from ext/spec-early-camps)
```jsonl
{"id":"steal-rules","title":"content/rules/xp.json steal and finale keys + xp_rules.gd steal test (top-damage share >= 0.4, killer squad differs)","files":["content/rules/xp.json","scripts/match/xp_rules.gd"],"hours":1.0}
{"id":"mob-damage-by","title":"damage per team on every Mob, not just Boss (mob.gd), reused by the steal test","files":["scripts/match/mob.gd","scripts/match/boss.gd"],"hours":1.0}
{"id":"finale-window","title":"one stagger at 20% HP for staggering monsters; skip during a phase stagger; horn cue","files":["scripts/match/mob.gd","scripts/match/boss.gd","scripts/match/lairs.gd"],"hours":1.5}
{"id":"tell-and-chips","title":"30% HP ring pulse in the top squad colour + damage chip per squad on mob and boss bars","files":["scripts/ui/hud_plate.gd","scripts/match/mob.gd"],"hours":1.5}
{"id":"steal-callout","title":"STOLEN banner + victim line + feed entry, SideColor, mobdead event carries top team (Net.VERSION bump)","files":["scripts/match/lairs.gd","scripts/ui/hud.gd","scripts/core/net.gd","scripts/match/match.gd"],"hours":1.5}
{"id":"bot-steal","title":"bots hold burst for the finale and steal by difficulty (<=12 m, <=30% HP)","files":["scripts/match/bot.gd","scripts/match/bot_keys.gd"],"hours":1.5}
{"id":"steal-check","title":"tools/steal_check.gd: steal vs normal kill, finale fires once, bot hold/commit; registered in the check registry","files":["tools/steal_check.gd"],"hours":1.0}
```
