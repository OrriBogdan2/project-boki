class_name HunterDash
extends RefCounted
## A Hunter's dash: the roll, dashing through things, and what a dash carries along.


static func do_dash(h: Hunter) -> void:
	if h.downed or h.out:
		return
	# stunned, rooted or Grounded (a Thief's Bola: no dash, jump or glide; a reeling Dredge still barges)
	if h.stun_t > 0.0 or h.root_t > 0.0 or (KitStatus.grounded(h) and not DredgeKit.reeling(h)):
		h._ab_feedback("dash", "deny")
		return
	if h.roll_t > 0.0 and h.move_kind == "rush":
		h.roll_t = 0.0  # a glove/ability rush cancels straight into the dash
	elif h.pad.size() > 0 and not h.pad.get("ledge", false) and float(h.pad.get("t", 0.0)) > 0.12:
		h.pad = {}  # break out of a jump pad's flight
	elif h.roll_t > 0.0 or h.grap.size() > 0 or h.pad.size() > 0:
		h.dash_buf = Loco.press_buffer + (minf(h.ak.dash_left(), Hunter.DASH_KEEP) if h.ak else 0.0)  # fire as it ends
		return
	var use_ex := h.dash.wants_long(h.grounded)
	if not h.grounded and h.dashes >= 1.0 and not h.air_dashed and int(h.owner_stat("air_dashes")) > 0:
		use_ex = false  # a merge's dodge in the air: a normal dodge, once per airtime
		h.air_dashed = true
	if h.m.blight:
		h.m.blight.noise(h.pos, "dash", h)  # a dash is loud enough for the Blight nearby
	if h.ak:
		# the archetype's dash shape: it spends its own charge (or the long air dash) itself
		h.ak.dash_press_at = h.m.time  # its moves from here are the dash's (AirLimits)
		h.ak.on_dash(use_ex)
		return
	if use_ex:
		if not h.dash.spend_long(DashState.long_cd(h.cdat)):
			h._ab_feedback("dash", "deny")
			return
		h.ex_next = true
		h.gliding = false
	else:
		h.dash.spend_short()
	var effs: Array = (
		h.dodge_def.effects
		if h.dodge_def
		else [{"type": "dash", "speed": Hunter.DASH_SPEED, "time": Hunter.DASH_TIME, "invuln": 0.14}]
	)
	Effects.run(
		effs,
		h,
		{"slot": "dodge", "ability": h.dodge_def.id if h.dodge_def else "dash", "level": h.ability_level("dash")}
	)
	CombatBus.ability_used.emit(h, h.dodge_def.id if h.dodge_def else "dash", "dodge")


## World.occupy, with the sky train in it: on a car's deck you walk freely (the deck is your floor,
## whatever the ground far below or a bridge overhead is doing), the engine is a wall, and walking
## off a car only takes you onto ground about level with the deck (a pier at a stop): the edge of a
## car over the abyss holds you like any island edge. Dashes, knockback and jumps go over it.
static func _occ(h: Hunter, x: float, z: float, guard: bool) -> float:
	var st: SkyTrain = h.m.skytrain
	if st == null:
		return h.m.world.occupy(x, z, h.hull_r(), h.pos.y, guard, h.spirit_t > 0.0)
	var sw := st.solid_at(x, z, h.pos.y, h.hull_r())
	if sw > 0.0:
		return sw
	if st.walk_deck(Vector3(x, h.pos.y, z), h.hull_r()) > World.VOID + 1.0:
		return 0.0
	if not st.on_deck(h.pos):
		return h.m.world.occupy(x, z, h.r, h.pos.y, guard, h.spirit_t > 0.0)
	var b: float = h.m.world.occupy(x, z, h.r, h.pos.y, false)
	if b == 0.0 and guard:
		var g: float = h.m.world.ground_at(x, z)
		if g <= World.VOID + 1.0 or g < h.pos.y - 0.9:
			return -1.0
	return b


## True only when there's no direction at all you could step: really stuck, not just walking into a wall.
static func _boxed_in(h: Hunter) -> bool:
	for i in 8:
		var a := TAU * i / 8.0
		if _occ(h, h.pos.x + cos(a) * 0.2, h.pos.z + sin(a) * 0.2, false) == 0.0:
			return false
	return true


