# Idle and stance audit: every Hunter standing still (Nov 7)

The owner (Nov 7): every Hunter's standing animation looks bad, with weird poses that are neither natural nor true to the
character. This page shows what each idle and stance does today and what it should do instead. Personality comes only
from our own characters (content/archetypes, LORE_MASKS, briefs/DECISIONS.md final names, briefs/art-refs).
Parity with a top shipped game applies to **quality** only: weight, overlap, a readable silhouette, a seamless loop.
No source hero's pose or attitude is copied.

## How this was measured

- **Strips.** `godot -- --idle-shots --shots-dir=<dir> [--wardens=a,b] [--frames=12] [--size=360]` (tools/idle_shots.gd).
  Per Hunter it writes:
  - `idle_front/`, `idle_side/`, `stance_front/` and `stance_side/`: 13 even samples of the keyed clip, f000 to f012.
    f012 is the clip's end, so comparing f012 with f000 shows the loop seam.
  - `live/`: the game's own hand-off while the Hunter stands still, every 0.5 s. HunterAnim drives the still state and
    WardenClips cross-fades idle into stance after `stance_after`.
- **Frame refs** below read `<strip>/fNNN`. live f000 is the spawn frame before the first blend (a tool artifact; ignore
  it). The lantern swing on Grimble at f000 to f002 is his spring bones settling after the tool turns the model. That is
  also a tool artifact.
- **This run** rendered on the hetzner box (Xvfb + llvmpipe, 2 min for all 12). The GPU worker had stopped claiming
  jobs (last heartbeat 20:07). The same run is still queued on it as jobq `20261107-200001-02555`.
- **Numbers** are read from the .glb clips. `--clip-check` now asserts them; see "The check" below.

## Ranking, worst first

| # | Hunter | Main problem |
|---|---|---|
| 1 | Kael the Unbroken (`juggernaut`) | No clips at all: a procedural mannequin frozen in an A-stance |
| 2 | Mossy the Barnacle Knight (`bulwark`) | Loop pop; 1.6 s stance; a shield wall hides the warm giant; the shield snaps up in 0.5 s |
| 3 | Tenzo the Stone Seer (`dolm`) | 0.8 s stance: a 2.5 Hz hip jitter; the feet slide in the hand-off |
| 4 | Cinder the Flame Queen (`ashwick`) | Arm locked straight out for the whole idle; built on the flamethrower the owner removed |
| 5 | Sparkle the Storm Chaser (`mage`) | "Never quite still" stands frozen for 5 s; the gum pops |
| 6 | Motley the Void Jester (`ostra`) | Finger pop of 11 to 16 deg at every loop; T-pose arms; the stance has no body keys |
| 7 | Meeko the Dawnfox (`tender`) | Idle and stance built on the lantern that DECISIONS dropped |
| 8 | Neve the Snowglide (`rimewright`) | Toy-soldier pike stance, feet together; no skater weight |
| 9 | Sable the Silver Thief (`thief`) | Square, locked knees; the stance only raises the pistol |
| 10 | Vex the Hired Gun (`gunslinger`) | Locked knees and a dead pelvis, but the coin flip is a real signature |
| 11 | Lace the Red Stitch (`archer`) | Close in attitude; only the head moves |
| 12 | Grimble the Scrap King (`dredge`) | Hunch and hook read in character; motion too small |

## What is wrong with all of them

1. **Sine metronome.** Every keyed idle is a few sines at 1x or 2x of the loop, on one shared phase, at 1 to 3 cm and
   1 to 3 deg. Nothing leads and nothing follows, nothing settles or holds, and there are no overlapping parts. The
   result reads as a mannequin on a turntable, not a person breathing. Shipped-quality idles offset each part
   (pelvis, then chest, then head, then hands, each 2 to 6 frames later), hold a pose, then shift weight with a
   settle.
2. **No chest.** The rig has no spine, chest or neck (RIG_CONTRACT: the head and arms hang from `hips`). Breathing can
   only move the whole upper body or the head, so the chest never rises.
   - Each rework adds a leaf `x_breath` bone under `hips`, skinned to the rib cage and keyed with a 1 to 3 % scale.
     Leaf `x_*` bones are already allowed; `ostra` ships some.
   - A real spine/chest/neck in the contract would fix this for every Hunter. That is a contract change
     (WardenSkeleton, every .glb, a docs/decisions note), so it is filed as a suggestion here, not done.
