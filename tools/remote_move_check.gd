extends "res://tools/remote_smooth_check.gd"
## --remote-move-check: how another player's Hunter moves on your screen when it dashes, air-dashes, slides
## along a wall and opens and closes its glider (Vex, Kael, Lace, Cinder), over a bad line. The line, the two
## games and the drawn-against-true comparison are --remote-smooth-check's (this extends it); only the host's
## script and the numbers differ. --remote-move-check is the 80 ms ping (40 ms +-20 each way), --remote-move-slow-check
## the 150 ms ping (75 ms +-20); `--rs-ms=N` sets the one-way time, `--rm-kit=Name` plays one kit, `--rm-reps=N` the
## script N times (a lost snapshot lands at other moments).
## Per kit and move the host's true path is recorded every step and the guest's drawn path every step:
##   host   the true path's biggest step in one frame (cm)
##   drawn  the drawn body's biggest step in one frame (cm)
##   jump   the drawn biggest step over the host's biggest step of that move (cm; 0 if under): a speed the move
##          never reaches. Main's NetSmooth: 17 to 19 cm (Cinder's dash, a lost snapshot); with the flattened curve 4.
## Teleports between moves (the host puts its Hunter back) are left out, 0.35 s each side.
## Lines: RMOVE ok|FAIL <what>, RMOVE <kit> <move> <numbers>.

const SLOW_ONE_WAY_MS := 75   # ms: half the 150 ms ping (--remote-move-slow-check)
const KITS := {"Vex": "gunslinger", "Kael": "juggernaut", "Lace": "archer", "Cinder": "ashwick"}
const MOVES := ["dash", "air", "wall", "glide", "close"]
const FALL_H := 25.0          # m the air dash and the glide start above the strip
const WALL_AT := Vector3(2.0, 0, -4.0)    # m from home: the middle of the rock the wall slide runs along
const WALL_LEN := 18.0        # m of face
const WALL_FROM := Vector3(-5.0, 0, -9.5)  # m from home: where the wall slide starts
const TELE := 3.0             # m in one step on the true path: a teleport
const JUMP_CM := 10.0         # cm: the most the drawn body's biggest step may be over the host's own, per move
const MARGIN_S := 0.35        # s left out each side of a teleport
const STALL_NEAR := [0.3, 0.8]   # s before and after a stalled frame left out (the clocks settle again)
const GAP_S := 1.0            # s the buffer gets to settle after a put-back

var reps := 1                 # --rm-reps=N: the whole script N times (a lost snapshot lands at other moments)
var only := ""                # --rm-kit=Name: just that kit
var rows := {}                # "Kit move" -> {"host": cm, "drawn": cm, "jump": cm, "n": frames}

func _init() -> void:
	tag = "RMOVE"
	flag = "--remote-move-check"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--remote-move-slow-check"):
			flag = "--remote-move-slow-check"      # the 150 ms ping line
			one_way_ms = SLOW_ONE_WAY_MS
		if a.begins_with("--rm-reps="): reps = maxi(1, int(a.substr(10)))
		if a.begins_with("--rm-kit="): only = a.substr(9)       # one kit (a quick look); all four when absent

## The host's Hunter as each kit does each move, recorded as [wall s, x, y, z, "<Kit> <move>" or "gap"].
func _script(truth: Array) -> void:
	var P := m.player
	for rep in reps:
		for kit in KITS:
			if only != "" and kit != only: continue
			var arch: String = KITS[kit]
			P.reclass(Arch.weight(arch), arch, Arch.signature(arch))
			P.unlock_all()
			P.inp["move"] = Vector2.ZERO
			await _put(dn.home + Vector3(-5.0, 0, -5.0), truth)
			await _dash(kit, truth)
			await _air(kit, truth)
			await _wall(kit, truth)
			await _glide(kit, truth)

## Puts the Hunter on `at` and lets it stand GAP_S (a gap: the buffer settles, nothing is measured).
func _put(at: Vector3, truth: Array) -> void:
	m.player.inp["move"] = Vector2.ZERO
	m.player.inp["glide"] = false
	m.player.inp["glide_btn"] = false
	m.player.teleport(at)
	await _host_run(GAP_S, "gap", truth)

func _dash(kit: String, truth: Array) -> void:
	var P := m.player
	P.inp["move"] = Vector2(1, 0)
	P.inp["aim"] = P.pos + Vector3(8, 0.9, 0)
	P.inp["dash"] = true
	await _host_run(DT, kit + " dash", truth)
	P.inp["dash"] = false
	await _host_run(0.9, kit + " dash", truth)
	P.inp["move"] = Vector2.ZERO
	await _host_run(0.6, kit + " dash", truth)

func _air(kit: String, truth: Array) -> void:
	var P := m.player
	await _put(dn.home + Vector3(-5.0, FALL_H, -5.0), truth)
	P.inp["move"] = Vector2(1, 0)
	P.inp["aim"] = P.pos + Vector3(8, 0.9, 0)
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	P.inp["dash"] = true
	await _host_run(DT, kit + " air", truth)
	P.inp["dash"] = false
	await _host_run(0.9, kit + " air", truth)
	P.inp["move"] = Vector2.ZERO
	await _host_run(0.4, kit + " air", truth)
	var t := 0.0
	while not P.grounded and t < 5.0:      # the fall to the strip is not the move
		await _host_run(0.1, "gap", truth)
		t += 0.1

