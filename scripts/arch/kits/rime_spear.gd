class_name RimeSpear
extends RefCounted
## Claire's RMB, the Ice Spear (docs/heroes/rimewright.md): hold to see the landing ring at the cursor while the
## spear forms between her palms; let go and both palms drive forward, PUSH_T later it leaves them and flies low
## to the cursor (clamped to its range). Where it lands: a small hit, a slow zone and, rmb.lance.delay later, the
## detonation. RimewrightKit forwards its RMB hooks, ticks and drops here; its numbers are rmb.lance.

const PUSH_T := 0.1            # s from letting go of RMB to the release: both palms drive forward (tm_spear)
const ARC := 0.25              # m the driven spear's low flight bows above the line from her palms to the ground
const AHEAD := 0.9             # m in front of her chest of the spear's head end; its shaft runs back to her palms
const CHEST_Y := 1.05          # m: the height of her palms at the chest
const FORM_T := 0.3            # s of holding RMB for the spear to grow to full size between her palms

var k: RimewrightKit
var h: Hunter
var m: Node
var aiming := false            # RMB held: the landing ring and the raised spear are up
var throw_t := -1.0            # s left of the push before the spear leaves her palms (-1: none)
var zones: Array = []          # landed spears: {at, left, total, id}
var zone_n := 0

func _init(kit: RimewrightKit) -> void:
	k = kit
	h = kit.h
	m = kit.m

func ld() -> Dictionary:
	return k.rmb_def()["lance"]

## Held: the landing ring at the cursor (clamped to range); she draws both palms in to her chest and the
## spear forms between them, pointing at the cursor.
func hold_tick(t: float) -> void:
	if not k.rmb_ready() or k.busy():
		return
	var lance := ld()
	AimKit.circle(
			h, "rmb",
			{
				"range": float(lance["range"]), "r": float(lance["zone_r"]), "ticks": true, "star": true,
				"col": Color("dffcff")})
	if not aiming:
		aiming = true
		k.play("tm_spear_aim")
		m.sfx("rime_spear_aim", h.pos, -6.0, 1.0)
	HeroVfx.of(m).hold(h, "spear_aim")
	_hold(lerpf(0.45, 1.0, clampf(t / FORM_T, 0.0, 1.0)), -0.25)

## The ice spear between her palms at `grown` of its size, `ahead` m further out than her chest (the push
## drives it out), along the aim.
func _hold(grown: float, ahead: float) -> void:
	var dir := h.aim_dir()
	var at := pos_at(ahead)
	var facing := Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP)
	var xf := Transform3D(facing.scaled(Vector3.ONE * grown), at)
	k.lk().keep("spear_prop", "spear", at, {"xf": xf})

## Where the spear sits in front of her chest, `ahead` m further along the aim.
func pos_at(ahead: float) -> Vector3:
	var dir := h.aim_dir() * (AHEAD + ahead)
	return h.position + Vector3(dir.x, CHEST_Y, dir.y)

## RMB let go: both palms drive forward (PUSH_T later the spear leaves them). A push, not a throw: no arm
## drawn back, no release flick.
func fire(c: Dictionary) -> void:
	k.last_variant = String(c["variant"])
	aiming = false
	AimKit.hide(h, "rmb")
	if not k.spend_rmb():
		k.lk().drop("spear_prop")
		if k.anim_id == "tm_spear_aim": k.anim_id = ""
		return
	throw_t = PUSH_T
	k.play("tm_spear")
	m.sfx("rime_spear_aim", h.pos, -4.0, 0.8)

## The push: the spear rides out on her palms until they are fully extended. A stun or the seal drops it.
func tick_throw(dt: float) -> void:
	if throw_t < 0.0:
		return
	if k.busy() or k.ult_running():
		_drop_throw()
		return
	throw_t -= dt
	_hold(1.0, -0.25 * throw_t / PUSH_T)
	if throw_t <= 0.0:
		throw_t = -1.0
		_release()

func _drop_throw() -> void:
	throw_t = -1.0
	k.lk().drop("spear_prop")

## A Boki merge: the aim drops (its ring, the raised spear) and a push still on her palms never leaves.
func drop() -> void:
	if aiming or k.rmb_down:
		aiming = false
		k.rmb_down = false
		if k.anim_id == "tm_spear_aim": k.anim_id = ""
		k.lk().drop("spear_prop")
	if throw_t >= 0.0:
		_drop_throw()

## Sealed in Rimelock: the aim ring goes.
func drop_aim() -> void:
	if aiming or k.rmb_down:
		aiming = false
		k.rmb_down = false
		AimKit.hide(h, "rmb")

func teardown() -> void:
	throw_t = -1.0
	zones.clear()

