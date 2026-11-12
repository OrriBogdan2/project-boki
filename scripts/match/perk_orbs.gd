class_name PerkOrbs
extends RefCounted
## Perk orbs: how perks are found in a match. Chests drop one, shrines one or two, bosses a fan of
## three different ones. An orb floats and bobs in its perk's colour with its icon and name over it;
## walk into it to take it (no prompt, no choice screen). Taking one from a boss's fan fades the other
## two for you only: everyone else can still take them. Orbs sync over Net like ground pickups.
## Numbers and the pool live in content/rules/perk_orbs.json; the perks themselves are Data.PERKS.
##
## Public API (other systems call these):
##   PerkOrbs.drop(m, source, pos, n := 0, h := null) -> Array   orbs from "chest" / "shrine" / "boss" / "brute"
##   PerkOrbs.spawn(m, perk_id, pos, id := "", fan := "", send := true) -> Dictionary   one orb of a chosen perk (a shop can use it)
##   PerkOrbs.grant(h, perk_id) -> bool   gives a hunter a perk with the pickup feedback
##   PerkOrbs.list(m) -> Array   the orbs on the ground
##   PerkOrbs.gem_mult(h) -> float   the multiplier on gems a hunter picks up (Scavenger, Magpie Pouch)

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/perk_orbs.json"))
		_rules = d if d is Dictionary else {}
	return _rules

## The match's orb state, kept on the match itself: {list, fan (fan id -> {nid: true}), n, rng, icons, peers (count)}.
static func st(m) -> Dictionary:
	if not m.has_meta("perk_orbs"):
		var r := RandomNumberGenerator.new()
		r.seed = hash("orbs%d" % int(m.opts.get("seed", 0)))      # its own stream: orbs never shift the match's rolls
		m.set_meta("perk_orbs", {"list": [], "fan": {}, "n": 0, "rng": r, "icons": {}})
	return m.get_meta("perk_orbs")

static func list(m) -> Array:
	return st(m)["list"]

static func gem_mult(h) -> float:
	return 1.0 + 0.25 * float(h.perk_n("scavenger")) + h.gear_stat("gems")

# ------------------------------------------------------------------ rolling

static func kind_of(id: String) -> String:
	var ks: Dictionary = rules().get("kinds", {})
	for k in ks:
		if (ks[k] as Array).has(id):
			return String(k)
	return ""

## One perk id for a source, favouring the kinds that source leans to. h (who earned it) skips perks
## they have maxed; exclude skips ids already in the same drop. "" when nothing is left.
static func roll(rng: RandomNumberGenerator, source: String, h = null, exclude := []) -> String:
	var rs: Dictionary = rules()
	var lean: Dictionary = (rs.get("sources", {}).get(source, {}) as Dictionary).get("lean", {})
	var wts: Dictionary = rs.get("weights", {})
	var ids: Array = []
	var ws: Array = []
	var tot := 0.0
	var kinds: Dictionary = rs.get("kinds", {})
	var names: Array = kinds.keys()
	names.sort()
	for k in names:
		for id in kinds[k]:
			if not Data.PERKS.has(id) or exclude.has(id) or (h != null and not h.perk_open(id)):
				continue
			var w := float(lean.get(k, 1.0)) * float(wts.get(id, 1.0))
			ids.append(id); ws.append(w); tot += w
	if ids.is_empty():
		return ""
	var r := rng.randf() * tot
	for i in ids.size():
		r -= float(ws[i])
		if r <= 0.0:
			return String(ids[i])
	return String(ids[ids.size() - 1])

# ------------------------------------------------------------------ dropping

