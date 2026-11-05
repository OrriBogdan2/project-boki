extends RefCounted
## --hero-vfx-check: the shared Hero looks (scripts/match/hero_vfx.gd).
##   - Every content/vfx file: each move its kit asks for has a recipe and none is left unused, each sound exists and
##     is a one-shot, every colour is in the palette, every layer is a known look, sizes and lives stay in budget,
##     and a Hero's own footsteps resolve when the file names them.
##   - The shared runtime, on a synthetic recipe set using every layer kind: anchors fall back from the model's node to
##     the Gun to the body; distance thins and then drops a look; pools and live particles stay capped in a pile-up and
##     a warm pool makes no new nodes; prewarm makes one of every kind; a hold thickens with its charge and stops by
##     itself; a projectile trail follows its node and ends with it; allies sit dimmer; a move arrives from another game.

const MAX_LIFE := 2.2          # s a look may linger (no long-lived noise)
const MAX_FLARE := 4.0         # m across, the largest burst (no screen-filling flashes)
const MAX_VORTEX := 4.5        # m radius, the largest ground swirl
## The kit scripts whose vfx("move") / hold(h, "move") / trail(h, "move", ...) calls each Hero's data must answer.
const KIT_FILES := {
	"archer": ["archer_kit", "pin_"], "ashwick": ["ashwick_"], "bulwark": ["bulwark_kit", "bjorn_"],
	"dolm": ["dolm_kit", "breah_"], "dredge": ["dredge_"], "gunslinger": ["gunslinger_"],
	"juggernaut": ["juggernaut_"], "mage": ["mage_"], "ostra": ["ostra_"], "rimewright": ["rimewright_"],
	"tender": ["tender_"], "thief": ["thief_"]}
const OWN := ["hurt", "downed", "guard_shell"]      # moves played from shared code, not the kit
## The synthetic recipes the runtime parts play: one layer of every kind.
const TEST := {"palette": {"main": "#ff8040", "hot": "#ffe080", "char": "#201008", "smoke": "#404040"},
	"anchors": {"tip": {"nodes": ["anchor_test_tip"], "gun": [0.0, 0.0, -0.6], "body": [0.2, 1.1, 0.5]},
		"chest": {"body": [0.0, 1.15, 0.0]},
		"palm": {"bone": "hand.R", "off": [0.0, 0.05, 0.0], "body": [0.3, 1.0, 0.2]}},
	"moves": {
		"all": {"fx": [{"p": "sweep", "size": 2.0}, {"p": "scorch", "size": 2.0}, {"p": "skirt", "size": 1.5},
			{"p": "flare", "size": 1.5, "near": true}, {"p": "ribbon", "at": "tip"},
			{"p": "bolt", "len": 4.0, "jag": 0.4},
			{"p": "vortex", "size": 2.0}, {"p": "ember", "n": 40}, {"p": "smoke", "n": 12}, {"p": "chunk", "n": 10},
			{"p": "shard", "n": 20}, {"p": "card", "n": 10}, {"p": "coin", "n": 20}, {"p": "star", "n": 20},
			{"p": "drop", "n": 24}]},
		"heat": {"fx": [{"p": "ember", "n": 12, "n_k": 1.0, "at": "tip"}]},
		"shot": {"fx": [{"p": "ribbon", "size": 0.2, "life": 1.5, "tail": 0.15}]}}}

