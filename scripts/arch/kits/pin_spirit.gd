class_name PinSpirit
extends RefCounted
## Hem's Shift, Spirit Walk (hero sheet pin.md): a quick dodge roll the plain-dash way (ArchKit.dash_dir: the
## move direction, the aim when standing still or with the cursor setting), then "time" s walking as a
## spirit: rocks, trees, pillars, barriers and ledge faces taller than a step-up don't stop her (Hunter.spirit_t,
## World.occupy's ghost). Through a face she keeps the height she went in at (floor_under), so she comes out
## the far side at her own level or walks on inside it; walking off a ledge drops her as usual. Damage ends
## it. If it ends while she is inside something she is put back where she last stood clear on solid ground
## (never the top of a face she walked into, never over the abyss). Inside something her screen goes dark blue;
## the whole walk her body is darkened (PinFx wash) on every game.

var k: ArcherKit
var h: Hunter
var t := 0.0                   # s of Spirit Walk left (0: not walking)
var total := 0.0               # the length of this walk (the inside boost fades over it)
var entry := Vector3.ZERO      # the last spot she stood clear of everything, on solid ground
var safe_in := Vector3.INF     # her Hunter.safe_pos when she went in (kept while inside terrain)
var inside := false
var walks := 0                 # (checks)
var snap_backs := 0               # times it ended inside something and put her back (checks)
var passed := 0                # steps spent inside something (checks)
var orbs: Array = []           # spirit orbs left where she walked into something: {pos, t, node}
var granted: Array = []        # others given a Spirit Walk: [hunter, seconds left, last clear spot]
const ORB_T := 4.0             # s an orb stays
const ORB_R := 0.9             # m touch radius

func _init(kit: ArcherKit) -> void:
	k = kit
	h = kit.h

func active() -> bool:
	return t > 0.0

## True from the roll until the walk is over, on every game: the owner's walk (spirit_t), or a remote copy's
## kit move: pin_roll for the roll, pin_walk for the base walk (the wire carries the move, not the rank).
func phasing() -> bool:
	if h.spirit_t > 0.0:
		return true
	var dd := k.dash_def()
	var span := float(dd.get("roll_t", 0.24)) if k.anim_id == "pin_roll" else float(dd.get("time", 2.8))
	return k.anim_id in ["pin_roll", "pin_walk"] and k.m.time - k.anim_at < span

func start() -> void:
	var dd := k.dash_def()
	var dir := k.dash_dir()
	var roll := float(dd["roll"])
	var rt := float(dd["roll_t"])
	k.travel(roll, rt, {"invuln": rt, "dir": dir, "trail": "roll", "curved": true})
	k.play("pin_roll")
	t = walk_time() + rt
	total = t
	entry = h.pos if h.grounded or h.safe_pos == Vector3.INF else h.safe_pos
	inside = false
	h.spirit_t = t
	walks += 1
	k.st["last_dash"] = "spirit"
	if k.rank("dash") >= 3:
		_share_with_allies()
	k.vfx("spirit_go", h.pos, dir)  # no ring or burst on a dash; the shell shows the walk

## Seconds of Spirit Walk after the roll: rank 3 adds "time_rank3".
func walk_time() -> float:
	var dd := k.dash_def()
	return float(dd.get("time", 2.8)) + (float(dd.get("time_rank3", 0.5)) if k.rank("dash") >= 3 else 0.0)

## Rank 3: allies near her when she starts walk as spirits for the same time, with no roll.
func _share_with_allies() -> void:
	var reach := float(k.dash_def().get("ally_r", 6.0))
	for x in k.m.hunters:
		var already := granted.any(func(g): return g[0] == x)
		if x == h or x.team != h.team or x.downed or x.out or already or h.flat_dist(x) > reach:
			continue
		var walk := walk_time()
		x.spirit_t = walk
		granted.append([x, walk, x.pos])
		k.m.fx.burst(x.pos + Vector3(0, 0.8, 0), PinFx.THREAD, 12, 3.0, 0.3)

## Rank 3: extra move speed while inside something that fades to nothing as the walk runs out (the physics
## data's +150 on a 455 base speed is the 0.33 in "inside_boost").
func inside_boost() -> float:
	if not inside or k.rank("dash") < 3 or total <= 0.0:
		return 0.0
	return float(k.dash_def().get("inside_boost", 0.33)) * clampf(t / total, 0.0, 1.0)

## Walking into something leaves a spirit orb at the entry: anyone else who touches it (ally or foe) walks
## as a spirit too, for the same time (wiki: Phase Walk's phase orb).
func _drop_orb(at: Vector3) -> void:
	var n := KitMeshes.inst(k.fx, Models.sphere(0.3, 12), KitShaders.mat("star", PinFx.THREAD))
	n.visible = true
	n.global_position = at + Vector3(0, 0.9, 0)
	n.scale = Vector3.ONE * 1.4
	orbs.append({"pos": at, "t": ORB_T, "node": n})
	k.vfx("spirit_orb", at)

