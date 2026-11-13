extends RefCounted
## The damage colours of the shared category tables (AbilityFx.CAT, Feel.CAT, KinRules.CAT_COLORS) belong to Boki
## and generic casts. No Hunter's ability may show them: every Hunter casts RMB (tap and hold), E, R and X (alone
## and with a Boki to merge with) while the effects layer records every colour it is asked to draw, and the
## Hunter data (hunter_abilities, gear, utility) is scanned for them. Called by --hero-vfx-check.

const DATA_DIRS := ["hunter_abilities", "gear", "utility"]
const HOLD_S := 0.8      # s RMB is held for the hold variant
const SETTLE_S := 0.7    # s a cast plays out (its delayed rings and bursts draw too)
const TOL := 0.005       # rgb distance that counts as the same colour
const KIN := "cindle"    # the Boki that comes along for a merge

## Records every colour the effects layer is asked for; draws nothing.
class CatSpy extends Fx:
	var seen: Array = []
	func _ready() -> void:
		pass
	func dust(_at: Vector3, _n := 8) -> void:
		pass
	func spark(_at: Vector3, _dir: Vector3, col: Color, _n := 8, _speed := 9.0, _spread := 50.0, _life := 0.22,
			_grav := 10.0, _size := 1.0) -> void:
		seen.append(col)
	func muzzle(_at: Vector3, _dir2: Vector2, col: Color, _power := 1.0) -> void:
		seen.append(col)
	func impact(_at: Vector3, _dir: Vector3, col: Color, _power := 1.0, _crit := false, _armor := false) -> void:
		seen.append(col)
	func beam(_a: Vector3, _b: Vector3, col: Color, _width := 0.45, _dur := 0.28) -> void:
		seen.append(col)
	func burst(_at: Vector3, col: Color, _n := 14, _speed := 4.0, _life := 0.5, _grav := 12.0, _size := 1.0,
			_dir := Vector3.UP, _spread := 180.0) -> void:
		seen.append(col)
	func ghost(_at: Vector3, _yaw: float, col: Color, _scl: float) -> void:
		seen.append(col)
	func body_glow(_at: Vector3, col: Color) -> void:
		seen.append(col)
	func number(_at: Vector3, _v: float, col: Color, _crit: bool, _prefix := "") -> void:
		seen.append(col)
	func word(_at: Vector3, _txt: String, col: Color, _big := false) -> void:
		seen.append(col)
	func ring(_at: Vector3, _radius: float, col: Color, _dur := 0.35) -> void:
		seen.append(col)
	func slash(_at: Vector3, _a0: float, _arc: float, _reach: float, col: Color, _heavy := false) -> void:
		seen.append(col)
	func flash(_at: Vector3, col: Color, _size := 0.35, _dur := 0.06) -> void:
		seen.append(col)
	func bolt(_a: Vector3, _b: Vector3, col: Color) -> void:
		seen.append(col)
	func cone(_at: Vector3, _d: Vector2, _length: float, col: Color) -> void:
		seen.append(col)

var ok: Callable
var ac: RefCounted

## Every colour the tables give Boki and generic damage.
func _fenced() -> Array:
	return [AbilityFx.cat_color("damage"), Feel.cat_color("damage"), KinRules.cat_color("damage")]

func _is_fenced(c: Color) -> bool:
	for f: Color in _fenced():
		if absf(c.r - f.r) < TOL and absf(c.g - f.g) < TOL and absf(c.b - f.b) < TOL:
			return true
	return false

func run(main: Node, ok_: Callable) -> void:
	ok = ok_
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	_data()
	await _chain()
	for arch: String in Arch.ids():
		await _casts(arch)

## A fenced colour written into Hunter ability data.
func _data() -> void:
	var hits: Array = []
	for dir in DATA_DIRS:
		for f in DirAccess.get_files_at("res://content/" + dir):
			if f.ends_with(".json"):
				var txt := FileAccess.get_file_as_string("res://content/%s/%s" % [dir, f]).to_lower()
				for c: Color in _fenced():
					if ("\"#" + c.to_html(false)) in txt:
						hits.append("%s/%s" % [dir, f])
	ok.call(hits.is_empty(), "no Hunter ability data names a Boki damage colour %s" % [hits])

## A Boki's shot rider that arcs on (the merge's chain) takes the shot's colour on a Hunter's shot, not damage's.
func _chain() -> void:
	var r: Array = ac.setup("gunslinger", 8.0, KIN)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var k: Kin = P.kin
	k.ks.carry_on_shot = {"chain": 1}
	var extra := {}
	P._kin_riders(extra)
	var arcs: Array = extra.get("fx_hit", [])
	var drawn := not arcs.is_empty() and not _is_fenced(Color(String(arcs[0]["color"])))
	ok.call(drawn, "a Hunter's arc-on rider is not drawn in a Boki damage colour")
	await ac.done(m)

## One Hunter's casts, alone and with a Boki to merge with.
func _casts(arch: String) -> void:
	var seen: Array = []
	for kin_sp in ["", KIN]:
		var r: Array = ac.setup(arch, 8.0, kin_sp)
		var m: Match = r[0]
		var P: Hunter = r[1]
		var spy := CatSpy.new()
		m.add_child(spy)
		m.fx = spy
		var kit: ArchKit = P.ak
		if kit != null:
			ac.tap(m, P)
			ac.step(m, SETTLE_S)
			kit.cd["rmb"] = 0.0
			ac.hold(m, P, HOLD_S)
			ac.step(m, SETTLE_S)
			kit.cd["e"] = 0.0
			kit.use_e()
			ac.step(m, SETTLE_S)
			P.ult = 1.0
			kit.use_r()
			ac.step(m, SETTLE_S)
			P.ult = 1.0
			kit.cast_ult()
			ac.step(m, SETTLE_S)
		if kin_sp != "":
			P.ult = 1.0
			ac.merge_now(P)
			ac.step(m, SETTLE_S)
		for s in m.shots:
			seen.append(s["col"])
		seen.append_array(spy.seen)
		await ac.done(m)
	var bad := seen.filter(func(c): return _is_fenced(c))
	var what := "%s: no cast of its draws a Boki damage colour (%d colours seen, %d fenced)"
	ok.call(bad.is_empty(), what % [arch, seen.size(), bad.size()])
