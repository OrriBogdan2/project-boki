# Server update 6: hunter ultimates on X (owner decision, 16:30 ET)

Queue this after each kitfix pair is ready. Run one follow-up per pair on the same pair branch, or as ext/ult-<pair> from it. Use **Opus 5.5 at medium effort**.

## Design (owner)
- Every hunter gets their own ultimate back on **X** (rebindable). It unlocks at level 6 and runs on its own cooldown.
- **Landing it charges the Boki bond** by about 60–80% of the bar (tunable in content/rules). Pay out only when it lands, catches or kills someone, not when it's cast.
- The main session owns the bond and merge files and is adding a public hook (EXT_TO_MAIN 16:30 ET asks for `KinBond.add(h, amount, reason)`; use whatever name it ships). If it isn't there yet, put the call behind a guarded stub in your kit file and say so.
- Merge stays on R. Never bind G, C, R or F.

## Reference
Every `briefs/hero-ref/<name>.md` now ends with a `## Ultimate (on X)` section: input, aim mode, telegraph, animation beats at 10 fps, VFX, numbers, fine print, and Build notes.
Corrections to note:
- Kaiju Blast is one press that fires two waves 0.6 s apart.
- Celeste's Ice Crash: recasting early ends it without the stun.

## Rules
Same as SERVER_UPDATE5:
- Clean room.
- Every ult gets its own noticeable animation, telegraph and sound, timed to the beats.
- The small mechanics: research them, build them, and assert them.
- Use the aimkit telegraphs.
- `_drop_holds()` for any channel.
- Shots go through `spawn_shot`.
- Re-merge the newest main.
- Check: each hero's combo check asserts the ult's cast, telegraph, payoff, cooldown and level gate, and that the bond is added only on a land.
- Screenshots and animation strips go under `ext/hero-shots:<name>/v2/ult/`.
- **Burst:** an ult followed straight by a merge must not one-shot a full-HP target. Assert it in one combined check.
