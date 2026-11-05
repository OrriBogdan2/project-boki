class_name DolmKit
extends ArchKit
## Tarek (id dolm, medium): Tremor Sense, Rubble Fists (tap boulder / hold punch), Rubble Leap, Quakefall,
## Stone Row, and Basalt Spine on X (breah_spine.gd). docs/heroes/dolm.md. The loop: raise rocks (Stone Row),
## then launch them with a held punch (every rock in the lane flies, a whole row one after another),
## a slam or a dash into the enemy. Rocks are low walls you can stand on and climb (StoneStand).
## Molten Guard: a punch that sends your own rocks flying gives a shield stack (a slam at rank 3 adds more).
##
## Rocks are Verbs walls that block movement (HeroZones.rock), so they respect collision, placement
## legality and the abyss edge; they are synced over Net as ["zone", ...] events.
## The RMB charge and slam live in BreahSlam (breah_slam.gd). Looks: her moments (rock eruptions with heavy
## debris, cracked ground, dust and grit, the eye-stones flaring as the tell of her big moves and sparking when
## she leaps) are HeroVfx's (content/vfx/dolm.json); the rock skins, held fist glows and stun crowns KitLooks'.

const ROCK_PAY := "ROCKFALL"
const STONE := Color("d9a35b")
const MOLTEN := Color("ff7a2a")
const LANE_COL := Color("f4ead8")       # the punch lane: pale stone white, as bright as an aim reticle
const ROCK_STEP_OFF := 1.0     # m: from atop a rock, Stone Row measures from the ground this far ahead
const LEAP_CROUCH := 0.06      # s: the rock bursts up and she crouches on it before the leap
const LEAP_ROCK_UP := 1.6      # m: how high the rock arcs after her

var lmb_t := -1.0              # how long the attack key has been down (-1: not pressed)
var lmb_was := false
var rid_n := 0
var dive := false              # a Quakefall in the air (the hop, a leap, an air press): slam on landing
var dive_k := 0.0              # ...with this much charge
var dive_fall := false         # ...plunging straight down (pressed in the air), not riding an arc
var dive_glide := false        # ...pressed in a glide: the glider folded and stays shut until she lands
var sight_t := 0.0
var sneak_t := 0.0             # how long she has been sneaking (the cone widens)
var shield_stacks := 0         # Molten Guard stacks
var shield_at := -99.0
var launch_pay := 0            # launched rocks that hit a hunter (payoff counter)
var rock_hits := {}            # foe instance id -> last time a rock burst on it (repeat bursts deal less)
# Rubble Leap in flight: {t, wait, T, from, to, dir, land_at (-1 until she lands)}
var leap := {}
var slam: BreahSlam
var spine: BreahSpine
# counters for the checks
var punches := 0
var boulders := 0
var launches := 0
var slams := 0
var dunks := 0
var wall_stuns := 0
var guard_punches := 0         # punches that launched a rock of ours and gave a Molten Guard stack
var rocks_made := 0
var sight_pings := 0
var landslides := 0            # leap rocks that came down and rolled on
var leap_lands := 0            # leaps that landed
var leap_hits := 0             # foes the landing crash caught
var sweeps := 0                # punches that launched 2+ rocks in a stream
var last_sweep := 0            # rocks the last punch launched
var splashes := 0              # boulder splash hits

func rock_def() -> Dictionary: return d.get("rock", {})
func slam_def() -> Dictionary: return rmb_def()["slam"]

func _setup() -> void:
	slam = BreahSlam.new(self)
	spine = BreahSpine.new(self)

# ------------------------------------------------------------------ X: Basalt Spine (BreahSpine)
func cast_ult() -> bool: return HeroUlt.press(self, spine.start)
func has_ult() -> bool: return true
func ult_running() -> bool: return spine.running()

## The id prefix of her rocks (unique per hunter, the same on every game).
func rid_owner() -> String:
	return h.nid if h.nid != "" else str(h.get_instance_id())

# ------------------------------------------------------------------ rocks
## Her Stone Row rocks (the pips and the cap); the Basalt Spine's ridge stands apart from both.
func my_rocks() -> Array:
	var out: Array = []
	for w in m.verbs.walls:
		if w.get("rock", false) and w.get("by") == h and not w.has("ult"):
			out.append(w)
	return out

func rocks_up() -> int:
	return my_rocks().size()

func res_text() -> String: return "%d/6" % mini(6, rocks_up())

func _rock_cap() -> int:
	return int(rock_def()["cap"]) + (3 if rank("kin") >= 3 else 0)

