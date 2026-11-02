class_name DolmKit
extends ArchKit
## Breah (id dolm, medium): Tremor Sense, Rubble Fists (tap boulder / hold punch), Landslide, Quakefall,
## Stone Row, and Basalt Spine on X (breah_spine.gd). docs/heroes/dolm.md. The loop: raise rocks (Stone Row, or the rock Landslide pushes),
## then launch them with a held punch (every rock in the lane flies, a whole row one after another),
## a slam or a dash into the enemy. Rocks are low walls you can stand on and climb (StoneStand).
## A slam that knocks or kills resets itself.
##
## Rocks are Verbs walls that block movement (HeroZones.rock), so they respect collision, placement
## legality and the abyss edge; they are synced over Net as ["zone", ...] events.
## The RMB charge and slam live in BreahSlam (breah_slam.gd); the looks in KitLooks.

const ROCK_PAY := "ROCKFALL"
const STONE := Color("d9a35b")
const MOLTEN := Color("ff7a2a")
const LANE_COL := Color("f4ead8")       # the punch lane: pale stone white, as bright as an aim reticle

var lmb_t := -1.0              # how long the attack key has been down (-1: not pressed)
var lmb_was := false
# the hold punched by itself: keep holding and the next wind-up starts, a release throws nothing
var lmb_auto := false
var rid_n := 0
var slam_hit := {}             # foe instance id -> time our slam hit it (a knock inside 6s resets Quakefall)
var dive := false              # the air Quakefall: slam on landing
var dive_k := 0.0              # ...with this much charge
var sight_t := 0.0
var sneak_t := 0.0             # how long she has been sneaking (the cone widens)
var shield_stacks := 0
var shield_at := -99.0
var launch_pay := 0            # launched rocks that hit a hunter (payoff counter)
var rock_hits := {}            # foe instance id -> last time a rock burst on it (repeat bursts deal less)
var carry := {}                # Landslide's rock riding ahead: {t, dir, hit}
var slam: BreahSlam
var spine: BreahSpine
# counters for the checks
var punches := 0
var boulders := 0
var launches := 0
var slams := 0
var dunks := 0
var wall_stuns := 0
var qf_resets := 0
var rocks_made := 0
var sight_pings := 0
var landslides := 0
var sweeps := 0                # punches that launched 2+ rocks in a stream
var last_sweep := 0            # rocks the last punch launched
var splashes := 0              # boulder splash hits
var carried_shoves := 0        # foes the Landslide rock shoved on its way

func rock_def() -> Dictionary: return d.get("rock", {})
func slam_def() -> Dictionary: return rmb_def()["slam"]

func _setup() -> void:
	slam = BreahSlam.new(self)
	spine = BreahSpine.new(self)

# ------------------------------------------------------------------ X: Basalt Spine (BreahSpine)
func cast_ult() -> bool: return spine.start()
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

func _new_rock(p: Vector3, dir: Vector2) -> bool:
	if not HeroZones.fits(m, p, h.pos.y):
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
	m.fx.burst(mid + Vector3(0, 0.6, 0), Color("d9b27a"), 14, 5.0, 0.4, 6.0, 1.1)
	m.fx.spark(mid + Vector3(0, 0.4, 0), Vector3(dir.x, 0.6, dir.y), MOLTEN, 10, 7.0, 35.0, 0.3, 6.0, 1.2)
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
	KitLooks.of(m).skin(m.shots[-1], skin)
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
	m.fx.ring(at, blast, Color("ff5a2a"), 0.3)
	m.fx.ring(at, blast * 0.55, Color("ffd08a"), 0.18)
	m.fx.burst(at + Vector3(0, 0.4, 0), Color("ff9a3c"), 22, 6.0, 0.5, 8.0, 1.1)
	m.fx.spark(at + Vector3(0, 0.3, 0), Vector3.UP, Color("3a2a22"), 12, 8.0, 70.0, 0.45, 16.0, 1.2)      # shrapnel
	m.fx.flash(at + Vector3(0, 0.6, 0), Color("ffc070"), 1.1, 0.08)
	m.sfx("br_burst", at, -3.0, 1.0)
	Feel.shake(m, "t2", h, at)
	net_ring(at, blast, Color("ff5a2a"))
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
	tell = "full" if n >= 6 else ("half" if n > 0 else "")
	if shield_stacks > 0 and m.time - shield_at > float(slam_def()["shield_t"]):
		shield_stacks = 0
	if shield_stacks > 0 and h.shield > 0.0 and fmod(m.time, 0.3) < dt:
		m.fx.ring(h.pos + Vector3(0, 0.1, 0), 1.0, Color("ffd24a"), 0.28)      # the Molten Guard ring
	if dive:
		if h.grounded or h.downed:
			dive = false
			if h.grounded and not h.downed:
				slam.land(dive_k)
		else:
			h.vel.y = minf(h.vel.y, -float(slam_def()["dive_speed"]))
	if not carry.is_empty():
		_tick_carry(dt)
	slam.tick(dt)
	spine.tick(dt)
	_tick_sight(dt)

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
## Landslide's carried rock (AimKit's telegraphs go with them through drop_holds).
func _drop_holds() -> void:
	dive = false
	dive_k = 0.0
	carry = {}
	if slam: slam.drop()
	if spine: spine.drop()
	if lmb_t >= 0.0:
		lmb_t = -1.0
		h.mel_hold = 0.0
	lmb_auto = false

