extends RefCounted
## --hero-vfx-check: the shared Hero looks (scripts/match/hero_vfx.gd) against every content/vfx file: each move a kit
## asks for has a recipe, each sound exists and is a one-shot, the colours resolve and the sizes stay in budget; the FX
## anchors fall back from the model's node to the Gun to the body; pools and live particles stay capped; distance
## thins and then drops a look; allies sit dimmer; a hold stops by itself; a move arrives from another game. Then, on a
## synthetic recipe set with one layer of every kind: a bone anchor follows the hand, prewarm makes one of every kind,
## a held stream turns with the aim, a projectile trail follows its node and ends with it. Last, every Hunter's
## dash has its own look and a stun shows the shared StunMark.

const MAX_LIFE := 2.2          # s a look may linger (no long-lived noise)
const MAX_FLARE := 4.0         # m across, the largest burst (no screen-filling flashes)
const MAX_VORTEX := 4.5        # m radius, the largest ground swirl
## The kit scripts whose vfx("move") / hold(h, "move") / trail(h, "move", ...) / shell(h, "move") / play(h, "move")
## calls each Hero's data must answer.
const KIT_FILES := {
	"archer": ["archer_kit", "pin_"], "ashwick": ["ashwick_"], "bulwark": ["bulwark_kit", "bjorn_"],
	"dolm": ["dolm_kit", "breah_"], "dredge": ["dredge_"], "gunslinger": ["gunslinger_"],
	"juggernaut": ["juggernaut_"], "mage": ["mage_"], "ostra": ["ostra_"], "rimewright": ["rimewright_", "care_look"],
	"tender": ["tender_"], "thief": ["thief_"]}
## The bar's scale rule (docs/VFX_QUALITY.md): an ultimate's hit reads bigger than the basic attack's.
## [arch, LMB hit, ult hit] for the Hunters whose two hits are both data.
const HIT_SCALE := [["gunslinger", "shot_hit", "x_impact"], ["archer", "arrow_hit", "ult_hit"],
	["mage", "lmb_hit", "x_strike"], ["rimewright", "dart_hit", "rime_crash"], ["thief", "bolt_hit", "encore_hit"],
	["dolm", "punch", "spine_rise"]]
## The synthetic recipes the runtime parts play: one layer of every kind.
const TEST := {"palette": {"main": "#ff8040", "hot": "#ffe080", "char": "#201008", "smoke": "#404040"},
	"anchors": {"palm": {"bone": "hand.R", "off": [0.0, 0.05, 0.0], "body": [0.3, 1.0, 0.2]},
		"tip": {"body": [0.2, 1.1, 0.5]}},
	"moves": {
		"all": {"fx": [{"p": "sweep", "size": 2.0}, {"p": "scorch", "size": 2.0}, {"p": "skirt", "size": 1.5},
			{"p": "flare", "size": 1.5, "near": true}, {"p": "ribbon", "at": "tip"}, {"p": "thread", "len": 2.0},
			{"p": "bolt", "len": 4.0, "jag": 0.4},
			{"p": "vortex", "size": 2.0}, {"p": "dome", "size": 2.0, "arc": 120}, {"p": "ember", "n": 40},
			{"p": "smoke", "n": 12}, {"p": "chunk", "n": 10},
			{"p": "shard", "n": 20}, {"p": "card", "n": 10}, {"p": "coin", "n": 20}, {"p": "star", "n": 20},
			{"p": "drop", "n": 24}, {"p": "petal", "n": 16}]},
		"stream": {"fx": [{"p": "ember", "n": 20, "way": "fwd", "lift": 0.0}]},
		"rope": {"fx": [{"p": "chain", "at": "tip", "size": 0.2}]},
		"shot": {"fx": [{"p": "ribbon", "size": 0.2, "life": 1.5, "tail": 0.15}]}}}