func rock_mid(w: Dictionary) -> Vector3:
	var mid: Vector2 = ((w["a"] as Vector2) + (w["b"] as Vector2)) * 0.5
	return Vector3(mid.x, float(w["y"]), mid.y)

## The ground her rocks rise from: the terrain under her while she stands (on one of her rocks too), else
## her own height (in the air nothing fits: Stone Row is ground-only).
func _floor_y() -> float:
	return m.world.ground_at(h.pos.x, h.pos.z) if h.grounded else h.pos.y

func _new_rock(p: Vector3, dir: Vector2) -> bool:
	if not HeroZones.fits(m, p, _floor_y()):
		return false
	var mine := my_rocks()
	while mine.size() >= _rock_cap():
		var old: Dictionary = mine.pop_front()
		m.verbs._break_wall(old)
		HeroZones.tx(m, ["zone", "rockgo", String(old.get("rid", ""))])
	rid_n += 1
	var rd := rock_def()
	HeroZones.rock(
		m, h, p, dir, "%s.r%d" % [rid_owner(), rid_n], float(rd["len"]),
		float(rd["time"]), float(rd["hp"])
	)
	rocks_made += 1
	return true

## A rock leaves the ground along `dir` and flies as a flaming boulder; where it ends it bursts.
## src: "punch" | "slam" | "dash".
func launch(w: Dictionary, dir: Vector2, src: String) -> void:
	var rd := rock_def()
	var mid := rock_mid(w)
	HeroZones.remove_rock(m, w)
	vfx("rock_launch", mid, dir)
	_fire_rock(mid + Vector3(0, 0.9, 0), dir, float(rd["dmg"]) * power("kin"), src, "rock", float(rd["range"]))
	if w.has("ult"):
		m.shots[-1]["x"]["ult"] = int(w["ult"])
	launches += 1

func _fire_rock(start: Vector3, dir: Vector2, dmg: float, src: String, skin: String, rng: float) -> void:
	var rd := rock_def()
	var spd := float(rd["speed"])
	m.spawn_shot(
		h, start, dir * spd, dmg, rng / spd, 0.45, Color("ff8a3c"),
		{
			"kb": float(rd["kb"]) if src != "dash" else float(dash_def()["kb"]), "tracer": 0.3, "src": "abil",
			"ab": "rock", "kx": func(s, at, e, why): _rock_end(s, at, e, why, src)
		}
	)
	HeroVfx.of(m).trail(h, "rock_trail", KitLooks.of(m).skin(m.shots[-1], skin))
	m.sfx("br_launch", start, -3.0, 1.0)

## Where a launched rock ends: it bursts, shreds and slows what it caught and splashes whoever is next
## to it. A rock bursting on someone a rock already burst on inside the repeat window deals less.
func _rock_end(s: Dictionary, at: Vector3, e: Ent, _why: String, src: String) -> void:
	var rd := rock_def()
	var x: Dictionary = s["x"]
	if x.get("burst_done", false):
		return
	x["burst_done"] = true
	var blast := float(rd["blast"])
	vfx("rock_burst", AimMode.ground(m, at), (s["vel"] as Vector2).normalized())
	m.sfx("br_burst", at, -3.0, 1.0)
	var slow_t := float(rd["slow_t"]) if src != "dash" else float(dash_def()["slow_t"])
	var ult_cast := int(x.get("ult", 0))
	var splash_dmg := float(s["dmg"]) * 0.6
	if e != null and is_instance_valid(e) and e.team != h.team:
		s["dmg"] = float(s["dmg"]) * _repeat_k(e)
		KitStatus.apply(e, "vul", float(rd["shred_t"]), float(rd["shred"]))
		if ult_cast > 0:
			s["dmg"] = spine.capped(e, float(s["dmg"]))
			_ult_rock_landed(e, ult_cast)
		x["slow"] = slow_t
		x["slow_k"] = float(rd["slow_k"])
		if e is Hunter:
			launch_pay += 1
			payoff_fx(e.pos, ROCK_PAY, Color("ffb36a"), "pay_rockfall", h.dir_to(e), e)
	for f in foes_in(at, blast):
		if f == e: continue
		var f_dmg := splash_dmg * _repeat_k(f)
		if ult_cast > 0:
			f_dmg = spine.capped(f, f_dmg)
			_ult_rock_landed(f, ult_cast)
		f.hurt(
			f_dmg, h,
			{
				"src": "abil", "ab": "rock", "slow": slow_t, "slow_k": float(rd["slow_k"]),
				"kb": Vector2(f.pos.x - at.x, f.pos.z - at.z).normalized() * 4.0
			}
		)
		KitStatus.apply(f, "vul", float(rd["shred_t"]), float(rd["shred"]))

