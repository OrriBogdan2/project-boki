extends "res://tools/archetype_check.gd"
## Lace's Spirit Walk look, run from --archer-combo-check (tools/archer_bulwark_combo_check.gd adds the counts): her
## own screen takes the wash for the whole walk (darker inside something), a portal opens where she goes into a rock
## and where she comes out (and where an end inside puts her), none on the roll, and the look changes no gameplay:
## the walk lasts its 2.8 s after the roll and still passes the rock. Prints AKCHECK lines.

const SOURCE_WALK := 2.8      # s of Spirit Walk after the roll (hero sheet pin.md, the card)
const ROCK_AHEAD := 5         # tiles from her start to the rock column: the roll ends clear of it
const PAST_ROCK := 1.6        # m past the rock's near face where she stops walking

func walk() -> void:
	var r := setup("archer", 9.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	(r[2] as Hunter).teleport(home + Vector3(0, 0, 6))      # (the dummy off her line)
	Sfx.listener = home           # (the camera's focus, which no frame moves here: the looks' detail share)
	var bx := int(home.x) + ROCK_AHEAD
	var wk: PackedByteArray = m.world.kind
	for dz in range(-2, 3):
		wk[m.world.idx(bx, int(home.z) + dz)] = World.T_BLOCK
	m.world.kind = wk
	_through(m, P, home, bx)
	_ends_inside(m, P, home, bx, r[5])
	var V := HeroVfx.of(m)
	var rec: Dictionary = HeroVfx.data("archer")["moves"]["spirit_portal"]
	var far := home + Vector3(0, 0, -4)
	V.net_in(["fx", "hvfx", P.nid, "spirit_portal", far.x, far.y, far.z, 1.0, 0.0, 0.0, 0.0, 0.0])
	var there := _portals(V).filter(func(n: Node3D): return absf(n.global_position.z - far.z) < 0.1)
	ok(
		"pin look: the portal goes to every game (hvfx, net on) and opens there",
		bool(rec.get("net", true)) and there.size() == 1,
		"net %s, portals there %d" % [rec.get("net", true), there.size()]
	)
	await done(m)

## Rolls east, walks through the rock column, stops past it and waits the walk out.
func _through(m: Match, P: Hunter, home: Vector3, bx: int) -> void:
	var K: ArcherKit = P.ak
	var V := HeroVfx.of(m)
	var opened := int(V.plays.get("spirit_portal", 0))
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	aim_at(P, home + Vector3(8, 0, 0))
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	var t0 := float(m.time)
	var roll_t := float(K.dash_def()["roll_t"])
	var roll_portals := -1
	var clear_tint := -1.0
	var inside_tint := 0.0
	var spots: Array = []
	var ghost := true
	while K.spirit.active() and float(m.time) - t0 < 5.0:
		var was_in := K.spirit.inside
		P.inp["move"] = Vector2.ZERO if P.pos.x > bx + PAST_ROCK else Vector2(1, 0)
		step(m, DT)
		ghost = ghost and (P.spirit_t > 0.0 or not K.spirit.active())
		if clear_tint < 0.0:
			clear_tint = K.fx.tint_want
		if roll_portals < 0 and float(m.time) - t0 >= roll_t:
			roll_portals = int(V.plays.get("spirit_portal", 0)) - opened
		if K.spirit.inside:
			inside_tint = K.fx.tint_want
		if was_in and not K.spirit.inside:
			spots = _portals(V).map(func(n: Node3D): return snappedf(n.global_position.x - bx, 0.01))
	var lasted := float(m.time) - t0
	var through := int(V.plays.get("spirit_portal", 0)) - opened
	ok(
		"pin look: a portal where she goes into the rock and one where she comes out",
		through == 2 and spots.size() == 2 and spots.min() < -0.2 and spots.max() > 1.2,
		"portals %d, x from the rock %s" % [through, spots]
	)
	ok(
		"pin look: nothing bursts on the roll (no portal; spirit_go has no flare, ring, disc or portal)",
		roll_portals == 0 and _burst_free(HeroVfx.data("archer")["moves"]["spirit_go"]),
		"portals on the roll %d" % roll_portals
	)
	ok(
		"pin look: her screen washes for the whole walk, darker inside the rock, clear after it",
		absf(clear_tint - PinFx.TINT_WALK) < 0.01 and inside_tint == 1.0 and K.fx.tint_want == 0.0
			and K.fx.tint != null,
		"walking %.2f inside %.2f after %.2f" % [clear_tint, inside_tint, K.fx.tint_want]
	)
	ok(
		"pin look: gameplay as before: 2.8 s after the roll, through the rock, a spirit the whole walk",
		absf(K.spirit.walk_time() - SOURCE_WALK) < 0.001 and absf(lasted - roll_t - SOURCE_WALK) < 2.5 * DT
			and P.pos.x > bx + 1.0 and K.spirit.passed > 0 and ghost,
		"walk %.2f lasted %.2f (roll %.2f) x %.1f (rock %d)" % [K.spirit.walk_time(), lasted, roll_t, P.pos.x, bx]
	)

## The walk running out inside the rock (put back at the entry) and inside a ledge (set on top): a portal where
## she comes out each time.
func _ends_inside(m: Match, P: Hunter, home: Vector3, bx: int, lv: int) -> void:
	var K: ArcherKit = P.ak
	var V := HeroVfx.of(m)
	_dash_into(m, P, home, Vector3(bx + 0.5, home.y, home.z))
	var opened := int(V.plays.get("spirit_portal", 0))
	var snaps := K.spirit.snap_backs
	K.spirit.end("time")
	var at_entry := _portals(V).filter(func(n: Node3D): return n.global_position.x < bx - 0.2)
	var added := int(V.plays.get("spirit_portal", 0)) - opened
	ok(
		"pin look: ending inside the rock puts her back at the entry, a portal there",
		K.spirit.snap_backs == snaps + 1 and added == 1 and at_entry.size() >= 1 and P.pos.x < bx,
		"snaps %d portals +%d x %.1f (rock %d)" % [K.spirit.snap_backs - snaps, added, P.pos.x, bx]
	)
	var W: World = m.world
	var wk: PackedByteArray = W.kind
	var wl: PackedByteArray = W.level
	for dz in range(-2, 3):
		wk[W.idx(bx, int(home.z) + dz)] = World.T_GROUND
		wl[W.idx(bx, int(home.z) + dz)] = lv + 2
	W.kind = wk
	W.level = wl
	_dash_into(m, P, home, Vector3(bx + 0.5, home.y, home.z))
	opened = int(V.plays.get("spirit_portal", 0))
	K.spirit.end("time")
	added = int(V.plays.get("spirit_portal", 0)) - opened
	ok(
		"pin look: ending inside a ledge sets her on top, a portal there",
		added == 1 and P.pos.y > home.y + 0.8 and K.spirit.snap_backs == snaps + 1,
		"portals +%d y %+.2f" % [added, P.pos.y - home.y]
	)
	for dz in range(-2, 3):
		wl[W.idx(bx, int(home.z) + dz)] = lv
	W.level = wl

## Starts a walk from `home` (the roll ends in the open), then puts her `inside` something for one step (the walk
## sees it).
func _dash_into(m: Match, P: Hunter, home: Vector3, inside: Vector3) -> void:
	step(m, 0.5)
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2.ZERO
	P.do_dash()
	step(m, 0.3)
	P.teleport(inside)
	step(m, DT)

## The portal looks showing now.
func _portals(V: HeroVfx) -> Array:
	return (V.pools.get("portal", []) as Array).filter(func(n: Node3D): return n.visible)

## True when a move's recipe has no burst kind (a flare, ring, ground disc, wall of flame or portal).
func _burst_free(rec: Dictionary) -> bool:
	for layer: Dictionary in rec.get("fx", []):
		if String(layer["p"]) in ["flare", "ring", "vortex", "skirt", "portal"]:
			return false
	return true