static func dash_with(h: Hunter, e: Dictionary) -> void:
	var d: Vector2 = h.inp["move"]
	if d.length() < 0.1 or (h.is_local() and Settings.get_v("dash_to_cursor")):
		d = h.aim_dir()  # standing still, or the "Dash toward the cursor" setting
	if e.has("dir") and (e["dir"] as Vector2).length() > 0.01:
		d = e["dir"]
	h.roll_dir = d.normalized()
	h.roll_speed = float(e.get("speed", Hunter.DASH_SPEED))
	h.roll_t = float(e.get("time", Hunter.DASH_TIME))
	h.move_kind = String(e.get("kind", "dash"))
	h.roll_falls = false
	h.dash_is_ex = h.ex_next
	if h.ex_next:
		# the long dash: the class's own distance and time (light 7m, medium 6m, heavy 5m)
		h.ex_next = false
		var k: Array = e.get("ex_feel", [1.0, 1.0])  # a Shift move's own dash_feel row (ArchKit.travel "feel")
		h.roll_t = float(h.cdat.get("ex_time", h.roll_t * 1.45))
		h.roll_speed = float(h.cdat.get("ex_dist", h.roll_speed * h.roll_t)) * float(k[0]) / (h.roll_t * float(k[1]))
		h.roll_t *= float(k[1])
		h.vel.y = maxf(h.vel.y, 0.0)
	h.roll_t /= Loco.dash_speed(h.arch)  # a hunter whose dash is slowed (tuning.json dash_speed) keeps its distance
	h.inv_t = maxf(h.inv_t, float(e.get("invuln", 0.14)))
	h.shove = (
		{
			"hit": {},
			"kb": float(e.get("shove_kb", 9.0)),
			"dmg": float(e.get("shove_dmg", 0.0)),
			"ws": float(e.get("wallstun", 0.0))
		}
		if e.get("shove", false)
		else {}
	)
	if float(e.get("phase", 0.0)) > 0.0:
		# Light: for the whole step shots fly straight through you
		h.phase_t = maxf(h.phase_t, h.roll_t + float(e["phase"]) * 0.3)
		h.inv_t = maxf(h.inv_t, h.roll_t + 0.02)
	match String(e.get("trail", "")):
		"ghost":
			for i in 3:
				h.m.later(
					h.roll_t * float(i) / 3.0,
					func():
						if is_instance_valid(h) and h.m:
							h.m.fx.ghost(h.position, h.face, Color("d8c8ff"), float(h.cdat["scale"]))
				)
		"roll":
			h.m.fx.dust(h.pos, 6)
		"dust":
			h.m.fx.dust(h.pos, 10)
	if not h.shove.is_empty():
		h.fortify_t = maxf(h.fortify_t, h.roll_t + 0.1)  # nothing knocks you back mid-charge
	h.dash_at = h.m.time
	h.dodged = false
	h.fly_t = 0.0
	if h.wpn.get("bloom_dash_reset", false):
		h.wbloom = 0.0
	h.m.sfx(HeroSfx.dash_name(h), h.pos, -4.0, 0.8 if not h.shove.is_empty() else 1.0)
	HunterFoley.dash(h)
	if not (h.ak and h.ak.own_dash_trail()):
		h.m.fx.dash_trail(h)  # the shared puff and ring; a kit with its own trail draws no ring


## Where this frame's dash step ends, short of a block: the segment a dash hit tests (Swept).
static func _dash_end(h: Hunter, dt: float) -> Vector3:
	var step := Loco.dash_hv(h.roll_dir * h.roll_speed, h.arch) * dt
	return Swept.clip(h.m.world, h.pos, h.pos + Vector3(step.x, 0, step.y))


## A grammar dash you perform (or a kit's dash that hits): what you dash through gets its effects.
static func _pass_along(h: Hunter, dt: float) -> void:
	var end := _dash_end(h, dt)
	for f in h.m.foes_of(h.team):
		if h.dash_pass.is_empty():
			return
		if (
			h.dash_pass["hit"].has(f.get_instance_id())
			or Swept.dist(f.pos, h.pos, end) > h.r + f.r + float(h.dash_pass.get("w", 0.8)) * 0.5
			or absf(f.pos.y - h.pos.y) > 1.4
		):
			continue
		h.dash_pass["hit"][f.get_instance_id()] = true
		if h.dash_pass.get("kx") is Callable:
			(h.dash_pass["kx"] as Callable).call(f)
			continue
		var o := {"src": "abil", "ab": "dodge", "tags": ["dodge"]}
		var po: Dictionary = h.dash_pass["opts"]
		for k in ["burn", "slow", "blight", "stun", "root"]:
			if po.has(k):
				o[k] = float(po[k])
		f.hurt(maxf(0.1, float(po.get("dmg", 0.0))) * h.m.dmg_mult(h), h, o)
		h.m.fx.burst(f.pos + Vector3(0, 0.8, 0), Color(String(po.get("color", "#a6ff3a"))), 8, 3.0, 0.3)


static func _shove_along(h: Hunter, dt: float) -> void:
	var end := _dash_end(h, dt)
	for f in h.m.foes_of(h.team):
		if h.shove.is_empty():
			return
		if (
			h.shove["hit"].has(f.nid)
			or Swept.dist(f.pos, h.pos, end) > h.r + f.r + 0.35
			or absf(f.pos.y - h.pos.y) > 1.4
		):
			continue
		h.shove["hit"][f.nid] = true
		var side := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z).normalized()
		var push := (h.roll_dir * 0.7 + side * 0.5).normalized() * float(h.shove["kb"])
		var so := {
			"kb": push,
			"lift": 2.5 if float(h.shove["kb"]) > 0.0 else 0.0,
			"src": "abil",
			"ab": "dodge",
			"tags": ["dodge"]
		}
		if float(h.shove.get("ws", 0.0)) > 0.0:
			so["wallstun"] = float(h.shove["ws"])
		f.hurt(maxf(0.1, float(h.shove["dmg"])) * h.m.dmg_mult(h), h, so)