## A Basalt Spine rock that reached a hunter inside the bond window fills the bond (judged a beat later, so
## a knock or kill from this very hit counts as one).
func _ult_rock_landed(f: Ent, ult_cast: int) -> void:
	if f is Hunter and spine.bond_open(ult_cast):
		m.later(0.02, func(): if is_instance_valid(f): HeroUlt.landed(self, f))

func _repeat_k(f: Ent) -> float:
	var rd := rock_def()
	var key := f.get_instance_id()
	var k := float(rd["repeat_k"]) if m.time - float(rock_hits.get(key, -99.0)) < float(rd["repeat_t"]) else 1.0
	rock_hits[key] = m.time
	return k

# ------------------------------------------------------------------ per step
func _tick(dt: float) -> void:
	var n := rocks_up()
	res = float(n)
	self_pips(6, mini(6, n), false, dt)
	tell = ""
	if n >= 6:
		tell = "full"
	elif n > 0:
		tell = "half"
	if shield_stacks > 0 and m.time - shield_at > float(d["passive"]["guard"]["t"]):
		shield_stacks = 0
	if shield_stacks > 0 and h.shield > 0.0:
		HeroVfx.of(m).hold(h, "guard")      # Molten Guard: embers rising round her while it holds
	if dive:
		_tick_dive()
	if not leap.is_empty():
		_tick_leap(dt)
	slam.tick(dt)
	spine.tick(dt)
	_tick_sight(dt)

## The pending air slam: it lands with her, or plunges if pressed in the air. After a hop, a leap or an air
## press the glider wins (item 26): holding glide drops the slam and hands the arc over, never dragging her
## down. Pressed in a glide (the source's slam out of a glide), the dive is committed: the glider stays shut.
func _tick_dive() -> void:
	if dive_glide:
		h.glide_cd = maxf(h.glide_cd, 0.1)
	if h.downed:
		dive = false
		dive_glide = false
	elif (h.gliding or bool(h.inp.get("glide", false))) and not dive_glide:
		dive = false
		h.fly_t = 0.0
		if dive_fall:
			h.vel.y = maxf(h.vel.y, 0.0)      # the canopy takes the plunge's speed at once
	elif h.grounded:
		dive = false
		dive_glide = false
		slam.land(dive_k)
	elif dive_fall:
		h.vel.y = minf(h.vel.y, -dive_speed())

## The air Quakefall's plunge (m/s down): the glider's dive speed out of a glide, its own otherwise.
func dive_speed() -> float:
	if not dive or not dive_fall:
		return 0.0
	return float(slam_def()["glide_dive_speed" if dive_glide else "dive_speed"])

## Tremor Sense: sneaking shows a narrow cone ahead that widens the longer you sneak, and the foes in
## it through walls and fog.
func _tick_sight(dt: float) -> void:
	if h.crouch and not h.downed:
		sneak_t += dt
		if h.is_local():
			var pd: Dictionary = d["passive"]
			AimKit.cone(
				h, "sight",
				{"len": float(pd["len"]), "deg": sight_deg(), "inner": 0.5, "alpha": 0.7, "col": Color("f3e6c8")}
			)
			sight_t -= dt
			if sight_t <= 0.0:
				sight_t = 0.5
				stonesight()
	else:
		sight_t = 0.0
		sneak_t = 0.0

func sight_deg() -> float:
	var pd: Dictionary = d["passive"]
	return lerpf(float(pd["deg"][0]), float(pd["deg"][1]), clampf(sneak_t / float(pd["grow"]), 0.0, 1.0))

## A Boki merge cancels the air Quakefall's dive, the Quake Fist's charge, the charge leap and
## Rubble Leap (AimKit's telegraphs go with them through drop_holds).
func _drop_holds() -> void:
	dive = false
	dive_k = 0.0
	dive_fall = false
	dive_glide = false
	leap = {}
	if slam: slam.drop()
	if spine: spine.drop()
	if lmb_t >= 0.0:
		lmb_t = -1.0
		h.mel_hold = 0.0

func stonesight() -> int:
	var dir := h.aim_dir()
	var n := 0
	var pd: Dictionary = d["passive"]
	for o in m.hunters:
		if o.team == h.team or not is_instance_valid(o) or o.dead or o.downed: continue
		var to := Vector2(o.pos.x - h.pos.x, o.pos.z - h.pos.z)
		if to.length() > float(pd["len"]) or to.length() < 0.1: continue
		if dir.angle_to(to) > deg_to_rad(sight_deg() * 0.5): continue
		vfx("sense", o.pos)
		n += 1
	if n > 0:
		vfx("eye_flare")
		play("breah_sense")
		m.sfx("br_sense", h.pos, -10.0, 1.0)
	sight_pings += n
	return n

