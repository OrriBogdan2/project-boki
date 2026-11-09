# Secondary motion: do the spring chains settle?

Owner, DECISIONS 2026-11-07: parity means quality, the source's weight and timing in our own characters. This
audit covers the spring chains (hair, braids, locs, manes, tails, wings, coat tails; `WardenGlb.Springs`,
RIG_CONTRACT "Spring chains") on the 12 v2 Heroes after a dash stop, a jump, and a sharp turn. For each chain it asks:
does it settle, does it swing on and on, does it freeze, and does it cut into the body?

## How it is measured

- `godot --headless --path . -- --spring-settle-check` (`tools/spring_settle_check.gd`) moves each Hero the way the
  hunter moves, with only the chains running (no clips, no wind ripple), at 60 fps:
  - **dash**: a dead stop after a full dash (`Hunter.DASH_SPEED` for `DASH_TIME`).
  - **land**: a standing jump (`JUMP_V`, `H_GRAV`), from take-off to landing.
  - **turn**: a 5.5 m/s run, then a 180-degree turn in 0.1 s, running on.
- Per chain it reports:
  - **peak**: the tip's biggest swing off its final place.
  - **settle**: the time until the tip stays within 1.5 cm of that place.
  - **swings**: how many times it passes through that place.
  - **overshoot**: its biggest swing back, as a share of the peak.
  - **into the body**: how far a joint comes in toward the hips-to-crown line, past both its own standing distance
    and its root's.
- The gate fails a chain that takes longer than 1.2 s to settle, swings more than 3 times, does not move on a dash
  stop (frozen), or comes more than 3 cm into the body.
- "Into the body" is a proxy, not a collision test. It is right for hair that lies on the head or back, where any
  move inward is a cut. Chains that hang off a fist or a belt (`spring_hang*`) have no body line, so they are
  reported but not gated on it.
- Known misses are listed in `OPEN`. They are reported, not failed, and an entry that starts passing fails the run
  until it is removed.
- Strips: `jobq submit --needs gpu --tree <tree> --out shots -- --hair-gallery --settle --size=320 --shots-dir=shots`
  (`tools/settle_shots.gd`). The upper body is filmed from the side at 30 fps, from 0.3 s before the event to 1.2 s
  after it. Each sheet `<id>_before.jpg` / `<id>_after.jpg` has three rows (dash, land, turn) and 9 frames per row,
  from -0.1 s to +0.97 s in 0.13 s steps. Made with
  `ffmpeg -start_number 6 -i <scene>/f%03d.png -vf "select='not(mod(n\,4))',scale=213:213,tile=9x1"` per row, then
  `vstack`.

## What the audit found (before)

| Hero | chains | settle (worst) | swings (worst) | into the body (worst, not hanging) | rows failing before -> after |
|---|---|---|---|---|---|
| breaker | 1 | 0.47 s | 2 | - | 0 -> 0 |
| hem | 3 | 0.60 s | 4 | 10 cm (tail, dash) | 5 -> 5 |
| kael | 7 | 0.55 s | 3 | 10 cm (mane_back, dash) | 5 -> 0 |
| vex | 1 | 0.57 s | 4 | 10 cm (braid, dash) | 2 -> 2 |
| ostra | 9 | 0.58 s | 3 | 23 cm (hornL, turn) | 11 -> 11 |
| ryzz | 2 | 0.53 s | 3 | 4 cm (pigR, land) | 1 -> 1 |
| tarek | 3 | 0.57 s | 3 | 14 cm (locs_back, dash) | 2 -> 0 |
| sable | 10 | 0.57 s | 3 | 11 cm (braid, dash) | 1 -> 1 |
| claire | 3 | 0.58 s | 3 | 10 cm (scarftail_braid, turn) | 1 -> 1 |
| cinder | 4 | 0.62 s | 3 | 9 cm (scarftail_hairc, dash) | 4 -> 2 |
| pip | 5 | 0.57 s | 4 | 17 cm (capeback, dash) | 4 -> 4 |
| dredge | 5 | 0.48 s | 3 | - | 0 -> 0 |

- **Nothing overshoots forever and nothing freezes.** Every chain settles within 0.62 s.
- **Every chain has the same timing.** One pull and one damping (tip pull 0.07, damp 0.84 per 1/60 s) give every
  chain a 0.41 s swing with about 22% overshoot per half swing. An antenna, a heavy mane and a lantern all bounce
  alike, which is where we lose the source's weight.
- **The real faults are cuts into the body.** A dead stop or a landing throws hair that lies on the back forward
  into it. On Tarek the stretch also tears the locs' skin into long black spikes (`dolm_before.jpg`, dash and turn,
  first frames).

