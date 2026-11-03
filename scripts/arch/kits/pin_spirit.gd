class_name PinSpirit
extends RefCounted
## Pin's Shift, Spirit Walk (hero sheet pin.md): a quick dodge roll the plain-dash way (ArchKit.dash_dir: the
## move direction, the aim when standing still or with the cursor setting), then "time" s walking as a
## spirit: rocks, trees, pillars and barriers don't stop her (Hunter.spirit_t; terrain cliffs and ledges
## still do). Damage ends it. If it ends while she is inside something she loses "stuck_cost" Focus and
## is put back where she last stood clear. While she is inside something her own screen goes dark blue.

var k: ArcherKit
var h: Hunter
var t := 0.0                   # s of Spirit Walk left (0: not walking)
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

func start(use_ex: bool) -> void:
	var dd := k.dash_def()
	var dir := k.dash_dir()
	var roll := float(dd.get("roll", 2.6))
	var rt := float(dd.get("roll_t", 0.16))
	k.travel(roll, rt, {"invuln": rt, "dir": dir, "trail": "roll"}, use_ex)
	k.play("pin_roll")
	t = float(dd.get("time", 2.8)) + (0.6 if k.rank("dash") >= 3 else 0.0) + rt
	entry = h.pos
	inside = false
	h.spirit_t = t
	walks += 1
	k.st["last_dash"] = "spirit"
	k.m.fx.burst(h.pos + Vector3(0, 0.6, 0), PinFx.GREEN, 18, 4.5, 0.35, 2.0, 1.0)
	k.m.fx.ring(h.pos, 1.2, PinFx.GREEN, 0.25)
	k.net_ring(h.pos, 1.2, PinFx.GREEN)
	k.m.sfx("pin_spirit", h.pos, -3.0 if h.is_local() else -7.0)

## Walking into something leaves a spirit orb at the entry: anyone else who touches it (ally or foe) walks
## as a spirit too, for the same time (wiki: Phase Walk's phase orb).
func _drop_orb(at: Vector3) -> void:
	var n := KitMeshes.inst(k.fx, Models.sphere(0.3, 12), KitShaders.mat("star", PinFx.GREEN))
	n.visible = true
	n.global_position = at + Vector3(0, 0.9, 0)
	n.scale = Vector3.ONE * 1.4
	orbs.append({"pos": at, "t": ORB_T, "node": n})
	k.m.fx.ring(at, ORB_R, PinFx.GREEN, 0.3)

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
				var walk := float(k.dash_def().get("time", 2.8))
				x.spirit_t = walk
				granted.append([x, walk])
				k.m.fx.burst(x.pos + Vector3(0, 0.8, 0), PinFx.GREEN, 12, 3.0, 0.3)
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
	if w.is_block(h.pos.x, h.pos.z):
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
	if k.anim_id == "pin_roll" and k.m.time - k.anim_at > 0.4:
		k.play("pin_walk")
	if inside:
		passed += 1
	else:
		entry = h.pos
	k.fx.tint_to(1.0 if inside else 0.0)
	k.fx.aura_on(clampf(t / 0.3, 0.0, 1.0))
	if t <= 0.0:
		end("time")

## Ends the walk (time, damage, a merge). Inside something: back to the entry point, Focus spent.
func end(why: String) -> void:
	if t <= 0.0 and h.spirit_t <= 0.0:
		return
	t = 0.0
	h.spirit_t = 0.0
	k.fx.aura_on(0.0)
	k.fx.tint_to(0.0)
	if blocked_here():
		snap_backs += 1
		k.add_res(-float(k.dash_def().get("stuck_cost", 30.0)))
		k.m.fx.burst(h.pos + Vector3(0, 0.8, 0), PinFx.GREEN, 10, 3.0, 0.3)
		h.teleport(entry)
		h.vel = Vector3.ZERO
		k.m.fx.ring(entry, 1.0, PinFx.GREEN, 0.25)
		k.m.sfx("pin_spirit_end", entry, -4.0, 0.8)
	elif why != "merge":
		k.m.sfx("pin_spirit_end", h.pos, -8.0)
	if k.anim_id in ["pin_roll", "pin_walk"]:
		k.anim_id = ""
