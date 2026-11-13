extends RefCounted
## --snag-check: every Hunter runs, dashes and glides along seeded paths on The Hollow Crown and the
## check counts stalls: horizontal speed under STALL_FRAC of the wanted speed for over STALL_S while the
## keys are held and nothing blocks by design (a wall or prop whose top is above mantle reach straight
## ahead). Prints the worst spots (1 m cells) with the cause. "SNAG DONE, stalls: N" ends the run; it
## fails when N is over MAX_STALLS. Counts fixed simulation steps; never touches the save.
## Options: --snag-paths=N (default 50), --snag-arch=id (one Hunter).

const DT := Match.DT
const MAP := "hollowcrown"
const PATHS := 50
const STALL_FRAC := 0.5        # of the wanted speed
const STALL_S := 0.15          # s under it before it counts
const SETTLE_S := 0.3          # s after a segment starts or turns (the acceleration ramp) not counted
const RUN_S := 1.6
const DASH_HOLD_S := 0.5       # s the keys stay held after a dash starts
const GLIDE_S := 1.4
## zeroed between paths
const TIMERS := [
	"grap_cd", "roll_t", "knock_t", "fly_t", "glide_cd", "stun_t", "root_t",
	"mantle_cd", "air_t", "coyote", "jump_buf", "ex_cd", "dash_buf",
]
const SEG_S := {"run": RUN_S, "dash": DASH_HOLD_S + 0.5, "glide": GLIDE_S}     # s per segment kind
const GLIDE_WANT := 4.5        # m/s: the glide's cruise (MaxGlide), the wanted speed while gliding
const MAX_STALLS := 2          # over this fails (2 are left: a dolm and a tender glide, see docs/MOVEMENT_FEEL.md)
const WORST := 12

var bad := 0
var m: Match
var w: World
var P: Hunter
var spots := {}                # "x,z" cell -> {n, causes, archs, kinds, at}
var stalls := 0
var stall_s := 0.0
var path_s := 0.0

func run(main: Node) -> void:
	Save.no_write = true
	var n_paths := PATHS
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--snag-paths="): n_paths = int(String(a).get_slice("=", 1))
		if String(a).begins_with("--snag-arch="): only = String(a).get_slice("=", 1)
	for arch in Arch.ORDER:
		if only != "" and arch != only:
			continue
		_boot(main, arch)     # a fresh match per Hunter: the world's clock never carries one run into the next
		var before := stalls
		for i in n_paths:
			_path(arch, i)
		print("SNAG %-11s stalls %3d" % [arch, stalls - before])
		m.queue_free()
		await main.get_tree().process_frame
	_report(n_paths)
	bad = 1 if stalls > MAX_STALLS else 0
	print("SNAG DONE, stalls: %d (%.1f s stalled of %.0f s walked), failures: %d" % [stalls, stall_s, path_s, bad])
	main.get_tree().quit()

## A match on the map with only the player in it, as `arch`.
func _boot(main: Node, arch: String) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"map": MAP, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true})
	m.set_process(false)
	w = m.world
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		if h != P:
			h.ctrl = "idle"
			h.out = true
			h.teleport(Vector3(-500, 50, -500))
	if P.kin:
		(P.kin as Kin).stow()
	P.ctrl = "local"
	P.unlock_all()
	P.set_arch(arch)

## Standing, clean, at p (the same reset the move-feel check uses).
func _reset(p: Vector3) -> void:
	P.out = false
	P.gone = false
	P.downed = false
	P.teleport(p)
	P.vel = Vector3.ZERO
	P.grounded = true
	P.pad = {}
	P.grap = {}
	P.gliding = false
	P.dropping = false
	P.diving = false
	P.glide_fuel = 1.0
	P.dashes = P.max_dashes()
	for f in TIMERS:
		P.set(f, 0.0)
	P.kb_t = -9.0
	P.hp = P.max_hp
	P.set("lfloat", {})
	for k in ["jump", "dash", "glide", "glide_btn", "crouch", "fire", "skill", "sec", "sig", "ult"]:
		P.inp[k] = false
	P.inp["move"] = Vector2.ZERO

