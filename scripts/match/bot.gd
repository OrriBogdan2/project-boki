class_name Bot
extends RefCounted
## Bot hunters. They fight, farm monsters, open chests, catch kin, revive teammates and head for exits
## (call a skiff and hold the dock, charge an uplink, or slip through a hatch with a key), and the
## scrappier ones go and crash a rival's loud exit.

func new_mind(rng: RandomNumberGenerator, skill: float, diff := {}) -> Dictionary:
	return {"skill": clampf(skill + rng.randf_range(-0.1, 0.1), 0.15, 1.0), "diff": diff, "react_t": 0.0, "seen": null, "think": 0.0, "tgt": null, "goal": Vector3.INF,
		"goal_kind": "", "strafe": 1.0 if rng.randf() < 0.5 else -1.0, "strafe_t": 0.0, "dash_cd": rng.randf_range(1, 3),
		"jump_cd": rng.randf_range(2, 5), "throw_cd": rng.randf_range(1.5, 4), "aim_err": Vector2.ZERO, "hurt_hp": 0.0,
		"wander": Vector3.INF, "stuck": 0.0, "last_pos": Vector3.ZERO}

const ARRIVE_R := 1.5          # bots ease off and stop turning this close to where they're going
const GOAL_KEEP := 4.0         # metres of extra reach for a goal we're already heading to
const GOAL_STICK := 5.0        # seconds a bot sticks to a goal before it may flip back to the last one
const LAND_SPREAD := 16.0      # metres: another squad landing this close counts as a crowded spot
const FRESH_T := 20.0          # seconds after landing a hunter is left alone unless they start it

## How many hunters of other squads are coming down (or standing) within r of p: where they mean to
## land while riding or gliding in, where they are once down. The local player counts double.
static func crowd_at(m: Match, h: Hunter, p: Vector3, r: float) -> int:
	var n := 0
	for o in m.hunters:
		if o == h or o.team == h.team or o.out:
			continue
		var q: Vector3 = o.ai.get("land", o.pos) if (o.riding or o.dropping) and o.ai.has("land") else o.pos
		if Vector2(q.x - p.x, q.z - p.z).length() < r:
			n += 2 if o == m.player and o.ctrl == "local" else 1
	return n

## Just landed and hasn't started anything: bots leave them be for FRESH_T (no third-partying
## someone the moment they touch down); whoever they hit can still hit back (provoked, in _choose).
static func fresh(m: Match, o: Ent) -> bool:
	return o is Hunter and ((o as Hunter).dropping or m.time - float(o.get_meta("landed_t", -99.0)) < float(m.opts.get("fresh_t", FRESH_T)))

## Goals a bot holds its ground for: it never bases away to a teammate from these.
const STAY_GOALS := ["yard", "board", "lift", "lair_dial", "lair_fight", "lair_camp", "lair_lever", "box", "beacon"]
const URGENT_GOALS := ["revive", "boki", "box", "beacon", "hum", "yard", "board", "lift", "lair_fight", "lair_escape", "lair_lever", "lair_updraft"]

## A bot this far from the local player, with no target and nothing urgent on (a revive, a lair, an exit),
## decides every FAR_EVERY sim steps (20 Hz) instead of every step, with the skipped time added in; its
## last inputs carry on in between. A big match has most of its bots roaming far away: item 94, script
## time grew with the Hunter count. (Fights and revives stay every step: at 20 Hz they turned in place.)
const FAR_M := 45.0            # m from the local player
const FAR_EVERY := 3           # sim steps per decision when that far

func tick(m: Match, h: Hunter, dt: float) -> void:
	var a := h.ai
	var acc := float(a.get("far_dt", 0.0)) + dt
	var me := m.player
	var busy: bool = a.get("tgt") != null or String(a.get("goal_kind", "")) in URGENT_GOALS
	if me != null and not me.out and not busy and h.flat_dist(me) > FAR_M and acc < dt * FAR_EVERY - dt * 0.5:
		a["far_dt"] = acc
		return
	a["far_dt"] = 0.0
	think(m, h, acc)

