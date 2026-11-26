class_name HunterRender
extends RefCounted
## How a Hunter is drawn each frame: the animation state, the model fit and the render position.


## The dodge pose HunterAnim plays. Claire's skate has its own, so the light-dash lean does not stack
## on the skate move's lean and tip her over.
static func _dash_anim_kind(h: Hunter) -> String:
	if not h.strike_at_end.is_empty():
		return "lunge"
	if h.move_kind == "rinkrun":
		return "skate"
	if h.move_kind == "rush":
		return "rush"
	var own := h.ak.dodge_anim() if h.ak else ""  # the kit's own (Slipstep's slide)
	return own if own != "" else String(Hunter.DODGE_ANIM.get(h.cls, "roll"))


## How far up the face a ledge rise has you (0 at the start, 1 at the lip), -1 when not rising: the
## animation's progress.
static func _rise_k(h: Hunter) -> float:
	if h.lfloat.is_empty():
		return -1.0
	var y0 := float(h.lfloat["y0"])
	return clampf((h.pos.y - y0) / maxf(0.05, float(h.lfloat["lip"]) + 0.12 - y0), 0.0, 1.0)


static func _anim_state(h: Hunter, stretch: float) -> void:
	var s := h.anim_s
	s["vel"] = h.vel
	s["face"] = h.face
	s[WardenLookAt.LOOK] = WardenLookAt.aim_of(h)
	s["grounded"] = h.grounded and h.pad.is_empty()
	s["gliding"] = h.gliding and not h.plunging()
	s["diving"] = h.plunging()
	s["skydive"] = h.diving
	s["rocket"] = h.rocket != null
	s["rolling"] = h.roll_t > 0.0
	s["dash_dir"] = h.roll_dir
	s["dash_kind"] = _dash_anim_kind(h)
	s["crouch"] = h.crouch_k
	s["dead"] = h.out
	s["dead_t"] = h.m.time - float(h.get_meta("died_at", h.m.time)) if h.out else 0.0
	s["fall"] = HunterFall.clip_k(h)
	s["ledge"] = h.grap.size() > 0
	var mk := _rise_k(h)
	if h.pad.has("face"):
		mk = clampf(float(h.pad["t"]) / maxf(0.01, float(h.pad["dur"])), 0.0, 1.0)
	s["mantle"] = mk
	StompLook.fill(h, s)  # "stomp" (the cycle's phase, -1 off) and its style
	UtilityPose.fill(h, s)  # "drink", or "util" with "util_move"
	s["recoil"] = h.recoil
	s["flash"] = clampf(h.flash_t / 0.12, 0.0, 1.0)
	s["fired"] = h.idle_fire
	s["wid"] = h.wid
	s["swing_n"] = h.swing_n
	var cd: Array = h.wpn.get("combo_dmg", [])
	var cn: int = maxi(1, cd.size() if cd.size() > 0 else (h.wpn.get("combo", [1.0]) as Array).size())
	s["combo"] = -1 if h.combo_i == 0 else (h.combo_i - 1) % cn
	s["charge"] = (
		clampf((h.mel_hold - 0.15) / maxf(0.1, float(h.wpn.get("charge_time", 1.0))), 0.0, 1.0)
		if h.mel_hold > 0.15
		else 0.0
	)
	s["cast"] = h.m.time - h.cast_at
	s["cast_slot"] = h.cast_slot
	if h.ak:  # (every frame: a move ended by play("") must not stay frozen in the state)
		s["kmove"] = h.ak.anim_id  # the kit's own full-body move (HunterAnim.KMOVES), "" for none
		s["kmove_t"] = h.m.time - h.ak.anim_at
	else:
		s.erase("kmove")  # (the dictionary is kept: a move the kit cleared must not stay on the body)
	if h.ak and h.ak.face_locked():
		s["statue"] = true  # frozen: no idle sway, glance or fidget
	h.wall_moves.anim_state(h, s)
	MergeKit.anim_state(h, s)
	KinDowned.anim_state(h, s)
	HazardMoves.anim_state(h, s)
	KinSummon.anim_state(h, s)
	s["hit_t"] = h.m.time - h.hurt_at
	s["hit_k"] = h.hit_k
	if h.last_hit_by and is_instance_valid(h.last_hit_by):
		s["hit_dir"] = Vector2(h.pos.x - h.last_hit_by.pos.x, h.pos.z - h.last_hit_by.pos.z)
	s["stun"] = h.stun_t > 0.0
	s["rooted"] = h.root_t > 0.0
	s["rooted"] = h.root_t > 0.0  # (a Hero's clips show both: WardenCc)
	s["gnd"] = KitStatus.grounded(h)
	s["heart"] = Heart.carrying(h)
	s["base"] = BaseRecall.progress(h)
	s["squash"] = h.squash
	s["stretch"] = stretch
	s["kin_on_shoulder"] = h.kin != null and (h.kin as Kin).state == "shoulder"
	# reviving a teammate: standing on their wisp
	var rv := false
	if h.grounded and not h.downed:
		for o in h.m.hunters:
			if o != h and o.downed and o.team == h.team and h in (o.get_meta("revivers", []) as Array):
				rv = true
				break
	s["reviving"] = rv or h.box_reviving()
	s["act"] = h.holding()
	s["act_at"] = WardenOpen.lid_near(h.m as Match, h.pos) if s["act"] in WardenOpen.KINDS else Vector3.INF
	s["idle_break"] = h.is_local()
	s["aim_pitch"] = AimPitch.of(h)
	# an emote bubble over us
	var em := ""
	var et := 99.0
	if h.m.truce:
		for e in h.m.truce.shown:
			if e["h"] == h:
				em = String(e["id"])
				et = float(e["t"])
	s["dead"] = h.out
	s["dead_t"] = h.m.time - float(h.get_meta("died_at", h.m.time)) if h.out else 0.0
	s["extract_t"] = WardenClips.leave_t(h)
	s["emote"] = em
	s["emote_t"] = et
	if not h.grounded and not h.gliding and not h.downed:
		s["air_h"] = clampf(h.pos.y - h.m.world.ground_at(h.pos.x, h.pos.z), 0.0, 30.0)
	else:
		s.erase("air_h")


