extends "res://tools/displace_net_check.gd"
## --glide-net-check: the glide button's instant open (inp.glide_btn, local input only) reaches the other game.
## Two real games over the desktop relay (the --displace-net-check harness): the guest's hunter falls from HIGH
## and, FALL_S into the fall, presses the glide button (or, for comparison, a second Space press) and holds it.
## The guest owns its hunter, so the open is decided on its own game; the host's copy only mirrors the
## snapshot's gliding bit (Match._net_apply). Both games log when the glider opens; the copy must open on
## every drop, within one snapshot (Net.tick's 0.1 s) plus a frame of the guest's open, the button no later
## than Space, over an 80 ms ping with 20 ms jitter and 2% lost snapshots (remote_smooth_check's LagRelay).
## The host's copy is drawn smoothly through the open, the hold and the close: its biggest step in one frame
## stays within JUMP_CM of the guest's own biggest step (NetSmooth keeps the curve off a speed the snapshots
## don't show). Lines: GNET ok|FAIL <what>, GNET <mode> rows.

const HIGH := 14.0           # m above the strip: a fall long enough to press mid-fall and glide a while
const FALL_S := 0.5          # s of falling before the press
const HOLD_S := 0.8          # s the press is held
const CLOSE_S := 0.5         # s the guest falls on after letting go (the glider closes on the first of them)
const TAIL_S := 0.45         # s the host watches its copy on after the guest's reply (the copy runs ~0.25 s behind)
const DROPS := 6             # drops per mode: the press lands at a different phase of the snapshot clock
const NET_TICK_S := 0.1          # s between snapshots (Net.tick's send_t)
const LINE_MS := 40          # ms one way on the line (an 80 ms ping); each packet +-20 ms, 2% of snapshots lost
const LAG_TOL := NET_TICK_S + DT + 0.02 + (LINE_MS + 20) / 1000.0   # s: a snapshot, a frame, the line and its jitter
# s: the loosest any single drop may lag (a loaded box can hitch one snapshot; a lost fallback is seconds)
const WORST_S := 0.6
const MODES := ["btn", "space"]
const RS := preload("res://tools/remote_smooth_check.gd")
const JUMP_CM := 6.0         # cm: the host's copy may step this much more in one frame than the guest's own body
const COPY_FROM := 6.0       # m below the drop height: the copy is on its way down (the put-back is not the move)

var host_open_ms := 0        # the host's copy opened (unix ms), 0 until then
var driving := false         # the guest is stepping a drop itself
var copy_rec: Array = []     # host: the copy's position each match step of the drop, once it is up there
var own_rec: Array = []      # guest: its own body each step of the drop
var recording := false       # host: a drop is running

func _relay() -> RelayServer:
	var relay := RS.LagRelay.new()
	relay.one_way = LINE_MS
	relay.rng.seed = 80
	return relay

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
	var med := {}
	var jumps := {"btn": [], "space": []}      # cm each drop's copy steps over the guest's own steps
	await _drop_once(G, "btn", 0)  # unmeasured: the host's first glider copy loads its canopy and trail
	for mode in MODES:
		var lags: Array = []
		var frames: Array = []
		for i in DROPS:
			var got := await _drop_once(G, mode, i)
			lags.append(got[0])
			frames.append(got[1])
			jumps[mode].append(got[2])
		var sorted := lags.duplicate()
		sorted.sort()
		# median: one loaded-box hitch does not decide it
		med[mode] = (sorted[DROPS / 2 - 1] + sorted[DROPS / 2]) / 2.0
		print("%s %s: guest open frames after the press %s; host copy lag (s) %s" % [tag, mode, frames, lags])
		ok(frames.max() <= (1 if mode == "btn" else 99) and frames.min() >= 1,
			"%s: the guest's own glider opens mid-fall (button: on the press step)" % mode, str(frames))
		ok(lags.max() < 9.0, "%s: the host's copy opens on every drop" % mode, str(lags))
		ok(med[mode] <= LAG_TOL and lags.max() <= WORST_S,
			"%s: the host's copy opens within %.3f s (%.1f frames) of the guest's own (median; every drop < %.1f s)"
			% [mode, LAG_TOL, LAG_TOL / DT, WORST_S], "median %.3f s = %.1f frames, worst %.3f s"
			% [med[mode], med[mode] / DT, lags.max()])
	for mode in MODES:
		var worst: float = jumps[mode].max()
		print("%s %s: the copy's biggest step over the guest's own (cm) %s" % [tag, mode, jumps[mode]])
		ok(worst <= JUMP_CM, "%s: the host's copy never steps more than %.0f cm over the guest's own body in a frame"
			% [mode, JUMP_CM], "worst %.1f cm" % worst)
	# the drops land at random phases of the 0.1 s snapshot clock, so two medians differ by up to a tick of noise
	ok(med["btn"] <= med["space"] + NET_TICK_S, "the button's remote open is no later than Space's (no fallback)",
		"median btn %.3f s, space %.3f s" % [med["btn"], med["space"]])
	_finish()

## One drop on the guest, then the hunter back at the park: [the host copy's lag (s), the guest's open frames,
## the copy's biggest step over the guest's own (cm)].
func _drop_once(G: Node, mode: String, i: int) -> Array:
	host_open_ms = 0
	replies.clear()
	copy_rec.clear()
	recording = true
	Net.lobby_emit("gn", {"c": "drop", "mode": mode, "at": [home.x, home.y + HIGH, home.z], "wait": i * DT})
	await _reply()
	await _run(TAIL_S)
	recording = false
	var jump := (_max_step(copy_rec) - _got("step_cm") / 100.0) * 100.0
	var g_ms := int(_got("open_ms"))
	var lag := (host_open_ms - g_ms) / 1000.0 if host_open_ms > 0 and g_ms > 0 else 9.0
	var frames := int(_got("frames"))
	await _place(G, home + PARK)
	return [snappedf(lag, 0.001), frames, snappedf(jump, 0.1)]

## The biggest distance between two neighbouring positions of `rec`, m.
static func _max_step(rec: Array) -> float:
	var top := 0.0
	for k in range(1, rec.size()):
		top = maxf(top, (rec[k] as Vector3).distance_to(rec[k - 1]))
	return top


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
	own_rec.clear()
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
	await super._run(CLOSE_S)
	driving = false
	Net.lobby_emit("dn_r", {"pos": [P.pos.x, P.pos.y, P.pos.z], "open_ms": open_ms, "frames": frames,
		"step_cm": _max_step(own_rec) * 100.0})

## The guest's main loop waits out a frame while a drop steps the match itself.
func _run(secs: float) -> void:
	if driving and not Net.is_host():
		await main.get_tree().process_frame
		return
	await super._run(secs)

## After each match step: the guest's body of a drop, the host's copy of it once it is up there.
func _stepped() -> void:
	super._stepped()
	if driving and not Net.is_host():
		own_rec.append(m.player.pos)
	elif recording and Net.is_host():
		for h in m.hunters:
			if h.remote and h.pos.y > home.y + HIGH - COPY_FROM: copy_rec.append(h.pos)

# ------------------------------------------------------------------ the host's view
## Every frame on the host: the first open of the guest's copy.
func _sample() -> void:
	if m == null or not Net.is_host() or host_open_ms > 0:
		return
	for h in m.hunters:
		if h.remote and h.gliding: host_open_ms = int(Time.get_unix_time_from_system() * 1000.0)