func think(m: Match, h: Hunter, dt: float) -> void:
	var a := h.ai
	a["think"] -= dt
	a["dash_cd"] -= dt; a["jump_cd"] -= dt; a["throw_cd"] -= dt; a["strafe_t"] -= dt
	if float(a.get("hold", 0.0)) > 0.0:
		a["hold"] = float(a["hold"]) - dt
		h.inp["sec_hold"] = float(a["hold"]) > 0.0
	var inp := h.inp
	inp["fire"] = false
	inp["interact"] = false
	if h.downed:
		_crawl(m, h)
		return
	if h.dropping:
		# steer the opening glide toward the chosen landing spot
		var land: Vector3 = a.get("land", h.pos)
		var to := Vector2(land.x - h.pos.x, land.z - h.pos.z)
		# too far to glide to from this height: settle for the closest island spot in reach
		var reach := maxf(0.0, (h.pos.y + 1.0) / Hunter.DROP_FALL * Hunter.DROP_SPEED)
		if to.length() > reach * 0.85 and not a.get("retarget", false):
			a["retarget"] = true
			var best := land; var bd := 1e9
			for sp in m.world.spawns + m.world.portal_spots:
				var d := Vector2(sp.x - h.pos.x, sp.z - h.pos.z).length()
				# (and away from where other squads are coming down: everyone falling short used to
				# pick the same nearest spot and the opening was a pile-up)
				var score := (d if d < reach * 0.8 else d + 1000.0) + crowd_at(m, h, sp, LAND_SPREAD) * 30.0
				if score < bd: bd = score; best = sp
			a["land"] = best
			land = best
			to = Vector2(land.x - h.pos.x, land.z - h.pos.z)
		inp["move"] = to.normalized() if to.length() > 0.6 else Vector2.ZERO
		return
	# the sky train's horn: off the rails before it gets here
	if m.skytrain and m.skytrain.eta(h) < SkyTrain.HORN_LEAD + 0.5:
		inp["move"] = m.skytrain.step_off_dir(h)
		return
	if a["think"] <= 0.0:
		a["think"] = randf_range(0.12, 0.3) / (0.6 + a["skill"])
		_choose(m, h)
	# crossing to another island on a glide route: run off the edge, jump, open the glider at the
	# top of the jump and steer for the landing (through any rings on the way)
	if a.has("cross"):
		var L: Dictionary = a["cross"]
		var land: Vector3 = L["land"]
		var tol := Vector2(land.x - h.pos.x, land.z - h.pos.z)
		a["cross_t"] = float(a.get("cross_t", 12.0)) - dt
		if (h.grounded and m.world.island_of(h.pos.x, h.pos.z) == int(L["to"])) or float(a["cross_t"]) <= 0.0:
			a.erase("cross"); a.erase("cross_t")
		# (gives up only well under the landing: dipping under the far lip is normal on a climb, the glider's
		# lift under the lip carries it up; at 1.2 m a bot bailed mid-glide and never crossed a climbing gap)
		elif not h.grounded and a.get("cross_go", false) and not (m.world.is_void(h.pos.x, h.pos.z) and h.pos.y < land.y - 4.0 and h.vel.y < 0.0):
			inp["move"] = tol.normalized()
			# over the landing: fold the glider and drop onto it
			inp["glide"] = tol.length() > 1.6 or m.world.is_void(h.pos.x, h.pos.z)
			# (only to open the glider: a press near the ground buffers a jump, and over the landing
			# that bounced the bot on the spot every time it touched down, never counting as landed)
			if inp["glide"] and not h.gliding and h.vel.y < 1.0 and h.can_glide():
				inp["jump"] = true
			return
		elif h.grounded and h.flat_dist(L["take"]) < 0.9 and h.glide_fuel > 0.6:
			inp["move"] = tol.normalized()
			inp["jump"] = true
			a["cross_go"] = true
			return
		else:
			a["cross_go"] = false
	# a downed squadmate comes first: go and pick them up unless a rival is right on top of us
	var rv := _revive_plan(m, h)
	if not rv.is_empty() and rv.has("danger"):
		a["tgt"] = rv["danger"]
	var tgt: Ent = a["tgt"]
	var move := Vector2.ZERO
	var df: Dictionary = a.get("diff", {})
	# a new target takes a beat to react to (much longer on easy), so you get the first shot
	if tgt != a.get("seen"):
		a["seen"] = tgt
		a["react_t"] = float(df.get("react", 0.3)) * randf_range(0.8, 1.3) * (1.6 if tgt is Hunter else 1.0)
	a["react_t"] = float(a.get("react_t", 0.0)) - dt
	# ---- a decoy: the rival vanished and left a copy behind; bots keep shooting the copy
	if tgt is Hunter and (tgt as Hunter).cloak_t > 0.0 and m.verbs:
		var dc: Dictionary = m.verbs.decoy_of(tgt)
		if not dc.is_empty() and h.flat_dist(dc["pos"]) < float(h.wpn["range"]) + 1.0:
			var dp: Vector3 = dc["pos"]
			inp["aim"] = dp + Vector3(0, 0.9, 0)
			inp["aim_y"] = dp.y
			inp["fire"] = true
			inp["move"] = Vector2.ZERO
			return
	# ---- combat
	var finishing: bool = tgt is Hunter and tgt.downed and not tgt.out
	if tgt and not tgt.dead and tgt.hittable() and (finishing or not (tgt is Hunter and not tgt.targetable())):
		var d := h.flat_dist(tgt)
		var to := h.dir_to(tgt)
		var pref: float = {"light": 4.5, "medium": 7.0, "heavy": 5.5}[h.cls]
		if h.wid == "sniper": pref = 11.0
		if h.wpn.get("melee", false): pref = 1.2
		elif h.wpn.has("pellets"): pref = 3.5
		if d > pref + 1.5:
			move = to
		elif d < pref - 2.0:
			move = -to
		if a["strafe_t"] <= 0.0:
			a["strafe_t"] = randf_range(0.6, 1.6)
			a["strafe"] = -a["strafe"]
		move += Vector2(-to.y, to.x) * a["strafe"] * 0.8
		if finishing:
			# walk onto the wisp to stomp it, and finish it
			move = to if d > 0.7 else Vector2.ZERO
			inp["interact"] = d < 1.5
		# aim with lead and some error that shrinks with skill
		var lead: Vector2 = Vector2(tgt.vel.x, tgt.vel.z) * (d / float(h.wpn["speed"])) * a["skill"]
		# the aim drifts smoothly around the target instead of jittering shot to shot
		a["aim_t"] = float(a.get("aim_t", 0.0)) - dt
		if a["aim_t"] <= 0.0:
			a["aim_t"] = randf_range(0.7, 1.3)
			a["aim_goal"] = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (1.15 - a["skill"]) * 1.6
		a["aim_err"] = (a["aim_err"] as Vector2).lerp(a.get("aim_goal", Vector2.ZERO), 1.0 - exp(-3.0 * dt))
		var aim: Vector2 = Vector2(tgt.pos.x, tgt.pos.z) + lead + a["aim_err"]
		inp["aim"] = Vector3(aim.x, tgt.hit_y() + 0.9, aim.y)
		inp["aim_y"] = tgt.hit_y()      # someone below a lip: their balloon, not their body
		var los := can_hit(m, h, tgt)
		# fast guns fire in bursts with a beat between them (to reposition); slow ones on cooldown
		a["burst"] = float(a.get("burst", 0.0)) - dt
		# fast guns fire in bursts; on easier bots the pauses between them are longer
		var duty := float(df.get("fire", 0.8))
		if a["burst"] < -randf_range(0.35, 0.6) / maxf(0.25, duty) * (1.0 if duty >= 0.99 else 1.4):
			a["burst"] = randf_range(0.7, 1.3) * (0.6 + 0.4 * duty)
		# (0.5: after the Oct 31 weapon retune a burst rifle or greatsword still counts as a fast weapon
		# and keeps its pauses, so bots don't hit harder than before)
		var trig_ok: bool = float(a["react_t"]) <= 0.0 and (a["burst"] > 0.0 or ((float(h.wpn["rate"]) > 0.5 or h.wpn.has("spin_up")) and randf() < duty * dt * 8.0 + (0.0 if duty < 0.99 else 1.0)))
		if los and d < float(h.wpn["range"]) + 0.5 and trig_ok:
			inp["fire"] = true
			a["nolos_t"] = 0.0
		elif not los:
			# no clear shot: work round to one (a path, not straight into the wall), and give up on it
			# after a while rather than hopping at a ledge shooting the rock
			move = _path_dir(m, h, tgt.pos)
			a["nolos_t"] = float(a.get("nolos_t", 0.0)) + dt
			if float(a["nolos_t"]) > 2.5:
				a["nolos_t"] = 0.0
				a["ignore"] = {"e": tgt, "until": m.time + 4.0}
				a["tgt"] = null
		var abil := float(df.get("abil", 0.7))
		BotKin.fight(m, h, tgt, d, abil)       # throw, C, recall
		# holding our uplink's yard: fight from in it, don't chase the waves out (an empty yard drains)
		if String(a.get("goal_kind", "")) == "yard" and a["goal"] != Vector3.INF and h.flat_dist(a["goal"]) > 2.4:
			move = (_path_dir(m, h, a["goal"]) + move * 0.3).normalized()
		# hexed into a critter: no fighting, just scurry away until it wears off
		if Hex.active(h):
			move = -to
			inp["fire"] = false
		# defensive moves
		if h.hp < a["hurt_hp"] - 12.0 and a["dash_cd"] <= 0.0 and randf() < 0.35 + abil * 0.65:
			a["dash_cd"] = randf_range(1.2, 3.0) / (0.5 + a["skill"])
			var side: Vector2 = Vector2(-to.y, to.x) * a["strafe"]
			if _safe(m, h, side, 3.5) and _safe(m, h, side, 5.0):
				a["dash_dir"] = side
				inp["dash"] = true
		a["hurt_hp"] = h.hp
		# abilities: easier bots only look for a chance every so often
		a["abil_t"] = float(a.get("abil_t", 0.0)) - dt
		if a["abil_t"] <= 0.0 and a["react_t"] <= 0.0:
			a["abil_t"] = randf_range(0.4, 1.0) * (1.0 + (1.0 - abil) * 4.0)
			if MergeKit.is_live(h):
				MergeKit.bot_use(h)       # merged: the ultimate when foes are in range or the window is closing (its hero kit plays as usual below)
			if h.ak:
				# the archetype's kit: dash, RMB variants, E and R (each kit knows its own moments)
				h.ak.bot_use(tgt, d, los)
				if not KinCommand.class_ults(): inp["ult"] = false      # R is the Merge: BotKin decides
				if not rv.is_empty() and h.flat_dist(rv["o"]) < 6.0:
					# picking up a squadmate: no kit move that carries us off them (a Shadow Step
					# behind the rival, a Rampage, a leap, an ult chase); E and the gun still go
					inp["dash"] = false; inp["sec"] = false; inp["ult"] = false
					h.ak.bot_hold["dash"] = 0.0; h.ak.bot_hold["rmb"] = 0.0
				BotKin.merge(h, tgt, d)
			else:
				_use_sig(m, h, tgt)
				_use_sec(m, h, tgt)
			# both gloves (Q and V), each when its moment comes (hook in range, wall when shot at...)
			Gloves.bot_use(h, tgt, abil, inp, func(gdf, t): return ability_aim(m, h, gdf, t))
	else:
		a["tgt"] = null
		var goal: Vector3 = a["goal"]
		if goal != Vector3.INF:
			move = _path_dir(m, h, goal)
			# arriving: ease off over the last stretch instead of running past the spot and back (at
			# full speed a bot overshot anything closer than a stride, a dropped weapon still popping
			# in the air, say, and whipped round every few frames: it looked like it was spinning).
			# And keep looking the way we were going: no turning to face a spot under our feet.
			var gd := h.flat_dist(goal)
			if gd < ARRIVE_R and a.get("cross", {}).is_empty():
				move *= clampf(gd / ARRIVE_R, 0.2, 1.0)
			if gd >= ARRIVE_R or not a.has("aim_hold"):
				inp["aim"] = Vector3(h.pos.x + move.x * 3.0, h.pos.y + 0.9, h.pos.z + move.y * 3.0)
				a["aim_hold"] = Vector2(move.x, move.y).normalized() if move.length() > 0.05 else Vector2(sin(h.face), cos(h.face)) * -1.0
			else:
				var ah: Vector2 = a["aim_hold"]
				inp["aim"] = Vector3(h.pos.x + ah.x * 3.0, h.pos.y + 0.9, h.pos.z + ah.y * 3.0)
			inp["aim_y"] = h.pos.y
			if h.flat_dist(goal) < 1.2 and a["goal_kind"] in ["chest", "catch", "revive", "box", "dock", "uplink", "hatch", "lair_dial", "lair_lever"]:
				inp["interact"] = not h.get_meta("box_broke", false)      # a broken box revive: let go, hold again
				move = Vector2.ZERO
			elif h.flat_dist(goal) < 1.0 and a["goal_kind"] in ["beacon", "board", "yard", "lair_camp"]:
				move = Vector2.ZERO
		BotKin.upkeep(h)
		# far from the squad with nothing to fight: now and then, base to a teammate
		# (not while holding a spot: an uplink's yard, a skiff's deck, a lair, a teammate's box or a
		# beacon: basing away from a charging uplink left its yard empty to drain)
		if h.base_t <= 0.0 and h.base_cd <= 0.0 and h.grounded and randf() < dt * 0.05 and not a.has("ping_goal") \
				and not String(a.get("goal_kind", "")) in STAY_GOALS:
			var mate := m.base_target(h)
			if mate and h.flat_dist(mate) > 30.0:
				h.start_base(mate)
		if h.base_t > 0.0:
			move = Vector2.ZERO
		# (heals fold the glider now, so a bot only drinks with ground under it, never over the void
		# or mid-drop)
		var heal_ok: bool = h.grounded or (not h.gliding and not h.dropping and not h.over_void())
		if heal_ok:
			BotBelt.think(m, h, a, inp)       # tonic, armor kit and the rest of the belt (bot_belt.gd)
		# swap a fainted kin out for the other one
		if h.kin and (h.kin as Kin).state == "downed" and h.kin2 and (h.kin2 as Kin).hp > 0.0:
			inp["swap"] = true
	# ---- reviving: walk to the downed squadmate and stand on them until they're up (shooting back
	# from there if there's a clear shot). A rival right on top of us is fought, but from beside them
	# (no backing off to our usual range), unless we're still a way off.
	if not rv.is_empty() and (not rv.has("danger") or h.flat_dist(rv["o"]) < 4.0):
		move = _revive_move(m, h, rv, dt)
		a.erase("dash_dir")
		if h.base_t > 0.0: h.base_t = 0.0
		if inp.get("interact", false) and not (tgt is Hunter and (tgt as Hunter).downed): inp["interact"] = false
		if move == Vector2.ZERO and tgt == null:
			var o: Hunter = rv["o"]
			inp["aim"] = Vector3(o.pos.x, o.pos.y + 0.5, o.pos.z)
			inp["aim_y"] = o.pos.y
	else:
		a.erase("rv")
	# ---- don't walk off edges (except onto the jump pad we're heading for), and keep off other pads
	var to_pad: bool = (a.has("pad_at") and h.flat_dist(a["pad_at"]) < 2.5) or (a.has("cross") and h.flat_dist(a["cross"]["take"]) < 2.5)
	for pd in m.world.pads:
		if a.has("pad_at") and pd["pos"] == a["pad_at"]:
			continue
		var dp: float = h.flat_dist(pd["pos"])
		if dp < 1.8 and move.length() > 0.1:
			move += -h.dir_to(pd["pos"]) * (1.8 - dp) * 1.5
	a.erase("pad_at")
	move = Breakables.bot_steer(m, h, move)
	# (heading for a downed squadmate near an edge, only look as far as them)
	var look := 1.2 if rv.is_empty() else clampf(h.flat_dist(rv["o"]) - 0.2, 0.4, 1.2)
	if move.length() > 0.01:
		move = move.normalized()
		if not to_pad and not _safe(m, h, move, look):
			var alt := Vector2(-move.y, move.x)
			if _safe(m, h, alt, 1.2): move = alt
			elif _safe(m, h, -alt, 1.2): move = -alt
			else: move = -move
	# walk around rocks and walls we keep bumping into
	if a.get("detour_t", 0.0) > 0.0:
		a["detour_t"] -= dt
		var dd: Vector2 = a["detour_dir"]
		if _safe(m, h, dd, 1.2):
			move = dd
	move = _brake_at_lip(m, h, move)
	inp["move"] = move
	if StoneStand.hop_ahead(h, move):
		inp["jump"] = true      # a teammate's rock in the way: hop it (Tenzo walks up his own; a foe's stops us)
	if a.has("dash_dir"):
		inp["move"] = a["dash_dir"]
		a.erase("dash_dir")
	# recover if knocked off: jump toward the nearest ground, then glide back to it
	inp["glide"] = false
	if not h.grounded and h.over_void():
		if h.vel.y < 0.0 and h.coyote > 0.0:
			inp["jump"] = true
		var back := _nearest_ground(m, h)
		# hold the glider: below the lip it lifts you back up to ground level
		inp["glide"] = h.ai["skill"] > 0.15
		if back != Vector2.ZERO:
			inp["move"] = back
	# unstick
	if Vector2(h.pos.x - a["last_pos"].x, h.pos.z - a["last_pos"].z).length() < 0.03 and move.length() > 0.5:
		a["stuck"] += dt
		# wedged for good (landed in a gap between rocks, say): hop to the nearest open ground,
		# like a player using "I'm stuck" in the menu
		a["frozen"] = float(a.get("frozen", 0.0)) + dt
		if float(a["frozen"]) > 4.0 and not h.downed and not m.world.is_void(h.pos.x, h.pos.z):
			a["frozen"] = 0.0
			var q := m.world.free_spot_near(h.pos + Vector3(move.x, 0, move.y) * 1.5, [h.pos], 0.8, 0.5, 5.0)
			if Vector2(q.x - h.pos.x, q.z - h.pos.z).length() > 0.3:
				h.teleport(Vector3(q.x, m.world.ground_at(q.x, q.z), q.z))
				h.vel = Vector3.ZERO
		if a["stuck"] > 0.6:
			a["hops"] = int(a.get("hops", 0)) + 1
			h.ai.erase("wp")        # find a new way round next time
			if _safe(m, h, move, 2.0) and randf() < 0.5 and int(a["hops"]) <= 2:
				inp["jump"] = true
			else:
				a["detour_t"] = randf_range(0.5, 1.1)
				a["detour_dir"] = Vector2(-move.y, move.x) * (1.0 if randf() < 0.5 else -1.0)
			a["stuck"] = 0.0
	else:
		a["stuck"] = 0.0
		if Vector2(h.pos.x - a["last_pos"].x, h.pos.z - a["last_pos"].z).length() > 0.05:
			a["frozen"] = 0.0
			if Vector2(h.pos.x - a["last_pos"].x, h.pos.z - a["last_pos"].z).length() > 0.08: a["hops"] = 0
	a["last_pos"] = h.pos
	_ease_aim(h, dt)

