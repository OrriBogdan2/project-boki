extends "res://tools/dash_flow_check.gd"
## --chain-sweep-check (advisory: prints, never gates a ship): DECISIONS "every interaction is chainable". For
## a light, medium and heavy Hunter, in every movement state, press dash, jump, glide, wall kick, mantle, LMB
## and E on the next step and assert the move starts, or that the documented rule (REFUSE below) says it does not.
## States: ground, air, glide, ground dash, air dash, rocket free fall, glide ring, lift ring, Ice Sheet (grip
## 0.12), Deep Water (speed 0.55). A wall is a carved 1.6 m block (two terraces) the wall actions use.
## It takes a player's keys (glide_press_only). A press that starts later than WATCH_NOW steps is a buffered
## one (DashFlow rows): it must start inside BUFFER_S and the line says how late. Prints "CHAIN ok|FAIL|n/a ...".
## Docs: docs/CHAIN_SWEEP.md.

const HEROES := {"light": "archer", "medium": "gunslinger", "heavy": "bulwark"}
const ACTIONS := ["dash", "jump", "glide", "wall_kick", "mantle", "lmb", "e"]
const WATCH_NOW := 2            # steps: "the next step" (read the step it is made, the move shows within 2)
const BUFFER_S := 1.0           # s: a buffered press starts within this of the press
const SKY := 60.0               # m above the ground a rocket free fall starts
const WALL_AT := 3              # tiles east of home the carved wall's face stands
const WALL_RISE := 2            # terraces (1.6 m) the carved wall is
const AT_WALL := 0.12           # m the wall pose stands off the face
const OPEN_TRIES := 60          # steps a glider that a cast keeps shut gets to open
const AIR_Y := 7.0              # m a plain air state starts above the ground
const WALL_Y := 1.0             # m a wall pose in the air starts above the ground: under the lip
const FIELDS := {"ice": "ice", "deep_water": "deep_water"}      # state -> terrain hazard kind
const PLAIN_KIN := "cindle"     # venom: counters none of the hazards

## Where a press is refused by a documented rule: "state/action" -> the rule. Everything else must start.
const REFUSE := {
	"ground/glide": "no glider off the ground (Hunter.can_glide); Space is the jump",
	"ice/glide": "no glider off the ground", "deep_water/glide": "no glider off the ground",
	"dash_ground/glide": "no glider off the ground",
	"glide/jump": "already gliding: the press has nothing to open", "glide/glide": "already gliding",
	"glide_ring/jump": "already gliding", "glide_ring/glide": "already gliding",
	"lift_ring/jump": "already gliding", "lift_ring/glide": "already gliding",
	"rocket_fall/wall_kick": "a dropping hunter never kicks (WallMoves.try_kick): Space pulls the glider",
	"rocket_fall/dash": "no dash, attack or ability while dropping (ArchKit.locked, the drop's own rules)",
	"rocket_fall/lmb": "no attack while dropping (ArchKit.locked)",
	"rocket_fall/e": "no ability while dropping (ArchKit.locked)",
	"glide/lmb": "no attack with the glider open (Hunter.can_fire)", "glide_ring/lmb": "no attack with the glider open",
	"lift_ring/lmb": "no attack with the glider open",
}
## Wall actions need a wall within reach: these states have none (a lane or the sky) or are on the ground.
const NO_WALL := {
	"ground/wall_kick": "a wall kick is an air move; on the ground Space is a jump",
	"ice/wall_kick": "air move", "deep_water/wall_kick": "air move", "dash_ground/wall_kick": "air move",
	"glide_ring/wall_kick": "no wall in an air lane", "glide_ring/mantle": "no wall in an air lane",
	"lift_ring/wall_kick": "no wall in an air lane", "lift_ring/mantle": "no wall in an air lane",
	"rocket_fall/mantle": "no wall in the sky",
}

