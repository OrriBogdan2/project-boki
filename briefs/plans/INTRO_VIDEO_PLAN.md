# Intro video plan (the AI-made prologue)

Written 2026-11-08 for the owner, who will make the video on his Mac with a Claude session. This is the plan, not the video.

**Why:** the current prologue (`scripts/ui/prologue.gd`) is five procedural 3D shots (about 36 s plus a title card) with captions. Space or a click advances, holding Esc (`HoldSkip`) skips, then it goes to the hatch screen (three eggs on an island). It shows no real characters, and its captions are out of date ("a Tyrant on the Crown", "He was the Wyrm"). The video shows the real Malgrave, Hunters and Boki in the key-art style.

**Canon** (briefs/LORE_MASKS.md): Malgrave, the Beloved (the Wyrm in human shape) ruled Solmere and fed her soul-Heart her people. Sable reached the Heart and the Wyrm woke; Kael wounded her; the Hollowing broke the land into the Skylands. Her body died but she lives in the Heart in the Hollow, **not defeated**. The Empty are faceless; Masks hold fallen Hunters; Boki are the Skylands' wildlife.

---

## 1. Story beats and shot list

Five beats: **Hook** (shot 1), **Solmere and the Beloved** (2-4), **The Waking and the Hollowing** (5-9), **The Empty and the Masks** (10-12), **Your story** (13-15).

Total: 15 shots, **81 s**. VO is spoken by **Pell** (the tutorial guide, a freed soul) unless the line is marked **M:** (Malgrave). The only on-screen text is the title in shot 15. Subtitles come from Godot (see §6).