## The spear leaves her palms and drives out low and fast to the cursor (clamped to its range): the further
## the target, the longer it travels (distance / speed). It lands only when it gets there; a foe in the way
## takes the small hit and it lands there.
func _release() -> void:
	k.lk().drop("spear_prop")
	var lance := ld()
	var dir := h.aim_dir()
	var start := pos_at(0.0)
	var spd := float(lance["speed"])
	var dist := AimMode.dist(h, float(lance["range"]))
	var on_land := func(_s: Dictionary, at: Vector3, _e: Ent, _why: String): _land(at)
	var extra := {"src": "abil", "ab": "utility", "tracer": 1.4, "kb": 0.0, "kx": on_land}
	# the spear itself does no damage on the way: its hit is the landing's small area (_land)
	m.spawn_shot(
			h, start, dir * spd, 0.0, dist / spd, float(lance["hit_r"]) * 0.5,
			k.col_of(k.rmb_def()), extra)
	var s := k.lk().last_shot()
	var land_y: float = k.ground(start + Vector3(dir.x, 0, dir.y) * dist).y + 0.1
	k.lk().skin(s, "spear", {"dist": dist, "y": land_y, "h": ARC})
	if not s.is_empty():
		HeroVfx.of(m).trail(h, "spear_trail", s["node"])
	k.stats["spears"] += 1
	m.sfx("rime_lance", h.pos, 0.0, 1.0)
	k.vfx("spear_push", null, dir)

## The spear lands: shards burst up, the slow zone (its real radius) spreads with a spinning crystal and a
## chill puff; 1.8 s later it detonates.
func _land(at0: Vector3) -> void:
	var lance := ld()
	var at := k.ground(at0)
	zone_n += 1
	zones.append({"at": at, "left": float(lance["delay"]), "total": float(lance["delay"]), "id": zone_n})
	k.lk().burst("spikes", at, {"r": 1.1, "dur": 0.35})
	k.vfx("spear_land", at, null, {"r": float(lance["zone_r"])})        # shards, a frosted ground and the chill puff
	m.sfx("rime_zone", at, -1.0, 0.85)
	m.sfx("rimewright_chime", at, -5.0, 0.9)          # the spinning crystal
	# the landing hit (the source's small area): foes right where it lands take it and a short slow
	for f in k.foes_in(at, float(lance["impact_r"])):
		f.hurt(
				float(lance["dmg"]) * k.power("sec"), h,
				{"src": "abil", "ab": "utility", "tags": ["utility", "lance"], "slow": 0.6, "slow_k": 0.35})
		k.add_chill(f)

func tick_zones(dt: float) -> void:
	var lance := ld()
	for z in zones.duplicate():
		z["left"] = float(z["left"]) - dt
		var at: Vector3 = z["at"]
		var fill := 1.0 - float(z["left"]) / maxf(0.01, float(z["total"]))
		var key := "zone%d" % int(z["id"])
		k.lk().keep(
				key, "zone", at,
				{
					"r": float(lance["zone_r"]), "col": Color("7fd8ff"), "rim": Color("e8ffff"), "fill": 0.8,
					"sweep": fill, "pattern": 2.0, "spin": m.time * 0.6, "a": 0.9})
		AimKit.circle(
				h, key,
				{
					"at": at, "r": float(lance["burst_r"]), "fill": fill, "all": true, "dashed": true,
					"col": Color("bff7ef")})
		for f in k.foes_in(at, float(lance["zone_r"])):
			f.slow_k = maxf(f.slow_k if f.slow_t > 0.0 else 0.0, float(lance["zone_slow"]))
			f.slow_t = maxf(f.slow_t, 0.2)
			k.add_chill(f)
		if float(z["left"]) <= 0.0:
			zones.erase(z)
			k.lk().drop(key)
			AimKit.hide(h, key)
			detonate(at)

func detonate(at: Vector3) -> void:
	var lance := ld()
	var rr := float(lance["burst_r"])
	var blast_k := float(lance.get("r3_dmg_k", 1.45)) if k.rank("sec") >= 3 else 1.0
	k.stats["detonations"] += 1
	# the big hit: a full-size starburst of ice spikes, a flash, shards thrown high, frost, mist, a glassy shatter
	k.lk().burst("spikes", at, {"r": rr * 0.95, "dur": 0.6})
	k.vfx("spear_burst", at, null, {"r": rr})
	m.sfx("rime_burst", at, 1.0, 0.9)
	m.sfx("rime_splinter", at, -3.0, 0.75)
	Shake.incoming_big(m, at, 0.6, h)
	k.play_soft("tm_clench")
	for f in k.foes_in(at, rr):
		f.hurt(
				float(lance["burst_dmg"]) * k.power("sec") * blast_k, h,
				{
					"src": "abil", "ab": "utility", "tags": ["utility", "lance"], "slow": 0.8, "slow_k": 0.3,
					"payoff": true})
		k.lk().burst("shell", f.pos, {"dur": float(lance["encase_t"]), "ent": f})