func stonesight() -> int:
	var dir := h.aim_dir()
	var n := 0
	var pd: Dictionary = d["passive"]
	for o in m.hunters:
		if o.team == h.team or not is_instance_valid(o) or o.dead or o.downed: continue
		var to := Vector2(o.pos.x - h.pos.x, o.pos.z - h.pos.z)
		if to.length() > float(pd["len"]) or to.length() < 0.1: continue
		if dir.angle_to(to) > deg_to_rad(sight_deg() * 0.5): continue
		m.fx.ring(o.pos, 0.9, Color("ff6a3a"), 0.55)
		m.fx.ring(o.pos, 0.5, Color("ffd08a"), 0.4)
		n += 1
	if n > 0:
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
		if lmb_t > float(ld["tap"]) or lmb_auto:
			var k := punch_k()
			h.mel_hold = k
			if anim_id != "breah_wind" or m.time - anim_at > 3.0: play("breah_wind")
			_punch_tele(k)
			if not KitLooks.of(m).holding("br_fist"): m.sfx("br_wind", h.pos, -6.0, 1.0)
			KitLooks.of(m).hold_on("br_fist", "hand", h, _fist_at(), 0.6 + 0.8 * k, MOLTEN.lerp(Color("ffe2a0"), k))
		if lmb_t >= float(ld["full"]) + float(ld["auto"]):
			_punch(punch_k())
			lmb_auto = true
	elif lmb_t >= 0.0:
		if lmb_t < float(ld["tap"]) and not lmb_auto: _boulder()
		elif lmb_t >= float(ld["tap"]): _punch(punch_k())
		else:
			lmb_t = -1.0
			h.mel_hold = 0.0
		lmb_auto = false
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
	KitLooks.of(m).skin(m.shots[-1], "boulder")
	m.sfx("br_throw", h.pos, -3.0, 1.0)
	m.fx.spark(start, Vector3(dir.x, 0.2, dir.y), MOLTEN, 6, 5.0, 25.0, 0.18, 2.0, 0.8)
	Juice.shot(h, start, dir)

