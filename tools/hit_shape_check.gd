extends RefCounted
## --hit-shape-check: how far, how wide and how round each Hunter's damaging inputs really hit
## (docs/HITBOX_SIZE.md, "Measured hit shapes"). The hero stands facing +X on flat ground beside a
## grid of training dummies (0.5 m apart, the standard body radius) and fires LMB tap and hold, RMB tap
## and hold, E, X (the hero ultimate) and the dash once each, aimed straight down +X. Which dummies lost
## health gives reach, lane width and arc. Only z >= 0 is gridded (shapes aimed down +X are mirrored:
## 70 dummies instead of 400 keep the run under a minute). A bullet stops at the first dummy it hits, so
## a shot is measured from its own flight range and radius instead. Prints HSROW lines for the doc table.
## Never touches the save.

const STEP := 1.0 / 20.0         # s per Match step (the grid is too heavy for 60 Hz)
const NX := 14                   # columns: x = 1.0 .. 7.5 m
const NZ := 5                    # rows: z = 0 .. 2.0 m (mirrored)
const GRID := 0.5                # m between dummies
const TOL := 0.10                # a content number this far off the measurement is flagged
const REACH_KEYS := ["range", "reach", "len", "length", "dist", "roll", "lunge"]
const WIDTH_KEYS := ["width"]
const ARC_KEYS := ["deg", "arc", "angle"]

var bad := 0
var m: Match
var p: Hunter
var home: Vector3
var dummies: Array = []
var n_dummies := NX * NZ
var step_dt := STEP
var parked := false              # the dummies stand behind the hero: a lane probe, only the shots count
var shot_seen: Array = []        # [reach from the hero, radius] of each non-melee shot the hero fired
var swing_seen := false          # the input fired a melee swing (its rays stop at the first dummy of the grid)
var layout := "grid"             # where the dummies stand: "grid", or a HitShapeZero layout (lane, ring)
var ring_r := 0.0                # the radius of the "ring" layout (m)
var pick := -1                   # the pass of a lane or ring (HitShapeZero.slot)
var aim_d := 20.0                # how far down +X the cursor is (m)
## Inputs whose hit the grid cannot read, so they are never flagged here: a dash that stops on the first foe
## it meets. Their lone-dummy reach is in --hit-shape-fine.
const FIRST_FOE := ["ashwick:dash"]
## Inputs reconciled with their content numbers (docs/HITBOX_SIZE.md "Mismatches over 10%", 11-21): a plain
## flag on one of these fails the check.
const RECONCILED := ["juggernaut:lmb", "juggernaut:lmb_hold", "juggernaut:dash", "ashwick:dash", "gunslinger:e",
	"bulwark:lmb", "bulwark:lmb_hold", "dredge:lmb", "dredge:x", "rimewright:e", "dolm:lmb",
	"mage:dash", "mage:dash_hold"]

