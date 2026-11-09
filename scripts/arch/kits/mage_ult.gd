class_name MageUlt
extends RefCounted
## Sparkle's ultimate, Kitefall (X). docs/heroes/mage.md has the numbers and the research notes.
##
## Press: a short crouch (a Shift or a jump in it combines: she launches from where it takes her), then she
## launches straight up and hangs there invulnerable while a pink range ring and its dark interior show round
## the take-off spot and the camera pulls back. Press again (X or the attack key) to come down as a bolt at the
## cursor, clamped inside the ring; with no second press she comes down there by herself when the hover runs
## out. The strike hurts, knocks back and adds Static to everyone round the landing spot, and pink lightning
## crackles at her feet for a moment after.

const CROUCH := "crouch"
const RISE := "rise"
const AIR := "air"
const FALL := "fall"
const AFTER := "after"
const AIRBORNE := [RISE, AIR, FALL]
const STEP_BACK := 0.5           # m: how finely the landing spot backs off a wall or a gap toward the take-off
const RAY_STEP := 0.25           # m along the cursor's ray
const RAY_FINE := 8              # the last step, cut this many times
const RAY_ABOVE := 12.0          # m: the ray is walked from this far above the take-off...
const RAY_BELOW := 12.0          # ... to this far below it
const CAM_PULL := 0.45           # how far the camera eases back while she hangs in the air

var kit: MageKit
var leap := {}                 # the running cast: {phase, t, from, base, top, land, high, queued, fire_free, disc}
var casts := 0                 # (tests)
var hits := 0                  # foes the strikes hit (tests)
var last := {}                 # (tests) the last strike: {at, hits, bond}
var spreads := 0               # (tests) Static carried to a foe by a strike

func _init(owner_kit: MageKit) -> void:
	kit = owner_kit

func data() -> Dictionary:
	return kit.x_def()

## Damage scale for the ult: the hunter's own multiplier and level growth (it has no ranks).
func power() -> float:
	return kit.m.dmg_mult(kit.h) * LevelGrowth.ap(kit.h)

func running() -> bool:
	return not leap.is_empty()

func phase() -> String:
	return String(leap.get("phase", ""))

## In the air (rising, hanging or coming down): nothing else of hers works and nothing hurts her.
func airborne() -> bool:
	return AIRBORNE.has(phase())

## Holds her in place: the crouch, the climb, the hang and the drop (the strike's crackle leaves her free).
func busy() -> bool:
	return running() and phase() != AFTER

# ------------------------------------------------------------------ the press
## The cast (HeroUlt.press has checked the cooldown and that nothing holds her).
func cast() -> bool:
	var h := kit.h
	if not kit.wire.is_empty() or kit.run_t > 0.0 or kit.rmb_down:
		return false
	if kit.m.world.is_void(h.pos.x, h.pos.z):
		return false
	var from := kit.ground(h.pos)
	leap = {"phase": CROUCH, "t": 0.0, "from": from, "land": from}
	leap["queued"] = false
	leap["fire_free"] = not bool(h.inp.get("fire", false))
	casts += 1
	kit.play("mage_x")
	kit.vfx("x_cast")          # a bolt drops onto her as she gathers
	kit.m.sfx("vv_ult_rise", h.pos, -2.0)
	kit.net_ring(from, float(data()["range"]), MageKit.GLOW)
	return true

## A second press while she hangs brings her down; pressed during the climb it waits for the hang.
func recast() -> bool:
	match phase():
		CROUCH, RISE:
			leap["queued"] = true
			return true
		AIR:
			_slam()
			return true
	return false

# ------------------------------------------------------------------ per step
func tick(dt: float) -> void:
	if leap.is_empty():
		return
	leap["t"] = float(leap["t"]) + dt
	var t := float(leap["t"])
	var xd := data()
	match phase():
		CROUCH:
			if _moving():
				leap["t"] = 0.0             # a Shift in the crouch: the crouch waits for it, then starts over
				leap["moved"] = true
			elif bool(leap.get("moved", false)):
				leap["moved"] = false
				kit.play("mage_x")
			else:
				_hold_still()
				if t >= float(xd["windup"]):
					_take_off()
		RISE:
			_hold_air(smoothstep(0.0, 1.0, t / float(xd["rise"])))
			_aim_tick()
			if t >= float(xd["rise"]):
				_next(AIR)
		AIR:
			_hold_air(1.0)
			_aim_tick()
			HeroVfx.of(kit.m).hold(kit.h, "x_hang")          # crackling round her while she hangs
			if _wants_down(t, xd):
				_slam()
		FALL:
			_fall_tick(clampf(t / float(xd["drop"]), 0.0, 1.0))
			if t >= float(xd["drop"]):
				_strike()
		AFTER:
			if t >= float(xd["after"]):
				leap = {}

func _next(p: String) -> void:
	leap["phase"] = p
	leap["t"] = 0.0

