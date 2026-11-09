class_name Lairs
extends RefCounted
## Boss lairs: walled arenas on the islands, each sealed by a gate, holding a boss (see Boss) and the
## Rare Egg it guards. Every expedition map has at least one (Skyreach has three).
##
## Getting in, after SUPERVIVE's vault locks:
##  - The dial (every lair). A ring dial on a stone lectern at the gate, a needle sweeping round it and
##    a few lit arcs. Press interact (or click, or the pad's A) as the needle passes through each arc;
##    light them all and that lock opens. Each gate has three or four locks, and each lock's arcs are
##    smaller and its needle faster. A miss resets the lock you're on and rings a loud chime: it pings
##    you to everyone nearby, shows you through grass for a moment, and calls up a few guards.
##    Everyone near can see the dial turning over the lectern and who's working it.
##  - Rune pylons (Stormcrown Eyrie). Hold interact at three pylons round the lair to light them; each
##    one lit brings guards. All three lit and the seal breaks.
##  - Ward stones (the Thornhive). Three ward stones stand round it; hitting one calls its guards out,
##    breaking all three breaks the seal.
## While sealed, a ward of light over the walls keeps everyone out (gliding in bounces off). Once open,
## the boss sleeps and you can walk in and out as you like. Step in past the threshold and it wakes:
## the gate's bars slam down and the ward lights up again, like a raid. Everyone inside is sealed in
## with it (nobody gets out, nobody crashes in) until the boss dies, everyone inside is down (it heals
## and goes back to sleep), or LOCK_T (90 s) runs out (the seal fails and it resets).
## The fight is loud: everyone within ALERT_R hears the boss roar, gets a ping with the boss's icon on
## the minimap and the full map, sees a shaft of light over the lair, and the seal's clock floats over
## the gate for anyone outside to read. So a squad outside has a choice: camp the gate, or move on.
## The kill doesn't open the gate straight away. It stays shut for VICTORY_T (20 s) unless someone
## inside pulls the lever by the gate; meanwhile an updraft blows at the back of the lair that only
## those who fought can ride, up over the wall and away on the glider from a side the campers aren't
## watching. It dies down when the gate opens. Everyone near hears the boss fall, so campers know the
## clock is running.
## The boss drops a Rare Egg (a backpack item, see Loot.rare_egg) shown on everyone's minimap for a
## few seconds, plus a strong weapon, a glove, treasure and XP.

const DIAL_R := 1.8            # reach to work the dial
const LOCKS := {"colossus": 4, "serpent": 3, "brood": 3}
const SPEEDS := [1.7, 2.25, 2.8, 3.4]      # the needle's speed per lock (radians a second)
const WIDTHS := [0.95, 0.74, 0.58, 0.46]   # each lit arc's width per lock (radians)
const TARGETS := [2, 2, 3, 3]              # lit arcs per lock
const SLACK := 0.05            # a hair of forgiveness either side of an arc
const JAM_T := 0.7             # after a miss the dial is jammed this long
const GRACE_T := 0.3           # the press that starts the dial doesn't count as a stop
const GUARD_CAP := 6           # guards a lair can have out at once
const RUNE_HOLD := 2.2
const EGG_PING_T := 8.0        # the dropped egg shows on everyone's minimap this long
const EGG_APART := 4.5         # a boss's Rare Egg lands this far from its loot pile, on a spot of its own
const CARRY_PING_T := 5.0      # ... and so does whoever picks it up
const LOCK_T := 90.0           # the longest a fight can keep you sealed in
const VICTORY_T := 20.0        # after the kill the gate stays shut this long unless the lever is pulled (so campers at the gate wait it out)
const LEVER_R := 1.7           # reach to pull the gate lever
const ALERT_R := 150.0         # everyone this close hears a lair fight start (and its boss fall)
const UP_R := 1.5              # the escape updraft's radius
const UP_TOP := 9.0            # ... and how high over the lair floor it carries you
const UP_PUSH := 8.0           # ... and how hard it throws you out over the wall at the top
const SPRITE := {"colossus": Color("ffb04a"), "serpent": Color("7fe8ff"), "brood": Color("b6ff6a")}

var m: Match
var list: Array = []
var egg_pings: Array = []      # {pos, until, follow: Hunter or null, text}
var _prev := {}                # hunter nid -> was interact held last tick
var _told := {}
var music_on := false
var press_log: Array = []      # tests: every stop attempt {lair, ok, lock}
var alert_log: Array = []      # tests: every outside alert {lair, kind: fight|fallen, nid}

func setup(match_node: Match) -> void:
	m = match_node
	if m.opts.get("training", false) or m.opts.get("duel", false) or m.opts.get("tutorial", false) or m.opts.get("sandbox", false):
		return
	for D in m.world.lair_defs:
		_add(D)

static func color_of(L: Dictionary) -> Color:
	return SPRITE.get(String(L.get("boss", "")), Color("ffd36a"))

func boss_name(L: Dictionary) -> String:
	return String(Data.MOBS.get(String(L["boss"]), {}).get("name", "the boss"))

# ------------------------------------------------------------------ building a lair
func _add(D: Dictionary) -> void:
	var w := m.world
	var c2: Vector2 = D["c"]
	var c := Vector3(c2.x, float(D["y"]), c2.y)
	var hf := int(D["half"])
	var out: Vector2 = D["out"]
	var col: Color = SPRITE.get(String(D["boss"]), Color("ffd36a"))
	var gate_c := c + Vector3(out.x, 0, out.y) * hf
	var dial := c + Vector3(out.x, 0, out.y) * (hf + 2.6)
	dial = Vector3(dial.x, w.ground_at(dial.x, dial.z), dial.z) if not w.is_void(dial.x, dial.z) else gate_c + Vector3(out.x, 0, out.y) * 1.6
	var L := {"i": list.size(), "id": D["id"], "name": D["name"], "boss": String(D["boss"]), "c": c, "half": hf, "out": out,
		"gate_tiles": D["gate_tiles"], "gate_c": gate_c, "dial": dial, "entry": D.get("entry", ["dial"]), "state": "dormant",
		"locks": int(LOCKS.get(String(D["boss"]), 3)), "lock": 0, "targets": [], "needle": randf() * TAU, "dir": 1.0, "active": false,
		"user": null, "jam": 0.0, "grace": 0.0, "fails": 0, "boss_mob": null, "adds": [], "guards": [], "runes": [], "wards": [],
		"gate_k": 0.0, "opened_by": "", "woke_at": -1.0, "bot_ti": -1, "bot_roll": false, "bot_wait": 0.0, "egg_wp": null, "egg_told": false}
	list.append(L)
	for q in D["gate_tiles"]:
		w.kind[w.idx(q.x, q.y)] = World.T_BLOCK
	# the gate across the gap, the seal over the walls, the dial at the gate
	var gate := BossModels.gate(3.0, col)
	gate.position = Vector3(floor(gate_c.x) + 0.5, c.y, floor(gate_c.z) + 0.5)
	gate.rotation.y = 0.0 if out.x == 0.0 else PI * 0.5
	m.add_child(gate)
	var dome := BossModels.dome(float(hf) + 0.5, col)
	dome.position = c + Vector3(0, 0.02, 0)
	m.add_child(dome)
	var dn := BossModels.dial_stone(col)
	Flora.paint_set_piece(gate)
	Flora.paint_set_piece(dn)
	dn.position = dial
	dn.rotation.y = atan2(out.x, out.y)
	m.add_child(dn)
	var lbl := Label3D.new()
	lbl.font = UI.big; lbl.font_size = 40; lbl.pixel_size = 0.01; lbl.outline_size = 12
	lbl.modulate = col.lightened(0.3); lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lbl.no_depth_test = true
	lbl.position = gate.position + Vector3(0, 4.6, 0)
	lbl.text = "%s\nDormant  ·  its gate rusted shut" % L["name"]
	lbl.modulate = Color(0.7, 0.7, 0.75)
	m.add_child(lbl)
	# inside, beside the gate: the lever that opens it after the kill; at the back, the vent the
	# escape updraft rises from, and the spot beyond the wall it carries you toward
	var side := Vector2(-out.y, out.x)
	var lv_at := c + Vector3(out.x, 0, out.y) * (float(hf) - 1.5) + Vector3(side.x, 0, side.y) * 2.6
	lv_at.y = w.ground_at(lv_at.x, lv_at.z) if not w.is_void(lv_at.x, lv_at.z) else c.y
	var lvn := BossModels.lever(col)
	Flora.paint_set_piece(lvn)
	lvn.position = lv_at
	lvn.scale = Vector3.ONE * 1.2
	lvn.rotation.y = atan2(-out.x, -out.y)
	m.add_child(lvn)
	var up_at := c - Vector3(out.x, 0, out.y) * (float(hf) - 2.3)
	up_at.y = c.y
	var vn := BossModels.vent(col, UP_R, UP_TOP + 3.0)
	vn.position = up_at
	m.add_child(vn)
	var beam := BossModels.alert_beam(col, float(hf))
	beam.position = c
	beam.visible = false
	m.add_child(beam)
	L["lever"] = lv_at
	L["up"] = up_at
	L["up_land"] = _escape_spot(c, hf, out)
	L["victory"] = false
	L["flown"] = []
	L["heard"] = {}
	L["nodes"] = {"gate": gate, "dome": dome, "dial": dn, "label": lbl, "lever": lvn, "vent": vn, "beam": beam}
	L["col"] = col
	# lairs stay dormant (empty, sealed for good) until SpawnPlan rolls them live: see plug_into
	_tint_dormant(L, true)

## Where the escape updraft throws you: open ground just beyond the back wall (or failing that one of
## the side walls), never the gate side. Out over the abyss if there's no ground there at all.
func _escape_spot(c: Vector3, hf: int, out: Vector2) -> Vector3:
	var w := m.world
	for dv in [-out, Vector2(-out.y, out.x), Vector2(out.y, -out.x)]:
		var d: Vector2 = dv
		for dist in [3.5, 5.0, 6.5, 8.0, 10.0]:
			for slide in [0.0, 2.0, -2.0, 4.0, -4.0]:
				var p: Vector3 = c + Vector3(d.x, 0, d.y) * (float(hf) + float(dist)) + Vector3(-d.y, 0, d.x) * float(slide)
				if w.is_void(p.x, p.z) or w.is_block(p.x, p.z) or w.lair_at(p.x, p.z, 1.5) >= 0 or w.edge_dist(int(p.x), int(p.z), 2) < 2:
					continue
				return Vector3(floor(p.x) + 0.5, w.ground_at(p.x, p.z), floor(p.z) + 0.5)
	var far := c - Vector3(out.x, 0, out.y) * (float(hf) + 6.0)
	return Vector3(far.x, c.y, far.z)

