extends "res://tools/displace_net_check.gd"
## --glide-net-check: the glide button's instant open (inp.glide_btn, local input only) reaches the other game.
## Two real games over the desktop relay (the --displace-net-check harness): the guest's hunter falls from HIGH
## and, FALL_S into the fall, presses the glide button (or, for comparison, a second Space press) and holds it.
## The guest owns its hunter, so the open is decided on its own game; the host's copy only mirrors the
## snapshot's gliding bit (Match._net_apply). Both games log when the glider opens; the copy must open on
## every drop, within one snapshot (Net.tick's 0.1 s) plus a frame of the guest's open, the button no later
## than Space. Lines: GNET ok|FAIL <what>, GNET <mode> rows.

const HIGH := 14.0           # m above the strip: a fall long enough to press mid-fall and glide a while
const FALL_S := 0.5          # s of falling before the press
const HOLD_S := 0.8          # s the press is held
const DROPS := 6             # drops per mode: the press lands at a different phase of the snapshot clock
const SNAP_S := 0.1          # s between snapshots (Net.tick's send_t)
const LAG_TOL := SNAP_S + DT + 0.02   # s: one snapshot, one frame, and the relay hop on one machine
const MODES := ["btn", "space"]

var host_open_ms := 0        # the host's copy opened (unix ms), 0 until then
var driving := false         # the guest is stepping a drop itself

func _init() -> void:
	tag = "GNET"
	guest_flag = "--glide-net-check=guest"

func run(main_node: Node) -> void:
	main_node.get_tree().process_frame.connect(_sample)
	await super.run(main_node)

# ------------------------------------------------------------------ the host
func _host() -> void:
	var G := await _host_up()
	if G == null:
		return _finish()
	await _place(G, home + PARK)
	var worst := {}
	for mode in MODES:
		var lags: Array = []
		var frames: Array = []
		for i in DROPS:
			host_open_ms = 0
			replies.clear()
			Net.lobby_emit("gn", {"c": "drop", "mode": mode, "at": [home.x, home.y + HIGH, home.z], "wait": i * DT})
			await _reply()
			var g_ms := int(_got("open_ms"))
			var lag := (host_open_ms - g_ms) / 1000.0 if host_open_ms > 0 and g_ms > 0 else 9.0
			lags.append(snappedf(lag, 0.001))
			frames.append(int(_got("frames")))
			await _place(G, home + PARK)
		worst[mode] = lags.max()
		print("%s %s: guest open frames after the press %s; host copy lag (s) %s" % [tag, mode, frames, lags])
		ok(frames.max() <= (1 if mode == "btn" else 99) and frames.min() >= 1,
			"%s: the guest's own glider opens mid-fall (button: on the press step)" % mode, str(frames))
		ok(lags.max() < 9.0, "%s: the host's copy opens on every drop" % mode, str(lags))
		ok(lags.max() <= LAG_TOL, "%s: the host's copy opens within %.3f s (%.1f frames) of the guest's own"
			% [mode, LAG_TOL, LAG_TOL / DT], "worst %.3f s = %.1f frames" % [lags.max(), lags.max() / DT])
	ok(worst["btn"] <= worst["space"] + DT, "the button's remote open is no later than Space's (no fallback)",
		"worst btn %.3f s, space %.3f s" % [worst["btn"], worst["space"]])
	_finish()

# ------------------------------------------------------------------ the guest
func _on_msg(topic: String, data, from: String) -> void:
	if topic == "gn" and typeof(data) == TYPE_DICTIONARY and m and m.player:
		_drop(String(data["mode"]), _v(data["at"]), float(data["wait"]))
		return
	super._on_msg(topic, data, from)

## The guest's hunter drops from `at`, presses mid-fall (the mode's key), holds, lets go; then says when it opened.
## The guest steps the drop itself (one step a frame, its main loop idle meanwhile), so the open's frame is exact.
func _drop(mode: String, at: Vector3, wait: float) -> void:
	var P := m.player
	driving = true
	_fresh(P)
	for k in ["glide", "glide_btn", "jump"]: P.inp[k] = false
	P.inp["glide_press_only"] = true       # a player's keys, as Match sets them
	P.teleport(at)
	P.grounded = false
	P.coyote = 0.0
	P.glide_fuel = 1.0
	P.glide_cd = 0.0
	await super._run(FALL_S + wait)
	var open_ms := 0
	var frames := -1
	for i in roundi(HOLD_S / DT):
		P.inp["glide"] = true
		P.inp["glide_btn"] = mode == "btn"
		P.inp["jump"] = mode == "space" and i == 0     # Match's do_jump route: a second Space press in the air
		await super._run(DT)
		if P.gliding and frames < 0:
			frames = i + 1
			open_ms = int(Time.get_unix_time_from_system() * 1000.0)
	P.inp["glide"] = false
	P.inp["glide_btn"] = false
	driving = false
	Net.lobby_emit("dn_r", {"pos": [P.pos.x, P.pos.y, P.pos.z], "open_ms": open_ms, "frames": frames})

## The guest's main loop waits out a frame while a drop steps the match itself.
func _run(secs: float) -> void:
	if driving and not Net.is_host():
		await main.get_tree().process_frame
		return
	await super._run(secs)

# ------------------------------------------------------------------ the host's view
## Every frame on the host: the first open of the guest's copy.
func _sample() -> void:
	if m == null or not Net.is_host() or host_open_ms > 0:
		return
	for h in m.hunters:
		if h.remote and h.gliding: host_open_ms = int(Time.get_unix_time_from_system() * 1000.0)
