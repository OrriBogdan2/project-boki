class_name HomeGather
extends RefCounted
## Light survival at home. Buy an axe at the market (Farm tab) and you can chop the wild trees on
## your island for wood; buy a pickaxe and you can mine its boulders for stone (cliffs stay put).
## Walk up to one and hold use: the right tool (an axe, a pickaxe) comes out, the weapon goes away, and
## it swings until you let go; three hits and it comes down (it keeps the hits you gave it). What you cut
## grows back slowly
## (the layout's "regrow" list, HomeBuild.regrow_due), so the wild never runs out. Wood and stone
## go into Save.d["mats"] (Work.add_mat) and pay for buildings and stations in build mode.
## home.gd calls find(p2) from _find_interact, label(it) / use(it) for the prompt, tick(d) every
## frame and busy() while you're mid-chop (the swing itself is ToolWork, the pose HunterTool).

## The tools: what each cuts, what that gives, its price at the market.
const TOOLS := {
	"axe": {"name": "Axe", "price": 35, "what": "tree", "mat": "wood", "n": 3, "col": Color("b0784a"),
		"desc": "Chop the wild trees on your island for wood (they grow back)."},
	"pickaxe": {"name": "Pickaxe", "price": 45, "what": "rock", "mat": "stone", "n": 3, "col": Color("a8b0c4"),
		"desc": "Mine the wild boulders on your island for stone (they grow back)."},
}
## Seconds before a chopped tree or a mined boulder grows back (real time: it carries on while
## you're out on an expedition).
const REGROW := {"tree": 900.0, "rock": 1500.0}
const HITS := 3
const REACH := 1.55
## Wood chips, rock chips and falling leaves, by what is being worked.
const CHIP_COL := {"tree": Color("c8955a"), "rock": Color("b8b4ae")}
const LEAF_COL := Color("6fb35a")
const TREE_TOP_Y := 2.2          # m: where the leaves shake loose
const CRACK_COL := Color("2a2622")

var h                                    # the Home screen
var tile := -1                           # the wild tile being worked
var damage := {}                         # tile index -> hits it has taken (it keeps them when you stop)
var cracks := {}                         # tile index -> the crack marks drawn on a boulder
var regrow_t := 1.0

func _init(home) -> void:
	h = home

static func has_tool(t: String) -> bool:
	return (Save.d.get("tools", []) as Array).has(t)

static func give_tool(t: String) -> void:
	if typeof(Save.d.get("tools")) != TYPE_ARRAY: Save.d["tools"] = []
	if not (Save.d["tools"] as Array).has(t): Save.d["tools"].append(t)

static func tool_for(what: String) -> String:
	for t in TOOLS:
		if String(TOOLS[t]["what"]) == what: return t
	return ""

## The market's Farm tab: the tools you don't have yet. [key, name, description, price, colour, on_buy, owned_text]
static func shop_goods() -> Array:
	var out: Array = []
	for t in TOOLS:
		var td: Dictionary = TOOLS[t]
		var tk: String = t
		out.append(["tool:" + t, td["name"], td["desc"], -1 if has_tool(t) else int(td["price"]), td["col"], func(): give_tool(tk), "yours" if has_tool(t) else ""])
	return out

func busy() -> bool:
	return tile >= 0 and h.tw.active()

## The nearest wild tree or boulder within reach of p2, as an interact entry (or {}).
func find(p2: Vector2) -> Dictionary:
	if h.hb == null or not h.visit.is_empty():
		return {}
	var w: World = h.world
	var cx := int(floor(p2.x)); var cz := int(floor(p2.y))
	var best := {}; var bd := REACH
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var x := cx + dx; var z := cz + dz
			if not w.inb(x, z): continue
			var i := w.idx(x, z)
			var what := String(h.hb.wild_t.get(i, ""))
			if what != "tree" and what != "rock": continue
			# the nearest point of the tile, so you can chop from any side
			var q := Vector2(clampf(p2.x, x, x + 1.0), clampf(p2.y, z, z + 1.0))
			var dd := p2.distance_to(q) + 0.3
			if dd < bd: bd = dd; best = {"kind": "wild", "i": i, "what": what, "d": dd}
	return best

func label(it: Dictionary) -> String:
	var t := tool_for(String(it["what"]))
	if not has_tool(t):
		return "Needs a%s %s (Market, Farm tab)" % ["n" if t == "axe" else "", String(TOOLS[t]["name"]).to_lower()]
	return "Chop the tree" if it["what"] == "tree" else "Mine the boulder"