## A dormant lair: its seal greyed out, its dial dark. A live one glows its boss's colour.
func _tint_dormant(L: Dictionary, dormant: bool) -> void:
	var dome: Node3D = L["nodes"]["dome"]
	var sh: MeshInstance3D = dome.get_node("Shell")
	var col: Color = L["col"] if not dormant else Color(0.6, 0.62, 0.68)
	(sh.material_override as StandardMaterial3D).albedo_color = Color(col, 0.10 if not dormant else 0.05)
	(dome.get_node("Rim") as MeshInstance3D).visible = not dormant
	(L["nodes"]["dial"] as Node3D).get_node("Ring").visible = not dormant

## SpawnPlan decides which lairs are live this match: every lair is a "boss" candidate; the rolled ones
## get their boss, guards and wards (see activate), the others stay dormant. Skyreach rolls 2 or 3 of its
## 3 lairs (the layout's spawn_points.boss), generated maps 1 or 2 of theirs.
func plug_into(plan: SpawnPlan) -> void:
	if list.is_empty() or plan == null:
		return
	if plan.of("boss").is_empty():
		for L in list:
			plan.add_candidate("boss", L["c"], String(L["name"]))
		plan.register("boss", {"pick": [1, list.size()]})
	plan.set_spawner("boss", func(_p, cand): return activate_near(cand["pos"]),
		func(cand): return String(_near(cand["pos"]).get("state", "")) == "cleared")
	plugged = true

var plugged := false

func _near(p: Vector3) -> Dictionary:
	var best := {}; var bd := 1e9
	for L in list:
		var d := Vector2(p.x - float(L["c"].x), p.z - float(L["c"].z)).length()
		if d < bd: bd = d; best = L
	return best if bd < 6.0 else {}

func activate_near(p: Vector3) -> Dictionary:
	var L := _near(p)
	if not L.is_empty(): activate(L)
	return L

## Without a spawn plan (tests, odd modes) every lair is live.
func ensure_live() -> void:
	if not plugged:
		for L in list: activate(L)

## Wakes a lair up for this match: its boss asleep in the middle, guards at the gate, and its other way in.
func activate(L: Dictionary) -> void:
	if L["active"]:
		return
	L["active"] = true
	L["state"] = "sealed"
	_tint_dormant(L, false)
	var lbl: Label3D = L["nodes"]["label"]
	lbl.text = "%s\nSealed" % L["name"]
	lbl.modulate = (L["col"] as Color).lightened(0.3)
	if m.net_on and not m.is_host:
		return
	var w := m.world
	var c: Vector3 = L["c"]; var hf := int(L["half"]); var out: Vector2 = L["out"]; var dial: Vector3 = L["dial"]
	var col: Color = L["col"]
	var D := {"boss": L["boss"], "entry": L["entry"]}
	# the boss, asleep in the middle
	var b := Boss.new()
	b.init_boss(m, m.next_id("b"), String(D["boss"]), c, float(m.T.get("mob", 1.0)) if not m.T.is_empty() else 1.0, L)
	m.add_child(b)
	m.mobs.append(b)
	m.ents_by_id[b.nid] = b
	b.face = atan2(-out.x, -out.y)
	L["boss_mob"] = b
	# guards camped outside the gate: fight through them to get to the dial
	for i in 3 + mini(int(m.tier), 1):
		var gk: String = ["skitter", "spitter", "bomber", "brute" if m.tier >= 1 else "skitter"][i % 4]
		var gp := dial + Vector3(out.x, 0, out.y) * 2.5 + Vector3(-out.y, 0, out.x) * (i - 1.5) * 1.6
		if w.is_void(gp.x, gp.z): gp = dial + Vector3(-out.y, 0, out.x) * (i - 1.5) * 1.4
		var g := m.spawn_mob(gk, Vector3(gp.x, w.ground_at(gp.x, gp.z), gp.z))
		g.camp = dial + Vector3(out.x, 0, out.y) * 2.0
		L["guards"].append(g)
	# the other ways in, round the walls on the three sides away from the gate
	var sides: Array = [Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)].filter(func(s): return s != out)
	if (L["entry"] as Array).has("runes"):
		for s in sides:
			var at := _round_spot(c, hf, s)
			if at == Vector3.INF: continue
			var rn := BossModels.rune_pylon(col)
			rn.position = at
			m.add_child(rn)
			L["runes"].append({"pos": at, "lit": false, "prog": 0.0, "held": 0.0, "node": rn})
	if (L["entry"] as Array).has("wards"):
		for s in sides:
			var at := _round_spot(c, hf, s)
			if at == Vector3.INF: continue
			var wd := m.spawn_mob("ward", at)
			wd.camp = at
			wd.set_meta("lair", L["i"])
			L["wards"].append(wd)

## A spot just outside the middle of one wall, on open ground (INF if there's none).
func _round_spot(c: Vector3, hf: int, s: Vector2) -> Vector3:
	var w := m.world
	for dist in [3.2, 2.4, 4.2]:
		for slide in [0.0, 2.5, -2.5, 4.5, -4.5]:
			var p: Vector3 = c + Vector3(s.x, 0, s.y) * (float(hf) + float(dist)) + Vector3(-s.y, 0, s.x) * float(slide)
			if not w.is_void(p.x, p.z) and not w.is_block(p.x, p.z) and w.edge_dist(int(p.x), int(p.z), 2) >= 2:
				return Vector3(floor(p.x) + 0.5, w.ground_at(p.x, p.z), floor(p.z) + 0.5)
	return Vector3.INF

# ------------------------------------------------------------------ queries
func inside(L: Dictionary, p: Vector3, pad := 0.0) -> bool:
	var c: Vector3 = L["c"]
	var hf := float(L["half"]) - 0.5 + pad
	return absf(p.x - c.x) <= hf and absf(p.z - c.z) <= hf

func lair_of(p: Vector3, pad := 0.0) -> Dictionary:
	for L in list:
		if inside(L, p, pad): return L
	return {}

## The lair's boss, or null once it's gone (or was never spawned here).
func boss_of(L: Dictionary) -> Boss:
	var b = L.get("boss_mob")
	if b == null or not is_instance_valid(b):
		return null
	return b as Boss

## The lair whose dial this hunter is working, or {}.
func puzzle_of(h: Hunter) -> Dictionary:
	for L in list:
		if is_same(L["user"], h): return L
	return {}

## The awake boss the local player is fighting (inside its lair, or right by it), or null.
func boss_for(p: Hunter) -> Boss:
	if p == null:
		return null
	for L in list:
		var b: Boss = boss_of(L)
		if b and is_instance_valid(b) and not b.dead and not b.dormant and inside(L, p.pos, 4.0):
			return b
	return null

func adds_alive(L: Dictionary) -> int:
	L["adds"] = (L["adds"] as Array).filter(func(x): return is_instance_valid(x) and not x.dead)
	return (L["adds"] as Array).size()

func _guards_alive(L: Dictionary) -> int:
	L["guards"] = (L["guards"] as Array).filter(func(x): return is_instance_valid(x) and not x.dead)
	return (L["guards"] as Array).size()

## What the minimap shows: sealed, open, the boss awake, cleared.
func icon_state(L: Dictionary) -> String:
	return String(L["state"])

# ------------------------------------------------------------------ interact
func interact_for(h: Hunter) -> Dictionary:
	var k := Settings.key_cap("interact")
	for L in list:
		if can_pull(L, h):
			return {"kind": "lair", "what": "lever", "lair": L, "act": true, "col": color_of(L), "label": "%s: Open the gate" % k}
	for L in list:
		if L["state"] != "sealed":
			continue
		if h.flat_dist(L["dial"]) < DIAL_R and absf(h.pos.y - float(L["dial"].y)) < 1.5 and (L["entry"] as Array).has("dial"):
			var u = L["user"]
			if is_same(u, h):
				return {"kind": "lair", "what": "dial", "lair": L, "act": true, "col": color_of(L),
					"label": "Press %s as the needle crosses a lit arc  ·  lock %d of %d" % [k, int(L["lock"]) + 1, int(L["locks"])]}
			if u != null:
				return {"kind": "lair", "what": "busy", "lair": L, "act": true, "col": color_of(L), "label": "%s is working the lock" % (u as Hunter).pname}
			return {"kind": "lair", "what": "dial", "lair": L, "act": true, "col": color_of(L),
				"label": "Press %s to work the lock of %s  ·  a miss rings a chime" % [k, L["name"]]}
		for rn in L["runes"]:
			if not rn["lit"] and h.flat_dist(rn["pos"]) < 1.7 and absf(h.pos.y - float(rn["pos"].y)) < 1.5:
				var lit: int = (L["runes"] as Array).filter(func(x): return x["lit"]).size()
				return {"kind": "lair", "what": "rune", "lair": L, "rune": rn, "act": true, "col": color_of(L),
					"label": "Hold %s to light the rune  (%d of %d lit)  ·  guards will come" % [k, lit, (L["runes"] as Array).size()]}
	return {}

## Can this hunter pull the lair's gate lever right now? (After the kill, from inside, standing at it.)
func can_pull(L: Dictionary, h: Hunter) -> bool:
	return L.get("victory", false) and not h.downed and not h.out and h.flat_dist(L["lever"]) < LEVER_R \
		and absf(h.pos.y - float(L["lever"].y)) < 1.5 and inside(L, h.pos, 0.0)

## Holding interact on something a lair offers (runes; the dial takes presses, see _tick_dial).
func hold(h: Hunter, it: Dictionary, dt: float) -> void:
	if String(it.get("what", "")) != "rune":
		return
	var rn: Dictionary = it["rune"]
	if m.time - h.hurt_at < 0.1:
		rn["prog"] = 0.0
	rn["prog"] = float(rn["prog"]) + dt / RUNE_HOLD
	rn["held"] = m.time
	if float(rn["prog"]) >= 1.0:
		_light_rune(it["lair"], rn, h)

func _light_rune(L: Dictionary, rn: Dictionary, h: Hunter) -> void:
	rn["lit"] = true
	rn["prog"] = 1.0
	var n: Node3D = rn["node"]
	if is_instance_valid(n): n.get_node("Lit").visible = true
	m.sfx("unlock", rn["pos"], 2.0, 1.2)
	m.fx.burst(rn["pos"] + Vector3(0, 1.4, 0), color_of(L), 24, 4.0, 0.6, -2.0)
	_loud(L, rn["pos"], h, "A rune flares at %s" % L["name"])
	_call_guards(L, rn["pos"], 2)
	var lit: int = (L["runes"] as Array).filter(func(x): return x["lit"]).size()
	if lit >= (L["runes"] as Array).size():
		open(L, h, "runes")
	elif h == m.player and m.hud:
		m.hud.toast("Rune %d of %d lit" % [lit, (L["runes"] as Array).size()], color_of(L))

