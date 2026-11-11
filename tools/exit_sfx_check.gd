class_name ExitSfxCheck
extends RefCounted
## The exit cue part of --extract-check: ExitSfx.heard holds what a skiff boarding played (the call's and the
## boarding's last COUNT_S s of ticks at UI level, then the deck hum, a cancel when the player stepped off, the
## hum again and the casting-off sting) and a rival's lone skiff stings from the berth, not in your ears.

static func verify(m: Match, berth: Vector3, rival: Hunter) -> bool:
	ExitSfx.depart(m, {"i": 99, "aboard": [rival], "berth": berth})
	var heard: Array = ExitSfx.heard.duplicate()
	ExitSfx.record = false
	var rival_sting: Array = heard.pop_back()
	var ticks := heard.filter(func(c): return c[0] == "warn_tick")
	var cues := heard.filter(func(c): return c[0] != "warn_tick").map(func(c): return c[0])
	var near := ticks.filter(func(c): return c[1]).size()
	print("EXCHECK skiff cues: %d ticks (%d positional), then %s" % [ticks.size(), near, cues])
	print("EXCHECK skiff cues: rival sting %s" % [rival_sting])
	var good: bool = ticks.size() == 2 * ExitSfx.COUNT_S and not ticks.any(func(c): return c[1]) \
		and cues == ["board_hum", "board_cancel", "board_hum", "depart_sting"] \
		and heard.back() == ["depart_sting", false] and rival_sting == ["depart_sting", true]
	if not good:
		print("EXCHECK FAIL skiff cues")
	return good
