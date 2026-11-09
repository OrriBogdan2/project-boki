extends RefCounted
## --move-fx-check: movement never spawns a ring, disc or burst. "Explosions only for things that truly explode;
## no bursts, rings or discs on dashes, landings or resets; a ground ring means gameplay." Every Hunter runs a
## ground dash, an air dash, a standing dash, a soft and a hard landing, a spiked landing, a wall kick, a wall bounce,
## a mantle and a takedown reset in the shared training match; the audit lists what each spawned (Fx rings and
## bursts, big flashes, the Hero looks of content/vfx) and fails on any ring/disc/burst type.
## Dust, ghosts, trails, ribbons and little sparks are the movement language and are allowed. A move that marks a
## real area (AREA) may draw its ring. `--move-fx-check` prints one MOVEFX line per Hunter and event.

const SOFT_FALL := 3.0         # m dropped for a soft landing
const HARD_FALL := 12.0         # m dropped for a hard landing
const FLASH_BIG := 1.3         # a flash this wide (Fx.flash size * 1.6) is a burst
const FOE_SPOT := Vector3(20, 0, 20)   # m from home: inside the flat patch, out of every move's reach
const ON_FOE := 1.5            # m: an effect this close to the foe a reset hits is the hit's feedback, not the reset's
const STEPS := 70              # sim steps (1/60 s) watched after each trigger
## Hero looks (content/vfx layer kinds) that are a ring, disc or burst; a "scorch" of shape disc/cone counts too.
const BURST_KINDS := ["flare", "vortex", "skirt"]
## "<hero>/<event>" pairs whose dash is itself an area move: Ostra's Lantern Trade swaps its circle, Dolm's raises a
## rock wall, Bulwark's 360 Smash hits all round him.
const AREA := ["ostra/dash", "ostra/air dash", "ostra/standing dash", "dolm/dash", "dolm/standing dash",
	"bulwark/dash", "bulwark/standing dash"]
## Moves played again and again along a path: a trail laid behind the mover (Rimewright's frost under the skate).
const TRAILS := ["skate_frost"]
const EVENTS := ["dash", "standing dash", "air dash", "soft landing", "hard landing", "spiked landing", "wall kick",
	"wall bounce", "mantle", "reset"]

var bad := 0
var rows := 0
var flow := preload("res://tools/dash_flow_check.gd").new()
var walls := {}
var foe_at := Vector3(1e6, 0, 0)       # where the last reset's foe stood

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("MOVEFX FAIL %s" % what)
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for hero in _heroes():
		var m: Match = flow._match(main, hero)
		_setup(m)
		for ev in EVENTS:
			_event(m, hero, ev)
		m.queue_free()
		await main.get_tree().process_frame
	print("MOVEFX DONE, %d rows, failures: %d" % [rows, bad])
	main.get_tree().quit()

## Every Hunter, or the ones named in --move-fx-check=<id>,<id>.
func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--move-fx-check=") and arg.length() > 16:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

## No opening drop and no Boki companion (their own landings and leaps are not the Hunter's movement), and two
## raised blocks beside the flat patch's centre: one terrace (a mantle) and four (a kick and a bounce).
func _setup(m: Match) -> void:
	for k in [flow.hunter.kin, flow.hunter.kin2]:
		if k:
			m.kins.erase(k)
			k.queue_free()
	flow.hunter.kin = null
	flow.hunter.kin2 = null
	flow.hunter.dropping = false
	m.air_rings.clear()          # a far air dash must not fly through a boost ring
	var w: World = m.world
	var home: Vector3 = flow.get_meta("home")
	var cx := int(floor(home.x))
	var cz := int(floor(home.z))
	var lv := int(w.level[w.idx(cx, cz)])
	for spec in [["step", 8, 1], ["wall", -8, 4]]:
		var z0: int = cz + int(spec[1])
		if not w.inb(cx + 11, z0 + 2) or not w.inb(cx + 9, z0 - 2) or not w.inb(cx, z0):
			z0 = cz - int(spec[1])
		for dz in range(-2, 3):
			for dx in range(9, 12):
				w.level[w.idx(cx + dx, z0 + dz)] = lv + int(spec[2])
		walls[spec[0]] = {"at": Vector3(cx + 9.0 - flow.hunter.r - 0.02, lv * World.LEVEL, z0 + 0.5),
			"top": (lv + int(spec[2])) * World.LEVEL}

## What the world holds before an event, to tell what it added.
func _snap(m: Match) -> Dictionary:
	var vfx := HeroVfx.of(m)
	return {"radial": m.fx.radial, "rings": m.fx.rings.size(), "fi": m.fx.fi, "plays": vfx.plays.duplicate()}