# ------------------------------------------------------------------ the dial
func _new_lock(L: Dictionary) -> void:
	var li := clampi(int(L["lock"]), 0, SPEEDS.size() - 1)
	var n: int = TARGETS[li]
	var wd: float = WIDTHS[li]
	var arcs: Array = []
	var needle := float(L["needle"])
	var dirn := float(L["dir"])
	var tries := 0
	while arcs.size() < n and tries < 200:
		tries += 1
		# never right on top of the needle: the first arc is at least a little way ahead of it
		var a := needle + dirn * randf_range(0.9, TAU - 0.6)
		var ok := true
		for t in arcs:
			if absf(wrapf(a - float(t["a"]), -PI, PI)) < wd + 0.55: ok = false; break
		if ok: arcs.append({"a": wrapf(a, -PI, PI), "w": wd, "hit": false})
	L["targets"] = arcs
	L["bot_ti"] = -1

func speed_of(L: Dictionary) -> float:
	return SPEEDS[clampi(int(L["lock"]), 0, SPEEDS.size() - 1)]

## Which unlit arc the needle is in now (-1 for none).
func target_under(L: Dictionary) -> int:
	var nd := float(L["needle"])
	var ts: Array = L["targets"]
	for i in ts.size():
		if ts[i]["hit"]: continue
		if absf(wrapf(nd - float(ts[i]["a"]), -PI, PI)) <= float(ts[i]["w"]) * 0.5 + SLACK:
			return i
	return -1

func _start_dial(L: Dictionary, h: Hunter) -> void:
	L["user"] = h
	L["grace"] = GRACE_T
	if (L["targets"] as Array).is_empty():
		_new_lock(L)
	m.sfx("click", L["dial"], 0.0, 0.8)
	# (no toast: the dial panel and the interact prompt both say how already; a third copy sat on your health bar)

func _stop_dial(L: Dictionary) -> void:
	L["user"] = null
	# the lock you were on resets when you walk away; the locks you opened stay open
	for t in L["targets"]: t["hit"] = false

## One press: hit the arc under the needle, or miss.
func press(L: Dictionary, h: Hunter) -> bool:
	if float(L["jam"]) > 0.0 or float(L["grace"]) > 0.0:
		return false
	var ti := target_under(L)
	press_log.append({"lair": L["id"], "ok": ti >= 0, "lock": int(L["lock"])})
	if ti < 0:
		_miss(L, h)
		return false
	L["targets"][ti]["hit"] = true
	m.sfx("ping", L["dial"], 0.0, 1.0 + 0.15 * (L["targets"] as Array).filter(func(t): return t["hit"]).size())
	m.fx.burst(L["dial"] + Vector3(0, 1.4, 0), color_of(L), 10, 2.5, 0.35, -1.0)
	if (L["targets"] as Array).all(func(t): return t["hit"]):
		L["lock"] = int(L["lock"]) + 1
		m.sfx("unlock", L["dial"], 0.0, 0.9 + 0.1 * int(L["lock"]))
		m.fx.burst(L["dial"] + Vector3(0, 1.5, 0), Color("fff4c0"), 22, 4.0, 0.5, -2.0)
		if int(L["lock"]) >= int(L["locks"]):
			open(L, h, "dial")
		else:
			L["dir"] = -float(L["dir"])
			_new_lock(L)
			if h == m.player and m.hud:
				m.hud.toast("LOCK %d OF %d OPEN" % [int(L["lock"]), int(L["locks"])], color_of(L))
	return true

func _miss(L: Dictionary, h: Hunter) -> void:
	L["fails"] = int(L["fails"]) + 1
	L["jam"] = JAM_T
	_new_lock(L)
	# a loud chime: everyone near hears where you are, you show through grass, and guards come
	m.sfx("warn", L["dial"], 6.0, 1.7)
	m.sfx("horn", L["dial"], -4.0, 1.6)
	m.fx.ring(L["dial"], 4.0, Color("ff6a5a"), 0.5)
	h.reveal_t = maxf(h.reveal_t, 3.0)
	_loud(L, L["dial"], h, "A lock chime rings out at %s" % L["name"])
	_call_guards(L, L["dial"], 2 + mini(int(m.tier), 1))
	if h == m.player and m.hud:
		m.hud.toast("MISSED  ·  the lock resets and the chime calls guards", Color("ff8a6a"))

## Something loud happened at a lair: a ping and a feed line for everyone close enough to hear it, a
## sound ping on the minimap, and nearby bots come and look.
func _loud(L: Dictionary, at: Vector3, by: Hunter, text: String) -> void:
	m.note_sound(by, at, "boom")
	for o in m.hunters:
		if o.out or o.extracted or o == by:
			continue
		var d: float = o.flat_dist(at)
		if d > 60.0:
			continue
		if o == m.player:
			m.ping(at, color_of(L))
			m.add_feed(text)
		elif o.ctrl == "bot" and o.team != by.team and d < 45.0 and randf() < 0.35:
			o.ai["wander"] = at

func _call_guards(L: Dictionary, at: Vector3, n: int) -> void:
	if m.net_on and not m.is_host:
		return
	var room := GUARD_CAP - _guards_alive(L)
	var pool: Array = ["skitter", "skitter", "spitter", "bomber"] + (["brute"] if m.tier >= 1 else [])
	for i in mini(n, room):
		var a := randf() * TAU
		var p: Vector3 = at + Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 4.5)
		if m.world.is_void(p.x, p.z) or m.world.is_block(p.x, p.z) or inside(L, p, 0.5):
			p = at + Vector3(L["out"].x, 0, L["out"].y) * 2.5
		var g := m.spawn_mob(String(pool[randi() % pool.size()]), Vector3(p.x, m.world.ground_at(p.x, p.z), p.z))
		g.camp = at
		g.st = "chase"
		g.tgt = L["user"] if L["user"] != null else null
		m.fx.burst(g.pos + Vector3(0, 0.5, 0), Color("c9a0ff"), 14, 3.0, 0.5, -2.0)
		L["guards"].append(g)

func _tick_dial(L: Dictionary, dt: float) -> void:
	if L["state"] != "sealed" or not (L["entry"] as Array).has("dial"):
		return
	var u = L["user"]
	if u != null:
		var h: Hunter = u
		if h.out or h.downed or h.extracted or not is_instance_valid(h) or h.flat_dist(L["dial"]) > DIAL_R + 1.3:
			_stop_dial(L)
			return
		h.set_hold("dial")
		L["needle"] = wrapf(float(L["needle"]) + float(L["dir"]) * speed_of(L) * dt, -PI, PI)
		L["jam"] = maxf(0.0, float(L["jam"]) - dt)
		L["grace"] = maxf(0.0, float(L["grace"]) - dt)
		if h.ctrl == "bot" and not h.remote:
			_bot_dial(L, h, dt)
		elif _pressed(h):
			press(L, h)
		return
	# nobody on it: the first press from someone standing at the dial starts it
	for h in m.hunters:
		if h.out or h.downed or h.extracted or h.dropping:
			continue
		if h.flat_dist(L["dial"]) < DIAL_R and absf(h.pos.y - float(L["dial"].y)) < 1.5 and _pressed(h):
			_start_dial(L, h)
			return

func _pressed(h: Hunter) -> bool:
	return bool(h.inp.get("interact", false)) and not bool(_prev.get(h.nid, false))

## Bots work the dial too: as the needle enters a lit arc they either catch it (more often the better
## they are, less often as the locks get faster) or press a beat too late.
func _bot_dial(L: Dictionary, h: Hunter, dt: float) -> void:
	if float(L["jam"]) > 0.0 or float(L["grace"]) > 0.0:
		L["bot_ti"] = -1
		return
	var ti := target_under(L)
	var skill := float(h.ai.get("skill", 0.5))
	if ti >= 0 and ti != int(L["bot_ti"]):
		L["bot_ti"] = ti
		L["bot_roll"] = randf() < clampf(0.6 + skill * 0.38 - int(L["lock"]) * 0.07, 0.3, 0.96)
		L["bot_wait"] = randf_range(0.0, float(L["targets"][ti]["w"]) / speed_of(L) * 0.7)
	if ti >= 0 and L["bot_roll"]:
		L["bot_wait"] = float(L["bot_wait"]) - dt
		if float(L["bot_wait"]) <= 0.0:
			press(L, h)
			L["bot_ti"] = -1
	elif ti < 0 and int(L["bot_ti"]) >= 0:
		var missed := not bool(L["bot_roll"])
		L["bot_ti"] = -1
		if missed:
			L["jam"] = 0.0
			press(L, h)       # too late: the needle has already left the arc

# ------------------------------------------------------------------ opening, waking, clearing
func open(L: Dictionary, by: Hunter, how: String) -> void:
	if L["state"] != "sealed":
		return
	L["state"] = "open"
	L["user"] = null
	L["opened_by"] = by.pname if by else ""
	L["open_at"] = m.time
	var w := m.world
	for q in L["gate_tiles"]:
		w.kind[w.idx(q.x, q.y)] = World.T_GROUND
	var lbl: Label3D = L["nodes"]["label"]
	lbl.text = "%s\nOpen" % L["name"]
	m.sfx("unlock", L["gate_c"], 4.0, 0.7)
	m.sfx("boom", L["gate_c"], 0.0, 0.5)
	m.fx.burst(L["gate_c"] + Vector3(0, 1.5, 0), color_of(L), 40, 6.0, 0.7, 4.0, 1.4)
	m.fx.ring(L["c"], float(L["half"]) + 1.0, color_of(L), 0.8)
	var how_s: String = {"dial": "cracked the lock of", "runes": "lit the runes of", "wards": "broke the wards of"}.get(how, "opened")
	m.add_feed("%s %s %s" % [by.pname if by else "Someone", how_s, L["name"]])
	if m.player and not m.player.out:
		m.ping(L["gate_c"], color_of(L))
		if m.player.flat_dist(L["c"]) < 60.0 and m.hud:
			m.hud.toast("%s IS OPEN" % String(L["name"]).to_upper(), color_of(L))

func wake(L: Dictionary, by: Ent) -> void:
	var b: Boss = boss_of(L)
	if b == null or not is_instance_valid(b) or b.dead or not b.dormant:
		return
	b.dormant = false
	b.awake_t = 0.0
	b.next_cd = 1.6
	b.st = "chase"
	L["state"] = "awake"
	L["woke_at"] = m.time
	var lbl: Label3D = L["nodes"]["label"]
	lbl.text = "%s\n%s" % [L["name"], b.md["name"]]
	m.sfx("horn", L["c"], 4.0, 0.55)
	m.sfx("v_warden", L["c"], 6.0, 0.45)
	Shake.incoming_big(m, L["c"], 0.6)
	m.fx.burst(b.pos + Vector3(0, 2.0, 0), color_of(L), 50, 7.0, 0.8, 0.0, 1.6)
	m.add_feed("%s has woken in %s" % [b.md["name"], L["name"]])
	lock_in(L)
	if m.player and not m.player.out:
		if inside(L, m.player.pos, 6.0):
			if m.hud: m.hud.toast("BOSS AWAKE  ·  %s" % String(b.md["name"]).to_upper(), color_of(L))
			m.sfx("ult", null, 0.0, 0.6)
			_music(true)
		else:
			m.ping(L["c"], color_of(L))