# ------------------------------------------------------------------ LMB: boulder / punch
func punch_k() -> float:
	var ld := lmb_def()
	return clampf((lmb_t - float(ld["tap"])) / maxf(0.05, float(ld["full"]) - float(ld["tap"])), 0.0, 1.0)

func lmb_override(held: bool, dt: float) -> bool:
	if h.wid != "rubble_fists":
		return false
	var ld := lmb_def()
	var pressed := held and not lmb_was
	lmb_was = held
	# (a merge ends the hold: letting go of it must not throw a punch mid-transformation)
	if not h.can_fire() or KinMerge.transforming(h):
		if lmb_t >= 0.0 and flow.pauses_hold("lmb") and not KinMerge.transforming(h):
			# a dash whose hold row keeps the Quake Fist charge: it charges on (short of the auto punch), its
			# lane stays up, and a release in it punches at the dash's end
			if held:
				lmb_t = minf(lmb_t + dt, float(ld["full"]))
				if lmb_t > float(ld["tap"]): _punch_tele(punch_k())
			return true
		if lmb_t >= 0.0:
			lmb_t = -1.0
			h.mel_hold = 0.0
		return true
	if slam.charging():
		if pressed: slam.extend()            # a punch during the Quakefall charge carries her (and the circle) forward
		if lmb_t >= 0.0:
			lmb_t = -1.0
			h.mel_hold = 0.0
		return true
	if h.ctrl != "local":
		# a bot: punches up close, throws boulders from range
		if held and h.fire_cd <= 0.0:
			var tg := _bot_target()
			if tg and h.flat_dist(tg) < 3.0: _punch(0.6)
			else: _boulder()
		return true
	if held:
		if lmb_t < 0.0:
			if h.fire_cd > 0.0:
				return true
			lmb_t = 0.0
		lmb_t += dt
		if lmb_t > float(ld["tap"]):
			var k := punch_k()
			h.mel_hold = k
			if anim_id != "breah_wind" or m.time - anim_at > 3.0: play("breah_wind")
			_punch_tele(k)
			HeroVfx.of(m).hold(h, "punch_charge", k)
			if not KitLooks.of(m).holding("br_fist"): m.sfx("br_wind", h.pos, -6.0, 1.0)
			KitLooks.of(m).hold_on("br_fist", "mote", h, _fist_at(), 0.9 + 1.0 * k, MOLTEN.lerp(Color("ffc23a"), k))
	elif lmb_t >= 0.0:
		# held as long as you like (the data: hold and release; no timeout), full stays full
		if lmb_t < float(ld["tap"]): _boulder()
		else: _punch(punch_k())
	elif pressed:
		pass
	return true

func _fist_at() -> Vector3:
	var dir := h.aim_dir()
	return h.pos + Vector3(dir.x * 0.35 - dir.y * 0.3, 1.05, dir.y * 0.35 + dir.x * 0.3)

## The held punch's lane: a pale rectangle with chevrons, from her feet toward the cursor.
func _punch_tele(k: float) -> void:
	var pd: Dictionary = lmb_def()["punch"]
	AimKit.lane(
		h, "punch",
		{
			"len": float(pd["len"]), "width": float(pd["width"]), "chevrons": 3, "k": k, "fill": k, "col": LANE_COL,
			"col_full": Color("ffd08a")
		}
	)
	AimKit.charge(h, k, {"col": MOLTEN})

func _boulder() -> void:
	var bd: Dictionary = lmb_def()["boulder"]
	lmb_t = -1.0
	h.mel_hold = 0.0
	h.fire_cd = float(bd["rate"])
	h.idle_fire = 0.0
	boulders += 1
	play("breah_throw")
	var dir := h.aim_dir()
	var spd := float(bd["speed"])
	var start := Vector3(h.pos.x + dir.x * 0.6, h.pos.y + 0.95 * float(h.cdat["scale"]), h.pos.z + dir.y * 0.6)
	var rng := AimMode.dist(h, float(bd["range"]), AimMode.MAX)
	m.spawn_shot(
		h, start, dir * spd, float(bd["dmg"]) * m.dmg_mult(h), rng / spd, float(bd["size"]), Color("ff9a3c"),
		{"kb": float(bd["kb"]), "tracer": 0.4, "kx": func(s, at, e, _why): _boulder_end(s, at, e)}
	)
	HeroVfx.of(m).trail(h, "rock_trail", KitLooks.of(m).skin(m.shots[-1], "boulder"))
	m.sfx("br_throw", h.pos, -3.0, 1.0)
	vfx("boulder_throw", start, dir)
	Juice.shot(h, start, dir)

