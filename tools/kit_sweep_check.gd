extends "res://tools/archetype_check.gd"
## --kit-sweep-check: the error sweep for merged kit branches. Each Hunter at max ranks presses every slot
## (LMB, RMB, E, dash, R, X) as a tap, a hold and a short release, plus every recast, on the ground, in the air
## and from the glider, beside a dummy and at a ledge (~20 s of play per run). The check fails on any push_error,
## script error or "Invalid" warning in the engine log. --ks-only=<archetype> runs one Hunter.

const ENVS := ["dummy", "ledge"]
const STATES := ["ground", "air", "glider"]
const SLOTS := ["lmb", "rmb", "e", "dash", "r", "x"]
const RECASTS := ["rmb", "e", "dash", "r", "x"]
const AIR_H := 9.0          # m above the strip for the air and glider runs
const HOLD_T := 1.2         # s a hold is kept down
const RELEASE_T := 0.2      # s before a release lets go
const SETTLE_T := 0.45      # s of play after the last input of an action

## Collects what the engine logs as an error; Godot may call it from any thread.
class ErrLog extends Logger:
	var found: Array = []
	var doing := ""      # the key press in progress
	func _log_error(
			fn: String, file: String, line: int, code: String, rationale: String, _ed: bool, kind: int, trace: Array
	) -> void:
		if file.begins_with("servers/rendering/dummy/"):
			return      # the headless renderer's own noise (no script frame), not a push_error or script error
		var text := "%s %s" % [code, rationale]
		if kind != Logger.ERROR_TYPE_WARNING or text.contains("Invalid"):
			var where := ""
			if trace.size() > 0:
				where = (trace[0] as ScriptBacktrace).format(0, 1).replace("\n", " < ")
			found.append("%s:%d %s [%s] during %s %s" % [file, line, text.strip_edges(), fn, doing, where])

var errlog := ErrLog.new()
var seen := {}
var runs := 0

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("kit_sweep_check", self)
	Save.no_write = true
	OS.add_logger(errlog)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--ks-only="): only = String(a).substr(10)
	for arch in Arch.ids():
		if only != "" and arch != only: continue
		for env in ENVS:
			for st in STATES:
				await _sweep(arch, env, st)
	OS.remove_logger(errlog)
	print("KSWEEP DONE, %d runs, %d distinct errors" % [runs, seen.size()])
	main.get_tree().quit(1 if fails > 0 else 0)

## One hero in one place and state: every slot and recast in turn, then the log is read.
func _sweep(arch: String, env: String, st: String) -> void:
	var r := setup(arch, 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	if env == "ledge":
		var W: World = m.world
		var hx := int(floor(home.x))
		var hz := int(floor(home.z))
		for dz in range(-10, 11):
			for dx in range(2, 20):
				W.kind[W.idx(hx + dx, hz + dz)] = World.T_VOID
		T.teleport(home + Vector3(0, 0, 4))
	P.slot_lv = {"sec": 3, "dash": 3, "kin": 3, "ult": 2}
	P.lvl = 9
	for slot in SLOTS:
		for mode in ["tap", "hold", "release"]:
			errlog.doing = "staging"
			_stage(m, P, home, st, env)
			await _press(m, P, slot, mode, st)
	for slot in RECASTS:
		errlog.doing = "staging"
		_stage(m, P, home, st, env)
		await _recast(m, P, slot, st)
	errlog.doing = "teardown"
	await done(m)
	var errs := errlog.found.duplicate()
	errlog.found.clear()
	for e in errs:
		if not seen.has(e):
			seen[e] = true
			ok("%s %s %s: %s" % [arch, env, st, e], false)
	runs += 1
	print("KSWEEP %-11s %-6s %-6s %s" % [arch, env, st, "ok" if errs.is_empty() else "%d errors" % errs.size()])

## Back on the spot with every cooldown, charge and the ultimate ready (and alive).
func _stage(m: Match, P: Hunter, home: Vector3, st: String, env: String) -> void:
	if P.downed:
		m.revive_hunter(P, null)
	P.out = false
	P.hp = P.max_hp
	P.teleport(home + Vector3(0, 0 if st == "ground" else AIR_H, 0))
	P.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	P.ult = 1.0
	P.fire_cd = 0.0
	P.ammo = maxi(P.ammo, 12)
	P.reload_t = 0.0
	P.glide_cd = 0.0
	for k in P.ak.cd:      # (a kit may hold more slots than the four)
		P.ak.cd[k] = 0.0
	P.ak.ch_rmb = float(P.ak.rmb_charges())
	P.inp["move"] = Vector2(1, 0) if env == "ledge" else Vector2.ZERO
	P.inp["aim"] = home + Vector3(8, 0.9, 0)
	P.inp["aim_y"] = home.y
	P.inp["glide"] = false
	if st == "glider":
		for i in 30:
			P.inp["glide"] = true
			m.step(DT)

## The slot's key goes down for one frame; `held` keys stay down (and the glide key with them).
func _frame(m: Match, P: Hunter, slot: String, down: bool, held: bool, st: String) -> void:
	P.inp["glide"] = st == "glider"
	match slot:
		"lmb": P.inp["fire"] = held
		"rmb":
			P.inp["sec"] = down
			P.inp["sec_hold"] = held
		"e": P.inp["sig"] = down
		"dash":
			P.inp["dash"] = down
			P.inp["dash_down"] = held
			if down: P.inp["move"] = Vector2(1, 0)
		"r": P.inp["ult"] = down
		"x":
			if down: HunterKeys.ult_pressed(P)
	m.step(DT)

func _play(m: Match, P: Hunter, slot: String, secs: float, held: bool, st: String) -> void:
	for i in int(secs / DT):
		_frame(m, P, slot, false, held, st)

func _press(m: Match, P: Hunter, slot: String, mode: String, st: String) -> void:
	errlog.doing = "%s %s" % [slot, mode]
	_frame(m, P, slot, true, mode != "tap", st)
	if mode == "hold":
		_play(m, P, slot, HOLD_T, true, st)
	elif mode == "release":
		_play(m, P, slot, RELEASE_T, true, st)
	_play(m, P, slot, SETTLE_T, false, st)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	await main.get_tree().process_frame

## The slot pressed again while it is still up: soon after, then once more later.
func _recast(m: Match, P: Hunter, slot: String, st: String) -> void:
	errlog.doing = "%s recast" % slot
	_frame(m, P, slot, true, false, st)
	_play(m, P, slot, 0.35, false, st)
	_frame(m, P, slot, true, false, st)
	_play(m, P, slot, 0.8, false, st)
	_frame(m, P, slot, true, false, st)
	_play(m, P, slot, SETTLE_T, false, st)
	await main.get_tree().process_frame
