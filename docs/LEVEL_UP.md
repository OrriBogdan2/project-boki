# In-match level-ups: what the source does, what we do

Owner playtest 11-11: level-ups need to be clearer, with fewer pop-ups overall. Code: `scripts/ui/level_up_cue.gd`,
`HudVitals.xp_row` (main's XP tracker, merged 11-13), `Hunter.gain_xp`. Check: `--level-hud-check`. Video: `--levelup-reel`.

## What the source does (and how sure we are)
- **Persistent level + XP.** 1.0 HUD: the level number sits at the far left of the vitals block on a dark strip,
  with a long XP bar beside it under the health and armour bars. The older HUD put a big level number in a coin
  ringed by XP on a round portrait. [hero-ref] (frames from the ability showcase and a commentated 1.0 guide)
- **What a level gives.** A stat boost and one ability point each time the bar fills. Points unlock the four
  abilities first, then rank them (up to 4). The ultimate opens at a set level. [data §7] [deltias]
- **The level-up moment.** After a level-up, "upgrade available" shows as glowing beams and an orb over the
  ability slots, and each slot carries a rank badge. Floating "+17 XP" numbers show XP coming in. [hero-ref]
- **Sound.** The source pairs a sound with pop-ups that players were missing: a patch made the gold-request
  sound louder for that reason. [steamdb] We found no source for the exact level-up sound, any screen-edge or
  character flash, or how long the moment lasts. The footage the hero-ref study used (`/home/claude/svvid`) is not
  on this worker, and the UI guide we found does not cover levels. [ludo]

Sources: [hero-ref] `briefs/hero-ref/HUD.md` on `origin/ext/agent-briefs` (sections 2 and 4); [data §7]
`docs/SUPERVIVE_DATA.md` section 7; [deltias] deltiasgaming.com "Supervive: Experience and Level Caps Explained";
[ludo] ludo.guide "User Interface (UI) Explained" (Supervive); [steamdb] Supervive patch notes on steamdb.info.

## Ours, before (0.24.5)
The level was a 26 px number on a coin at the portrait's corner, with a thin XP ring round it. The same level
also showed as "LV n" in the clock bar. A level-up popped the coin and threw a gold ring round the portrait. It
also put a "LEVEL n · +1 skill point" line in the top-centre message lane for 3.2 s, often under another toast,
and a gold full-screen wash on even levels. The world cue (Fx.body_glow) is the same glow as "ability ready" and
"resource full", so it can't mark a level-up on its own.

## Ours, now
- **Always there:** main's XP tracker (11-13, `ext/ui-xp-tracker`) on the vitals block's top edge: LV number and a
  gold XP bar that fills smoothly, popping when XP lands. It replaced the level coin and the long bar under the
  ability row this branch first drew; the coin is gone, the rest of this section stands. The clock bar's
  duplicate "LV n" is gone, and so is the clipped class name under the portrait (the vitals hover has it).
- **The moment (all at once, then gone):** the chime (unchanged), the level number goes gold, a **gold column with three
  rising chevrons over your hero** (0.8 s, HUD-drawn, so no ground ring), and a **card just over the vitals**
  (2.6 s): "LEVEL n", then "+6% health +5% ability power", then what is new (the weapon's step, "ultimate
  open (X)", "n points to spend"). The slots a point can go into already wear gold borders or a gold +.
- **Removed:** the lane line, the full-screen wash, and the portrait's ring burst. The overall pop-up count
  goes down by one per level, and the even-level wash is gone.

## Video
`docs/shots/levelup-clear/levelup_fight.mp4` (game camera, sound on): Lisette trading shots with a rival, levelling
2 -> 3 at about 3.6 s and 5 -> 6 at about 8 s. `before_levelup_fight.mp4` is the same run on 0.24.5. Remake it with
`--levelup-reel` (the command is in `tools/levelup_reel.gd`).