## The hang ends on a queued press, a fresh attack press, or when the hover time is up (she comes down at the cursor).
func _wants_down(t: float, xd: Dictionary) -> bool:
	var fire := bool(kit.h.inp.get("fire", false))
	if not fire:
		leap["fire_free"] = true
	var hung := t >= float(xd["min_air"])
	if hung and bool(leap["queued"]):
		return true
	if hung and fire and bool(leap["fire_free"]):
		return true
	return t >= float(xd["hover"])

## The crouch: no steering, but a jump still goes (she takes off from up there) and any speed she had runs out
## under her the way it would (item 51: an ability combines with Shift and a jump).
func _hold_still() -> void:
	kit.h.inp["move"] = Vector2.ZERO

## A Wirerun charging or streaking, or her air dash: Shift pressed in the crouch.
func _moving() -> bool:
	return not kit.wire.is_empty() or kit.run_t > 0.0 or kit.h.roll_t > 0.0

## Up at the take-off spot, `k` of the way to the top: no keys, no gravity, nothing touches her.
func _hold_air(k: float) -> void:
	var h := kit.h
	var from: Vector3 = leap["from"]
	h.inp["move"] = Vector2.ZERO
	h.inp["jump"] = false
	h.gliding = false
	h.vel = Vector3.ZERO
	var y := lerpf(float(leap["base"]), float(leap["top"]), k) + 0.12 * sin(kit.m.time * 3.0) * k
	h.pos = Vector3(from.x, y, from.z)
	_untouchable(0.1)
	if h.is_local() and kit.m.cam:
		kit.m.cam.pull = maxf(kit.m.cam.pull, CAM_PULL * k)

func _untouchable(secs: float) -> void:
	var h := kit.h
	h.inv_t = maxf(h.inv_t, secs)
	h.phase_t = maxf(h.phase_t, secs)

## She launches from where she is: a jump or a dash in the crouch moves the ring there (unless that is over the
## abyss), and the climb starts at her height, so nothing snaps.
func _take_off() -> void:
	var h := kit.h
	var r := float(data()["range"])
	var was: Vector3 = leap["from"]
	if Vector2(h.pos.x - was.x, h.pos.z - was.z).length() > 0.5 and not kit.m.world.is_void(h.pos.x, h.pos.z):
		leap["from"] = kit.ground(h.pos)
		kit.net_ring(leap["from"], r, MageKit.GLOW)
	var from: Vector3 = leap["from"]
	leap["base"] = h.pos.y
	leap["top"] = maxf(from.y + float(data()["height"]), h.pos.y)
	_next(RISE)
	kit.play("mage_x_air")
	kit.vfx("x_rise", from)            # dust kicked out, a bolt up her climb (the range is AimKit's ring, not a fill)
	kit.m.fx.word(h.pos + Vector3(0, 2.6, 0), "INVULNERABLE", MageKit.GLOW, false)
	kit.m.sfx("vv_ult_hum", h.pos, -6.0)
	_untouchable(0.2)

# ------------------------------------------------------------------ aiming the landing
## The ground under the cursor: its ray walked down to the first ground it meets. Hanging 5 m up, inp["aim"] (the
## ray cut at her own height) is metres away from it. Without a ray (a bot, a remote hunter) the aim point is the spot.
func cursor_spot() -> Vector3:
	var ray = kit.h.inp.get("aim_ray")
	if not (ray is Array) or (ray as Array).size() != 2:
		return kit.aim()
	var o: Vector3 = ray[0]
	var d: Vector3 = ray[1]
	if d.y > -0.01:
		return kit.aim()
	var low: float = (leap["from"] as Vector3).y - RAY_BELOW
	var t := maxf(0.0, (((leap["from"] as Vector3).y + RAY_ABOVE) - o.y) / d.y)
	var end := (low - o.y) / d.y
	while t < end:
		var p := o + d * t
		if p.y <= kit.m.world.ground_at(p.x, p.z):
			# (back up the last step in small ones, for the exact spot)
			for i in RAY_FINE:
				var q := o + d * (t - RAY_STEP * float(i) / RAY_FINE)
				if q.y > kit.m.world.ground_at(q.x, q.z):
					return o + d * (t - RAY_STEP * float(i - 1) / RAY_FINE)
			return p
		t += RAY_STEP
	# over the abyss: the plane she took off from (land_point backs off to ground)
	return o + d * (((leap["from"] as Vector3).y - o.y) / d.y)

## Where she would come down: the cursor clamped inside the ring, backed off toward the take-off spot until it
## is standable ground (never a wall, never the abyss).
func land_point() -> Vector3:
	var from: Vector3 = leap["from"]
	var a := cursor_spot()
	var v := Vector2(a.x - from.x, a.z - from.z).limit_length(float(data()["range"]))
	var steps := maxi(1, int(ceil(v.length() / STEP_BACK)))
	for i in steps + 1:
		var u := 1.0 - float(i) / float(steps)
		var p := from + Vector3(v.x * u, 0, v.y * u)
		if not kit.m.world.is_void(p.x, p.z) and not kit.m.world.is_block(p.x, p.z):
			return kit.ground(p)
	return from