## The boulder bursts where it ends: a small fireball with a red ring on the ground, splashing the
## foes beside the one it hit.
func _boulder_end(s: Dictionary, at: Vector3, e: Ent) -> void:
	var bd: Dictionary = lmb_def()["boulder"]
	var g := AimMode.ground(m, at)
	m.fx.ring(g, float(bd["splash"]), Color("ff3a2a"), 0.28)
	m.fx.burst(at, Color("ffb050"), 12, 4.0, 0.3, 4.0, 1.0)
	m.fx.flash(at, Color("ffd090"), 0.7, 0.06)
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
	var fp := h.pos + Vector3(dir.x * 1.3, 1.0, dir.y * 1.3)
	m.fx.burst(fp, Color("e8c07a"), int(8 + 10 * k), 4.0 + 4.0 * k, 0.3, 4.0, 1.0, Vector3(dir.x, 0.1, dir.y), 40.0)
	m.fx.spark(fp, Vector3(dir.x, 0.05, dir.y), MOLTEN, int(8 + 8 * k), 9.0 + 6.0 * k, 22.0, 0.22, 2.0, 1.2)
	m.fx.slash(h.pos + Vector3(0, 1.0, 0), atan2(dir.y, dir.x), 0.5, float(pd["len"]) * 0.8, MOLTEN, k > 0.6)
	m.sfx("br_punch", h.pos, -1.0, 1.0)
	Feel.shake(m, "t3" if k > 0.6 else "t2", h, fp)
	var swept := sweep_rocks(dir)
	last_sweep = swept.size()
	if swept.size() >= 2: sweeps += 1
	for i in swept.size():
		var w: Dictionary = swept[i]
		if i == 0:
			launch(w, dir, "punch")
		else:
			m.later(float(pd["sweep_stagger"]) * i, func(): if m.verbs.walls.has(w): launch(w, dir, "punch"))
	for f in foes_in(h.pos, float(pd["len"]) + 0.6):
		if not AimMode.in_lane(h.pos, dir, float(pd["len"]), float(pd["width"]), f.pos, f.r):
			continue
		var o := {
			"src": "abil", "ab": "lmb", "kb": dir * kb, "lift": 2.0, "melee": true, "wallstun": float(pd["wall_stun"]),
			"heavy": true
		}
		var hp0: float = f.hp
		f.hurt(dmg, h, o)
		if terrain_behind(f, dir, 1.6):
			wall_stuns += 1
			if not (f is Hunter):
				f.hurt(2.0, h, {"src": "abil", "ab": "lmb", "stun": float(pd["wall_stun"])})
			m.fx.word(f.pos + Vector3(0, 2.0, 0), "WALLED", Color("ffb36a"), false)
			KitLooks.of(m).crown(f, float(pd["wall_stun"]))
		if f.hp < hp0 and h.is_local() and m.cam: m.cam.punch(0.03)

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

# ------------------------------------------------------------------ dash: Landslide
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if use_ex:
		if not spend_dash(true): return true
		play("breah_exdash")
		travel(
			float(h.cdat.get("ex_dist", 4.6)), float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1, "trail": "dust"}, true
		)
		m.sfx("br_shove", h.pos, -4.0, 1.0)
		return true
	if not spend_dash(false):
		return true
	var dist := float(dd["dist"]) * (float(dd["speed_k"]) if rank("dash") >= 3 else 1.0)
	var t := float(dd["time"]) * (float(dd["speed_k"]) if rank("dash") >= 3 else 1.0)
	var dir := h.aim_dir()
	play("breah_dash")
	# the rock bursts up just in front of her, a puff behind, then rides ahead of her for the dash
	var front := h.pos + Vector3(dir.x, 0, dir.y) * 0.9
	m.fx.burst(front + Vector3(0, 0.4, 0), Color("c9a27a"), 14, 5.0, 0.4, 9.0, 1.1)
	m.fx.spark(front, Vector3.UP, MOLTEN, 8, 6.0, 25.0, 0.25, 8.0, 1.0)
	m.fx.dust(h.pos - Vector3(dir.x, 0, dir.y) * 0.6, 8)
	m.sfx("br_rise", front, -4.0, 1.2)
	travel(dist, t, {"invuln": float(dd["invuln"]), "trail": "roll", "dir": dir})
	carry = {"t": t, "dir": dir, "hit": {}}
	return true

func _tick_carry(dt: float) -> void:
	var dir: Vector2 = carry["dir"]
	var at := h.pos + Vector3(dir.x, 0, dir.y) * 1.0 + Vector3(0, 0.5, 0)
	KitLooks.of(m).hold_on("br_carry", "dashrock", h, at)
	# the rock shoves whoever it runs into ahead of her (the setup for the dunk)
	for f in foes_in(at, 1.1):
		if carry["hit"].has(f.get_instance_id()): continue
		carry["hit"][f.get_instance_id()] = true
		carried_shoves += 1
		f.hurt(
			2.0 * power("dash"), h, {"src": "abil", "ab": "dash", "kb": dir * float(dash_def()["kb"]), "heavy": true}
		)
	carry["t"] = float(carry["t"]) - dt
	if float(carry["t"]) <= 0.0 or h.downed:
		var go := not h.downed
		carry = {}
		if go: _landslide_launch(dir)

