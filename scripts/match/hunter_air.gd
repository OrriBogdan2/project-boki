class_name HunterAir
extends RefCounted
## A Hunter in the air by force: the jump, launches, jump pads and being freed from clipping into a wall.


static func do_jump(h: Hunter) -> void:
	if h.ak and h.ak.cast_locked() and not h.grounded and not h.gliding:
		h.glide_armed = true  # a cast keeps the glider shut: held, it opens as the cast ends
	if (
		h.downed
		or h.stun_t > 0.0
		or h.grap.size() > 0
		or h.out
		or KitStatus.grounded(h)
		or (h.ak and h.ak.cast_locked())
	):
		return
	if not h.lfloat.is_empty():
		h._ledge_fling()
		return
	if h.dropping and h.diving:
		h._deploy()
		return
	if h.pad.size() > 0:
		# press jump mid-flight off a jump pad and the glider opens, keeping the launch's speed
		if not h.pad.get("ledge", false) and float(h.pad["t"]) > 0.12 and h.can_glide():
			h.pad = {}
			h._open_glider()
		return
	if h.roll_t > 0.0 and h.grounded and h.move_kind == "dash":
		# jump out of a dash: the dash ends and the jump carries Loco.dash_jump_keep of its speed (the farm's too)
		var keep := Vector2(h.vel.x, h.vel.z) * Loco.dash_jump_keep
		h.roll_t = 0.0
		h.glide_cd = 0.0
		h.vel.x = keep.x
		h.vel.z = keep.y
	if h.grounded or h.coyote > 0.0:
		h.glide_cd = 0.0  # a jump off the ground is a fresh air phase: a move's wind-down was for its own end
		h.vel.y = Hunter.JUMP_V * (float((h.kin as Kin).ks.mount.get("jump", 1.0)) if h.mounted() else 1.0)
		h.jump_at = h.m.time
		h.grounded = false
		h.coyote = 0.0
		h.m.sfx("jump", h.pos, -6.0)
		h.m.fx.dust(h.pos, 2)  # a little kick of dust off the ground
		return
	if h.air_jumps < int(h.owner_stat("extra_jumps")) and not h.gliding:
		# a merge's double jump
		h.air_jumps += 1
		h.vel.y = Hunter.JUMP_V
		h.m.fx.dust(h.pos, 4)
		h.m.sfx("jump", h.pos, -4.0, 1.2)
		return
	if h.wall_moves.try_kick(h):
		return
	# already in the air: a second press opens the glider, rising or falling, unless you're about to land
	var near_ground := HunterMove.near_landing(h.vel.y, h.pos.y - h.ground()) and not h.over_void()
	if not h.gliding and not near_ground and (h._dash_into_glide() or h.can_glide()):
		h._open_glider()
		if h.gliding:
			return  # (refused by the locomotion state, e.g. a wire's knocked tail: the press stays armed below)
	h.glide_armed = not h.gliding and not near_ground  # a move keeps it shut: held, it opens as the move ends
	h.jump_buf = HunterMove.jump_buffer_s


static func launch_to(h: Hunter, target: Vector3, t: float) -> void:
	if target.y > h.pos.y + World.STEP and not h.m.world.is_void(target.x, target.z):
		# up onto higher ground (a grapple onto a ledge, a leap up a cliff): the move was
		# aimed there, so it's a sure arc that clears the lip (a pad flight) instead of a thrown
		# body that can clip the cliff's edge now that ledges no longer grab you on their own
		var d := Vector2(target.x - h.pos.x, target.z - h.pos.z).length()
		h.pad = {"from": h.pos, "to": target, "t": 0.0, "dur": maxf(0.12, t), "h": 0.6 + 0.12 * d}
		h.vel = Vector3((target.x - h.pos.x) / maxf(0.12, t), 0.0, (target.z - h.pos.z) / maxf(0.12, t))
		h.grounded = false
		h.fly_t = 0.0
		h.roll_t = 0.0
		return
	h.vel.x = (target.x - h.pos.x) / t
	h.vel.z = (target.z - h.pos.z) / t
	h.vel.y = (target.y - h.pos.y) / t + 0.5 * Hunter.H_GRAV * t
	h.grounded = false
	h.fly_t = t + 0.3
	h.roll_t = 0.0


static func pad_launch(h: Hunter, to: Vector3) -> void:
	var d := Vector2(to.x - h.pos.x, to.z - h.pos.z).length()
	h.pad = {
		"from": h.pos,
		"to": to,
		"t": 0.0,
		"dur": clampf(d / 12.0, 0.7, 1.5),
		"h": maxf(h.pos.y, to.y) - h.pos.y + 2.5 + d * 0.12
	}
	h.roll_t = 0.0
	h.grap = {}
	h.grounded = false


static func _pad_fly(h: Hunter, dt: float) -> void:
	h.pad["t"] += dt
	var k := clampf(h.pad["t"] / h.pad["dur"], 0.0, 1.0)
	var a: Vector3 = h.pad["from"]
	var b: Vector3 = h.pad["to"]
	var np: Vector3
	if h.pad.has("face"):
		np = h._mantle_point(k)
	else:
		var y := lerpf(a.y, b.y, k) + 4.0 * float(h.pad["h"]) * k * (1.0 - k)
		np = Vector3(lerpf(a.x, b.x, k), y, lerpf(a.z, b.z, k))
	h.vel = (np - h.pos) / maxf(dt, 0.0001)
	h.pos = np
	if k >= 1.0:
		h.pos = b
		var ledge: bool = h.pad.get("ledge", false)
		var hvel := Vector2(h.vel.x, h.vel.z)
		if ledge and hvel.length() > 0.01:
			# out of a mantle you keep running in the same direction, no stop
			hvel = hvel.normalized() * float(h.pad.get("carry", h.base_speed))
		h.vel = Vector3(hvel.x, 0.0, hvel.y).limit_length(h.base_speed * 1.3)
		h.grounded = true
		h.pad = {}
		h.squash = 0.12 if ledge else 0.3
		h.m.fx.dust(h.pos, 3 if ledge else 8)
		h.m.sfx("land", h.pos, -12.0 if ledge else -8.0)


## Islands are solid all the way down: if anything (a pull, a drag, a shove) has left you inside an
## island's column below its top, you're put back beside it, or on top when the top is in reach.
static func _unclip(h: Hunter) -> void:
	if h.grounded or h.pad.size() > 0 or h.grap.size() > 0 or h.spirit_t > 0.0:
		return
	var w: World = h.m.world
	var g: float = w.ground_at(h.pos.x, h.pos.z)
	if g <= World.VOID + 1.0 or h.pos.y > g - 1.25 or h.ground() != g:
		return
	if g - h.pos.y <= HunterFeel.mantle_reach_abyss and not w.is_block(h.pos.x, h.pos.z):
		h.pos.y = g
		h.vel.y = 0.0
		h.grounded = true
		return
	for rad in [0.5, 0.8, 1.2, 1.7, 2.4, 3.2, 4.5]:
		for i in 16:
			var a := TAU * i / 16.0
			var x: float = h.pos.x + cos(a) * rad
			var z: float = h.pos.z + sin(a) * rad
			if w.is_void(x, z) and w.occupy(x, z, h.hull_r(), h.pos.y, false) == 0.0:
				h.pos.x = x
				h.pos.z = z
				h.vel.x = 0.0
				h.vel.z = 0.0
				return
	if h.safe_pos != Vector3.INF:
		h.teleport(h.safe_pos)
		h.vel = Vector3.ZERO