## One seeded path for the current Hunter: a start on any ground tile (props and terraces included),
## then run, dash, glide, each toward a heading that turns up to 70 degrees.
func _path(arch: String, i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210 + i * 7919
	var g := Vector3.ZERO
	for _t in 500:
		var tx := rng.randi_range(0, w.w - 1)
		var tz := rng.randi_range(0, w.h - 1)
		if w.kind[w.idx(tx, tz)] == World.T_GROUND:
			g = Vector3(tx + 0.5, w.level[w.idx(tx, tz)] * World.LEVEL, tz + 0.5)
			break
	_reset(g)
	var ang := rng.randf() * TAU
	for seg in ["run", "dash", "glide", "run", "glide", "dash"]:
		ang = _no_void(ang + deg_to_rad(rng.randf_range(-70.0, 70.0)), 7.0 if seg == "glide" else 4.5)
		if _segment(arch, seg, Vector2(cos(ang), sin(ang))) < 0 or P.pos.y < w.lowest_top() - 2.0:
			break

## The heading nearest `ang` (turning in 25 degree steps) with no void within `clear_m` m of the body:
## a path walks along the island and never off it.
func _no_void(ang: float, clear_m: float) -> float:
	for k in 15:
		for sign in [1.0, -1.0]:
			var a: float = ang + sign * deg_to_rad(25.0) * k
			var clear := true
			for j in range(1, int(clear_m / 0.5) + 1):
				if w.is_void(P.pos.x + cos(a) * j * 0.5, P.pos.z + sin(a) * j * 0.5):
					clear = false
					break
			if clear:
				return a
	return ang

## Holds `dir` for one segment; counts stalls. Returns steps, or -1 when the body left the map.
func _segment(arch: String, kind: String, dir: Vector2) -> int:
	P.inp["move"] = dir
	P.inp["aim"] = P.pos + Vector3(dir.x, 0.9, dir.y) * 8.0
	var total := int(SEG_S[kind] / DT)
	var low := 0.0
	var t_seg := 0.0
	var last_dir := dir
	for s in total:
		if kind == "dash" and s == int(0.3 / DT):
			P.dashes = P.max_dashes()
			P.ex_cd = 0.0
			P.do_dash()
		if kind == "glide":
			P.inp["jump"] = s < 3
			P.inp["glide"] = s > 12
			P.inp["glide_btn"] = s > 12
		var p0 := P.pos
		m.step(DT)
		t_seg += DT
		if P.pos.y < w.lowest_top() - 3.0 or P.out:
			_clear()
			return -1
		var hv := Vector2(P.vel.x, P.vel.z)
		var want := _wanted(kind)
		var counts := t_seg > SETTLE_S and want > 0.0 and _free_to_move(kind)
		path_s += DT if counts else 0.0
		if counts and hv.length() < want * STALL_FRAC and (P.pos - p0).length() < want * STALL_FRAC * DT:
			low += DT
			if low > STALL_S and low - DT <= STALL_S:
				_stall(arch, kind, dir)
			if low > STALL_S: stall_s += DT
		else:
			low = 0.0
	_clear()
	return total

## Is the body in the state the segment measures, and not slowed by design (stun, a ledge rise, a kit pace
## under 1 such as Motley's Trade in flight)?
func _free_to_move(kind: String) -> bool:
	if P.stun_t > 0.0 or not P.lfloat.is_empty() or (P.ak != null and P.ak.pace() < 1.0):
		return false
	match kind:
		"run": return P.grounded
		"glide": return P.gliding
		_: return P.roll_t > 0.0

func _clear() -> void:
	for k in ["jump", "dash", "glide", "glide_btn"]:
		P.inp[k] = false

func _wanted(kind: String) -> float:
	match kind:
		"run": return P.base_speed
		"dash": return P.roll_speed
		_: return GLIDE_WANT

## The stall just confirmed: skip it when a wall blocks by design, else file it by cell.
func _stall(arch: String, kind: String, dir: Vector2) -> void:
	var reach := Hunter.MANTLE_REACH + (Hunter.TALL_CLIMB_EXTRA if HunterMove.climbs_tall(P) else 0.0)
	var d := dir.normalized()
	var slide := _ideal_slide(d, reach)
	if slide < STALL_FRAC:
		return
	stalls += 1
	var key := "%d,%d" % [int(floor(P.pos.x)), int(floor(P.pos.z))]
	var e: Dictionary = spots.get(key, {"n": 0, "causes": {}, "archs": {}, "kinds": {}, "at": P.pos, "head": d})
	e["n"] = int(e["n"]) + 1
	var cause := _cause(d)
	for k in [["causes", cause], ["archs", arch], ["kinds", kind]]:
		e[k[0]][k[1]] = int(e[k[0]].get(k[1], 0)) + 1
	spots[key] = e

## The share of the wanted speed a perfect slide along the walls touching the body keeps: 1 with no wall
## in the way, sin(angle to the wall) when keys lean into one. A wall is a prop whose top is over the
## feet by more than World.STEP (props are never climbed), or terrain over the feet by more than mantle reach.
func _ideal_slide(d: Vector2, reach: float) -> float:
	var best := 1.0
	var rr := P.r + 0.3
	var p := Vector2(P.pos.x, P.pos.z)
	for tz in range(int(floor(p.y - rr)), int(floor(p.y + rr)) + 1):
		for tx in range(int(floor(p.x - rr)), int(floor(p.x + rr)) + 1):
			if not w.inb(tx, tz):
				continue
			var top := w.level[w.idx(tx, tz)] * World.LEVEL
			var wall := top > P.pos.y + reach
			if w.kind[w.idx(tx, tz)] == World.T_BLOCK:
				wall = top + World.BLOCK_H > P.pos.y + World.STEP
			if not wall:
				continue
			var c := Vector2(clampf(p.x, tx, tx + 1.0), clampf(p.y, tz, tz + 1.0))
			var n := p - c
			if n.length() > rr or n.length() < 0.0001:
				continue
			n = n.normalized()
			var into := -d.dot(n)
			if into > 0.0:
				best = minf(best, sqrt(maxf(0.0, 1.0 - into * into)))
	return best

## What looks like it caught the body: the ground, props and terrain just ahead of the keys.
func _cause(d: Vector2) -> String:
	var y := P.pos.y
	var side := Vector2(-d.y, d.x)
	var q0 := Vector2(P.pos.x, P.pos.z)
	var best := 0.0
	var prop := false
	var edge := false
	for o: Vector2 in [Vector2.ZERO, side * P.r, -side * P.r]:
		for dist: float in [P.r + 0.1, P.r + 0.35]:
			var q: Vector2 = q0 + o + d * dist
			best = maxf(best, w.ground_at(q.x, q.y) - y)
			prop = prop or w.is_block(q.x, q.y)
			edge = edge or w.is_void(q.x, q.y)
	if prop:
		return "prop corner"
	if best > World.LEVEL + 0.05:
		return "terrace wall %.1f m up" % best
	if best > World.STEP:
		return "lip %.2f m (World.STEP %.2f)" % [best, World.STEP]
	if edge:
		return "edge"
	return "none ahead" if P.grounded else "air"

func _report(n_paths: int) -> void:
	var list := spots.values()
	list.sort_custom(func(a, b): return int(a["n"]) > int(b["n"]))
	print("SNAG worst spots (%d cells, %d paths x %d hunters):" % [list.size(), n_paths, Arch.ORDER.size()])
	for e in list.slice(0, WORST):
		var at: Vector3 = e["at"]
		print("SNAG  %3d x at (%.1f, %.2f, %.1f) heading (%.2f,%.2f)  causes %s  kinds %s  hunters %d" % [
			e["n"], at.x, at.y, at.z, e["head"].x, e["head"].y, str(e["causes"]), str(e["kinds"]), e["archs"].size()])
	var by_cause := {}
	for e in list:
		for c in e["causes"]:
			var k := String(c).get_slice(" ", 0)
			by_cause[k] = int(by_cause.get(k, 0)) + int(e["causes"][c])
	print("SNAG by cause: %s" % str(by_cause))
