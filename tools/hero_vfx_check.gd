extends RefCounted
## --hero-vfx-check: the shared Hero looks (scripts/match/hero_vfx.gd) against every content/vfx file: each move a kit
## asks for has a recipe, each sound exists and is a one-shot, the colours resolve and the sizes stay in budget; the FX
## anchors fall back from the model's node to the Gun to the body; pools and live particles stay capped; distance
## thins and then drops a look; allies sit dimmer; a hold stops by itself; a move arrives from another game. Then, on a
## synthetic recipe set with one layer of every kind: a bone anchor follows the hand, prewarm makes one of every kind,
## a held stream turns with the aim, a projectile trail follows its node and ends with it. And the status looks
## (scripts/combat/status_looks.gd): every plain status brings its own look onto the body that has it, and only that.

const MAX_LIFE := 2.2          # s a look may linger (no long-lived noise)
const MAX_FLARE := 4.0         # m across, the largest burst (no screen-filling flashes)
const MAX_VORTEX := 4.5        # m radius, the largest ground swirl
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
	_statuses(m, P)
	await _core_kinds(main, m, V, P)
	await _lisette(main, V)
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
			var vortex_big: bool = layer["p"] == "vortex" and big > MAX_VORTEX
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

# ------------------------------------------------------------------ status looks
## The statuses the source makes readable on a body: each has a look in content/rules/status_looks.json.
const STATUSES := ["burn", "chill", "slow", "stun", "root", "gnd", "daze", "static", "antiheal", "sick"]
const RIG_PARTS := 16          # meshes one status look may use (30 Hunters each with a few stay cheap)

## Puts `st` on `F` the way the game does (its timers, KitStatus, a kit's keep) or takes it off.
func _set_status(m: Match, F: Hunter, st: String, on: bool) -> void:
	var t := 1.5 if on else 0.0
	match st:
		"stun": F.stun_t = t
		"root": F.root_t = t
		"slow": F.slow_t = t
		"burn": F.burn_t = t
		"antiheal": F.blight_t = t
		"sick": F.sick_t = t
		"gnd": F.set_meta("gnd_until", m.time + t)
		"daze": F.set_meta("rat_until", m.time + t)
		"chill", "static":
			if on: StatusLooks.of(m).keep(F, st)
			else: m.time += StatusLooks.KEEP + 0.01

func _statuses(m: Match, P: Hunter) -> void:
	var L := StatusLooks.of(m)
	var rules := StatusLooks.rules()
	var F: Hunter = null
	for h: Hunter in m.hunters:
		if h != P: F = h
	F.teleport(P.pos + Vector3(3.0, 0, 0))
	Sfx.listener = P.pos
	ok(STATUSES.all(func(st): return rules.has(st)), "status looks: every plain status has data")
	var looks := {}
	for st: String in STATUSES:
		_set_status(m, F, st, true)
		var up := L.showing(F, st)
		var rig: Node3D = (L.rigs.get("%d/%s" % [F.get_instance_id(), st], {}) as Dictionary).get("n")
		var parts := rig.find_children("*", "MeshInstance3D", true, false).size() if rig else 0
		ok(up and not L.showing(P, st), "status %s: its look comes up on that body only" % st)
		ok(parts > 0 and parts <= RIG_PARTS, "status %s: %d meshes (at most %d)" % [st, parts, RIG_PARTS])
		looks[String(rules[st]["look"])] = true
		_set_status(m, F, st, false)
		ok(not L.showing(F, st), "status %s: the look goes when it ends" % st)
	ok(looks.size() == STATUSES.size(), "status looks: each status has a look of its own (%d)" % looks.size())
	var made := L.made
	for st: String in STATUSES:
		_set_status(m, F, st, true)
	ok(STATUSES.all(func(st): return L.showing(F, st)) and L.made == made,
		"status looks: all at once on one body, from the pool (built %d)" % L.made)
	for st: String in STATUSES:
		_set_status(m, F, st, false)
	L.from_hit(F, {"stun": 0.5, "burn": 4.0, "burn_for": 2.0, "blight": 1.0})
	ok(L.showing(F, "stun") and L.showing(F, "burn") and L.showing(F, "antiheal"),
		"status looks: a hit sent to another game's body shows what it carries here")
	m.time += 2.1
	ok(not L.showing(F, "stun") and not L.showing(F, "burn"), "status looks: ... until that status would end")
	F.stun_t = 1.0
	F.teleport(P.pos + Vector3(StatusLooks.LOD_FAR + 4.0, 0, 0))
	ok(not L.showing(F, "stun"), "status looks: nothing draws past LOD_FAR")
	F.stun_t = 0.0
