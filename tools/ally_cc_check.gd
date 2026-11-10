extends RefCounted
## --ally-cc-check: a teammate stands on every spot a hero's moves land and must not be moved or gain a status.
## Each of the 12 heroes presses each slot (LMB, RMB tap and hold, E, X, dash), on the ground and in the air,
## with an ally standing on the aim line at 2, 3.5, 6 and 9 m. Pushes, pulls, knocks, swaps, roots, slows,
## stuns, Grounded, Shred, Dazed, Blight and burns all count. The source's own ally rules are the EXCEPTIONS
## (briefs/supervive-data/supervive_kits.md): Grimble's Abyssal Grasp "pulls the first target hit (enemy or ally)",
## Motley's Swap teleports "you and all units" it lands on. Tenzo's rocks are walls an ally hops (owner-decided,
## not a move); his Basalt Spine never raises a rock inside a body, so whoever stands on the line steps aside
## (a move only, no status: EXCEPTIONS with `move_only`).
## Prints ALLYCC PASS/FAIL.

const AKCheck := preload("res://tools/archetype_check.gd")
const HEROES := [
	"gunslinger", "juggernaut", "ashwick", "bulwark", "dolm", "mage",
	"ostra", "dredge", "thief", "rimewright", "tender", "archer",
]
const SLOTS := ["lmb", "rmb", "rmb_hold", "e", "x", "dash"]
const SPOTS_M := [2.0, 3.5, 6.0, 9.0]     # m ahead of the caster, along the aim line
const WATCH_S := 3.0                      # s each press is watched
const MOVED_M := 0.1                      # m: an ally that drifted this far was moved
const TOUCH_M := 0.3                      # m: closer than the two radii plus this counts as touching
const AIR_M := 3.0                        # m above the floor for the in-the-air presses
## The source's ally rules: "hero slot" -> [what the move may do to an ally, true when only a move is excused].
const EXCEPTIONS := {
	"dredge rmb": ["pulls the first target hit, enemy or ally", false],
	"dredge rmb_hold": ["pulls the first target hit, enemy or ally", false],
	"ostra dash": ["swaps you and all units at the landing spot", false],
	"dolm x": ["no rock rises inside a body: whoever is on the line steps aside", true],
}

var main: Node
var fails := 0
var n := 0

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("ALLYCC %-34s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

## A status or move on `a`, as words ("" when it is untouched). `from` is where the ally stood. When a body
## ran into it (`bumped`: a dash or lunge through it), the sideways shove of Match._separate is no ability and
## is not counted; every status still is.
static func touched(m: Match, a: Hunter, from: Vector3, bumped: bool) -> String:
	var bad: Array = []
	var sideways := Vector2(a.pos.x - from.x, a.pos.z - from.z).length() > MOVED_M and not bumped
	if sideways or absf(a.pos.y - from.y) > MOVED_M:
		bad.append("moved %.2f m to %s" % [a.pos.distance_to(from), a.pos - from])
	for k in ["stun_t", "root_t", "slow_t", "knock_t", "vuln_t", "blight_t", "burn_t"]:
		if float(a.get(k)) > 0.0:
			bad.append(k)
	for k in ["gnd_until", "rat_until", "dsr_until"]:
		if a.has_meta(k) and float(a.get_meta(k)) > float(m.time):
			bad.append(k)
	if not m.displace.towing(a).is_empty():
		bad.append("towed")
	return ", ".join(bad)

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--hero="):
			only = String(a).substr(7)
	for hero in HEROES:
		if only == "" or only == hero:
			await _hero(hero)
	print("ALLYCC DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _hero(hero: String) -> void:
	var ak := AKCheck.new()
	ak.main = main
	var leaks: Array = []
	var held := 0
	for slot in SLOTS:
		for air in [false, true]:
			var bad := await _press(ak, hero, slot, air)
			if bad == "":
				continue
			if _excused("%s %s" % [hero, slot], bad):
				held += 1
			else:
				leaks.append("%s%s: %s" % [slot, " (air)" if air else "", bad])
	var note := " [source exception used x%d]" % held if held else ""
	ok("%s: allies left alone" % hero, leaks.is_empty(), "; ".join(leaks) + note)

func _excused(key: String, bad: String) -> bool:
	return EXCEPTIONS.has(key) and (not EXCEPTIONS[key][1] or (", " not in bad and "moved" in bad))

## One press: returns what the allies suffered ("" when none).
func _press(ak: AKCheck, hero: String, slot: String, air: bool) -> String:
	var r: Array = ak.setup(hero, 9.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	r[2].teleport(r[4] + Vector3(0, 0, -9.5))      # the setup's rival dummy steps out of the line
	var allies: Array = []
	var from: Array = []
	for d in SPOTS_M:
		var at: Vector3 = r[4] + Vector3(d, 0, 0)
		var a: Hunter = m.make_hunter("Ally", p.team, "medium", "Ally", "idle", {}, at, {"arch": "none"})
		a.max_hp = 10000.0
		a.hp = a.max_hp
		a.armor = 0.0
		a.max_armor = 0.0
		allies.append(a)
	for i in 5:
		m.step(AKCheck.DT)
	for a in allies:
		from.append(a.pos)
	ak.aim_at(p, allies[1].pos)
	if air:
		p.teleport(p.pos + Vector3(0, AIR_M, 0))
	_start(ak, m, p, slot)
	var bad := ""
	var bumped: Array = [false, false, false, false]      # a body ran into this ally
	var t := 0.0
	while t < WATCH_S and bad == "":
		_hold(p, slot, t)
		ak.step(m, AKCheck.DT)
		t += AKCheck.DT
		for i in allies.size():
			for body in [p] + allies:
				if body != allies[i] and body.flat_dist(allies[i]) < body.r + allies[i].r + TOUCH_M:
					bumped[i] = true
			var s := touched(m, allies[i], from[i], bumped[i])
			if s != "":
				bad = "%.1f m ahead: %s" % [SPOTS_M[i], s]
				break
	await ak.done(m)
	return bad

func _start(ak: AKCheck, m: Match, p: Hunter, slot: String) -> void:
	match slot:
		"lmb": p.inp["fire"] = true
		"rmb": ak.tap(m, p)
		"rmb_hold":
			p.inp["sec_hold"] = true
			p.ak.press_rmb()
		"e": p.ak.use_e()
		"x":
			p.ult = 1.0
			HunterKeys.ult_pressed(p)
		"dash": p.inp["dash"] = true

## The key stays down for a while (LMB 1 s, RMB hold 0.9 s) and the dash key for one step.
func _hold(p: Hunter, slot: String, t: float) -> void:
	if slot == "lmb" and t > 1.0:
		p.inp["fire"] = false
	elif slot == "rmb_hold" and t > 0.9:
		p.inp["sec_hold"] = false
	elif slot == "dash" and t > 0.05:
		p.inp["dash"] = false
