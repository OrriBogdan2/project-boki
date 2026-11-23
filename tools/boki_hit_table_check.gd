extends RefCounted
## --boki-hit-table-check: every kit's slots (LMB, RMB tap, E, dash, X) fired at a Hunter dummy, a
## summoned Boki and a wild Boki on the archetype check's flat strip, then compared (BokiHit,
## docs/decisions/0047): a Boki takes the Hunter's damage times dmg_k, every status the Hunter got
## that the rule lets through, and a knock whenever the Hunter was knocked. The execute hits (Kael's
## Execution Slam, Lace's last ult arrow) finish a low Boki too. Then the status rules themselves: a
## stunned Boki neither walks nor bites, a rooted wild one stands, and a knock moves a Boki by 1/mass.
## The Boki gets the dummy's hit circle for the table, so a smaller body's misses don't hide the rule.
## Prints one BHT row per kit and slot (--bht-only=<kit id> runs one kit). Never touches the save.

const SLOTS := ["lmb", "rmb", "e", "dash", "x"]
const KINDS := ["hunter", "summoned", "wild"]
const SPECIES := "zapple"
const DIST := 3.0             # m from the Hunter to the target (melee swings reach it)
const WATCH := 2.5            # s a slot's hits are counted
const WATCH_X := 4.5          # s for an ultimate
const DMG_BAND := 0.25        # a Boki's total may differ by this share (a smaller body misses the odd edge pellet)
const KNOCKED := 2.0          # m/s of sideways speed that counts as a knock
const EXECUTES := {"juggernaut": "rmb", "archer": "x"}
const X_FIRES := ["archer"]   # an ult that arms the next shots (Lace's): LMB is held through its watch
const BIG_HP := 10000.0       # a target nothing finishes, so a slot's whole damage shows
const EXEC_WAIT := 4.0        # s before the execute pass, so the last slot's ultimate is over
const EXEC_HP := 300.0        # a Hunter-sized pool for the execute pass (5% left)
const KB_BAND := 0.25         # a Boki's knock speed may differ from the Hunter's / its mass by this share
const STATUS := ["stun", "root", "slow", "burn"]
const SETTLE := 6             # frames a reset target stands before the next slot
const TAIL := 0.6             # s the last slot gets to finish (a held punch lands on release)