## Moves a kit doesn't name in full: a thing every Hero has, or built from a kind.
const CALLED_ELSEWHERE := ["hurt", "downed", "string_idle", "string_draw", "fire_tap", "fire_arrow",
	"fire_super", "fire_over", "fire_heavy", "fire_ult"]

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
	_hit_scale()
	var broken: Array = []
	for sh: Shader in [HeroVfx.SURFACE, HeroVfx.MOTES, HeroVfx.MOTE, StunMark.SPIRAL, StunMark.SPIRAL_GLOW]:
		if sh.get_shader_uniform_list().is_empty():          # (a shader that fails to compile lists no uniforms)
			broken.append(sh.resource_path)
	ok(broken.is_empty(), "every shared look's shader compiles %s" % [broken])
	var m: Match = flow._match(main, "juggernaut")
	await main.get_tree().process_frame
	var P: Hunter = m.player
	var V := HeroVfx.of(m)
	Sfx.listener = P.pos
	_anchors(V, P)
	_lod(V, P)
	_budget(V, P)
	await _holds(main, m, V, P)
	_view(m, V, P)
	_kit(m, V, P)
	_origins(P)
	_net(m, V, P)
	await _status_and_dash(main, m, P)
	await _core_kinds(main, m, V, P)
	await _lisette(main, V)
	print("HEROVFX %s" % ("OK" if bad == 0 else "%d failed" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)

## The moves a Hero's kit asks for (from its scripts' source).
func _called(arch: String) -> Dictionary:
	var called := {}
	var re := RegEx.create_from_string("(?:vfx\\(|(?:hold|trail|shell)\\(\\w+(?:\\.\\w+)?, |play\\(h, )\"(\\w+)\"")
	for f in DirAccess.get_files_at("res://scripts/arch/kits"):
		if f.ends_with(".gd") and (KIT_FILES.get(arch, []) as Array).any(func(pre): return f.begins_with(pre)):
			for hit in re.search_all(FileAccess.get_file_as_string("res://scripts/arch/kits/" + f)):
				called[hit.get_string(1)] = true
	return called

## Everything the data promises is really there, and everything the kit asks for is in the data.
func _recipes(arch: String) -> void:
	var d := HeroVfx.data(arch)
	var moves: Dictionary = d.get("moves", {})
	ok(not moves.is_empty(), "%s has a recipe file" % arch)
	var called := _called(arch)
	var missing := called.keys().filter(func(k): return not (moves.has(k) or String(k).ends_with("_")))
	ok(not called.is_empty() and missing.is_empty(),
			"%s: all %d moves its kit calls have recipes %s" % [arch, called.size(), missing])
	var unused := moves.keys().filter(func(k): return not called.has(k) and not k in CALLED_ELSEWHERE)
	ok(unused.is_empty(), "%s: no recipe is left unused %s" % [arch, unused])
	var pal: Dictionary = d["palette"]
	var bad_sound: Array = []
	var bad_col: Array = []
	var over: Array = []
	var flat_only: Array = []
	for mv: String in moves:
		for s: Dictionary in moves[mv].get("sfx", []):
			if not _sound_exists(String(s["n"])):
				bad_sound.append(s["n"])
		for layer: Dictionary in moves[mv].get("fx", []):
			for key in ["c", "c2", "c3"]:
				if layer.has(key) and not pal.has(layer[key]):
					bad_col.append(layer[key])
			var big := float(layer.get("size", 0.0)) if layer.get("size", 0.0) is float else 0.0
			var flare_big: bool = layer["p"] == "flare" and big > MAX_FLARE
			var vortex_big: bool = layer["p"] == "vortex" and big > MAX_VORTEX
			var life := float(layer.get("life", 0.0))
			if layer["p"] == "ribbon" and layer.has("tail"):
				life = minf(life, HeroVfx.TRAIL_MAX)     # a projectile trail runs as long as its shot, capped
			var lasts: bool = layer["p"] == "thread"      # (a needle's thread stays as long as the needle)
			if (life > MAX_LIFE and not lasts) or flare_big or vortex_big:
				over.append(mv)
			var hold_only: bool = layer["p"] in ["string", "chain"]
			if not (HeroVfx.MODES.has(layer["p"]) or HeroVfx.LOOKS.has(layer["p"]) or hold_only):
				flat_only.append(layer["p"])
	ok(bad_sound.is_empty(), "%s: every sound in the data has a file %s" % [arch, bad_sound])
	ok(bad_col.is_empty(), "%s: every colour is in the palette %s" % [arch, bad_col])
	ok(over.is_empty(), "%s: no look over %.1f s, %.1f m flare, %.1f m swirl %s" % [arch, MAX_LIFE, MAX_FLARE,
			MAX_VORTEX, over])
	ok(flat_only.is_empty(), "%s: every layer is a known look %s" % [arch, flat_only])
	var loops: Array = []
	for mv: String in moves:
		for s: Dictionary in moves[mv].get("sfx", []):
			var st: Variant = Sfx.streams.get(s["n"], null)
			if st is AudioStreamWAV and (st as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
				loops.append(s["n"])
	ok(loops.is_empty(), "%s: every sound is a one-shot, nothing can outlive the match %s" % [arch, loops])

func _sound_exists(sname: String) -> bool:
	return ResourceLoader.exists("res://audio/%s.wav" % sname) or ResourceLoader.exists("res://audio/%s_1.wav" % sname)

## Model node, then the Gun, then the body. Works on today's model and on one with the named anchors.
func _anchors(V: HeroVfx, P: Hunter) -> void:
	var gun: Node3D = P.model.get_node("Rig/Torso/Aim/Gun")
	var a: Dictionary = HeroVfx.data("juggernaut")["anchors"]["blade_tip"]
	var via_gun: Vector3 = gun.global_transform * Vector3(a["gun"][0], a["gun"][1], a["gun"][2])
	var had_node: bool = WardenGlb.anchor(P.model, "weapon_muzzle") != null
	var tip := V.anchor_pos(P, "blade_tip")
	ok(had_node or tip.distance_to(via_gun) < 0.001, "blade_tip uses the Gun's space on a model without the anchor")
	var fake := Node3D.new()
	fake.name = "anchor_blade_tip"
	var host: Node = P.model.get_node_or_null("Warden")
	if host != null:
		host.add_child(fake)
		fake.global_position = P.pos + Vector3(1, 2, 3)
		V._anchors.clear()
		var seen := V.anchor_pos(P, "blade_tip")
		ok(seen.distance_to(fake.global_position) < 0.001, "a model's own anchor_blade_tip wins")
		host.remove_child(fake)
		V._anchors.clear()
	fake.free()
	var keep := P.model
	P.model = null
	var body := V.anchor_pos(P, "chest")
	ok(body.distance_to(P.pos + Vector3(0, 1.15, 0)) < 0.2, "no model at all: the body offset still places it")
	P.model = keep

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
	var o := {"r": 2.6, "core": 1.2}
	_clear(V)
	V.play(P, "drop_hit", P.pos, Vector2.RIGHT, o)
	var near_n := V.live_n
	var near_nodes := _visible_nodes(V)
	_clear(V)
	var mid := P.pos + Vector3(HeroVfx.LOD_NEAR + 4.0, 0, 0)
	V.play(P, "drop_hit", mid, Vector2.RIGHT, o)
	ok(V.live_n > 0 and V.live_n <= near_n * HeroVfx.LOD_MID_K + 1 and _visible_nodes(V) < near_nodes,
			"past LOD_NEAR: the near layers drop, the rest thin (%d -> %d particles)" % [near_n, V.live_n])
	_clear(V)
	V.play(P, "drop_hit", P.pos + Vector3(HeroVfx.LOD_FAR + 4.0, 0, 0), Vector2.RIGHT, o)
	ok(V.live_n == 0 and _visible_nodes(V) == 0, "past LOD_FAR: nothing is drawn")

## The worst case: every big move at once, many times over.
func _budget(V: HeroVfx, P: Hunter) -> void:
	_clear(V)
	for i in 40:
		for mv in ["drop_hit", "slam_hit", "wave_fire", "riposte_land", "spin", "haul_hit"]:
			V.play(P, mv, P.pos, Vector2.RIGHT, {"r": 2.6, "core": 1.2, "len": 8.0, "w": 2.0})
	ok(V.live_n <= HeroVfx.MAX_LIVE, "a pile-up stays at the live cap (%d <= %d)" % [V.live_n, HeroVfx.MAX_LIVE])
	var capped := true
	for kind: String in V.pools:
		capped = capped and (V.pools[kind] as Array).size() <= int(HeroVfx.POOL[kind])
	ok(capped, "every pool stays within its cap")
	var made := V.made
	for i in 10:
		V.play(P, "drop_hit", P.pos, Vector2.RIGHT, {"r": 2.6, "core": 1.2})
	ok(V.made == made, "a warm pool makes no new nodes")
	_clear(V)

func _holds(main: Node, m: Match, V: HeroVfx, P: Hunter) -> void:
	V.hold(P, "enraged")
	ok(V.holds.size() == 1 and V.live_n > 0, "a hold starts emitting")
	var em: GPUParticles3D = V.holds.values()[0]["layers"][0]["node"]
	var floor_y: float = (em.process_material as ShaderMaterial).get_shader_parameter("floor_y")
	ok(is_equal_approx(floor_y, m.world.ground_at(P.pos.x, P.pos.z)), "its motes land on the ground under it")
	var n0 := V.live_n
	V.hold(P, "enraged")
	ok(V.live_n == n0, "asking again keeps the one emitter")
	m.time += HeroVfx.HOLD_LINGER + 0.1
	V._tick_holds()
	ok(V.holds.is_empty(), "the asks stop: the hold ends by itself")
	await main.get_tree().process_frame
	_clear(V)

func _view(m: Match, V: HeroVfx, P: Hunter) -> void:
	ok(is_equal_approx(V.view_k(P), 1.0), "your own effects at full")
	var keep: Hunter = m.player
	var none := {"arch": "none"}
	var ally: Hunter = m.make_hunter("A", P.team, "medium", "Ally", "idle", {}, P.pos + Vector3(3, 0, 0), none)
	var foe: Hunter = m.make_hunter("B", P.team + 1, "medium", "Foe", "idle", {}, P.pos + Vector3(-3, 0, 0), none)
	ok(is_equal_approx(V.view_k(ally), HeroVfx.ALLY_K), "an ally's effects sit at ALLY_K")
	ok(is_equal_approx(V.view_k(foe), 1.0), "an enemy's effects at full")
	ok(keep == m.player, "the viewer is unchanged")

## The kit really goes through the shared helper, and with the own look the shared cast language stays out.
func _kit(m: Match, V: HeroVfx, P: Hunter) -> void:
	var K: JuggernautKit = P.ak
	V.plays.clear()
	var rings0: int = m.fx.rings.size()
	K._slam()
	ok(int(V.plays.get("slam_hit", 0)) == 1, "the Finishing Slam plays its recipe")
	ok(m.fx.rings.size() == rings0, "no shared ring under it")
	ok(not m.fx.own_look and Sfx.skip.is_empty(), "the own-look scope closes")

## Shot origins (content/shot_origins.json): every measured muzzle sits on the body, turns with the aim, and a seated
## round leaves from it at its own height, as fast as before and still ending where it would have.
func _origins(P: Hunter) -> void:
	var arch0 := P.arch
	for arch: String in ["gunslinger", "archer", "mage", "thief", "dredge", "ashwick", "dolm"]:
		for move: String in ["lmb", "rmb", "e", "throw"]:
			for o: Array in ShotOrigin.data(arch, move).get("at", []):
				var on := absf(float(o[0])) <= 0.8 and float(o[1]) > 0.0 and float(o[1]) <= 0.8
				ok(on, "%s %s: origin %s on the body" % [arch, move, o])
	P.arch = "thief"
	var at := ShotOrigin.point(P, "lmb", 1, P.pos + Vector3(0, 0.9, 0))
	var d := P.aim_dir()
	var side := Vector2(at.x - P.pos.x, at.z - P.pos.z).dot(Vector2(-d.y, d.x))
	ok(is_equal_approx(at.y, P.pos.y + 0.9) and side < -0.3,
		"the left crossbow's round leaves on her left (%.2f m)" % side)
	P.arch = arch0
	var sd := {"pos": P.pos + Vector3(d.x * 0.6, 0.9, d.y * 0.6), "vel": d * 20.0, "life": 0.5, "x": {}}
	var end: Vector2 = Vector2(sd["pos"].x, sd["pos"].z) + d * 10.0
	ShotOrigin.seat(sd, at)
	var lands: Vector2 = Vector2(at.x, at.z) + (sd["vel"] as Vector2) * float(sd["life"])
	ok(sd["start"] == at and lands.distance_to(end) < 0.01 and is_equal_approx((sd["vel"] as Vector2).length(), 20.0),
		"a seated round leaves the muzzle and lands where it would have")

## Her needles: one that misses stays in the ground with its thread; the bow's string stands down for a model's own.
func _lisette(main: Node, V0: HeroVfx) -> void:
	var m: Match = flow._match(main, "archer")
	await main.get_tree().process_frame
	var P: Hunter = m.player
	var V := HeroVfx.of(m)
	ok(V != V0, "a new match has its own pools")
	Sfx.listener = P.pos
	var K: ArcherKit = P.ak
	K.fx._plant(P.pos + Vector3(3, 0, 0), Vector2(1, 0), "arrow")
	ok(int(V.plays.get("needle_stuck", 0)) == 1, "a missed needle leaves its thread")
	var last: Dictionary = V.live.filter(func(e): return (e["node"] as Node3D).visible)[0]
	ok(is_equal_approx(float(last["dur"]), PinFx.SPENT_T), "the thread lasts as long as the needle")
	ok(is_equal_approx(PinFx.HEAVY_SCALE, 6.0), "the Heavy Shot stays big")
	V.hold(P, "string_idle")
	var key := "%d/string_idle" % P.get_instance_id()
	var wanted: int = 0 if V._model_has(P, "halo_bow_mid") else 1
	ok((V.holds[key]["layers"] as Array).size() == wanted, "the string shows unless the model brings its own")
	var hip := V.anchor_pos(P, "nock")
	ok(hip.distance_to(K.hand_pos(true)) < 0.001 or WardenGlb.anchor(P.model, "anchor_nock") != null,
			"nock: the model's anchor, else the drawing hand")

## The shared kinds on a synthetic recipe set (the real files are done with): every layer kind plays and a pile-up
## stays capped; a bone anchor follows the hand; prewarm builds one of every kind and hides them; a stream held along
## the aim turns with it; a projectile's trail follows its node and runs out when it is gone.
func _core_kinds(main: Node, m: Match, V: HeroVfx, P: Hunter) -> void:
	HeroVfx.set_data(P.arch, TEST)
	V._anchors.clear()
	_clear(V)
	V.play(P, "all", P.pos, Vector2.RIGHT)
	ok(_visible_nodes(V) >= HeroVfx.MODES.size() + HeroVfx.LOOKS.size() - 1, "every layer kind plays")
	for i in 40:
		V.play(P, "all", P.pos, Vector2.RIGHT)
	ok(V.live_n <= HeroVfx.MAX_LIVE, "a pile-up of every kind stays at the live cap (%d)" % V.live_n)
	_clear(V)
	var sky := V._bolt_end({"rise": -9.0}, P, P.pos + Vector3(0, 9, 0), Vector2.RIGHT, {})
	ok(sky.distance_to(P.pos) < 0.001, "a bolt with a negative rise strikes straight down from its height")
	var sk := WardenGlb.skeleton(P.model.get_node_or_null("Warden"))
	var palm := V.anchor_pos(P, "palm")
	if sk != null:
		var pose := sk.get_bone_global_pose(WardenSkeleton.find(sk, "hand.R"))
		var want := sk.global_transform * (pose * Vector3(0.0, 0.05, 0.0))
		ok(palm.distance_to(want) < 0.001, "a bone anchor follows the model's hand.R")
	else:
		ok(palm.distance_to(P.pos) < 1.6, "a bone anchor on a model without a skeleton falls back to the body")
	V.prewarm(P.pos)
	ok(V._warming.size() == HeroVfx.POOL.size(), "prewarm holds up one node of every kind (%d)" % V._warming.size())
	V.prewarm_end()
	ok(_visible_nodes(V) == 0 and V._warming.is_empty(), "and they are hidden again")
	P.inp["aim"] = P.pos + Vector3(4, 0, 0)
	V.hold(P, "stream")
	P.inp["aim"] = P.pos + Vector3(0, 0, 4)
	V._tick_holds()
	var lay: Dictionary = V.holds.values()[0]["layers"][0]
	var way: Vector3 = (lay["node"].process_material as ShaderMaterial).get_shader_parameter("dir")
	ok(way.distance_to(Vector3(0, 0, 1)) < 0.01, "a stream held along the aim turns with it (%s)" % way)
	m.time += HeroVfx.HOLD_LINGER + 0.1
	V._tick_holds()
	_clear(V)
	V.hold(P, "rope", 0.0, {"to": P.pos + Vector3(3, 1, 0)})
	V.hold(P, "rope", 1.0, {"to": P.pos + Vector3(0, 1, 3)})
	V._tick_holds()
	var rope: MeshInstance3D = V.holds.values()[0]["layers"][0]["node"]
	var tension: float = (rope.material_override as ShaderMaterial).get_shader_parameter("life")
	var far_end := (rope.mesh as ImmediateMesh).get_aabb().end
	ok(rope.visible and tension == 1.0 and far_end.z > P.pos.z + 2.5,
			"a held chain runs to the kit's newest point at its tension (%.1f, %s)" % [tension, far_end])
	m.time += HeroVfx.HOLD_LINGER + 0.1
	V._tick_holds()
	ok(not rope.visible, "and goes when the asks stop")
	_clear(V)
	var shot := Node3D.new()
	m.add_child(shot)
	shot.global_position = P.pos + Vector3(0, 1, 0)
	V.trail(P, "shot", shot)
	ok(V.ribbons.size() == 1, "a projectile gets its trail")
	for i in 4:      # (ticked by hand: on a loaded box a frame's delta can outlast the tail)
		shot.global_position += Vector3(0.5, 0, 0)
		V._tick_ribbon(V.ribbons[0], 0.02)
	ok((V.ribbons[0]["pts"] as Array).size() >= 3, "the trail follows the projectile")
	shot.visible = false
	for i in 30:
		await main.get_tree().process_frame
	ok(V.ribbons.is_empty(), "the projectile ends: its tail runs out")
	shot.queue_free()
	_clear(V)
	HeroVfx.set_data(P.arch, {})

func _net(m: Match, V: HeroVfx, P: Hunter) -> void:
	V.plays.clear()
	m.ents_by_id[P.nid] = P
	V.net_in(["fx", "hvfx", P.nid, "spin", P.pos.x, P.pos.y, P.pos.z, 1.0, 0.0, 0.0, 0.0, 2.6])
	ok(int(V.plays.get("spin", 0)) == 1, "a move arrives from another game")

## Every Hunter's dash draws its own look: none falls back to the shared team-colour pill (fx.ghost, a new node
## per tick). A stun shows StunMark over the head while it lasts, on Hunters and monsters, from a fixed pool.
func _status_and_dash(main: Node, m: Match, P: Hunter) -> void:
	var bodies: Array[Hunter] = []
	var pill: Array = []
	for arch: String in HeroVfx.heroes():
		var at := P.pos + Vector3(2.0 * bodies.size() - 12.0, 0, 4.0)
		var H: Hunter = m.make_hunter("D" + arch, P.team + 1, Arch.weight(arch), arch, "idle", {}, at, {"arch": arch})
		bodies.append(H)
		var ghosts0: int = m.fx.ghosts.size()
		H.roll_t = 0.3
		for i in 6:
			H.render(0.03, 1.0)
		H.roll_t = 0.0
		if m.fx.ghosts.size() != ghosts0:
			pill.append(arch)
	ok(pill.is_empty(), "every Hunter's dash draws its own look, not the shared pill %s" % [pill])
	var S := StunMark.of(m)
	var T: Hunter = bodies[0]
	T.stun_t = 1.0
	T.render(0.016, 1.0)
	await main.get_tree().process_frame
	ok(S.on(T) and not S.on(P), "a stunned Hunter shows the stun mark, the others don't")
	var top: float = S.marks[S.whose.find(T)].global_position.y - T.global_position.y
	ok(absf(top - (HudPlate.plate_offset(T) - StunMark.UNDER_PLATE)) < 0.01, "it sits over the head, under the plate")
	T.stun_t = 0.0
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(not S.on(T), "the stun ends: the mark goes")
	var nodes0 := S.get_child_count()
	for H in bodies:
		H.stun_t = 1.0
		H.render(0.016, 1.0)
	var shown := S.marks.filter(func(n: Node3D) -> bool: return n.visible).size()
	ok(shown == StunMark.POOL and S.get_child_count() == nodes0,
		"%d stunned bodies share the %d marks, no new nodes" % [bodies.size(), StunMark.POOL])
	for H in bodies:
		H.stun_t = 0.0
	var V := HeroVfx.of(m)
	for key: String in V.holds.keys():
		V._end_hold(V.holds[key])
	V.holds.clear()          # (the dashes' own holds; the runtime parts below read the first hold)
	_clear(V)

func _hit_scale() -> void:
	var small: Array = []
	for row: Array in HIT_SCALE:
		var moves: Dictionary = HeroVfx.data(row[0]).get("moves", {})
		if _widest(moves.get(row[1], {})) >= _widest(moves.get(row[2], {})):
			small.append(row[0])
	ok(small.is_empty(), "every ultimate's hit reads bigger than the LMB's %s" % [small])

## The widest shape a recipe always draws (flares, sweeps, skirts, scorches, swirls; not a `when` variant).
func _widest(recipe: Dictionary) -> float:
	var w := 0.0
	for layer: Dictionary in recipe.get("fx", []):
		var sized: bool = layer.get("size") is float or layer.get("size") is int
		if layer["p"] in ["flare", "sweep", "skirt", "scorch", "vortex"] and sized and not layer.has("when"):
			w = maxf(w, float(layer["size"]))
	return w