## The boulder bursts where it ends: stone chips and dust over a small cracked patch, splashing the foes
## beside the one it hit.
func _boulder_end(s: Dictionary, at: Vector3, e: Ent) -> void:
	var bd: Dictionary = lmb_def()["boulder"]
	vfx("boulder_hit", AimMode.ground(m, at), (s["vel"] as Vector2).normalized())
	m.sfx("br_boulder_hit", at, -4.0, 1.0)
	for f in foes_in(at, float(bd["splash"])):
		if f == e: continue
		splashes += 1
		f.hurt(float(s["dmg"]) * float(bd["splash_k"]), h, {"src": "abil", "ab": "lmb"})

## The punch: a narrow lane toward the aim. Foes in it are thrown back (into a wall: stunned) and every
## rock in it flies, the ones lined up along the aim too, one after another.
func _punch(k: float) -> void:
	var pd: Dictionary = lmb_def()["punch"]
	lmb_t = -1.0
	h.mel_hold = 0.0
	h.fire_cd = float(pd["rate"])
	h.idle_fire = 0.0
	punches += 1
	play("breah_punch")
	AimKit.hide(h, "punch")
	var dir := h.aim_dir()
	# the step: an impulse, not a roll (a punch is not a dash: it never blocks fire or reads as one)
	var stepv := float(pd["step_v"]) * (float(pd["air_k"]) if not h.grounded else 1.0)
	h.vel.x = dir.x * stepv
	h.vel.z = dir.y * stepv
	var dmg: float = lerpf(float(pd["dmg"][0]), float(pd["dmg"][1]), k) * m.dmg_mult(h)
	var kb := lerpf(float(pd["kb"][0]), float(pd["kb"][1]), k)
	vfx("punch", h.pos, dir, {"len": float(pd["len"]), "k": k})
	m.sfx("br_punch", h.pos, -1.0, 1.0)
	var swept := sweep_rocks(dir)
	last_sweep = swept.size()
	if swept.size() >= 2: sweeps += 1
	if swept.any(func(w): return w.get("by") == h):      # (the data: hitting *your* rocks; an ally's still fly)
		guard_punches += 1
		guard_stack()
	for i in swept.size():
		var w: Dictionary = swept[i]
		if i == 0:
			launch(w, dir, "punch")
		else:
			m.later(float(pd["sweep_stagger"]) * i, func(): if m.verbs.walls.has(w): launch(w, dir, "punch"))
	var landed := 0
	for f in foes_in(h.pos, float(pd["len"]) + 0.6):
		if not AimMode.in_lane(h.pos, dir, float(pd["len"]), float(pd["width"]), f.pos, f.r):
			continue
		var o := {
			"src": "abil", "ab": "lmb", "kb": dir * kb, "lift": 2.0, "melee": true, "wallstun": float(pd["wall_stun"]),
			"heavy": true
		}
		var hp0: float = f.hp
		f.hurt(dmg, h, o)
		landed += 1
		_punch_impact(f.pos, dir, k)
		if terrain_behind(f, dir, 1.6):
			wall_stuns += 1
			if not (f is Hunter):
				f.hurt(2.0, h, {"src": "abil", "ab": "lmb", "stun": float(pd["wall_stun"])})
			m.fx.word(f.pos + Vector3(0, 2.0, 0), "WALLED", Color("ffb36a"), false)
			KitLooks.of(m).crown(f, float(pd["wall_stun"]))
	if landed == 0:
		_punch_impact(h.pos + Vector3(dir.x, 0, dir.y) * float(pd["len"]), dir, k)

## The fist's blow landing on the hit frame (on each foe it caught, or at the lane's end): a hot flash, stone
## chunks thrown on along the punch and dust, bigger the longer she held.
func _punch_impact(at: Vector3, dir: Vector2, k: float) -> void:
	vfx("punch_hit", at, dir, {"k": k})

## Every rock of her team the punch reaches, nearest first: the ones in the lane, then any lined up
## further along the aim with no gap wider than `sweep_gap` (punching along a Stone Row sweeps it).
func sweep_rocks(dir: Vector2) -> Array:
	var pd: Dictionary = lmb_def()["punch"]
	var half := float(pd["width"]) * 0.5 + float(pd["sweep_pad"])
	var cand: Array = []
	for w in m.verbs.walls:
		if not w.get("rock", false) or int(w["team"]) != h.team:
			continue
		var mid := rock_mid(w)
		if absf(mid.y - h.pos.y) >= 2.0: continue
		var to := Vector2(mid.x - h.pos.x, mid.z - h.pos.z)
		var along := to.dot(dir)
		var perp := absf(to.dot(Vector2(-dir.y, dir.x)))
		if along < -0.5 or along > float(pd["sweep_max"]) or perp > half:
			continue
		cand.append([along, w])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	var last := -1e9
	for c in cand:
		var along2: float = c[0]
		if along2 <= float(pd["len"]) + 0.5 or along2 - last <= float(pd["sweep_gap"]):
			out.append(c[1])
			last = along2
		else:
			break
	return out