## The range ring with its gold rim (everyone sees where she can come down), the dark inside, and the gold
## crown at the cursor (her own).
func _aim_tick() -> void:
	var h := kit.h
	var from: Vector3 = leap["from"]
	var r := float(data()["range"])
	leap["land"] = land_point()
	var ring := {"at": from, "r": r, "ticks": true, "col": MageKit.GLOW, "col2": MageKit.GLOW, "all": true, "lw": 0.1}
	AimKit.circle(h, "x_ring", ring)
	var crown := {"at": leap["land"], "r": float(data()["radius"]) * 0.5, "ticks": true, "star": true}
	crown.merge({"col": MageKit.GLOW, "col2": MageKit.PINK, "hot": 0.5, "lw": 0.09})
	AimKit.circle(h, "x_aim", crown)


# ------------------------------------------------------------------ the strike
func _slam() -> void:
	var land: Vector3 = land_point()
	leap["land"] = land
	leap["high"] = kit.h.pos
	_next(FALL)
	kit.play("mage_x_dive")
	AimKit.hide(kit.h, "x_aim")
	# the landing marker flashes on the spot a beat before she arrives (everyone sees it)
	var mark := {"at": land, "r": float(data()["radius"]), "all": true, "dur": float(data()["drop"]), "fill": 1.0}
	mark.merge({"col": MageKit.GLOW, "col2": MageKit.GLOW, "hot": 0.6})
	AimKit.circle(kit.h, "x_land", mark)
	kit.net_ring(land, float(data()["radius"]), MageKit.GLOW)

## Coming down: a streak of lightning from where she hung onto the marker (the body hides in it).
func _fall_tick(u: float) -> void:
	var h := kit.h
	var a: Vector3 = leap["high"]
	var b: Vector3 = leap["land"]
	h.vel = Vector3.ZERO
	h.inp["move"] = Vector2.ZERO
	h.pos = a.lerp(b, u * u)
	_untouchable(0.1)
	if h.model:
		h.model.visible = u < 0.3
	if h.is_local() and kit.m.cam:
		kit.m.cam.pull = maxf(kit.m.cam.pull, CAM_PULL)

func _strike() -> void:
	var h := kit.h
	var xd := data()
	var at: Vector3 = leap["land"]
	var r := float(xd["radius"])
	h.teleport(at)
	h.vel = Vector3.ZERO
	if h.model:
		h.model.visible = true
	_next(AFTER)
	kit.play("mage_x_land")
	kit.m.later(0.55, kit.gum.blow)      # (once she is back on her feet)
	kit.vfx("x_strike", at, h.aim_dir(), {"r": r})
	kit.m.sfx("vv_ult_slam", at, 1.0)
	Shake.incoming_big(kit.m, at, 0.6, h)
	var struck := kit.foes_in(at, r)
	var shared := _highest_static(struck)
	# (found before the ult's stack lands: that lifts the stacked foe past the count, and the arc lost its source)
	var source: Ent = _static_source(struck, shared)
	var dmg := float(xd["dmg"]) * power()
	for f in struck:
		var away := Vector2(f.pos.x - at.x, f.pos.z - at.z)
		away = away.normalized() if away.length() > 0.1 else h.aim_dir()
		var o := {"src": "abil", "ab": "ult", "tags": ["ult", "kitefall"], "kb": away * float(xd["push"])}
		o["lift"] = float(xd["lift"])
		f.hurt(dmg, h, o)
		_share_static(f, shared, source)
		kit.add_spark(f, int(xd["stacks"]))
		HeroUlt.landed(kit, f)
	hits += struck.size()
	last = {"at": at, "hits": struck.size()}

func _highest_static(struck: Array) -> int:
	var best := 0
	for f in struck:
		best = maxi(best, kit.spark_n(f))
	return best

func _static_source(struck: Array, shared: int) -> Ent:
	for f in struck:
		if shared > 0 and kit.spark_n(f) == shared:
			return f
	return null

## Thunderstorm: when the strike hits a foe carrying Static, every foe it hits is raised to the highest count
## among them (before the ult's own stack), with lightning arcing from the stacked foe to each.
func _share_static(f: Ent, shared: int, source: Ent) -> void:
	var have := kit.spark_n(f)
	if shared <= have or source == null:
		return
	kit.add_spark(f, shared - have)
	spreads += 1
	var chest := Vector3(0, 1.0, 0)
	kit.vfx("x_share", source.position + chest, null, {"to": f.position + chest})

# ------------------------------------------------------------------ ends
## A Boki merge (or a kit swap) mid-cast: she drops straight down where she took off, nothing strikes; the
## cooldown stays spent.
func drop() -> void:
	if leap.is_empty():
		return
	var h := kit.h
	if AIRBORNE.has(phase()):
		h.teleport(leap["from"])
		h.vel = Vector3.ZERO
	if h.model:
		h.model.visible = true
	for id in ["x_ring", "x_aim", "x_land"]:
		AimKit.hide(h, id)
	leap = {}