## A dash and a run at a rock's face at 45 degrees: the body slides along it.
func _wall(kit: String, truth: Array) -> void:
	var P := m.player
	var by: Hunter = null
	for h in m.hunters:
		if h.remote: by = h
	var rock := HeroZones.rock(m, by if by else P, dn.home + WALL_AT, Vector2(1, 0), "dwall", WALL_LEN,
		999.0, 999.0, false)
	await _put(dn.home + WALL_FROM, truth)
	var d := Vector2(1, 1).normalized()
	P.inp["move"] = d
	P.inp["aim"] = P.pos + Vector3(d.x * 8.0, 0.9, d.y * 8.0)
	P.inp["dash"] = true
	await _host_run(DT, kit + " wall", truth)
	P.inp["dash"] = false
	await _host_run(1.8, kit + " wall", truth)
	P.inp["move"] = Vector2.ZERO
	await _host_run(0.5, kit + " wall", truth)
	HeroZones.remove_rock(m, rock, false)

## Falls, opens the glider with its button, holds it, lets go and falls on.
func _glide(kit: String, truth: Array) -> void:
	var P := m.player
	await _put(dn.home + Vector3(-5.0, FALL_H, -5.0), truth)
	await _host_run(0.4, "gap", truth)
	P.inp["move"] = Vector2(1, 0)
	P.inp["glide_press_only"] = true
	P.inp["glide"] = true
	P.inp["glide_btn"] = true
	await _host_run(2.0, kit + " glide", truth)
	P.inp["glide"] = false
	P.inp["glide_btn"] = false
	await _host_run(1.0, kit + " close", truth)
	P.inp["move"] = Vector2.ZERO
	var t := 0.0
	while not P.grounded and t < 5.0:
		await _host_run(0.1, "gap", truth)
		t += 0.1

# ------------------------------------------------------------------ the numbers
func _report(truth: Array, drawn, lost: int) -> void:
	if typeof(drawn) != TYPE_ARRAY or truth.size() < 60:
		ok(false, "records to compare")
		return
	var w0: float = truth[0][0]
	var w1: float = truth[-1][0]
	var lag := _best_lag(truth, drawn, w0, w1)
	var teles: Array = []                 # wall times of the put-backs on the true path
	for i in range(1, truth.size()):
		if _p(truth[i]).distance_to(_p(truth[i - 1])) > TELE: teles.append(float(truth[i][0]))
	var steps := PackedFloat64Array()     # the true step at each truth sample, m
	steps.resize(truth.size())
	for i in range(1, truth.size()):
		steps[i] = _p(truth[i]).distance_to(_p(truth[i - 1]))
		if truth[i][4] != "gap" and truth[i - 1][4] == truth[i][4]:
			var r: Dictionary = rows.get(truth[i][4], {"host": 0.0, "drawn": 0.0, "jump": 0.0, "n": 0})
			r["host"] = maxf(r["host"], steps[i] * 100.0)
			rows[truth[i][4]] = r
	var j := 0
	var held := 0
	for i in range(1, drawn.size()):
		var w: float = float(drawn[i][0]) - lag
		if w < w0 + 0.2 or w > w1: continue
		while j < truth.size() - 2 and truth[j + 1][0] < w: j += 1
		var ph: String = truth[j][4]
		if ph == "gap" or _near(teles, w):
			continue
		if _stalled_near(stalls, w) or _stalled_near(guest_stalls, float(drawn[i][0])):
			held += 1             # a frame this box was too slow for is the box's, not the line's
			continue
		var step := _p(drawn[i]).distance_to(_p(drawn[i - 1]))
		var r: Dictionary = rows.get(ph, {"host": 0.0, "drawn": 0.0, "jump": 0.0, "n": 0})
		r["n"] += 1
		r["drawn"] = maxf(r["drawn"], step * 100.0)
		rows[ph] = r
	print("%s line: %d ms ping (%d +-%d ms one way), %.0f%% loss (%d snapshots lost); drawn %.0f ms behind" % [
		tag, one_way_ms * 2, one_way_ms, JITTER_MS, LOSS * 100.0, lost, lag * 1000.0])
	for key in rows:
		rows[key]["jump"] = maxf(0.0, rows[key]["drawn"] - rows[key]["host"])
	print("%s load: %d drawn frames left out near a frame over 0.1 s (host stalls %d, guest %d)" % [
		tag, held, stalls.size(), guest_stalls.size()])
	var worst := 0.0
	var worst_at := ""
	for kit in KITS:
		if only != "" and kit != only: continue
		for mv in MOVES:
			var key := "%s %s" % [kit, mv]
			var r: Dictionary = rows.get(key, {"host": 0.0, "drawn": 0.0, "jump": 0.0, "n": 0})
			print("%s %-6s %-5s frames %3d  host max step %5.1f cm  drawn max step %5.1f cm  jump %5.1f cm" % [
				tag, kit, mv, r["n"], r["host"], r["drawn"], r["jump"]])
			ok(r["n"] > 30, "%s: the guest drew it" % key, "%d frames" % r["n"])
			if r["jump"] > worst:
				worst = r["jump"]
				worst_at = key
	print("%s worst jump: %.1f cm (%s)" % [tag, worst, worst_at])
	ok(worst <= JUMP_CM, "no drawn step is more than %.0f cm over the host's own steps" % JUMP_CM,
		"%.1f cm, %s" % [worst, worst_at])

## A stall [wall s, s lost] within STALL_NEAR of wall time w (before or after).
static func _stalled_near(list: Array, w: float) -> bool:
	for x in list:
		if w >= float(x[0]) - STALL_NEAR[0] and w <= float(x[0]) + STALL_NEAR[1]: return true
	return false

static func _near(list: Array, w: float) -> bool:
	for t in list:
		if absf(w - float(t)) < MARGIN_S: return true
	return false