func _music(on: bool) -> void:
	if on == music_on:
		return
	music_on = on
	# the layered score brings its boss stem in by itself (MusicDir reads music_on)
	if m.music_dir == null or not m.music_dir.started:
		Sfx.play_music("hollow" if on or m.tier >= 2 else "match", 0.8)

## The lair emptied: the boss settles back to sleep in the middle and heals up.
func reset_boss(b: Boss) -> void:
	var L: Dictionary = b.lair
	b._clear_attack()
	b.dormant = true
	b.phase = 0
	b.enraged = false
	b.awake_t = 0.0
	b.tgt = null
	b.st = "idle"
	b.stag_open = 0.0
	b.pos = Vector3(float(L["c"].x), b.pos.y, float(L["c"].z)); b.prev = b.pos
	b.hp = b.max_hp      # it heals up while it sleeps
	for a in L["adds"]:
		if is_instance_valid(a) and not a.dead: a.dead = true; a.visible = false
	L["adds"] = []
	unlock(L)
	L["calm_until"] = m.time + 8.0      # a breather: whoever's still inside can walk out before it stirs again
	L["state"] = "open"
	(L["nodes"]["label"] as Label3D).text = "%s\nOpen" % L["name"]
	m.add_feed("%s settles back to sleep" % b.md["name"])
	_music(false)

func on_boss_phase(b: Boss, p: int) -> void:
	var L: Dictionary = b.lair
	if m.player and inside(L, m.player.pos, 6.0) and m.hud:
		m.hud.toast("PHASE %d  ·  %s grows furious" % [p + 1, b.md["name"]], color_of(L))
	m.sfx("warn", b.pos, 2.0, 0.6)
	Juice.boss_phase(m, b)

func on_enrage(b: Boss) -> void:
	if m.player and inside(b.lair, m.player.pos, 6.0) and m.hud:
		m.hud.toast("%s IS ENRAGED" % String(b.md["name"]).to_upper(), Color("ff5a4a"))
	m.add_feed("%s is enraged" % b.md["name"])

## Adds a boss calls up (the Brood Mother's brood); they belong to the lair and stay in it.
func spawn_add(L: Dictionary, kind: String, at: Vector3) -> void:
	if adds_alive(L) >= 9:
		return
	var a := m.spawn_mob(kind, at)
	a.camp = L["c"]
	a.st = "chase"
	var b: Boss = boss_of(L)
	if b and is_instance_valid(b): a.tgt = b.tgt
	L["adds"].append(a)

## Every monster death passes through here: bosses, ward stones, guards.
func on_mob_dead(mb: Mob, credit: Ent) -> void:
	if mb is Boss:
		_boss_dead((mb as Boss).lair, mb as Boss, credit)
		return
	if mb.mkind == "ward" and mb.has_meta("lair"):
		var L: Dictionary = list[int(mb.get_meta("lair"))]
		var left: int = (L["wards"] as Array).filter(func(x): return is_instance_valid(x) and not x.dead and x != mb).size()
		m.sfx("boom", mb.pos, 2.0, 0.8)
		m.fx.burst(mb.pos + Vector3(0, 1.5, 0), Color("8fd8ff"), 30, 6.0, 0.6, 3.0)
		var hb: Hunter = credit if credit is Hunter else null
		if left == 0:
			open(L, hb, "wards")
		elif hb == m.player and m.hud:
			m.hud.toast("Ward broken  ·  %d left" % left, color_of(L))

## A ward stone was hit for the first time: its guards come out.
func on_ward_hit(mb: Mob, by: Ent) -> void:
	if mb.has_meta("woke"):
		return
	mb.set_meta("woke", true)
	var L: Dictionary = list[int(mb.get_meta("lair"))]
	var hb: Hunter = (by as Kin).owner_h if by is Kin and (by as Kin).owner_h else (by as Hunter if by is Hunter else null)
	if hb: _loud(L, mb.pos, hb, "A ward stone shrieks at %s" % L["name"])
	_call_guards(L, mb.pos, 3)

func _boss_dead(L: Dictionary, b: Boss, credit: Ent) -> void:
	var killer: Hunter = (credit as Kin).owner_h if credit is Kin and (credit as Kin).owner_h else (credit as Hunter if credit is Hunter else null)
	L["state"] = "cleared"
	L["cleared_by"] = killer.pname if killer else ""
	# everyone's Boki who fought it cheers (and remembers it)
	for hh in m.hunters:
		if hh.kin and hh.kin.comp and not hh.out and (hh == killer or hh.flat_dist(b) < 22.0) and hh.kin.state != "downed":
			hh.kin.comp.on_boss_kill(String(b.md.get("name", "the boss")), b.pos)
	(L["nodes"]["label"] as Label3D).text = "%s\nCleared" % L["name"]
	if L.get("locked", false):
		_victory(L, b)      # the gate stays shut a moment: the lever, the updraft, or wait it out
	else:
		unlock(L)
	# a small pile, all of it worth having (one Epic or Legendary piece of gear, a Brand upgrade for
	# its killer's weapon, one treasure, sometimes a Rift Key), and the Rare Egg on its own spot a few steps away,
	# under its own beam, so it's never lost in the pile
	var at := _floor_spot(L, b.pos, 0.0)
	# (1.6 m out: at 0.9 their names ran into each other)
	GearDrops.run_table(m, "boss", at, m.rng, {"r": 1.6, "h": killer, "bonus": m.biomes.rarity_bonus_at(at) if m.biomes else 0})
	m.spawn_val(Loot.valuable("crown_shard" if m.rng.randf() < 0.5 else "kin_idol"), at + Vector3(0, 0, -0.8))
	if m.exits and not m.exits.list.is_empty() and m.rng.randf() < 0.5:
		m.exits.drop_key(at + Vector3(0, 0, 1.1))
	# the egg: of the floor spots EGG_APART out from the pile, the one furthest from every pile item
	var pile_at: Array = [at + Vector3(0, 0, -0.8), at + Vector3(0, 0, 1.1)]
	for wp in m.wpicks:      # (the gear just dropped, and anything already lying on the lair's floor)
		if inside(L, wp["pos"], 0.0): pile_at.append(wp["pos"])
	var egg_at := at
	var best := -1.0
	for k in 12:
		var a := TAU * float(k) / 12.0
		var q := _floor_spot(L, at + Vector3(cos(a), 0, sin(a)) * EGG_APART, 1.8)
		var near := 1e9
		for pp in pile_at: near = minf(near, Vector2(q.x - pp.x, q.z - pp.z).length())
		if near > best: best = near; egg_at = q
	var sp := String(b.md.get("egg", ""))
	if Data.KIN.has(sp):
		drop_egg(L, Loot.rare_egg(sp, b.mkind), egg_at)
	# XP for everyone who fought it: the most for the killer's squad
	for h in m.hunters:
		if h.out or h.extracted or not inside(L, h.pos, 4.0):
			continue
		var share := 1.0 if killer and h.team == killer.team else (0.5 if float(b.damage_by.get(h.team, 0.0)) > b.max_hp * 0.1 else 0.2)
		h.gain_xp(260.0 * share)
	if killer and not killer.remote:
		killer.add_stat("bosses")
		PerkOrbs.drop(m, "boss", b.pos, 0, killer)      # a fan of three perk orbs
	# the boss's brood scatters
	for a in L["adds"]:
		if is_instance_valid(a) and not a.dead: a.camp = a.pos
	m.add_feed("%s felled %s!" % [killer.pname if killer else "Someone", b.md["name"]])
	m.sfx("horn", null, -2.0, 0.7)
	_music(false)

## The boss is dead and its gate still shut: VICTORY_T on the clock, the lever lit, the updraft
## blowing at the back. Everyone near hears it fall (a different cry from the fight's roar) and their
## ping on the lair turns to "fallen", so whoever is camping the gate knows the clock is running.
func _victory(L: Dictionary, b: Boss) -> void:
	L["victory"] = true
	L["victory_at"] = m.time
	L["flown"] = []
	var lvn: Node3D = L["nodes"]["lever"]
	if is_instance_valid(lvn): lvn.get_node("Lit").visible = true
	_set_updraft(L, true)
	var bn: String = b.md["name"] if b else "The boss"
	var ins: Array = L.get("sealed_in", [])
	if m.player and m.hud and ins.has(m.player):
		m.hud.toast("VICTORY  ·  PULL THE LEVER BY THE GATE, OR RIDE THE UPDRAFT OUT THE BACK", color_of(L))
	_alert(L, "fallen", "%s has fallen at %s" % [bn, L["name"]])

## Shout a lair's news to everyone outside within ALERT_R: a spatial cry from the lair, a ping with
## the boss's icon on the minimap and full map, a toast. kind: "fight" (it woke and sealed) or "fallen".
func _alert(L: Dictionary, kind: String, text: String) -> void:
	L["alert"] = kind
	L["alert_text"] = text
	L["alert_at"] = m.time
	var c: Vector3 = L["c"]
	var ins: Array = L.get("sealed_in", [])
	var heard: Dictionary = L["heard"]
	var near_any := false
	for o in m.hunters:
		if o.out or o.extracted or ins.has(o) or (L.get("flown", []) as Array).has(o):
			continue
		if o.flat_dist(c) > ALERT_R:
			continue
		near_any = true
		heard[o.nid] = m.time
		alert_log.append({"lair": L["id"], "kind": kind, "nid": o.nid})
		if o == m.player:
			m.ping(c, color_of(L))
			m.add_feed(text)
			if m.hud: m.hud.toast(text.to_upper() if kind == "fallen" else text, color_of(L) if kind == "fight" else Color("ffd36a"))
		elif o.ctrl == "bot" and kind == "fight":
			o.ai.erase("camp_" + String(L["id"]))      # (a fresh fight: think again about camping it)
	if near_any or (m.player and ins.has(m.player)):
		# the cry carries: spatial, loud, from the lair itself
		if kind == "fight":
			m.sfx("v_warden", c, 10.0, 0.42)
			m.sfx("horn", c, 8.0, 0.5)
			m.sfx("boom", c, 4.0, 0.35)
		else:
			m.sfx("horn", c, 9.0, 0.95)
			m.sfx("die_big_1", c, 8.0, 0.55)
			m.sfx("unlock", c, 6.0, 0.6)
	m.note_sound(null, c, "boom")
	var beam: Node3D = L["nodes"].get("beam")
	if is_instance_valid(beam):
		beam.visible = true
		var gold := kind == "fallen"
		for nm in ["Shaft", "Core"]:
			var mi: MeshInstance3D = beam.get_node(nm)
			var base: Color = Color("ffd36a") if gold else color_of(L)
			(mi.material_override as ShaderMaterial).set_shader_parameter("color", Color(base.lightened(0.5 if nm == "Core" else 0.0), 0.55 if nm == "Core" else 0.3))

