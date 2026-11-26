extends RefCounted
## --hero-vfx-check: the shared Hero looks (scripts/match/hero_vfx.gd) against every content/vfx file: each move a kit
## asks for has a recipe, each sound exists and is a one-shot, the colours resolve and the sizes stay in budget; the FX
## anchors fall back from the model's node to the Gun to the body; pools and live particles stay capped; distance
## thins and then drops a look; allies sit dimmer; a hold stops by itself; a move arrives from another game. Then, on a
## synthetic recipe set with one layer of every kind: a bone anchor follows the hand, prewarm makes one of every kind,
## a held stream turns with the aim, a projectile trail follows its node and ends with it. Claire's scarf tails hang
## from their anchor, follow it, stream behind a run and are off at Low; her Rimelock breaks outward when she ends it
## and melts when it runs out. Each ability's emitter on the swapped models stays on its bone (tools/hero_vfx_emit.gd).
## And the status looks
## (scripts/combat/status_looks.gd): every plain status brings its own look onto the body that has it, and only that,
## and a summoned Boki under crowd control wears the same looks as a Hunter, sized to its body.
## The drop rocket's looks (DropRocket): its trail, the puff where a Hunter jumps out and the dust where it lands.

const MAX_LIFE := 2.2  # s a look may linger (no long-lived noise)
const ROCKET_AT := 6.0  # s into the ship's run when the squad launches: over the islands on ROCKET_SEED
const ROCKET_SEED := 4242
const ROCKET_RIDE := 1.5  # s ridden before the trail is measured: past the rocket's speed-up
const ROCKET_TRAIL_M := 10.0  # m of trail at least behind the dive by then, so it reaches up the skydive view
const ROCKET_ALONE_M := 3.0  # m over the ground from where only the rocket steps (the landing's count is its own)
const ROCKET_CAP_S := 20.0  # s a ride may take at most
const SETTLE_TOP_V := 5.0  # m/s: the landing dust is never faster than this (it settles, it does not blast)
const STREAK_PILE := 40  # streaks asked for at once: the pool still caps them
const MAX_FLARE := 4.0  # m across, the largest burst (no screen-filling flashes)
const ZONE_CORE_A := 0.25  # alpha at most at the centre of a zone (docs/VFX_QUALITY.md)
const MAX_VORTEX := 4.5  # m radius, the largest ground swirl or shockwave ring
const TRACER_FULL := 3  # steps (60/s) a round flies before its tracer must be drawn full length
const END_MS := 1.0  # ms of CPU a Rimelock end look may take to spawn from a warm pool
## The kit scripts whose vfx("move") / hold(h, "move") / trail(h, "move", ...) / play(h, "move") calls each Hero's
## data must answer.
const KIT_FILES := {
	"archer": ["archer_kit", "pin_"],
	"ashwick": ["ashwick_"],
	"bulwark": ["bulwark_kit", "bjorn_"],
	"dolm": ["dolm_kit", "breah_"],
	"dredge": ["dredge_"],
	"gil": ["gil_"],
	"gunslinger": ["gunslinger_"],
	"juggernaut": ["juggernaut_"],
	"mage": ["mage_"],
	"ostra": ["ostra_"],
	"rimewright": ["rimewright_"],
	"tender": ["tender_", "care_look"],
	"thief": ["thief_"]
}
## The synthetic recipes the runtime parts play: one layer of every kind.
const TEST := {
	"palette": {"main": "#ff8040", "hot": "#ffe080", "char": "#201008", "smoke": "#404040"},
	"anchors":
	{"palm": {"bone": "hand.R", "off": [0.0, 0.05, 0.0], "body": [0.3, 1.0, 0.2]}, "tip": {"body": [0.2, 1.1, 0.5]}},
	"moves":
	{
		"all":
		{
			"fx":
			[
				{"p": "sweep", "size": 2.0},
				{"p": "scorch", "size": 2.0},
				{"p": "skirt", "size": 1.5},
				{"p": "flare", "size": 1.5, "near": true},
				{"p": "ribbon", "at": "tip"},
				{"p": "thread", "len": 2.0},
				{"p": "bolt", "len": 4.0, "jag": 0.4},
				{"p": "portal", "size": 1.4},
				{"p": "vortex", "size": 2.0},
				{"p": "ring", "size": 2.0},
				{"p": "fist", "size": 2.0, "drop": 3.0},
				{"p": "ember", "n": 40},
				{"p": "smoke", "n": 12},
				{"p": "chunk", "n": 10},
				{"p": "shard", "n": 20},
				{"p": "card", "n": 10},
				{"p": "coin", "n": 20},
				{"p": "star", "n": 20},
				{"p": "drop", "n": 24},
				{"p": "plus", "n": 8}
			]
		},
		"ring": {"fx": [{"p": "sweep", "size": 2.0, "arc": 360, "band": 0.3, "turn": 0.16, "life": 0.5}]},
		"stream": {"fx": [{"p": "ember", "n": 20, "way": "fwd", "lift": 0.0}]},
		"shot": {"fx": [{"p": "ribbon", "size": 0.2, "life": 1.5, "tail": 0.15}]}
	}
}
## docs/VFX_QUALITY.md backlog 9, the shot trails that were hairlines at match zoom: Lace's tap shots, Sparkle's bolts.
## tender.json moves that heal, and moves that hurt (the rest, a hop and the dash, are hers and free)
const MEEKO_HEALS := [
	"heal_stars", "hearth", "hearth_land", "hearth_motes", "bloom", "call", "call_land", "call_plus", "mended"
]
const MEEKO_HURTS := [
	"cast",
	"cast_trail",
	"kindled",
	"seed_aim",
	"seed_cast",
	"seed_trail",
	"seed_stick",
	"seed_field",
	"seed_burst",
	"seed_root"
]
const SHOT_TRAILS := {"archer": "fire_tap", "mage": "lmb_trail"}
const TRAIL_MIN := 0.45  # m across at the head, so a shot trail reads at match zoom (the hairlines were 0.26)
const FIRE_HUE := Vector2(0.04, 0.2)  # hue (0..1) of orange through yellow: Kael's red keys stay out of it
## Moves a kit doesn't name in full: every Hero's own, built from a kind, or played by a shared look (rock crumble).
const CALLED_ELSEWHERE := [
	"hurt",
	"downed",
	"guard_shell",
	"string_idle",
	"string_draw",
	"fire_tap",
	"fire_arrow",
	"fire_super",
	"fire_over",
	"fire_heavy",
	"fire_ult",
	"rock_crumble"
]
## The camera-facing effect shaders that soften where they meet the ground (shaders/soft_fade.gdshaderinc).
## (fx_dot has its own ground fade: FxDot, ground_y.)
const SOFT_SHADERS := ["ld_fx", "ld_fx_glow", "hero_vfx", "hero_vfx_mote"]

