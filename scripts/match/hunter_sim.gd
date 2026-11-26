class_name HunterSim
extends RefCounted
## A Hunter's per-step simulation: the control step (sim) and the physics step (_physics) that moves, falls,
## lands and rides.


static func sim(h: Hunter, dt: float) -> void:
	if dt <= 0.0:
		h.prev = h.pos  # a far, calm bot's off step (SimLod)
		return
	h.prev = h.pos
	h.abyss_sfx.tick(h, dt)
	if h.out or h.extracted:
		if not h.merge_st.is_empty():
			KinMerge.end(h, "broken")  # (eliminated or extracted mid-merge: the form goes with you)
		return
	if h.riding:
		# aboard the skyship: you go where it goes until you jump
		if h.remote:
			h.net_follow(dt)
		else:
			if h.rocket:
				h.pos = h.rocket.pos
			else:
				SkyDeck.hold(h)  # on the deck at your squad slot (still, facing the bow)
			h.gate_ranks()  # a press on a locked ability still spends a point
			if h.ctrl == "local" and h.inp["jump"] and not h.m.skydrop.detach(h):
				h.m.ship_jump(h)
			h.glide_btn_held = h.inp.get("glide_btn", false)  # a glide key held aboard is no press out there
			for k in [
				"jump",
				"dash",
				"sig",
				"util1",
				"util2",
				"util3",
				"util4",
				"util5",
				"util6",
				"ult",
				"fire",
				"skill",
				"swap"
			]:
				h.inp[k] = false
		return
	h.tick_status(dt)
	if h.grounded:
		h.air_peak = h.pos.y
	HunterCooldowns.tick(h, dt)
	if h.shield_t > 0.0:
		h.shield_t -= dt
		if h.shield_t <= 0.0:
			h.shield = 0.0
			h.shield_kind = ""
	h.dash.tick(dt, h.max_dashes(), h.dash_regen() if h.dash.charges < h.max_dashes() else 1.0)
	h._refresh_kin_stats()
	var regen := h.owner_stat("regen") + h.kin_pt("owner_regen")
	if regen > 0.0 and not h.downed and h.hp < h.max_hp:
		h.hp = minf(h.max_hp, h.hp + regen * dt * (1.0 - h.blight_k if h.blight_t > 0.0 else 1.0))
	KinRegen.owner_shield_tick(h, dt)
	if h.is_local():
		WarnSfx.low_hp(h, dt)
	if h.owner_stat("dodge_regen") >= 0.99:
		h.dashes = h.max_dashes()
	for bk in h.kbuffs.keys():
		h.kbuffs[bk][1] = float(h.kbuffs[bk][1]) - dt
		if float(h.kbuffs[bk][1]) <= 0.0:
			h.kbuffs.erase(bk)
	if h.grounded:
		h.air_jumps = 0
		h.air_dashed = false
	# shots spread more while you move, jump or have just dashed, and settle when you stand still
	if not h.remote:
		h.crouch = (
			bool(h.inp.get("crouch", false))
			and h.grounded
			and not h.downed
			and h.roll_t <= 0.0
			and not h.gliding
			and not h.dropping
			and not h.riding
			and h.charge.is_empty()
		)
		h.scout = bool(h.inp.get("scout", false)) and not h.downed and not h.out and not h.dropping and not h.riding
	var want_bloom := -0.3 if h.crouch else 0.0
	if not h.grounded:
		want_bloom = 1.0
	elif Vector2(h.vel.x, h.vel.z).length() > 1.5 and not h.crouch:
		want_bloom = 0.45
	if h.roll_t > 0.0:
		want_bloom = 1.4
	h.bloom = lerpf(h.bloom, want_bloom, 1.0 - exp(-(10.0 if want_bloom > h.bloom else 4.0) * dt))
	h.glider_snd.tick(h)
	HoverHum.tick(h)
	h.abyss_snd.tick(h)
	if h.ak:
		h.ak.sound_tick(dt)
	if h.remote:
		h.net_follow(dt)
		return
	if not h.downed and not h.dropping:
		Bond.passive(h, dt)
	h.swap_cd = maxf(0.0, h.swap_cd - dt)
	KinMerge.tick(h, dt)
	h.idle_fire += dt
	if h.downed:
		# your other kin comes out of the satchel to pick you up if the active one can't
		if h.kin and (h.kin as Kin).state == "downed" and h.kin2 and (h.kin2 as Kin).hp > 0.0:
			h.swap_kin(true)
		# a wisp doesn't bleed out: it's lost to enemy stomps, a finish, or more damage
		if h.down_hp <= 0.0:
			h.m.eliminate(h, h.last_hit_by, "finished")
			return
	# bringing a teammate back at their deathbox: no attacks, and moving breaks it
	if h.box_reviving():
		BoxRevive.guard_inputs(h)
	# mid-stomp you're committed: none of your own buttons do anything until it ends
	if not h.stomp.is_empty():
		for kk in [
			"dash",
			"jump",
			"sig",
			"skill",
			"sec",
			"ult",
			"swap",
			"util1",
			"util2",
			"util3",
			"util4",
			"util5",
			"util6",
			"gear1",
			"gear2",
			"fire",
			"throw",
			"kin_ab"
		]:
			h.inp[kk] = false
		h.inp["move"] = Vector2.ZERO
	# inputs
	AirLimits.fold_at_touchdown(h, dt)
	AirLimits.gate_drop(h)  # the opening drop: steering only (item 162)
	KinDowned.commit(h)  # carrying your Boki: Shift or interact puts it down; no jump, glide or firing
	if h.ak:
		h.ak.gate_inputs()  # a kit's lock-out (Cinder's Flue Flight: only E)
	# gloves need no point: Gloves
	h.gate_ranks()
	BaseRecall.tick(h, dt)
	if h.base_t > 0.0:
		h.inp["fire"] = false  # channeling: no attacks while you base
	if h.ak:
		h.ak.flow.route(dt)  # presses during a dash: fire, held to its end, or cancel it (DashFlow)
	if h.inp["dash"]:
		h.do_dash()
	if h.dash_buf > 0.0 and h.roll_t <= 0.0 and h.grap.is_empty() and h.pad.is_empty() and not h.inp["dash"]:
		h.dash_buf = 0.0
		h.do_dash()
	if h.inp["jump"]:
		h.do_jump()
	if h.runner:
		h.runner.rate = 1.0 + h.gear_stat("cdr")
		h.runner.tick(dt)
	var cdr := h.gear_stat("cdr")
	if cdr > 0.0:
		h.sig_cd = maxf(0.0, h.sig_cd - dt * cdr)
	for gi in 2:
		h.gear_cd[gi] = maxf(0.0, float(h.gear_cd[gi]) - dt)
		if h.inp.get("gear%d" % (gi + 1), false):
			if h.ak and h.ak.cast_locked():
				h._ab_feedback("gear%d" % gi, "deny")
			elif (
				(h.gear[gi] as Dictionary).is_empty()
				or float(h.gear_cd[gi]) > 0.0
				or not Gear.active(String(h.gear[gi].get("id", "")))
			):
				h._ab_feedback("gear%d" % gi, "deny")
			else:
				h.m.use_gear(h, gi)
	if h.ak:
		# the archetype's kit: E utility, right click with its variants, R ultimate; the kin's own
		# ability is on its own key (C: cast from where the Boki is)
		h.ak.tick(dt)
		if h.inp["sig"]:
			h.ak.use_e()
		if h.inp["sec"]:
			h.ak.press_rmb()
		if h.inp.get("kin_ab", false) and not h.ak.cast_locked():
			h.use_boki_c()
	elif h.inp["sig"]:
		h.use_kin_ability("k1")
	if h.inp.get("kin_ab", false) and h.ak == null:
		h.use_kin_ability("k1")
	# (a kin's second ability and mid-fight kin swaps are retired from the kit; bots don't press them)
	if h.inp["sec"] and h.runner and h.runner.has_slot("utility") and h.ak == null:
		var ud: AbilityDef = h.runner.def_of("utility")
		if not ud.charge.is_empty() and h.runner.is_ready("utility") and h.abil_charge.is_empty():
			h.abil_charge = {"t": 0.0}  # a charge-up: it fires when you let go
			h.m.sfx("rail", h.pos, -14.0, 0.6)
			h.m.sfx("ab_charge", h.pos, -6.0 if h.is_local() else -13.0)
		elif ud.charge.is_empty() and h.runner.use("utility", {"level": h.ability_level("sec")}):
			h.used["utility"] = int(h.used.get("utility", 0)) + 1
			h._ab_feedback("sec", "cast")
		elif h.abil_charge.is_empty():
			h._ab_feedback("sec", "deny")
	if not h.abil_charge.is_empty():
		h._tick_charge(dt)
	for ui in UtilityBelt.SLOTS:
		if h.inp[UtilityBelt.KEYS[ui]]:
			UtilityBelt.press(h, ui)
	UtilityBelt.tick(h, dt)
	h.atk.tick_burst(dt)
	h.atk.tick_weapon(dt)
	h.swing_t = maxf(0.0, h.swing_t - dt)
	if h.inp["ult"]:
		h.use_ultimate()
	h.atk.trigger(dt)
	h.inp["kin_ab"] = false
	for k in Hunter.PRESS_KEYS:
		h.inp[k] = false
	FireTap.stepped(h)
	_physics(h, dt)
	var ad := h.aim_dir()
	var want := atan2(-ad.x, -ad.y)
	if h.roll_t > 0.0 and not (h.ak and h.ak.aims_in_dash()):
		want = atan2(-h.roll_dir.x, -h.roll_dir.y)
	if not (h.ak and h.ak.face_locked()):
		h.face = rotate_toward(h.face, want, HunterMove.turn_rate * dt)