3. **Locked knees and a dead pelvis.** On 9 of 12 Hunters the hips do not move in the stance (`hips` Y = 0) and both
   knees are straight. Weight never sits on one leg.
4. **Stance and idle use different feet.** WardenClips cross-fades idle into stance linearly over 0.5 s
   (warden_clips.gd:432). When the two clips plant the feet differently (Tenzo, Mossy), the feet slide and the arms
   swing through each other. Each stance should keep the idle's feet, or start from the idle's last pose.
   - Code suggestion, separate from these items: ease the `stance_w` blend (smoothstep) and lengthen it to about 0.8 s.
5. **Stale personality text.** content/archetypes still holds the old lines for Mossy, Meeko, Kael, Grimble and Cinder.
   The specs below follow the newer source; a text task should bring the archetype files in line.
6. **No fidget.** No Hunter has a signature beat. Each spec below bakes one into a longer loop (6 to 9 s), because
   WardenClips has no random fidget layer. Adding that layer later would let the loops shrink back.

## Per Hunter

Each target applies **quality** parity only. The attitude comes from the line quoted for that Hunter.

### 1. Kael the Unbroken (`juggernaut`, art `kael`): procedural, frozen

- **Source:** LORE_MASKS, which wins per DECISIONS: "grim, cold, never cocky"; kael_clips.py: "enormous, grim,
  economical". The archetype line "a proud champion... fights like the crowd is watching" is stale.
- **Today:**
  - kael.glb carries 0 clips (KIT_PARITY gap 1), so he stands on procedural HunterAnim.
  - live f001 to f015 (7 s) are identical. The sword hangs out at his right, angled away from the leg as if on a rod.
    The left arm is dead straight and the legs are spread in a wide A.
  - There is no breath, no weight and no stance hand-off.
- **Target idle (6 s):**
  - A planted, wide-but-relaxed base with the weight on the back leg; knees soft.
  - The sword's point rests on the ground at his right foot, with the hand over the pommel. The blade's weight pulls
    the right shoulder down.
  - Slow, deep breaths (`x_breath` 3 %, one breath per 3 s). The head barely moves and the eyes stay level.
  - Fidget once per loop: he rolls his neck a few degrees and resettles the grip, a single economical motion.
- **Target stance (8 s):**
  - The same feet. He lifts the sword onto his shoulder, then holds still for long stretches.
  - Once per loop the shoulder dips under the weight and he resettles it.
  - Nothing showy: stillness is his attitude.
- **Work:** bake kael_clips.py (idle :39, stance :53) to the spec into the v2 .glb, and add
  `content/rules/warden_anim/kael.json` (loco idle/stance, `stance_after` 4.0) so WardenClips takes over.

### 2. Mossy the Barnacle Knight (`bulwark`, art `breaker`)

- **Source:** archetype ("huge, warm-hearted... laughs easily and guards everyone near him"). FIDELITY: a round
  shipwreck-hull body, a diving-helmet porthole face with mood eyes, an anglerfish on a line, a capstan hammer and a
  figurehead hatch shield.
- **Today:**
  - The idle seam pops the head 4.2 deg at idle_front f012 to f000. `breathe()` (breaker_anims.py:67) runs root and
    head at half rate, so a 3.2 s clip ends half a cycle off.
  - idle_front f000 to f012 are almost identical: the 1 to 2 cm sway is invisible on a body this size.
  - stance_front f000 to f012: the hatch shield is raised square in front of him, covering the porthole face and the
    whole body. The friendliest Hunter reads as a wall.
  - stance_side f000 to f012: the shield stands off the body like a free plank.
  - The stance is only 1.6 s and has the same 4.2 deg seam.
  - live f008 to f009: the shield goes from his side to in front of his face within one 0.5 s step, a linear lift of a
    door-sized prop.