## Did this hunter hear the lair's fight (or its boss fall) and is it still news?
func alerted(L: Dictionary, h: Hunter) -> bool:
	return h != null and (L["heard"] as Dictionary).has(h.nid) and alert_on(L)

## A lair's alert holds while its seal does, and a few seconds after.
func alert_on(L: Dictionary) -> bool:
	return String(L.get("alert", "")) != "" and (L.get("locked", false) or m.time - float(L.get("unlock_at", -99.0)) < 8.0)

## The lever was pulled (or the clock ran out): the gate opens, the updraft dies down.
func _victory_open(L: Dictionary, by: Hunter) -> void:
	if not L.get("victory", false):
		return
	L["victory"] = false
	var lvn: Node3D = L["nodes"]["lever"]
	if is_instance_valid(lvn):
		lvn.get_node("Lit").visible = false
		var arm: Node3D = lvn.get_node("Arm")
		var tw := m.create_tween()
		tw.tween_property(arm, "rotation:x", 0.75, 0.25).set_trans(Tween.TRANS_BACK)
	_set_updraft(L, false)
	if by:
		by.set_hold("lever", 0.9)
		m.sfx("click", L["lever"], 4.0, 0.6)
		m.sfx("unlock", L["lever"], 2.0, 0.8)
		m.fx.burst(L["lever"] + Vector3(0, 1.6, 0), color_of(L), 18, 3.5, 0.5, -2.0)
		m.add_feed("%s pulled the lever: %s's gate opens" % [by.pname, L["name"]])
	else:
		m.add_feed("%s's gate grinds open" % L["name"])
	L["opened_by_lever"] = by.pname if by else ""
	unlock(L)

func _set_updraft(L: Dictionary, on: bool) -> void:
	L["up_on"] = on
	var vn: Node3D = L["nodes"].get("vent")
	if is_instance_valid(vn):
		vn.get_node("Air").visible = on
		vn.get_node("Ring").visible = on
	if on:
		m.sfx("glide", L["up"], 4.0, 0.6)
		m.fx.burst(L["up"] + Vector3(0, 0.6, 0), Color(1, 1, 1), 26, 6.0, 0.6, 6.0, 1.0, Vector3.UP, 20.0)

## The column of light is 12 m tall and stands at the back of the lair, right where the camera looks
## over it at anyone who has just landed beyond the back wall: it washed the whole view out in a white
## haze. Hidden from your view while you're outside the lair on its far side (the side the updraft
## throws you to), shown again as soon as you're back in or round the front. Purely visual.
func _updraft_view(L: Dictionary) -> void:
	var vn: Node3D = L["nodes"].get("vent")
	if not is_instance_valid(vn) or m.player == null or m.cam == null:
		return
	var air: Node3D = vn.get_node("Air")
	var p: Hunter = m.player
	var u: Vector3 = L["up"]
	var behind := false
	if not inside(L, p.pos, 0.0) and not (p.auto_glide and (L["flown"] as Array).has(p)):
		# from the camera, the column sits between you and the lens: you're further from the camera
		# than the column is (along the camera's look on the ground) and not far off to its side
		var fwd := -m.cam.global_basis.z
		var f2 := Vector2(fwd.x, fwd.z).normalized()
		var rel := Vector2(p.pos.x - u.x, p.pos.z - u.z)
		behind = rel.dot(f2) > 0.0 and absf(rel.cross(f2)) < float(L["half"]) + 4.0 and rel.length() < float(L["half"]) * 2.0 + 10.0
	air.visible = not behind

## Out of the column the updraft's glide carries you on to the landing spot beyond the wall and sets
## you down there; steer (or take the glide key) and you fly yourself instead.
func _tick_flyers(L: Dictionary) -> void:
	var land: Vector3 = L["up_land"]
	var u: Vector3 = L["up"]
	var flown: Array = L["flown"]
	for h in flown.duplicate():
		if not is_instance_valid(h) or h.out or h.grounded and not h.auto_glide:
			if not L.get("up_on", false): flown.erase(h)
			continue
		if not h.auto_glide or h.remote:
			continue
		if Vector2(h.pos.x - u.x, h.pos.z - u.z).length() < UP_R + 0.4 and h.pos.y < u.y + UP_TOP - 0.6:
			continue      # (still in the column)
		var to := Vector2(land.x - h.pos.x, land.z - h.pos.z)
		var steering: bool = h.ctrl != "bot" and (h.inp.get("move", Vector2.ZERO) as Vector2).length() > 0.2
		if not steering:
			var want := to.normalized() * minf(UP_PUSH, maxf(1.5, to.length() * 1.4)) if to.length() > 0.05 else Vector2.ZERO
			h.vel.x = want.x; h.vel.z = want.y
		if not inside(L, h.pos, 1.0) and not m.world.is_void(h.pos.x, h.pos.z) and to.length() < (2.5 if not steering else 0.0):
			h.auto_glide = false      # over the landing: fold the glider and drop onto it

## Seconds until the gate opens on its own after the kill.
func victory_left(L: Dictionary) -> float:
	return maxf(0.0, VICTORY_T - (m.time - float(L.get("victory_at", m.time))))

## Is this hunter allowed on the lair's escape updraft (sealed in for the fight, or already on it)?
func may_fly(L: Dictionary, h: Hunter) -> bool:
	# (once over the wall and out, it's one ride: drop back into the column and it won't lift you again)
	if (L.get("escaped", []) as Array).has(h):
		return false
	return (L.get("sealed_in", []) as Array).has(h) or (L.get("flown", []) as Array).has(h)

## The escape updraft: those who fought step into it and it lifts them high over the lair, then
## throws them out on the glider toward up_land, over the back wall. Anyone else is shoved off it.
func _tick_updraft(L: Dictionary, dt: float) -> void:
	if not L.get("up_on", false):
		return
	var u: Vector3 = L["up"]
	var land: Vector3 = L["up_land"]
	var top := u.y + UP_TOP
	_updraft_view(L)
	for h in m.hunters:
		if h.out or h.extracted or h.remote or h.riding or h.dropping or h.downed:
			continue
		var rel := Vector2(h.pos.x - u.x, h.pos.z - u.z)
		if rel.length() > UP_R + h.r * 0.5 or h.pos.y > top + 1.5 or h.pos.y < u.y - 1.0:
			continue
		if not may_fly(L, h):
			# not one of those who fought: it won't carry you, it shoves you off
			var pd := rel.normalized() if rel.length() > 0.05 else Vector2(L["out"].x, L["out"].y)
			h.vel.x = pd.x * 5.0; h.vel.z = pd.y * 5.0
			if h.vel.y > 0.0: h.vel.y = 0.0
			if h == m.player and m.hud and m.time - float(_told.get("up", -9.0)) > 2.5:
				_told["up"] = m.time
				m.hud.toast("The updraft only carries those who fought", color_of(L))
			continue
		if not (L["flown"] as Array).has(h):
			(L["flown"] as Array).append(h)
			h.auto_glide = true
			h.glide_cd = 0.0
			h.glide_fuel = maxf(h.glide_fuel, 0.8)
			m.sfx("glide", h.pos, 2.0, 1.2)
			m.fx.burst(h.pos + Vector3(0, 0.5, 0), Color(1, 1, 1), 18, 5.0, 0.5, 6.0, 1.0, Vector3.UP, 25.0)
			if h == m.player and m.hud: m.hud.toast_small("Riding the updraft out", color_of(L))
		h.grounded = false
		h.pad = {}
		if h.pos.y < top - 0.6:
			# up the column, drawn to its middle
			h.vel.y = maxf(h.vel.y, 11.0)
			h.vel.x = lerpf(h.vel.x, -rel.x * 3.0, 1.0 - exp(-6.0 * dt))
			h.vel.z = lerpf(h.vel.z, -rel.y * 3.0, 1.0 - exp(-6.0 * dt))
		else:
			# at the top: out over the wall
			var to := Vector2(land.x - h.pos.x, land.z - h.pos.z)
			var d := to.normalized() if to.length() > 0.1 else Vector2(-L["out"].x, -L["out"].y)
			h.vel = Vector3(d.x * UP_PUSH, maxf(h.vel.y, 1.0), d.y * UP_PUSH)
	_tick_flyers(L)
	# whoever has flown out over the wall is free of the seal
	var ins: Array = L.get("sealed_in", [])
	for h in (L["flown"] as Array):
		if is_instance_valid(h) and ins.has(h) and not inside(L, h.pos, 0.3):
			ins.erase(h)
			if not L.has("escaped"): L["escaped"] = []
			(L["escaped"] as Array).append(h)
			m.add_feed("%s rode the updraft out of %s" % [h.pname, L["name"]])

## A clear spot on a lair's floor near `p`, at least `margin` in from the walls.
func _floor_spot(L: Dictionary, p: Vector3, margin: float) -> Vector3:
	var c: Vector3 = L["c"]
	var hf := float(L["half"]) - 1.6 - margin
	var q := Vector3(clampf(p.x, c.x - hf, c.x + hf), p.y, clampf(p.z, c.z - hf, c.z + hf))
	q = m.world.free_spot_near(q, [], 0.8, 0.5, 4.0)
	q.y = m.world.ground_at(q.x, q.z)
	return q

## Puts a Rare Egg on the ground (a boss's, or one spilled from a pack), loud.
func drop_egg(L: Dictionary, item: Dictionary, at: Vector3) -> Dictionary:
	m.spawn_val(item, at)
	var wp: Dictionary = m.wpicks[m.wpicks.size() - 1]
	var old: Node3D = wp["node"]
	if is_instance_valid(old): old.queue_free()
	var n := BossModels.rare_egg(Data.KIN[String(item["sp"])]["glow"] if Data.KIN.has(String(item["sp"])) else Color("ffd36a"))
	n.position = at
	m.add_child(n)
	wp["node"] = n
	wp["egg"] = true
	L["egg_wp"] = wp
	L["egg_uid"] = String(item["uid"])
	L["egg_told"] = false
	egg_pings.append({"pos": at, "until": m.time + EGG_PING_T, "follow": null, "text": "Rare Egg"})
	m.add_feed("A Rare Egg dropped at %s" % L["name"])
	m.sfx("unlock", at, 4.0, 0.6)
	if m.player and not m.player.out:
		m.ping(at, Color("ffd36a"))
		if m.hud: m.hud.toast("A RARE EGG DROPPED AT %s" % String(L["name"]).to_upper(), Color("ffd36a"))
	return wp

