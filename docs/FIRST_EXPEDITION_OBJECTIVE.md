# First expedition: the next step is always on screen

Owner ask (11-19): a brand-new player on their first expedition must always know what to do next, without a wall of text.

## Where the next step was unclear (fresh save, 1080p, the real match flow)
1. **Landing.** Nothing said what the expedition is for. The screen had a Boki-behaviour hint and the island blurb, no goal.
2. **Finding a Boki.** Wild Boki showed only as small minimap dots. The first-capture hint only fires once you are already next to one.
3. **Capture is two steps.** "Knock it out, then scan it" was only taught by a one-time hint at the Boki itself.
4. **After the scan.** Nothing said "now leave". The way-out line only comes when the Blight closes in.
5. **Leaving.** Start the uplink, hold the yard, take the lift: three steps, each told only when you were already standing at it.

## What it does now
One line under the minimap clock (`ObjectiveTracker`), verb-first, plus a pin over the thing it names, an arrow on the screen
edge when it is off screen, and a ring on the minimap. State lives in `FirstObjective` and is read from the world every half second:

| Step | Line | Marker |
|---|---|---|
| find | Find a wild Boki | nearest wild Boki (a knocked-out one first) |
| knock | Knock it out | the same Boki, once you are within 18 m |
| scan | Scan it: hold F beside it | the knocked-out Boki |
| leave | Go to the outpost, then Start the uplink: hold F, Hold the yard: uplink 42%, Step into the lift | the Uplink outpost (the running uplink keeps its own pin) |

A finished step ticks green in the card's top row with a chime. A step that goes back (the Boki woke and ran) simply shows the earlier line.
It never pauses or blocks anything, hides while you ride or drop, and the world arrow keeps clear of the left HUD column. Your Boki's own
"Wild Boki" callout, when it is on the same spot, stands in for the pin (the same look, so one is enough).

It runs until the save has got out of one expedition (`Save.d.tutorial.first_objective`, set on extracting; a save with `extracts > 0` is
migrated as done, one that has caught a Boki before starts at "leave"). The tutorial match, duel, arena, training and autoplay never have it.
No new save field: it lives in the existing `tutorial` dictionary, like `first_capture`.

Words and numbers: `content/rules/first_objective.json`. Check: `--first-objective-check`. Shots: `--first-objective-shots --shots-dir=<dir> --size=1920x1080`
(software renderer is fine). Pictures: `docs/first_objective/` (1600x900 copies of the 1080p shots).

Also fixed on the way: the screen-edge marker's label sat under the arrow on the left and right edges and hid its first letters (`EdgeMarker._label_at`).