## Drops orbs for a source at a point. n = 0 uses the source's own count. h is who earned them: it
## picks perks they can still use, and a fan opens toward them. A boss (or any source marked "fan")
## drops three different orbs in a fan; the others are spaced round the point.
static func drop(m, source: String, pos: Vector3, n := 0, h = null) -> Array:
	var s := st(m)
	var rng: RandomNumberGenerator = s["rng"]
	var rs: Dictionary = rules()
	var src: Dictionary = (rs.get("sources", {}) as Dictionary).get(source, {})
	if n <= 0:
		var span: Array = src.get("n", [1, 1])
		n = rng.randi_range(int(span[0]), int(span[1]))
	var picks: Array = []
	for i in n:
		var id := roll(rng, source, h, picks)
		if id == "":
			id = roll(rng, source, null, picks)      # everything open to them is taken: any perk still shows up
		if id == "":
			break
		picks.append(id)
	var fan := ""
	if bool(src.get("fan", false)) and picks.size() > 1:
		s["n"] = int(s["n"]) + 1
		fan = "f%s_%d" % [m.player.nid if m.player else "x", int(s["n"])]
		s["fan"][fan] = {}
	var out: Array = []
	var face := rng.randf() * TAU
	if h != null and h.flat_dist(pos) > 0.5:
		face = atan2(h.pos.z - pos.z, h.pos.x - pos.x)
	for i in picks.size():
		var a := face
		var r := 1.3
		if fan != "":
			a = face + (float(i) - float(picks.size() - 1) * 0.5) * float(rs.get("fan_spread", 0.7))
			r = float(rs.get("fan_radius", 2.4))
		elif picks.size() > 1:
			a = face + TAU * float(i) / float(picks.size())
		out.append(spawn(m, String(picks[i]), _spot(m, pos, a, r), "", fan))
	return out

## A ground spot at angle a, radius r from a point, pulled in toward the point if it's void or a wall.
static func _spot(m, at: Vector3, a: float, r: float) -> Vector3:
	for k in [1.0, 0.7, 0.4, 0.0]:
		var x: float = at.x + cos(a) * r * k
		var z: float = at.z + sin(a) * r * k
		if k == 0.0 or not (m.world.is_void(x, z) or m.world.is_block(x, z)):
			return Vector3(x, maxf(m.world.ground_at(x, z), at.y - 1.5) if k > 0.0 else at.y, z)
	return at

## One orb of a given perk at a spot. fan joins it to a fan. Online the others get it too (send).
static func spawn(m, perk: String, at: Vector3, id := "", fan := "", send := true) -> Dictionary:
	var s := st(m)
	if id == "":
		s["n"] = int(s["n"]) + 1
		id = "o%s_%d" % [m.player.nid if m.player else "x", int(s["n"])]
	if fan != "" and not (s["fan"] as Dictionary).has(fan):
		s["fan"][fan] = {}
	var node := _build(m, perk)
	node.position = at
	m.add_child(node)
	var o := {"id": id, "perk": perk, "pos": at, "fan": fan, "node": node, "ph": float(at.x) * 1.7 + float(at.z), "faded": false}
	(s["list"] as Array).append(o)
	if m.net_on and send:
		_announce(m, o)
	return o

static func _announce(m, o: Dictionary) -> void:
	var at: Vector3 = o["pos"]
	m.net_event(["odrop", o["id"], o["perk"], o["fan"], m._r(at.x), m._r(at.y), m._r(at.z)])

## When a player joins, the host re-sends every live orb so the late joiner sees them.
static func _greet_joiners(m, s: Dictionary) -> void:
	if not m.net_on or not Net.is_host():
		return
	var count: int = Net.peers.size()
	if count > int(s.get("peers", count)):
		for o in s["list"]:
			_announce(m, o)
	s["peers"] = count

## The look: a glowing core with a ring, motes, the perk's icon and its name floating above, all in its colour.
static func _build(m, perk: String) -> Node3D:
	var pd: Dictionary = Data.PERKS[perk]
	var col: Color = pd["col"]
	var root := Node3D.new()
	var ring := MeshInstance3D.new()
	ring.mesh = Models.flat_quad(1.7)
	ring.material_override = Models.ring_mat(Color(col, 0.55), 0.12)
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var beam := Models.part(root, Models.cyl(0.07, 0.14, 3.2, 10), Models.glow_mat(Color(col, 0.2)), Vector3(0, 1.6, 0), Vector3.ONE, Vector3.ZERO, "Beam")
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bob := Node3D.new(); bob.name = "Bob"; bob.position = Vector3(0, 0.95, 0); root.add_child(bob)
	var spin := Node3D.new(); spin.name = "Spin"; bob.add_child(spin)
	Models.part(spin, Models.sphere(0.2, 12), Models.toon(col, true, 0.9), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "Core")
	var tor := TorusMesh.new(); tor.inner_radius = 0.3; tor.outer_radius = 0.35
	Models.part(spin, tor, Models.toon(col.lightened(0.3), false, 0.8), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0.4, 0), "Halo")
	var sp := Sprite3D.new()
	sp.name = "Icon"
	sp.texture = _icon_tex(m, perk)
	sp.pixel_size = 0.0085
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false; sp.double_sided = true
	sp.position = Vector3(0, 0.85, 0)
	bob.add_child(sp)
	var lb := Label3D.new()
	lb.name = "Name"
	lb.text = String(pd["name"])
	lb.font = UI.big; lb.font_size = 30; lb.pixel_size = 0.0085; lb.outline_size = 10
	lb.modulate = col
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.no_depth_test = true
	lb.position = Vector3(0, 1.75, 0)
	bob.add_child(lb)
	m._element_motes(root, col, true)
	return root