## Turn the way a person would: when the bot isn't shooting or casting this tick, its aim swings
## round at a capped rate instead of snapping. Goals and targets that flicker (a target stepping in
## and out of reach, the aim dropping back to the walking direction for a frame) had bots whipping
## round several times a second. Shots and abilities still aim exactly where they were meant to.
const AIM_TURN := 5.0          # rad/s with nothing to fight
const AIM_TURN_FIGHT := 9.0    # rad/s with a target, between shots
const AIM_NEAR := 1.5          # m: an aim point this close says nothing about a way to face: hold the facing
func _ease_aim(h: Hunter, dt: float) -> void:
	var a := h.ai
	var inp := h.inp
	var aim3: Vector3 = inp["aim"]
	var dv := Vector2(aim3.x - h.pos.x, aim3.z - h.pos.z)
	if dv.length() < 0.05:
		return
	var want := atan2(dv.y, dv.x)
	var acting: bool = inp.get("fire", false) or inp.get("sig", false) or inp.get("sec", false) or inp.get("gear1", false) or inp.get("gear2", false) \
		or inp.get("ult", false) or inp.get("dash", false) or inp.get("interact", false)
	if acting:
		return
	# (from where the bot is facing now: Hunter.face points along (-sin, -cos))
	var cur := atan2(-cos(h.face), -sin(h.face))
	var rate := AIM_TURN_FIGHT if a.get("tgt") != null else AIM_TURN
	if dv.length() >= AIM_NEAR:
		cur += clampf(wrapf(want - cur, -PI, PI), -rate * dt, rate * dt)
	var L := maxf(dv.length(), 1.0)
	inp["aim"] = Vector3(h.pos.x + cos(cur) * L, aim3.y, h.pos.z + sin(cur) * L)