## A short shove of her own body along `dir` (the punch's step, the charge's lunge): the roll motion
## with no dodge, no riders and no dash sound.
func _lunge(dist: float, t: float, dir: Vector2) -> void:
	if dist <= 0.0 or h.roll_t > 0.0:
		return
	h.roll_dir = dir.normalized()
	h.roll_speed = dist / maxf(0.02, t)
	h.roll_t = t
	h.move_kind = "rush"

# ------------------------------------------------------------------ dash: Rubble Leap
## A second charge at rank 3.
func extra_dashes() -> float:
	return 1.0 if rank("dash") >= 3 else 0.0

## Shift on the ground: a rock bursts up under her, she leaps in an arc to the cursor (up to `dist`, with
## the global dash feel on top like every dash), lands with a crash that shoves everyone beside her, and
## the rock she leapt from comes down right after her and rolls on (the source's odd dash and thrown
## rock, built as a leap: docs/heroes/dolm.md). In the air it is her long dash.
func on_dash(use_ex: bool) -> bool:
	if use_ex:
		if not spend_dash(true): return true
		play("breah_exdash")
		travel(
			float(h.cdat.get("ex_dist", 4.6)), float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1, "trail": "dust"}, true
		)
		m.sfx("br_shove", h.pos, -4.0, 1.0)
		return true
	if in_dash() or not spend_dash(false):
		return true
	if not leap.is_empty():
		_rock_down()       # the last leap's rock was still coming down: it rolls on now
	var dd := dash_def()
	var dir := h.aim_dir()
	var to := leap_spot(dir)
	var flight := float(dd["time"]) * float(dash_feel()["time"])
	leap = {"t": 0.0, "wait": LEAP_CROUCH, "T": flight, "from": h.pos, "to": to, "dir": dir, "land_at": -1.0}
	play("breah_dash")
	# the rock heaves up under her first (debris and dust, no blast: no explosions on a dash); she crouches on
	# it, then leaps
	vfx("leap_rise")
	m.sfx("br_rise", h.pos, -4.0, 1.2)
	AimKit.circle(
		h, "leap",
		{"at": to, "r": float(dd["land_r"]), "fill": 0.0, "all": true, "col": Color("ff5a2a"), "dur": flight + 0.3}
	)
	CombatBus.ability_used.emit(h, String(dd.get("id", "dash")), "dodge")
	return true

## Where the leap lands: the cursor, clamped between `min` and `dist` (times the dash feel; a third
## further at rank 3), pulled back toward her until it is ground a body fits on.
func leap_spot(dir: Vector2) -> Vector3:
	var dd := dash_def()
	var far := float(dd["dist"]) * float(dash_feel()["dist"]) * (float(dd["speed_k"]) if rank("dash") >= 3 else 1.0)
	var to_aim := Vector2(aim().x - h.pos.x, aim().z - h.pos.z).length()
	var want := clampf(to_aim, float(dd["min"]), far)
	while want > 0.3:
		var p := h.pos + Vector3(dir.x, 0, dir.y) * want
		var g: float = m.world.ground_at(p.x, p.z)
		if g > World.VOID + 1.0 and g - h.pos.y < 2.5 and m.world.occupy(p.x, p.z, h.r, g, false) == 0.0:
			return Vector3(p.x, g, p.z)
		want -= 0.25
	return h.pos