var mm: Match
var face := Vector2.ZERO        # the carved wall's face (world x, z) in the fixture now under test
var low_y := 0.0                # ground height under the wall's foot
var results := {}               # "state/action/weight" -> "ok" | "FAIL" | "refused" | "n/a"
var note_n := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		bad += 1
		print("CHAIN FAIL %s" % what)

func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(_on_used)
	var only := _only()
	for weight in HEROES:
		var hero: String = HEROES[weight]
		if not only.is_empty() and hero not in only:
			continue
		mm = _match(main, hero)
		face = _carve(mm, hunter.pos)
		set_meta("home", hunter.pos)
		for st in ["ground", "air", "glide", "dash_ground", "dash_air", "rocket_fall"]:
			_state_row(weight, hero, st)
		mm.queue_free()
		await main.get_tree().process_frame
		mm = _crown(main, hero)
		for st in ["ice", "deep_water", "glide_ring", "lift_ring"]:
			_state_row(weight, hero, st)
		mm.queue_free()
		await main.get_tree().process_frame
	CombatBus.ability_used.disconnect(_on_used)
	var refused := 0
	for k in results:
		refused += 1 if results[k] == "refused" else 0
	print("CHAIN DONE, failures: %d, refused by a documented rule: %d, n/a: %d" % [bad, refused, skipped])
	main.get_tree().quit()

## --chain-sweep-check=<hero>,<hero> runs only those heroes.
func _only() -> PackedStringArray:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chain-sweep-check=") and arg.length() > 20:
			return arg.get_slice("=", 1).split(",")
	return PackedStringArray()

# ------------------------------------------------------------------ fixtures
## The Hollow Crown (seed 5, the hazard check's), the hunter's Boki a plain one, god on.
func _crown(main: Node, hero: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 5, "no_drop": true, "demo_kin": PLAIN_KIN,
		"cls": Arch.weight(hero), "arch": hero, "weapon": Arch.signature(hero), "god": true})
	m.set_process(false)
	_clear_mobs(m)
	hunter = m.player
	hunter.set_arch(hero)
	hunter.unlock_all()
	hunter.lvl = 10
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(60, 0, 60))
	return m

## A WALL_RISE terrace block WALL_AT tiles east of `home`, level ground round it: the wall the wall actions use.
func _carve(m: Match, home: Vector3) -> Vector2:
	var world: World = m.world
	var x0 := int(floor(home.x))
	var z0 := int(floor(home.z))
	var home_i: int = world.idx(x0, z0)
	var lv := int(world.level[home_i])
	for dz in range(-4, 5):
		for dx in range(WALL_AT, WALL_AT + 4):
			var i: int = world.idx(x0 + dx, z0 + dz)
			world.kind[i] = World.T_GROUND
			world.level[i] = lv + WALL_RISE
			world.island[i] = world.island[home_i]
			for d in [world.walls, world.props, world.stairs, world.bush]:
				d.erase(i)
	low_y = lv * World.LEVEL
	return Vector2(x0 + float(WALL_AT), z0 + 0.5)

## The middle tile of the first hazard area of `kind`.
func _field_home(kind: String) -> Vector3:
	var tz := TerrainHazards.of(mm)
	for area in tz.areas:
		if area["kind"] != kind:
			continue
		var c: Vector3 = area["centre"]
		var mid := Vector2(c.x - 0.5, c.z - 0.5)
		var best: Vector2i = area["cells"][0]
		for q in area["cells"]:
			if Vector2(q).distance_to(mid) < Vector2(best).distance_to(mid):
				best = q
		return Vector3(best.x + 0.5, float(area["y"]), best.y + 0.5)
	return Vector3.INF