## A clear shot from where we stand: from our feet's eye height (not the top of a hop), at the lower
## of the two heights, so a ledge or a rock between us stops us firing into it.
func can_hit(m: Match, h: Hunter, tgt: Ent) -> bool:
	var base_y := h.pos.y
	if not h.grounded:
		var gy := m.world.ground_at(h.pos.x, h.pos.z)
		if gy > World.VOID + 1.0: base_y = minf(h.pos.y, gy)
	var y := minf(base_y, tgt.pos.y) + 0.9
	if tgt.pos.y - base_y > 2.4:
		return false
	# the shot has some width: the line and both its edges have to be clear (no grazing a corner)
	var side := Vector2(tgt.pos.z - h.pos.z, h.pos.x - tgt.pos.x).normalized() * 0.22
	for k in [0.0, 1.0, -1.0]:
		var o := Vector3(side.x * k, 0, side.y * k)
		if not m.world.los(Vector3(h.pos.x, base_y, h.pos.z) + o, tgt.pos + o, y):
			return false
	# and the shot itself, eye to chest, mustn't clip a lip of ground on the way (firing down off a
	# shelf at someone just below its edge: the flat check above passes, the real line hits the lip)
	var y0 := base_y + 0.95; var y1 := tgt.pos.y + 0.9
	for i in 24:
		var f := (i + 0.5) / 24.0
		if m.world.ground_at(lerpf(h.pos.x, tgt.pos.x, f), lerpf(h.pos.z, tgt.pos.z, f)) > lerpf(y0, y1, f) - 0.05:
			return false
	return true

const RV_RANGE := 70.0        # how far a bot will go for a downed squadmate
const RV_DANGER := 3.2        # a rival this close gets fought before the revive
const RV_ON := 1.1            # stand this close (the revive ring is Life.R["revive_radius"])

## The downed squadmate to go and pick up ({} for none), with "danger" set to a rival we have to
## deal with first (right on top of us, or standing on the wisp).
func _revive_plan(m: Match, h: Hunter) -> Dictionary:
	var best: Hunter = null; var bs := 1e9
	for o in m.hunters:
		if o == h or o.team != h.team or not o.downed or o.out or o.extracted:
			continue
		var d := h.flat_dist(o)
		if d > RV_RANGE or m.world.is_void(o.pos.x, o.pos.z):
			continue
		var sc := d - (8.0 if o == m.player else 0.0)
		if sc < bs: bs = sc; best = o
	if best == null:
		return {}
	var plan := {"o": best}
	# who's a threat: a rival on the wisp (blocks the revive), or anything hostile right next to us
	var dz: Ent = null; var dd := 1e9
	for st in best.get_meta("stompers", []):
		if is_instance_valid(st) and not (st as Hunter).dead and not (st as Hunter).downed:
			dz = st; dd = 0.0
	if dz == null:
		for o in m.hunters:
			if o.team == h.team or o.downed or o.out or not o.targetable() or (m.truce and m.truce.holds(h, o)):
				continue
			var d := h.flat_dist(o)
			if d < RV_DANGER and d < dd and absf(o.pos.y - h.pos.y) < 2.0:
				dz = o; dd = d
		for mb in m.mobs:
			if mb.dead or (mb is Boss and (mb as Boss).dormant):
				continue
			var d := h.flat_dist(mb)
			if d < RV_DANGER * 0.8 and d < dd and absf(mb.pos.y - h.pos.y) < 2.0 and mb.tgt == h:
				dz = mb; dd = d
	if dz:
		plan["danger"] = dz
	return plan