func use(it: Dictionary) -> void:
	if h.water.swimming:
		h._toast("Not while you're swimming")
		return
	if it.is_empty() or not it.has("what"):
		return
	var t := tool_for(String(it["what"]))
	if not has_tool(t):
		h._toast("Needs a%s %s (Market)" % ["n" if t == "axe" else "", String(TOOLS[t]["name"]).to_lower()])
		return
	var w: World = h.world
	tile = int(it["i"])
	h.tw.begin(t, Vector3(tile % w.w + 0.5, 0, tile / w.w + 0.5), _hit, HunterTool.period(t) * 0.4)

func cancel() -> void:
	h.tw.stop()
	tile = -1

func tick(d: float) -> void:
	if not h.visit.is_empty() or h.hb == null:
		return
	regrow_t -= d
	if regrow_t <= 0.0:
		regrow_t = 5.0
		h.hb.regrow_due()
	if tile < 0:
		return
	# walking away (or the tile going) stops it
	var mv := Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))
	if mv.length() > 0.2 or not h.hb.wild_t.has(tile) or h.panel_open != "" or (h.hb and h.hb.active):
		cancel()
		return
	h.tw.tick(d, h.tw.held())
	if not h.tw.active():
		tile = -1

## The head lands: chips, a sound, the target reacting. False once it is down (or gone).
func _hit() -> bool:
	if not h.hb.wild_t.has(tile):
		return false
	var w: World = h.world
	var at := Vector3(tile % w.w + 0.5, 0, tile / w.w + 0.5)
	var tree: bool = h.hb.wild_t[tile] == "tree"
	var hits := int(damage.get(tile, 0)) + 1
	damage[tile] = hits
	if h.fx:
		var chip_y := 0.9
		if not tree:
			chip_y = 0.5
		h.fx.burst(at + Vector3(0, chip_y, 0), CHIP_COL[String(h.hb.wild_t[tile])], 10, 2.6)
		if tree:
			h.fx.burst(at + Vector3(0, TREE_TOP_Y, 0), LEAF_COL, 6, 1.0, 0.9, 2.0)
		else:
			h.fx.spark(at + Vector3(0, 0.6, 0), Vector3.UP, Color("ffe2a0"), 6, 5.0, 70.0)
	Sfx.play("break_wood" if tree else "armor_hit", at, -6.0, 0.1)
	Sfx.play("rustle" if tree else "thump", at, -10.0, 0.1, 0.8)
	if not tree:
		_crack(at, hits)
	if hits >= HITS and demo_loop:
		damage[tile] = 0
	elif hits >= HITS:
		finish()
		return false
	return true

## Dark cracks on the boulder, one more for every hit.
func _crack(at: Vector3, hits: int) -> void:
	var holder: Node3D = cracks.get(tile)
	if holder == null or not is_instance_valid(holder):
		holder = Node3D.new()
		holder.position = at
		h.add_child(holder)
		cracks[tile] = holder
	var mat := Models.toon(CRACK_COL, false)
	var ang := float(hits) * 2.1 + float(tile)
	var at_rock := Vector3(sin(ang) * 0.35, 0.5 + float(hits) * 0.08, 0.7)      # on the face you see from the south
	Models.part(holder, Models.box(0.07, 0.6, 0.07), mat, at_rock, Vector3.ONE, Vector3(0.4, ang, 0.7))

## The last hit: it comes down, you get its wood or stone, and it starts growing back.
func finish() -> int:
	var w: World = h.world
	var i := tile
	var what := String(h.hb.wild_t.get(i, ""))
	var at := Vector3(i % w.w + 0.5, 0, i / w.w + 0.5)
	damage.erase(i)
	if cracks.has(i):
		(cracks[i] as Node3D).queue_free()
		cracks.erase(i)
	tile = -1
	if not h.hb.clear_wild(Vector2i(i % w.w, i / w.w), float(REGROW.get(what, 900.0))):
		return 0
	h.hb.mesh_t = 0.05
	h.hb.ver += 1
	h.hb._reach_cache.clear()
	h.hb.refresh_grid()
	var td: Dictionary = TOOLS[tool_for(what)]
	var n := int(td["n"]) + (1 if randf() < 0.3 else 0)
	Work.add_mat(String(td["mat"]), n)
	Work.count(String(td["mat"]), n)
	_fall(at, what)
	if h.fx:
		h.fx.dust(at, 14)
		h.fx.word(at + Vector3(0, 1.4, 0), "+%d %s" % [n, td["mat"]], Color(td["col"]).lightened(0.3))
	Sfx.play("pickup", at, -8.0, 0.1, 1.1)
	h._refresh_top()
	Save.save_game()
	return n