## The icon texture for a perk: drawn once into a tiny SubViewport (kept for the match).
static func _icon_tex(m, perk: String) -> Texture2D:
	var s := st(m)
	var cache: Dictionary = s["icons"]
	if not cache.has(perk):
		var vp := SubViewport.new()
		vp.size = Vector2i(96, 96)
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var pd: Dictionary = Data.PERKS[perk]
		var ctl := IconCtl.new()
		ctl.perk_icon = String(pd["icon"]); ctl.col = pd["col"]
		ctl.size = Vector2(96, 96)
		vp.add_child(ctl)
		m.add_child(vp)
		cache[perk] = vp
	return (cache[perk] as SubViewport).get_texture()

class IconCtl extends Control:
	var perk_icon := ""
	var col := Color.WHITE
	func _draw() -> void:
		draw_circle(Vector2(48, 48), 44.0, Color(0.04, 0.05, 0.09, 0.82))
		draw_arc(Vector2(48, 48), 42.0, 0.0, TAU, 40, Color(col, 0.95), 4.0, true)
		Icons.draw(self, perk_icon, Vector2(48, 48), 24.0, col)

# ------------------------------------------------------------------ taking

## Is this orb still open to this hunter? Maxed on the perk, or already took from its fan: not.
static func can_take(m, h, o: Dictionary) -> bool:
	if not h.perk_open(String(o["perk"])):
		return false
	return not took_from_fan(m, h.nid, o)

static func took_from_fan(m, nid: String, o: Dictionary) -> bool:
	var fan := String(o["fan"])
	return fan != "" and (st(m)["fan"].get(fan, {}) as Dictionary).has(nid)

## A hunter takes an orb (from_net: the other player's game already did, so just record it).
static func take(m, h, o: Dictionary, nid := "", from_net := false) -> void:
	var s := st(m)
	if not (s["list"] as Array).has(o):
		return
	(s["list"] as Array).erase(o)
	if is_instance_valid(o["node"]):
		(o["node"] as Node).queue_free()
	var who: String = h.nid if h != null else nid
	if String(o["fan"]) != "":
		s["fan"][String(o["fan"])][who] = true
	if from_net or h == null:
		return
	if m.net_on:
		m.net_event(["otake", o["id"], who])
	grant(h, String(o["perk"]))

## Gives a hunter a perk with the pickup feedback: a ring, a word, a toast for you.
static func grant(h, perk: String) -> bool:
	if not Data.PERKS.has(perk) or not h.perk_open(perk):
		return false
	h.add_perk(perk)
	var m = h.m
	var pd: Dictionary = Data.PERKS[perk]
	if m != null and m.fx != null:
		m.sfx("bond", h.pos, -4.0, 1.3)
		m.fx.ring(h.pos, 1.6, pd["col"], 0.35)
		m.fx.burst(h.pos + Vector3(0, 1.0, 0), pd["col"], 16, 3.2, 0.5, -2.0)
		if h == m.player:
			m.fx.word(h.pos + Vector3(0, 2.4, 0), String(pd["name"]).to_upper(), pd["col"], true)
			if m.hud:
				m.hud.toast("%s  ·  %s" % [pd["name"], pd["desc"]], pd["col"])
	return true

# ------------------------------------------------------------------ per frame

## Bob and spin the orbs, fade a fan you've taken from, and let hunters walk into them.
static func update(m, dt: float) -> void:
	var s := st(m)
	_greet_joiners(m, s)
	var orbs: Array = s["list"]
	if orbs.is_empty():
		return
	var t: float = m.time
	var me = m.player
	for o in orbs:
		var n: Node3D = o["node"]
		var bob: Node3D = n.get_node("Bob")
		bob.position.y = 0.95 + sin(t * 2.2 + float(o["ph"])) * 0.12
		(bob.get_node("Spin") as Node3D).rotation.y += dt * 1.8
		var gone: bool = me != null and took_from_fan(m, me.nid, o)
		if gone != bool(o["faded"]):
			_fade(o, gone)
	var r := float(rules().get("take_radius", 1.2))
	for h in m.hunters:
		if h.out or h.downed or h.dropping or h.riding or h.remote or h.extracted:
			continue
		for o in orbs:
			var d: float = h.flat_dist(o["pos"])
			if d >= r + (0.2 if h.ctrl == "bot" else 0.0) or absf(h.pos.y - float(o["pos"].y)) >= 1.5:
				continue
			if not can_take(m, h, o) or (h.ctrl == "bot" and not best_in_fan(m, h, o)):
				continue
			take(m, h, o)
			break

