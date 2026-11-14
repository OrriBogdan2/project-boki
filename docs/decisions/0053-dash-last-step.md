# 0053: The step a dash ends in

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement

## Problem
A dash's time is rarely a whole number of 60 Hz steps, so it ends partway through a step. On the ground,
`Hunter._physics` ran that whole step at the run speed `HunterMove.dash_exit` hands over, and the time the
dash still had was lost. Sparkle's tap Wirerun came up 5.5% short of its 5.6 m lane. In the air, the step runs at
the dash's speed, because an air dash keeps that speed after it ends (owner 11-08, air drag bleeds it). The
felt-dash measure counted that whole step as dash, so Grimble's air dash read 3.99 m against 3.67 m.

## Options
1. Run the air step at the dash's remainder (the release note's suggestion). The dash then measures
   3.67 m. But the speed it hands over either drops to that remainder, which undoes owner 11-08's carry and
   the dash-into-glide hand-off, or it stalls one frame and then flies on at the full speed.
2. Run the step the dash ends in as the dash for the time it had left, then the hand-over for the rest. On
   the ground, that is the run. In the air, it is the carried speed, so nothing changes there. The measure
   reads the travel at the moment the dash ends.

## Decision
Option 2. `HunterMove.dash_rest` gives the metres the dash still owed. `Hunter` adds them to that step's travel
(through the usual block push-out), and the hunter carries on at run speed. `--move-feel-check _felt_dash`
takes off the hand-over tail and reports the dash's own time.

## Consequences
hunter.gd +3 lines of wiring. Ground dashes now cover their whole distance at any tick rate. Air movement is
unchanged. No Net or save change.