# ------------------------------------------------------------------ every tick
func tick(dt: float) -> void:
	if list.is_empty():
		return
	for L in list:
		_tick_dial(L, dt)
		_tick_seal(L, dt)
		_tick_lock(L, dt)
		_tick_gate(L, dt)
		_tick_runes(L, dt)
		_tick_egg(L)
		_tick_show(L)
		if not L.get("up_on", false) and not (L.get("flown", []) as Array).is_empty():
			_tick_flyers(L)
		if L["state"] in ["open", "awake"] and not L.get("locked", false) and m.time >= float(L.get("calm_until", 0.0)) and (not m.net_on or m.is_host):
			for h in m.hunters:
				if not h.out and not h.extracted and not h.dropping and not h.downed and inside(L, h.pos, -0.6):
					if L["state"] == "open": wake(L, h)
					else: lock_in(L)       # woken from outside (a shot through the gate): seals once someone steps in
					break
	# the dial's needle on the lectern turns for everyone to see
	for L in list:
		var dn: Node3D = L["nodes"]["dial"]
		if is_instance_valid(dn):
			var nd: Node3D = dn.get_node("Face/Needle")
			nd.rotation.y = -float(L["needle"])
	egg_pings = egg_pings.filter(func(e): return m.time < float(e["until"]))
	for h in m.hunters:
		_prev[h.nid] = bool(h.inp.get("interact", false))
	if m.player and music_on and boss_for(m.player) == null:
		_music(false)

## What a lair shows the world while its fight is on: the seal's clock over the gate (it floats there
## for anyone outside to read), and the shaft of light over it, pulsing, until the news is old.
func _tick_show(L: Dictionary) -> void:
	var nodes: Dictionary = L.get("nodes", {})
	if L.get("locked", false):
		var lbl: Label3D = nodes["label"]
		var b: Boss = boss_of(L)
		var bn := String(b.md["name"]) if b else "The boss"
		if L.get("victory", false):
			lbl.text = "%s\n%s has fallen  ·  gate opens %s" % [L["name"], bn, clock(victory_left(L))]
		else:
			lbl.text = "%s\n%s FIGHT  ·  %s" % [L["name"], bn.to_upper(), clock(lock_left(L))]
		# (it's for those outside, like the beam: inside, the top banner says the same and the gate's copy
		# only lands on top of your HUD)
		var in_l: bool = m.player != null and inside(L, m.player.pos, 1.0)
		if in_l != lbl.has_meta("hid_in"):
			if in_l: lbl.set_meta("hid_in", lbl.visible); lbl.visible = false
			else: lbl.visible = bool(lbl.get_meta("hid_in")); lbl.remove_meta("hid_in")
	elif nodes.has("label") and is_instance_valid(nodes["label"]) and (nodes["label"] as Node).has_meta("hid_in"):
		var l2: Label3D = nodes["label"]
		l2.visible = bool(l2.get_meta("hid_in")); l2.remove_meta("hid_in")
	var beam: Node3D = nodes.get("beam")
	if is_instance_valid(beam) and (beam.visible or (alert_on(L) and beam.has_meta("hid"))):
		# (it's for those outside: hidden for whoever is in the lair, where it would only glare)
		var in_it: bool = m.player != null and inside(L, m.player.pos, 1.0)
		beam.set_meta("hid", in_it)
		if not alert_on(L) or in_it:
			beam.visible = false
		else:
			beam.visible = true
			var k := 1.0 + 0.1 * sin(m.time * 3.2)
			(beam.get_node("Shaft") as Node3D).scale = Vector3(k, 1.0, k)
			(beam.get_node("Ring") as Node3D).rotation.y = m.time * 0.4

## m:ss, rounded up (a clock that reads 0:15 for the whole first second).
static func clock(t: float) -> String:
	var s := int(ceil(maxf(0.0, t)))
	return "%d:%02d" % [s / 60, s % 60]

## While a lair is sealed, its ward keeps everything out: walking, gliding or being thrown in bounces.
func _tick_seal(L: Dictionary, dt: float) -> void:
	if not L["state"] in ["sealed", "dormant"]:
		return
	var bodies: Array = []
	for h in m.hunters:
		if not h.out and not h.extracted and not h.riding: bodies.append(h)
	for k in m.kins:
		if not k.dead and k.state in ["active", "flying", "returning", "wild", "dazed"]: bodies.append(k)
	for mb in m.mobs:
		if not mb.dead and not (mb is Boss): bodies.append(mb)
	for e in bodies:
		if not inside(L, e.pos, 0.25):
			continue
		# hunters still dropping in from the skyship, and anyone flying high over the walls, pass over;
		# whoever comes down inside (or walks, glides or is thrown in low) is put back out
		if e is Hunter and (e as Hunter).dropping:
			continue
		if not e.grounded and e.pos.y > float(L["c"].y) + 3.6:
			continue
		_push_out(L, e)
		if e == m.player and m.hud and m.time - float(_told.get("seal", -9.0)) > 3.0:
			_told["seal"] = m.time
			m.hud.toast(("%s is sealed. Open its gate first" if L["state"] == "sealed" else "%s lies dormant this time. Its gate is rusted shut") % L["name"], color_of(L))
			m.sfx("shield", e.pos, -4.0, 1.4)

## Puts someone just outside a lair's walls, out the nearest side (or by the dial), set down still.
func _push_out(L: Dictionary, e: Ent) -> void:
	var c: Vector3 = L["c"]
	var hf := float(L["half"]) - 0.5
	var dx: float = e.pos.x - c.x; var dz: float = e.pos.z - c.z
	var push := Vector2(signf(dx) if dx != 0.0 else 1.0, 0) if absf(dx) > absf(dz) else Vector2(0, signf(dz) if dz != 0.0 else 1.0)
	var to: Vector3 = e.pos
	if push.x != 0.0: to.x = c.x + push.x * (hf + 1.6)
	else: to.z = c.z + push.y * (hf + 1.6)
	to = m.world.free_spot_near(to, [], 0.6, e.r, 4.0)
	if m.world.is_void(to.x, to.z) or m.world.is_block(to.x, to.z) or inside(L, to, 0.6):
		to = L["dial"]
	e.pos = Vector3(to.x, maxf(e.pos.y, m.world.ground_at(to.x, to.z)), to.z); e.prev = e.pos
	# set down just outside, still: a shove here could carry someone off the island's edge
	if e.grounded or e.pos.y <= m.world.ground_at(to.x, to.z) + 0.05:
		e.vel = Vector3.ZERO
		e.pos.y = m.world.ground_at(to.x, to.z); e.prev = e.pos
	else:
		e.vel = Vector3(push.x * 2.0, maxf(e.vel.y, 1.5), push.y * 2.0)
	if e is Kin and (e as Kin).state == "flying": (e as Kin).state = "returning"
	m.fx.burst(e.pos + Vector3(0, 1.0, 0), color_of(L), 12, 3.0, 0.4, -2.0)

# ------------------------------------------------------------------ sealed in with the boss
## The boss woke with someone inside: the gate shuts behind them and the ward lights up. Whoever is
## in stays in; whoever is out stays out. Anyone standing in the gateway is put outside first, so
## nobody is left inside the gate's stones.
func lock_in(L: Dictionary) -> void:
	if L.get("locked", false) or L["state"] != "awake":
		return
	var ins: Array = []
	for h in m.hunters:
		if not h.out and not h.extracted and not h.riding and not h.dropping and inside(L, h.pos, 0.25):
			ins.append(h)
	if ins.is_empty():
		return
	L["locked"] = true
	L["lock_at"] = m.time
	L["sealed_in"] = ins
	L["heard"] = {}
	L["flown"] = []
	L["escaped"] = []
	# whoever is in the gateway itself steps in, clear of the gate's stones
	var c: Vector3 = L["c"]
	var keep := float(L["half"]) - 0.95
	for h in ins:
		h.pos.x = clampf(h.pos.x, c.x - keep, c.x + keep); h.pos.z = clampf(h.pos.z, c.z - keep, c.z + keep); h.prev = h.pos
	var w := m.world
	for q in L["gate_tiles"]:
		var tc := Vector3(q.x + 0.5, 0, q.y + 0.5)
		for e in m.hunters + m.kins + m.mobs:
			if is_instance_valid(e) and not e.dead and not (e is Boss) and absf(e.pos.x - tc.x) < 0.5 + e.r and absf(e.pos.z - tc.z) < 0.5 + e.r and not ins.has(e):
				_push_out(L, e)
		w.kind[w.idx(q.x, q.y)] = World.T_BLOCK
	m.sfx("boom", L["gate_c"], 2.0, 0.55)
	m.sfx("shield", L["gate_c"], 2.0, 0.7)
	m.fx.burst(L["gate_c"] + Vector3(0, 1.5, 0), color_of(L), 30, 5.0, 0.6, 3.0, 1.2)
	m.fx.ring(L["c"], float(L["half"]) + 0.6, color_of(L), 0.7)
	(L["nodes"]["label"] as Label3D).text = "%s\nSealed in  ·  a fight is on" % L["name"]
	var b: Boss = boss_of(L)
	m.add_feed("%s is sealed: %s fight%s %s" % [L["name"], ", ".join(ins.map(func(x): return x.pname)), "s" if ins.size() == 1 else "", b.md["name"] if b else "the boss"])
	if m.player and m.hud:
		if ins.has(m.player):
			m.hud.toast("SEALED IN  ·  DEFEAT %s" % (String(b.md["name"]).to_upper() if b else "THE BOSS"), color_of(L))
	_alert(L, "fight", "%s fight at %s" % [b.md["name"] if b else "Boss", L["name"]])
	_tick_show(L)

## The seal drops: the gate opens again (the boss died, everyone in it went down, or time ran out).
func unlock(L: Dictionary) -> void:
	if not L.get("locked", false):
		return
	L["locked"] = false
	L["sealed_in"] = []
	L["unlock_at"] = m.time
	if L.get("victory", false):
		L["victory"] = false
		_set_updraft(L, false)
		var lvn: Node3D = L["nodes"]["lever"]
		if is_instance_valid(lvn): lvn.get_node("Lit").visible = false
	var w := m.world
	for q in L["gate_tiles"]:
		w.kind[w.idx(q.x, q.y)] = World.T_GROUND
	(L["nodes"]["label"] as Label3D).text = "%s\n%s" % [L["name"], "Cleared" if L["state"] == "cleared" else "Open"]
	m.sfx("unlock", L["gate_c"], 3.0, 0.8)
	m.fx.burst(L["gate_c"] + Vector3(0, 1.5, 0), color_of(L), 24, 5.0, 0.6, 3.0, 1.0)