## Hunter.set_model's part after the base class has parented the model.
static func after_model(h: Hunter, n: Node3D) -> void:
	if n == null:
		return
	h.vis_k = 1.0
	fit_scale(h)


## Puts VIS_SCALE x the camera's hunter_scale on the model (again when the Settings camera changes).
static func fit_scale(h: Hunter) -> void:
	var k: float = Hunter.VIS_SCALE * (h.m.cam.hunter_scale if h.m and h.m.cam else 1.0)
	if is_equal_approx(k, h.vis_k):
		return
	h.model.scale *= k / h.vis_k
	var ring := h.model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.scale /= k / h.vis_k
	h.vis_k = k


static func render_pos(h: Hunter, alpha: float) -> Vector3:
	if not Hunter.LOCAL_RENDER_LEAD or not h.is_local() or h.freeze_t > 0.0 or h.remote:
		return h.prev.lerp(h.pos, alpha)
	var stp := h.pos - h.prev
	if stp.length() > 1.5:
		return h.pos
	return h.pos + stp * alpha


## Hunter.render's part after the base class has moved the node.
static func after_render(h: Hunter, delta: float, alpha: float) -> void:
	if Hunter.LOCAL_RENDER_LEAD and h.is_local() and h.freeze_t <= 0.0 and not h.remote:
		h.position = render_pos(h, alpha)
	StepSmooth.ease(h, delta)
	h.visible = (
		(not h.out or HunterWisp.out_visible(h))
		and (not h.extracted or WardenClips.leave_t(h) >= 0.0)
		and SkyDeck.drawn(h)
		and not h.unseen
	)
	if not h.model:
		return
	fit_scale(h)
	HunterWisp.tick(h, delta)
	UltGlow.tick(h, delta)
	var body_face := HunterFall.face_of(h)  # a knocked-down body keeps facing the way it fell
	if h.m.cam:
		h.model.basis = h.m.cam.char_basis(body_face, h.model.scale, not SkyDeck.upright(h))  # (CamRig.char_lean)
	else:
		h.model.rotation.y = body_face
	if h.out and h.has_meta("fling"):
		# hit by the sky train: the body is flung tumbling through the air for a moment, then gone
		var fl: Dictionary = h.get_meta("fling")
		var ft: float = h.m.time - float(fl["t"])
		if ft < 1.2:
			var v0: Vector3 = fl["v"]
			h.visible = true
			h.position = (fl["from"] as Vector3) + v0 * ft + Vector3(0, -0.5 * Hunter.H_GRAV * 0.45 * ft * ft, 0)
			h.model.rotation = Vector3(ft * 9.0, h.face + ft * float(fl["spin"]) * 6.0, ft * 4.0 * float(fl["spin"]))
			return
		h.remove_meta("fling")
		h.model.rotation = Vector3(0, h.face, 0)
		if h.m.cam:
			h.model.basis = h.m.cam.char_basis(h.face, h.model.scale)
	# riding a mount: you sit up on its back
	var ride := (h.kin as Kin).ride_height() if h.mounted() and not h.downed else SkyDeck.lift(h)
	h.model.position.y = lerpf(h.model.position.y, ride - HazardMoves.sink(h), minf(1.0, delta * 12.0))
	if h.rocket:
		h.rocket.seat(h)
	if h.remote:
		h.update_lip()
	h._render_weapon_fx(delta)
	DropReticle.tick(h, delta)
	var rig: Node3D = h.model.get_node("Rig")
	var torso: Node3D = rig.get_node("Torso")
	if h.anim == null or h.anim.model != h.model:
		h.anim = HunterAnim.new(h.model)
	var hv := Vector2(h.vel.x, h.vel.z)
	var spd := hv.length()
	h.crouch_k = move_toward(h.crouch_k, 1.0 if h.crouch else 0.0, delta * 8.0)
	var stretch := 0.0
	if h.roll_t > 0.0:
		stretch = 0.25 if h.anim.dash_kind != "roll" else 0.0
	elif not h.gliding and not h.grounded and h.pad.is_empty():
		stretch = clampf(h.vel.y / 30.0, -0.1, 0.18)
	# posed every SimLod.pose_every frames (staggered), catching up the skipped time; a backlog from a slower rate
	# (it just came on screen or closer) poses now
	h.anim_dt += delta
	h.anim_n += 1
	var every := SimLod.pose_every(h.m, h)
	var posed := (h.anim_n + h.get_instance_id()) % every == 0 or h.anim_dt > every * delta
	h.model.set_meta(WardenGlb.POSE_HELD, -1 if posed else Engine.get_process_frames())
	if posed:
		_anim_state(h, stretch)
		h.anim.update(h.anim_dt, h.anim_s)
		h.anim.feet.plant(h.anim, h.m.world, h.anim_dt, every == 1 and FootPlant.near(h), h.pos.y, h.r)
		h.anim_dt = 0.0
	if posed and h.anim.stepped and not h.downed:
		StepReach.contact(h)
		if h.grounded and spd > 4.0:  # (running: the surface's step and little puffs of dust, on the plant)
			h.m.fx.dust(h.pos, 2)
			Juice.footstep(h)
	if posed:
		HazardMoveSfx.play(h)
	if posed and h.anim.slammed and not h.downed:
		# a heavy coming down hard: a ring of dust where they land
		h.m.fx.dust(h.pos, 12)
	var tc: Color = Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]
	if h.roll_t > 0.0:
		h.ghost_t -= delta
		if h.ghost_t <= 0.0 and h.model.visible and not (h.ak and h.ak.own_dash_trail()):
			h.ghost_t = 0.028
			if h.ak == null or not h.ak.dash_afterimage():
				h.m.fx.ghost(h.position, h.face, tc, float(h.cdat["scale"]))
	elif h.gliding:
		h.wind_t -= delta
		# carrying a dash's momentum: a dense streak trail and afterimages until it bleeds off
		var boosted := h.boost_fx_t > 0.0 and spd > HunterMove.glide_cruise * 1.25 and not h.dropping
		h.boost_fx_t = maxf(0.0, h.boost_fx_t - delta) if boosted else 0.0
		if h.wind_t <= 0.0:
			h.wind_t = 0.035 if boosted else 0.09
			h.m.fx.debris(
				h.pos + Vector3(randf_range(-0.8, 0.8), 1.9, randf_range(-0.4, 0.4)),
				Color(1, 1, 1, 0.8 if boosted else 0.5),
				4 if boosted else 2,
				1.0,
				0.45,
				-1.0,
				0.9 if boosted else 0.7,
				Vector3(-h.vel.x, 0, -h.vel.z).normalized(),
				20.0
			)
			if boosted:
				h.m.fx.ghost(h.position, h.face, Color(0.85, 0.95, 1.0), float(h.cdat["scale"]))
	# (the rig's squash, the skydive and lying downed are posed by HunterAnim)
	var glide_goal := 1.0 if h.gliding and not h.plunging() else 0.0
	h.glide_k = move_toward(h.glide_k, glide_goal, delta * (7.0 if h.gliding else 9.0))
	var gl: Node3D = torso.get_node("Glider")
	gl.visible = h.glide_k > 0.02
	if gl.visible:
		var gk := h.glide_k - 1.0
		var ek := 1.0 + 2.7 * gk * gk * gk + 1.7 * gk * gk  # pops open with a little overshoot
		gl.scale = Vector3(ek * (1.0 + sin(h.m.time * 9.0) * 0.02), ek, ek)
		gl.rotation.x = 0.35 * ek - 0.1
		GliderHeat.tick(h, gl, delta)
	var halo := torso.get_node_or_null("Halo")
	if halo:
		halo.rotation.y += delta * 2.0
		halo.position.y = 1.26 + sin(h.m.time * 3.0) * 0.03
	# (the weapon's pose, recoil and melee swings are HunterAnim's too)
	# cloaked: allies see a shimmer, enemies see nothing unless very close
	var lp: Ent = h.m.local_player()
	var see := true
	if h.cloak_t > 0.0:
		if lp and lp.team != h.team:
			see = lp.flat_dist(h) < 2.2 and int(h.m.time * 10.0) % 3 == 0
		else:
			see = int(h.m.time * 14.0) % 3 != 0
	h.model.visible = see and not HunterWisp.hides(h)  # a critter or a Wisp stands in
	ShieldLook.tick(h)
	SideRings.tick(h)
	BodyTell.tick(h, delta)
	var ring := h.model.get_node("TeamRing") as MeshInstance3D
	ring.visible = not h.downed
	h._render_balloon(delta)
	Oomph.render_hit(h, delta)
	if (h.drink_t > 0.0 or h.kit_t > 0.0 or h.box_reviving()) and h.visible and see:
		h.vuln_fx_t -= delta
		if h.vuln_fx_t <= 0.0:
			h.vuln_fx_t = 0.22
			h.m.fx.burst(h.pos + Vector3(0, 2.05, 0), Color("ff6a4a"), 3, 1.2, 0.3, -1.0, 0.8)