func _tick_leap(dt: float) -> void:
	var dd := dash_def()
	leap["t"] = float(leap["t"]) + dt
	if h.downed:
		leap = {}
		AimKit.hide(h, "leap")
		return
	var from: Vector3 = leap["from"]
	var to: Vector3 = leap["to"]
	if float(leap["wait"]) > 0.0:
		leap["wait"] = float(leap["wait"]) - dt
		KitLooks.of(m).hold_on("br_carry", "dashrock", h, from + Vector3(0, 0.35, 0))
		if float(leap["wait"]) <= 0.0:
			_leap_off()
		return
	var flown := float(leap["t"]) - LEAP_CROUCH
	var flight := float(leap["T"])
	AimKit.circle(
		h, "leap",
		{
			"at": to, "r": float(dd["land_r"]), "fill": clampf(flown / flight, 0.0, 1.0), "all": true,
			"col": Color("ff5a2a")
		}
	)
	# the rock follows her arc a beat behind, tumbling
	var lag := float(dd["rock_lag"])
	var ur := clampf((flown - lag) / flight, 0.0, 1.0)
	var rock_at := from.lerp(to, ur) + Vector3(0, 0.5 + sin(ur * PI) * LEAP_ROCK_UP, 0)
	var land_at := float(leap["land_at"])
	if land_at < 0.0 and not h.grounded and h.pad.is_empty():
		h.vel.y -= _leap_pull() * dt
	if land_at < 0.0 and flown > 0.08 and (h.grounded or flown > flight + 0.5):
		_leap_land()
		land_at = flown
		leap["land_at"] = flown
	var rock_down := maxf(flight, land_at) + lag
	if flown < rock_down:
		KitLooks.of(m).hold_on("br_carry", "dashrock", h, rock_at)
		return
	if land_at >= 0.0:
		_rock_down()

## The leap is over: its rock comes down at the landing spot and rolls on.
func _rock_down() -> void:
	var to: Vector3 = leap["to"]
	var dir: Vector2 = leap["dir"]
	leap = {}
	AimKit.hide(h, "leap")
	_landslide_launch(to, dir)

func _leap_off() -> void:
	var dd := dash_def()
	h.launch_to(leap["to"], float(leap["T"]))
	if h.pad.is_empty():
		h.vel.y += 0.5 * _leap_pull() * float(leap["T"])     # a heavy rock leap: a higher arc, same landing time
	h.inv_t = maxf(h.inv_t, float(dd["invuln"]))
	h.dash_at = m.time
	vfx("leap")
	m.sfx("br_leap", h.pos, -3.0, 1.0)
	Feel.dash_sound(m, id, h.pos, h)

## Rubble Leap falls at its own leap_grav (a heavy arc that still lands on time): the pull on top of gravity.
func _leap_pull() -> float:
	return maxf(0.0, float(dash_def().get("leap_grav", Hunter.H_GRAV)) - Hunter.H_GRAV)

## The landing: a crash that shoves everyone beside her (the first of the leap's two hits).
func _leap_land() -> void:
	var dd := dash_def()
	leap_lands += 1
	var at := h.pos
	var r := float(dd["land_r"])
	play("breah_leap_land")
	vfx("leap_land", at)      # the hit area was the landing circle all through the flight: no ring or blast here
	m.sfx("br_slam", at, -5.0, 1.15)
	rider_points(leap["from"], at)
	for f in foes_in(at, r, 2.0):
		leap_hits += 1
		var away := Vector2(f.pos.x - at.x, f.pos.z - at.z)
		away = away.normalized() if away.length() > 0.05 else h.aim_dir()
		f.hurt(
			float(dd["land_dmg"]) * power("dash"), h,
			{"src": "abil", "ab": "dash", "kb": away * float(dd["kb"]), "lift": 2.0, "heavy": true}
		)

## The rock comes down just ahead of where she landed and rolls on (the leap's second hit).
func _landslide_launch(at: Vector3, dir: Vector2) -> void:
	var dd := dash_def()
	landslides += 1
	var start := at + Vector3(dir.x * 0.9, 0.5, dir.y * 0.9)
	vfx("landslide", start, dir)
	_fire_rock(start, dir, float(dd["dmg"]) * power("dash"), "dash", "dashrock", float(dd["rock_range"]))
	m.sfx("br_roll", start, -3.0, 1.0)

## Her own hand tell (the molten fists) replaces the shared white charge orb.
func charge_orb() -> bool:
	return false

## Rubble Leap is her ground dash for DashFlow: from the press until she lands (the rock rolling on after is not).
func in_dash() -> bool:
	return super.in_dash() or _leaping()

## Rubble Leap's time left until its planned landing (the shared dash's otherwise).
func dash_left() -> float:
	if _leaping():
		return maxf(0.0, LEAP_CROUCH + float(leap["T"]) - float(leap["t"]))
	return super.dash_left()

func _leaping() -> bool:
	return not leap.is_empty() and float(leap["land_at"]) < 0.0

## Her dash moves (breah_dash, breah_exdash) are the whole dash pose: no shared roll under them.
func dodge_anim() -> String:
	return "kit"

## No shared after-image pill: her dashes kick up their own debris and dust (content/vfx "leap_rise", "leap").
func dash_afterimage() -> bool:
	return true