## Is this spot inside a sealed lair this hunter isn't sealed in (so it can't get there)?
func walled_off(h: Hunter, p: Vector3) -> bool:
	var L := lair_of(p, 0.0)
	return not L.is_empty() and L.get("locked", false) and not (L.get("sealed_in", []) as Array).has(h)

## Is this hunter sealed in a lair right now? (Returns the lair, or {}.)
func sealed_lair(h: Hunter) -> Dictionary:
	for L in list:
		if L.get("locked", false) and (L["sealed_in"] as Array).has(h):
			return L
	return {}

## Seconds until the seal fails on its own.
func lock_left(L: Dictionary) -> float:
	return maxf(0.0, LOCK_T - (m.time - float(L.get("lock_at", m.time))))

## While sealed: those inside stay inside (walking, dashing, gliding or shoved), those outside stay
## out; it breaks when everyone inside is down or out, or when LOCK_T runs out (the boss resets).
func _tick_lock(L: Dictionary, dt: float) -> void:
	if not L.get("locked", false):
		return
	var b: Boss = boss_of(L)
	if L.get("victory", false):
		# the boss is down and the gate still shut: the lever, the updraft, or the clock
		L["sealed_in"] = (L["sealed_in"] as Array).filter(func(x): return is_instance_valid(x) and not x.out and not x.extracted)
		for h in m.hunters:
			if h.out or h.extracted or h.remote:
				continue
			if can_pull(L, h) and (_pressed(h) or (h.ctrl == "bot" and String(h.ai.get("goal_kind", "")) == "lair_lever")):
				_victory_open(L, h)
				return
		if victory_left(L) <= 0.0:
			_victory_open(L, null)
			return
		_tick_updraft(L, dt)
		_hold_seal(L, b)
		return
	if b == null or b.dead or L["state"] != "awake":
		unlock(L)
		return
	var ins: Array = (L["sealed_in"] as Array).filter(func(x): return is_instance_valid(x) and not x.out and not x.extracted)
	L["sealed_in"] = ins
	var standing: Array = ins.filter(func(x): return not x.downed)
	if standing.is_empty() or m.time - float(L["lock_at"]) >= LOCK_T:
		var wiped := standing.is_empty()
		m.add_feed(("%s wiped the party in %s" if wiped else "The seal on %s failed: %s settles back to sleep") % ([b.md["name"], L["name"]] if wiped else [L["name"], b.md["name"]]))
		if m.player and m.hud and m.player.flat_dist(L["c"]) < 40.0:
			m.hud.toast(("THE SEAL BREAKS  ·  %s HEALS AND SLEEPS" if wiped else "THE SEAL FAILS  ·  %s RESETS") % String(b.md["name"]).to_upper(), color_of(L))
		reset_boss(b)
		return
	_hold_seal(L, b)

## While sealed, those inside stay in and those outside stay out (anyone riding the escape updraft
## is let over the wall).
func _hold_seal(L: Dictionary, b: Boss) -> void:
	var ins: Array = L["sealed_in"]
	var flown: Array = L.get("flown", [])
	var c: Vector3 = L["c"]
	var hf := float(L["half"]) - 0.5
	var keep := hf - 0.45
	for h in m.hunters:
		if h.out or h.extracted or h.riding or h.dropping or (flown.has(h) and not h.grounded):
			continue
		if ins.has(h):
			if not inside(L, h.pos, 0.0):
				h.pos.x = clampf(h.pos.x, c.x - keep, c.x + keep); h.pos.z = clampf(h.pos.z, c.z - keep, c.z + keep)
				h.pos.y = maxf(h.pos.y, m.world.ground_at(h.pos.x, h.pos.z))
				h.prev = h.pos
				h.vel.x = 0.0; h.vel.z = 0.0
				if h == m.player and m.hud and m.time - float(_told.get("lock", -9.0)) > 2.5:
					_told["lock"] = m.time
					if L.get("victory", false):
						m.hud.toast("The gate is still shut  ·  pull the lever, or ride the updraft", color_of(L))
					else:
						m.hud.toast("Sealed in  ·  defeat %s" % (b.md["name"] if b else "the boss"), color_of(L))
					m.sfx("shield", h.pos, -4.0, 1.4)
		elif inside(L, h.pos, 0.25) and (h.grounded or h.pos.y <= float(c.y) + 3.6):
			_push_out(L, h)
			if h == m.player and m.hud and m.time - float(_told.get("seal", -9.0)) > 3.0:
				_told["seal"] = m.time
				m.hud.toast("%s is sealed while its fight is on" % L["name"], color_of(L))

func _tick_gate(L: Dictionary, dt: float) -> void:
	if L["state"] in ["sealed", "dormant"]:
		return
	var locked: bool = L.get("locked", false)
	if float(L["gate_k"]) >= 1.0 and not locked:
		return
	# opening takes a moment; slamming shut on a lock-in is quick
	L["gate_k"] = move_toward(float(L["gate_k"]), 0.0 if locked else 1.0, dt / (0.35 if locked else 1.6))
	var k := float(L["gate_k"])
	var gate: Node3D = L["nodes"]["gate"]
	if is_instance_valid(gate):
		var bars: Node3D = gate.get_node("Bars")
		bars.position.y = -3.3 * k * k
		bars.position.x = sin(m.time * 40.0) * 0.03 * (1.0 - k)
		bars.visible = k < 1.0
	var dome: Node3D = L["nodes"]["dome"]
	if is_instance_valid(dome):
		var sh: MeshInstance3D = dome.get_node("Shell")
		# sealed in: the ward glows and breathes over the walls
		var glow := (0.07 + 0.05 * sin(m.time * 3.0)) if locked else 0.0
		(sh.material_override as StandardMaterial3D).albedo_color.a = 0.10 * (1.0 - k) + glow * (1.0 - k)
		dome.get_node("Rim").visible = k < 0.5
		dome.visible = k < 1.0

func _tick_runes(L: Dictionary, dt: float) -> void:
	for rn in L["runes"]:
		if rn["lit"]: continue
		if m.time - float(rn["held"]) > 0.1:
			rn["prog"] = maxf(0.0, float(rn["prog"]) - dt * 0.5)

## Who has the egg now: the first time someone picks it up, everyone hears about it.
func _tick_egg(L: Dictionary) -> void:
	var wp = L.get("egg_wp")
	if wp == null or L.get("egg_told", true):
		return
	if m.wpicks.has(wp):
		return
	L["egg_told"] = true
	var uid := String(L.get("egg_uid", ""))
	for h in m.hunters:
		for it in h.pack:
			if String(it.get("uid", "")) == uid:
				egg_pings.append({"pos": h.pos, "until": m.time + CARRY_PING_T, "follow": h, "text": "Egg carrier"})
				m.add_feed("%s took the Rare Egg" % h.pname)
				if h == m.player and m.hud:
					m.hud.toast("You have the Rare Egg  ·  get it home", Color("ffd36a"))
				elif m.player and not m.player.out:
					m.ping(h.pos, Color("ffd36a"))
				return

# ------------------------------------------------------------------ bots
## Where a bot wants to go for the lairs: a dropped egg first, then (for the bolder ones) a lair.
func bot_goal(h: Hunter, leaving: bool) -> Array:
	var a := h.ai
	var sl := sealed_lair(h)
	if not sl.is_empty():
		if sl.get("victory", false):
			return _bot_exit(sl, h)
		return [sl["c"], "lair_fight"]      # sealed in: there's only the boss
	# riding the escape updraft out: steer for where it throws you
	for L in list:
		if (L.get("flown", []) as Array).has(h) and not h.grounded and h.auto_glide:
			return [L["up_land"], "lair_escape"]
	for L in list:
		var wp = L.get("egg_wp")
		if wp != null and m.wpicks.has(wp) and h.flat_dist(wp["pos"]) < 50.0:
			if not a.has("egg_" + String(L["id"])): a["egg_" + String(L["id"])] = randf() < 0.45 + 0.5 * float(a.get("skill", 0.5))
			if a["egg_" + String(L["id"])]:
				return [wp["pos"], "lair_egg"]
	var cg := _bot_camp(h, leaving)
	if not cg.is_empty():
		return cg
	if leaving or m.time < 25.0 or h.hp < h.max_hp * 0.55:
		return []
	if not a.has("boss_hunt"):
		# a bot on its own (no squadmate left) waits for level 8 before it thinks about a boss: alone
		# at level 2-6 they cracked a lair, got sealed in with it and were wiped (5 of 9 seeded simtests)
		if h.lvl < 8 and not m.hunters.any(func(o): return o != h and o.team == h.team and not o.out):
			return []
		# stronger bots go after bosses more often
		a["boss_hunt"] = randf() < 0.12 + 0.45 * float(a.get("skill", 0.5))
	if not a["boss_hunt"]:
		return []
	var best := {}; var bd := 110.0
	for L in list:
		if L["state"] in ["cleared", "dormant"] or L.get("locked", false): continue
		# a sealed gate bots can't work (runes, wards) isn't a goal: try the next lair instead of giving up
		if L["state"] == "sealed" and not (L["entry"] as Array).has("dial"): continue
		# (the lair we picked last time reaches a little further: at the edge of the range a bot
		# walking about flipped between it and a roam goal every think, turning round each time)
		var d := h.flat_dist(L["c"]) - (15.0 if a.get("lair_pick", "") == String(L["id"]) else 0.0)
		if d < bd: bd = d; best = L
	if best.is_empty():
		a.erase("lair_pick")
		return []
	a["lair_pick"] = String(best["id"])
	if best["state"] == "sealed":
		if not (best["entry"] as Array).has("dial"):
			return []
		var u = best["user"]
		if u != null and not is_same(u, h):
			return [best["dial"] + Vector3(best["out"].x, 0, best["out"].y) * 3.0, "roam"]
		return [best["dial"], "lair_dial"]
	return [best["c"], "lair_fight"]

## A bot sealed in after the kill: the egg if it's still lying here, then out. With rivals waiting at
## the gate (and the updraft blowing) it rides the updraft out the back; otherwise it pulls the lever.
func _bot_exit(L: Dictionary, h: Hunter) -> Array:
	var a := h.ai
	var wp = L.get("egg_wp")
	if wp != null and m.wpicks.has(wp) and inside(L, wp["pos"], 0.0) and victory_left(L) > 3.0:
		var key := "egg_" + String(L["id"])
		if not a.has(key): a[key] = randf() < 0.45 + 0.5 * float(a.get("skill", 0.5))
		if a[key]:
			return [wp["pos"], "lair_egg"]
	var way := "updraft" if L.get("up_on", false) and campers(L, h.team) > 0 else "lever"
	a["lair_exit"] = way
	if way == "updraft":
		return [L["up"], "lair_updraft"]
	return [L["lever"], "lair_lever"]

