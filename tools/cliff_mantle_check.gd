extends RefCounted
## --cliff-mantle-check (item 185b): mantling at the real cliffs and terraces of the shipped expedition
## map (the Hollow Crown, on the Meadow and Dusk Isles tiers), as SUPERVIVE does it: fly into a ledge
## with momentum and come over the top still moving. Every non-sheer terrace face 1..4 terraces high
## (sampled) and every lipped island rim, for several Hunters played as a player (ctrl "local"):
##   jump_0 / jump_30 / jump_60  a running jump into the face, head-on and 30 and 60 degrees off
##   dash_jump                   a dash along the ground, then a jump into the face
##   jump_dash                   a running jump, then straight away an air dash into the face
##   glide                       gliding in below the lip
##   abyss                       falling below an island's rim, heading back in
## Asserts each kind of approach tops at least TOP_RATE of its tries, that over the lip you still have
## KEEP (0.6) of the speed you came in with in KEEP_RATE of them, and that no face is topped by nobody.
## Double-high ground (4 terraces, 3.2m: LAYOUT_RULES' wall tier) is never reached by jumping alone, a
## dash included: only a glide (or a launch, an ability, the abyss) gets you up it.
## With --verbose prints every try. Never touches the save.

const DT := Match.DT
const HEROES := ["thief", "gunslinger", "juggernaut", "mage", "dredge"]
const MAX_FACES := 16          # faces sampled per rise
const TRIAL_S := 2.6
const MODES := ["jump_0", "jump_30", "jump_60", "dash_jump", "jump_dash", "glide"]
const KEEP := MantleCarry.KEEP
const TOP_RATE := 0.9
const DOUBLE_HIGH := 4         # terraces: the wall tier, out of a jump's reach
const KEEP_RATE := 0.9

var m: Match
var w: World
var h: Hunter
var bad := 0
var stats := {}        # "kind rise mode" -> counts and sums
var verbose := false
var rises := 0         # tries that rose up a face (a Warden's mantle clip plays at the rise)
var rises_full := 0    # ...that got to the lip
var rises_back := 0    # steps the rise phase went backwards