# ------------------------------------------------------------------ the sweep
func _state_row(weight: String, hero: String, st: String) -> void:
	var home := Vector3.INF
	if FIELDS.has(st):
		home = _field_home(FIELDS[st])
		if home == Vector3.INF:
			ok(false, "%s %s: no %s area on the map" % [weight, hero, st])
			return
		face = _carve(mm, home)
		set_meta("home", home)
	for action in ACTIONS:
		var key := "%s/%s" % [st, action]
		var label := "%s %s in %s: %s" % [weight, hero, st, action]
		if NO_WALL.has(key):
			skipped += 1
			results[key + "/" + weight] = "n/a"
			print("CHAIN n/a  %s (%s)" % [label, NO_WALL[key]])
			continue
		if not _control(action):
			skipped += 1
			results[key + "/" + weight] = "n/a"
			print("CHAIN n/a  %s (does not go off on the plain ground of this fixture either)" % label)
			continue
		var got := _chain_trial(st, action)
		var rule: String = REFUSE.get(key, "")
		if got >= 0:
			var late := " (buffered, %.2fs)" % (got * Match.DT) if got > WATCH_NOW else ""
			print("CHAIN ok   %s: starts%s" % [label, late])
			results[key + "/" + weight] = "ok"
		elif rule != "":
			print("CHAIN ok   %s: refused, %s" % [label, rule])
			results[key + "/" + weight] = "refused"
		else:
			ok(false, label + ": the press was dropped (nothing started)")
			results[key + "/" + weight] = "FAIL"

## On plain ground, with no move in progress, the action goes off here at all (some need a target, or ground).
func _control(action: String) -> bool:
	if action in ["wall_kick", "mantle", "glide"]:
		return true
	var saved: Vector3 = get_meta("home")
	_ready_up(mm)
	var before := _snap()
	var dash0 := hunter.ak.dash_press_at
	_press_action(action, "ground")
	for i in 30:
		mm.step(Match.DT)
		_release()
		if _started(action, "ground", before, dash0):
			set_meta("home", saved)
			return true
	set_meta("home", saved)
	return false

## One trial: establish the state, press the action on the next step, watch BUFFER_S. Steps from the press to
## the start (0 = the same step's result), or -1 when nothing started.
func _chain_trial(st: String, action: String) -> int:
	_ready_up(mm)
	var wall: bool = action in ["wall_kick", "mantle"]
	if not _enter(st, wall):
		ok(false, "%s %s: could not enter the state for %s (gliding %s, grounded %s, fuel %.2f, glide_cd %.2f)" % [
			hunter.arch, st, action, hunter.gliding, hunter.grounded, hunter.glide_fuel, hunter.glide_cd])
		return -2
	var before := _snap()
	var dash0 := hunter.ak.dash_press_at
	var vy0 := hunter.vel.y
	_press_action(action, st)
	for i in int(BUFFER_S / Match.DT):
		mm.step(Match.DT)
		_release()
		if _started(action, st, before, dash0, vy0):
			return i
	return -1

func _release() -> void:
	for k in ["dash", "jump", "fire", "sig", "sec", "gear1", "glide_btn"]:
		hunter.inp[k] = false
	if hunter.gliding or hunter.dropping:
		return
	hunter.inp["glide"] = false

func _press_action(action: String, st: String) -> void:
	hunter.inp["glide_press_only"] = true
	match action:
		"dash":
			hunter.inp["dash"] = true
		"jump", "wall_kick":
			hunter.inp["jump"] = true
			hunter.inp["glide"] = true
		"glide":
			hunter.inp["glide_btn"] = true
			hunter.inp["glide"] = true
		"mantle":
			hunter.inp["move"] = Vector2(1, 0)
			hunter.inp["jump"] = hunter.grounded
		"lmb":
			hunter.inp["fire"] = true
		"e":
			_press("e")
	if st == "rocket_fall" or action in ["wall_kick", "mantle"]:
		hunter.inp["aim"] = hunter.pos + Vector3(1, 0.9, 0)

## What "the move started" means for each action, in the state's terms.
func _started(action: String, st: String, before: Dictionary, dash0: float, vy0 := 0.0) -> bool:
	match action:
		"dash":
			return hunter.ak.dash_press_at > dash0 or hunter.ak.in_dash() and st not in ["dash_ground", "dash_air"]
		"jump", "glide":
			if st in ["ground", "ice", "deep_water", "dash_ground"]:
				return hunter.jump_at > float(before.get("jump_at", -9.0)) if action == "jump" else false
			if st == "rocket_fall":
				return not hunter.diving and hunter.gliding
			return hunter.gliding
		"wall_kick":
			return WallMoves.scuffs > int(before.get("scuffs", 0)) or hunter.vel.y > vy0 + 1.0
		"mantle":
			return hunter.mantling() or hunter.pos.y > low_y + WALL_RISE * World.LEVEL - 0.1     # or up on the top
		_:
			return _went_off(before, action)

