extends RefCounted
## --hero-vfx-check: the shared Hero looks (scripts/match/hero_vfx.gd) against every content/vfx file: each move a kit
## asks for has a recipe, each sound exists and is a one-shot, the colours resolve and the sizes stay in budget; the FX
## anchors fall back from the model's node to the Gun to the body; pools and live particles stay capped; distance
## thins and then drops a look; allies sit dimmer; a hold stops by itself; a move arrives from another game. Then, on a
## synthetic recipe set with one layer of every kind: a bone anchor follows the hand, prewarm makes one of every kind,
## a held stream turns with the aim, a projectile trail follows its node and ends with it. Claire's scarf tails hang
## from their anchor, follow it, stream behind a run and are off at Low. Each ability's emitter on the swapped
## models stays on its bone (tools/hero_vfx_emit.gd). The drop rocket's looks (DropRocket): its trail, the puff where
## a Hunter jumps out and the dust where it lands.

const MAX_LIFE := 2.2          # s a look may linger (no long-lived noise)
const ROCKET_AT := 6.0         # s into the ship's run when the squad launches: over the islands on ROCKET_SEED
const ROCKET_SEED := 4242
const ROCKET_RIDE := 1.5       # s ridden before the trail is measured: past the rocket's speed-up
const ROCKET_TRAIL_M := 10.0   # m of trail at least behind the dive by then, so it reaches up the skydive view
const ROCKET_ALONE_M := 3.0    # m over the ground from where only the rocket steps (the landing's count is its own)
const ROCKET_CAP_S := 20.0     # s a ride may take at most
const SETTLE_TOP_V := 5.0      # m/s: the landing dust is never faster than this (it settles, it does not blast)
const STREAK_PILE := 40        # streaks asked for at once: the pool still caps them
const MAX_FLARE := 4.0         # m across, the largest burst (no screen-filling flashes)
const MAX_VORTEX := 4.5        # m radius, the largest ground swirl or shockwave ring
## The kit scripts whose vfx("move") / hold(h, "move") / trail(h, "move", ...) / play(h, "move") calls each Hero's
## data must answer.
const KIT_FILES := {
	"archer": ["archer_kit", "pin_"], "ashwick": ["ashwick_"], "bulwark": ["bulwark_kit", "bjorn_"],
	"dolm": ["dolm_kit", "breah_"], "dredge": ["dredge_"], "gunslinger": ["gunslinger_"],
	"juggernaut": ["juggernaut_"], "mage": ["mage_"], "ostra": ["ostra_"], "rimewright": ["rimewright_"],
	"tender": ["tender_"], "thief": ["thief_"]}
## The synthetic recipes the runtime parts play: one layer of every kind.
const TEST := {"palette": {"main": "#ff8040", "hot": "#ffe080", "char": "#201008", "smoke": "#404040"},
	"anchors": {"palm": {"bone": "hand.R", "off": [0.0, 0.05, 0.0], "body": [0.3, 1.0, 0.2]},
		"tip": {"body": [0.2, 1.1, 0.5]}},
	"moves": {
		"all": {"fx": [{"p": "sweep", "size": 2.0}, {"p": "scorch", "size": 2.0}, {"p": "skirt", "size": 1.5},
			{"p": "flare", "size": 1.5, "near": true}, {"p": "ribbon", "at": "tip"}, {"p": "thread", "len": 2.0},
			{"p": "bolt", "len": 4.0, "jag": 0.4},
			{"p": "vortex", "size": 2.0}, {"p": "ember", "n": 40}, {"p": "smoke", "n": 12}, {"p": "chunk", "n": 10},
			{"p": "shard", "n": 20}, {"p": "card", "n": 10}, {"p": "coin", "n": 20}, {"p": "star", "n": 20},
			{"p": "drop", "n": 24}]},
		"stream": {"fx": [{"p": "ember", "n": 20, "way": "fwd", "lift": 0.0}]},
		"shot": {"fx": [{"p": "ribbon", "size": 0.2, "life": 1.5, "tail": 0.15}]}}}
