# Anim pilot: idle and death slice (Lace, Kael, Vex, Albert)

Same recipe as `ext/anim-tarek-pilot`: Meshy auto-rig, library actions, Blender retarget onto the rig contract
(`retarget_v3`, cycle/floor/lock), 3/4 contact sheets, blind judge (Fable, same rubric: weight/timing, silhouette,
personality, foot contact, loopability for idles, gameplay readability; 1-5). Candidates were shuffled and the
current clip was one of them; the judge saw only letters. Personality briefs came from our own characters
(archetype text, `docs/art/IDLE_AUDIT.md` targets), not from a source hero. Meshy spend: 22 action tasks, about 66 credits.

A clip is kept only if it beats the current one. Judge limit: 10 thumbnails per clip cannot confirm subtle seams
or small slides, so the seam/slide numbers come from `--clip-check`.

| Hunter | Slot | Current | Best Meshy | Verdict |
|---|---|---|---|---|
| Lace (archer, art hem) | idle | 3.8 | a338 4.2 (a249 4.1) | **ship a338**: long still hold, small head change |
| Lace | death | **4.0** | a183 3.4 | keep current (quiet knee, fold, flat) |
| Kael (juggernaut) | idle | 3.9 | a335 4.5 | **not shipped (11-13)**: main replaced the judged idle with the IDLE_AUDIT one (df7b2fa); a335 needs a new judge against it |
| Kael | death | **4.2** | a183 4.0 | keep current (knee, face-down slam) |
| Vex (gunslinger) | idle | 3.8 | a338 4.3 | **ship a338**: weight on one leg, relaxed contrapposto |
| Vex | death | **3.9** | a183 3.7 | keep current |
| Albert (bulwark, art breaker) | idle, death | - | - | not run: Meshy rejects his mesh ("could not be rigged", an1 breaker_rig). His gait stays the generated giant stride (`tools/art1/breaker_gait.py`) |

Rejected across hunters: arms-flare idle (a12 / a249 variants), curl-into-a-ball deaths (a189, a8), flinch-then-late-fall deaths.

Notes: the judge found Vex's head scan subtle and Lace's bow partly hidden behind her body in a338. The
Meshy idles are long (Lace 7.9 s, Kael 11.3 s), so the long holds the audit asks for fit.
Sheets and mp4s: `/home/boki/anim/pilot4/renders/blind/` (key.json maps letters to clips).

Checks on the shipped clips (11-11): `--clip-check` 0 failures, idle loop seams 0.0x the limit for archer (7.9 s),
juggernaut (11.3 s) and gunslinger (7.9 s). `--idle-shots --wardens=archer,juggernaut,gunslinger` on jobq gpu
(job 20261111-041846-25040) rendered clean: no pops at f000 against the last frame. Kael's a335 dips into a deep
forward brace mid-loop, which is the stance the judge scored.

Merge with main (11-13): main rebuilt hem.glb and vex.glb (appeal3 bodies, v95 swap, Lace's longer legs) but kept the
idles this pilot judged, so a338 was spliced into main's files by node name (`/home/boki/anim/pilot4/scripts/splice_idle.py`):
every other clip, mesh and anchor is main's byte for byte, and translation keys move by the rest delta of each bone
(Lace: hips +0.126, thighs +0.132, the same shift main gave her old idle). Kael keeps main's 6.0 s IDLE_AUDIT idle;
his a335 action is still in the pilot folder for a re-judge.