## The orbs and the walks they gave (run every step, walking or not).
func tick_orbs(dt: float) -> void:
	for o in orbs.duplicate():
		o["t"] = float(o["t"]) - dt
		if float(o["t"]) <= 0.0:
			(o["node"] as Node3D).queue_free()
			orbs.erase(o)
			continue
		var op: Vector3 = o["pos"]
		for x in k.m.hunters:
			if x == h or x.downed or x.out or granted.any(func(g): return g[0] == x): continue
			if Vector2(x.pos.x - op.x, x.pos.z - op.z).length() < ORB_R + x.r and absf(x.pos.y - op.y) < 1.5:
				var walk := walk_time()
				x.spirit_t = walk
				granted.append([x, walk, x.pos])
				k.m.fx.burst(x.pos + Vector3(0, 0.8, 0), PinFx.THREAD, 12, 3.0, 0.3)
	for g in granted.duplicate():
		var x: Hunter = g[0]
		g[1] = float(g[1]) - dt
		if not is_instance_valid(x):
			granted.erase(g)
		elif float(g[1]) <= 0.0:
			x.spirit_t = 0.0
			if inside_of(x):
				x.teleport(g[2])
				x.vel = Vector3.ZERO
			granted.erase(g)
		else:
			x.spirit_t = float(g[1])
			if clear_ground(x):
				g[2] = x.pos

func blocked_here() -> bool:
	return inside_of(h)

## Is x inside something a Spirit Walk passes: a rock, tree or pillar tile, a movement-blocking barrier, or
## terrain (a ledge face walked into: ground under its body stands above its feet).
static func inside_of(x: Hunter) -> bool:
	var w: World = x.m.world
	if w.is_block(x.pos.x, x.pos.z) or in_terrain(x):
		return true
	var reach := x.hull_r() * 0.6
	return not w.dyn_walls.is_empty() and Verbs.wall_blocks(w.dyn_walls, x.pos.x, x.pos.z, reach, x.pos.y) > 0.0

static func in_terrain(x: Hunter) -> bool:
	for o in [Vector2.ZERO, Vector2(x.r, 0), Vector2(-x.r, 0), Vector2(0, x.r), Vector2(0, -x.r)]:
		if x.m.world.ground_at(x.pos.x + o.x, x.pos.z + o.y) > x.pos.y + World.STEP:
			return true
	return false

## A spot to be put back to: clear of everything, standing, not over the abyss.
static func clear_ground(x: Hunter) -> bool:
	return x.grounded and not x.over_void() and not inside_of(x)

## The floor under a spirit inside terrain is the height it went in at (Hunter._physics), so it walks through
## a face at its own level instead of being lifted onto the top.
static func floor_under(x: Hunter, g: float) -> float:
	return x.pos.y if x.spirit_t > 0.0 and g > x.pos.y + World.STEP else g

func tick(dt: float) -> void:
	if t <= 0.0:
		return
	if t <= dt:
		end("time")             # (before t reaches 0: end() skips a walk that is already over)
		return
	t -= dt
	h.spirit_t = t
	var was_in := inside
	inside = blocked_here()
	if inside and not was_in:
		_drop_orb(entry)
		safe_in = h.safe_pos
	if in_terrain(h) and safe_in != Vector3.INF:
		h.safe_pos = safe_in            # (Hunter._physics saves where she stands; inside a face isn't safe)
	# footage 655.55-655.65: the roll goes straight into the crouched walk, no landing beat, so the walk's pose
	# takes over the moment the travel ends (roll_t) and the roll clip's standing tail (0.24-0.36) never shows
	if k.anim_id == "pin_roll" and k.m.time - k.anim_at >= float(k.dash_def().get("roll_t", 0.24)):
		k.play("pin_walk")
	if inside:
		passed += 1
	elif clear_ground(h):
		entry = h.pos
	k.fx.tint_to(1.0 if inside else 0.0)
	k.fx.aura_on(clampf(t / 0.3, 0.0, 1.0))

## Ends the walk (time, damage, a merge). Inside something: back to the entry point.
func end(why: String) -> void:
	if t <= 0.0 and h.spirit_t <= 0.0:
		return
	t = 0.0
	h.spirit_t = 0.0
	k.fx.aura_on(0.0)
	k.fx.tint_to(0.0)
	if blocked_here():
		snap_backs += 1
		h.teleport(entry)
		h.vel = Vector3.ZERO
		k.vfx("spirit_snap", entry)
	elif why != "merge":
		k.vfx("spirit_end")
	if k.anim_id in ["pin_roll", "pin_walk"]:
		k.anim_id = ""