static func _physics(h: Hunter, dt: float) -> void:
	if h.pad.size() > 0:
		h._pad_fly(dt)
		return
	if h.grap.size() > 0:
		h._grapple(dt)
		return
	var mv: Vector2 = h.inp["move"] if h.stun_t <= 0.0 and h.root_t <= 0.0 else Vector2.ZERO
	var spd := HunterMove.ground_speed(h.base_speed, HunterMove.speed_bonus(h, mv), h._move_mult())
	var hv := Vector2(h.vel.x, h.vel.z)
	var cur := hv.length()
	if h.stun_t > 0.0:
		HunterMove.cut_air_dash(h)
	var in_dash := h.roll_t > 0.0  # (its last step, the hand-over to the run, included)
	HunterMove.dash_off_ledge(h)
	if h.roll_t > 0.0:
		h.roll_t -= dt
		hv = Loco.dash_hv(h.roll_dir * h.roll_speed, h.arch)  # its speed per hunter (tuning.json)
		if not h.shove.is_empty():
			h._shove_along(dt)
		if not h.dash_pass.is_empty():
			h._pass_along(dt)
		if h.roll_t <= 0.0 and h.grounded:
			var run_v := HunterMove.dash_exit(hv, spd)  # no hard stop: the run carries on (in the air, air drag)
			h.dash_rest = HunterMove.dash_rest(hv, run_v, h.roll_t + dt)
			hv = run_v
	elif h.fly_t > 0.0:
		h.fly_t -= dt
	elif h.knock_t > 0.0:
		h.knock_t -= dt
		hv = hv.move_toward(Vector2.ZERO, 6.0 * dt)
		# directional influence: hold a key to bend the knockback, never to cancel it
		if mv.length() > 0.1:
			var spd0 := hv.length()
			hv = (hv + mv * spd0 * h.knock_steer * 4.0 * dt).limit_length(spd0)
	elif h.gliding:
		# the glider keeps the speed you bring into it (a dash or a pad into a glide carries) and
		# drifts on when you let go of the keys
		var hot_k := HunterMove.overheat_speed if h.glide_fuel <= 0.001 else 1.0
		var gs := HunterMove.glide_cruise * hot_k * (1.0 + h.gear_stat("glide_speed"))
		var carry := Loco.glide_carry(h.arch) * (1.0 + h.gear_stat("glide_speed"))
		if h.loco.since > 0.0:  # the step the glider opens keeps your velocity exactly (item 8)
			var base := h.glide_lift.unswoop(hv)  # the swoop rides on top of the glide's steering
			base = (
				h.glide_dive.steer(base, mv * gs, gs, dt)
				if h.glide_dive.on
				else Loco.glide_step(base, mv * gs, gs, carry, dt)
			)
			hv = h.glide_lift.reswoop(base)
		if h.dropping:
			# the drop goes where you point and stops when you let go: no fixed heading to circle on
			hv = DropFeel.steer(Vector2(h.vel.x, h.vel.z), mv, h.diving, dt)
		# wind roads carry you along (either way), updrafts lift you
		h.in_current = false
		if not h.dropping:
			var wd: Dictionary = h.m.world.wind_at(h.pos)
			if not wd.is_empty():
				h.in_current = true
				var wdir: Vector3 = wd["dir"]
				var w2 := Vector2(wdir.x, wdir.z).normalized()
				if hv.dot(w2) < 0.0:
					w2 = -w2
				hv = hv.lerp(w2 * 14.0, 1.0 - exp(-2.5 * dt))
				h.vel.y = lerpf(h.vel.y, clampf((float(wd["y"]) - h.pos.y) * 2.5, -3.0, 6.0), 1.0 - exp(-4.0 * dt))
			var up: Dictionary = h.m.world.updraft_at(h.pos)
			if not up.is_empty():
				h.in_current = true
				h.vel.y = move_toward(h.vel.y, 9.0, 45.0 * dt)  # grabs you harder
	else:
		# near-instant on the ground (and in a kit's hover); a jump keeps its run-up
		if h.grounded or (h.ak != null and h.ak.hovering()):
			var grip: float = h.m.ground_grip(h.pos, h)  # ice in a frost region: you skid instead of stopping
			if (mv * spd).length() >= 0.001:
				var wv := HunterMove.along_wall(mv * spd, h.slide_n)  # walk along the wall you touch
				var bv := HunterMove.along_wall(hv, h.slide_n)  # the body's into-wall speed dropped too
				hv = Loco.accel_to(bv, wv, h.ground_accel * grip, 0.0, HunterMove.brake_rate(hv.length()) * grip, dt)
			else:
				hv = HunterMove.brake(hv, grip, dt)
		elif not h.lfloat.is_empty():
			hv = Loco.accel_to(hv, mv * spd, Hunter.AIR_ACCEL, HunterFeel.air_decel, HunterFeel.air_overspeed, dt)
		else:
			hv = Loco.air_step(hv, mv, spd, dt)  # strong WASD air control, the farm's too
	hv = h.dash_glide.step(h, Vector2(h.vel.x, h.vel.z), hv, dt)
	hv = MantleCarry.step(h, hv, dt)
	h.vel.x = hv.x
	h.vel.z = hv.y
	h.update_lip()
	h.wall_moves.carry(h, mv, dt)
	h._update_glide(dt)
	if not h.lfloat.is_empty() and h._ledge_rise(dt, mv):
		pass  # rising up a ledge's face (sets vel.y; your keys steer as in any jump)
	elif h.gliding and h.in_current:
		pass  # the current sets the height
	elif h.gliding and not h.dropping and h.below_lip:
		# below ground level over the abyss the glider lifts you hard, then brakes near the top.
		# Let go just before ground level to carry the lift up as height (feathering)
		h.vel.y = h.abyss_lift_vy(
			h.vel.y, h.lip_y - h.pos.y, dt, 1.0 if h.glide_fuel > 0.001 else HunterMove.overheat_lift
		)
		h.glide_lift.hang_t = GlideLift.HANG_T
	elif h.gliding:
		var sink := HunterMove.glide_sink
		if h.dropping:
			sink = HunterFeel.dive_fall if h.diving else HunterFeel.drop_fall
		if h.dropping:
			var vy_rate := HunterFeel.dive_vy_rate if h.diving else HunterFeel.drop_vy_rate
			h.vel.y = DropFeel.fall_vy(h.vel.y, sink, vy_rate, h.pos.y - h.ground(), dt)
		elif h.glide_dive.on:
			h.vel.y = h.glide_lift.build(h, h.glide_dive.fall_vy(h.vel.y, dt), sink)
		else:
			h.vel.y = h.glide_lift.fall_vy(h, sink, dt)  # pulled down high up, caught, swooping on a level-out
			# [footage] over the abyss a glider holds at island level instead of sinking below it,
			# so you can cross until the heat runs out
			if h.over_void() and h.vel.y < 0.0 and h.pos.y + h.vel.y * dt < h.lip_y:
				h.vel.y = minf(0.0, (h.lip_y - h.pos.y) / dt)
	elif MergeKit.rising(h):
		h.vel.y = MergeKit.rise_vy(h)  # the ultimate's climb (Thunderhead)
	elif h.roll_t > 0.0 and not h.grounded and not h.dropping and not h.roll_falls:
		h.vel.y = h.ak.dash_vy(dt) if h.ak else 0.0  # an air dash holds your height (a skate sinks)
	elif not h.grounded:
		HunterMove.fall(h, dt)
	# a person walks straight off an island's edge and falls (then the glider and the abyss rules
	# take over); only bots keep an edge guard (a walk only: a shove still takes them over)
	var guard: bool = (
		h.ctrl == "bot"
		and h.grounded
		and h.roll_t <= 0.0
		and h.knock_t <= 0.0
		and h.m.time - h.kb_t > 0.6
		and hv.length() <= spd * 1.25
	)
	# horizontal with walls; mantle onto ledges you run or fall into
	var x0 := h.pos.x
	var z0 := h.pos.z
	var pre_v := Vector2(h.vel.x, h.vel.z)
	h.wall_hit_v = Vector2.ZERO
	var step_up := 0.0
	# rocks and trees: slide round them. Where you're heading is pushed straight out of any blocker
	# it overlaps, and the part of your speed going into it is dropped (no bounce, no catch on a
	# corner); the axis moves below then only meet terrain, edges and walls.
	StoneStand.mover = h  # (rocks: only their caster climbs them)
	if not h.grounded and h.spirit_t <= 0.0:
		# sunk past a prop's top while beside it (a glide coming down): out of its side first, or the axis
		# moves below meet the prop around the body and stop the speed along its face too
		var out_of: Vector2 = h.m.world.push_out_blocks(h.pos.x, h.pos.z, h.r, h.pos.y)
		h.pos.x = out_of.x
		h.pos.z = out_of.y
	var tgt := Vector2(h.pos.x + h.vel.x * dt, h.pos.z + h.vel.z * dt) + h.dash_rest
	h.dash_rest = Vector2.ZERO
	if h.spirit_t <= 0.0 and tgt.distance_to(Vector2(h.pos.x, h.pos.z)) > 2.0 * Swept.STEP:
		var stop := Swept.clip(h.m.world, h.pos, Vector3(tgt.x, h.pos.y, tgt.y))  # a step longer than a block is thick
		tgt = Vector2(stop.x, stop.z)
	var pw := Vector3(tgt.x, tgt.y, 0.0)
	if h.spirit_t <= 0.0:
		pw = HunterMove.push_out_walls(h, h.m.world.push_out_blocks(tgt.x, tgt.y, h.r, h.pos.y))
	var po := Vector2(pw.x, pw.y)
	var block_n := Vector2.ZERO  # out of the rock you met this step (its face's normal)
	var rock_b := 0.0  # ...and its top, standing in for occupy()'s answer below
	if po.distance_squared_to(tgt) > 1e-10:
		block_n = (po - tgt).normalized()
		rock_b = (
			pw.z
			if pw.z > 0.0
			else h.m.world.ground_at(tgt.x - block_n.x * h.r * 0.7, tgt.y - block_n.y * h.r * 0.7) + World.BLOCK_H
		)
		var hvb := Vector2(h.vel.x, h.vel.z)
		var into := hvb.dot(block_n)
		if into < 0.0:
			hvb -= block_n * into
			h.vel.x = hvb.x
			h.vel.z = hvb.y
		tgt = po
	var nx := tgt.x
	var b1: float = h._occ(nx, h.pos.z, guard)
	if b1 == 0.0:
		h.pos.x = nx
	elif h.grounded and b1 > 0.0 and b1 - h.pos.y <= World.LEVEL + 0.05:
		step_up = b1
	elif b1 > 0.0 or b1 == -1.0:
		h.vel.x = 0.0 if b1 == -1.0 else WallMoves.stopped(h, h.vel.x)
	var nz := tgt.y
	var b2: float = h._occ(h.pos.x, nz, guard)
	if b2 == 0.0:
		h.pos.z = nz
	elif h.grounded and b2 > 0.0 and b2 - h.pos.y <= World.LEVEL + 0.05:
		step_up = maxf(step_up, b2)
	elif b2 > 0.0 or b2 == -1.0:
		h.vel.z = 0.0 if b2 == -1.0 else WallMoves.stopped(h, h.vel.z)
	if step_up > 0.0 and mv.length() > 0.3:
		# walking into a single terrace steps you up it smoothly, no hop
		h.pos.y = step_up
		h.prev.y = h.pos.y
		var fw := mv.normalized() * spd * dt
		if h._occ(h.pos.x + fw.x, h.pos.z + fw.y, guard) == 0.0:
			h.pos.x += fw.x
			h.pos.z += fw.y
	elif step_up == 0.0 and HunterMove.caught(in_dash, b1, b2) and (hv.length() > 1.0 or mv.length() > 0.3):
		# caught on a corner: slip sideways around it rather than sticking (the keys' own pull counts
		# when the corner has already eaten the speed: running at a wall corner used to crawl past it)
		var moved := Vector2(h.pos.x - x0, h.pos.z - z0).length()
		var want := maxf(hv.length(), spd * mv.length()) * dt
		if moved < want * 0.35:
			var dn := (hv if hv.length() > 1.0 else mv).normalized()
			# (try first the side that leads away from what stopped you, never round toward it)
			var wn_x := pre_v.x if b1 > 0.0 else 0.0
			var wn_y := pre_v.y if b2 > 0.0 else 0.0
			var wn := -Vector2(wn_x, wn_y)
			var sides := [Vector2(-dn.y, dn.x), Vector2(dn.y, -dn.x)]
			if wn.dot(sides[1]) > wn.dot(sides[0]):
				sides.reverse()
			var here := Vector2(h.pos.x, h.pos.z)
			var tries := []
			for side: Vector2 in sides:
				tries.append(here + (side * 0.8 + dn * 0.4) * want)
			# (last: round a terrace corner neither side clears, both its faces met at once)
			tries.append(BodySlip.round_corner(h.m.world, here, dn * want, h.r, h.pos.y))
			for to: Vector2 in tries:
				if h._occ(to.x, to.y, guard) == 0.0:
					h.pos.x = to.x
					h.pos.z = to.y
					break
	if (b1 > 0.0 or b2 > 0.0) and step_up == 0.0 and h.spirit_t <= 0.0 and h._occ(h.pos.x, h.pos.z, false) > 0.0:
		var out_to := BodySlip.eject(h.m.world, h.pos.x, h.pos.z, h.r, h.pos.y)  # inside a wall or prop: out of it
		h.pos.x = out_to.x
		h.pos.z = out_to.y
	# a safety net: pushing to move for a second without going anywhere means something has us
	# wedged, so step out to the nearest open ground
	if h.grounded and mv.length() > 0.3 and h.stun_t <= 0.0 and h.root_t <= 0.0 and not h.remote and h.grap.is_empty():
		if Vector2(h.pos.x - x0, h.pos.z - z0).length() < 0.004 and h._boxed_in():
			h.wedged_t += dt
			if h.wedged_t > 0.9:
				h.wedged_t = 0.0
				var free: Vector3 = h.m.world.free_spot_near(h.pos, [], 1.0, h.hull_r(), 2.5)
				if free.distance_to(h.pos) > 0.05 and absf(free.y - h.pos.y) < 1.0:
					h.pos = Vector3(free.x, free.y, free.z)
					h.m.fx.dust(h.pos, 4)
		else:
			h.wedged_t = 0.0
	var blk := maxf(maxf(b1, b2), rock_b)
	# (a rock you slid along counts as a wall you hit, with the part of your speed that went into it)
	var rock_v := block_n * minf(0.0, pre_v.dot(block_n)) if rock_b > 0.0 else Vector2.ZERO
	if b1 > 0.0 or b2 > 0.0:
		var hit_x := pre_v.x if b1 > 0.0 else 0.0
		var hit_y := pre_v.y if b2 > 0.0 else 0.0
		h.wall_hit_v = Vector2(hit_x, hit_y)
	elif rock_v.length() > 0.01:
		h.wall_hit_v = rock_v
	var slide_x := -signf(pre_v.x) if b1 > 0.0 else 0.0
	var slide_y := -signf(pre_v.y) if b2 > 0.0 else 0.0
	var hit_n := Vector2(slide_x, slide_y).normalized() if (b1 > 0.0 or b2 > 0.0) else block_n
	h.slide_n = hit_n if h.grounded and step_up == 0.0 else Vector2.ZERO
	if (b1 > 0.0 or b2 > 0.0 or rock_v.length() > 0.01) and blk > h.pos.y + 0.6:
		# against a wall: in the air you can kick off it; knocked into it hard, you're stunned
		if not h.grounded:
			h.wall_touch_t = 0.2
			h.wall_n = hit_n
			h.wall_moves.hit(h, pre_v, blk)
		if (
			h.m.time - h.kb_t < 0.6
			and pre_v.length() > 8.0
			and h.wslam_t <= 0.0
			and not h.remote
			and KnockWall.tall(h.m, h, blk)
		):
			h.wslam_t = 1.2
			var st := maxf(0.9, h.wallstun)
			h.wallstun = 0.0
			h.stun_t = maxf(h.stun_t, st)
			h.m.on_wall_slam(h, pre_v.normalized())
			h.hurt(10.0, h.last_hit_by, {"src": "wall"})
	if h.grounded:
		h.wall_moves.land()
		h.glide_lift.hang_t = 0.0
	h.wall_touch_t = maxf(0.0, h.wall_touch_t - dt)
	h.wslam_t = maxf(0.0, h.wslam_t - dt)
	# rocks, trees and walls are walls: no hop onto them (item 151; their tops were never ground, so a hop left
	# you inside the clump). Terrain ledges are the ledge rise's (_ledge_rise).
	StoneStand.climb(h, maxf(maxf(b1, b2), pw.z))  # the caster walking into her own rock rises onto it
	StoneStand.mover = null
	var g := h.ground()
	if h.spirit_t > 0.0 and g > h.pos.y + World.STEP:
		# Phase Walk into a ledge face: she climbs it (no wall stops her), and walking off the top drops her
		g = minf(g, h.pos.y + HunterFeel.spirit_climb * dt)
		h.grounded = true
		h.vel.y = 0.0
	# m of drop kept on foot (stairs: the slope)
	var keep: float = 0.05 + h.m.world.stair_slope(x0, z0, h.pos.x, h.pos.z)
	if h.grounded and g < h.pos.y - keep:
		h.grounded = false
		h.vel.y = minf(h.vel.y, 0.0)
		h.coyote = HunterMove.coyote_s
		h.roll_falls = h.roll_t > 0.0 and h.move_kind == "dash"
	if not h.grounded:
		var fv := h.vel.y
		h.pos.y += h.vel.y * dt
		h.air_peak = maxf(h.air_peak, h.pos.y)
		if g > World.VOID + 1.0 and h.vel.y <= 0.0 and h.pos.y <= g and h.pos.y > g - 1.25:
			h.pos.y = g
			h.vel.y = 0.0
			h.grounded = true
			h.fly_t = 0.0
			h._skyfall(h.air_peak - g, fv)
			h.air_peak = g
			if h.gliding:
				h.gliding = false
				h.m.fx.dust(h.pos, 5)
			var was_drop := h.dropping  # the drop's own landing has its feedback (Match.on_drop_landed)
			if h.dropping:
				h.dropping = false
				h.diving = false
				h.m.on_drop_landed(h)
			if h.shot_down:
				GlideSpike.land(h)
			if fv < -11.0 or cur > spd * 1.3:
				h.m.fx.dust(h.pos, 6)
				h.squash = 0.15
				h.land_t = 0.2
				h.m.sfx("land", h.pos, -10.0)
			elif fv < -4.0 and not was_drop:
				# every real landing reads: a brief squash by how fast you came down, a puff
				# and a soft thud; no lockout, you keep moving the same step
				h.squash = maxf(h.squash, clampf(-fv / 60.0, 0.07, 0.16))
				h.m.fx.dust(h.pos, 2 if fv > -8.0 else 4)
				var land_db := -16.0 if fv > -8.0 else -12.0
				h.m.sfx("land", h.pos, land_db + (0.0 if h.is_local() else -6.0))
			if fv < -17.0:
				# a long drop lands hard: a thud, a puff of dust and a short stagger
				h.m.fx.dust(h.pos, 12)
				h.squash = 0.25
				h.land_t = 0.32
			if h.jump_buf > 0.0:
				h.jump_buf = 0.0
				h.vel.y = Hunter.JUMP_V
				h.grounded = false
	else:
		StoneStand.stand(h, g)
	if h.grounded:
		h.last_gy = h.pos.y
		if int(h.m.time * 10.0) != int((h.m.time - dt) * 10.0) and not h.dropping:
			var w: World = h.m.world
			if not (
				w.is_void(h.pos.x + 1.4, h.pos.z)
				or w.is_void(h.pos.x - 1.4, h.pos.z)
				or w.is_void(h.pos.x, h.pos.z + 1.4)
				or w.is_void(h.pos.x, h.pos.z - 1.4)
			):
				h.safe_pos = h.pos
	h._unclip()
	h._try_ledge_grab(dt)
	h.moves.settle(dt)
	if h.is_local():
		Loco.report(h.loco, Vector2(h.vel.x, h.vel.z), h.vel.y, HunterMove.glide_cruise if h.gliding else spd)
	if h._in_abyss():
		h.fall_out()