## The fix: tuning in data, no new system

A Hero's `content/rules/warden_anim/<art>.json` may now carry a `"springs"` block that tunes chains by the start of
their name: `{"pull": [root, tip], "damp", "limit", "limit_in"}`.

- `limit` is how far (radians) a link may bend off its rest line.
- `limit_in` is how far it may bend toward the bone it hangs from (the body side). It is blended by how much the
  bend points that way.
- A link held by a limit loses its speed into the limit instead of being thrown back past rest.
- Chains with no entry run exactly as before (the check's numbers for them are unchanged).

The worst 3 were ranked on the hair chains, the subject of this pass:

- **Kael** (`spring_mane`: pull 0.16/0.05, damp 0.7, limit 0.8, limit_in 0)
- **Tarek** (`spring_locs`: same numbers)
- **Cinder** (`spring_scarftail_hair`: pull 0.2/0.06, damp 0.7, limit 0.5, limit_in 0)

Ostra's hat and coat tails rank worst overall, but they are costume, not hair. They are the next pass (alternative
noted below).

**Kael.** His mane is the heaviest hair in the roster, but it bounced like an antenna: a 0.41 s swing, three passes
through rest after a dash stop, and the back of the mane thrown 10 cm forward into his shoulders on the stop and
8 cm on a landing. The front locks cut 5-8 cm into his chest on a turn. With a lower pull the mane swings slower:
about 0.75 s a swing at the tip, the weight of a mane. Damp 0.7 lets it settle in one pass with about 1%
overshoot at the tip. `limit_in` 0 keeps it off his back and chest while it still streams freely outward and behind
(peak 0.28 m on a stop, 0.49 m on a turn). After: all 15 mane rows pass, at most 2 cm into the body, settles in
0.30 s or less, at most one pass through rest. Strips: `juggernaut_before.jpg` / `juggernaut_after.jpg`.

**Tarek.** His back locs were the worst hair in the audit. They came 14 cm into his back on a dash stop, and the
left locs 9 cm into his side on a turn. Because they lag so far, their skin tore into long spikes. The locs get the
mane's numbers: heavy and slow, with `limit` 0.8 so that no link bends past about 45 degrees and the skin stops
tearing. After: all 9 rows pass, at most 1.2 cm into the body, settle in 0.33 s or less, and at most one pass through
rest (two small ones, 10 cm, for the right locs on a turn).
Strips: `dolm_before.jpg` / `dolm_after.jpg`.

**Cinder.** Her three hair strands went three passes through rest. The left strand cut 9 cm in on a turn and the
centre strand 6-9 cm in on all three moves. She gets a lighter setting than the two manes: pull 0.2/0.06, damp 0.7,
limit 0.5 rad, and none toward the body. That gives a quicker swing (about 0.6 s) that settles in one pass. After:
both side strands pass everywhere, and the centre strand passes the turn (7.5 -> 0 cm). The centre strand on the
dash stop (9 -> 6 cm) and the jump (6 -> 4.5 cm) stays open. That strand hangs almost on her spine line. The jolt of a
dead stop or a take-off pulls the curved strand straight, and a straight strand cuts the corner into her back.
That is no bend at all, so a tighter `limit` makes it worse (tried 0.25-0.35: 4.4-5.3 cm). It needs a body collider
or the strand rigged a little off the back. Strips: `ashwick_before.jpg` / `ashwick_after.jpg`.

## Open (in `OPEN`, docs/DEBT.md)

- Ostra: hat tails (`hornL/R`, up to 23 cm into the body), `wisp` (91% overshoot on landing) and coat tails 0/3/5.
- Pip: `capeback` (17 cm) and `tail` (4 swings on a turn).
- Hem: `tail` and both scarf tails (4 swings on a turn; tail 10 cm in on a dash).
- Vex: braid (10 cm in on a dash, 4 swings on a turn).
- Sable: braid (11 cm, dash).
- Claire: braid (10 cm, turn).
- Ryzz: right pigtail (4 cm, land).
- Cinder: the centre strand (above).

The same `springs` block fixes most of them. The alternative to tuning Ostra's tails next is a short hat-tail
`limit_in` pass for all three hat and cape owners (Ostra, Pip, Hem) in one go.

## Runs

- Before strips: jobq `20261109-103355-05057` (all 12, rp1).
- After strips: jobq `20261109-104244-19449` (Kael, Tarek, Cinder).
- The short captures per Hunter (mp4: dash, land and turn, one after another) are on `ext/secondary-motion-settle-clips`,
  not for merge.