func _snap() -> Dictionary:
	var s := super._snap()
	s["jump_at"] = hunter.jump_at
	s["scuffs"] = WallMoves.scuffs
	return s

# ------------------------------------------------------------------ states
## Puts the hunter in `st` (at the wall's foot for a wall action); true when the state holds this step.
func _enter(st: String, wall: bool) -> bool:
	var home: Vector3 = get_meta("home")
	var pose := Vector3(face.x - (hunter.r + AT_WALL), low_y, face.y)
	if wall:
		hunter.teleport(pose)
	_keys_in(wall)
	match st:
		"ground", "ice", "deep_water":
			mm.step(Match.DT)
			return hunter.grounded
		"air":
			_rise(WALL_Y if wall else AIR_Y)
			return not hunter.grounded
		"glide":
			_rise(AIR_Y + 5.0)
			_open_glider()
			if wall:
				hunter.teleport(Vector3(pose.x, low_y + WALL_Y, pose.z))
				hunter.vel.y = 0.0
			return hunter.gliding
		"dash_ground", "dash_air":
			if st == "dash_air":
				_rise(WALL_Y if wall else AIR_Y)
			hunter.inp["dash"] = true
			var n := 0
			while not hunter.ak.in_dash() and n < DASH_WAIT:
				mm.step(Match.DT)
				hunter.inp["dash"] = false
				n += 1
			return hunter.ak.in_dash()
		"rocket_fall":
			hunter.teleport(Vector3(home.x, low_y + SKY, home.z))
			hunter.vel = Vector3.ZERO
			hunter.grounded = false
			hunter.dropping = true
			hunter.diving = true
			hunter.gliding = false
			mm.step(Match.DT)
			return hunter.dropping and hunter.diving
		"glide_ring":
			return _ring(false)
		"lift_ring":
			return _ring(true)
	return false

## Keys held through the state: into the wall for a wall pose, none otherwise.
func _keys_in(wall: bool) -> void:
	hunter.inp["move"] = Vector2(1, 0) if wall else Vector2.ZERO
	hunter.inp["glide_press_only"] = true

func _rise(height: float) -> void:
	hunter.pos += Vector3(0, height, 0)
	hunter.grounded = false
	hunter.coyote = 0.0
	for i in 2:
		mm.step(Match.DT)      # the locomotion state leaves GROUNDED (a glide from it is refused)

## Fresh Space presses up in the air (kept held between): the glider opens, once a cast still winding down
## (a Longneedle channel) lets it.
func _open_glider() -> void:
	hunter.inp["glide"] = true
	for i in OPEN_TRIES:
		hunter.inp["jump"] = i % 4 == 0
		mm.step(Match.DT)
		if hunter.gliding:
			break
	hunter.inp["jump"] = false

## Flies into the first glide ring (or lift ring) of the map and returns true the step after it took the hunter.
func _ring(lift: bool) -> bool:
	for rg in mm.air_rings.list:
		if rg["lift"] != lift:
			continue
		var c: Vector3 = rg["pos"]
		var dir: Vector2 = rg["dir"] if not lift else Vector2.ZERO
		hunter.teleport(c - Vector3(dir.x, 0.0, dir.y) * 1.5)
		hunter.grounded = false
		hunter.vel = Vector3(dir.x, 0.0, dir.y) * 12.0
		hunter.inp["glide"] = true
		hunter.gliding = true
		var cd: Dictionary = rg["cd"]
		cd.clear()
		for i in 30:
			mm.step(Match.DT)
			if cd.has(hunter.nid):
				return true
		return false
	return false
