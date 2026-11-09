class_name BotRamp
extends RefCounted
## Gentler backfill bots for a new player (DECISIONS 11-08: an Extraction is always 10 trios, bots
## fill the empty slots). Over the first RAMP_MATCHES finished matches the bots' knobs (aim, reaction,
## damage, trigger time, abilities, chase) climb from the Easy profile to the tier's normal one:
## match 1 is pure Easy, the 4th is normal. For the first RAMP_MATCHES matches the bots also hold
## their ultimates for the first NO_ULT_S seconds. Bots only: humans are never touched.

const RAMP_MATCHES := 3       # finished matches that still get the gentle profile
const NO_ULT_S := 120.0       # seconds into the match before a gentle bot may use its ultimate
const KNOBS := ["skill", "react", "dmg", "fire", "abil", "aggro"]      # the BOT_DIFF numbers that ramp

## `base` (the run's normal profile) eased toward Easy for a player with `matches` finished matches.
static func cfg(base: Dictionary, matches: int) -> Dictionary:
	if matches >= RAMP_MATCHES:
		return base
	var easy: Dictionary = Data.BOT_DIFF["easy"]
	var t := float(maxi(matches, 0)) / RAMP_MATCHES
	var out := base.duplicate()
	for k in KNOBS:
		out[k] = lerpf(float(easy[k]), float(base[k]), t)
	out["no_ult_s"] = NO_ULT_S
	return out

## The match count the ramp follows: your own offline; online the host's view of the least
## experienced human in the match (a roster entry with no count counts as a veteran).
static func matches_for(opts: Dictionary) -> int:
	var roster: Array = (opts.get("net", {}) as Dictionary).get("roster", [])
	if roster.is_empty():
		return int(Save.d.get("matches", 0))
	var n := RAMP_MATCHES
	for r in roster:
		n = mini(n, int((r as Dictionary).get("matches", RAMP_MATCHES)))
	return n