func _event(m: Match, hero: String, ev: String) -> void:
	var h: Hunter = flow.hunter
	flow._ready_up(m)
	h.ak.res = 0.0
	h.ak.fx_t = 99.0          # the resource tell glow (ArchKit._tells) is not movement: keep it out of the audit
	for mb in m.mobs:
		mb.dead = true            # a mob in a ram's way is a hit (a real impact), not movement
	for o in m.hunters:
		if o != h:
			o.out = true          # out of the match: nobody fights, falls or shoots
			o.teleport(flow.get_meta("home") + FOE_SPOT)
	var before := _snap(m)
	var flashes0: int = m.fx.flashes.size()
	_trigger(m, h, ev)
	var spawned := _spawned(m, hero, before, flashes0)
	rows += 1
	print("MOVEFX %-10s %-14s %s" % [hero, ev, ", ".join(spawned) if not spawned.is_empty() else "-"])
	var area: bool = "%s/%s" % [hero, ev] in AREA
	ok(spawned.is_empty() or area, "%s: %s spawned %s" % [hero, ev, ", ".join(spawned)])

func _trigger(m: Match, h: Hunter, ev: String) -> void:
	h.inp["move"] = Vector2.ZERO
	match ev:
		"dash", "air dash", "standing dash":
			if ev == "air dash":
				flow._lift()
			if ev != "standing dash":
				h.inp["move"] = Vector2(0, -1)
			h.inp["dash"] = true
			m.step(Match.DT)
			h.inp["dash"] = false
		"soft landing", "hard landing", "spiked landing":
			h.pos.y += SOFT_FALL if ev == "soft landing" else HARD_FALL
			h.grounded = false
			h.shot_down = ev == "spiked landing"
		"wall kick", "wall bounce", "mantle":
			_at_wall(h, ev)
		"reset":
			h.dashes = 0.0
			DashReset.takedown(h, _foe(m, h))
			_kit_reset(m, h)
	for i in STEPS:
		m.step(Match.DT)
	h.inp["move"] = Vector2.ZERO

func _foe(m: Match, h: Hunter) -> Hunter:
	for o in m.hunters:
		if o.team != h.team:
			return o
	return null

## The three kits that give the dash back with a look of their own.
func _kit_reset(m: Match, h: Hunter) -> void:
	var foe := _foe(m, h)
	foe.teleport(h.pos + Vector3(3, 0, 0))
	foe_at = foe.pos
	if h.ak is MageKit:
		(h.ak as MageKit)._blowout(foe)
	elif h.ak is ThiefKit:
		(h.ak as ThiefKit)._reset_fx(foe)
	elif h.ak is GunslingerKit:
		(h.ak as GunslingerKit)._on_knock(foe)
	foe.teleport(flow.get_meta("home") + FOE_SPOT)

## Wall events: at the foot of the one-terrace step (mantle) or the four-terrace wall, as wallmove-check does.
func _at_wall(h: Hunter, ev: String) -> void:
	var wl: Dictionary = walls["step"] if ev == "mantle" else walls["wall"]
	var at: Vector3 = wl["at"]
	h.teleport(at)
	h.wall_n = Vector2(-1, 0)
	match ev:
		"mantle":
			h.inp["move"] = Vector2(1, 0)
			h.inp["jump"] = true
		"wall kick":
			h.pos.y += 1.0
			h.grounded = false
			h.wall_touch_t = 0.2
			h.inp["move"] = Vector2(1, 0)
			h.inp["jump"] = true
		"wall bounce":
			h.pos.y += 0.5
			h.grounded = false
			h.vel = Vector3(7.0, 0, -7.0)
			h.wall_touch_t = 0.2

## The ring/disc/burst types the event added, as short labels.
func _spawned(m: Match, hero: String, before: Dictionary, flashes0: int) -> Array:
	var out: Array = []
	var h: Hunter = flow.hunter
	var all_rings: Array = m.fx.rings.slice(int(before["rings"]))
	var rings := 0
	for r: Dictionary in all_rings:
		if (r["node"] as Node3D).global_position.distance_to(foe_at) > ON_FOE:
			rings += 1
	var bursts: int = m.fx.radial - int(before["radial"]) - all_rings.size()
	for b: CPUParticles3D in m.fx.bursts:
		if b.emitting and b.global_position.distance_to(foe_at) <= ON_FOE:
			bursts -= 1
	if rings > 0:
		out.append("Fx.ring x%d" % rings)
	if bursts > 0:
		out.append("Fx.burst x%d" % bursts)
	for f: Dictionary in m.fx.flashes.slice(flashes0):
		if float(f["s0"]) > FLASH_BIG and (f["node"] as Node3D).global_position.distance_to(foe_at) > ON_FOE:
			out.append("Fx.flash %.1f" % float(f["s0"]))
	var plays: Dictionary = HeroVfx.of(m).plays
	var moves: Dictionary = HeroVfx.data(hero).get("moves", {})
	for mv: String in plays:
		if int(plays[mv]) > int(before["plays"].get(mv, 0)):
			for layer: Dictionary in (moves.get(mv, {}) as Dictionary).get("fx", []):
				if layer.has("when") or mv in TRAILS:
					continue          # drawn only when the move hit something (hit feedback), or a trail
				var kind := String(layer["p"])
				if kind in BURST_KINDS or (kind == "scorch" and String(layer.get("shape", "disc")) != "lane"):
					out.append("%s:%s" % [mv, kind])
	return out