func ok(cond: bool, what: String) -> void:
	print("CLIFF %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	verbose = "--verbose" in OS.get_cmdline_user_args()
	for tier in [0, 1]:
		await _tier(main, tier)
	var keys := stats.keys()
	keys.sort()
	print("CLIFF rows: topped, kept 0.6x, then means over the topped: speed in, lowest, over the lip, s")
	for k in keys:
		var s: Dictionary = stats[k]
		var n := maxf(1, s["top"])
		print("CLIFF row %-18s %3d/%-4d %3d/%-4d in %.1f low %.1f lip %.1f %.2fs" % [
			k, s["top"], s["n"], s["kept"], s["top"], s["vin"] / n, s["vmin"] / n, s["vlip"] / n, s["t"] / n])
		var top_rate := float(s["top"]) / maxf(1, s["n"])
		if String(k).begins_with("face %d " % DOUBLE_HIGH) and not String(k).ends_with("glide"):
			ok(s["top"] == 0, "%s: double-high ground can't be reached by jumping alone (%d tops)" % [k, s["top"]])
			continue
		ok(top_rate >= TOP_RATE, "%s: tops %d%% of tries" % [k, int(100.0 * top_rate)])
		var keep_rate := float(s["kept"]) / n
		var kept := "%s: keeps 0.6x speed over the lip %d%%" % [k, int(100.0 * keep_rate)]
		ok(s["top"] == 0 or keep_rate >= KEEP_RATE, kept)
	ok(rises > 0 and rises_back == 0 and rises_full * 10 >= rises * 9,
			"rise phase follows the body (%d rises, %d reach the lip, %d back)" % [rises, rises_full, rises_back])
	print("CLIFF DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _tier(main: Node, tier: int) -> void:
	if m:
		m.queue_free()
		await main.get_tree().process_frame
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": tier, "length": 1e9, "seed": 77 + tier, "no_drop": true})
	m.set_process(false)
	w = m.world
	print("CLIFF tier %d map %s (%dx%d)" % [tier, m.map_name, w.w, w.h])
	for i in 30:
		m.step(DT)
	_clear_others()
	var faces := _faces()
	var rims := _rims()
	print("CLIFF tier %d: %d terrace faces, %d rims" % [tier, faces.size(), rims.size()])
	for arch in HEROES:
		h.set_arch(arch)
		h.unlock_all()
		for f in faces:
			for mode in MODES:
				_count("face %d %s" % [f["rise"], mode], _try(f, mode), f, arch)
		for r in rims:
			_count("rim abyss", _try(r, "abyss"), r, arch)
	for f in faces:
		var where := "tier %d face %d terraces at %s dir %s" % [tier, f["rise"], f["a"], f["d"]]
		ok(f.get("topped", false), "%s: someone tops it" % where)

## Only the player is in the match: no monsters, rivals or Boki to bump into.
func _clear_others() -> void:
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	h = m.player
	for o in m.hunters:
		if o != h:
			o.ctrl = "idle"
			o.teleport(Vector3(-500, 50, -500))
			o.out = true
	for kk in [h.kin, h.kin2]:
		if kk:
			m.kins.erase(kk)
			kk.queue_free()
	h.kin = null
	h.kin2 = null
	h.ctrl = "local"

## r: {top, vin, vmin, vlip, t}; a try that couldn't start (no ground to stand on there) isn't counted
func _count(k: String, r: Dictionary, f: Dictionary, arch: String) -> void:
	if r.get("skip", false):
		return
	if not stats.has(k):
		stats[k] = {"n": 0, "top": 0, "kept": 0, "vin": 0.0, "vmin": 0.0, "vlip": 0.0, "t": 0.0}
	var s: Dictionary = stats[k]
	s["n"] += 1
	if r["k_max"] >= 0.0:
		rises += 1
		rises_full += 1 if r["k_max"] >= 0.9 else 0
		rises_back += r["k_back"]
	if r["top"]:
		s["top"] += 1
		f["topped"] = true
		for key in ["vin", "vmin", "vlip", "t"]:
			s[key] += r[key]
		if r["vlip"] >= KEEP * r["vin"] - 0.01:
			s["kept"] += 1
	if verbose:
		print("CLIFF try %s %s at %s dir %s: %s" % [k, arch, f["a"], f["d"], r])

func _ground(x: int, z: int) -> bool:
	return w.inb(x, z) and w.kind[w.idx(x, z)] == World.T_GROUND and not w.stairs.has(w.idx(x, z))

func _lv(x: int, z: int) -> int:
	return w.level[w.idx(x, z)]

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Terrace faces: a low tile a whose neighbour b (along d) is 1..4 terraces higher, b not sheer, a
## 4-tile run-up 3 tiles wide behind a at a's level, ground behind b to land on, and a straight face.
func _faces() -> Array:
	var by_rise := {1: [], 2: [], 3: [], 4: []}
	for z in w.h:
		for x in w.w:
			if not _ground(x, z):
				continue
			for d: Vector2i in DIRS:
				var b := Vector2i(x, z) + d
				if not _ground(b.x, b.y) or w.sheer.has(w.idx(b.x, b.y)):
					continue
				var rise := _lv(b.x, b.y) - _lv(x, z)
				var beyond := b + d
				if rise < 1 or rise > 4 or not _ground(beyond.x, beyond.y) or _lv(beyond.x, beyond.y) < _lv(b.x, b.y):
					continue
				if _runway(Vector2i(x, z), d) and _straight(Vector2i(x, z), d, rise):
					by_rise[rise].append({"a": Vector2i(x, z), "d": d, "rise": rise, "la": _lv(x, z)})
	var out: Array = []
	for r in by_rise:
		out.append_array(_spread(by_rise[r]))
	return out

func _runway(a: Vector2i, d: Vector2i) -> bool:
	for k in range(1, 5):
		for s in [-1, 0, 1]:
			var q: Vector2i = a - d * k + Vector2i(d.y, d.x) * s
			if not _ground(q.x, q.y) or _lv(q.x, q.y) != _lv(a.x, a.y):
				return false
	return true

## A straight stretch of face: the same rise for 2 tiles either side (an angled run slides along it).
func _straight(a: Vector2i, d: Vector2i, rise: int) -> bool:
	var side := Vector2i(d.y, d.x)
	for s in [-2, -1, 1, 2]:
		var lo: Vector2i = a + side * s
		var hi: Vector2i = lo + d
		if not _ground(lo.x, lo.y) or not _ground(hi.x, hi.y) or _lv(lo.x, lo.y) != _lv(a.x, a.y):
			return false
		if _lv(hi.x, hi.y) - _lv(lo.x, lo.y) != rise or w.sheer.has(w.idx(hi.x, hi.y)):
			return false
	return true

## Evenly spaced picks, at most MAX_FACES.
func _spread(arr: Array) -> Array:
	var out: Array = []
	var stride := maxi(1, ceili(arr.size() / float(MAX_FACES)))
	for i in range(0, arr.size(), stride):
		out.append(arr[i])
	return out

## Lipped island rims: ground tile b, the void for two tiles out from it, and ground behind it.
func _rims() -> Array:
	var arr: Array = []
	for z in w.h:
		for x in w.w:
			if not _ground(x, z) or w.sheer.has(w.idx(x, z)):
				continue
			for d: Vector2i in DIRS:
				var a := Vector2i(x, z) - d
				var a2 := a - d
				if _void(a) and _void(a2) and _ground(x + d.x, z + d.y):
					arr.append({"a": a, "d": d, "rise": 0, "la": _lv(x, z)})
	return _spread(arr)

func _void(p: Vector2i) -> bool:
	return w.inb(p.x, p.y) and w.kind[w.idx(p.x, p.y)] == World.T_VOID

const TIMERS := ["grap_cd", "mantle_cd", "roll_t", "knock_t", "fly_t", "stun_t",
	"dash_buf", "coyote", "jump_buf", "ex_cd"]

func _reset(at: Vector3, grounded: bool) -> void:
	h.out = false
	h.downed = false
	h.hp = h.max_hp
	h.teleport(at)
	h.grounded = grounded
	h.vel = Vector3.ZERO
	h.pad = {}
	h.grap = {}
	h.lfloat = {}
	for k in TIMERS:
		h.set(k, 0.0)
	h.kb_t = -9.0
	h.gliding = false
	h.dropping = false
	h.diving = false
	h.last_gy = at.y
	h.air_t = 0.0 if grounded else 0.3
	h.carry_v = 0.0
	h.carry_mini = {}
	h.dashes = h.max_dashes()
	for k in ["glide", "glide_btn", "jump", "dash", "fire", "sig", "sec", "ult"]:
		h.inp[k] = false
	h.inp["move"] = Vector2.ZERO
	for i in 3:
		m.step(DT)

## Puts the Hunter at the start of an approach; false if it can't stand there.
func _setup(f: Dictionary, mode: String, face: Vector2, mv: Vector2, top: float) -> bool:
	var dv := Vector2(f["d"])
	var gy := float(f["la"]) * World.LEVEL
	if mode == "abyss":
		var p := face - dv * 3.0
		_reset(Vector3(p.x, top - 1.2, p.y), false)
		h.last_gy = top
		h.vel = Vector3(dv.x * 6.0, 0.0, dv.y * 6.0)
	elif mode == "glide":
		var p2 := face - mv * 5.0
		_reset(Vector3(p2.x, top - 0.2, p2.y), false)
		h.last_gy = gy
		h.inp["glide"] = true
		h.inp["glide_btn"] = true
		h.gliding = true
		h.vel = Vector3(mv.x * 6.0, 0.0, mv.y * 6.0)
	else:
		# already running: 6m out head-on (a dash needs the room), else 1.6m from the face's plane
		var out := 6.0 if mode == "dash_jump" else 1.6
		var st := face - mv * (out / maxf(0.5, mv.dot(dv)))
		_reset(Vector3(st.x, gy + 0.02, st.y), true)
		h.vel = Vector3(mv.x, 0.0, mv.y) * h.base_speed
		return h.grounded and absf(h.pos.y - gy) <= 0.3
	return true

## One approach at a face (or a rim, mode "abyss"). Returns {top, vin, vmin, vlip, t}: vin the horizontal
## speed as you reach the face, vmin the lowest from then until you're over the top, vlip the speed as you
## first stand over the top tile, t the seconds from reaching the face to over it.
func _try(f: Dictionary, mode: String) -> Dictionary:
	var a: Vector2i = f["a"]
	var d: Vector2i = f["d"]
	var dv := Vector2(d)
	var face := Vector2(a.x + 0.5, a.y + 0.5) + dv * 0.5
	var top := float(f["la"] + f["rise"]) * World.LEVEL
	var ang := 0.0
	if mode in ["jump_0", "jump_30", "jump_60"]:
		ang = float(mode.substr(5)) * (1.0 if (a.x + a.y) % 2 == 0 else -1.0)
	var mv := dv.rotated(deg_to_rad(ang))
	var res := {"top": false, "vin": 0.0, "vmin": 99.0, "vlip": 0.0, "t": 0.0, "k_max": -1.0, "k_back": 0}
	var k_was := -1.0
	if not _setup(f, mode, face, mv, top):
		res["skip"] = true
		return res
	h.inp["aim"] = Vector3(face.x + mv.x * 4.0, top + 0.9, face.y + mv.y * 4.0)
	var t := 0.0
	var jumped := mode in ["glide", "abyss"]
	var dashed := not mode.contains("dash")
	var touch_t := -1.0
	var b := a + d
	while t < TRIAL_S:
		h.inp["move"] = mv
		h.inp["jump"] = false
		h.inp["dash"] = false
		var to_face := (face - Vector2(h.pos.x, h.pos.z)).dot(dv)
		if mode == "dash_jump" and not dashed and to_face < 3.2:
			h.inp["dash"] = true
			dashed = true
		elif not jumped and (dashed or mode == "jump_dash") and to_face < (2.6 if mode == "jump_dash" else 1.4):
			h.inp["jump"] = true
			jumped = true
		elif mode == "jump_dash" and jumped and not dashed and h.air_t > 0.08 and not h.grounded:
			h.inp["dash"] = true
			dashed = true
		var hv := Vector2(h.vel.x, h.vel.z).length()
		m.step(DT)
		t += DT
		var hv1 := Vector2(h.vel.x, h.vel.z).length()
		var rk := MantleCarry.rise_k(h)
		if rk >= 0.0 and k_was >= 0.0 and rk < k_was - 0.001:
			res["k_back"] += 1
		res["k_max"] = maxf(res["k_max"], rk)
		k_was = rk
		res["ymax"] = maxf(float(res.get("ymax", -9.0)), h.pos.y - top)
		res["dmin"] = minf(float(res.get("dmin", 9.0)), to_face)
		if touch_t < 0.0 and (to_face < h.r + 0.35 or not h.lfloat.is_empty()):
			touch_t = t
			res["vin"] = maxf(hv, hv1)
		if touch_t >= 0.0:
			res["vmin"] = minf(res["vmin"], hv1)
		var past := (Vector2(h.pos.x, h.pos.z) - face).dot(dv) > 0.3
		var on_b := int(floor(h.pos.x)) == b.x and int(floor(h.pos.z)) == b.y
		if (on_b or past) and h.pos.y >= top - 0.15 and touch_t >= 0.0:
			res["top"] = true
			res["vlip"] = hv1
			res["t"] = t - touch_t
			break
	if res["vmin"] > 90.0:
		res["vmin"] = 0.0
	return res