# ------------------------------------------------------------------ RMB: Quakefall (BreahSlam)
func rmb_charge_full() -> float:
	return float(rmb_def()["hold"]) + float(slam_def()["time"])

func rmb_auto_t() -> float:
	return rmb_charge_full() + 0.5

func rmb_hold_tick(t: float) -> void:
	slam.hold_tick(t)

func move_k() -> float:
	return slam.move_k()

func fire_rmb(c: Dictionary) -> void:
	slam.fire(c)

func _slam(k: float, at_feet: bool) -> void:
	slam.slam(k, at_feet)

## Molten Guard: one more stack (each is a shield, up to the cap, all expiring together).
func guard_stack() -> void:
	var gd: Dictionary = d["passive"]["guard"]
	shield_stacks = mini(int(gd["cap"]), shield_stacks + 1)
	shield_at = m.time
	h.shield = maxf(h.shield, float(gd["shield"]) * shield_stacks)
	h.shield_t = float(gd["t"])
	vfx("guard_up")

# ------------------------------------------------------------------ E: Stone Row
## The row's spots: 3 rocks in a slight curve across the aim (the outer two set back), and at rank 3 an
## extra row behind. Every spot is judged before the first rock goes up (rocks block sight and walking).
func row_spots(dir: Vector2) -> Array:
	var ed := e_def()
	var side := Vector2(-dir.y, dir.x)
	var rows := 2 if rank("kin") >= 3 else 1
	var spots: Array = []
	var from := h.pos
	if h.grounded and h.pos.y - _floor_y() > 0.5:
		# standing on one of her rocks: the row is measured along the ground from just past it
		from = Vector3(h.pos.x + dir.x * ROCK_STEP_OFF, _floor_y(), h.pos.z + dir.y * ROCK_STEP_OFF)
	for r in rows:
		var dist := float(ed["dist"]) + float(ed["row_gap"]) * r
		var base := h.pos + Vector3(dir.x, 0, dir.y) * dist
		var wk := HeroZones.walk(m, from, base, dist)
		if not wk["ok"] or wk["stopped"] == "wall" or wk["stopped"] == "abyss":
			continue      # a wall or the abyss lies between you and the row
		for i in [0, -1, 1]:
			var p := base + Vector3(
				side.x, 0, side.y
			) * float(ed["gap"]) * float(i) - Vector3(dir.x, 0, dir.y) * float(ed["curve"]) * absf(float(i))
			p.y = m.world.ground_at(p.x, p.z)
			# the rock must be reachable in line from the caster (no building through a wall)
			if m.world.los(
				h.pos + Vector3(0, 0.5, 0), p + Vector3(0, 0.5, 0), h.pos.y + 0.5
			) and HeroZones.fits(m, p, _floor_y()):
				spots.append([p, r])
	return spots

func cast_e() -> bool:
	var ed := e_def()
	var dir := h.aim_dir()
	var spots := row_spots(dir)
	if spots.is_empty():
		if h.is_local() and m.hud: m.hud.toast_small("No room for rocks here", col_of(ed))
		return false
	play("breah_raise")
	vfx("eye_flare")
	# the tell: a red-orange flash on the ground where each rock will rise, then the rocks
	var tell := float(ed["tell"])
	for j in spots.size():
		var p: Vector3 = spots[j][0]
		AimKit.circle(
			h, "e_tell%d" % j, {"at": p, "r": 0.75, "fill": 1.0, "col": Color("ff4a1f"), "all": true, "dur": tell}
		)
		vfx("row_tell", p, dir)
	m.sfx("br_crack", h.pos, -3.0, 1.0)
	for j in spots.size():
		var p2: Vector3 = spots[j][0]
		m.later(tell, func(): if is_instance_valid(h) and not KinMerge.active(h): _raise(p2, dir))
	m.later(tell, _raise_feel)
	return true

func _raise(p: Vector3, dir: Vector2) -> void:
	if not _new_rock(p, dir):
		return
	vfx("rock_rise", p, dir)

func _raise_feel() -> void:
	if not is_instance_valid(h):
		return
	m.sfx("br_raise", h.pos, -1.0, 1.0)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if HeroUlt.ready(self) and dist > 3.0 and dist < 9.0 and los and randf() < 0.1:
		h.inp["aim"] = tgt.pos
		HunterKeys.ult_pressed(h)
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist > 4.0 and dist < 9.0 and los and randf() < 0.25:
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and dist < 3.4 and los:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		bot_hold["rmb"] = float(rmb_def()["hold"]) + float(slam_def()["time"]) * randf_range(0.3, 1.0)
		return
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and dist > 2.5 and dist < 6.0 and los and randf() < 0.2:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["dash"] = true
