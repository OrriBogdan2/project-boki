extends RefCounted
## --lair-fall-check: a dash in or out of a boss lair never ends in "you fell". On both hand-made maps
## (Hollowcrown, and Skyreach for rolling sessions), in every lair:
##   1. the floor inside the walls has no hole to the abyss
##   2. a jump and a dash from spots across the floor (by the walls, the corners and the middle), in eight
##      directions, never falls (Kael's Rampage and the plain dash)
##   3. riding the escape updraft out after the kill and dashing on along its throw (or 45 degrees either
##      side) comes down on the island: the ride's landing has room past it (Lairs.UP_LAND_ROOM)
##   4. the guard: a hunter over solid ground, however deep under it, is never lost to the abyss
## A fall shows as god mode putting the player back on the marker. Prints "LAIRFALL ok|FAIL ..." lines
## and "LAIRFALL DONE, failures: N". Never touches the save.

const MAPS := ["hollowcrown", "skyreach"]
const HEROES := ["juggernaut", ""]      # Kael's air dash, and the plain dash ("": no archetype)
const SPOTS := [Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]      # x half-widths from the middle
const WALL_GAP := 1.2         # m between a spot by the wall and the wall's inner face
const JUMP_TO_DASH := 0.2     # s from the jump to the dash (near the top of the hop)
const TRY_T := 1.4            # s each jump and dash runs

var bad := 0
var m: Match
var h: Hunter
var marker := Vector3.ZERO      # where god mode puts a fallen player back

func ok(cond: bool, what: String) -> void:
	print("LAIRFALL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	main.set_meta("lair_fall_check", self)
	Save.no_write = true
	Save.d = Save.fresh()
	for map in MAPS:
		_start(main, map)
		for L in m.lairs.list:
			_floor_whole(L)
			for hero in HEROES:
				_become(hero)
				_jump_dashes(L, hero)
		_ride_out(map, m.lairs.list)
		_guard(m.lairs.list[0])
		m.queue_free()
	print("LAIRFALL DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _start(main: Node, map: String) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 5, "no_drop": true, "map": map})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	h = m.player
	for other in m.hunters:
		other.ctrl = "idle"
	h.ctrl = "local"
	m.opts["god"] = true
	marker = m.world.random_ground()
	h.ai["land"] = marker
	ok(m.lairs.list.size() == 3, "%s: three lairs" % map)

func _become(hero: String) -> void:
	if hero != "":
		h.reclass(Arch.weight(hero), hero, Arch.signature(hero))
	h.set_arch(hero)
	h.unlock_all()

func _floor_whole(L: Dictionary) -> void:
	var c: Vector3 = L["c"]
	var inner := int(L["half"]) - 1
	var holes := 0
	for dz in range(-inner, inner + 1):
		for dx in range(-inner, inner + 1):
			if m.world.is_void(c.x + dx, c.z + dz):
				holes += 1
	ok(holes == 0, "%s: no hole in the floor (%d)" % [L["name"], holes])

func _reset(at: Vector3) -> void:
	h.out = false
	h.downed = false
	h.hp = h.max_hp
	h.teleport(at)
	h.vel = Vector3.ZERO
	h.grounded = true
	h.gliding = false
	h.auto_glide = false
	h.glide_cd = 0.0
	h.stun_t = 0.0
	h.dashes = 9.0
	h.ex_cd = 0.0
	h.air_dashed = false

## Steps the match with `press` choosing the keys each frame; true if the player fell.
func _run(sec: float, d: Vector2, press: Callable) -> bool:
	var t := 0.0
	while t < sec:
		var keys: Dictionary = press.call(t)
		h.inp["move"] = d if keys.get("move", false) else Vector2.ZERO
		h.inp["aim"] = h.pos + Vector3(d.x, 0, d.y) * 6.0
		h.inp["jump"] = keys.get("jump", false)
		h.inp["dash"] = keys.get("dash", false)
		var before := h.pos
		m.step(Match.DT)
		t += Match.DT
		if h.pos.distance_to(marker) < 0.01 and before.distance_to(marker) > 0.5:
			return true
	h.inp["move"] = Vector2.ZERO
	return false

func _jump_dashes(L: Dictionary, hero: String) -> void:
	var c: Vector3 = L["c"]
	var reach := float(L["half"]) - 0.5 - WALL_GAP
	var press := func(t: float) -> Dictionary:
		return {"move": true, "jump": t < Match.DT, "dash": absf(t - JUMP_TO_DASH) < Match.DT * 0.5}
	var tries := 0
	var fell: Array = []
	for s in SPOTS:
		var at := Vector3(c.x + s.x * reach, c.y, c.z + s.y * reach)
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0)
			_reset(at)
			tries += 1
			if _run(TRY_T, d, press):
				fell.append("%s %s" % [s, d])
	var who := hero if hero != "" else "plain"
	ok(fell.is_empty(), "%s, %s: %d jump dashes, none fell %s" % [L["name"], who, tries, fell.slice(0, 3)])

## After the kill: ride the updraft and dash on along its throw at the top of the climb and as it carries you.
func _ride_out(map: String, lairs: Array) -> void:
	_become("juggernaut")
	for L in lairs:
		m.lairs.activate(L)
		for g in L.get("guards", []):
			if is_instance_valid(g): g.dead = true
		var c: Vector3 = L["c"]
		_reset(c)
		if L["state"] == "sealed":
			m.lairs.open(L, h, "dial")
		m.lairs.wake(L, h)
		_run(0.2, Vector2.ZERO, func(_t): return {})
		var b: Boss = L["boss_mob"]
		if b.buried:
			b._clear_attack()
		b.hurt(b.hp + b.max_hp, h, {"src": "test"})
		_run(0.2, Vector2.ZERO, func(_t): return {})
		for a in L.get("adds", []):
			if is_instance_valid(a): a.dead = true
		var u: Vector3 = L["up"]
		var land: Vector3 = L["up_land"]
		var throw := Vector2(land.x - u.x, land.z - u.z).normalized()
		var tries := 0
		var fell: Array = []
		for turn in [-PI / 4.0, 0.0, PI / 4.0]:
			var d := throw.rotated(turn)
			for td in [0.9, 1.2, 1.5, 1.8]:
				L["victory_at"] = m.time
				L["flown"] = []
				L["escaped"] = []
				_reset(Vector3(u.x, c.y, u.z))
				tries += 1
				var press := func(t: float) -> Dictionary:
					var jump := absf(t - td + 0.1) < Match.DT * 0.5
					return {"move": t >= td and t < td + 0.35, "jump": jump, "dash": absf(t - td) < Match.DT * 0.5}
				if _run(5.0, d, press):
					fell.append("%.1f s %s" % [td, d])
		var what := "%s, %s: %d dashes out of the escape updraft" % [map, L["name"], tries]
		ok(fell.is_empty(), "%s, none fell %s" % [what, fell.slice(0, 3)])

## The guard: deep under a lair's floor (as if something had sunk you through it) is never "you fell".
func _guard(L: Dictionary) -> void:
	var c: Vector3 = L["c"]
	_reset(c)
	h.pos = Vector3(c.x, -45.0, c.z)
	h.grounded = false
	ok(not h._in_abyss(), "%s: 48 m under the floor is not the abyss" % L["name"])
	_reset(c)