func ok(cond: bool, what: String) -> void:
	print("HSCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _slot(i: int) -> Vector3:
	if layout != "grid": return home + HitShapeZero.slot(layout, i, ring_r, pick)
	return home + Vector3(1.0 + (i / NZ) * GRID, 0.0, (i % NZ) * GRID)

func _clear_dummies() -> void:
	for i in dummies.size():
		var d: Hunter = dummies[i]
		d.teleport(home + Vector3(-6.0, 0, 6.0) if parked else _slot(i))
		d.vel = Vector3.ZERO
		var parked_out := layout != "grid" and pick >= 0 and i % HitShapeZero.PASSES != pick
		d.out = parked_out      # (a dummy off its pass costs no step time)
		d.body_r = -1.0 if layout == "grid" else 0.01      # (a lane's dummies overlap: no body pushing, or they spread)
		d.hp = d.max_hp
		d.stun_t = 0.0
		d.root_t = 0.0
		d.slow_t = 0.0
		d.knock_t = 0.0
		d.burn_t = 0.0
		d.blight_t = 0.0
		d.vuln_t = 0.0
		d.marks = {}
		d.hit_by = {}
		for key in d.get_meta_list(): d.remove_meta(key)      # (a status or a mark an earlier input left on it)

## No wild monster stays on the field (one wandering in would bite a dummy, and read as a hit).
func _clear_mobs() -> void:
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()

## A lane's or ring's dummies stand close together: hold each on its slot (a knock or a push would carry it away).
func _pin() -> void:
	for i in dummies.size():
		var d: Hunter = dummies[i]
		d.teleport(_slot(i))
		d.vel = Vector3.ZERO

## The slots that lost health since the last call; the dummies go back to their places.
func _took_damage() -> Array:
	var hit: Array = []
	for i in dummies.size():
		var d: Hunter = dummies[i]
		if d.hp < d.max_hp: hit.append(i)
	return hit

func _spawn(main: Node) -> void:
	var ac: RefCounted = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var r: Array = ac.setup("mage", 30.0)
	m = r[0]
	p = r[1]
	home = r[4]
	(r[2] as Hunter).teleport(home + Vector3(-6.0, 0, -8.0))      # the setup's own target: out of the grid
	for i in n_dummies:
		var d: Hunter = m.make_hunter("D%d" % i, 5, "medium", "Dummy", "idle", {}, _slot(i), {"arch": "none"})
		d.max_hp = 1e6
		d.hp = 1e6
		dummies.append(d)

## Fresh hero, fresh dummies, aim down +X; then fires `kind` and returns the slots hit within `secs`.
func _probe(arch: String, kind: String, hold: float, secs: float, park := false, again := []) -> Array:
	parked = park
	_prep(arch)
	var hit := {}
	var t := 0.0
	while t < secs:
		_press(kind, hold, t, t == 0.0)
		for a in again:
			if t >= float(a[0]) and not a.has("done"):
				a.append("done")
				_again(String(a[1]))
		m.step(0.002 if t == 0.0 else step_dt)      # (a tiny first step: a bullet is seen before a dummy eats it)
		t += step_dt
		for s in m.shots:
			if s["by"] == p and s["x"].get("melee", false): swing_seen = true
			if s["by"] == p and not s["x"].get("melee", false) and not s.has("hs_seen"):
				s["hs_seen"] = true
				shot_seen.append([_shot_reach(s), float(s["r"])])
		if parked and not shot_seen.is_empty(): break
		for i in _took_damage(): hit[i] = true
		_clear_mobs()
		if layout != "grid":
			_pin()
		if kind == "rmb_hold" and t >= hold: p.inp["sec_hold"] = false
	_release()
	return hit.keys()

## How far from the hero a shot ends: where it starts (a muzzle sits ahead of the body) plus its flight, which
## for a slug that slows (`decel`, the shotgun) is v^2 / 2a, not its life times its first speed.
func _shot_reach(s: Dictionary) -> float:
	var v := (s["vel"] as Vector2).length()
	var fly := float(s["life0"]) * v
	if s["x"].has("decel") and float(s["x"]["decel"]) > 0.0:
		fly = minf(fly, v * v / (2.0 * float(s["x"]["decel"])))
	var st: Vector3 = s.get("start", s["pos"]) - home
	return Vector2(st.x, st.z).length() + fly

## The hero as `arch` at home, aimed down +X at full ult and charges, the dummies in their slots.
func _prep(arch: String) -> void:
	HeroVfx.of(m).ribbons.clear()      # (a trail still following the old model would read a freed node)
	p.reclass(Arch.weight(arch), arch)
	p.unlock_all()
	p.lvl = 6
	p.slot_lv["ult"] = 1
	p.ult = 1.0
	p.dashes = p.max_dashes()
	p.hp = p.max_hp
	p.teleport(home)
	p.vel = Vector3.ZERO
	p.dash_pass = {}  # (a dash cut short keeps what it did to foes in its way, for the next hero)
	p.inp["aim"] = home + Vector3(aim_d, 0.9, 0)
	p.inp["aim_y"] = home.y
	m.shots.clear()
	m.zones.clear()
	m.fields.list.clear()      # (an ult's patch or wall from the last input)
	_clear_mobs()
	m._later.clear()      # (a delayed step of the last input)
	m.meteors.clear()
	_clear_dummies()
	shot_seen.clear()
	swing_seen = false
	for i in 3: m.step(step_dt)
	_clear_dummies()

## One step of input for `kind` `t` seconds into it (`first`: the press itself).
func _press(kind: String, hold: float, t: float, first: bool) -> void:
	var held := t < hold
	p.inp["fire"] = (kind == "lmb" and first) or (kind in ["lmb_hold", "x_fire"] and held)
	p.inp["sec_hold"] = kind == "rmb_hold" and held
	p.inp["dash_down"] = (kind == "dash" and first) or (kind == "dash_hold" and held)
	p.fire_cd = 0.0 if first else p.fire_cd
	if first:
		match kind:
			"rmb", "rmb_hold": p.ak.press_rmb()
			"e": p.ak.use_e()
			"x", "x_fire": p.ak.cast_ult()
			"dash", "dash_hold": p.do_dash()

## A second press of the same input (a recast, the follow-up strike): `again` = [seconds in, input].
func _again(kind: String) -> void:
	match kind:
		"e": p.ak.use_e()
		"x": p.ak.cast_ult()
		"rmb": p.ak.press_rmb()
		"dash": p.do_dash()

func _release() -> void:
	p.inp["fire"] = false
	p.inp["dash_down"] = false
	p.inp["sec_hold"] = false

## {reach, width, arc, n}: reach to the far edge of what was hit (m), the widest lane across the
## aim line (m) and the angle the hits spread over (degrees). Centres are corrected by the dummy's
## own hit circle and by half a grid cell, since a dummy is hit once its circle touches the shape.
func _measure(hit: Array) -> Dictionary:
	var out := {"n": hit.size(), "reach": 0.0, "width": 0.0, "arc": 0.0, "src": "grid", "cap": ""}
	if hit.is_empty(): return out
	var rd: float = dummies[0].hit_radius()
	var far := 0.0
	var zmax := 0.0
	for i in hit:
		var c: Vector3 = _slot(i) - home
		far = maxf(far, Vector2(c.x, c.z).length())
		zmax = maxf(zmax, c.z)
	var edge_x := 1.0 + (NX - 1) * GRID
	var edge_z := (NZ - 1) * GRID
	var cap := ""
	for i in hit:
		var c: Vector3 = _slot(i) - home
		if c.x >= edge_x and not cap.contains("r"): cap += "r"
		if c.z >= edge_z and not cap.contains("w"): cap += "w"
	out["cap"] = cap
	var arc := 0.0
	for i in hit:
		var c: Vector3 = _slot(i) - home
		if Vector2(c.x, c.z).length() >= far * 0.6: arc = maxf(arc, absf(atan2(c.z, c.x)))
	out["reach"] = maxf(0.0, far - rd + GRID * 0.5)
	out["width"] = maxf(0.0, 2.0 * (zmax - rd + GRID * 0.5))
	out["arc"] = rad_to_deg(arc) * 2.0 if zmax > rd + GRID else 0.0
	return out

func _top(d: Dictionary, keys: Array) -> float:
	var best := 0.0
	for k in keys:
		var v = d.get(k, 0.0)
		if v is Array and not v.is_empty():
			best = maxf(best, float(v[v.size() - 1]))
		elif v is float or v is int:
			best = maxf(best, float(v))
	return best

## The kit's JSON numbers for this input: the slot's def (or the weapon for LMB). Kits whose hit is not the
## plain number read the field the kit hits with (`shot`: a projectile that bursts on the first dummy, measured
## on a clear lane instead).
func _content(kind: String) -> Dictionary:
	var o := _content_kit(p.arch, kind)
	if not o.is_empty(): return o
	var d: Dictionary
	match kind:
		"lmb", "lmb_hold": d = p.wpn
		"rmb", "rmb_hold": d = p.ak.rmb_def()
		"e": d = p.ak.e_def()
		"x", "x_fire": d = p.ak.x_def()
		_: d = p.ak.dash_def()
	return {"reach": _top(d, REACH_KEYS), "width": _top(d, WIDTH_KEYS), "arc": _top(d, ARC_KEYS)}

## "reach +23%" for every content number that is more than TOL off; "~" marks one within the 0.5 m grid (a
## lane's width is two edges, so 1.0 m). A swing or a first-foe dash is not flagged (the grid stops it).
func _flags(meas: Dictionary, cont: Dictionary) -> String:
	var out: Array = []
	if meas["src"] in ["swing", "first"]: return ""
	for k in ["reach", "width", "arc"]:
		var c: float = cont[k]
		var v: float = meas[k]
		if c <= 0.0 or int(meas["n"]) == 0: continue
		var edge := "r" if k == "reach" else "w"
		if edge in meas["cap"]: continue      # the grid ends first
		if absf(v - c) > TOL * c:
			var grid_err := 2.0 * GRID if k == "width" else GRID
			var tag := "~" if k != "arc" and absf(v - c) <= grid_err else ""
			out.append("%s%s %+.0f%%" % [tag, k, (v - c) / c * 100.0])
	return ", ".join(out)

func _has(_arch: String, kind: String) -> bool:
	match kind:
		"rmb_hold": return float(p.ak.rmb_def().get("hold", 0.0)) > 0.0
		"dash_hold": return float(p.ak.dash_def().get("hold", 0.0)) > 0.0
		"x": return not p.ak.x_def().is_empty()
		"lmb_hold": return p.wpn.has("charge_time") or p.wpn.has("draw")
	return true

func _secs_for(kind: String, hold: float) -> float:
	match kind:
		"e": return 3.0 if p.arch == "rimewright" else 1.2      # (Rink Wall slides about 4 m/s: give it the grid)
		"x": return 1.5
		"lmb": return 0.5
		"rmb", "rmb_hold": return maxf(hold + 0.5, 0.6) + _flight_s()
	return hold + 0.5 if hold > 0.0 else 0.6

## Seconds a thrown RMB (Gil's flask) spends in the air before it lands: its flight plus the flight per metre.
func _flight_s() -> float:
	var rd := p.ak.rmb_def()
	var far := float(rd.get("range", 0.0)) * float(rd.get("hold_range", 1.0))
	return float(rd.get("flight", 0.0)) + float(rd.get("flight_per_m", 0.0)) * far

func _hold_for(kind: String) -> float:
	match kind:
		"lmb_hold": return maxf(float(p.wpn.get("charge_time", 0.0)), 1.1 if p.wpn.has("draw") else 0.6) + 0.15
		"rmb_hold":
			var rd := p.ak.rmb_def()
			return maxf(float(rd.get("full_t", 0.0)), float(rd.get("hold", 0.3)) + 0.5) + 0.1
		"dash_hold": return float(p.ak.dash_def().get("hold", 0.6)) + 0.05
	return 0.0

## Where the spark of a hit on `tgt` spawned: the impact flash nearest its body, within 1.5 s of `kind` being
## pressed as in _probe (`put_zone`: a Cinder patch under the target instead, nothing pressed).
func _spark_at(arch: String, kind: String, tgt: Hunter, put_zone := false) -> Vector3:
	parked = true      # (the grid dummies stand behind the hero: only `tgt` is in the line of fire)
	_prep(arch)
	m.fields.list.clear()
	tgt.teleport(home + Vector3(1.6 if put_zone else 3.0, 0, 0))
	tgt.hp = tgt.max_hp
	tgt.vel = Vector3.ZERO
	if put_zone:
		var patch := {"radius": 2.0, "dmg": 5.0, "every": 0.2, "time": 3.0, "color": "#ff7a30"}
		m.fields.add(p, tgt.pos, patch, {"slot": "zone"}, 1.0)
	var t := 0.0
	while t < 1.5:
		m.fx.flashes.clear()
		_press(kind, _hold_for(kind), t, t == 0.0)
		m.step(0.002 if t == 0.0 else step_dt)
		t += step_dt
		if tgt.hp < tgt.max_hp:
			break
	_release()
	var best := Vector3(INF, INF, INF)
	for f in m.fx.flashes:
		var at: Vector3 = (f["node"] as Node3D).global_position
		if at.distance_to(tgt.pos) < best.distance_to(tgt.pos):
			best = at
	return best

## A dummy of Hunter `arch`, parked out of the way (the shared hit shapes' dummies are all `arch: none`).
func _target(id: String, arch: String, dz: float) -> Hunter:
	var spot := home + Vector3(-6.0, 0, 6.0 + dz)
	var t := m.make_hunter(id, 5, Arch.weight(arch), "Target", "idle", {}, spot, {"arch": arch})
	t.reclass(Arch.weight(arch), arch)
	t.max_hp = 1e6
	t.hp = 1e6
	return t

## The spark of a hit sits inside the target's collider (its hurtbox circle, feet to top of head), whatever
## the kit that hit: a projectile (Vex), a melee sweep (Kael), a zone tick (Cinder, low: a patch on the ground).
func _contact_checks() -> void:
	var cases := [["gunslinger", "lmb", false], ["juggernaut", "lmb", false], ["ashwick", "", true]]
	for tarch in ["dredge", "tender"]:
		var tgt := _target("T_" + tarch, tarch, 0.0)
		for c in cases:
			var at := _spark_at(c[0], c[1], tgt, c[2])
			var h := Arch.hit_h(tarch)
			var flat := Vector2(at.x - tgt.pos.x, at.z - tgt.pos.z).length()
			var rise := at.y - tgt.pos.y
			var what := "%s on %s (%.2f m tall): spark %.2f m up, %.2f m off centre" % [c[0], tarch, h, rise, flat]
			ok(at.x < INF and flat <= tgt.r + 0.01 and at.y >= tgt.pos.y and at.y <= tgt.pos.y + h, what)
			if c[2]:
				ok(at.y - tgt.pos.y < 0.5, "%s: a zone tick sparks low, at the patch on the ground" % c[0])
		tgt.teleport(home + Vector3(-6.0, 0, 6.0))
	var tall := _target("T_tall", "dredge", 0.0)
	var small := _target("T_small", "tender", 2.0)
	var top := Vector3(tall.pos.x + 5.0, tall.pos.y + 9.0, tall.pos.z)
	ok(is_equal_approx(HitContact.clamp_to(tall, top).y - tall.pos.y, Arch.hit_h("dredge") - HitContact.EDGE),
			"a point over the head is held at the head top: tall")
	ok(is_equal_approx(HitContact.clamp_to(small, top).y - small.pos.y, Arch.hit_h("tender") - HitContact.EDGE),
			"a point over the head is held at the head top: small")
	var side := HitContact.clamp_to(small, top)
	ok(Vector2(side.x - small.pos.x, 0).length() <= small.r + 0.001, "a point off to the side is held in the hurtbox")
	var struck := HitContact.point(small, tall, {}).y - small.pos.y
	ok(struck > 0.0 and struck < Arch.hit_h("tender"), "a hit with no contact point still lands inside the collider")


## The measured row of input `kind` of `a`, and the content numbers it is read against: [meas, cont]. A zero
## row has a driver (HitShapeZero.DRIVERS) or is a NO_DAMAGE input; the plain run is the shared grid.
func _row(a: String, kind: String, key: String) -> Array:
	if HitShapeZero.DRIVERS.has(key):
		var driven := HitShapeZero.measure(self, a, kind, HitShapeZero.DRIVERS[key])
		return [driven, HitShapeZero.content(self, a, kind)]
	var hold := _hold_for(kind)
	var hit := _probe(a, kind, hold, _secs_for(kind, hold))
	var meas := _measure(hit)
	var cont := _content(kind)
	if swing_seen and meas["n"] > 0: meas["src"] = "swing"
	if key in FIRST_FOE: meas["src"] = "first"
	var lone_shot: bool = meas["n"] >= 1 and meas["n"] <= 2 or cont.get("shot", false)
	if lone_shot and kind != "dash" and kind != "dash_hold":
		_probe(a, kind, hold, _secs_for(kind, hold), true)      # a lone bullet: measured on a clear lane
		if not shot_seen.is_empty():
			var far := 0.0
			for sh in shot_seen: far = maxf(far, sh[0])
			var wide := 2.0 * float(shot_seen[0][1])
			meas = {"n": meas["n"], "reach": far, "width": wide, "arc": 0.0, "src": "shot", "cap": ""}
	return [meas, cont]

## A row that read zero must be an input that hurts nobody by design (HitShapeZero.NO_DAMAGE, proved here
## on a longer window), or it has no driver yet: the check fails.
func _zero_ok(a: String, kind: String, key: String, meas: Dictionary) -> void:
	if int(meas["n"]) > 0:
		if HitShapeZero.NO_DAMAGE.has(key): ok(false, "%s hurt a dummy: it is not a no-damage input" % key)
		return
	if HitShapeZero.NO_DAMAGE.has(key):
		ok(HitShapeZero.hurt_nobody(self, a, kind), "%s hurts nobody (%s)" % [key, HitShapeZero.NO_DAMAGE[key][0]])
	else:
		ok(false, "%s reads zero hit and has no driver (HitShapeZero.DRIVERS) or no-damage reason" % key)

## Prints the HSROW line of one input and fails a reconciled row that drifted; 1 when it hurt a dummy.
func _report(a: String, kind: String, key: String, meas: Dictionary, cont: Dictionary) -> int:
	var flags := _flags(meas, cont)
	if key in RECONCILED:
		var plain := 0
		for f in flags.split(", ", false): plain += 0 if f.begins_with("~") else 1
		ok(plain == 0, "%s %s matches its content numbers (%s)" % [a, kind, flags])
	var src: String = meas["src"] + ("+" + meas["cap"] if meas["cap"] != "" else "")
	if int(meas["n"]) == 0: src = "none"
	print("HSROW|%s|%s|%d|%s|%.1f|%.1f|%.0f|%.1f|%.1f|%.0f|%s" % [a, kind, meas["n"], src,
			meas["reach"], meas["width"], meas["arc"], cont["reach"], cont["width"], cont["arc"], flags])
	return 1 if int(meas["n"]) > 0 else 0

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	await _spawn(main)
	var t0 := CheckClock.own_msec()
	var only := ""      # (--hero=<arch>: one hunter only, for a quick look)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hero="): only = arg.substr(7)
	for a in Arch.ids():
		if only != "" and not (a in only.split(",")): continue
		var hits := 0
		p.reclass(Arch.weight(a), a)
		for kind in ["lmb", "lmb_hold", "rmb", "rmb_hold", "e", "x", "dash", "dash_hold"]:
			if not _has(a, kind): continue
			var key: String = a + ":" + kind
			var row := _row(a, kind, key)
			var meas: Dictionary = row[0]
			var cont: Dictionary = row[1]
			_zero_ok(a, kind, key, meas)
			hits += _report(a, kind, key, meas, cont)
		for key in HitShapeZero.EXTRA:
			if not key.begins_with(a + ":"): continue
			var extra_kind: String = key.split(":")[1]
			var meas := HitShapeZero.measure(self, a, "rmb", HitShapeZero.EXTRA[key])
			_zero_ok(a, extra_kind, key, meas)
			_report(a, extra_kind, key, meas, HitShapeZero.content(self, a, extra_kind))
		ok(hits >= 1, "%s: at least one input hurt a dummy (%d did)" % [a, hits])
	_contact_checks()
	var took := (CheckClock.own_msec() - t0) / 1000.0
	ok(took < 120.0, "the run took %.1f s (budget 120)" % took)
	HeroVfx.of(m).ribbons.clear()
	print("HIT SHAPE CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Content for the inputs whose JSON number is not the hit's own size (docs/HITBOX_SIZE.md, "Mismatches over 10%").
func _content_kit(a: String, kind: String) -> Dictionary:
	var l: Dictionary = p.ak.lmb_def()
	match a + ":" + kind:
		"juggernaut:lmb":      # the kit's sword (lmb.reach / arc), not greatsword.json's range 3.4 / arc 160
			return {"reach": float(l["reach"]), "width": 0.0, "arc": float(l["arc"])}
		"juggernaut:lmb_hold":      # Searing Wave at full charge
			var wave_w := 2.0 * float(l["wave_size"][1])
			return {"reach": float(l["wave_range"][1]), "width": wave_w, "arc": 0.0, "shot": true}
		"juggernaut:dash":      # the dash and the tip burst at its end
			var dd := p.ak.dash_def()
			return {"reach": float(dd["dist"]) + float(dd["tip_r"]), "width": 0.0, "arc": 0.0}
		"gunslinger:e":      # JSON `width` is the half-width of the beam
			return {"reach": float(p.ak.e_def()["range"]), "width": 2.0 * float(p.ak.e_def()["width"]), "arc": 0.0}
		"bulwark:lmb":      # the hammer throw: flies throw_range and sweeps 0.9 m round its path
			return {"reach": float(l["throw_range"]) + 0.9, "width": 1.8, "arc": 0.0}
		"bulwark:lmb_hold":      # Crushing Blow
			return {"reach": float(l["smash_reach"]), "width": 0.0, "arc": float(l["smash_arc"])}
		"dolm:lmb":
			var b: Dictionary = l["boulder"]
			return {"reach": float(b["range"]), "width": 2.0 * float(b["size"]), "arc": 0.0, "shot": true}
		"dolm:lmb_hold":      # the punch lane, from where she stands at the release (the step comes after)
			var pu: Dictionary = l["punch"]
			return {"reach": float(pu["len"]), "width": float(pu["width"]), "arc": 0.0}
		"rimewright:e":      # the wall erupts `reach` ahead and slides up to `travel` toward the cursor
			var ed := p.ak.e_def()
			return {"reach": float(ed["reach"]) + float(ed["travel"]), "width": 0.0, "arc": 0.0}
		"mage:dash", "mage:dash_hold":      # Wirerun hurts what the body crosses, padded by width + 0.6
			var wd := p.ak.dash_def()
			return {"reach": float(wd["dist"][1]), "width": float(wd["width"]) + 0.6 + 2.0 * p.r, "arc": 0.0}
	return {}