## A stand-in that topples (a tree) or crumbles (a boulder) while the ground is rebuilt under it.
func _fall(at: Vector3, what: String) -> void:
	var n: Node3D = null
	var rng := RandomNumberGenerator.new(); rng.seed = int(at.x * 131 + at.z * 7)
	if Flora.on():
		n = Flora.node("tree" if what == "tree" else "rock", "meadow", rng.randi_range(0, Flora.VARIANTS - 1), 0.85 if what == "tree" else 0.9)
	if n == null:
		n = Models.tree(rng, Color("5a9a4f"), "round") if what == "tree" else Models.rock(rng, 1.0)
	n.position = at
	h.add_child(n)
	var tw := n.create_tween()
	if what == "tree":
		var away := Vector3(at.x - h.ppos.x, 0, at.z - h.ppos.z).normalized()
		var axis := Vector3.UP.cross(away).normalized()
		if axis.length() < 0.1: axis = Vector3.RIGHT
		tw.tween_method(func(k: float): if is_instance_valid(n): n.basis = Basis(axis, k * PI * 0.48), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.35)
	else:
		tw.tween_property(n, "scale", Vector3(1.2, 0.2, 1.2), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.2)
	tw.tween_callback(n.queue_free)

# ------------------------------------------------------------------ tooling: --farm-demo
var demo_loop := false                   # screenshots: keep swinging, never finish

## A brand new farm-start save for screenshots (never written): one Boki, the farm-start gems, an
## island from seed. "station" adds a few Boki with knacks for the stations and some wood.
static func demo_save(which: String, seed: int) -> Dictionary:
	var d := Save.fresh()
	var pip := Save.new_kin("zapple", "Pip")
	pip["starter"] = true
	d["roster"].append(pip); d["active"] = pip["uid"]
	if which in ["station", "panel", "chop", "busy"]:
		for p in [["pebbit", "Rocky"], ["burrlet", "Moss"], ["cindle", "Ash"]]:
			var r := Save.new_kin(p[0], p[1])
			r["level"] = 5; r["trust"] = 70.0
			d["roster"].append(r)
	for r in d["roster"]:
		Care.ensure(r)
		for n in Care.NEEDS: r["needs"][n] = 95.0
	HomeLayout.new_fs(d, seed)
	d["tutorial"] = {"home": true, "day1_done": which != "busy"}
	if which == "busy":
		d["tutorial"]["ft"] = {"did": {"axe": true}, "done": false, "skipped": false, "gift": false}
	if which != "empty" and which != "ghost":
		d["tools"] = ["axe", "pickaxe"]
		d["mats"] = {"wood": 14, "stone": 6}
	if which == "busy":
		d["tools"] = ["axe"]
		d["mats"] = {}
	return d

## Puts a catalog item down on the nearest spot to `near` it fits (no charge). Returns its entry.
func demo_place(id: String, near: Vector3, r := 0, min_d := 0.0) -> Dictionary:
	var hb: HomeBuild = h.hb
	var item := {"kind": "deco", "id": id, "r": r, "from": -1}
	var sz := HomeLayout.size_of(id, r)
	for rad in range(int(min_d), 22):
		for k in 48:
			var a := float(k) / 48.0 * TAU
			var x := int(round(near.x + cos(a) * rad - sz.x * 0.5)); var z := int(round(near.z + sin(a) * rad - sz.y * 0.5))
			var cs := HomeLayout.cells_of([x, z, x + sz.x - 1, z + sz.y - 1])
			if hb.fits(item, cs):
				var lay := hb.L()
				var e := {"u": HomeLayout._next_uid(lay), "id": id, "x": x, "z": z, "r": r}
				lay["deco"].append(e)
				hb.apply(false)
				return e
	return {}