- **Target idle (6 s):**
  - Big, slow belly breathing (`x_breath` 3 %, plus 2 cm of hip rise). Weight rolls from foot to foot every 3 s like a
    sailor on deck. The head lags the body by 4 frames.
  - The anglerfish lure bobs on its line with overlap: it trails the head, overshoots, settles.
  - The shield rests on the ground against his left leg, hatch outward, with his hand on its rim.
  - Fidget once per loop: he glances down at the lure and his porthole eyes go happy (mood texture) as it bobs.
- **Target stance (6 s):**
  - The same feet. The shield comes up to chest height only, angled so the face stays visible: a host standing
    in front of his crew, not a door shut.
  - The capstan hammer rests on his shoulder. Same weight roll, slower.
- **Seam:** derive every curve from the loop length (full cycles only) so `--clip-check` passes. Remove both
  `bulwark:*` entries from `STAND_OPEN`.
- **Done (ext/idle-bulwark):** tools/art1/breaker_anims.py `idle_over` / `stance_over`.
  - Idle 6 s: a sailor's roll (one cycle per 3 s, soft knees, the hip 2 cm up on each breath), two breaths on the
    new `x_breath` bone (3 %, skinned to the rib cage by `anim_kit.add_breath`), pelvis 2 frames and head 4 frames
    behind the body, the hands 6 frames behind. The hammer drum and the door's edge stay planted on the ground while
    the body rolls over them.
  - Fidget at 1.3 to 2.9 s: he turns and nods at the lure; `warden_anim/breaker.json` `"glance"` turns the porthole
    eyes happy over that window while the idle alone plays (`WardenClips.idle_at`, `WardenMood.step`).
  - Stance 8 s, not 6: the slower roll (one cycle per 4 s) has to close on the loop. The idle's feet, the door at
    chest height angled out so the face shows, the hammer on the shoulder with one hitch per loop.
  - Seams 0.0x the limit (`--clip-check`); before and after strips: jobq `--out shots_before` / `shots_after`.

### 3. Tenzo the Stone Seer (`dolm`, art `tarek`)

