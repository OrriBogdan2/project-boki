class_name PinSpirit
extends RefCounted
## Pin's Shift, Spirit Walk (hero sheet pin.md): a quick dodge roll in the move direction (the aim when
## standing still), then "time" s walking as a spirit: rocks, trees, pillars and barriers don't stop her
## (Hunter.spirit_t; terrain cliffs and ledges still do). Damage ends it. If it ends while she is inside
## something she loses "stuck_cost" Focus and is put back where she last stood clear. While she is inside
## something her own screen goes dark blue.

var k: ArcherKit
var h: Hunter
var t := 0.0                   # s of Spirit Walk left (0: not walking)
var entry := Vector3.ZERO      # the last spot she stood clear of everything
var inside := false
var walks := 0                 # (checks)
var snapped := 0               # times it ended inside something and put her back (checks)
var passed := 0                # steps spent inside something (checks)

func _init(kit: ArcherKit) -> void:
	k = kit
	h = kit.h

func active() -> bool:
	return t > 0.0

func start(use_ex: bool) -> void:
	var dd := k.dash_def()
	var mv: Vector2 = h.inp.get("move", Vector2.ZERO)
	var dir := mv.normalized() if mv.length() > 0.1 else h.aim_dir()
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
	inside = blocked_here()
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
		snapped += 1
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