## Where to walk for the revive: onto them, by a path; if we stop getting closer, try another side
## of them (a reachable spot next to them), and stand still once we're on the ring.
func _revive_move(m: Match, h: Hunter, rv: Dictionary, dt: float) -> Vector2:
	var a := h.ai
	var o: Hunter = rv["o"]
	var st: Dictionary = a.get("rv", {})
	if st.get("o") != o:
		st = {"o": o, "best": 1e9, "t": 0.0, "side": -1, "spot": o.pos}
		a["rv"] = st
	var d := h.flat_dist(o)
	if d < RV_ON and absf(h.pos.y - o.pos.y) < 1.4:
		st["t"] = 0.0; st["best"] = d
		return Vector2.ZERO
	var spot: Vector3 = o.pos if int(st["side"]) < 0 else st["spot"]
	if int(st["side"]) >= 0 and spot.distance_to(o.pos) > 1.6:
		st["side"] = -1; spot = o.pos         # they crawled off: back to heading straight for them
	var ds := h.flat_dist(spot)
	if ds < float(st["best"]) - 0.25:
		st["best"] = ds; st["t"] = 0.0
	else:
		st["t"] = float(st["t"]) + dt
	if float(st["t"]) > 1.8:
		# no progress: pick the next reachable spot round them (on their level, open ground)
		st["t"] = 0.0; st["best"] = 1e9
		h.ai.erase("wp")
		for k in 8:
			var sd := (int(st["side"]) + 1 + k) % 8
			var ang := TAU * sd / 8.0 + 0.3
			for r in [0.8, 1.2]:
				var q: Vector3 = o.pos + Vector3(cos(ang), 0, sin(ang)) * r
				if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z):
					continue
				var gy := m.world.ground_at(q.x, q.z)
				if absf(gy - o.pos.y) > 1.0:
					continue
				st["side"] = sd; st["spot"] = Vector3(q.x, gy, q.z)
				break
			if int(st["side"]) == sd:
				break
		spot = st["spot"]
	if h.flat_dist(spot) < 0.35:
		return Vector2.ZERO
	return _path_dir(m, h, spot)

func _nearest_ground(m: Match, h: Hunter) -> Vector2:
	var best := Vector2.ZERO; var bd := 1e9
	for a in 16:
		var ang := TAU * a / 16.0
		var dv := Vector2(cos(ang), sin(ang))
		for r in [2.0, 4.0, 6.0, 9.0, 12.0, 16.0, 22.0, 30.0]:
			var x: float = h.pos.x + dv.x * r; var z: float = h.pos.z + dv.y * r
			# the glider's abyss lift carries you up to ground level, so higher ground counts too
			if not m.world.is_void(x, z) and not m.world.is_block(x, z) and m.world.ground_at(x, z) < h.pos.y + 4.0:
				if r < bd: bd = r; best = dv
				break
	return best

## Stopping (no keys) a Hunter coasts ~0.4 m on SUPERVIVE's walking stop (item 150). A bot that stops
## at a rim (a revive, a loot spot, the end of a path) and would coast over a drop or the void counter-
## steers instead, which brakes at the full turn rate, as a player would.
func _brake_at_lip(m: Match, h: Hunter, move: Vector2) -> Vector2:
	var hv := Vector2(h.vel.x, h.vel.z)
	if move.length() > 0.01 or not h.grounded or hv.length() < 0.5:
		return move
	var d := hv.normalized()
	var p := Vector2(h.pos.x, h.pos.z) + d * (h.r + 0.45)
	if m.world.is_void(p.x, p.y) or m.world.ground_at(p.x, p.y) < h.pos.y - World.STEP:
		return -d * 0.05
	return move

func _safe(m: Match, h: Hunter, d: Vector2, dist: float) -> bool:
	for k in [0.5, 1.0]:
		var p: Vector2 = Vector2(h.pos.x, h.pos.z) + d * dist * k
		if m.world.is_void(p.x, p.y):
			return false
	return true

func _crawl(m: Match, h: Hunter) -> void:
	var best: Hunter = null; var bd := 1e9
	for o in m.hunters:
		if o != h and o.team == h.team and not o.downed and not o.out:
			var d := h.flat_dist(o)
			if d < bd: bd = d; best = o
	var mv := Vector2.ZERO
	if best and bd > 1.2:
		mv = h.dir_to(best)
	if mv.length() > 0 and not _safe(m, h, mv, 1.0):
		mv = Vector2.ZERO
	h.inp["move"] = mv

## Right click: the weapon's utility, used when a target is in reach.
func _use_sec(m: Match, h: Hunter, tgt: Ent) -> void:
	var a := h.ai
	# holding a charge-up (Rail Charge): keep holding until it's ready, then let go
	if float(a.get("hold", 0.0)) > 0.0:
		h.inp["sec_hold"] = true
		if tgt: h.inp["aim"] = Vector3(tgt.pos.x, tgt.pos.y + 0.9, tgt.pos.z)
		return
	h.inp["sec_hold"] = false
	if tgt == null:
		return
	if h.runner and h.runner.has_slot("utility") and h.runner.is_ready("utility"):
		var ud: AbilityDef = h.runner.def_of("utility")
		var aim := ability_aim(m, h, ud, tgt)
		if tgt is Mob and (tgt as Mob).stag_open > 0.0 and h.flat_dist(tgt) < 7.0:
			aim = tgt.pos
		if aim != Vector3.INF:
			h.inp["aim"] = aim
			h.inp["sec"] = true
			if not ud.charge.is_empty():
				a["hold"] = float(ud.bot.get("hold", ud.charge.get("time", 1.0)))
				h.inp["sec_hold"] = true

## Where a bot would aim one of its abilities right now, from the ability's "bot" hint, or
## Vector3.INF if this isn't the moment:
##   in_range [min, max]  the target is in reach and in sight: aim at it
##   under_fire           a rival is shooting you: aim between you and them (walls, reflects)
##   clumped              two or more foes bunched near the target, or a rival hunter in reach
##   hurt below           low on health: at your own feet (heals, decoys)
##   gap                  the target is across the abyss within reach (bridges)
func ability_aim(m: Match, h: Hunter, def: AbilityDef, tgt: Ent) -> Vector3:
	var b: Dictionary = def.bot
	if b.is_empty() or tgt == null:
		return Vector3.INF
	var d := h.flat_dist(tgt)
	var mx := float(b.get("max", def.cast_range if def.cast_range > 0.0 else 8.0))
	var mn := float(b.get("min", 0.0))
	var sees: bool = m.world.los(h.pos, tgt.pos, h.pos.y + 0.95)
	var tp := Vector3(tgt.pos.x + tgt.vel.x * 0.15, tgt.pos.y + 0.9, tgt.pos.z + tgt.vel.z * 0.15)
	match String(b.get("when", "")):
		"in_range":
			if d >= mn and d <= mx and sees and randf() < 0.55:
				return tp
		"under_fire":
			var att = h.last_hit_by
			if att is Kin and (att as Kin).owner_h: att = (att as Kin).owner_h
			if att is Ent and is_instance_valid(att) and not att.dead and att.team != h.team and m.time - h.hurt_at < 0.6 and h.flat_dist(att) > 2.5:
				var dd: Vector2 = h.dir_to(att)
				return Vector3(h.pos.x + dd.x * 2.5, att.pos.y + 0.9, h.pos.z + dd.y * 2.5)
		"clumped":
			if d <= mx:
				var n := 0
				for f in m.foes_of(h.team):
					if f.flat_dist(tgt) < 3.0: n += 1
				if n >= 2 or (tgt is Hunter and randf() < 0.35):
					return tgt.pos
		"hurt":
			if h.hp < h.max_hp * float(b.get("below", 0.5)) and m.time - h.hurt_at < 2.0:
				return h.pos
		"gap":
			if d < 10.0 and d > 3.0:
				var mid := h.pos.lerp(tgt.pos, 0.5)
				if m.world.is_void(mid.x, mid.z) and absf(tgt.pos.y - h.pos.y) < 1.2:
					return tgt.pos
		"always":
			return tp
	return Vector3.INF