## Rivals of this team standing outside a lair's gate (waiting for whoever comes out).
func campers(L: Dictionary, team: int) -> int:
	var n := 0
	for o in m.hunters:
		if o.team == team or o.out or o.extracted or o.downed or o.riding or o.dropping:
			continue
		if not inside(L, o.pos, 0.5) and o.flat_dist(L["gate_c"]) < 18.0:
			n += 1
	return n

## A fight we heard about: some squads go and camp its gate for whoever comes out, more often the
## stronger they are (more of them up, healthier, better bots), never when they're leaving.
func _bot_camp(h: Hunter, leaving: bool) -> Array:
	if leaving:
		return []
	for L in list:
		if not alerted(L, h) or String(L["state"]) == "dormant":
			continue
		if (L.get("sealed_in", []) as Array).any(func(x): return is_instance_valid(x) and x.team == h.team):
			continue      # (our own squad is in there)
		var key := "camp_" + String(L["id"])
		if not h.ai.has(key):
			h.ai[key] = randf() < camp_odds(h)
		if h.ai[key]:
			return [camp_spot(L, h), "lair_camp"]
	return []

## How likely a bot is to go and camp a lair fight it heard: its skill, how many of its squad are up,
## and how healthy they are.
func camp_odds(h: Hunter) -> float:
	var mates: Array = m.hunters.filter(func(x): return x.team == h.team and not x.out and not x.extracted)
	var up: Array = mates.filter(func(x): return not x.downed)
	if up.is_empty():
		return 0.0
	var hpk := 0.0
	for x in up: hpk += x.hp / maxf(1.0, x.max_hp)
	hpk /= float(up.size())
	if up.size() == 1 and hpk < 0.5:
		return 0.0
	return clampf(0.1 + 0.3 * float(h.ai.get("skill", 0.5)) + 0.15 * float(mini(up.size(), 4) - 1) + 0.3 * (hpk - 0.5), 0.0, 0.85)

## Where a camper waits: a few steps out from the gate, off to one side of the path.
func camp_spot(L: Dictionary, h: Hunter) -> Vector3:
	var out: Vector2 = L["out"]
	var sd := 1.0 if (hash(h.nid) % 2) == 0 else -1.0
	for k in [Vector2(3.5, 2.5), Vector2(4.5, 1.2), Vector2(3.0, 3.5), Vector2(2.5, 0.0)]:
		var p: Vector3 = L["dial"] + Vector3(out.x, 0, out.y) * k.x + Vector3(-out.y, 0, out.x) * k.y * sd
		if not m.world.is_void(p.x, p.z) and not m.world.is_block(p.x, p.z) and not inside(L, p, 1.0):
			return Vector3(p.x, m.world.ground_at(p.x, p.z), p.z)
	return L["dial"]

## Bots that reach a dropped egg pick it up (into the pack, dropping their least valuable thing if full).
func bot_pickups() -> void:
	for L in list:
		var wp = L.get("egg_wp")
		if wp == null or not m.wpicks.has(wp):
			continue
		for h in m.hunters:
			if h.ctrl != "bot" or h.out or h.downed or h.remote or h.dropping:
				continue
			if h.flat_dist(wp["pos"]) < 1.3 and absf(h.pos.y - float(wp["pos"].y)) < 1.2:
				var it := Pack.ground_item(wp)
				if not Pack.room(h):
					var li := Pack.lowest(h)
					if li >= 0:
						Pack.spawn_item(m, h.pack[li], Pack._near(h))
						h.pack.remove_at(li)
				Pack._off_ground(m, wp)
				h.pack.append(it)
				h.ai["leave"] = true
				m.sfx("pickup", h.pos, 0.0, 0.8)
				break

# ------------------------------------------------------------------ test hooks
## --lair-demo=puzzle|fight|egg|sealed|victory|updraft|outside: a scene set up for a screenshot ("sealed": just
## inside the gate after it has shut behind you; "victory": the boss just fallen, the gate still shut,
## you by the lever with the updraft blowing at the back; "updraft": the same, then you step into the
## updraft and ride it out over the back wall (LAIRDEMO lines time the ride); "outside": a rival squad sealed in with the
## boss and you outside its gate, the alert's beam over the lair and the seal's clock over the gate;
## "outside_map": the same with the full map open on the alert).
func demo(mode: String) -> void:
	if list.is_empty() or m.player == null:
		return
	var P: Hunter = m.player
	var pick := String(m.opts.get("demo_boss", ""))
	var L: Dictionary = list[0]
	for x in list:
		if String(x["boss"]) == pick: L = x
	activate(L)
	if m.has_meta("lair_demo_done"):
		if mode == "puzzle" and is_same(L["user"], P):
			# keep the needle sweeping and a lock half done for the shot
			pass
		if mode in ["fight", "sealed"]:
			var b: Boss = boss_of(L)
			if b and is_instance_valid(b) and not b.dead:
				P.hp = P.max_hp
				if not inside(L, P.pos, -1.0):
					var back: Vector3 = L["c"] + Vector3(L["out"].x, 0, L["out"].y) * (2.0 if mode == "fight" else float(L["half"]) - 2.6)
					P.teleport(Vector3(back.x, m.world.ground_at(back.x, back.z), back.z))
				for o in m.hunters:
					if o != P and o.team == P.team: o.hp = o.max_hp
		if mode in ["victory", "updraft"]:
			var b: Boss = boss_of(L)
			if b and not b.dead and L.get("locked", false):
				b.hurt(b.max_hp * 3.0, null, {"src": "test"})      # (no killer: no perk choice over the shot)
			if mode == "victory":
				m.cam.zoom = 1.9; m.cam.zoom_to = 1.9      # (the match eases the camera back to 1 every frame)
			if L.get("victory", false):
				L["victory_at"] = m.time - 2.2      # (hold the clock for the shot)
				P.hp = P.max_hp
				if mode == "updraft" and L.get("up_on", false) and not m.has_meta("updraft_demo"):
					# step into the escape updraft and ride it out (--shot-times= for the whole ride)
					m.set_meta("updraft_demo", m.time)
					var u: Vector3 = L["up"]
					P.teleport(Vector3(u.x, m.world.ground_at(u.x, u.z), u.z))
					print("LAIRDEMO into the updraft at %.1f" % m.time)
				if mode == "updraft" and m.has_meta("updraft_demo") and P.grounded and not inside(L, P.pos, 0.0) and not m.has_meta("updraft_landed"):
					m.set_meta("updraft_landed", m.time)
					print("LAIRDEMO landed outside at %.1f (%.1f s after stepping in)" % [m.time, m.time - float(m.get_meta("updraft_demo"))])
		if mode in ["outside", "outside_map"]:
			if mode == "outside_map" and m.hud and not m.hud.map_open() and L.get("locked", false) and m.time - float(L.get("alert_at", m.time)) > 0.8:
				m.hud.open_map()
			L["lock_at"] = m.time - 18.6
			P.hp = P.max_hp
			m.cam.zoom = 2.2; m.cam.zoom_to = 2.2
			for o in L.get("sealed_in", []):
				o.hp = o.max_hp
		return
	m.set_meta("lair_demo_done", true)
	for g in L["guards"]:
		if is_instance_valid(g): g.dead = true; g.visible = false
	for o in m.hunters:
		if o.team != P.team:
			o.teleport(m.world.spawns[-1] if not m.world.spawns.is_empty() else o.pos)
			o.ctrl = "idle"
	match mode:
		"puzzle":
			var at: Vector3 = L["dial"] + Vector3(L["out"].x, 0, L["out"].y) * 0.9
			P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
			_start_dial(L, P)
			L["grace"] = 0.0
			L["lock"] = 1
			_new_lock(L)
			L["targets"][0]["hit"] = true
			m.cam.snap(P.pos)
		"exterior":
			var at: Vector3 = L["dial"] + Vector3(L["out"].x, 0, L["out"].y) * 1.2 + Vector3(-L["out"].y, 0, L["out"].x) * 1.5
			P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
			m.cam.zoom_to = 1.7; m.cam.zoom = 1.7
			m.cam.snap(P.pos)
		"fight", "egg", "sealed":
			open(L, P, "dial")
			L["gate_k"] = 0.999
			var at: Vector3 = L["c"] + Vector3(L["out"].x, 0, L["out"].y) * (float(L["half"]) - 2.6 if mode == "sealed" else 2.0)
			P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
			for o in m.hunters:
				if o != P and o.team == P.team:
					o.teleport(P.pos + Vector3(-L["out"].y, 0, L["out"].x) * 2.0)
					o.ctrl = "idle"
			m.cam.snap(P.pos)
			wake(L, P)
			var b: Boss = boss_of(L)
			if mode == "egg" and b:
				b.hurt(b.max_hp * 2.0, P, {"src": "test"})
		"victory", "updraft":
			open(L, P, "dial")
			L["gate_k"] = 0.999
			var out: Vector3 = Vector3(L["out"].x, 0, L["out"].y)
			var side := Vector3(-L["out"].y, 0, L["out"].x)
			var at: Vector3 = L["lever"] - out * 1.0 + side * 0.8
			P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
			for o in m.hunters:
				if o != P and o.team == P.team:
					var q: Vector3 = L["up"] + out * 2.2 + side * 1.2
					o.teleport(Vector3(q.x, m.world.ground_at(q.x, q.z), q.z))
					o.ctrl = "idle"
			if mode == "victory":
				m.cam.zoom_to = 2.0; m.cam.zoom = 2.0
			m.cam.snap(P.pos)
			wake(L, P)
		"outside", "outside_map":
			open(L, P, "dial")
			L["gate_k"] = 0.999
			var out: Vector3 = Vector3(L["out"].x, 0, L["out"].y)
			var side := Vector3(-L["out"].y, 0, L["out"].x)
			# a rival squad inside with the boss
			var n := 0
			for o in m.hunters:
				if o.team != P.team and n < 2:
					var q: Vector3 = L["c"] + side * (n * 2.0 - 1.0) * 1.6 + out * 1.5
					o.teleport(Vector3(q.x, m.world.ground_at(q.x, q.z), q.z))
					o.ctrl = "idle"
					n += 1
			var at: Vector3 = L["dial"] + out * 1.4 + side * 1.6
			P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
			for o in m.hunters:
				if o != P and o.team == P.team:
					o.teleport(P.pos + side * -2.2)
					o.ctrl = "idle"
			m.cam.zoom_to = 2.3; m.cam.zoom = 2.3
			m.cam.snap(P.pos)
			var b: Boss = boss_of(L)
			if b: wake(L, b.tgt if b.tgt else P)