## Fades a fan orb out for the local player (or back in): only the picture changes, the orb is still there for others.
static func _fade(o: Dictionary, on: bool) -> void:
	o["faded"] = on
	var n: Node3D = o["node"]
	var bob: Node3D = n.get_node("Bob")
	var a := 0.16 if on else 1.0
	var col: Color = Data.PERKS[String(o["perk"])]["col"]
	(bob.get_node("Name") as Label3D).modulate = Color(col, a)
	(bob.get_node("Icon") as Sprite3D).modulate = Color(1, 1, 1, a)
	for nm in ["Spin"]:
		(bob.get_node(nm) as Node3D).visible = not on
	(n.get_node("Beam") as Node3D).visible = not on
	for c in n.get_children():
		if c is CPUParticles3D:
			(c as CPUParticles3D).emitting = not on

## Remote events: another player's game dropped or took an orb.
static func on_net(m, x: Array) -> void:
	match String(x[0]):
		"odrop":
			for o in list(m):
				if o["id"] == String(x[1]):
					return
			if Data.PERKS.has(String(x[2])):
				spawn(m, String(x[2]), Vector3(x[4], x[5], x[6]), String(x[1]), String(x[3]), false)
		"otake":
			for o in list(m):
				if o["id"] == String(x[1]):
					take(m, m.ents_by_id.get(String(x[2]), null), o, String(x[2]), true)
					break

# ------------------------------------------------------------------ tooling

## Test hook (--perk-demo): a couple of perks already taken, a boss's fan of three orbs near the player,
## then a level-up 3s later. With --chest-demo instead: the nearest chest is opened and drops its orb.
static func demo(m) -> void:
	var P = m.player
	for id in ["keen", "keen", "toughskin"]:
		P.add_perk(id)
	if m.opts.get("chest_demo", false):
		var near: Dictionary = {}
		for c in m.chests:
			if not c["open"] and (near.is_empty() or P.flat_dist(c["pos"]) < P.flat_dist(near["pos"])):
				near = c
		if not near.is_empty():
			m._open_chest(P, near)
		return
	drop(m, "boss", P.pos + Vector3(0, 0, -5.0), 3, P)
	m.get_tree().create_timer(3.0, false).timeout.connect(func(): if is_instance_valid(P): P.gain_xp(float(Hunter.XP_TO[1]) - P.xp + 1.0))      # then a level-up

# ------------------------------------------------------------------ bots

## How much a bot wants a perk: higher goes first. 0 when they can't take it.
static func want(h, perk: String) -> float:
	if not h.perk_open(perk):
		return 0.0
	var bw: Dictionary = rules().get("bot_want", {})
	return float(bw.get(perk, bw.get("default", 1.5))) - 0.25 * float(h.perk_n(perk))

## Of the orbs in one fan, the one this bot wants most (it never takes two). Always true off a fan.
static func best_in_fan(m, h, o: Dictionary) -> bool:
	if String(o["fan"]) == "":
		return true
	var mine := want(h, String(o["perk"]))
	for q in list(m):
		if q != o and q["fan"] == o["fan"] and can_take(m, h, q):
			var theirs := want(h, String(q["perk"]))
			if theirs > mine + 0.001 or (absf(theirs - mine) <= 0.001 and String(q["id"]) < String(o["id"])):
				return false
	return true

## Where a bot should walk to pick up an orb it wants, INF when there's none in reach.
## cur is its current goal (so it sticks with the one it's heading for).
static func bot_goal(m, h, cur: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := float(rules().get("bot_radius", 16.0))
	for o in list(m):
		var p: Vector3 = o["pos"]
		if not can_take(m, h, o) or not best_in_fan(m, h, o) or m.world.is_void(p.x, p.z):
			continue
		if m.lairs and m.lairs.walled_off(h, p):
			continue
		var d: float = h.flat_dist(p) - (3.0 if p.distance_to(cur) < 0.5 else 0.0) - want(h, String(o["perk"]))
		if d < bd:
			bd = d; best = p
	return best