## The kin's E when it fits the moment (read from the ability's cue), and the bond ultimate (R,
## the merge) once it's full. (The kin uses its auto active on its own; this is the hunter asking.)
func _use_sig(m: Match, h: Hunter, tgt: Ent) -> void:
	var k: Kin = h.kin
	if k == null or not k.ready_to_fight() or tgt == null:
		return
	var d := h.flat_dist(tgt)
	var kd := k.flat_dist(tgt)
	for slot in ["k1"]:
		if not k.runner.is_ready(slot) or not k.slot_open(slot):
			continue
		var def := k.runner.def_of(slot)
		var go := false
		if def.from == "owner":
			var cue := def.cue.type if def.cue else ""
			match cue:
				"owner_hurt": go = h.hp < h.max_hp * float(def.cue.params.get("below", 0.5))
				"owner_falling": go = h.below_lip
				_: go = d < 9.0 and randf() < 0.3
		else:
			var reach := def.cast_range if def.cast_range > 0.0 else 7.0
			go = (kd < reach or (k.state == "shoulder" and d < 8.0)) and randf() < 0.35
			if tgt is Mob and (tgt as Mob).stag_open > 0.0 and kd < reach:
				go = true
		if go:
			h.inp["aim"] = Vector3(tgt.pos.x, tgt.pos.y, tgt.pos.z)
			h.inp["sig" if slot == "k1" else "skill"] = true
			break
	if KinMerge.can_cast(h):
		var u := KinMerge.def_for(k)
		var go_r := false
		if u:
			go_r = (d < 7.0 and tgt is Hunter) or (d < 5.0 and tgt is Mob and (tgt as Mob).max_hp > 150.0) or (h.hp < h.max_hp * 0.4 and d < 9.0)
		if go_r:
			h.inp["aim"] = Vector3(tgt.pos.x, tgt.pos.y, tgt.pos.z)
			h.inp["ult"] = true

