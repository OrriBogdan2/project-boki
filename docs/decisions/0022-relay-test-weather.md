# 0022: Relay test weather for online cast latency

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** networking

## Problem
Source parity says your own ability starts the frame you press it, even online. To prove it we need two
games talking at a bad but realistic line (100 ms round trip, 2% loss), and nothing in the game could add
lag or loss to the desktop relay.

## Options
1. A lag/loss layer in `Net` on every game. Touches the live send path of every player.
2. Opt-in `--lag-ms` / `--loss` on `RelayServer`: the relay holds each packet it sends, drops a lost
   snapshot and delays a lost reliable message by one round trip (in order, as ENet's resend would).
   Off by default, so live servers send exactly as before.
3. OS-level netem. Needs root and doesn't run on every check box.

## Decision
Option 2: it lives in one file, only checks pass the flags, and all traffic between two games goes
through the relay anyway. The measurement then showed no cosmetic prediction is needed (each game owns its
own Hunter and casts it locally), so nothing in the cast path changed.

## Consequences
- `scripts/server/relay.gd` (held queue, its own dice), `tools/cast_predict_check.gd` (`--cast-predict-check`).
- Net.VERSION bump: no (no message or snapshot changed; the defaults are a pass-through).
- If a later change makes a cast wait for the host, `--cast-predict-check` fails and prediction is due then.
