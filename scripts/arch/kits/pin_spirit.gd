class_name PinSpirit
extends RefCounted
## Hem's Shift, Spirit Walk (hero sheet pin.md): a quick dodge roll the plain-dash way (ArchKit.dash_dir: the
## move direction, the aim when standing still or with the cursor setting), then "time" s walking as a
## spirit: rocks, trees, pillars, barriers and raised terrain don't stop her (Hunter.spirit_t; the data's
## Phase Walk rolls "through a pillar and the raised-platform wall"). Damage ends it. If it ends while she
## is inside something she is put back where she last stood clear. While she is inside something her own
## screen goes dark blue.

var k: ArcherKit
var h: Hunter
var t := 0.0                   # s of Spirit Walk left (0: not walking)
var total := 0.0               # the length of this walk (the inside boost fades over it)
var entry := Vector3.ZERO      # the last spot she stood clear of everything
var inside := false
var walks := 0                 # (checks)
var snap_backs := 0               # times it ended inside something and put her back (checks)
var passed := 0                # steps spent inside something (checks)
var orbs: Array = []           # spirit orbs left where she walked into something: {pos, t, node}
var granted: Array = []        # others the orbs gave a Spirit Walk to: [hunter, seconds left]
const ORB_T := 4.0             # s an orb stays
const ORB_R := 0.9             # m touch radius

func _init(kit: ArcherKit) -> void:
	k = kit
	h = kit.h

func active() -> bool:
	return t > 0.0

func start() -> void:
	var dd := k.dash_def()
	var dir := k.dash_dir()
	var roll := float(dd.get("roll", 3.5))
	var rt := float(dd.get("roll_t", 0.24))
	k.travel(roll, rt, {"invuln": rt, "dir": dir, "trail": "roll"})
	k.play("pin_roll")
	t = walk_time() + rt
	total = t
	entry = h.pos
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
		granted.append([x, walk])
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
				granted.append([x, walk])
				k.m.fx.burst(x.pos + Vector3(0, 0.8, 0), PinFx.THREAD, 12, 3.0, 0.3)
	for g in granted.duplicate():
		var x: Hunter = g[0]
		g[1] = float(g[1]) - dt
		if not is_instance_valid(x) or float(g[1]) <= 0.0:
			if is_instance_valid(x): x.spirit_t = 0.0
			granted.erase(g)
		else:
			x.spirit_t = float(g[1])

func blocked_here() -> bool:
	var w: World = k.m.world
	if w.is_block(h.pos.x, h.pos.z) or w.ground_at(h.pos.x, h.pos.z) > h.pos.y + World.STEP:
		return true
	return not w.dyn_walls.is_empty() and Verbs.wall_blocks(w.dyn_walls, h.pos.x, h.pos.z, h.r * 0.6, h.pos.y) > 0.0

func tick(dt: float) -> void:
	if t <= 0.0:
		return
	t -= dt
	h.spirit_t = maxf(t, 0.0)
	var was_in := inside
	inside = blocked_here()
	if inside and not was_in:
		_drop_orb(entry)
	# footage 655.55-655.65: the roll goes straight into the crouched walk, no landing beat, so the walk's pose
	# takes over the moment the travel ends (roll_t) and the roll clip's standing tail (0.24-0.36) never shows
	if k.anim_id == "pin_roll" and k.m.time - k.anim_at >= float(k.dash_def().get("roll_t", 0.24)):
		k.play("pin_walk")
	if inside:
		passed += 1
	else:
		entry = h.pos
	k.fx.tint_to(1.0 if inside else 0.0)
	k.fx.aura_on(clampf(t / 0.3, 0.0, 1.0))
	if t <= 0.0:
		end("time")

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