const DT_FILL := 1.0 / 60.0  # s per step while timing the Faultline fill
const STATUSES := ["burn", "chill", "slow", "stun", "root", "gnd", "daze", "static", "antiheal", "sick"]
const RIG_PARTS := 16  # meshes one status look may use (30 Hunters each with a few stay cheap)
const BOKI_CC := ["stun", "root", "slow", "daze"]
const NO_RING := {
	"ashwick": ["flashover"],
	"dredge": ["anchor_slam", "reel"],
	"gil": ["dive", "tide_lunge", "beached", "wave_land"],
	"gunslinger": ["e_fire"],
	"juggernaut": ["slam_hit"],
}
const NO_SCORCH := {"dolm": ["row_tell"], "rimewright": ["rime", "rime_melt"]}
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
		_looks(arch)
	var gold: Array = []
	for f in DirAccess.get_files_at("res://scripts/arch/kits"):
		if f.ends_with(".gd") and FileAccess.get_file_as_string("res://scripts/arch/kits/" + f).contains("ffd25a"):
			gold.append(f)
	ok(gold.is_empty(), "no kit holds the shared gold ffd25a: a Hunter's flashes follow its colour %s" % [gold])
	await preload("res://tools/hero_vfx_emit.gd").new().run(main, self)
	preload("res://tools/hero_colour_check.gd").new().run(ok)
	var m: Match = flow._match(main, "juggernaut")
	await main.get_tree().process_frame
	var p: Hunter = m.player
	var v := HeroVfx.of(m)
	Sfx.listener = p.pos
	_anchors(v, p)
	_lod(v, p)
	_budget(v, p)
	await _holds(main, m, v, p)
	_view(m, v, p)
	_lean()
	_kit(m, v, p)
	_motley_trade(m, p)
	_dolm_rocks(m)
	_armour(m, p)
	_net(m, v, p)
	_statuses(m, p)
	_boki_statuses(m, p)
	_tier_up(m, v, p)
	_zones(main)
	_soft_edges(m)
	await _core_kinds(main, m, v, p)
	_shot_trails(m, v, p)
	await _lisette(main, v)
	await _vex_core(main)
	await _scarf(main)
	await _rime_ends(main)
	_dots(m)
	_decor_rings()
	await _sable_ring(main)
	await preload("res://tools/hero_cat_fence_check.gd").new().run(main, ok)
	await _rocket(main)
	await _vex_tracer(main)
	await _slam_fill(main)
	print("HEROVFX %s" % ("OK" if bad == 0 else "%d failed" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)


## Every camera-facing effect fades into the ground instead of cutting a line into it, on each renderer (one
## include, picked by renderer); the Compatibility fallback's ground map comes with the match world.
func _soft_edges(m: Match) -> void:
	for sname: String in SOFT_SHADERS:
		var code := (load("res://shaders/%s.gdshader" % sname) as Shader).code
		ok(code.contains("soft_fade.gdshaderinc") and code.contains("soft_fade("), "%s softens into the ground" % sname)
	ok(m.world.get_children().any(func(c: Node) -> bool: return c is FxGround), "the match world shares its ground map")


## The moves a Hero's kit asks for (from its scripts' source).
func _called(arch: String) -> Dictionary:
	var called := {}
	var re := RegEx.create_from_string('(?:vfx\\(|(?:hold|trail)\\(\\w+(?:\\.\\w+)?, |play\\(h, )"(\\w+)"')
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
	ok(
		not called.is_empty() and missing.is_empty(),
		"%s: all %d moves its kit calls have recipes %s" % [arch, called.size(), missing]
	)
	var ends := moves.values().map(func(rec): return String(rec.get("end", "")))  # a trail's end move
	var unused := moves.keys().filter(func(k): return not called.has(k) and not k in CALLED_ELSEWHERE and not k in ends)
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
			var flare_big: bool = layer["p"] in ["flare", "portal"] and big > MAX_FLARE
			var vortex_big: bool = layer["p"] in ["vortex", "ring"] and big > MAX_VORTEX
			var life := float(layer.get("life", 0.0))
			if layer["p"] == "ribbon" and layer.has("tail"):
				life = minf(life, HeroVfx.TRAIL_MAX)  # a projectile trail runs as long as its shot, capped
			var lasts: bool = layer["p"] == "thread"  # (a needle's thread stays as long as the needle)
			if (life > MAX_LIFE and not lasts) or flare_big or vortex_big:
				over.append(mv)
			if not (HeroVfx.MODES.has(layer["p"]) or HeroVfx.LOOKS.has(layer["p"]) or layer["p"] == "string"):
				flat_only.append(layer["p"])
	ok(bad_sound.is_empty(), "%s: every sound in the data has a file %s" % [arch, bad_sound])
	ok(bad_col.is_empty(), "%s: every colour is in the palette %s" % [arch, bad_col])
	ok(
		over.is_empty(),
		"%s: no look over %.1f s, %.1f m flare, %.1f m swirl %s" % [arch, MAX_LIFE, MAX_FLARE, MAX_VORTEX, over]
	)
	ok(flat_only.is_empty(), "%s: every layer is a known look %s" % [arch, flat_only])
	var loops: Array = []
	for mv: String in moves:
		for s: Dictionary in moves[mv].get("sfx", []):
			var st: Variant = Sfx.streams.get(s["n"], null)
			if st is AudioStreamWAV and (st as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
				loops.append(s["n"])
	ok(loops.is_empty(), "%s: every sound is a one-shot, nothing can outlive the match %s" % [arch, loops])


## Kael's black-red: his red keys and the model's crack colour stay out of orange and yellow
## (Cinder owns fire). The Gilded Riposte's gold keys stay gold on purpose.
func _looks(arch: String) -> void:
	if arch != "juggernaut":
		return
	var pal: Dictionary = HeroVfx.data(arch)["palette"]
	var cols := {"model_glow.core": Arch.def(arch).get("model_glow", {}).get("core", "")}
	for k: String in [
		"main",
		"hot",
		"char",
		"smoke",
		"red",
		"wave",
		"peak",
		"chain",
		"chain_iron",
		"chain_hot",
		"chain_hook",
		"haul",
		"haul_hot"
	]:
		cols[k] = pal.get(k, "")
	var warm: Array = []
	for k: String in cols:
		var c := Color(str(cols[k])) if str(cols[k]).is_valid_html_color() else Color.BLACK
		if c.s > 0.3 and c.v > 0.25 and c.h > FIRE_HUE.x and c.h < FIRE_HUE.y:
			warm.append(k)
	ok(warm.is_empty(), "%s: no red key is orange or yellow %s" % [arch, warm])


func _sound_exists(sname: String) -> bool:
	return ResourceLoader.exists("res://audio/%s.wav" % sname) or ResourceLoader.exists("res://audio/%s_1.wav" % sname)


## Model node, then the Gun, then the body. Works on today's model and on one with the named anchors.
func _anchors(v: HeroVfx, p: Hunter) -> void:
	var gun: Node3D = p.model.get_node("Rig/Torso/Aim/Gun")
	var a: Dictionary = HeroVfx.data("juggernaut")["anchors"]["blade_tip"]
	var via_gun: Vector3 = gun.global_transform * Vector3(a["gun"][0], a["gun"][1], a["gun"][2])
	var had_node: bool = WardenGlb.anchor(p.model, "weapon_muzzle") != null
	var tip := v.anchor_pos(p, "blade_tip")
	ok(had_node or tip.distance_to(via_gun) < 0.001, "blade_tip uses the Gun's space on a model without the anchor")
	var fake := Node3D.new()
	fake.name = "anchor_blade_tip"
	var host: Node = p.model.get_node_or_null("Warden")
	if host != null:
		host.add_child(fake)
		fake.global_position = p.pos + Vector3(1, 2, 3)
		v._anchors.clear()
		var seen := v.anchor_pos(p, "blade_tip")
		ok(seen.distance_to(fake.global_position) < 0.001, "a model's own anchor_blade_tip wins")
		host.remove_child(fake)
		v._anchors.clear()
	fake.free()
	var keep := p.model
	p.model = null
	var body := v.anchor_pos(p, "chest")
	ok(body.distance_to(p.pos + Vector3(0, 1.15, 0)) < 0.2, "no model at all: the body offset still places it")
	p.model = keep


func _visible_nodes(v: HeroVfx) -> int:
	var n := 0
	for kind: String in v.pools:
		for node in v.pools[kind]:
			if (node as Node3D).visible:
				n += 1
	return n


func _clear(v: HeroVfx) -> void:
	for kind: String in v.pools:
		for node in v.pools[kind]:
			(node as Node3D).visible = false
	v.live.clear()
	v.motes.clear()
	v.ribbons.clear()
	v.live_n = 0


func _lod(v: HeroVfx, p: Hunter) -> void:
	var o := {"r": 2.6, "core": 1.2}
	_clear(v)
	v.play(p, "drop_hit", p.pos, Vector2.RIGHT, o)
	var near_n := v.live_n
	var near_nodes := _visible_nodes(v)
	_clear(v)
	var mid := p.pos + Vector3(HeroVfx.LOD_NEAR + 4.0, 0, 0)
	v.play(p, "drop_hit", mid, Vector2.RIGHT, o)
	ok(
		v.live_n > 0 and v.live_n <= near_n * HeroVfx.LOD_MID_K + 1 and _visible_nodes(v) < near_nodes,
		"past LOD_NEAR: the near layers drop, the rest thin (%d -> %d particles)" % [near_n, v.live_n]
	)
	_clear(v)
	v.play(p, "drop_hit", p.pos + Vector3(HeroVfx.LOD_FAR + 4.0, 0, 0), Vector2.RIGHT, o)
	ok(v.live_n == 0 and _visible_nodes(v) == 0, "past LOD_FAR: nothing is drawn")


## The worst case: every big move at once, many times over.
func _budget(v: HeroVfx, p: Hunter) -> void:
	_clear(v)
	for i in 40:
		for mv in ["drop_hit", "slam_hit", "wave_fire", "riposte_land", "spin", "haul_hit"]:
			v.play(p, mv, p.pos, Vector2.RIGHT, {"r": 2.6, "core": 1.2, "len": 8.0, "w": 2.0})
	ok(v.live_n <= HeroVfx.MAX_LIVE, "a pile-up stays at the live cap (%d <= %d)" % [v.live_n, HeroVfx.MAX_LIVE])
	var capped := true
	for kind: String in v.pools:
		capped = capped and (v.pools[kind] as Array).size() <= int(HeroVfx.POOL[kind])
	ok(capped, "every pool stays within its cap")
	var made := v.made
	for i in 10:
		v.play(p, "drop_hit", p.pos, Vector2.RIGHT, {"r": 2.6, "core": 1.2})
	ok(v.made == made, "a warm pool makes no new nodes")
	_clear(v)


func _holds(main: Node, m: Match, v: HeroVfx, p: Hunter) -> void:
	v.hold(p, "enraged")
	ok(v.holds.size() == 1 and v.live_n > 0, "a hold starts emitting")
	var n0 := v.live_n
	v.hold(p, "enraged")
	ok(v.live_n == n0, "asking again keeps the one emitter")
	m.time += HeroVfx.HOLD_LINGER + 0.1
	v._tick_holds()
	ok(v.holds.is_empty(), "the asks stop: the hold ends by itself")
	await main.get_tree().process_frame
	_clear(v)


func _view(m: Match, v: HeroVfx, p: Hunter) -> void:
	ok(is_equal_approx(v.view_k(p), 1.0), "your own effects at full")
	var keep: Hunter = m.player
	var none := {"arch": "none"}
	var ally: Hunter = m.make_hunter("A", p.team, "medium", "Ally", "idle", {}, p.pos + Vector3(3, 0, 0), none)
	var foe: Hunter = m.make_hunter("B", p.team + 1, "medium", "Foe", "idle", {}, p.pos + Vector3(-3, 0, 0), none)
	ok(is_equal_approx(v.view_k(ally), HeroVfx.ALLY_K), "an ally's effects sit at ALLY_K")
	ok(is_equal_approx(v.view_k(foe), 1.0), "an enemy's effects at full")
	ok(keep == m.player, "the viewer is unchanged")


## A sweep stood up along the aim ("tilt" 90) turns up to its "lean" toward the match camera: no aim shows it
## edge-on, and it never tips past the lean.
func _lean() -> void:
	var back := Vector3(0, sin(deg_to_rad(57.0)), cos(deg_to_rad(57.0)))
	var layer := {"tilt": 90.0, "lean": 30.0}
	var worst := 1.0
	var within := true
	for i in 8:
		var b := Basis(Vector3.UP, TAU * i / 8.0)
		var roll := HeroVfx.sweep_roll(layer, b, back)
		var normal := b * Basis(Vector3(0, 0, 1), roll) * Vector3.UP
		worst = minf(worst, absf(normal.dot(back)))
		within = within and absf(roll - PI * 0.5) <= deg_to_rad(30.0) + 0.001
	var stood := HeroVfx.sweep_roll({"tilt": 90.0}, Basis(), back)
	var edge := absf((Basis(Vector3(0, 0, 1), stood) * Vector3.UP).dot(back))
	ok(worst > 0.4 and within and edge < 0.01, "a stood-up sweep leans to the camera at every aim (%.2f)" % worst)


## One language for armour on every body: a hit on the shell flashes the body shell-coloured, a health hit white, the
## break holds the flash and sheds shards with no ring or burst, and the HUD strip flashes as the armour empties.
func _armour(m: Match, p: Hunter) -> void:
	var at := p.pos + Vector3(-4, 0, 0)
	var foe: Hunter = m.make_hunter("A", p.team + 1, "medium", "Foe", "idle", {}, at, {"arch": "none"})
	foe.hurt(5.0, p, {})
	ok(foe.armor > 0.5 and foe.shell_t > 0.0, "a hit on the armour flashes the body shell-coloured")
	foe.tick_status(Juice.SHELL_FLASH_T + 0.01)
	foe.armor = 0.0
	foe.hurt(5.0, p, {})
	ok(foe.shell_t <= 0.0 and foe.flash_t > 0.0, "a hit on health flashes white")
	foe.armor = 1.0
	foe.shell_t = 0.0
	var radial0: int = m.fx.radial
	var rings0: int = m.fx.rings.size()
	foe.hurt(60.0, p, {})
	var held := foe.shell_t > Juice.SHELL_FLASH_T and foe.flash_t > Juice.SHELL_FLASH_T
	ok(foe.armor <= 0.0 and held, "the break holds the shell flash on the body")
	ok(m.fx.radial == radial0 and m.fx.rings.size() == rings0, "no ring and no burst with it")
	var plates := HudPlate.new()
	plates._watch(foe, 0.016)
	foe.armor = foe.max_armor
	plates._watch(foe, 0.016)
	foe.armor -= 5.0
	plates._watch(foe, 0.016)
	ok(plates.armor_flash_of(foe) > 0.5, "the armour strip flashes as it loses some")
	foe.hp = 0.0


## The kit really goes through the shared helper, and with the own look the shared cast language stays out.
func _kit(m: Match, v: HeroVfx, p: Hunter) -> void:
	var k: JuggernautKit = p.ak
	v.plays.clear()
	var rings0: int = m.fx.rings.size()
	k._slam()
	ok(int(v.plays.get("slam_hit", 0)) == 1, "the Finishing Slam plays its recipe")
	ok(m.fx.rings.size() == rings0, "no shared ring under it")
	ok(not m.fx.own_look and Sfx.skip.is_empty(), "the own-look scope closes")


## Motley's Trade in his sea teal (VFX_QUALITY 11-12 rescore, DECISIONS 11-08: every Hunter's abilities in their
## colour): the landing end and the lobbed lantern are teal, the hot core a lighter teal, and no ostra recipe, palette
## entry or Swollen look is magenta or pink, and his own end (TRADE_COL, the dash slot col) is teal too.
func _teal(c: Color) -> bool:
	return c.s < 0.25 or c.v < 0.15 or (c.h > 0.40 and c.h < 0.55)


func _mat_cols(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		var mt: Material = (n as MeshInstance3D).material_override
		if mt is StandardMaterial3D:
			out.append((mt as StandardMaterial3D).albedo_color)
		elif mt is ShaderMaterial:
			for u: Dictionary in (mt as ShaderMaterial).shader.get_shader_uniform_list():
				var v: Variant = (mt as ShaderMaterial).get_shader_parameter(u["name"])
				if v is Color:
					out.append(v)
	for c in n.get_children():
		_mat_cols(c, out)


func _motley_trade(m: Match, p: Hunter) -> void:
	var sea := Color("2ee6c0")
	ok(
		OstraKit.TRADE_EDGE.is_equal_approx(sea),
		"Motley Trade: the landing end is his sea teal #%s" % OstraKit.TRADE_EDGE.to_html(false)
	)
	ok(
		_teal(OstraKit.TRADE_COL) and _teal(Color(String(Arch.def("ostra")["dash"]["col"]))),
		"Motley Trade: his own end and the dash slot col are teal #%s" % OstraKit.TRADE_COL.to_html(false)
	)
	var hot := OstraKit.HOT
	ok(
		_teal(hot) and hot.s > 0.1 and hot.v >= sea.v and hot.s < sea.s,
		"Motley Trade: the hot core is a lighter teal #%s" % hot.to_html(false)
	)
	var d := HeroVfx.data("ostra")
	var off: Array = []
	for k: String in d["palette"]:
		if k == "pink" or not _teal(Color(String(d["palette"][k]))):
			off.append(k)
	ok(off.is_empty(), "Motley: every ostra palette colour is teal or neutral, none pink %s" % [off])
	var looks := KitLooks.of(m)
	for kind: String in ["star", "aura"]:
		var cols: Array = []
		_mat_cols(looks.hold_on("chk_" + kind, kind, p, p.pos), cols)
		looks.release("chk_" + kind)
		var bad_v: Array = cols.filter(func(c: Color): return not _teal(c)).map(func(c: Color): return c.to_html(false))
		ok(
			cols.size() >= 3 and bad_v.is_empty(),
			(
				"Motley %s: every colour is teal or neutral (%d, off %s)"
				% ["Trade lantern" if kind == "star" else "Swollen sphere", cols.size(), bad_v]
			)
		)
	ok(_teal(OstraWell.SWOLLEN_COL), "Motley Nightwell: the Swollen core is teal, not pink")


## Tenzo's thrown rocks are cold basalt with a cobalt rim (DECISIONS 11-08): no heat, no material warmer than blue.
func _dolm_rocks(m: Match) -> void:
	var warm: Array = []
	for kind in ["boulder", "rock", "dashrock"]:
		var n := KitLooks.of(m)._build(kind)
		for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
			var mat: Material = (mi as MeshInstance3D).material_override
			if mat is ShaderMaterial:
				var sm := mat as ShaderMaterial
				# the rock's own shader (glow, rim, heat) or a KitLooks.shade_mat haze (cel_tint's color)
				var hot := false
				for p: String in ["glow", "rim_col", "color"]:
					var c: Variant = sm.get_shader_parameter(p)
					hot = hot or (c is Color and (c as Color).r > (c as Color).b)
				var heat: Variant = sm.get_shader_parameter("heat")
				if hot or (heat != null and float(heat) > 0.0):
					warm.append(kind)
			elif mat is StandardMaterial3D:
				var c := (mat as StandardMaterial3D).albedo_color
				if c.r > c.b:
					warm.append(kind)
		n.free()
	for i in RockLook.COLS.size():  # his raised rocks (Stone Row, Basalt Spine): cobalt slate too
		var sm := RockLook._crag(i)[1] as ShaderMaterial
		var hues: Array = ["glow", "rim_col", "stone", "stone_hi", "cap_col"].map(sm.get_shader_parameter)
		if float(sm.get_shader_parameter("heat")) > 0.0 or hues.any(func(c: Color) -> bool: return c.r >= c.b):
			warm.append("crag%d" % i)
	ok(warm.is_empty(), "Tenzo's rocks: no heat, no rock or haze material warmer than the cobalt palette %s" % [warm])
	# the raised rocks (Stone Row, Basalt Spine) and his fists wear the arm's slate and teal: nothing red-leaning
	var raised: Array = [RockLook.make()]
	var fist := Node3D.new()
	HeroArms.build(fist, "rubble_fists", null, null, null)
	raised.append(fist)
	var red: Array = []
	for root: Node in raised:
		for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mat: Material = (mi as MeshInstance3D).material_override
			var cols: Array = []
			if mat is ShaderMaterial:
				for p: String in ["stone", "stone_hi", "glow", "rim_col", "cap_col", "color"]:
					cols.append((mat as ShaderMaterial).get_shader_parameter(p))
			elif mat is StandardMaterial3D:
				cols.append((mat as StandardMaterial3D).albedo_color)
			for c: Variant in cols:
				if c is Color and (c as Color).r > (c as Color).b:
					red.append("%s %s" % [mi.name, c])
		root.free()
	ok(red.is_empty(), "Tenzo's raised rocks and fists: slate and teal only, no warm material %s" % [red])


## Vex's rifle rounds are HeroVfx data (content/vfx/gunslinger.json): through a held string every live round of hers
## carries a tracer riding it, drawn 2-4.5 m long once the round has flown a few steps at the weapon's speed and wide
## enough to follow at match zoom, the stock round glow dark under it, with a flash at the gun for each round and a
## spark where one lands. The round nodes and the looks are stepped with the match here, as a 60 fps frame draws them.
func _vex_tracer(main: Node) -> void:
	var m: Match = flow._match(main, "gunslinger")
	await main.get_tree().process_frame
	var p: Hunter = m.player
	var v := HeroVfx.of(m)
	v.plays.clear()
	p.inp["aim"] = p.pos + Vector3(8.0, 0.9, 0.0)
	p.inp["aim_y"] = p.pos.y
	p.inp["fire"] = true
	var bare := 0  # steps a live round had no full tracer riding it
	var born := {}  # round sid -> the step it was first seen
	var thin := 0.0
	var lit := 0  # steps a tracer rode a round whose stock glow still showed
	var spd := float(p.wpn["speed"])
	for i in 150:
		m.step(1.0 / 60.0)
		m.render_shots(1.0)
		v._process(1.0 / 60.0)
		for sd: Dictionary in m.get("shots"):
			if sd["by"] != p or (sd["x"] as Dictionary).has("src") or not is_instance_valid(sd["node"]):
				continue
			var mine: Array = v.ribbons.filter(func(e: Dictionary): return e["follow"] == sd["node"])
			if not born.has(sd["sid"]):
				born[sd["sid"]] = i
				if born.size() == 1:
					var fly := (sd["vel"] as Vector2).length()
					ok(absf(fly - spd) < 0.5, "a round flies at the weapon's speed (%.0f m/s)" % spd)
			var drawn := 0.0  # the longest layer, head to tail, riding the round
			for e: Dictionary in mine:
				thin = maxf(thin, float(e["width"]))
				var pts: Array = e["pts"]
				if pts.size() > 1 and HeroVfx._at(pts[0]).distance_to((sd["node"] as Node3D).global_position) < 0.1:
					drawn = maxf(drawn, HeroVfx._at(pts[0]).distance_to(HeroVfx._at(pts[-1])))
			var age := i - int(born[sd["sid"]])  # steps since it was fired (the kit picks it up a step on)
			if (mine.is_empty() and age > 0) or (age >= TRACER_FULL and (drawn < 2.0 or drawn > 4.5)):
				bare += 1
			var orb := (sd["node"] as MeshInstance3D).material_override as ShaderMaterial
			if not mine.is_empty() and (orb.get_shader_parameter("color") as Color).a > 0.0:
				lit += 1
	p.inp["fire"] = false
	ok(born.size() >= 15, "a held string fires its rounds (%d)" % born.size())
	ok(bare == 0, "every live round has a tracer riding it, drawn 2-4.5 m long (%d bare)" % bare)
	ok(thin >= 0.3, "the tracer is wide enough for the match camera (%.2f m)" % thin)
	ok(lit == 0, "the tracer is the whole round: the stock glow is dark under it (%d lit)" % lit)
	var flashes := int(v.plays.get("shot", 0))
	var tracers := int(v.plays.get("shot_trail", 0))
	ok(flashes >= born.size(), "a muzzle flash for every round (%d of %d)" % [flashes, born.size()])
	ok(tracers >= born.size(), "a tracer for every round (%d of %d)" % [tracers, born.size()])
	var spark: Array = (v._rec(p, "shot_hit").get("fx", []) as Array).map(func(l: Dictionary): return String(l["p"]))
	ok(spark.has("flare") and spark.has("ember"), "a round that lands has a flash and sparks")


## docs/VFX_QUALITY.md: a zone is a lit rim and a soft inside, 0.25 alpha at most at the centre. Vex's X discs, Motley's
## well (floor and dome), Meeko's seed and Hearthlight discs and Sable's X ring, from the values the kits draw with.
func _zones(main: Node) -> void:
	var m: Match = flow._match(main, "gunslinger")
	# VVFx.disc (Sparkle's Skycall; Vex's discs are HeroVfx data since ext/vfx-vex-data)
	var vex: Node3D = VVFx.of(m).disc(Vector3.ZERO, 3.4, Color("2a1018"), Color("c43a2a"), 1.0, Color("ff9a5c"))
	var vm := (vex as MeshInstance3D).material_override as ShaderMaterial
	ok(
		(
			float(vm.get_shader_parameter("fill_a")) <= ZONE_CORE_A
			and (vm.get_shader_parameter("color3") as Color).a > 0.0
		),
		"VVFx disc: centre alpha at most %.2f and a lit rim" % ZONE_CORE_A
	)
	ok(is_equal_approx(vex.scale.x * VVFx.DISC_EDGE, 3.4), "VVFx disc: its rim on the hitbox radius")
	var looks := KitLooks.of(m)
	var well := looks.hold_on("zone_well", "well", m, Vector3.ZERO, 4.5)
	var fm := (well.get_node("Floor") as MeshInstance3D).material_override as ShaderMaterial
	var floor_a := float(fm.get_shader_parameter("fill")) * (fm.get_shader_parameter("color") as Color).a
	ok(
		floor_a <= ZONE_CORE_A and float(fm.get_shader_parameter("thickness")) > 0.0,
		"Motley's well: no solid floor (centre alpha 0), a lit rim"
	)
	var dome := looks.hold_on("zone_dome", "well_dome", m, Vector3.ZERO, 4.5)
	var dm := (dome.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	var dome_a := float(dm.get_shader_parameter("alpha")) * (float(dm.get_shader_parameter("body")) + 0.1)
	ok(dome_a <= ZONE_CORE_A, "Motley's well dome: centre alpha at most %.2f, the rim carries it" % ZONE_CORE_A)
	_meeko_field()
	_meeko_heal_hurt()


## Meeko's ground zones (the zone rule): care_disc's body grows as 0.18 + 0.22 r^2 to r 0.89, where its rim starts, and
## draws at 1.6x; the whole inside up to the rim stays at most 0.25, under the Burrseed root field and under the
## Hearthlight (on her at a 0.85, thrown at 1.1). The field wears the hurt colour; the burst's ring lands on its rim
## (the ring shader's band ends at 0.9 of its size).
func _meeko_field() -> void:
	var d := HeroVfx.data("tender")
	var fd: Dictionary = d["field"]
	var hd: Dictionary = d["hearth_disc"]
	var rim_k := (0.18 + 0.22 * 0.89 * 0.89) * 1.6
	var inside := {
		"root field": float(fd["fill"]) * float(fd["a"]) * rim_k,
		"Hearthlight on her": float(hd["fill"]) * 0.85 * rim_k,
		"Hearthlight thrown": float(hd["thrown_fill"]) * 1.1 * rim_k,
	}
	for what: String in inside:
		ok(
			inside[what] <= ZONE_CORE_A,
			"Meeko's %s: inside alpha at most %.2f to the rim (%.2f)" % [what, ZONE_CORE_A, inside[what]]
		)
	var hurt := Color(String(d["palette"][fd["col"]]))
	ok(not _heal_hue(hurt), "Meeko's root field: the hurt colour, not her heal green (%s)" % hurt.to_html(false))
	var ring: Array = (d["moves"]["seed_burst"]["fx"] as Array).filter(func(l): return l["p"] == "ring")
	ok(
		ring.size() == 1 and ring[0]["size"] == "r" and absf(float(ring[0]["size_x"]) * 0.9 - 1.0) < 0.01,
		"Meeko's root field: the burst's ring lands on the burst radius"
	)
	var hit: Array = d["moves"]["ember_hit"]["fx"]
	ok(
		hit.any(func(l): return l["p"] == "chunk") and hit.any(func(l): return l["p"] == "ember"),
		"Meeko's Ember Cast hit: a leaf chunk-and-spark burst"
	)
	var call_ring: Array = (d["moves"]["call"]["fx"] as Array).filter(func(l): return l["p"] == "ring")
	ok(call_ring.size() == 1 and call_ring[0]["size"] == "r", "Meeko's Hearth Call: a ring at the tether's reach")


## Meeko's heals and hurts read apart (COMBAT_CLARITY): every heal look is her leaf green family and its motes rise,
## every hurt look is another hue (embers) and its motes fall, sharp (no curl); the Hearthlight's last bloom swirls
## only on its rim (no filled disc).
func _meeko_heal_hurt() -> void:
	var d := HeroVfx.data("tender")
	var pal: Dictionary = d["palette"]
	var bad_v: Array = []
	for mv: String in d["moves"]:
		var heal := MEEKO_HEALS.has(mv)
		var hurt := MEEKO_HURTS.has(mv)
		for layer: Dictionary in d["moves"][mv]["fx"]:
			for key in ["c", "c2", "c3"]:
				var c := Color(String(pal[layer[key]])) if layer.has(key) else Color.GRAY
				if c.s >= 0.25 and ((heal and not _heal_hue(c)) or (hurt and _heal_hue(c))):
					bad_v.append("%s.%s" % [mv, layer[key]])
			if not HeroVfx.LOOKS.has(String(layer["p"])):
				continue
			var grav := float(layer.get("grav", 0.0))
			if (heal and grav > 0.0) or (hurt and (grav <= 0.0 or float(layer.get("curl", 0.0)) > 0.0)):
				bad_v.append("%s motion" % mv)
	ok(bad_v.is_empty(), "Meeko: heals leaf green and rising, hurts embers falling %s" % [bad_v])
	var swirl: Array = (d["moves"]["bloom"]["fx"] as Array).filter(func(l): return l["p"] == "vortex")
	ok(swirl.all(func(l): return bool(l.get("thin", false))), "Meeko's bloom: a rim swirl, no filled disc")


## True when `c` sits in Meeko's heal family: her leaf green's hue band in the colour check.
func _heal_hue(c: Color) -> bool:
	var dh := absf(c.h - Arch.color("tender").h) * 360.0
	return minf(dh, 360.0 - dh) <= preload("res://tools/hero_colour_check.gd").FAMILY_DEG


## Her needles: one that misses stays in the ground with its thread; the bow's string stands down for a model's own.
func _lisette(main: Node, v0: HeroVfx) -> void:
	var m: Match = flow._match(main, "archer")
	await main.get_tree().process_frame
	var p: Hunter = m.player
	var v := HeroVfx.of(m)
	ok(v != v0, "a new match has its own pools")
	Sfx.listener = p.pos
	var k: ArcherKit = p.ak
	k.fx._plant(p.pos + Vector3(3, 0, 0), Vector2(1, 0), "arrow")
	ok(int(v.plays.get("needle_stuck", 0)) == 1, "a missed needle leaves its thread")
	var last: Dictionary = v.live.filter(func(e): return (e["node"] as Node3D).visible)[0]
	ok(is_equal_approx(float(last["dur"]), PinFx.SPENT_T), "the thread lasts as long as the needle")
	ok(is_equal_approx(PinFx.HEAVY_SCALE, 6.0), "the Heavy Shot stays big")
	v.hold(p, "string_idle")
	var key := "%d/string_idle" % p.get_instance_id()
	var wanted: int = 0 if v._model_has(p, "halo_bow_mid") else 1
	ok((v.holds[key]["layers"] as Array).size() == wanted, "the string shows unless the model brings its own")
	var hip := v.anchor_pos(p, "nock")
	ok(
		hip.distance_to(k.hand_pos(true)) < 0.001 or WardenGlb.anchor(p.model, "anchor_nock") != null,
		"nock: the model's anchor, else the drawing hand"
	)


## Cinderfall's hot centre ring: at every ult rank it sits at the radius the +core_k damage uses (the data's
## core_r), everyone sees it (rivals in the hostile tint) and it fills toward the impact with the outer disc.
func _vex_core(main: Node) -> void:
	var m: Match = flow._match(main, "gunslinger")
	await main.get_tree().process_frame
	var p: Hunter = m.player
	var u: GunslingerUlt = (p.ak as GunslingerKit).ult
	var want := float(p.ak.x_def()["core_r"])
	for rank in range(1, int(Hunter.SLOT_MAX["ult"]) + 1):
		p.lvl = int(Hunter.ULT_AT[rank - 1])
		p.slot_lv["ult"] = rank
		u.cast()
		u.tick(0.4)
		var ring := AimKit.entry(p, "xc%d" % u.casts)
		var fill := float(AimKit.entry(p, "x%d" % u.casts).get("fill", -1.0))
		ok(
			(
				is_equal_approx(float(ring.get("r", 0.0)), want)
				and is_equal_approx(u.core_r(), want)
				and bool(ring.get("all", false))
				and fill > 0.0
				and is_equal_approx(float(ring.get("fill", 0.0)), fill)
			),
			(
				"Cinderfall rank %d: the centre ring is the damage core (%.2f m), seen by all, filling with the disc"
				% [rank, want]
			)
		)
		u.clear()


## The shared kinds on a synthetic recipe set (the real files are done with): every layer kind plays and a pile-up
## stays capped; a bone anchor follows the hand; prewarm builds one of every kind and hides them; a stream held along
## the aim turns with it; a projectile's trail follows its node and runs out when it is gone.
func _core_kinds(main: Node, m: Match, v: HeroVfx, p: Hunter) -> void:
	HeroVfx.set_data(p.arch, TEST)
	v._anchors.clear()
	_clear(v)
	v.play(p, "all", p.pos, Vector2.RIGHT)
	# (- 1: the tier-up sheen is drawn by HeroVfx.tier_up, never by a recipe layer)
	ok(_visible_nodes(v) >= HeroVfx.MODES.size() + HeroVfx.LOOKS.size() - 1, "every layer kind plays")
	for i in 40:
		v.play(p, "all", p.pos, Vector2.RIGHT)
	ok(v.live_n <= HeroVfx.MAX_LIVE, "a pile-up of every kind stays at the live cap (%d)" % v.live_n)
	_clear(v)
	v.play(p, "ring", p.pos, Vector2.RIGHT)
	v.play(p, "all", p.pos, Vector2.RIGHT)
	var arcs := [v._arc(360.0), v._arc(120.0)]
	var sweeps := v.live.filter(func(e): return (e["node"] as MeshInstance3D).mesh in arcs)
	var got := sweeps.map(
		func(e):
			return [
				(e["mat"] as ShaderMaterial).get_shader_parameter("head_t"),
				(e["mat"] as ShaderMaterial).get_shader_parameter("band")
			]
	)
	ok(
		(
			sweeps.size() == 2
			and is_equal_approx(got[0][0], 0.32)
			and is_equal_approx(got[0][1], 0.3)
			and is_equal_approx(got[1][0], 0.28)
			and got[1][1] == 0.0
		),
		"a sweep's even band runs round in its own turn (0.16 of 0.5 s); a plain one keeps the taper %s" % [got]
	)
	_clear(v)
	var sk := WardenGlb.skeleton(p.model.get_node_or_null("Warden"))
	var palm := v.anchor_pos(p, "palm")
	if sk != null:
		var pose := sk.get_bone_global_pose(WardenSkeleton.find(sk, "hand.R"))
		var want := sk.global_transform * (pose * Vector3(0.0, 0.05, 0.0))
		ok(palm.distance_to(want) < 0.001, "a bone anchor follows the model's hand.R")
	else:
		ok(palm.distance_to(p.pos) < 1.6, "a bone anchor on a model without a skeleton falls back to the body")
	v.prewarm(p.pos)
	ok(v._warming.size() == HeroVfx.POOL.size(), "prewarm holds up one node of every kind (%d)" % v._warming.size())
	v.prewarm_end()
	ok(_visible_nodes(v) == 0 and v._warming.is_empty(), "and they are hidden again")
	p.inp["aim"] = p.pos + Vector3(4, 0, 0)
	v.hold(p, "stream")
	p.inp["aim"] = p.pos + Vector3(0, 0, 4)
	v._tick_holds()
	var lay: Dictionary = v.holds.values()[0]["layers"][0]
	var way: Vector3 = (lay["node"].process_material as ShaderMaterial).get_shader_parameter("dir")
	ok(way.distance_to(Vector3(0, 0, 1)) < 0.01, "a stream held along the aim turns with it (%s)" % way)
	m.time += HeroVfx.HOLD_LINGER + 0.1
	v._tick_holds()
	_clear(v)
	var shot := Node3D.new()
	m.add_child(shot)
	shot.global_position = p.pos + Vector3(0, 1, 0)
	v.trail(p, "shot", shot)
	ok(v.ribbons.size() == 1, "a projectile gets its trail")
	for i in 4:  # (ticked by hand: on a loaded box a frame's delta can outlast the tail)
		shot.global_position += Vector3(0.5, 0, 0)
		v._tick_ribbon(v.ribbons[0], 0.02)
	ok((v.ribbons[0]["pts"] as Array).size() >= 3, "the trail follows the projectile")
	shot.visible = false
	for i in 30:
		await main.get_tree().process_frame
	ok(v.ribbons.is_empty(), "the projectile ends: its tail runs out")
	shot.queue_free()
	_clear(v)
	HeroVfx.set_data(p.arch, {})


## Lace's tap shots and Sparkle's finger bolts: thick at match zoom with a bright head, the body in the Hunter's colour;
## Lace's long and sharp, Sparkle's a wider, blunter streak; Lace's drawn arrows stay above the tap; a head fits the
## circle its shot hits in (the hit sizes are the weapons'). Flying: the head is part of the trail's own mesh, a pooled
## node keeps no look of the last Hunter's, and a volley makes no node once the pool is warm. The stock orb under such a
## round stays hidden (Oomph.hide_orb).
func _shot_trails(m: Match, v: HeroVfx, p: Hunter) -> void:
	var reach := {}
	for arch: String in SHOT_TRAILS:
		var lay := _ribbon_of(arch, SHOT_TRAILS[arch])
		var shot: Dictionary = Content.weapon(Arch.signature(arch)).primary
		var col := Color(String(HeroVfx.data(arch)["palette"][lay["c"]]))
		var head := float(lay.get("head", 0.0))
		reach[arch] = float(lay["tail"]) * float(shot["speed"])  # m of trail behind the head
		ok(
			float(lay["size"]) >= TRAIL_MIN and head > 0.0,
			"%s %s: %.2f m across, a %.2f m head" % [arch, SHOT_TRAILS[arch], float(lay["size"]), head]
		)
		ok(
			col.is_equal_approx(Arch.color(arch)),
			"%s: the trail is the Hunter's colour (#%s)" % [arch, col.to_html(false)]
		)
		ok(head * 0.5 <= float(shot["size"]) + p.hit_radius(), "%s: the head fits the circle its shot hits in" % arch)
	var tap := _ribbon_of("archer", "fire_tap")
	var bolt := _ribbon_of("mage", "lmb_trail")
	ok(
		not tap.get("soft", false) and float(tap.get("head_len", 1.0)) >= 2.0,
		"Lace's is sharp: %.1f m of trail, a pointed head" % reach["archer"]
	)
	ok(
		float(bolt["size"]) > float(tap["size"]) and float(bolt.get("head_len", 1.0)) < float(tap["head_len"]),
		"Sparkle's is a wider, blunter streak than Lace's: %.1f m of trail" % reach["mage"]
	)
	var sizes := ["fire_tap", "fire_arrow", "fire_super"].map(func(mv): return float(_ribbon_of("archer", mv)["size"]))
	ok(sizes[0] < sizes[1] and sizes[1] < sizes[2], "Lace's drawn arrows stay thicker than the tap %s" % [sizes])
	var shot := Node3D.new()
	m.add_child(shot)
	shot.global_position = p.pos + Vector3(0, 1, 0)
	_clear(v)
	_shoot(v, p, "mage", shot)
	var node: Node3D = v.ribbons[0]["node"]
	_clear(v)
	_shoot(v, p, "archer", shot)
	var e: Dictionary = v.ribbons[0]
	ok(
		e["node"] == node and not (e["mat"] as ShaderMaterial).get_shader_parameter("soft"),
		"a pooled trail Sparkle used comes back hard-edged for Lace"
	)
	for i in 4:  # (by hand, as above)
		shot.global_position += Vector3(1.0, 0, 0)
		v._tick_ribbon(e, 0.016)
	var ahead := (e["node"] as MeshInstance3D).mesh.get_aabb().end.x - shot.global_position.x
	var tip := float(tap["head"]) * float(tap["head_len"]) * 0.5
	ok(absf(ahead - tip) < 0.01, "the head is in the trail's own mesh, its tip %.2f m ahead of the shot" % ahead)
	for i in HeroVfx.POOL["ribbon"]:
		_shoot(v, p, "archer", shot)
	var made := v.made
	for i in 24:
		_shoot(v, p, "archer" if i % 2 == 0 else "mage", shot)
	ok(
		v.made == made and v.ribbons.size() <= int(HeroVfx.POOL["ribbon"]),
		"a volley of 24 draws on the ribbon pool: no new node (%d running)" % v.ribbons.size()
	)
	shot.queue_free()
	_clear(v)
	HeroVfx.set_data(p.arch, {})
	m.spawn_shot(p, p.pos + Vector3(0, 1, 0), Vector2(30, 0), 0.0, 0.5, 0.18, Color.WHITE)
	var drawn: Dictionary = m.shots[-1]
	Oomph.hide_orb(drawn)
	m.render_shots(1.0)
	ok(
		(drawn["node"] as Node3D).scale.x < 0.01 and is_equal_approx(float(drawn["r"]), 0.18),
		"a round its kit draws keeps the stock orb shrunk through the match's frame; its hit size is kept"
	)


## One shot trail as `arch`'s (its recipes stand in for the test Hunter's own).
func _shoot(v: HeroVfx, p: Hunter, arch: String, shot: Node3D) -> void:
	HeroVfx.set_data(p.arch, HeroVfx.data(arch))
	v.trail(p, SHOT_TRAILS[arch], shot)


func _ribbon_of(arch: String, move: String) -> Dictionary:
	for layer: Dictionary in HeroVfx.data(arch)["moves"][move]["fx"]:
		if layer["p"] == "ribbon":
			return layer
	return {}


func _net(m: Match, v: HeroVfx, p: Hunter) -> void:
	v.plays.clear()
	m.ents_by_id[p.nid] = p
	v.net_in(["fx", "hvfx", p.nid, "spin", p.pos.x, p.pos.y, p.pos.z, 1.0, 0.0, 0.0, 0.0, 2.6])
	ok(int(v.plays.get("spin", 0)) == 1, "a move arrives from another game")


## The armour tier-up sheen: one per tier-up (the real path, Match._armor_up), coloured by the new tier, climbing the
## body for SHEEN_LIFE; a break and a gain that stays inside the tier draw none; another game's tier-up arrives too.
func _tier_up(m: Match, v: HeroVfx, p: Hunter) -> void:
	_clear(v)
	v.plays.clear()
	var sheens := func() -> Array:
		return (v.pools.get("sheen", []) as Array).filter(func(n: Node3D) -> bool: return n.visible)
	p.armor_xp = 0.0
	p.armor_tier = 0
	ok(p.armor_gain(10.0) < 0, "a gain inside the tier is no tier-up")
	ok(sheens.call().is_empty() and int(v.plays.get("armor_up", 0)) == 0, "no sheen without a tier-up")
	for tier in range(1, Hunter.ARMOR_TIERS.size()):
		_clear(v)
		v.plays.clear()
		p.armor_gain(float(Hunter.ARMOR_TIERS[tier][2]) - p.armor_xp)
		m._armor_up(p)
		var made: Array = sheens.call()
		ok(made.size() == 1 and int(v.plays.get("armor_up", 0)) == 1, "tier %d: one sheen" % tier)
		var col := Color.BLACK
		if made.size() == 1:
			col = (made[0].material_override as ShaderMaterial).get_shader_parameter("col")
		ok(col.is_equal_approx(Hunter.ARMOR_TIERS[tier][1]), "tier %d: the new tier's colour" % tier)
	ok(v.live.size() == 1 and is_equal_approx(float(v.live[0]["dur"]), 0.4), "the sheen sweeps in 0.4 s")
	_clear(v)
	v.plays.clear()
	m.on_armor_break(p, null)
	ok(sheens.call().is_empty() and int(v.plays.get("armor_up", 0)) == 0, "no sheen on an armour break")
	v.net_in(["fx", "hvfx", p.nid, "armor_up", p.pos.x, p.pos.y, p.pos.z, 0.0, 0.0, 2.0, 0.0, 0.0])
	ok(sheens.call().size() == 1, "a rival's tier-up arrives from another game")


## Claire's two scarf tails (HeroScarf): one ribbon each pinned beside the neck anchor, which follows the neck bone;
## at rest they hang down behind her, running they stream back against the motion; a new frame after she moves, the
## roots are where the anchor went; off at the Low preset, back on without new meshes.
func _scarf(main: Node) -> void:
	var m: Match = flow._match(main, "rimewright")
	await main.get_tree().process_frame
	var p: Hunter = m.player
	var v_v := HeroVfx.of(m)
	Sfx.listener = p.pos
	var s := v_v.scarves
	var was: Variant = Settings.v.get("quality", "auto")
	Settings.v["quality"] = "high"
	s.tick(1.0 / 60.0)
	ok(s.wearers.size() == 1 and s.wearers[0].h == p and s.wearers[0].tails.size() == 2, "Claire wears two scarf tails")
	var w: HeroScarf.Wearer = s.wearers[0]
	var a: Dictionary = HeroVfx.data("rimewright")["anchors"]["scarf"]
	var sk := WardenGlb.skeleton(p.model.get_node_or_null("Warden"))
	var neck := v_v.anchor_pos(p, "scarf")
	if sk != null:
		var pose := sk.get_bone_global_pose(WardenSkeleton.find(sk, String(a["bone"])))
		var off := Vector3(a["off"][0], a["off"][1], a["off"][2])
		ok(neck.distance_to(sk.global_transform * (pose * off)) < 0.001, "the scarf anchor rides the neck bone")
	ok(
		neck.y > p.pos.y + 1.0 and neck.y < p.pos.y + 1.8,
		"the scarf anchor sits at her neck (%.2f m up)" % (neck.y - p.pos.y)
	)
	for i in 90:
		s.tick(1.0 / 60.0)
	var ln := float(w.cfg["len"])
	var back := p.model.global_basis.z.normalized()
	for tail: HeroScarf.Tail in w.tails:
		var mesh := tail.node.mesh as ImmediateMesh
		ok(tail.node.visible and mesh.get_surface_count() == 1, "a tail is one ribbon mesh, drawn")
		var drop := tail.pts[0].y - tail.pts[-1].y
		ok(drop > ln * 0.7, "at rest a tail hangs (tip %.2f m under its root)" % drop)
		ok((tail.pts[-1] - tail.pts[0]).dot(back) > 0.0, "and hangs behind her, not through her")
	ok(s.made == 2, "one mesh per tail (%d)" % s.made)
	var step := Vector3(6.0, 0.0, 0.0) / 60.0
	for i in 60:
		p.model.global_position += step
		s.tick(1.0 / 60.0)
	var roots := s.roots(w)
	for j in 2:
		var tail: HeroScarf.Tail = w.tails[j]
		ok(tail.pts[0].distance_to(roots[j]) < 0.001, "a tail's root follows the anchor as she moves")
		var trail := tail.pts[0].x - tail.pts[-1].x
		ok(trail > ln * 0.4, "running at 6 m/s it streams behind her (%.2f m back)" % trail)
	Sfx.listener = p.pos + Vector3(HeroVfx.LOD_FAR * 2.0, 0.0, 0.0)
	s.tick(1.0 / 60.0)
	ok(w.tails.all(func(t: HeroScarf.Tail): return t.node.visible), "your own scarf shows past the LOD listener")
	Sfx.listener = p.pos
	Settings.v["quality"] = HeroScarf.OFF_PRESET
	s.tick(1.0 / 60.0)
	ok(w.tails.all(func(t: HeroScarf.Tail): return not t.node.visible), "off at the Low preset")
	Settings.v["quality"] = "high"
	s.tick(1.0 / 60.0)
	ok(w.tails.all(func(t: HeroScarf.Tail): return t.node.visible) and s.made == 2, "back on, the same meshes")
	Settings.v["quality"] = was
	s.prewarm(p.pos)
	s.prewarm_end()
	s.prewarm(p.pos)
	ok(s.made == 3, "the loading screen draws one more ribbon (its shader compiles then), pooled after")
	s.prewarm_end()


## Albert's Faultline tell (BjornUlt): the lane's fill sweeps out over exactly the wind-up from the data, at
## every rank, and the slam lands on the very step it closes (fill 1.0). Also with a changed windup, so the
## time is read from data.
func _slam_fill(main: Node) -> void:
	var m: Match = flow._match(main, "bulwark")
	await main.get_tree().process_frame
	var p: Hunter = m.player
	var k: BulwarkKit = p.ak
	var xd: Dictionary = k.d["x"]
	var windup0: float = xd["windup"]
	p.lvl = 6
	for rank in [1, 2, 3, 0]:
		xd["windup"] = 0.6 if rank == 0 else windup0
		for slot: String in p.slot_lv:
			p.slot_lv[slot] = maxi(rank, 1)
		k.cd["x"] = 0.0
		k.ult.cast()
		var t_full := -1.0
		var t_slam := -1.0
		var t := 0.0
		while k.ult.phase != "" and t < 2.0 and t_slam < 0.0:
			m.step(DT_FILL)
			t += DT_FILL
			if t_full < 0.0 and float(AimKit.entry(p, "x").get("fill", 0.0)) >= 1.0:
				t_full = t
			if k.ult.slams > 0:
				t_slam = t
		var label := (
			"rank %d windup %.2f: fill closed at %.3f s, slam at %.3f s" % [maxi(rank, 1), xd["windup"], t_full, t_slam]
		)
		ok(absf(t_full - float(xd["windup"])) <= DT_FILL and t_full == t_slam, label)
		k.ult.slams = 0
		k.ult.phase = ""
		k.ult._hide_lane()
	xd["windup"] = windup0
	m.queue_free()


## Rimelock's ends read apart, each with its own look: X or Shift before the time is up (even the late crack) breaks
## the shell outward with a flash, the time running out melts it off her. Warm, each look spawns in under END_MS.
func _rime_ends(main: Node) -> void:
	var m: Match = flow._match(main, "rimewright")
	await main.get_tree().process_frame
	var p: Hunter = m.player
	var v := HeroVfx.of(m)
	var k: RimewrightKit = p.ak
	var hold := float(k.x_def()["hold"])
	var late := hold - float(k.x_def()["late"]) * 0.5
	for path: Array in [["X early", 1.0, "x"], ["X late", late, "x"], ["Shift", 1.0, "dash"], ["time up", hold, ""]]:
		v.plays.clear()
		k._start_rime()
		k.rime["t"] = float(path[1]) - 0.001
		match String(path[2]):
			"x":
				k.ult_recast()
			"dash":
				p.inp["dash"] = true
				k._tick_rime(0.01)
				p.inp["dash"] = false
			_:
				k._tick_rime(0.01)
		var want := "rime_melt" if path[2] == "" else "rime_break"
		var not_want := "rime_break" if path[2] == "" else "rime_melt"
		ok(
			k.rime.is_empty() and int(v.plays.get(want, 0)) == 1 and not v.plays.has(not_want),
			"Rimelock ended by %s: %s, not %s" % [path[0], want, not_want]
		)
	for mv: String in ["rime_break", "rime_melt"]:
		var best := INF
		for i in 5:
			var t0 := Time.get_ticks_usec()
			v.play(p, mv, p.pos, Vector2.RIGHT)
			best = minf(best, (Time.get_ticks_usec() - t0) / 1000.0)
		ok(best < END_MS, "%s spawns in %.3f ms (< %.1f)" % [mv, best, END_MS])
	for i in 20:
		v.play(p, "rime_break", p.pos, Vector2.RIGHT)
		v.play(p, "rime_melt", p.pos, Vector2.RIGHT)
	var made := v.made
	v.play(p, "rime_break", p.pos, Vector2.RIGHT)
	v.play(p, "rime_melt", p.pos, Vector2.RIGHT)
	ok(v.made == made and v.live_n <= HeroVfx.MAX_LIVE, "a pile-up of ends stays pooled and capped (%d nodes)" % made)
	_clear(v)
	m.queue_free()


## The soft dots: every burst and wisp sparkle shares the one FxDot material; Low and Very Low take the height-fade
## variant (no depth read, so no depth copy) and the other presets the shader's own pick per renderer; a burst
## tells the dots the ground under it.
func _dots(m: Match) -> void:
	var was: Variant = Settings.v.get("quality", "auto")
	Settings.v["quality"] = "high"
	var high := FxDot.material()
	Settings.v["quality"] = "low"
	var low := FxDot.material()
	ok(low.shader != high.shader and low.shader.code.begins_with("#define DOT_HEIGHT_FADE"), "Low dots fade by height")
	ok(not high.shader.code.begins_with("#define") and FxDot.material() == low, "one material per preset")
	Settings.v["quality"] = was
	var at := Vector3(m.player.pos.x, m.player.pos.y + 1.0, m.player.pos.z)
	m.fx.burst(at, Color.WHITE)
	var p: CPUParticles3D = m.fx.bursts[(m.fx.bi + m.fx.bursts.size() - 1) % m.fx.bursts.size()]
	var g: float = m.world.ground_at(at.x, at.z)
	ok(is_equal_approx(float(p.get_instance_shader_parameter("ground_y")), g), "a burst gives its ground (%.2f)" % g)


# ------------------------------------------------------------------ status looks
## The statuses the source makes readable on a body: each has a look in content/rules/status_looks.json.


## Puts `st` on `F` the way the game does (its timers, KitStatus, a kit's keep) or takes it off.
func _set_status(m: Match, f: Hunter, st: String, on: bool) -> void:
	var t := 1.5 if on else 0.0
	match st:
		"stun":
			f.stun_t = t
		"root":
			f.root_t = t
		"slow":
			f.slow_t = t
		"burn":
			f.burn_t = t
		"antiheal":
			f.blight_t = t
		"sick":
			f.sick_t = t
		"gnd":
			f.set_meta("gnd_until", m.time + t)
		"daze":
			f.set_meta("rat_until", m.time + t)
		"chill", "static":
			if on:
				StatusLooks.of(m).keep(f, st)
			else:
				m.time += StatusLooks.KEEP + 0.01


func _statuses(m: Match, p: Hunter) -> void:
	var l := StatusLooks.of(m)
	var rules := StatusLooks.rules()
	var f: Hunter = null
	for h: Hunter in m.hunters:
		if h != p:
			f = h
	f.teleport(p.pos + Vector3(3.0, 0, 0))
	Sfx.listener = p.pos
	ok(STATUSES.all(func(st): return rules.has(st)), "status looks: every plain status has data")
	var looks := {}
	for st: String in STATUSES:
		_set_status(m, f, st, true)
		var up := l.showing(f, st)
		var rig: Node3D = (l.rigs.get("%d/%s" % [f.get_instance_id(), st], {}) as Dictionary).get("n")
		var parts := rig.find_children("*", "MeshInstance3D", true, false).size() if rig else 0
		ok(up and not l.showing(p, st), "status %s: its look comes up on that body only" % st)
		ok(parts > 0 and parts <= RIG_PARTS, "status %s: %d meshes (at most %d)" % [st, parts, RIG_PARTS])
		if st == "gnd":
			ok(rig.find_child("Arrow", true, false) != null, "status gnd: a down arrow over the head")
		looks[String(rules[st]["look"])] = true
		_set_status(m, f, st, false)
		ok(not l.showing(f, st), "status %s: the look goes when it ends" % st)
	ok(looks.size() == STATUSES.size(), "status looks: each status has a look of its own (%d)" % looks.size())
	var made := l.made
	for st: String in STATUSES:
		_set_status(m, f, st, true)
	ok(
		STATUSES.all(func(st): return l.showing(f, st)) and l.made == made,
		"status looks: all at once on one body, from the pool (built %d)" % l.made
	)
	for st: String in STATUSES:
		_set_status(m, f, st, false)
	l.from_hit(f, {"stun": 0.5, "burn": 4.0, "burn_for": 2.0, "blight": 1.0})
	ok(
		l.showing(f, "stun") and l.showing(f, "burn") and l.showing(f, "antiheal"),
		"status looks: a hit sent to another game's body shows what it carries here"
	)
	m.time += 2.1
	ok(not l.showing(f, "stun") and not l.showing(f, "burn"), "status looks: ... until that status would end")
	f.stun_t = 1.0
	f.teleport(p.pos + Vector3(StatusLooks.LOD_FAR + 4.0, 0, 0))
	ok(not l.showing(f, "stun"), "status looks: nothing draws past LOD_FAR")
	f.stun_t = 0.0


## The crowd control a summoned Boki takes (docs/specs/SUMMON_CC.md) on its body: the Hunter's look, colours and
## pace, sized to the Boki (over its head, round its body), from the pool; Grounded never lands so shows nothing.


func _boki_statuses(m: Match, p: Hunter) -> void:
	var l := StatusLooks.of(m)
	var f: Hunter = null
	for h: Hunter in m.hunters:
		if h != p:
			f = h
	var k := m.give_kin(f, Save.new_kin("zapple", "Pip"))
	k.state = "active"
	k.set_meta("summoned", true)
	k.teleport(p.pos + Vector3(-3.0, 0, 0))
	f.teleport(p.pos + Vector3(3.0, 0, 0))
	k.render(1.0 / 60.0, 1.0)
	var kk := StatusLooks.body_k(k)
	ok(
		kk.y < kk.x and kk.x < 1.0,
		"boki status: a look's size comes from the Boki's body (%.2f across, %.2f up)" % [kk.x, kk.y]
	)
	for st: String in BOKI_CC:
		_put_cc(m, k, st, true)
		_put_cc(m, f, st, true)
		l.tick(0.0)
		var kr: Dictionary = l.rigs.get("%d/%s" % [k.get_instance_id(), st], {})
		var fr: Dictionary = l.rigs.get("%d/%s" % [f.get_instance_id(), st], {})
		ok(l.showing(k, st) and l.showing(f, st), "boki status %s: the look comes up on the summoned Boki" % st)
		if kr.is_empty() or fr.is_empty():
			continue
		ok(_mats(kr["n"]) == _mats(fr["n"]), "boki status %s: in the Hunter's colours" % st)
		for i in 3:
			l.tick(0.25)
		ok(is_equal_approx(float(kr["t"]), float(fr["t"])), "boki status %s: at the Hunter's pace" % st)
		var y := float(StatusLooks.rules()[st].get("y", 0.0))
		var body: Node3D = (kr["n"] as Node3D).get_child(0)
		if y > 0.0:
			var up := body.global_position.y - k.pos.y
			var head := k.model.scale.y * StatusLooks.KIN_TALL  # (a Boki's size varies: measured from its head)
			var hunter_up: float = (fr["n"] as Node3D).get_child(0).global_position.y - f.pos.y
			ok(
				up > head and up < head + 0.6,
				(
					"boki status %s: over the Boki's head (%.2f m up, its head %.2f, a Hunter's %.2f)"
					% [st, up, head, hunter_up]
				)
			)
		else:
			var n: Node3D = kr["n"]
			ok(
				n.scale.y < n.scale.x and n.scale.x < (fr["n"] as Node3D).scale.x,
				"boki status %s: round its squat body (%.2f across, %.2f up)" % [st, n.scale.x, n.scale.y]
			)
		_put_cc(m, k, st, false)
		_put_cc(m, f, st, false)
		ok(not l.showing(k, st), "boki status %s: the look goes when it ends" % st)
	k.stun_t = 1.0
	k.render(1.0 / 60.0, 1.0)
	ok(
		k.model.get_meta("dazed") and not k.model.get_meta("starry"),
		"boki status: a stunned Boki squints but its own stars stay off (one ring of stars, the shared one)"
	)
	k.stun_t = 0.0
	KitStatus.apply(k, "gnd", 3.0)
	ok(not l.showing(k, "gnd"), "boki status: Grounded does not land on a summoned Boki, so no cords")
	k.remote = true
	l.from_hit(k, {"stun": 0.5, "root": 0.5})
	KitStatus.apply(k, "rat", 1.0, 0.0, false)
	ok(
		l.showing(k, "stun") and l.showing(k, "root") and l.showing(k, "daze"),
		"boki status: another game's summoned Boki shows the CC it is sent"
	)
	m.time += 1.1
	ok(not l.showing(k, "stun") and not l.showing(k, "daze"), "boki status: ... until it would end")
	k.remote = false
	m.kins.erase(k)
	m.ents_by_id.erase(k.nid)
	f.kin = null
	k.queue_free()


## Puts a crowd control kind on `e` the way the game does, or takes it off.
func _put_cc(m: Match, e: Ent, st: String, on: bool) -> void:
	var t := 1.5 if on else 0.0
	match st:
		"stun":
			e.stun_t = t
		"root":
			e.root_t = t
		"slow":
			e.slow_t = t
		"daze":
			if on:
				KitStatus.apply(e, "rat", t)
			else:
				m.time += 1.51  # (a Boki's Daze is shown for its length: StatusLooks.put)


## The materials a rig draws with (by colour), to compare two rigs of one status.
func _mats(n: Node3D) -> Array:
	var out := {}
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var mat := mi.material_override
		if mat is StandardMaterial3D:
			out[(mat as StandardMaterial3D).albedo_color.to_html()] = true
		elif mat is ShaderMaterial:
			out[Color((mat as ShaderMaterial).get_shader_parameter("albedo")).to_html()] = true
	var keys := out.keys()
	keys.sort()
	return keys


## The drop rocket (DropRocket): a thin trail in the squad colour from the nozzle that runs out after the landing, from
## the shared ribbon pool, as long at any frame rate, none at the very-low preset; a puff where a Hunter jumps out and
## dust settling where it lands, on Fx's dust pool, no ring or burst, also when another game's flags say so.
func _rocket(main: Node) -> void:
	var was: Variant = Settings.v.get("quality", "auto")
	Settings.v["quality"] = "high"
	var m := _rocket_match(main)
	var v_v := HeroVfx.of(m)
	var p: Hunter = m.player
	m.ship_jump(p)
	var r: DropRocket = p.rocket
	var e: Dictionary = v_v.ribbons[-1] if not v_v.ribbons.is_empty() else {}
	var nozzle: Node3D = e.get("follow")
	ok(r != null and nozzle != null and nozzle.get_parent() == r.node, "the launch starts a trail from the nozzle")
	if nozzle == null:
		return
	var col: Color = Data.TEAM_COLORS[p.team % Data.TEAM_COLORS.size()]
	ok(
		(e["mat"] as ShaderMaterial).get_shader_parameter("col") == col and float(e["width"]) <= DropRocket.TRAIL_W,
		"the trail is in the squad colour and thin (%.2f m)" % float(e["width"])
	)
	_ride(m, v_v, ROCKET_RIDE)
	var pts: Array = e["pts"]
	var up: Vector3 = HeroVfx._at(pts[-1]) - HeroVfx._at(pts[0])
	ok(HeroVfx._at(pts[0]).distance_to(nozzle.global_position) < 0.01, "its head rides the nozzle")
	ok(up.y > 0.0 and up.length() >= ROCKET_TRAIL_M, "it streams up behind the dive (%.1f m)" % up.length())
	_rocket_out(m, r)
	var high_dots := _rocket_land(m, v_v, r)
	await main.get_tree().process_frame
	_ride(m, v_v, DropRocket.TRAIL_S + 0.1)
	ok(not (e["node"] as Node3D).visible, "the trail runs out after the landing, back to the pool")
	_streaks(v_v)
	m.queue_free()
	Settings.v["quality"] = DropRocket.TRAIL_OFF
	m = _rocket_match(main)
	v_v = HeroVfx.of(m)
	m.ship_jump(m.player)
	r = m.player.rocket
	ok(r != null and v_v.ribbons.is_empty(), "no trail at the very-low preset")
	for h: Hunter in r.riders:
		h.remote = true  # another game flew it down: its riders' flags say they landed with it
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
		ok(
			(dust[0] as CPUParticles3D).amount < high_dots,
			"fewer dots at very low (%d, %d at high)" % [(dust[0] as CPUParticles3D).amount, high_dots]
		)
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
func _ride(m: Match, v: HeroVfx, secs: float) -> void:
	for i in maxi(1, int(round(secs / Match.DT))):
		m.step(Match.DT)
		v._process(Match.DT)


## Jumping out, here and as another game's flags: a small puff where they let go, no ring and no burst.
func _rocket_out(m: Match, r: DropRocket) -> void:
	var mates: Array = r.riders.filter(func(x: Hunter): return x != m.player)
	var radial0 := m.fx.radial
	var puff: CPUParticles3D = m.fx.bursts[m.fx.bi]
	var at := r.exit_at()
	m.skydrop.detach(mates[0])
	var beside := Vector2(at.x - r.pos.x, at.z - r.pos.z).length()
	ok(
		puff.color == Fx.AIR and puff.global_position.distance_to(at) < 0.01 and beside > DropRocket.BODY_R,
		"jumping out leaves a small puff where they let go, beside the body (%d dots)" % puff.amount
	)
	var far: Hunter = mates[1]
	far.remote = true
	far.riding = false
	far.dropping = true
	puff = m.fx.bursts[m.fx.bi]
	at = r.exit_at()
	r.tick(Match.DT)
	far.remote = false
	ok(
		not r.riders.has(far) and puff.color == Fx.AIR and puff.global_position.distance_to(at) < 0.01,
		"another game's flags say one jumped out: the same puff here"
	)
	ok(m.fx.radial == radial0, "no ring and no burst on jumping out")


## The rocket comes down: dust settles round it, low and slow, and no ring or burst from it or the riders'
## touchdowns. Returns the dust's dots.
func _rocket_land(m: Match, v: HeroVfx, r: DropRocket) -> int:
	var t := 0.0
	while t < ROCKET_CAP_S and r.pos.y - m.world.ground_at(r.pos.x, r.pos.z) > ROCKET_ALONE_M:
		_ride(m, v, Match.DT)
		t += Match.DT
	var radial0 := m.fx.radial
	while t < ROCKET_CAP_S and not r.done:
		r.tick(Match.DT)  # (the rocket alone: no one else's touchdown lands in the count)
		t += Match.DT
	ok(r.done and m.fx.radial == radial0, "the landing adds no ring or burst, nor do the riders' touchdowns")
	var dust := _settles(m.fx).filter(func(p: CPUParticles3D): return m.player.flat_dist(p.global_position) < 8.0)
	ok(dust.size() == 1, "dust settles where it lands, round the squad that stepped out")
	if dust.size() != 1:
		return 0
	var p: CPUParticles3D = dust[0]
	var ground := m.world.ground_at(p.global_position.x, p.global_position.z)
	ok(
		p.initial_velocity_max <= SETTLE_TOP_V and p.gravity.y > -2.0 and p.global_position.y - ground < 0.5,
		"low and slow, sinking back: not a blast (%.1f m/s, %d dots)" % [p.initial_velocity_max, p.amount]
	)
	return p.amount


## Fx's dust emitters running a landing's settle.
func _settles(fx: Fx) -> Array:
	return fx.bursts.filter(func(p: CPUParticles3D): return p.color == Fx.HEAVY_DUST and p.emitting)


## A streak keeps a point a step, not a frame, so it is as long at 30 fps as at 144; a later one reuses a pooled
## ribbon; a pile of them stays within the pool.
func _streaks(v: HeroVfx) -> void:
	var made := v.made
	var slow := _streak_span(v, 30.0)
	ok(v.made == made, "a later trail reuses the pooled ribbon (no new node)")
	var fast := _streak_span(v, 144.0)
	ok(absf(fast - slow) < slow * 0.15, "as long at 144 fps as at 30 (%.1f m, %.1f m)" % [fast, slow])
	var dots: Array = []
	for i in STREAK_PILE:
		var dot := Node3D.new()
		v.add_child(dot)
		dots.append(dot)
		v.streak(dot, Color.WHITE, DropRocket.TRAIL_W, DropRocket.TRAIL_S)
	ok(
		(v.pools["ribbon"] as Array).size() <= int(HeroVfx.POOL["ribbon"]),
		"%d trails at once stay in the pool (%d)" % [STREAK_PILE, (v.pools["ribbon"] as Array).size()]
	)
	for dot: Node3D in dots:
		dot.queue_free()
	_clear(v)


## How long a streak behind a node diving at the rocket's speed is after a second at `fps`.
func _streak_span(v: HeroVfx, fps: float) -> float:
	var dot := Node3D.new()
	v.add_child(dot)
	v.streak(dot, Color.WHITE, DropRocket.TRAIL_W, DropRocket.TRAIL_S)
	var e: Dictionary = v.ribbons[-1]
	for i in int(fps):
		dot.global_position += Vector3.DOWN * DropRocket.FALL / fps
		v._process(1.0 / fps)
	var pts: Array = e["pts"]
	var span := HeroVfx._at(pts[-1]).distance_to(HeroVfx._at(pts[0]))
	dot.queue_free()
	_clear(v)
	return span


## DECISIONS "a ground ring means gameplay": the moves that are a dash, a landing, a reset or a cast with no area
## carry no ring layer, and no scorch under a wind-up (docs/VFX_QUALITY.md, "Ground ring audit").


func _decor_rings() -> void:
	for table: Dictionary in [NO_RING, NO_SCORCH]:
		var kind := "ring" if table == NO_RING else "scorch"
		for arch: String in table:
			var file := FileAccess.get_file_as_string("res://content/vfx/%s.json" % arch)
			var moves: Dictionary = JSON.parse_string(file)["moves"]
			for move: String in table[arch]:
				var layers: Array = (moves[move] as Dictionary).get("fx", []) if moves.has(move) else []
				var n := layers.filter(func(l: Dictionary): return l["p"] == kind).size()
				ok(n == 0, "%s/%s draws no %s layer (a decoration, not an area)" % [arch, move, kind])


## Sable's Encore ring: at 0.2s of its 0.4s grow it is about half the full radius (growth, not a pop), and it and the
## blade layer stay centred on her through a Vault, to within a hand's width.
func _sable_ring(main: Node) -> void:
	var m: Match = flow._match(main, "thief")
	await main.get_tree().process_frame
	var p: Hunter = m.player
	var u: ThiefUlt = (p.ak as ThiefKit).encore
	p.lvl = maxi(p.lvl, int(Hunter.ULT_AT[0]))
	p.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(p)
	var reach := float(u.data()["reach"])
	while float(u.st["t"]) < 0.2 - 0.5 * Match.DT:
		m.step(Match.DT)
	var half := float(AimKit.entry(p, "ult")["r"]) / reach
	ok(absf(half - 0.5) < 0.05, "Sable's Encore ring is about half its full radius at 0.2s (%.2f)" % half)
	var drawn := AimKit.entry(p, "ult").duplicate()
	drawn["alpha"] = 2.0  # the brightest beat
	var got: Array = load("res://tools/aimkit_check.gd").measure(drawn, 0.0, float(drawn["r"]) - 0.05)
	ok(
		(drawn["col"] as Color).is_equal_approx(AimKit.hero_col(p)) and got[0] <= ZONE_CORE_A and got[1] >= 0.5,
		(
			"Sable's X: a lit %s rim over a faint inside (centre alpha %.2f <= %.2f at the brightest beat, rim %.2f)"
			% [AimKit.hero_col(p).to_html(false), got[0], ZONE_CORE_A, got[1]]
		)
	)
	m.step(0.3)
	p.inp["move"] = Vector2(0, -1)
	p.inp["dash"] = true
	var worst := 0.0
	var from := p.pos
	for i in 40:
		m.step(Match.DT)
		var ring: Vector2 = AimKit.entry(p, "ult")["at"]
		var orbit := Vector3.ZERO
		for j in ThiefUlt.ORBITERS:
			orbit += ((u.k.fx().placed["enc_orb%d" % j] as Dictionary)["node"] as Node3D).global_position
		orbit /= float(ThiefUlt.ORBITERS)
		worst = maxf(
			worst,
			maxf(
				ring.distance_to(Vector2(p.pos.x, p.pos.z)),
				Vector2(orbit.x, orbit.z).distance_to(Vector2(p.pos.x, p.pos.z))
			)
		)
	ok(
		p.pos.distance_to(from) > 3.0 and worst < 0.1,
		"Sable's ring and blades stay on her through a Vault (off by %.2f m)" % worst
	)
