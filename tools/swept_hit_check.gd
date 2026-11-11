extends RefCounted
## --swept-hit-check: fast shots and dash hits must not skip a body or a wall at low frame rates. Every case
## is a real kit cast (the weapon, an ability or the dash) at a still dummy from 3 ranges, stepped at 30 and
## 144 fps: it must hit 100% of the time at both rates. Then the same casts with one thin block between
## the two at both rates: nothing gets through (Swept, scripts/combat/swept.gd).

const RANGES := [4.0, 8.0, 12.0]      # m to the dummy unless a case lists its own (a weapon or lane that is shorter)
const RATES := [30.0, 144.0]
const SECS := 2.2          # how long each cast is stepped
const WARM := 0.5          # s of idle stepping before a cast (animations settle at the new rate)

var main: Node
var n := 0
var fails := 0
var ak: RefCounted

## What each case does. fire: hold LMB; rmb: hold RMB for a while (0 = tap); e: press E;
## dash: Shift toward the dummy; no_cover: it goes through a block by design (the hook pierces terrain,
## Kael mantles one), so no cover run.
const CASES := [
	{"arch": "gunslinger", "name": "Vex rifle", "fire": 0.3},
	{"arch": "gunslinger", "name": "Vex Burr", "rmb": 0.0, "ranges": [4.0, 7.0, 10.0]},
	{"arch": "archer", "name": "Lace longbow", "fire": 1.4},
	{"arch": "archer", "name": "Lace Heavy Shot", "rmb": 1.6},
	{"arch": "rimewright", "name": "Neve darts", "fire": 0.5},
	{"arch": "rimewright", "name": "Neve Palm Lance", "rmb": 0.6},
	{"arch": "dredge", "name": "Grimble Abyssal Hand", "rmb": 0.0, "no_cover": true, "ranges": [4.0, 7.0, 10.0]},
	{"arch": "dredge", "name": "Grimble shotgun", "fire": 0.4, "ranges": [2.0, 3.5, 5.0]},
	{"arch": "thief", "name": "Sparkle Shadow Knife", "e": true},
	{"arch": "thief", "name": "Sparkle Bola", "rmb": 0.0, "ranges": [3.0, 5.0, 6.5]},
	{"arch": "mage", "name": "Motley dash", "dash": true},
	{"arch": "mage", "name": "Motley Coilshot", "rmb": 1.0},
	{"arch": "juggernaut", "name": "Kael Warchain", "e": true},
	{"arch": "juggernaut", "name": "Kael Rampage", "dash": true, "no_cover": true, "ranges": [2.0, 3.5, 5.0]},
	{"arch": "juggernaut", "name": "Kael wave", "fire": 0.3, "ranges": [3.0, 5.0, 7.0]},
	{"arch": "ostra", "name": "Sable snap", "rmb": 0.0},
	{"arch": "tender", "name": "Meeko seed", "rmb": 0.0},
	{"arch": "ashwick", "name": "Cinder bolt", "rmb": 0.0},
]

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("SWEPT %-58s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	var archs: Array = []
	for c in CASES:
		if not archs.has(c["arch"]): archs.append(c["arch"])
	_segments()
	for arch in archs:
		await _arch(String(arch))
	print("SWEPT DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Swept itself: a body between two far-apart steps is touched, one beside the path is not.
func _segments() -> void:
	var a := Vector3(0, 0, 0)
	var b := Vector3(1.4, 0, 0)       # a 40 m/s step at 30 fps
	ok("Swept.dist: a body between two steps is on the segment", Swept.dist(Vector3(0.7, 0, 0.3), a, b) < 0.31)
	ok("Swept.dist: a body beside the path is not", Swept.dist(Vector3(0.7, 0, 1.0), a, b) > 0.99)
	ok("Swept.dist: past the end it measures to the end", is_equal_approx(Swept.dist(Vector3(2.4, 0, 0), a, b), 1.0))

func _arch(arch: String) -> void:
	var cases: Array = CASES.filter(func(c): return c["arch"] == arch)
	for c in cases:
		for cover in ([false] if c.get("no_cover", false) else [false, true]):
			var hits := 0
			var total := 0
			var line := ""
			for dist in c.get("ranges", RANGES):
				for rate in RATES:
					# a fresh match per cast: no state carries from one rate to the next
					var r: Array = ak.setup(arch, dist)
					var m: Match = r[0]
					if cover:
						_block_between(m, r[4], dist)
					total += 1
					var got := _cast(m, r[1], r[2], r[4], dist, 1.0 / rate, c)
					hits += int(got)
					line += " %.0fm@%.0f:%s" % [dist, rate, "hit" if got else "miss"]
					await ak.done(m)
			var label := "%s %s" % [c["name"], "blocked by thin cover" if cover else "hits a still dummy"]
			ok(label, (hits == 0) if cover else (hits == total), line)

## One thin block tile on the lane, half way to the dummy, and the lane's neighbours so nothing slips round it.
func _block_between(m: Match, home: Vector3, dist: float) -> void:
	var w: World = m.world
	var bx := int(floor(home.x + dist * 0.5))
	for dz in range(-2, 3):
		var i: int = w.idx(bx, int(floor(home.z)) + dz)
		w.kind[i] = World.T_BLOCK

## Resets the pair, casts once and steps `secs` at `dt`. True when the dummy took damage.
func _cast(m: Match, P: Hunter, T: Hunter, home: Vector3, dist: float, dt: float, c: Dictionary) -> bool:
	P.teleport(home)
	P.vel = Vector3.ZERO
	T.teleport(home + Vector3(dist, 0, 0))
	T.vel = Vector3.ZERO
	ak.fresh(T)
	T.hp = T.max_hp
	var K: ArchKit = P.ak
	for k in K.cd: K.cd[k] = 0.0
	K.ch_rmb = 1.0
	P.dashes = P.max_dashes()
	P.ammo = 99
	m.shots.clear()
	_idle(m, WARM, dt)
	ak.aim_at(P, T.pos)
	var hold_f := float(c.get("fire", 0.0))
	var hold_r := float(c.get("rmb", -1.0))
	if c.get("e", false):
		K.use_e()
	elif c.get("dash", false):
		P.inp["dash_down"] = true
		P.do_dash()
	elif hold_r >= 0.0:
		P.inp["sec_hold"] = hold_r > 0.0
		K.press_rmb()
	var t := 0.0
	while t < SECS:
		ak.aim_at(P, T.pos)
		P.inp["fire"] = t < hold_f
		P.inp["sec_hold"] = hold_r > 0.0 and t < hold_r
		P.inp["dash_down"] = c.get("dash", false)
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(dt)
		T.vel = Vector3.ZERO
		t += dt
	for k in ["fire", "sec_hold", "dash_down"]:
		P.inp[k] = false
	return T.hp < T.max_hp

func _idle(m: Match, secs: float, dt: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(dt)
		t += dt