var bad := 0
var flow := preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	print("HEROVFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for arch: String in HeroVfx.heroes():
		_recipes(arch)
	var m: Match = flow._match(main, "juggernaut")
	await main.get_tree().process_frame
	var P: Hunter = m.player
	HeroVfx.set_data(P.arch, TEST)
	var V := HeroVfx.of(m)
	Sfx.listener = P.pos
	_anchors(V, P)
	_prewarm(m, V)
	_lod(V, P)
	_budget(V, P)
	await _holds(main, m, V, P)
	await _trail(main, m, V, P)
	_view(m, V, P)
	_net(m, V, P)
	HeroVfx.set_data(P.arch, {})
	print("HEROVFX %s" % ("OK" if bad == 0 else "%d failed" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)

## The moves a Hero's kit asks for (from its scripts' source).
func _called(arch: String) -> Dictionary:
	var called := {}
	var re := RegEx.create_from_string(
			"(?:vfx\\(|(?:hold|trail)\\(\\w+(?:\\.\\w+)?, )\"(\\w+)\"")
	for f in DirAccess.get_files_at("res://scripts/arch/kits"):
		if not f.ends_with(".gd"):
			continue
		if not (KIT_FILES.get(arch, []) as Array).any(func(pre): return f.begins_with(pre)):
			continue
		for hit in re.search_all(FileAccess.get_file_as_string("res://scripts/arch/kits/" + f)):
			called[hit.get_string(1)] = true
	return called

## Everything the data promises is really there, and everything the kit asks for is in the data.
func _recipes(arch: String) -> void:
	var d := HeroVfx.data(arch)
	var moves: Dictionary = d.get("moves", {})
	ok(not moves.is_empty(), "%s has a recipe file" % arch)
	var called := _called(arch)
	var missing := called.keys().filter(func(k): return not moves.has(k))
	ok(not called.is_empty() and missing.is_empty(),
			"%s: all %d moves its kit calls have recipes %s" % [arch, called.size(), missing])
	var unused := moves.keys().filter(func(k): return not called.has(k) and not k in OWN)
	ok(unused.is_empty(), "%s: no recipe is left unused %s" % [arch, unused])
	var pal: Dictionary = d.get("palette", {})
	var bad_sound: Array = []
	var bad_col: Array = []
	var over: Array = []
	var unknown: Array = []
	for mv: String in moves:
		for s: Dictionary in moves[mv].get("sfx", []):
			if not Sfx.has(String(s["n"])):
				bad_sound.append(s["n"])
		for layer: Dictionary in moves[mv].get("fx", []):
			for key in ["c", "c2", "c3"]:
				if layer.has(key) and not pal.has(layer[key]):
					bad_col.append(layer[key])
			if _over(layer):
				over.append(mv)
			if not (HeroVfx.MODES.has(layer["p"]) or HeroVfx.LOOKS.has(layer["p"])):
				unknown.append(layer["p"])
	ok(bad_sound.is_empty(), "%s: every sound in the data exists %s" % [arch, bad_sound])
	ok(bad_col.is_empty(), "%s: every colour is in the palette %s" % [arch, bad_col])
	ok(over.is_empty(), "%s: no look over %.1f s, %.1f m flare, %.1f m swirl %s" % [arch, MAX_LIFE, MAX_FLARE,
			MAX_VORTEX, over])
	ok(unknown.is_empty(), "%s: every layer is a known look %s" % [arch, unknown])
	var loops: Array = []
	for mv: String in moves:
		for s: Dictionary in moves[mv].get("sfx", []):
			var st: Variant = Sfx.streams.get(s["n"], null)
			if st is AudioStreamWAV and (st as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
				loops.append(s["n"])
	ok(loops.is_empty(), "%s: every sound is a one-shot, nothing can outlive the match %s" % [arch, loops])
	for surface: String in (d.get("steps", {}) as Dictionary):
		ok(Sfx.has(HeroVfx.step_sound(arch, surface)), "%s's own %s footstep exists" % [arch, surface])

func _over(layer: Dictionary) -> bool:
	var life := float(layer.get("life", 0.0))
	var big := float(layer.get("size", 0.0)) if layer.get("size", 0.0) is float else 0.0
	if layer["p"] == "ribbon" and layer.has("tail"):
		life = minf(life, HeroVfx.TRAIL_MAX)     # a projectile trail runs as long as its shot, capped
	var too_big: bool = (layer["p"] == "flare" and big > MAX_FLARE) or (layer["p"] == "vortex" and big > MAX_VORTEX)
	return life > MAX_LIFE or too_big

## Model node, then the Gun, then the body. Works on today's model and on one with the named anchors.
func _anchors(V: HeroVfx, P: Hunter) -> void:
	var gun: Node3D = P.model.get_node("Rig/Torso/Aim/Gun")
	var via_gun: Vector3 = gun.global_transform * Vector3(0.0, 0.0, -0.6)
	V._anchors.clear()
	ok(V.anchor_pos(P, "tip").distance_to(via_gun) < 0.001, "an anchor uses the Gun's space on a model without it")
	var fake := Node3D.new()
	fake.name = "anchor_test_tip"
	var host: Node = P.model.get_node_or_null("Warden")
	if host != null:
		host.add_child(fake)
		fake.global_position = P.pos + Vector3(1, 2, 3)
		V._anchors.clear()
		ok(V.anchor_pos(P, "tip").distance_to(fake.global_position) < 0.001, "a model's own anchor empty wins")
		host.remove_child(fake)
		V._anchors.clear()
	fake.free()
	var sk := WardenGlb.skeleton(P.model.get_node_or_null("Warden"))
	var palm := V.anchor_pos(P, "palm")
	if sk != null:
		var bi := WardenSkeleton.find(sk, "hand.R")
		var want := sk.global_transform * (sk.get_bone_global_pose(bi) * Vector3(0.0, 0.05, 0.0))
		ok(bi >= 0 and palm.distance_to(want) < 0.001, "a bone anchor follows the model's hand.R")
	else:
		ok(palm.distance_to(P.pos) < 1.6, "a bone anchor on a model without a skeleton falls back to the body")
	var keep := P.model
	P.model = null
	ok(V.anchor_pos(P, "chest").distance_to(P.pos + Vector3(0, 1.15, 0)) < 0.2, "no model: the body offset places it")
	P.model = keep

func _prewarm(m: Match, V: HeroVfx) -> void:
	_clear(V)
	V.prewarm()
	var kinds := V.pools.keys()
	ok(kinds.size() == HeroVfx.POOL.size(), "prewarm makes one node of every kind (%d)" % kinds.size())
	ok(_visible_nodes(V) == 0, "and they stay hidden")
	ok(V.get_parent() == m, "under the match, where warm_up finds them")

func _visible_nodes(V: HeroVfx) -> int:
	var n := 0
	for kind: String in V.pools:
		for node in V.pools[kind]:
			if (node as Node3D).visible: n += 1
	return n

func _clear(V: HeroVfx) -> void:
	for kind: String in V.pools:
		for node in V.pools[kind]:
			(node as Node3D).visible = false
	V.live.clear()
	V.motes.clear()
	V.ribbons.clear()
	V.live_n = 0

func _lod(V: HeroVfx, P: Hunter) -> void:
	_clear(V)
	V.play(P, "all", P.pos, Vector2.RIGHT)
	var near_n := V.live_n
	var near_nodes := _visible_nodes(V)
	ok(near_nodes >= HeroVfx.MODES.size() + HeroVfx.LOOKS.size() - 1, "every layer kind plays (%d nodes)" % near_nodes)
	_clear(V)
	V.play(P, "all", P.pos + Vector3(HeroVfx.LOD_NEAR + 4.0, 0, 0), Vector2.RIGHT)
	ok(V.live_n > 0 and V.live_n <= near_n * HeroVfx.LOD_MID_K + 8 and _visible_nodes(V) < near_nodes,
			"past LOD_NEAR: the near layers drop, the rest thin (%d -> %d particles)" % [near_n, V.live_n])
	_clear(V)
	V.play(P, "all", P.pos + Vector3(HeroVfx.LOD_FAR + 4.0, 0, 0), Vector2.RIGHT)
	ok(V.live_n == 0 and _visible_nodes(V) == 0, "past LOD_FAR: nothing is drawn")

## The worst case: every kind at once, many times over.
func _budget(V: HeroVfx, P: Hunter) -> void:
	_clear(V)
	for i in 40:
		V.play(P, "all", P.pos, Vector2.RIGHT)
	ok(V.live_n <= HeroVfx.MAX_LIVE, "a pile-up stays at the live cap (%d <= %d)" % [V.live_n, HeroVfx.MAX_LIVE])
	var capped := true
	for kind: String in V.pools:
		capped = capped and (V.pools[kind] as Array).size() <= int(HeroVfx.POOL[kind])
	ok(capped, "every pool stays within its cap")
	var made := V.made
	for i in 10:
		V.play(P, "all", P.pos, Vector2.RIGHT)
	ok(V.made == made, "a warm pool makes no new nodes")
	_clear(V)

func _holds(main: Node, m: Match, V: HeroVfx, P: Hunter) -> void:
	V.hold(P, "heat")
	ok(V.holds.size() == 1 and V.live_n > 0, "a hold starts emitting")
	var n0 := V.live_n
	V.hold(P, "heat")
	ok(V.live_n == n0, "asking again keeps the one emitter")
	V.hold(P, "heat", 1.0)
	ok(V.holds.size() == 1 and V.live_n > n0, "its charge grows: the emitter thickens (%d -> %d)" % [n0, V.live_n])
	m.time += HeroVfx.HOLD_LINGER + 0.1
	V._tick_holds()
	ok(V.holds.is_empty(), "the asks stop: the hold ends by itself")
	await main.get_tree().process_frame
	_clear(V)

func _trail(main: Node, m: Match, V: HeroVfx, P: Hunter) -> void:
	var shot := Node3D.new()
	m.add_child(shot)
	shot.global_position = P.pos + Vector3(0, 1, 0)
	V.trail(P, "shot", shot)
	ok(V.ribbons.size() == 1, "a projectile gets its trail")
	for i in 4:
		shot.global_position += Vector3(0.5, 0, 0)
		await main.get_tree().process_frame
	ok((V.ribbons[0]["pts"] as Array).size() >= 3, "the trail follows the projectile")
	shot.visible = false
	for i in 30:
		await main.get_tree().process_frame
	ok(V.ribbons.is_empty(), "the projectile ends: its tail runs out")
	shot.queue_free()
	_clear(V)

func _view(m: Match, V: HeroVfx, P: Hunter) -> void:
	ok(is_equal_approx(V.view_k(P), 1.0), "your own effects at full")
	var none := {"arch": "none"}
	var ally: Hunter = m.make_hunter("A", P.team, "medium", "Ally", "idle", {}, P.pos + Vector3(3, 0, 0), none)
	var foe: Hunter = m.make_hunter("B", P.team + 1, "medium", "Foe", "idle", {}, P.pos + Vector3(-3, 0, 0), none)
	ok(is_equal_approx(V.view_k(ally), HeroVfx.ALLY_K), "an ally's effects sit at ALLY_K")
	ok(is_equal_approx(V.view_k(foe), 1.0), "an enemy's effects at full")

func _net(m: Match, V: HeroVfx, P: Hunter) -> void:
	V.plays.clear()
	m.ents_by_id[P.nid] = P
	V.net_in(["fx", "hvfx", P.nid, "all", P.pos.x, P.pos.y, P.pos.z, 1.0, 0.0, 0.0, 0.0, 2.6])
	ok(int(V.plays.get("all", 0)) == 1, "a move arrives from another game")