- **Source:** archetype ("a young, nimble rock elementalist with a bandana over his eyes. He reads the ground by feel.
  Quiet and light on his feet, he moves stone like it [is a dance partner]").
- **Today:**
  - idle_front: arms hang straight with the gauntlets and the feet are square. Only the stones over his head move.
  - stance_front and stance_side f000 to f012 cover just **0.8 s**: a 2.2 cm hip bounce at 2.5 Hz (tarek_clips.py
    :82 to :90). It reads as nervous jitter, not a calm blind seer.
  - live f012 to f013: the idle's square feet cross-fade into the stance's split feet, so they slide.
- **Target idle (6 s):**
  - Weight on the balls of the feet, knees soft, one heel lifting and lowering (he feels the ground).
  - The head tilts and listens, turning toward a sound rather than looking; no eye-line, because of the bandana.
  - The stones orbit his hands slowly; one hand turns a stone over by touch.
  - Fidget once per loop: he taps a toe and the stones answer with a small hop, like a dance partner.
- **Target stance (6 s):**
  - The same feet. He sinks a little lower into a light, balanced guard. The stones gather between his palms in a slow
    figure-8.
  - Breath in the shoulders; no bounce faster than 1 Hz.
- **Seam / length:** remove `dolm:stance` from `STAND_OPEN`.

### 4. Cinder the Flame Queen (`ashwick`, art `cinder`)

- **Source:** DECISIONS (Nov 7): "no weapons, fire from her hands", obsidian outfit, living-fire hair, a flame-tipped
  tail. The archetype ("salamander-folk alchemist... goggles") is stale.
- **Today:**
  - idle_side f000 to f012: the right arm is locked straight out at shoulder height, aiming the flamethrower, for the
    whole 3.6 s. A pointing statue, and the strangest pose in the roster.
  - stance_front: the flamethrower is held upright by the face and the tank is on her back. Both props were removed by
    the owner. Hips do not move in the stance.
- **Target idle (6 s):**
  - A loose S-curve: weight on one hip and the other knee forward, the tail sweeping slowly behind.
  - Empty hands. One hand rests at the collarbone while the other rolls a small flame across its knuckles.
  - The hair flickers with overlap behind the head turn.
  - Fidget once per loop: she lets the flame lick up her wrist and smiles at it, delighted by fire.
- **Target stance (6 s):**
  - The same feet. Both palms lift to hip height with a small flame in each, and the magma cracks brighten. An
    unhurried shift of hip to hip.
- **Note:** her model still carries the removed flamethrower. Author the hands empty now (the stuck arm is wrong either
  way), and the rework lands cleanly when the v2 model replaces it.

### 5. Sparkle the Storm Chaser (`mage`, art `ryzz`)

- **Source:** archetype ("bold and revolutionary... calls the lightning down and does not ask permission"); lineup
  notes: bubblegum, finger guns, never quite still.
- **Today:**
  - idle_front f000 to f012: the staff is on her right shoulder and her heels are close together. The body moves 4 deg
    at most.
  - stance_front f000 to f012: arms folded with one hand up, unchanged for **5 s** (hips 0, body 4 deg at most). Only
    the gum grows, then it pops at f011 (u 0.92).
- **Target idle (5 s):**
  - Never square. A cocked hip; she bounces lightly on her toes to an inner beat (0.5 to 1 Hz with a hold).
  - The staff swings off the shoulder, spins a half turn and lands back.
  - Fidget once per loop: she blows a bubble that pops, and she snaps her fingers with a spark.
- **Target stance (6 s):**
  - The same feet. Finger guns at nobody, a head tilt, then she drops into a lean on the staff. The bubble grows and
    pops on a beat, not at the loop end.

### 6. Motley the Void Jester (`ostra`, art `ostra`)

- **Source:** archetype ("a sinister, grinning jester who floats... menacing and gleeful"); FIDELITY: a
  jack-in-the-box on a brass spring rising from a hovering box.
- **Today:**
  - The finger bones `x_fing*` pop **11 to 13 deg** at the idle seam and **12 to 16 deg** at the stance seam (f012 to
    f000).
  - idle_front: arms stretched level with the shoulders like a T, a busy silhouette. The cards orbiting are the only
    real life.
  - The 2.0 s stance has no body keys.
- **Target idle (5 s):**
  - Bob on the spring: a compress, hang, overshoot settle once per 2.5 s. The torso lags the box and the head lags the
    torso, the follow-through of a spring toy.
  - Hands low and loose, fingers drumming one after another (keys that close at the seam).
  - Fidget once per loop: the head tilts too far, past natural, and snaps back with a grin.
- **Target stance (6 s):**
  - The same spring height, sinking lower into the box. He shuffles cards hand to hand in an arc.
- **Seam:** remove both `ostra:*` entries from `STAND_OPEN`.

### 7. Meeko the Dawnfox (`tender`, art `pip`)

- **Source:** DECISIONS (Nov 7): "a timid wild Boki... still fears the dark, but walks into the places that scare her
  for anyone who needs her". No lantern: she holds nothing. The sun and raincloud companions are not built yet.
- **Today:**
  - idle_front f000 to f012: the lantern is held out in her left hand.
  - stance_front f008 to f009 and live f019: a big lantern lift to face height dominates the stance. Both clips are
    built on the prop DECISIONS dropped.
- **Target idle (5 s):**
  - Small, close posture: paws together at the chest, ears up. The tail curls forward, then relaxes. The wings flutter
    faintly.
  - Fidget once per loop: an ear flicks and she glances over her shoulder at a noise, then takes a breath and squares
    up (brave).
- **Target stance (6 s):**
  - The same feet. She hugs her satchel strap and rises onto her toes to look ahead.
- **Note:** the model swap waits for her final master sheet (DECISIONS). The rework edits only the clips on the
  current model and hides the lantern by keying it out of view. If companion bones exist by then, leave them unkeyed.

### 8. Neve the Snowglide (`rimewright`, art `claire`)

- **Source:** archetype ("a graceful ice skater who glides where others walk... elegant and playful, with a cold
  edge").
- **Today:**
  - idle_front: the spear stands upright at her right side like a guard's pike and her feet are together.
  - stance_front: hands clasped under the chin. Body 5 deg at most, hips 0.
  - Side views barely change.
- **Target idle (6 s):**
  - A skater's rest: weight on one blade with the other toe tucked behind, and a slow glide-sway left and right with
    the arms trailing.
  - The spear rests diagonally across her shoulders or in the crook of her arm.
  - Fidget once per loop: a small toe-pick tap that leaves frost, then a half spin on one blade back to rest.
- **Target stance (6 s):**
  - The same feet. The spear twirls once and lowers to a ready angle, with a cool smirk.

### 9. Sable the Silver Thief (`thief`, art `sable`)

- **Source:** archetype ("quick, quiet and light-fingered... never where you aimed, and she smiles when you miss").
- **Today:**
  - idle_front: square feet and locked knees; the pistol hangs out at her side.
  - stance_front: the pistol is raised upright by her shoulder and nothing else changes. Hips 0.
- **Target idle (5 s):**
  - Light and off-balance on purpose: weight on one foot, the other on its toe. The head turns quickly, then holds.
  - Fidget once per loop: she spins the pistol back into its holster grip, a sleight of hand.
- **Target stance (6 s):**
  - The same feet, a crouch lower. Her free hand rolls a coin or trinket across the knuckles, then it vanishes.

### 10. Vex the Hired Gun (`gunslinger`, art `vex`)

- **Source:** archetype ("a sharp, professional soldier... calm under fire, always has a plan").
- **Today:**
  - idle_front: straight locked legs and a hand on the hip; body 4 deg at most, only blinks.
  - stance_side f001 to f002 and f007 to f008: the coin flip is a good signature already.
- **Target idle (5 s):**
  - Contrapposto with one knee soft. The minigun's weight sits on the back and shoulder, so the torso leans a degree
    against it.
  - A slow scan of the horizon: a head turn, hold, return.
- **Target stance (6 s):**
  - Keep the coin flip and add a follow-through: the head follows the coin, there is a small catch dip, and she pockets
    it.

### 11. Lace the Red Stitch (`archer`, art `hem`)

- **Source:** archetype ("a cool, patient hunter... says little and watches everything"); briefs/art-refs/ravel_v2
  (a marionette seamstress with needles crossed on her back, red strings, a recurve bow).
- **Today:**
  - idle_front: the bow is down at the left with a mild contrapposto. Only the head moves (7 deg at most); the hips are
    still.
  - stance_front: hand on hip.
- **Target idle (6 s):**
  - Stillness that reads as watching: long holds, then one deliberate head turn that the shoulders follow 4 frames
    later.
  - Fidget once per loop: she draws a red thread taut between two fingers and lets it go.
- **Target stance (6 s):**
  - The same feet. The bow comes up loosely across the body and an arrow is nocked, not drawn.

### 12. Grimble the Scrap King (`dredge`, art `dredge`)

- **Source:** DECISIONS final name; lineup: greedy, hunched, a smug squint, the hook arm, appraising coins through his
  loupe. The archetype ("a broken machine...") is stale.
- **Today:**
  - idle_front and stance_front: the hunch and the hook arm read in character.
  - Body motion 5 deg at most; idle and stance are nearly the same pose.
- **Target idle (5 s):**
  - A greedy sway from foot to foot, with the hoard on his back swinging a beat behind.
  - The hook taps his leg.
- **Target stance (6 s):**
  - The same feet. He pulls a coin, squints at it through the loupe, bites it, and pockets it.

## The check

`--clip-check` (tools/clip_check.gd `_standing`) asserts, for every Hunter with keyed clips:

- the idle and stance loops close: the last key is within 1 deg (`SEAM_DEG`) and 1 cm (`SEAM_M`) of the first, on
  every track;
- each clip lasts at least 2 s (`STAND_MIN`).

`STAND_OPEN` lists what is still open: `ostra:idle`, `ostra:stance` and `dolm:stance`. Open entries are reported, not failed. An entry that starts passing fails the run until it is removed,
so each rework must delete its own entries.

## Verifying a rework

1. Before, and again after re-exporting the .glb, run
   `jobq submit --needs gpu --tree <tree> --out shots -- --idle-shots --wardens=<id> --frames=12 --shots-dir=shots`.
2. Compare idle and stance, front and side, f000 against f012 (the seam), and the `live/` hand-off.
3. Run `--clip-check`.