## The nearest wild tile of a kind to p (tile index, or -1).
func nearest_wild(p: Vector3, what: String) -> int:
	var w: World = h.world
	var best := -1; var bd := 1e9
	for i in h.hb.wild_t:
		if h.hb.wild_t[i] != what: continue
		var dd := Vector2(i % w.w + 0.5 - p.x, i / w.w + 0.5 - p.z).length()
		if dd < bd: bd = dd; best = i
	return best

## An open tile beside wild tile i, the side nearest p.
func beside(i: int, p: Vector3) -> Vector3:
	var w: World = h.world
	var best := Vector3.INF; var bd := 1e9
	for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x: int = i % w.w + dv.x; var z: int = i / w.w + dv.y
		if not w.inb(x, z) or w.kind[w.idx(x, z)] != World.T_GROUND: continue
		var q := Vector3(x + 0.5, 0, z + 0.5)
		var dd := Vector2(q.x - p.x, q.z - p.z).length()
		if dd < bd: bd = dd; best = q
	return best

func demo(which: String) -> void:
	h.day_t = 0.42
	var cam: CamRig = h.cam
	var land := HomeLayout.LANDING
	match which:
		"empty":
			# the whole island from above, as a new save first sees it
			h.ppos = land; h.player.position = land
			for k in h.kins:
				k["pos"] = land + Vector3(6.0, 0, 4.5); (k["node"] as Node3D).position = k["pos"]; k["t"] = 999.0; k["goal"] = k["pos"]
			cam.zoom_to = 2.5; cam.zoom = 2.5; cam.snap(Vector3(44, 0, 34))
		"ghost", "ghostbad":
			# build mode holding the house: on open meadow (green), or turned and pushed into the
			# wild where it doesn't fit (red)
			h.hb.toggle()
			h.hb.cat = "Buildings"
			var e := demo_place("house", land + Vector3(0, 0, -7), 0)      # find a spot, then take it back up as the ghost
			if not e.is_empty():
				var lay: Dictionary = h.hb.L()
				lay["deco"].erase(e)
				h.hb.apply(false)
			h.hb.take("house")
			if which == "ghost" and not e.is_empty():
				h.hb.debug_m = Vector2(float(e["x"]) + 2.5, float(e["z"]) + 1.5)
			elif which == "ghostbad":
				h.hb.rotate_held()
				var ti2 := nearest_wild(land + Vector3(0, 0, -7), "tree")
				var w2: World = h.world
				h.hb.debug_m = Vector2(ti2 % w2.w + 0.5, ti2 / w2.w + 2.0) if ti2 >= 0 else Vector2(land.x, land.z)
			for mi in h.hb.ghost.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).transparency = 0.5
			h.hb._build_bar()
			var cm: Vector2 = h.hb.debug_m
			cam.zoom_to = 1.25; cam.zoom = 1.25; cam.snap(Vector3(cm.x, 0, cm.y + 2.0))
			h.ppos = Vector3(cm.x, 0, cm.y + 2.0); h.player.position = h.ppos
		"busy":
			_demo_busy(land)
		"chop", "station", "panel":
			demo_place("house", land + Vector3(0, 0, -7), 0)
			demo_place("crop_patch", land + Vector3(7, 0, -3), 0)
			demo_place("cook_pot", land + Vector3(3, 0, -6), 0)
			h._sync_fixtures()
			var ti := nearest_wild(land, "tree")
			if ti < 0:
				return
			var w: World = h.world
			var tp := Vector3(ti % w.w + 0.5, 0, ti / w.w + 0.5)
			if which == "chop":
				# a tree you can stand south of (in front of it for the camera)
				var st := Vector3.INF
				var best_d := 1e9
				for i in h.hb.wild_t:
					if h.hb.wild_t[i] != "tree": continue
					var x: int = i % w.w; var z: int = i / w.w
					if not w.inb(x, z + 1) or w.kind[w.idx(x, z + 1)] != World.T_GROUND or w.kind[w.idx(x, z + 2)] != World.T_GROUND: continue
					var dd := Vector2(x - land.x, z - land.z).length()
					if dd < best_d: best_d = dd; ti = i; st = Vector3(x + 0.5, 0, z + 1.45)
				if st == Vector3.INF: st = beside(ti, land)
				h.ppos = st; h.player.position = st
				for k in h.kins:
					k["pos"] = st + Vector3(2.0, 0, 1.0); (k["node"] as Node3D).position = k["pos"]
				cam.zoom_to = 0.6; cam.zoom = 0.6; cam.snap(st)
				demo_loop = true
				h.tw.test_hold = true
				use({"kind": "wild", "i": ti, "what": "tree"})
				return
			# the island's grove: the tree with the most trees round it, away from the landing
			var bn := -1
			for i in h.hb.wild_t:
				if h.hb.wild_t[i] != "tree": continue
				var p := Vector3(i % w.w + 0.5, 0, i / w.w + 0.5)
				if Vector2(p.x - land.x, p.z - land.z).length() < 9.0: continue
				var n := 0
				for j in h.hb.wild_t:
					if h.hb.wild_t[j] == "tree" and Vector2(j % w.w - i % w.w, j / w.w - i / w.w).length() < 3.5: n += 1
				if n > bn: bn = n; tp = p
			var camp := demo_place("lumber_camp", tp, 0, 2.0)
			var cc := HomeLayout.deco_center(camp) if not camp.is_empty() else tp
			var rocks := nearest_wild(tp, "rock")
			var garden := demo_place("seed_garden", cc + (cc - tp).normalized() * 3.0 + Vector3(-2, 0, 0), 0, 1.0)
			var kiln := demo_place("kiln", cc + (cc - tp).normalized() * 3.0 + Vector3(2, 0, 0), 0, 1.0)
			var quarry := demo_place("quarry", Vector3(rocks % w.w + 0.5, 0, rocks / w.w + 0.5), 0, 2.0) if rocks >= 0 else {}
			var roster: Array = Save.d["roster"]
			var pairs := [[1, camp], [2, garden], [3, kiln]]
			for p in pairs:
				if (p[1] as Dictionary).is_empty(): continue
				Work.assign(roster[p[0]], int(p[1]["u"]))
			h.hw.scan()
			var mid := HomeLayout.deco_center(camp) if not camp.is_empty() else tp
			for k in h.kins:
				var J: Dictionary = h.hw.best_job(k)
				if J.is_empty() or Work.assigned(k["rec"]) < 0: continue
				h.hw.take(k, J)
				var kj: Dictionary = k["job"]
				k["pos"] = kj["at"]; (k["node"] as Node3D).position = kj["at"]
				kj["phase"] = "work"; kj["left"] = 999.0; kj["dur"] = 1400.0
				h.hw._hold(k, String(kj["kind"]))
				k["t"] = 999.0
			h.ppos = mid + (mid - tp).normalized() * 2.5 + Vector3(0, 0, 1.0); h.player.position = h.ppos
			for k in h.kins:
				if Work.assigned(k["rec"]) < 0:
					k["pos"] = h.ppos + Vector3(-1.5, 0, 1.5); (k["node"] as Node3D).position = k["pos"]; k["t"] = 999.0; k["goal"] = k["pos"]
			cam.zoom_to = 0.9; cam.zoom = 0.9; cam.snap(mid + (mid - tp).normalized() * 1.5)
			if which == "panel" and not camp.is_empty():
				h.get_tree().create_timer(0.5).timeout.connect(func(): h.hw.open_station(camp))