var main: Node
var gil_bag: Array = []         # Gil's bag as first dealt, put back before each of his trials
var ak: RefCounted
var bad := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	if not cond:
		bad += 1
		print("BHT FAIL %s" % what)

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--bht-only="): only = String(arg).substr(11)
	for a in Arch.ids():
		if only != "" and a != only:
			continue
		var rows := {}
		for kind in KINDS:
			rows[kind] = await _kit(a, kind)
		_compare(a, rows)
	await _rules()
	print("BHT DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ the table
## One kit against one kind of target: {slot: {dmg, st: {status: s}, kb, done}}.
func _kit(a: String, kind: String) -> Dictionary:
	var s: Array = ak.setup(a, DIST)
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	var home: Vector3 = s[4]
	var spot := Vector3(T.pos.x, m.world.ground_at(T.pos.x, T.pos.z), T.pos.z)
	var tgt: Ent = T
	if T.kin:      # the dummy's own Boki would be a second foe beside it (Sable's Bola tangles two)
		var o: Kin = T.kin
		o.dead = true
		m.kins.erase(o)
		o.queue_free()
		T.kin = null
	if kind != "hunter":
		var rec := Save.new_kin(SPECIES)
		if kind == "summoned":
			tgt = m.give_kin(T, rec)
			T.teleport(spot + Vector3(0, 0, 8.0))      # its Hunter off to the side, out of every slot's reach
		else:
			tgt = m.spawn_wild(rec, spot)
			T.teleport(m.world.random_ground())
		tgt.r = T.r      # the dummy's hit circle, so only the rule differs (the mass stays the Boki's)
	P.ak.cd_off = true
	var out := {}
	for slot in SLOTS:
		out[slot] = await _fire(m, P, tgt, home, spot, slot, 1.0)
	if EXECUTES.has(a):      # last (it leaves the dummy down), once the ultimate has run out
		ak.step(m, EXEC_WAIT)
		out["execute"] = await _fire(m, P, tgt, home, spot, String(EXECUTES[a]), 0.05)
	await ak.done(m)
	return out

func _reset(m: Match, P: Hunter, t: Ent, home: Vector3, spot: Vector3, hp_k: float) -> void:
	P.inp["fire"] = false
	_still(t)      # (a summoned Boki would bite its foe in the first tail steps, staggering Cinder's hose)
	ak.step(m, TAIL)
	for w in m.verbs.walls.duplicate():      # the last slot's rocks and walls go, so each slot starts clean
		if w.get("by") == P: m.verbs._break_wall(w)
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.ult = 1.0
	P.dashes = P.max_dashes()
	t.max_hp = BIG_HP if hp_k >= 1.0 else EXEC_HP
	t.hp = t.max_hp * hp_k
	for st in STATUS:
		t.set(st + "_t", 0.0)
	t.cc_immune_t = 0.0
	t.dr = {}
	t.dr_stun = false
	t.set_meta("marks", {})
	t.teleport(spot)
	t.vel = Vector3.ZERO
	if t is Kin:
		(t as Kin).state = "wild" if (t as Kin).is_wild() else "active"
		(t as Kin).shield = 0.0
	if P.ak is GilKit:      # (Gil's bag is shuffled: every trial throws the same next potion)
		if gil_bag.is_empty(): gil_bag = (P.ak as GilKit).bag.duplicate()
		(P.ak as GilKit).bag = gil_bag.duplicate()
	ak.aim_at(P, spot)
	for i in SETTLE:      # both feet down again (a dummy left in the air takes Tenzo's Dunk)
		_still(t)
		m.step(ak.DT)

## Fires one slot at `t` and watches: damage, the statuses it carried, the sideways speed, finished.
func _fire(m: Match, P: Hunter, t: Ent, home: Vector3, spot: Vector3, slot: String, hp_k: float) -> Dictionary:
	_reset(m, P, t, home, spot, hp_k)
	var hp0 := t.hp
	var r := {"dmg": 0.0, "st": {}, "kb": 0.0, "done": false, "mass": t.mass()}
	# statuses a hit carried (a Hunter's own stagger slow, Oomph.react, is not a kit's and isn't counted)
	var seen := func(e: Node, st: String, _by: Node, secs: float) -> void:
		if e == t: r["st"][st] = maxf(float(r["st"].get(st, 0.0)), secs)
	CombatBus.status_applied.connect(seen)
	match slot:
		"rmb": ak.tap(m, P)
		"e": P.ak.use_e()
		"dash": P.inp["dash"] = true
		"x": HunterKeys.ult_pressed(P)
	var secs := WATCH_X if slot == "x" else WATCH
	var tt := 0.0
	while tt < secs:
		var shoot := (slot == "lmb" and tt < 1.0) or (slot == "x" and X_FIRES.has(P.ak.id))
		if shoot: P.inp["fire"] = true
		ak.aim_at(P, t.pos)
		_still(t)
		for mb in m.mobs: mb.queue_free()      # (a monster wandering into a fan would take its slugs)
		m.mobs.clear()
		m.step(ak.DT)
		tt += ak.DT
		t.pos.x = spot.x      # held on its spot: hits don't hang on how far each body drifts (speed shows the knock)
		t.pos.z = spot.z
		r["kb"] = maxf(float(r["kb"]), Vector2(t.vel.x, t.vel.z).length())
	P.inp["fire"] = false
	CombatBus.status_applied.disconnect(seen)
	r["dmg"] = hp0 - t.hp
	r["done"] = _finished(t)
	return r

## Out of the fight: dead, downed, or (a wild Boki) dazed.
func _finished(t: Ent) -> bool:
	if t.dead or t.hp <= 0.0:
		return true
	if t is Kin:
		return (t as Kin).state in ["dazed", "downed"]
	return (t as Hunter).downed

## Keeps a target from walking or biting on its own (knocks and tows still move it).
func _still(t: Ent) -> void:
	if t is Kin:
		var k := t as Kin
		k.speed = 0.0
		k.atk_cd = 9.0
		k.angry_at = null
		if k.brain: k.brain.think_t = 1e9
	elif t is Hunter:
		(t as Hunter).ctrl = "idle"

func _compare(a: String, rows: Dictionary) -> void:
	var slots: Array = SLOTS.duplicate()
	if EXECUTES.has(a): slots.append("execute")
	var cc: Array = BokiHit.rules().get("cc", BokiHit.CC)
	for slot in slots:
		var hr: Dictionary = rows["hunter"][slot]
		var line := "BHT %-10s %-7s" % [a, slot]
		for kind in KINDS:
			var r: Dictionary = rows[kind][slot]
			var tags := ",".join(r["st"].keys()) + (" DONE" if r["done"] else "")
			line += " | %-8s %6.0f kb%4.1f %s" % [kind, r["dmg"], r["kb"], tags]
		print(line)
		for kind in ["summoned", "wild"]:
			var r: Dictionary = rows[kind][slot]
			var what := "%s %s on a %s Boki" % [a, slot, kind]
			if slot == "execute":
				ok(r["done"] == hr["done"], "%s: finished %s, the Hunter %s" % [what, r["done"], hr["done"]])
				continue
			var k := float(BokiHit.rules()["dmg_k"][kind])
			var want := float(hr["dmg"]) * k
			var near := absf(float(r["dmg"]) - want) <= maxf(2.0, want * DMG_BAND)
			ok(near, "%s: %.0f dmg, want %.0f (Hunter %.0f x %.2f)" % [what, r["dmg"], want, hr["dmg"], k])
			for st in hr["st"].keys():
				if cc.has(st):
					ok(r["st"].has(st), "%s: the Hunter got %s, the Boki didn't" % [what, st])
			if float(hr["kb"]) > KNOCKED:
				var why := "%s: the Hunter was knocked (%.1f m/s), the Boki %.1f" % [what, hr["kb"], r["kb"]]
				ok(float(r["kb"]) > KNOCKED, why)
				var kb_want := float(hr["kb"]) * float(hr["mass"]) / float(r["mass"])
				var kb_near := absf(float(r["kb"]) - kb_want) <= kb_want * KB_BAND
				var kb_why := "%s: knocked %.1f m/s, want %.1f (Hunter's x mass %.2f / %.2f)"
				ok(kb_near, kb_why % [what, r["kb"], kb_want, hr["mass"], r["mass"]])

# ------------------------------------------------------------------ the status rules
func _rules() -> void:
	var s: Array = ak.setup("gunslinger", DIST)
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	var sb: Kin = m.give_kin(T, Save.new_kin(SPECIES))
	sb.teleport(P.pos + Vector3(1.0, 0, 0))
	sb.target = P
	sb.atk_cd = 0.0
	sb.stun_t = 1.0
	var hp0 := P.hp
	var at := sb.pos
	ak.step(m, 0.5)
	var moved := sb.flat_dist(at)
	var still := "a stunned summoned Boki neither bites nor walks (hp %.0f->%.0f, moved %.2f)" % [hp0, P.hp, moved]
	ok(P.hp >= hp0 and moved < 0.05, still)
	var w: Kin = m.spawn_wild(Save.new_kin(SPECIES), P.pos + Vector3(4.0, 0, 0))
	w.angry_at = P
	w.root_t = 1.0
	at = w.pos
	ak.step(m, 0.4)
	ok(w.flat_dist(at) < 0.05, "a rooted wild Boki stands (moved %.2f)" % w.flat_dist(at))
	w.root_t = 0.0
	w.teleport(at)
	w.vel = Vector3.ZERO
	var kb := Vector2(6.0, 0.0)
	w.hurt(1.0, P, {"kb": kb})
	var want := kb.x / w.mass()
	var said := "a knock moves a Boki by 1/mass: %.2f m/s, want %.2f (mass %.2f)" % [w.vel.x, want, w.mass()]
	ok(absf(w.vel.x - want) < 0.01, said)
	await ak.done(m)