func _landslide_launch(dir: Vector2) -> void:
	var dd := dash_def()
	landslides += 1
	var start := h.pos + Vector3(dir.x * 0.9, 0.5, dir.y * 0.9)
	m.fx.burst(start, Color("e8c07a"), 14, 5.0, 0.4, 6.0, 1.1, Vector3(dir.x, 0.1, dir.y), 35.0)
	_fire_rock(start, dir, float(dd["dmg"]) * power("dash"), "dash", "dashrock", float(dd["rock_range"]))
	m.sfx("br_roll", h.pos, -3.0, 1.0)

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

func _reset_quake() -> void:
	qf_resets += 1
	cd["rmb"] = 0.0
	ch_rmb = float(rmb_charges())
	armed_fx("QUAKE RESET", "sec")

func on_knock(t: Hunter, mine: bool) -> void:
	if mine and slam_hit.has(t.get_instance_id()) and m.time - float(slam_hit[t.get_instance_id()]) < 6.0:
		slam_hit.erase(t.get_instance_id())
		_reset_quake()

# ------------------------------------------------------------------ E: Stone Row
## The row's spots: 3 rocks in a slight curve across the aim (the outer two set back), and at rank 3 an
## extra row behind. Every spot is judged before the first rock goes up (rocks block sight and walking).
func row_spots(dir: Vector2) -> Array:
	var ed := e_def()
	var side := Vector2(-dir.y, dir.x)
	var rows := 2 if rank("kin") >= 3 else 1
	var spots: Array = []
	for r in rows:
		var dist := float(ed["dist"]) + float(ed["row_gap"]) * r
		var base := h.pos + Vector3(dir.x, 0, dir.y) * dist
		var wk := HeroZones.walk(m, h.pos, base, dist)
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
			) and HeroZones.fits(m, p, h.pos.y):
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
	# the tell: a red-orange flash on the ground where each rock will rise, then the rocks
	var tell := float(ed["tell"])
	for j in spots.size():
		var p: Vector3 = spots[j][0]
		AimKit.circle(
			h, "e_tell%d" % j, {"at": p, "r": 0.75, "fill": 1.0, "col": Color("ff4a1f"), "all": true, "dur": tell}
		)
		m.fx.spark(p + Vector3(0, 0.1, 0), Vector3.UP, MOLTEN, 4, 3.0, 40.0, 0.2, 2.0, 0.8)
	m.sfx("br_crack", h.pos, -3.0, 1.0)
	for j in spots.size():
		var p2: Vector3 = spots[j][0]
		m.later(tell, func(): if is_instance_valid(h) and not KinMerge.active(h): _raise(p2, dir))
	m.later(tell, _raise_feel)
	net_ring(h.pos, 2.0, col_of(ed))
	return true

func _raise(p: Vector3, dir: Vector2) -> void:
	if not _new_rock(p, dir):
		return
	m.fx.burst(p + Vector3(0, 0.2, 0), MOLTEN, 8, 4.0, 0.3, 8.0, 1.0)

func _raise_feel() -> void:
	if not is_instance_valid(h):
		return
	m.sfx("br_raise", h.pos, -1.0, 1.0)
	Feel.shake(m, "t2", h, h.pos)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if HeroUlt.unlocked(self) and float(cd["x"]) <= 0.0 and dist > 3.0 and dist < 9.0 and los and randf() < 0.1:
		h.inp["aim"] = tgt.pos
		h.inp["xult"] = true
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist > 4.0 and dist < 9.0 and los and randf() < 0.25:
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and dist < 3.4 and los:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		bot_hold["rmb"] = float(rmb_def()["hold"]) + float(slam_def()["time"]) * randf_range(0.3, 1.0)
		return
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and dist > 5.0 and dist < 9.0 and los and randf() < 0.2:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["dash"] = true