## The tutorial's chop step with a Boki talking beside the marked tree and a few toasts at once.
func _demo_busy(land: Vector3) -> void:
	var ti := nearest_wild(land, "tree")
	if ti < 0:
		return
	var st := beside(ti, land)
	h.ppos = st + Vector3(0, 0, 2.0)
	h.player.position = h.ppos
	var w: World = h.world
	var tree := Vector3(ti % w.w + 0.5, 0, ti / w.w + 0.5)
	h.cam.zoom_to = 0.8
	h.cam.zoom = 0.8
	h.cam.snap(st)
	h.get_viewport().warp_mouse(Vector2(8.0, 540.0))      # (no hover card over the picture)
	if h.kins.is_empty():
		return
	var talker: Dictionary = h.kins[0]
	h._say(talker, "Ooh, a tree! Swing at it and I'll carry the wood", 60.0)
	for i in 20:      # (the shot lands somewhere in here, however slow the frames)
		talker["pos"] = tree + Vector3(0.6, 0, 0.8)
		(talker["node"] as Node3D).position = talker["pos"]
		talker["goal"] = talker["pos"]
		for txt in ["A Pebbit is ready to hatch!", "Not enough wood", "Not enough wood", "Hob has new blueprints"]:
			h._toast(txt)
		await h.get_tree().create_timer(1.0).timeout