func _choose(m: Match, h: Hunter) -> void:
	var a := h.ai
	# fight: nearest rival hunter in sight, else monsters close by
	var best: Ent = null; var bs := -1e9
	var ign: Dictionary = a.get("ignore", {})
	var ign_e = ign.get("e") if m.time < float(ign.get("until", 0.0)) else null
	for o in m.hunters:
		if o.team == h.team or not o.targetable() or o == ign_e:
			continue
		if m.truce and m.truce.holds(h, o):
			continue
		if o is Hunter and not m.can_see(h.team, o):
			continue
		var d := h.flat_dist(o)
		# early on bots farm monsters and only fight hunters who come close or shoot them
		var provoked: bool = h.last_hit_by == o or (o is Hunter and h.last_hit_by == o.kin)
		if (not provoked and fresh(m, o)) or m.demo_shielded(o):
			continue
		var reach := (13.0 if m.time > 100.0 or provoked else 8.0) * float((a.get("diff", {}) as Dictionary).get("aggro", 1.0))
		if provoked: reach = maxf(reach, 10.0)
		var bounty: bool = m.rolling != null and o.has_meta("bounty")
		if bounty: reach += 5.0        # (a rolling session: a hunter with a bounty on them is worth going after)
		if d > reach or absf(o.pos.y - h.pos.y) > 3.0:
			continue
		if not m.world.los(h.pos, o.pos, h.pos.y + 0.95) and d > 4.0:
			continue
		var s: float = 20.0 - d + (6.0 if o == a["tgt"] else 0.0) - o.hp * 0.03 + (5.0 if bounty else 0.0)
		if s > bs: bs = s; best = o
	if best == null:
		for mb in m.mobs:
			if mb.dead or mb == ign_e or (mb is Shrubling and (mb as Shrubling).ss == "disguised"): continue
			# a sleeping boss can't be hurt; an awake one is worth walking up to
			if mb is Boss and (mb as Boss).dormant: continue
			var d := h.flat_dist(mb)
			var reach := 16.0 if mb is Boss else 8.0
			if mb is Blight:
				# the Blight: fight what's coming for us (a Warden's bolts reach further); hurt and
				# with nothing to drink, step away instead (_blight_flee) unless it's right on us
				reach = 11.0 if mb.tgt == h else 7.0
				if h.hp < h.max_hp * 0.3 and h.tonics <= 0 and d > 2.5:
					continue
			if d < reach and absf(mb.pos.y - h.pos.y) < 2.0 and m.world.los(h.pos, mb.pos, h.pos.y + 0.95):
				var s := 10.0 - d
				if mb.tgt == h: s += 5.0
				if s > bs: bs = s; best = mb
	# finish off downed rivals before their kin or team picks them up
	if best == null:
		for o in m.hunters:
			if o.team != h.team and o.downed and not o.out and h.flat_dist(o) < 11.0 and m.world.los(h.pos, o.pos, h.pos.y + 0.95) and not (m.truce and m.truce.holds(h, o)):
				best = o; break
	# angry wild kin also count
	if best == null:
		for k in m.kins:
			if k.is_wild() and k.state == "wild" and not k.dead and h.flat_dist(k) < 7.0 and (k.angry_at == h or randf() < 0.5):
				best = k; break
	a["tgt"] = best
	if best:
		return
	# no fight: pick a goal
	var time_left := Rolling.bot_time_left(m, h)     # (a rolling session: this squad's own planned stay)
	var goal := Vector3.INF; var gk := ""
	for o in m.hunters:
		if o != h and o.team == h.team and o.downed and not o.out:
			goal = o.pos; gk = "revive"; break
	if goal == Vector3.INF:
		goal = BotKin.rescue_goal(h)       # a downed Boki: run into it
		if goal != Vector3.INF: gk = "boki"
	# a dead teammate: their deathbox while the soul's there, else a revive beacon
	if goal == Vector3.INF:
		for b in m.boxes:
			var o: Hunter = b["owner"]
			if o.team == h.team and o != h and Life.soul_here(m, b) and h.flat_dist(b["pos"]) < 45.0:
				goal = b["pos"]; gk = "box"; break
	if goal == Vector3.INF and m.hunters.any(func(x): return x.team == h.team and x.out and not x.gone):
		var bd := 90.0
		for bc in m.beacons:
			if bc["used"]: continue
			var d := h.flat_dist(bc["pos"])
			if d < bd: bd = d; goal = bc["pos"]; gk = "beacon"
	# hurt with the Blight close: get away from it first
	if goal == Vector3.INF and m.blight:
		var fl := _blight_flee(m, h)
		if fl != Vector3.INF:
			goal = fl; gk = "flee"
	# our squad's uplink is charging: every hunter in its yard charges it faster (and an empty yard
	# drains it), so go and hold it rather than wander off after boxes, pings or lairs (unless we're
	# sealed in a lair already)
	var holding_yard: bool = m.exits != null and String(m.exits.active_for(h.team).get("state", "")) == "charging" \
		and (m.lairs == null or m.lairs.sealed_lair(h).is_empty())
	if goal == Vector3.INF and holding_yard:
		var yg: Array = m.exits.bot_goal(h, true)
		if not yg.is_empty() and String(yg[1]) == "yard":
			goal = yg[0]; gk = "yard"
	# a rival's deathbox revive humming within earshot: go and stop it
	if goal == Vector3.INF:
		for b in m.box_hums.values():
			if int(b["team"]) != h.team and h.flat_dist(b["pos"]) < Match.HUM_RANGE:
				goal = b["pos"]; gk = "hum"; break
	# anyone else's box with something in it
	# (the range checks below reach a little further for what we're already heading to: right at
	# the edge of one, a bot used to pick it, step away, drop it, step back, every think, turning on
	# the spot each time)
	var cur: Vector3 = a["goal"]
	if goal == Vector3.INF:
		for b in m.boxes:
			if not b["empty"] and h.flat_dist(b["pos"]) < 14.0 + (GOAL_KEEP if b["pos"] == cur else 0.0) and not (b["owner"].team == h.team and Life.soul_here(m, b)):
				goal = b["pos"]; gk = "box"; break
	# a perk orb we want lying close by: walk into it
	if goal == Vector3.INF:
		var og := PerkOrbs.bot_goal(m, h, cur)
		if og != Vector3.INF:
			goal = og; gk = "orb"
	# someone asked us to follow them (a Follow me emote from a teammate or truce partner)
	if goal == Vector3.INF and a.has("follow"):
		var fw: Dictionary = a["follow"]
		var fh: Hunter = fw["h"]
		if m.time < float(fw["until"]) and is_instance_valid(fh) and not fh.out and not fh.extracted:
			if h.flat_dist(fh) > 3.0: goal = fh.pos; gk = "follow"
		else:
			a.erase("follow")
	# a squadmate pinged somewhere: go and have a look
	if goal == Vector3.INF and a.has("ping_goal"):
		var pg: Dictionary = a["ping_goal"]
		var pp: Vector3 = pg["pos"]
		if m.time < float(pg["until"]) and h.flat_dist(pp) > 3.5 and not m.world.is_void(pp.x, pp.z):
			goal = pp; gk = "ping"
			if h.base_t > 0.0: h.cancel_base()      # (a base channel would hold us still, then carry us off to a mate and drop the ping)
		else:
			a.erase("ping_goal")
	# boss lairs: a dropped Rare Egg, or (bolder bots) a lair to open and its boss to fight
	if goal == Vector3.INF and m.lairs and not m.lairs.list.is_empty() and not holding_yard:
		# heading home, as far as lairs go: late in the match, carrying a Rare Egg, or a bot that has
		# decided to leave once the match is far enough along. (The random "leave" roll below can
		# fire in the first minute; it used to cancel every lair plan right away, though the exits
		# don't act on it until 30% in, so the bot just wandered.)
		var egg_home: bool = h.pack.any(func(it): return Loot.is_rare_egg(it))
		var lair_leave: bool = time_left < 170.0 or egg_home or (a.get("leave", false) and Rolling.bot_past(m, h, 0.3))
		var lg: Array = m.lairs.bot_goal(h, lair_leave)
		if not lg.is_empty():
			goal = lg[0]; gk = String(lg[1])
	if goal == Vector3.INF and m.exits and not m.exits.list.is_empty():
		# heading home: late in the match, with a good haul, or just because
		if not a.get("leave", false) and randf() < 0.0015:
			a["leave"] = true
		# (not in the first stretch of the match: everyone heading straight home empties the map)
		var leaving: bool = time_left < 170.0 or (Rolling.bot_past(m, h, 0.3) and (h.gems > 40 or a.get("leave", false)))
		var g: Array = m.exits.bot_goal(h, leaving)
		if not g.is_empty() and _banned(m, a, g[0]) and String(g[1]) in ["dock", "uplink"]:
			g = []
		if g.is_empty() and not leaving:
			# some bots go and crash a rival's skiff call or uplink
			if not a.has("contest"): a["contest"] = randf() < 0.35
			if a["contest"]: g = m.exits.bot_contest(h, 40.0)
		if not g.is_empty():
			goal = g[0]; gk = String(g[1])
	if goal == Vector3.INF:
		for k in m.kins:
			if KinLoss.scannable_by(h, k) and Capture.room(h) and h.flat_dist(k) < 14.0 + (GOAL_KEEP if k.pos.distance_to(cur) < 2.0 else 0.0):
				goal = k.pos; gk = "catch"; break
	if goal == Vector3.INF:
		var kg := BotKeys.goal(m, h, cur)      # no key yet: fight for one first
		if not kg.is_empty():
			goal = kg[0]
			gk = String(kg[1])
	if goal == Vector3.INF:
		var bd := BotKeys.chest_range(h)       # a key in hand: now a chest
		for c in m.chests:
			if not BotKeys.chest_open_for(h, c): continue
			var d := h.flat_dist(c["pos"]) - (GOAL_KEEP if c["pos"] == cur else 0.0)
			if d < bd: bd = d; goal = c["pos"]; gk = "chest"
	if goal == Vector3.INF:
		var bd := 12.0
		for p in m.pickups:
			if m.world.is_void(p["pos"].x, p["pos"].z):
				continue
			if m.lairs and m.lairs.walled_off(h, p["pos"]):
				continue      # (behind a sealed lair's gate: no way in from here)
			var d := h.flat_dist(p["pos"]) - (GOAL_KEEP if p["pos"].distance_to(cur) < 1.0 else 0.0)
			if d < bd: bd = d; goal = p["pos"]; gk = "loot"
	if goal == Vector3.INF:
		# roam toward monsters or another island
		if a["wander"] == Vector3.INF or h.flat_dist(a["wander"]) < 2.0 or randf() < 0.02:
			var alive_mobs := m.mobs.filter(func(x): return not x.dead and not (x is Blight))     # (camps level you; the Blight doesn't)
			if alive_mobs.size() > 0 and randf() < 0.6:
				a["wander"] = alive_mobs.pick_random().pos
			else:
				a["wander"] = m.world.random_ground()
		goal = a["wander"]; gk = "roam"
	# a goal we gave up on for now: head for a detour instead, and keep it (re-rolling a fresh one
	# every think left the bot dithering on the spot)
	if _banned(m, a, goal):
		var dt: Vector3 = a.get("detour", Vector3.INF)
		if dt == Vector3.INF or _banned(m, a, dt) or h.flat_dist(dt) < 2.0:
			dt = m.world.random_ground()
			a["detour"] = dt
		goal = dt; gk = "roam"
	# flip-flopping between two goals (A, B, A again within a few seconds): stay on the one we're on
	# for a while. Two goals pulling opposite ways had a bot turning round every think: it spun.
	# (a goal that only moved a little is the same one, walking: a kin, a squadmate we follow)
	if goal != a["goal"] and a["goal"] != Vector3.INF and not gk in URGENT_GOALS and goal.distance_to(a["goal"]) > 3.0 \
			and goal.distance_to(a.get("prev_goal", Vector3.INF)) < 1.0 and m.time - float(a.get("goal_set_t", -99.0)) < GOAL_STICK:
		goal = a["goal"]; gk = String(a["goal_kind"])
	if goal != a["goal"] and (a["goal"] == Vector3.INF or goal.distance_to(a["goal"]) > 3.0):
		a["prev_goal"] = a["goal"]
		a["goal_set_t"] = m.time
	# give up on goals we can't seem to reach
	if goal != a["goal"]:
		a["goal_best"] = 1e9
		a["goal_since"] = m.time
	elif goal != Vector3.INF:
		var d := h.flat_dist(goal)
		if d < 2.0 and String(a.get("goal_kind", "")) in ["board", "yard", "beacon", "lair_dial", "lair_lever", "lair_camp"]:
			a["goal_since"] = m.time      # there and waiting (holding a dock, charging an uplink) is fine
		if d < float(a.get("goal_best", 1e9)) - 0.5:
			a["goal_best"] = d
			a["goal_since"] = m.time
		elif m.time - float(a.get("goal_since", m.time)) > 14.0:
			var bans: Dictionary = a.get("banned", {})
			bans[goal] = m.time + 20.0
			a["banned"] = bans
			a["goal_since"] = m.time
			a["goal_best"] = 1e9
	a["goal"] = goal
	a["goal_kind"] = gk