| # | s | What we see | Camera | Mood | Refs (briefs/art-refs/) | VO / text |
|---|---|---|---|---|---|---|
| 1 | 5 | **HOOK.** Black, then a heartbeat. The crimson glass Wyrmheart fills the frame and beats once. A masked woman's smile is reflected in the glass, and her eyes open. | Extreme close-up, slow push in | Seductive, wrong | villain/wyrmheart_ref_from_keyart.jpg, villain/malgrave_mask.jpg | **M:** (whisper) "Come closer, darling." |
| 2 | 6 | Solmere whole: a pink-and-white palace, gold domes, red banners, a river, rose petals drifting | Slow crane up and over the bridge | Golden, too perfect | villain/solmere_skyline.jpg | "Once, the sky held one great land: Solmere." |
| 3 | 6 | Malgrave on her coiled infinity-tail throne. Faceful courtiers kneel and throw petals, and she smiles | Slow dolly toward the throne at low angle | Adored, uneasy | villain/malgrave_human.jpg, villain/solmere_throne_room.jpg | "Ruled by Malgrave, the Beloved. A queen who never aged." |
| 4 | 5 | The vault: the Heart glows on a pedestal, and threads of light (souls) flow into it from the city | Slow orbit around the pedestal | Hungry, crimson | villain/hearts_chamber.jpg | "She kept her soul in a heart of glass, and fed it her people." |
| 5 | 5 | **The thief.** Gloved hands with a moth-wing knife reach from the shadows and lift the Heart. It pulses | First-person view (as in the Thief's View key art) | Tense, near silent | sable_v2/sable_v2_master_sheet.jpg, keyart/keyart_thief_view_final.jpg | "Three hundred years. Until a thief reached its heart." |
| 6 | 6 | Malgrave's mask in extreme close-up. The crimson tear-swirls glow, then her face stretches into the pearl dragon's head as wings unfold over the city | Hard push in, then a fast pull back | Awe, horror | villain/malgrave_mask.jpg, villain/malgrave_hybrid.jpg, villain/malgrave_dragon.jpg | "She was the Wyrm in human shape. And it woke." |
| 7 | 5 | Kael leaps against the sky, his chained greatsword white-hot, and cuts the Wyrm's flank. She ROARS | Tracking low angle, fast | Heroic, violent | kael_v2/kael_v2_master_sheet.jpg, kael_v2/kael_v2_splash_final.jpg | (no VO: the roar) |
| 8 | 6 | **The Hollowing.** The land cracks. Thousands of soul-lights burst out and tear the kingdom into islands that lift into the sky | Extreme wide, slow pull back | Fire to violet | villain/solmere_skyline.jpg (composition), ui/ui_style_void_A2_base.png (island shapes) | "The Wyrm broke the land, and stole our essence." |
| 9 | 5 | The Heart drops DOWN through clouds into the violet dark of the Hollow and comes to rest, still glowing | Fall with it, top-down | Cold, deep | villain/wyrmheart_ref_from_keyart.jpg | "Her body died. She did not." |
| 10 | 5 | Dawn over the Skylands. On a floating island, villagers turn toward camera. Their faces are smooth and blank | Gentle dolly along a rope bridge | Quiet, sad | ui/ui_style_void_A2_base.png (islands); villagers are generic | "In time, we were born without faces. The Empty." |
| 11 | 6 | Relics drift up out of the dark like embers: a coin, a chain, skates, a compass, a stitched porcelain mask. A blank hand touches one, a ghostly porcelain face flickers over the blank face, and Vex settles in | Push in on the hand | Hope, eerie | vex_v2/vex_v2_master_sheet.jpg, hem_v5_sheet_vivid.png (Lace's mask), villain/malgrave_mask.jpg (Mask shape) | "Our salvation: the cursed relics we once tried to destroy. Masks, each holding a fallen Hunter." |
| 12 | 6 | Hunters dive off island edges in twos and threes (Odd Jobs, Fallen Court, Hearthguard, Sable and Grimble), racing down through the clouds | Diving follow-cam, whip pans between groups | Thrilling | keyart/keyart_thief_view_final.jpg, keyart/keyart_last_light_final.jpg, boki_hero_lineup.jpg | "Every Hunter races down for the Wyrmheart. One wish: to remake the world, or rule it." |
| 13 | 4 | Deep below, inside the Heart: Malgrave's smile, eyes half open | Slow push in | Seductive threat | villain/malgrave_portrait.jpg | **M:** "Come down to me." |
| 14 | 5 | Morning in the Skylands. Boki play among the islands: a Vespyx pounces, a Prismander glints in a pool, a Mycroll puffs spores, Selenfin glide | Floating sideways track | Warm, alive (the turn to the game's tone) | boki/*_concept.png, ui/ui_style_ref_boki_card.png (Voidling Fox look) | "But the Skylands are still alive. And wild things still look for a friend." |
| 15 | 6 | **Your island:** a small grassy floating island with a stone shrine and three eggs glowing ember, crystal and spore-green. One wobbles and cracks. Cut to black, then **PROJECT BOKI** | Slow push in, ending on the eggs | Hopeful | the in-game hatch island (screenshot via `--prologue`, then hatch), brand/logo_A_wordmark.png | "Your story starts here." Title: brand wordmark |

Shot 15 must match the hatch screen's first frame (same island, the same three eggs), so the cut into `hatch.gd` feels like one shot. The owner should grab a screenshot of the hatch island as that keyframe's ref.

## 2. Style bible (from our real art)

- **Look:** painted stylized fantasy as in `keyart/keyart_thief_view_final.jpg` and `keyart_last_light_final.jpg`: clean shapes, readable silhouettes, soft rim light. Not photoreal, anime-flat or plastic 3D.
- **Solmere (shots 2-4):** pearl white, blush pink, rose and gold under a soft peach sky, with red banners. Red is Solmere's colour (`villain/solmere_skyline.jpg`, LORE round 5).
- **Malgrave:** pearl white, crimson fin ridge and tear-swirls, gold claws (`villain/MALGRAVE_QUEEN_LOOK.md`, `malgrave_dragon.jpg`). Never visibly evil: beautiful and wrong.
- **The Heart:** smooth glossy crimson glass with a pink-red inner glow. No gold veins, no crack (the key-art lock).
- **Hollowing and Hollow (6-9, 13):** ember orange into violet and indigo, purple soul-light: the Void & Masks palette (`ui/ui_style_void_A2_base.png`, briefs/UI_STYLE.md).
- **Skylands dawn (10, 14, 15):** blue sky, peach horizon, green tops, grey-brown rock undersides (the prologue's "dawn" MOODS: `3e72c4`, `8eb8ea`, `ffcf96`).
- **Boki:** chunky, round and friendly, with big eyes (`boki/selenfin_concept.png`, `ui/ui_style_ref_boki_card.png`).
- **Hunters:** v2 master sheets; `boki_hero_lineup.jpg` for scale; `art-refs/FIDELITY_CHECKLIST.md`.
- **Format:** 16:9, 1920x1080, 24 fps.

## 3. Tools (checked 2026-11-08; prices rough, check the live page)

- **Primary: Google Flow (Veo 3.1 + Nano Banana Pro)** on Google AI Pro, about $20/month for 1,000 credits (a Veo 3.1 Fast clip is about 20). **Frames to Video** takes a first and a last frame; **Ingredients** takes up to 3 reference images (8 s clips). Nano Banana Pro made our key art, so stills will match. Expect $20-60 total with top-ups.
- **Fallback: Kling 3.0** (kling.ai): start and end frames, plus reusable "Elements" from 2-4 images per character, about $10-40/month. Use it when Veo drifts off-model or refuses a shot (Malgrave's outfit may trip filters).
- **Also:** Seedance 2.x on Higgsfield (Plus, about $49/month) takes many more references if both struggle.
- **Audio:** ElevenLabs (voice and SFX; Starter about $5/month allows commercial use). Music from a composer or ElevenLabs Music; freesound.org CC0 for extra SFX. No free tiers that forbid commercial use.

Sources: [Flow features](https://support.google.com/flow/answer/16352836), [Flow plans](https://labs.google/fx/tools/flow), [Kling 3.0 guide](https://www.datacamp.com/tutorial/kling-3-0), [Kling pricing](https://magichour.ai/blog/kling-ai-pricing), [Seedance on Higgsfield](https://higgsfield.ai/blog/seedance-2-0-pricing-2026), [consistency roundup](https://www.kapwing.com/resources/best-ai-video-generators-for-character-consistency/).

## 4. Keeping characters on-model

1. **Reference sheets first.** One 16:9 sheet per character (front, 3/4, side, face close-up, palette strip), saved as `refs/<name>_sheet.png`, built from:
   - Malgrave: `villain/malgrave_human_alt_standing.jpg`, `malgrave_mask.jpg`, `malgrave_portrait.jpg`; her dragon form: `malgrave_dragon.jpg`, `malgrave_hybrid.jpg`
   - Sable, Kael, Vex: `sable_v2/`, `kael_v2/`, `vex_v2/` master sheets
   - Boki: `boki/` concepts plus in-game screenshots of Vespyx, Prismander and Mycroll
2. **Character cards.** One fixed paragraph per character (Malgrave: "pearl-white serpent dragon, crimson fin ridge, white porcelain eye-mask with gold scale crest, crimson tear-swirls..."), pasted word for word into every prompt.
3. **Keyframes before video.** A Nano Banana Pro still for each shot's first frame (and last frame when it moves or transforms), with the sheet attached. Approve all 15-25 side by side before spending video credits.
4. **Animate first-to-last frame.** Clips of 8 s or less, one action each, trimmed to the table. Shots 6 and 11 need both frames.
5. **Hide the hard parts.** Hunters in shot 12 are small, back-lit and moving; Sable is only hands; the Empty are generic. Malgrave's face is close only in shots 1, 3, 6 and 13.
6. **Reject drift.** Regenerate if the mask, the Heart (no gold, no crack), Kael's cracks or the palette drift. Log takes in `shots.csv` (shot, take, tool, prompt, kept, note).

## 5. Audio

- **Music:** one 80 s cue. A sweet music-box and harp waltz for Solmere, souring at shot 5. Orchestra and choir hit on the roar (7), a low drone in the Hollow (9-13), then it warms into the game's title melody (14) and resolves on the title.
- **VO:** **Pell** narrates (warm, slightly wry, unhurried; 13 lines). **Malgrave** whispers 2 lines close to the mic, amused, never shouting. The script is the table's VO column, about 150 words.
- **SFX:** heartbeat (1, 4, 13), petals and crowd (2-3), glass chime as the Heart lifts (5), unfurl and roar (6-7), cracking stone and a soul "whoomph" (8), falling wind (9), porcelain shimmer (11), dive wind (12), Boki chirps (14), egg crack under the title (15).
- **Video audio off:** all sound is built in the edit.

## 6. Assembly and in-game use

- **Edit:** DaVinci Resolve (free) on a 1920x1080, 24 fps timeline. Export the master as `intro_master.mov` (ProRes).
- **Game file:** Godot 4.6 `VideoStreamPlayer` plays **Ogg Theora (.ogv)**:
  `ffmpeg -i intro_master.mov -vf scale=1920:1080,fps=24 -c:v libtheora -q:v 6 -c:a libvorbis -q:a 5 -ar 48000 intro.ogv`
  **Budget: 35 MB or less.** If over, use `-q:v 5`, then `scale=1600:900`. Theora decodes on the CPU, so 1080p24 is the ceiling.
- **Where:** `res://art/video/intro.ogv` and `intro_subs.json` (VO lines with times). No burned-in text except the title; Godot draws subtitles through `tr()`, so they translate.
- **Change in `prologue.gd`** (described here; a later task implements it):
  - In `_ready()`, when `res://art/video/intro.ogv` exists and the build is not web, add a full-screen `VideoStreamPlayer` (keep aspect, black behind) to the UI `CanvasLayer` with `bus = "Music"`, and skip the 3D sets and `Sfx.play_music`/`play_ambience`.
  - Keep `HoldSkip`; connect `VideoStreamPlayer.finished` to `_finish()`. Space or a click shows the "hold Esc to skip" hint instead of advancing.
  - Draw subtitles from the subs file with the existing caption `Label` styling.
  - Otherwise (web, or no file), run the current 3D prologue as the fallback. `_finish()` already saves `tutorial.prologue` and goes to hatch or title, so rewatching still works.
  - Add one assert to `tools/prologue_check.gd`: the video path finishes and lands on hatch.
- **Separate small fix:** update the old in-game captions to the current LORE "Prologue text".

## 7. Owner workflow on the Mac (in order)

1. Install: Homebrew, then `brew install ffmpeg`; DaVinci Resolve (free); sign up for Google AI Pro (Flow) and ElevenLabs.
2. `mkdir -p ~/BokiShare/intro`, then `cd ~ && claude`, and paste the message below.
3. Build the sheets and cards (§4), then all keyframes. Claude writes the prompts and checks each still; you generate and save where it says.
4. Approve the keyframes in one pass (the cheap place to say no).
5. Generate the 15 clips (2-4 takes each); keep the best.
6. Make the VO, music and SFX.
7. Cut in Resolve to the table timings; export `intro_master.mov`.
8. Claude converts to `.ogv`, checks size, length and audio, and writes `intro_subs.json`.
9. Leave the files in `~/BokiShare/intro/out/` and tell the coordinator.

**Paste this into the new Mac Claude session:**

```
You're helping me make the ~80 s AI intro video for my game Project Boki. The full plan is
briefs/plans/INTRO_VIDEO_PLAN.md on branch ext/agent-briefs of
https://github.com/OrriBogdan2/project-boki. Shallow-clone that branch into ~/BokiShare/repo
(read-only: never push), read the plan, LORE_MASKS.md and the art refs it cites, then run it with
me step by step. Work in ~/BokiShare/intro with the subfolders refs/, keyframes/, clips/, audio/, edit/
and out/. For each shot, write me the exact prompts (the character card pasted word for word).
I'll generate in Google Flow (Veo 3.1 and Nano Banana Pro) and save the results where you say.
Then look at every image or clip I save and tell me plainly if it's off-model against the refs.
Keep shots.csv as the take log. At the end, convert to intro.ogv with the plan's ffmpeg command
(35 MB max), write intro_subs.json, and check the length, size and audio. Short answers,
one step at a time. Ask me only when you really need a choice from me.
```

**What comes back to us, in `~/BokiShare/intro/out/`:**
- `intro.ogv`: the game file
- `intro_subs.json`: `[{"start": 0.4, "end": 4.6, "who": "malgrave", "text": "..."}]`
- `intro_master.mov`, or a link to it: the master, for re-encodes and the trailer
- `keyframes/`: the approved stills (reusable for the store page and loading screens)
- `shots.csv`, plus a `CREDITS.txt` listing the tools used, the voice and music sources and their licences

## 8. Open questions for the owner (each has a default; agents use the default if there's no answer)

1. **Who narrates?** Default: **Pell** narrates and Malgrave gets the two whispers. The alternative is Malgrave telling it all, which is creepier but gives away less about Pell.
2. **Skippable on first launch?** Default: **yes**, by holding Esc, as now. It can always be rewatched from the title screen.
3. **Should the file live in git?** Default: **yes**, as one file of 35 MB or less in `art/video/`. The alternative is a launcher-only download, which keeps the repo light but makes the setup harder.
4. **Will Malgrave's look pass the video filters?** Default: if Veo refuses her outfit, use the standing ref (`malgrave_human_alt_standing.jpg`) with the feather mantle closed, and move her shots to Kling. Never redesign her.
5. **Voice actors or AI voices?** Default: **AI voices** (ElevenLabs) for now, with the script kept so real actors can re-record later at the same timings.
