# The 2v2 tutorial: a sparring match, not a menu

Owner idea (Orri, 2026-11-11). This is the prototype on `ext/tutorial-2v2`: `--duo-tutorial` plays it,
`--duo-tutorial --duo-test` watches the test driver play it, `--duo-tutorial-check` checks it headless.
Code: `scripts/match/duo_tutorial.gd` (beats), `duo_tutorial_cast.gd` (the three bots), `duo_tutorial_drive.gd`
(scripted player), `scripts/ui/duo_tutorial_hud.gd`. Words and tuning: `content/rules/duo_tutorial.json`.
Map: `content/maps/duo_arena.json`.

## The shape
- **The ring.** One round floor, a ruin wall two tiles thick all the way round, no gates, no ledges, no void.
  Four stone blocks for cover, two patches of grass. Anyone knocked into or over the wall is put back on the floor.
- **2v2.** You and **Meeko** (the Dawnfox, a real bot hunter on your team; Lace if you play Meeko) against
  **Clod** (Kael's kit) and **Thistle** (Lace's kit), two ordinary bots at 45% damage.
- **One voice.** Meeko says one short line per beat in a bubble over her head (pinned to the screen edge when she
  is off it). The top-centre pill shows the key and the count (`[key] Slide 1/2`). A row of dots shows the beats.
  Nothing pauses and nothing sits in the middle of the screen.
- **It escalates.** The rivals go *still → strafe → poke (short bursts, taking turns) → fight → full*. They get
  harder only when you pass a beat, never while you're stuck.

## The beats
| # | Beat | Rivals | Meeko | Passes when | Her line (start) |
|---|---|---|---|---|---|
| 1 | meet | still | waits | you walk up to her | "Hi! I'm Meeko. Come over here, I don't bite." |
| 2 | slide | still | at your side | 2 slides | "Slide is faster than running. And you look great doing it." |
| 3 | attack | still | at your side | 4 hits on Clod | "Clod is napping on the job. Go wake him up." |
| 4 | right click | still | at your side | 1 cast | "Your Heavy Shot hits harder. Show him." (Lace: names come from your kit) |
| 5 | E | strafe | at your side | 1 cast | "And your Hail Wall. That one's a crowd-pleaser." |
| 6 | dodge | poke | at your side | 2 slides with a shot closing in (or a rival in arm's reach) | "Uh-oh, they're awake. When they shoot, slide out of the way!" |
| 7 | focus | poke | marks Thistle, fights her | Thistle knocked out | "I'm marking Thistle. Both of us, same one. That's the whole trick." |
| 8 | Boki | poke | fights | you send your Boki | "Cindle is wiggling. Send them in!" |
| 9 | capture | stand back | at your side | a wild Boki caught | "Oh! A wild Boki wandered in. Knock it out, then hold F on it." |
| 10 | revive | stand back | knocked down | you stand on her wisp until she's up | "Oof. I'm down! Stand on my wisp, I'll owe you one." |
| 11 | merge | fight | fights | you merge with your Boki (meter filled for you) | "Your bond is full. Press R, you and Cindle, together!" |
| 12 | finale | full | fights | both rivals knocked out | "That's everything. Now let's win one for real!" |

Done lines are short payoffs ("Smooth." · "He felt that. Probably." · "Can't hit what isn't there." · "Back up! I
totally meant to do that." · "We won! You're ready for the real thing."), then the end card: *Sparring match won*.
Fight barks, at most one every 4 s: your knock ("Textbook."), hers ("My little sun did most of that."), you going
down ("Up you get. Happens to me all the time."), a rival back up ("They always come back. It's kind of sweet.").
Abilities are named from your kit (%A, %N); keys from your bindings. No Boki: beats 8 and 11 drop out.

## Fail-safes
- **Stall:** 9 s with no progress: Meeko says the beat's nag line ("Slide! Like you're late for something.") and
  the pill pulses; again every 9 s.
- **Skip:** 32 s with no progress: the beat passes itself ("Let's skip ahead. I won't tell.").
- **Capture help:** 14 s in and the wild Boki still up: her little sun bonks it for you ("Your turn!").
- **Nobody loses:** a knocked rival is back at its corner after 3 s at full health; Meeko never bleeds out; you
  are back up at once (the practice rule).

## Checked
`--duo-tutorial-check`: Lace, Kael and Vex each play it through: all 12 beats in order, none by the skip, the rivals
hold fire in beats 1-4, nobody stays outside the ring, the wild Boki is caught; an idle player gets the nag line and
the first beat passes itself. Runs take 55-85 s of match time.

## Open choices (decided for the prototype, alternatives noted)
- **All abilities unlocked from the start.** The current course unlocks one per level; here each beat just uses
  one. Alternative: keep the level-ups (one point per beat) if the run levels should be taught too.
- **You're revived at once** (the practice rule the ring borrows). Better: Meeko runs over and revives you, which
  teaches the wisp from the other side; it needs the match's training revive to step aside for the tutorial.
- **The catch isn't banked** (the ring is a practice match). Shipping it as your first catch needs the match result
  to carry it home.
- **Put back in the ring** is a teleport (rare: a hard knock over the wall). A taller wall collision would hide it.
- **Where it goes:** the prototype is its own launch flag. To ship, it replaces or follows the course in
  `tutorial.gd` (Orri's call); the title's Tutorial entry would point here.

## Film
`docs/shots/tutorial-2v2/duo_run.mp4`: the test driver playing Vex start to end card (68 s, 960x540, the match's
own camera). Made with `--gameplay-media --media-clip=9 --media-secs=150`. The GPU queue was dropping jobs
(rc=125), so this one is a software render on rpc5 (xvfb, opengl3). Things the film shows that still need work:
the run's level-up banners (XP from hitting the rivals) talk over Meeko, and the camera sits off-centre on the
player. A truce offer from the rivals was in the take; it's gone since (sparring rivals don't offer one).