## Moves a kit doesn't name in full: a thing every Hero has, or built from a kind.
const CALLED_ELSEWHERE := ["hurt", "downed", "guard_shell", "string_idle", "string_draw", "fire_tap", "fire_arrow",
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
	await preload("res://tools/hero_vfx_emit.gd").new().run(main, self)
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
	_net(m, V, P)
	await _core_kinds(main, m, V, P)
	await _lisette(main, V)
	await _scarf(main)
	await _rocket(main)
	print("HEROVFX %s" % ("OK" if bad == 0 else "%d failed" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)

## The moves a Hero's kit asks for (from its scripts' source).
func _called(arch: String) -> Dictionary:
	var called := {}
	var re := RegEx.create_from_string("(?:vfx\\(|(?:hold|trail)\\(\\w+(?:\\.\\w+)?, |play\\(h, )\"(\\w+)\"")
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
			var vortex_big: bool = layer["p"] in ["vortex", "ring"] and big > MAX_VORTEX
			var life := float(layer.get("life", 0.0))
			if layer["p"] == "ribbon" and layer.has("tail"):
				life = minf(life, HeroVfx.TRAIL_MAX)     # a projectile trail runs as long as its shot, capped
			var lasts: bool = layer["p"] == "thread"      # (a needle's thread stays as long as the needle)
			if (life > MAX_LIFE and not lasts) or flare_big or vortex_big:
				over.append(mv)
			if not (HeroVfx.MODES.has(layer["p"]) or HeroVfx.LOOKS.has(layer["p"]) or layer["p"] == "string"):
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

## Claire's two scarf tails (HeroScarf): one ribbon each pinned beside the neck anchor, which follows the neck bone;
## at rest they hang down behind her, running they stream back against the motion; a new frame after she moves, the
## roots are where the anchor went; off at the Low preset, back on without new meshes.
func _scarf(main: Node) -> void:
	var m: Match = flow._match(main, "rimewright")
	await main.get_tree().process_frame
	var P: Hunter = m.player
	var V := HeroVfx.of(m)
	Sfx.listener = P.pos
	var S := V.scarves
	var was: Variant = Settings.v.get("quality", "auto")
	Settings.v["quality"] = "high"
	S.tick(1.0 / 60.0)
	ok(S.wearers.size() == 1 and S.wearers[0].h == P and S.wearers[0].tails.size() == 2, "Claire wears two scarf tails")
	var w: HeroScarf.Wearer = S.wearers[0]
	var a: Dictionary = HeroVfx.data("rimewright")["anchors"]["scarf"]
	var sk := WardenGlb.skeleton(P.model.get_node_or_null("Warden"))
	var neck := V.anchor_pos(P, "scarf")
	if sk != null:
		var pose := sk.get_bone_global_pose(WardenSkeleton.find(sk, String(a["bone"])))
		var off := Vector3(a["off"][0], a["off"][1], a["off"][2])
		ok(neck.distance_to(sk.global_transform * (pose * off)) < 0.001, "the scarf anchor rides the neck bone")
	ok(neck.y > P.pos.y + 1.0 and neck.y < P.pos.y + 1.8, "the scarf anchor sits at her neck (%.2f m up)"
			% (neck.y - P.pos.y))
	for i in 90:
		S.tick(1.0 / 60.0)
	var ln := float(w.cfg["len"])
	var back := P.model.global_basis.z.normalized()
	for tail: HeroScarf.Tail in w.tails:
		var mesh := tail.node.mesh as ImmediateMesh
		ok(tail.node.visible and mesh.get_surface_count() == 1, "a tail is one ribbon mesh, drawn")
		var drop := tail.pts[0].y - tail.pts[-1].y
		ok(drop > ln * 0.7, "at rest a tail hangs (tip %.2f m under its root)" % drop)
		ok((tail.pts[-1] - tail.pts[0]).dot(back) > 0.0, "and hangs behind her, not through her")
	ok(S.made == 2, "one mesh per tail (%d)" % S.made)
	var step := Vector3(6.0, 0.0, 0.0) / 60.0
	for i in 60:
		P.model.global_position += step
		S.tick(1.0 / 60.0)
	var roots := S.roots(w)
	for j in 2:
		var tail: HeroScarf.Tail = w.tails[j]
		ok(tail.pts[0].distance_to(roots[j]) < 0.001, "a tail's root follows the anchor as she moves")
		var trail := tail.pts[0].x - tail.pts[-1].x
		ok(trail > ln * 0.4, "running at 6 m/s it streams behind her (%.2f m back)" % trail)
	Sfx.listener = P.pos + Vector3(HeroVfx.LOD_FAR * 2.0, 0.0, 0.0)
	S.tick(1.0 / 60.0)
	ok(w.tails.all(func(t: HeroScarf.Tail): return t.node.visible), "your own scarf shows past the LOD listener")
	Sfx.listener = P.pos
	Settings.v["quality"] = HeroScarf.OFF_PRESET
	S.tick(1.0 / 60.0)
	ok(w.tails.all(func(t: HeroScarf.Tail): return not t.node.visible), "off at the Low preset")
	Settings.v["quality"] = "high"
	S.tick(1.0 / 60.0)
	ok(w.tails.all(func(t: HeroScarf.Tail): return t.node.visible) and S.made == 2, "back on, the same meshes")
	Settings.v["quality"] = was
	S.prewarm(P.pos)
	S.prewarm_end()
	S.prewarm(P.pos)
	ok(S.made == 3, "the loading screen draws one more ribbon (its shader compiles then), pooled after")
	S.prewarm_end()

## The drop rocket (DropRocket): a thin trail in the squad colour from the nozzle that runs out after the landing, from
## the shared ribbon pool, as long at any frame rate, none at the very-low preset; a puff where a Hunter jumps out and
## dust settling where it lands, on Fx's dust pool, no ring or burst, also when another game's flags say so.
func _rocket(main: Node) -> void:
	var was: Variant = Settings.v.get("quality", "auto")
	Settings.v["quality"] = "high"
	var m := _rocket_match(main)
	var V := HeroVfx.of(m)
	var P: Hunter = m.player
	m.ship_jump(P)
	var r: DropRocket = P.rocket
	var e: Dictionary = V.ribbons[-1] if not V.ribbons.is_empty() else {}
	var nozzle: Node3D = e.get("follow")
	ok(r != null and nozzle != null and nozzle.get_parent() == r.node, "the launch starts a trail from the nozzle")
	if nozzle == null:
		return
	var col: Color = Data.TEAM_COLORS[P.team % Data.TEAM_COLORS.size()]
	ok((e["mat"] as ShaderMaterial).get_shader_parameter("col") == col and float(e["width"]) <= DropRocket.TRAIL_W,
			"the trail is in the squad colour and thin (%.2f m)" % float(e["width"]))
	_ride(m, V, ROCKET_RIDE)
	var pts: Array = e["pts"]
	var up: Vector3 = (pts[-1][0] as Vector3) - (pts[0][0] as Vector3)
	ok((pts[0][0] as Vector3).distance_to(nozzle.global_position) < 0.01, "its head rides the nozzle")
	ok(up.y > 0.0 and up.length() >= ROCKET_TRAIL_M, "it streams up behind the dive (%.1f m)" % up.length())
	_rocket_out(m, r)
	var high_dots := _rocket_land(m, V, r)
	await main.get_tree().process_frame
	_ride(m, V, DropRocket.TRAIL_S + 0.1)
	ok(not (e["node"] as Node3D).visible, "the trail runs out after the landing, back to the pool")
	_streaks(V)
	m.queue_free()
	Settings.v["quality"] = DropRocket.TRAIL_OFF
	m = _rocket_match(main)
	V = HeroVfx.of(m)
	m.ship_jump(m.player)
	r = m.player.rocket
	ok(r != null and V.ribbons.is_empty(), "no trail at the very-low preset")
	for h: Hunter in r.riders:
		h.remote = true          # another game flew it down: its riders' flags say they landed with it
		h.riding = false
		h.grounded = true
	var radial0: int = m.fx.radial
	var riders: Array = r.riders.duplicate()
	r.tick(Match.DT)
	for h: Hunter in riders:
		h.remote = false
	var dust := _settles(m.fx)
	ok(r.done and dust.size() == 1 and m.fx.radial == radial0, "the flags say they landed: the same dust here")
	if dust.size() == 1:
		ok((dust[0] as CPUParticles3D).amount < high_dots, "fewer dots at very low (%d, %d at high)"
				% [(dust[0] as CPUParticles3D).amount, high_dots])
	m.queue_free()
	Settings.v["quality"] = was

## A three-a-side squad match, everyone aboard the skyship ROCKET_AT seconds into its run.
func _rocket_match(main: Node) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": ROCKET_SEED})
	m.set_process(false)
	m.skydrop.planning = false
	for i in int(ROCKET_AT / Match.DT):
		m.step(Match.DT)
	return m

## Match steps with the looks' frames between them (the tree isn't running frames here).
func _ride(m: Match, V: HeroVfx, secs: float) -> void:
	for i in maxi(1, int(round(secs / Match.DT))):
		m.step(Match.DT)
		V._process(Match.DT)

## Jumping out, here and as another game's flags: a small puff where they let go, no ring and no burst.
func _rocket_out(m: Match, r: DropRocket) -> void:
	var mates: Array = r.riders.filter(func(x: Hunter): return x != m.player)
	var radial0 := m.fx.radial
	var puff: CPUParticles3D = m.fx.bursts[m.fx.bi]
	var at := r.exit_at()
	m.skydrop.detach(mates[0])
	var beside := Vector2(at.x - r.pos.x, at.z - r.pos.z).length()
	ok(puff.color == Fx.AIR and puff.global_position.distance_to(at) < 0.01 and beside > DropRocket.BODY_R,
			"jumping out leaves a small puff where they let go, beside the body (%d dots)" % puff.amount)
	var far: Hunter = mates[1]
	far.remote = true
	far.riding = false
	far.dropping = true
	puff = m.fx.bursts[m.fx.bi]
	at = r.exit_at()
	r.tick(Match.DT)
	far.remote = false
	ok(not r.riders.has(far) and puff.color == Fx.AIR and puff.global_position.distance_to(at) < 0.01,
			"another game's flags say one jumped out: the same puff here")
	ok(m.fx.radial == radial0, "no ring and no burst on jumping out")

## The rocket comes down: dust settles round it, low and slow, and no ring or burst from it or the riders'
## touchdowns. Returns the dust's dots.
func _rocket_land(m: Match, V: HeroVfx, r: DropRocket) -> int:
	var t := 0.0
	while t < ROCKET_CAP_S and r.pos.y - m.world.ground_at(r.pos.x, r.pos.z) > ROCKET_ALONE_M:
		_ride(m, V, Match.DT)
		t += Match.DT
	var radial0 := m.fx.radial
	while t < ROCKET_CAP_S and not r.done:
		r.tick(Match.DT)          # (the rocket alone: no one else's touchdown lands in the count)
		t += Match.DT
	ok(r.done and m.fx.radial == radial0, "the landing adds no ring or burst, nor do the riders' touchdowns")
	var dust := _settles(m.fx).filter(func(p: CPUParticles3D): return m.player.flat_dist(p.global_position) < 8.0)
	ok(dust.size() == 1, "dust settles where it lands, round the squad that stepped out")
	if dust.size() != 1:
		return 0
	var p: CPUParticles3D = dust[0]
	var ground := m.world.ground_at(p.global_position.x, p.global_position.z)
	ok(p.initial_velocity_max <= SETTLE_TOP_V and p.gravity.y > -2.0 and p.global_position.y - ground < 0.5,
			"low and slow, sinking back: not a blast (%.1f m/s, %d dots)" % [p.initial_velocity_max, p.amount])
	return p.amount

## Fx's dust emitters running a landing's settle.
func _settles(fx: Fx) -> Array:
	return fx.bursts.filter(func(p: CPUParticles3D): return p.color == Fx.HEAVY_DUST and p.emitting)

## A streak keeps a point a step, not a frame, so it is as long at 30 fps as at 144; a later one reuses a pooled
## ribbon; a pile of them stays within the pool.
func _streaks(V: HeroVfx) -> void:
	var made := V.made
	var slow := _streak_span(V, 30.0)
	ok(V.made == made, "a later trail reuses the pooled ribbon (no new node)")
	var fast := _streak_span(V, 144.0)
	ok(absf(fast - slow) < slow * 0.15, "as long at 144 fps as at 30 (%.1f m, %.1f m)" % [fast, slow])
	var dots: Array = []
	for i in STREAK_PILE:
		var dot := Node3D.new()
		V.add_child(dot)
		dots.append(dot)
		V.streak(dot, Color.WHITE, DropRocket.TRAIL_W, DropRocket.TRAIL_S)
	ok((V.pools["ribbon"] as Array).size() <= int(HeroVfx.POOL["ribbon"]), "%d trails at once stay in the pool (%d)"
			% [STREAK_PILE, (V.pools["ribbon"] as Array).size()])
	for dot: Node3D in dots:
		dot.queue_free()
	_clear(V)

## How long a streak behind a node diving at the rocket's speed is after a second at `fps`.
func _streak_span(V: HeroVfx, fps: float) -> float:
	var dot := Node3D.new()
	V.add_child(dot)
	V.streak(dot, Color.WHITE, DropRocket.TRAIL_W, DropRocket.TRAIL_S)
	var e: Dictionary = V.ribbons[-1]
	for i in int(fps):
		dot.global_position += Vector3.DOWN * DropRocket.FALL / fps
		V._process(1.0 / fps)
	var pts: Array = e["pts"]
	var span := (pts[-1][0] as Vector3).distance_to(pts[0][0])
	dot.queue_free()
	_clear(V)
	return span
