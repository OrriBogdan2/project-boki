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
var fight: LairsFight
var lock: LairsLock
var bots: LairsBots
var demo_scene: LairsDemo

func setup(match_node: Match) -> void:
	m = match_node
	fight = LairsFight.new(self)
	lock = LairsLock.new(self)
	bots = LairsBots.new(self)
	demo_scene = LairsDemo.new(self)
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
	lock._loud(L, rn["pos"], h, "A rune flares at %s" % L["name"])
	lock._call_guards(L, rn["pos"], 2)
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
	lock._loud(L, L["dial"], h, "A lock chime rings out at %s" % L["name"])
	lock._call_guards(L, L["dial"], 2 + mini(int(m.tier), 1))
	if h == m.player and m.hud:
		m.hud.toast("MISSED  ·  the lock resets and the chime calls guards", Color("ff8a6a"))

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
			bots._bot_dial(L, h, dt)
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

# ------------------------------------------------------------------ every tick
func tick(dt: float) -> void:
	if list.is_empty():
		return
	for L in list:
		_tick_dial(L, dt)
		lock._tick_seal(L, dt)
		lock._tick_lock(L, dt)
		lock._tick_gate(L, dt)
		lock._tick_runes(L, dt)
		fight._tick_egg(L)
		_tick_show(L)
		if not L.get("up_on", false) and not (L.get("flown", []) as Array).is_empty():
			lock._tick_flyers(L)
		if L["state"] in ["open", "awake"] and not L.get("locked", false) and m.time >= float(L.get("calm_until", 0.0)) and (not m.net_on or m.is_host):
			for h in m.hunters:
				if not h.out and not h.extracted and not h.dropping and not h.downed and inside(L, h.pos, -0.6):
					if L["state"] == "open": fight.wake(L, h)
					else: lock.lock_in(L)       # woken from outside (a shot through the gate): seals once someone steps in
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
		fight._music(false)

## What a lair shows the world while its fight is on: the seal's clock over the gate (it floats there
## for anyone outside to read), and the shaft of light over it, pulsing, until the news is old.
func _tick_show(L: Dictionary) -> void:
	var nodes: Dictionary = L.get("nodes", {})
	if L.get("locked", false):
		var lbl: Label3D = nodes["label"]
		var b: Boss = boss_of(L)
		var bn := String(b.md["name"]) if b else "The boss"
		if L.get("victory", false):
			lbl.text = "%s\n%s has fallen  ·  gate opens %s" % [L["name"], bn, clock(lock.victory_left(L))]
		else:
			lbl.text = "%s\n%s FIGHT  ·  %s" % [L["name"], bn.to_upper(), clock(lock.lock_left(L))]
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
	if is_instance_valid(beam) and (beam.visible or (lock.alert_on(L) and beam.has_meta("hid"))):
		# (it's for those outside: hidden for whoever is in the lair, where it would only glare)
		var in_it: bool = m.player != null and inside(L, m.player.pos, 1.0)
		beam.set_meta("hid", in_it)
		if not lock.alert_on(L) or in_it:
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

# ------------------------------------------------------------------ parts (moved out; the public API stays here)
func wake(L: Dictionary, by: Ent) -> void:
	fight.wake(L,by)

func reset_boss(b: Boss) -> void:
	fight.reset_boss(b)

func on_boss_phase(b: Boss, p: int) -> void:
	fight.on_boss_phase(b,p)

func on_enrage(b: Boss) -> void:
	fight.on_enrage(b)

func spawn_add(L: Dictionary, kind: String, at: Vector3) -> void:
	fight.spawn_add(L,kind,at)

func on_mob_dead(mb: Mob, credit: Ent) -> void:
	fight.on_mob_dead(mb,credit)

func on_ward_hit(mb: Mob, by: Ent) -> void:
	fight.on_ward_hit(mb,by)

func _floor_spot(L: Dictionary, p: Vector3, margin: float) -> Vector3:
	return fight._floor_spot(L,p,margin)

func alerted(L: Dictionary, h: Hunter) -> bool:
	return lock.alerted(L,h)

func victory_left(L: Dictionary) -> float:
	return lock.victory_left(L)

func may_fly(L: Dictionary, h: Hunter) -> bool:
	return lock.may_fly(L,h)

func walled_off(h: Hunter, p: Vector3) -> bool:
	return lock.walled_off(h,p)

func sealed_lair(h: Hunter) -> Dictionary:
	return lock.sealed_lair(h)

func lock_left(L: Dictionary) -> float:
	return lock.lock_left(L)

func bot_goal(h: Hunter, leaving: bool) -> Array:
	return bots.bot_goal(h,leaving)

func campers(L: Dictionary, team: int) -> int:
	return bots.campers(L,team)

func camp_odds(h: Hunter) -> float:
	return bots.camp_odds(h)

func camp_spot(L: Dictionary, h: Hunter) -> Vector3:
	return bots.camp_spot(L,h)

func bot_pickups() -> void:
	bots.bot_pickups()

func demo(mode: String) -> void:
	demo_scene.demo(mode)
