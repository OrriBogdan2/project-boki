# SALVAGE PR #546 (ext/merge-lane-N2-1120)

Job 20261123-000803-a1 (worker rpg7), 2026-11-23. Gate state before: REGATE RED/CONFLICT, merge-gap 200.

## Result: merge not done, close recommended (branch kept)

Measured:
- Branch is 477 commits ahead of origin/main (235 non-merge, none patch-id-equal to main) and 935 behind.
- `git merge origin/main` = 2075 conflict hunks in ~150 files (scripts/core/{data,net,save,sfx,settings}.gd,
  scripts/match/{hunter,arena,ent,hud-adjacent,models,cam,fx,...}.gd, scripts/ui/*, ~50 tools/*_check.gd, docs).
  Main re-did gdformat/lint, KillFeed, AbilityText (scripts/arch/ability_text.gd), hit-feel table, move rules;
  the lane edited the same lines. Hand-resolving 2075 hunks and re-fixing the checks they break cannot be gated
  safely in one session; I aborted the merge and pushed nothing to code.
- Diff vs main is 1552 files / +44k -53k, mostly main's own newer work reading as "removed", so it is not a reviewable PR.
- Successor PR #642 (ext/merge-lane-N2-1122, head d5dce31379) is the re-roll of this lane on a newer main:
  113 commits ahead, 101 behind, merges with main with 0 conflicts (git merge-tree). It carries NONE of the 231
  files #546 adds, so it is a different, smaller bundle (ground-ring audit, stomp prompt, time trial, Grimble sfx...).
  Same lane name, not a superset: #546's unique work below is NOT in #642.

## Unique to #546, not on main nor #642 (checked by file/symbol presence on origin/main)
- Six-slot belt (slots 1-2 pinned to tonic and armor kit, data-driven channel times), belt cancel cues
  (belt_spill, belt_fumble), belt item hints/tips, BotShop (scripts/match/bot_shop.gd)
- Combat HUD calm (toasts/hints queue in a fight, level-up card, loot names wait) + 1080p shots
- Audio: CarrySfx, IncomingHitSfx, KitWindup + Sfx voice handles (broken casts cut wind-up sound), Boki state cues,
  Boki wisp summon line, ~42 new audio files in audio/
- models.gd split into models_{base,bake,face,gear,hair,home,hunter,kin,look}.gd (god-file budget), KinNames,
  warden_clip_file.gd
- content/utility (18 files), ability-text single reader, --fsm-check, --range-screen-check, feel-lab deletion
- 43 new tools/*_check.gd and ~40 doc shots (docs/shots/ui-inventory etc.)
- Dropped by the lane itself already: knock_feed.gd (main's KillFeed won), Lace/Tenzo glb re-weights (stay on
  ext/rig-ship-1117, owner model check).

Commit subjects (non-merge, 110 chars) are listed at the end for the backlog.

## Recommendation for the coordinator
1. Close PR #546 with a comment pointing at this file (keep the branch, do not delete it).
2. Do not re-merge this bundle whole. Re-lane it as small slices, each cut from current main and gated alone:
   (a) six-slot belt + belt cues/hints + BotShop, (b) combat HUD calm, (c) audio trio CarrySfx/IncomingHitSfx/KitWindup
   + audio files, (d) models.gd split (pure refactor; most conflict-prone, do it last or fresh on main),
   (e) content/utility + ability text.  Cherry-pick by theme from the commit list; most slices touch 10-30 files.
3. #642 can go through its own gate independently.

## Commit subjects on #546 not on main
- --fsm-check: every Fsm built from its table and its edges asserted, the pattern driven once
- --range-screen-check: every aimed slot's max-range end on screen at the default and closest wheel zoom, four a
- Ability text: one reader (AbilityText) for name, short, line and full; keys via Settings.key_cap, numbers from
- Add the missing .uid for tools/clip_cancels_check.gd (Godot import)
- Art specs: Kael and Lace use voxel weights (bake-off B specs)
- Art tools: v95 swap spec option weights=voxel (skin weights through the master's voxel solid)
- Art: Tenzo rebake: the pick's paint baked onto the 60k mesh (v95_swap own.rebake), no black or orange specks
- Belt cancel cues (belt_spill, belt_fumble) and the sickness heart + seconds on the squad row
- Belt item hints: first ground pickup shows its key and effect; tonic and armor kit on low health and armor bre
- Belt item tips on Match._tip: first ground pickup shows its key and effect; tonic and armor kit on low health 
- Belt: six slots, 1 and 2 pinned to the tonic and armor kit; channel times, speeds and heals from data
- Boki state coverage: --boki-anim-audit drives every rigged Boki through every game state; faint plays settle/n
- Boki state cue checks on main: Sfx.listener (main has no move_listener); the nap row waits out main's 15 s wal
- Boki state cues on the 0.24.6 line (SFX_AUDIT row 19): BaseLife eat and nap, one cue per event, MIN_GAP
- Boki wisps (0.24.6 summon line): boki_downed as a summon is killed back into a wisp and as a wisp breaks loose
- Broken casts cut their wind-up sound: Sfx voice handles + KitWindup
- Carry cues: lead swap handover, carry-out claim lock-in, stolen sting / sly take (CarrySfx)
- Checks: glider heat rows measure the real glide (9 s, lift cost, overheated speed and burn); fall parity purge
- Combat HUD calm: armour note, level-up card, UNLOCK word, ground loot names and loot counters wait out a fight
- Combat HUD calm: in a fight toasts and hints queue (only urgent shows), one card at a time in a match, fight e
- Content: one kin folder (kin_v2 -> kin, the home and economy data kin -> kin_home); readers, wiki generator, c
- DASHES_AND_ABILITY_FEEL 5.4/5.5: a freeze costs the cap only the time it adds; your Boki and your Fuse count a
- Delete the dead feel-lab state machine: scripts/feel/, tests/feel_test.tscn, tests/feel_sim.gd, --feel-lab
- Docs and wiki: Vex's Coin Blast (coin toss) and Palm Lance (from the palm)
- Docs: owner-hardware perf notes (PERF_PLAN_1111 already points at them), flagged as history
- Docs: six-slot belt in the equal-footing decision, Nov 9 parity section in the source utilities doc
- Docs: unique decision numbers (oldest note keeps each number, 57 others get 0101+), references follow; health.
- Drop stray .uid files swept in by git add -A
- EggHatch: set_warmth keeps its own doc comment
- EggHover: the hint sits just left of the black egg, clear of the title's line
- Event hints: tide, Heartspark and hot zone get a one-time line
- ExtractGoal: compare seat ids as floats (JSON numbers)
- Fewer text popups: lane shows 2 (1 in a fight), small lines queue and drop in a fight; cut redundant toasts
- Field items to source behaviour: lethal Skyfall with a fire patch, Bounty Banner knock = out, 40 s blighting f
- First-hints check: a scripted first expedition drives each match hint; hints wait out the first 2 s of a fight
- First-match guide: the exit line names the way out the goal line points at, and how to use it
- First-time hints for the Heartspark: 'The Heart is charged...' when it is ready, 'Everyone can see you...' whe
- Fix ext/mc-20261110-1030 parse breaks: stale down_k read, duplicate registry keys
- Fsm M1 hardening: guard_from, timed log with reasons, refusals log, Fsm.live registry; the F7 readout lists ev
- Fsm: --fsm-check audits every Fsm table; delete the dead feel-lab (controller, camera, pad, input, world, test
- Garden Boki voices: HomeVoice caps home Boki voices at 3, once per Boki per 1.2 s, dropped past earshot; sulk 
- Gil: Ground Swim 6 m in 0.4 s (15 m/s) -> 4.5 m in 0.55 s (8.2 m/s), so it reads as under the ground (owner 11
- Glider heat numbers (lift, tap, overheat burn/speed/lift) move into hunter_move.json; check asserts them (glid
- HUD G/armor: before/after shots, style fixes
- HUD feed: a long line is cut at a word so it ends short of the top-centre strips (TextCache.fit)
- HUD: the message column starts under the first-match guide's line, never behind it
- Hatch: the mystery egg's hover is a soft rim glow and a small hint that fade in/out in 0.15 s (EggHover)
- Hearth Lamp belt item, revive sickness as a status (heart + seconds on plate and squad row, hunter snapshot, N
- Heartspark tips ported to Match._tip: 'The Heart is charged' when it lies free, 'Everyone can see you' when yo
- HeroVfx: one comment shortened (the style check's line length, back to its baseline of 0)
- Hit-stop: a freeze asked while another runs costs the player's cap only the time it adds (supervive-impact 847
- Hollow Crown: restore main's legendaries list (cairnback, hivara) that the vfx-utility-read-port regen dropped
- Hover card (world tip) never opens in a fight: it was a 440 px card in the centre of the screen
- HudPlate: SICK_COL with the other consts (gdlint class-definitions-order)
- Hunter first-time hints: four one-line hints per Hunter via Match._tip (HunterHints), save v20 -> v21, --hunte
- Hunter hints: ask after the vision hint so it keeps the lane first
- HunterNet: sickness fields before the channel fields, so the channel stays the row's last two (hudref-check)
- Impact: your Boki's strike and blasts never shake your camera (Match.shake door deleted); a freeze asked in a 
- In-match shops: four vendors on The Hollow Crown, seeded stock for run gems, shop panel, full-map legend, bot 
- Incoming-hit cue: a hit on you plays hit_in panned toward where it came from (IncomingHitSfx); --incoming-hit-
- Inventory pass: full pack on one screen, belt counts apart, deathbox footer inside its window
- Kael black-red: his VFX keys, chain and model crack go black and crimson to match the red-vein splash (owner 1
- Kael: take ext/kael-black-red's owner pick A kael_v95.jpg (missed in the stuck-integ-03fec497 merge)
- Keep the cursor in the window during a fight (CursorMode helper, Controls setting, --cursor-mode-check)
- Kill feed: knock rows with faces and the ability icon (KnockFeed)
- KillFeed: clear() and rects() (the message cards keep off the feed's rows), the lane's MsgLane API ported from
- KnockFeed: lane 266 px so it clears the message cards inside the safe margin (row paddings tightened, names 82
- Lane N2 after merging main: BaseFetch.playing() (GardenMusic ducks for a Fetch Cup round), --backpack-check co
- Lane N2: --cast-lock-buffer-check: Vex's ult wind-up no longer locks the body on main
- Lane N2: --clip-cancels-check follows main's blend_out and drops a stale entry; --abyss-check's fall depth tol
- Lane N2: --knock-feed-check clears the first-match banner and fight state before it counts message cards
- Lane N2: --launch-arc-check's pad carries the new jump-pad fields (lift/push/arm); Tender ember_hit uses palet
- Lane N2: --sfx-set-check reads the uplink countdown in exits_flow.gd (exits split)
- Lane N2: Dredge's barge keeps main's 0.18 s press hold (be6ffab8's shared 0.15 s window dropped a press inside
- Lane N2: Sparkle's Wirerun hold ignores a Space pressed on its first step (dash_jump 'same' row stays ignore; 
- Lane N2: Training Grounds: item pedestals skip the tonic/armor-kit slots when the six-slot belt is full, item 
- Lane N2: after merging main: tut-wide-cam's wall kick and pad sign are on main (p07's copies dropped)
- Lane N2: checks follow main's rules after the merge (thief bolt flash dropped for the hit-feel table, glide fr
- Lane N2: checks follow the bundle: --clarity-check drops the Sable bolt-flash case (the flash itself was dropp
- Lane N2: health ratchet back to main's reds (merge-from-wisp decision renumbered 0171, four long lines shorten
- Lane N2: juggernaut_kit reads Loco.press_buffer (be6ffab8 dropped BUFFER, main's pull code still used it); dro
- Lane N2: keep main's Lace (hem.glb) and Tenzo (tarek.glb) models; rig-ship's re-weighted glbs stay on ext/rig-
- Lane N2: style ratchet and decision-number clash (0101 one-movement-profile -> 0160)
- Lane N2: the tight standing view eases a terrace step at most 2.4 m/s (--step-smooth-check bulwark/thief back 
- Loading bar: runs the last stretch over FILL_T instead of snapping full (--loading-check jump fix, from ext/ui
- Loading screen: painted splash unwashed, text bottom-left, no glass card
- Match HUD: G only on the Boki slot (drop the duplicate beside the utility belt); armor above health on own HUD
- Meeko: Ember Cast hit leaf chunk-and-spark burst; Hearth Call draws a ring at its 12.6 m tether range (P14 vfx
- Merge origin/main into ext/hunter-first-hints-port (dredge.json: keep hint + main card)
- Merge origin/main into ext/p19-port-1118; shorten one registry comment for the style ratchet
- Nametags: name only, smaller; no level badge or bounty text line
- Naming line for a new Boki: suggestion from the species name, dice, text box, Keep
- Net 0.24.18 for the shop events (sbuy/sgot/sno); the port's 0.25.0 sat on the old lobby note and above main's 
- Net.VERSION 0.25.2 comment: one deathbox note, heart note
- One movement profile (owner 11-11): a body stays on ground that drops under 0.45 m (the farm's flights), the v
- Ostra combo check: the rank-3 seed burn band reads the data's burn (8.2/s, Void E 250 dmg/s vs 365 bomb) inste
- PanelClose: 'outside the panel' from the right click's own position, not the pointer's (under xvfb the pointer
- Port ext/stuck-integ-b771bcef's unique work onto main: steal cues (StealSfx cry/reel thud, steals.json, wavs, 
- Registry: drop a comment that made one line over 120 (style ratchet)
- Revert the sfx-listener-hunter port (282fa584a9): its 3D casts in checks need the 3D listener base (AudioStrea
- Rig: Lace, Kael, Tenzo skin weights from the bake-off methods, patched into main's glbs (glb_reweight.py: only
- Rig: better skin weights for Sable (voxel), Tenzo (Meshy), Kael (voxel), Lace (voxel), rebuilt with v95_to_gam
- Rig: skin-weight transfer matches by body part (aligned per part), smooths clashing neighbours; Sable (voxel w
- Rules.md regenerated (main's camera presets)
- Sable dropped from this PR: main's sable.glb (new painted face) restored
- Sable's crossbow hits flash the struck body in her colour (Ent.flash_tint); --clarity-check row (P14 combat-sa
- Shake: your Boki's landing strike and blasts never shake your camera (supervive-impact 215e18e9f)
- Shop screenshots hook, wiki refresh, shorter legend lean text
- Shops/utility_more: callout words go to HUD toasts, shop panel uses the installed theme (uipolish rows same as
- Shops: drop chest_key from the never-sell list (keys_check text rule: only key tables may name a chest key; sh
- Shops: legend gets its own space under the squad panel, shorter lean text with player category names, one Armo
- Size baseline: 842.5 -> 884.7 MB. Main's art since the last bump grew textures +38.6 MB and left main at +5.0%
- Sparkle: Space in the Wirerun's air hold opens the glider (DECISIONS 11-08); glide-hold-check drops the SWALLO
- Spike blocks on GlideSpike: Tenzo's tap Quakefall (+40%, no abyss extra) and Grimble's ground Anchor Drop spik
- Splashes: 10 Hunter splashes re-cut at 2400x1350 from the live site art (lossy import)
- Split models.gd (3304 lines) into focused models_<part>.gd files behind a forwarding facade; style debt moves 
- Stale player-facing text pass: README controls/revive/shimmer/renderer, wiki Controls and Classes (R ult, X Fu
- Style ratchet: fix 2 lines main got from #351 (long line, history comment) so health --strict passes
- Style ratchet: wrap the inherited long lines (main.gd, exit_models, models, title, check_registry)
- Style: keep the branch's gdformat'd AbilityText files and hud_hover (style ratchet); shorten one registry comm
- Style: the ported lines under the ratchet (registry comment, heat vars, camera rate, check strings)
- Style: wrap the Quakefall doc line, Gil's move-feel source note without a history tag
- Tab board: your squad's stats, gear and Boki; rivals reduced to a squads-left count
- Tab squad board: squads left, pips per squad, your squad's levels/knocks/Boki, Ways Out line
- Tenzo skin slot albedo 0.8 grey (old tint read orange); V95_SWAP rebake and clip-shots yaw notes
- Tenzo: Basalt Spine rocks wear one joined ridge fin and a glowing seam; the fin crumbles with its rock; pooled
- Tenzo: the owner's 11-15 age-down pick (hunter3d1115/A) in game, Meshy skin weights; height_3d 1.13
- Title shots: wait for the logo and menu to finish fading in before the title picture
- Title: trailer arrangement of Hearthlight at 108 BPM with drums; boom under the logo, swell on each crossfade
- Tools: v95_swap fit moves each vertex by its voxel skin weights
- Tutorial driver: the wall kick is pressed from the take-off on (P07 port of tut-wide-cam)
- Tutorial fight check: each starter plays from the start
- Tutorial framing per starter at 1280x720 (P07 port of tut-wide-cam)
- UI clutter: keep a clear zone over your own hunter (HunterZone)
- UI overload: newcomer HUD staging, one-line extraction goal, map seat labels
- UiTorn: corner points can no longer fold over their chip (port of ext/combat-neve-lmb-torn 08a413d06, READY, s
- Uplink lift: 10 s countdown ticks (squad UI-level, rivals from the lift); nothing played warn_tick on main (P1
- Utility looks: Skyfall fuse fill follows match time; reel frames each effect centred, HUD off, rival on solid 
- Utility looks: Skyfall fuse ring, Blight Flask edge, Twin Gate portals and link, Thorn Wall spikes, Warp Seed 
- Vex E: the beam opens out of her palm (a nose taper on her three beam layers)
- Vex checks: the coin and the beam leave her palm, the gun arm stays down, the flick is 0.5 s
- Vex clips: coin_flick and palm_cast in a clips-only glb, added to her library at load (vex.glb untouched)
- Vex timing check: drop _knock's unused argument and one capital argument name (gdlint back to its baseline cou
- Vex: RMB is a coin toss from her free hand, E charges at and fires from her open palm (presentation only)
- Voice sets for the candidate's new rigged species: caecilith, lilybara, umbrathere
- WIP checkpoint 20261115-074018-a5 2026-11-15T07:45:12Z
- WIP checkpoint 20261119-014338-a4 2026-11-19T01:48:36Z
- Ways Out HUD: a new player keeps the quest card and the out-line (only the four seat cells differ)
- Waystone card: keep main's one lock line; the closest-Boki hint from ui-waystone-keys rides at its end
- Waystone locked cards: name where each key comes from (Old Pell's Wayseed every 3 days for 110 gems; the close
- Wiki: regenerate Controls (F7 move_readout key) and Rules (tuning.json) so gen_wiki --check passes
- Wrap hud_vitals header comment (style ratchet after merge)
- Your own CC on the HUD: one line under the vitals, each effect's word and a bar shrinking over its time, worst
- ZoneCards: wrap two long lines (style ratchet)
- blight_nest_check follows main: a bot player needs a mind, gems counted by value (DropMerge piles), a bot star
- boki-rig-check: fixed kin uids + 15% roam floor (the fliers' row was a dice roll)
- box_revive_check: keep the solid test under the style ratchet
- box_revive_check: pick a spot with no solid within reach (the merged world put a stall there and shoved the re
- carry_take reach 34 m (main's hear range is now 30 m, the take must carry past it); rewrap wisp_steal_check he
- check_registry: drop duplicate --fsm-check key from the merge
- check_registry: main's file plus --vex-cast-closeup (drops the branch's whitespace reformat)
- combat tools: gdformat + gdlint clean
- combat-calm-check: the world hover card stays shut in a fight (HudHover.world_tip_waits)
- combat-hud-shots: a 15 min match (the 1e9 length showed a 16666666:36 timer); before/after re-shot on the RTX 
- combat-hud-shots: the same bot-duel and PvE fight frame on the real HUD, for before/after (+ hurt_wash.gd.uid 
- docs/HUD.md: the guide's exit line and the message column under it
- docs/HUD.md: the kill feed (KnockFeed) row, its pop-up budget line, the lane checks; style baseline locks in h
- docs/HUD: the world hover card stays shut in a fight
- docs/HUD: what a fight shows now
- docs/heroes/dolm.md: Basalt Spine rocks share a ridge fin (P14)
- docs/shots/combat-hud-calm-1119: the same bot-duel and PvE fight frame at 1920x1080, before and after
- docs/shots/ui-inventory: GPU before/after at 1280x720 and 3440x1440 (jobq), notes on the stale-import crash an
- docs/shots/ui-knock-feed: GPU shots of the kill feed at 1280x720 and 2560x1080
- docs/shots/waystone-keys: the Waystone row on a real GPU (jobq 20261112-112411-05121)
- docs: ui-inventory pass shots (1280x720, 3440x1440 before/after) and HUD.md inventory lines
- empty_shots --only=eggs: hover and leave the mystery egg, then pick and start its hatch
- first-hints-check: rivals stand still and the player is held during the Heartspark moments
- first_match_guide_check: split a long line (style ratchet)
- fix(registry): drop duplicate --level-hud-check row (main added the same row; duplicate dict key broke main.gd
- garden HUD groups: park the pointer at the top edge before counting (xvfb left it mid-screen on a Boki: its ho
- garden-sfx-check: the nap walk wait on its own line (style ratchet)
- gdformat (line length 120) on the scripts the Vex coin/palm change touches: no behaviour change
- gdformat the new AbilityText files
- heart-check: ignore the machine's mod-mode god flag
- hearth_lamp: name its body move (place) and cast time (0.6 s) so --utility-pose-check maps every belt item
- hob_talk: no 'release' on a null CamLook when Hob talks before the look is made (new-player-flow-check script 
- hud-g-armor port: the Boki card's G slot counts the throw wait down (the belt-side G slot that drew it is gone
- hud: one red low-health edge: skip LowHpCue's glow while HurtWash shows (heartbeat sound kept)
- integ: clip-cancels CANCEL_OPEN: jug_reel>jug_dash now passes (dropped); jug_lunge_wind>jug_lunge 0.79 m opene
- integ: drop the duplicate HeroVfx._look_rng from the vex-coin-palm merge (parse error)
- integ: re-add WardenClipFile.add from ext/vex-coin-palm-1117 (lost in the warden_clips resolution; Vex coin_fl
- integ: shorten the new CANCEL_OPEN note (style ratchet)
- integ: wrap a long comment line in kael_tap_ult_check.gd (style ratchet)
- inv_shots: say when a shot is not saved (GPU before-run came back with captions only, no reason in the log)
- inventory_check: shorter comment (style ratchet)
- kit drill check: Vex's rmb line says 'coin' now (launcher -> coin toss rename)
- kit-text-check reads a knockup field as a duration (Gil's 'knocks them up for 0.5s' sat near the 0.55 s Ground
- loading-check: test the tip against TipPick's tip set (loading.gd's TIPS table moved to content/rules/tips.jso
- match-audio checks on main: the carry row gives its bot a second Boki (main retired TWO_KIN); the interrupt ro
- match-audio-check: the wind-up cut is timed in game frames, not wall ms (13 false reds on a slow box)
- match-audio-check: type the carry reach row (parse error after the style split)
- match-audio-interrupts: send the check's downed Boki away so its rescue channel doesn't gate the Dolm fist hol
- match-audio-interrupts: the no-new-player row ignores held channel loops and the one-off sting player (both th
- match.gd: knock credit on one line (god-file budget after the KnockFeed wiring)
- match_audio_interrupts: gdformat
- move-feel-check: Gil's ground row follows the slower Ground Swim
- mystery-egg-check: warp the pointer too (under xvfb a parsed motion left it mid-screen, so the black egg's hov
- perf-bench: --bench-ab runs pets, Boki wisps, pets again in one process so the A/B shares one GPU
- sable_wings_shots: drop the stale WardenGlb.set_model call (main's version; the function does not exist)
- safe-area, cooldown-text, equal checks: run on a veteran save (they test the whole HUD; a new save's is staged
- sfx_world.json: scan exits_flow.gd and utility_more.gd (split out of exits.gd / utility_use.gd); the moved hol
- tools: --vex-cast-closeup films Vex's RMB and E close up (front and 3/4) for the owner clips
- tools: Vex close-up recorder draws the real fx (listener at Vex), all overlays off, a close free-hand view
- uid files Godot made for the two combat tools
- uihud bundle: Neve (rimewright) splash back to main's 11-15 hair-pass owner pick (the lane's 2400 re-cut preda
- uihud bundle: gate reds fixed: splashes back to main's 960x540 owner picks (--portrait-check wants SPLASH_PX; 
- uihud bundle: hudref check runs the wash pass before the size pass (which draws its own match); knock-feed che
- uihud bundle: message cards slide aside of the kill feed's rows (MsgLane.keep_off <- KnockFeed.rects(), screen
- uihud lane -b: egg-card check follows main's hidden mystery card (three starter cards, the mystery one once pi
- uihud lane -b: hatch naming Enter key uses NameStep.box (merge fix)
- uihud lane -b: wrap the two long lines the merge added (hud_vitals header, hatch_check starter-card name)
- uihud lane: HurtWash reads DamageDir.hits (main replaced Hud.hurt_dirs/hurt_from); check follows
- uihud lane: drop duplicate check_registry keys from union merges
- uihud lane: drop the full-pack-at-720p check (it asserts ui-inventory-pass's compact rows; the bundle keeps ma
- uihud lane: level-up card reads LevelGrowth.rate (main's straight-line growth); egg chips use a named shell co
- uihud lane: level-up card shows main's 3.9% ability power growth (one decimal); check follows
- uihud: check_registry dedupe after the main merge (main already has the ways-out and carry-boki rows); only --
- uipolish-check: drop the Dash result-card checks (main replaced RaceGame's card with BaseRace)
- v95 swap --weights meshy: a thigh's weight above its hip joint goes to the hips
- v95 swap: --weights meshy (Meshy auto-rig skin weights mapped onto the game skeleton); clip shots: --turn-clip
- warden_model_check: wrap dolm height comment (style ratchet long_line, PR #284)
- ways-out-sfx check: the rival that takes the Heartspark is one still standing (with the new shop spots the fir
- ways_out_sfx_check: wrap the standing-rival comment (style ratchet)
- wiki Rules.md: regenerate tarek warden_look row for this PR's skin albedo
- wiki: regenerate Rules for the Wayseed card text