## A hurt bot with the Blight near (and nothing to drink) backs off the way it isn't: a spot ten
## tiles away from the Blight's middle, on solid ground. INF when there's no need.
func _blight_flee(m: Match, h: Hunter) -> Vector3:
	if h.hp >= h.max_hp * 0.3 or h.tonics > 0:
		return Vector3.INF
	var c := Vector2.ZERO; var n := 0
	for mb in m.mobs:
		if mb is Blight and not mb.dead and h.flat_dist(mb) < 10.0:
			c += Vector2(mb.pos.x, mb.pos.z); n += 1
	if n == 0:
		return Vector3.INF
	c /= float(n)
	var away := (Vector2(h.pos.x, h.pos.z) - c).normalized()
	if away.length() < 0.1: away = Vector2(1, 0)
	for k in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var d2 := away.rotated(k)
		var q := h.pos + Vector3(d2.x, 0, d2.y) * 10.0
		if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z):
			return Vector3(q.x, m.world.ground_at(q.x, q.z), q.z)
	return Vector3.INF

## Direction to walk toward a goal, using jump pads to cross to other islands.
func _path_dir(m: Match, h: Hunter, goal: Vector3) -> Vector2:
	var here := m.world.island_of(h.pos.x, h.pos.z)
	var there := m.world.island_of(goal.x, goal.z)
	if here < 0 or there < 0 or here == there:
		if here >= 0 and h.grounded: h.ai.erase("cross")
		return _steer(m, h, goal)
	# breadth-first search over the island graph
	var prev := {here: -1}
	var q := [here]
	while q.size() > 0:
		var cur: int = q.pop_front()
		if cur == there:
			break
		for pd in m.world.pads + m.world.links:
			if pd["from"] == cur and not prev.has(pd["to"]):
				prev[pd["to"]] = cur
				q.append(pd["to"])
	if not prev.has(there):
		return h.dir_to(goal)
	var nxt := there
	while prev[nxt] != here and prev[nxt] != -1:
		nxt = prev[nxt]
	for pd in m.world.pads:
		if pd["from"] == here and pd["to"] == nxt:
			h.ai["pad_at"] = pd["pos"]
			h.ai.erase("cross")
			return _steer(m, h, pd["pos"])
	for lk in m.world.links:
		if lk["from"] == here and lk["to"] == nxt:
			if not h.ai.has("cross") or h.ai["cross"] != lk:
				h.ai["cross"] = lk
				h.ai["cross_t"] = 14.0
			return _steer(m, h, lk["take"])
	return h.dir_to(goal)

## Heads for a spot on this island, finding a way around walls when they're in the way.
func _steer(m: Match, h: Hunter, goal: Vector3) -> Vector2:
	var from := Vector2(h.pos.x, h.pos.z)
	var to := Vector2(goal.x, goal.z)
	if _clear_line(m, from, to):
		h.ai.erase("wp")
		h.ai.erase("nopath")
		return h.dir_to(goal)
	var gt := Vector2i(int(floor(goal.x)), int(floor(goal.z)))
	var wp: Dictionary = h.ai.get("wp", {})
	if wp.is_empty() or wp["goal"] != gt or m.time - float(wp["t"]) > 2.0:
		wp = {"goal": gt, "t": m.time, "path": _grid_path(m, Vector2i(int(floor(h.pos.x)), int(floor(h.pos.z))), gt)}
		h.ai["wp"] = wp
	var path: Array = wp["path"]
	if path.is_empty():
		# no way there on foot: walking straight at it had the bot shuffle at a rim (or step off a
		# terrace and climb back) until the 14 s give-up. Give up on it after a moment instead.
		_no_path(m, h)
		return h.dir_to(goal)
	h.ai.erase("nopath")
	# aim for the furthest waypoint we can walk straight to
	var pick: Vector2 = path[0]
	for i in range(path.size() - 1, -1, -1):
		if _clear_line(m, from, path[i]):
			pick = path[i]
			break
	while path.size() > 1 and from.distance_to(path[0]) < 0.6:
		path.pop_front()
	var d := pick - from
	return d.normalized() if d.length() > 0.05 else h.dir_to(goal)

const NO_PATH_GIVE_UP := 1.5     # seconds without a walkable path before a goal is banned for now

func _no_path(m: Match, h: Hunter) -> void:
	var a: Dictionary = h.ai
	var g: Vector3 = a.get("goal", Vector3.INF)
	if g == Vector3.INF or String(a.get("goal_kind", "")) in URGENT_GOALS:
		return
	var np: Array = a.get("nopath", [])
	if np.is_empty() or np[0] != g:
		a["nopath"] = [g, m.time]      # (per goal: a new one gets its own moment)
	elif m.time - float(np[1]) > NO_PATH_GIVE_UP:
		var bans: Dictionary = a.get("banned", {})
		bans[g] = m.time + 20.0
		a["banned"] = bans
		a.erase("nopath")

func _clear_line(m: Match, a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var n := int(d.length() / 0.4) + 1
	var side := Vector2(-d.y, d.x).normalized() * 0.32
	for k in range(1, n + 1):
		var p := a + d * (float(k) / n)
		if m.world.is_block(p.x, p.y) or m.world.is_block(p.x + side.x, p.y + side.y) or m.world.is_block(p.x - side.x, p.y - side.y):
			return false
		# the abyss blocks a walk too: straight at a goal across a bay in the island, the edge guard
		# turned the bot aside every frame and it shuffled on the spot instead of taking the way round
		if m.world.is_void(p.x, p.y):
			return false
	return true

## Breadth-first search over walkable tiles (a window around the trip), returning tile centres.
func _grid_path(m: Match, a: Vector2i, b: Vector2i) -> Array:
	var W: World = m.world
	var lo := Vector2i(mini(a.x, b.x) - 8, mini(a.y, b.y) - 8)
	var hi := Vector2i(maxi(a.x, b.x) + 8, maxi(a.y, b.y) + 8)
	var prev := {a: a}
	var q: Array = [a]
	var found := false
	var steps := 0
	while q.size() > 0 and steps < 4000:
		steps += 1
		var cur: Vector2i = q.pop_front()
		if cur == b or (absi(cur.x - b.x) <= 1 and absi(cur.y - b.y) <= 1 and W.is_block(b.x + 0.5, b.y + 0.5)):
			b = cur
			found = true
			break
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + dv
			if prev.has(nx) or nx.x < lo.x or nx.y < lo.y or nx.x > hi.x or nx.y > hi.y or not W.inb(nx.x, nx.y):
				continue
			var i := W.idx(nx.x, nx.y)
			if W.kind[i] != World.T_GROUND:
				continue
			if absf(W.ground_at(nx.x + 0.5, nx.y + 0.5) - W.ground_at(cur.x + 0.5, cur.y + 0.5)) > 1.7:
				continue
			prev[nx] = cur
			q.append(nx)
	if not found:
		return []
	var out: Array = []
	var c := b
	while c != a:
		out.push_front(Vector2(c.x + 0.5, c.y + 0.5))
		c = prev[c]
	return out

func _banned(m: Match, a: Dictionary, p: Vector3) -> bool:
	var bans: Dictionary = a.get("banned", {})
	return bans.has(p) and float(bans[p]) > m.time
