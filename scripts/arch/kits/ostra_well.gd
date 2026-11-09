class_name OstraWell
extends RefCounted
## Ostra's ultimate on X, Nightwell (HeroUlt): tap X to set a well at the cursor (clamped, on ground short of
## walls). A pale dome of its exact size shows to everyone for 1.0s, then it opens into a turning violet
## disc for 3.5s: every foe inside (or who walks in) is stunned until it closes and drawn to its centre,
## taking a small tick every 0.1s. Allies pass through untouched. Ostra is locked in the cast pose for the dome
## (data x.tell, Void's 1.0s telegraph): no moving, no other abilities or attacks, and no turning once the short
## wind-up (data x.wind) is over. When it opens he clenches it in and is free to move or leave while
## it keeps going. A hard CC or a merge frees him early.
## Swollen, it is larger. It closes quietly, with no blast. Bond: each hunter it catches counts as a land
## (HeroUlt.landed), paid on the catch, never per tick. Its looks hang on the match, not on Ostra, so a
## merge or a knock on his doesn't take the placed well down.

const DOME_COL := Color("a8e4ff")
const DISC_COL := Color("b06bff")
const PINK := Color("ff4fd8")
const TICK := 0.1                       # s between damage ticks
const HOLD_R := 0.25                    # m from the centre where a caught body stops being drawn in
const GATHER_Y := 2.4                   # m over his ground point: the orb above his raised hands

var k: OstraKit
var phase := ""                         # "" | "tell" (the dome) | "open" (the well)
var phase_t := 0.0
var center := Vector3.ZERO
var radius := 0.0
var swollen := false
var tick_left := 0.0
var caught := {}                        # instance id -> the body, for this cast
var draws: Array = []                   # the Displace tows drawing the caught in
var locked := false                     # Ostra is held in the cast pose
var aim_lock := Vector2.ZERO            # the facing kept after the wind-up (ZERO until then)
var lock_t := 0.0                       # s since the press
var dash_held := false                  # Shift pressed during the lock: it goes when he is freed
# counters for the checks
var casts := 0
var opens := 0
var caught_hunters := 0
var ticks := 0
var denied := 0

func _init(kit: OstraKit) -> void:
	k = kit

func xd() -> Dictionary: return k.x_def()

func running() -> bool: return phase != ""

func is_open() -> bool: return phase == "open"

func start() -> bool:
	if running():
		return false
	var pw := HeroZones.walk(k.m, k.h.pos, k.aim(), float(xd()["range"]))
	if not pw["ok"]:
		denied += 1
		if k.h.is_local() and k.m.hud:
			k.m.hud.toast_small("No ground for the well", k.col_of(xd()))
		return false
	center = pw["pos"]
	swollen = k.is_swollen()
	radius = float(xd()["r_swollen"]) if swollen else float(xd()["r"])
	caught = {}
	phase = "tell"
	phase_t = 0.0
	locked = true
	aim_lock = Vector2.ZERO
	lock_t = 0.0
	casts += 1
	k.play("ostra_well")
	k.m.sfx("os_well", center, -2.0, 1.0)
	k.net_ring(center, radius, DOME_COL)
	return true

func tick(dt: float) -> void:
	_tick_lock(dt)
	match phase:
		"tell":
			_tick_tell(dt)
		"open":
			_tick_open(dt)

## The lock: facing is kept once the wind-up is over; a stun or a knock frees him (the well itself goes on).
func _tick_lock(dt: float) -> void:
	if not locked:
		return
	if k.h.downed or k.h.out or k.h.stun_t > 0.0 or k.h.knock_t > 0.0:
		unlock()
		return
	lock_t += dt
	if aim_lock == Vector2.ZERO and lock_t >= float(xd()["wind"]):
		aim_lock = k.h.aim_dir()
	_hand_looks()

## What he holds while locked: a black orb swelling over his raised hands as the dome fills.
func _hand_looks() -> void:
	var grown := clampf(phase_t / float(xd()["tell"]), 0.0, 1.0)
	var ahead := k.h.aim_dir() * 0.35
	var over := k.h.pos + Vector3(ahead.x, GATHER_Y, ahead.y)
	KitLooks.of(k.m).hold_on("os_well_gather", "dark", k.h, over, lerpf(0.5, 1.6, grown))

## Shift during the lock (content/dash_flow/ostra.json into_dash.x, "buffer"): held for the step the well
## opens and frees him.
func press_dash() -> void:
	dash_held = true

## Frees Ostra from the cast pose (the well stays); the opening, a merge or a CC ends it. `move` is the move
## he leaves it with. A Shift held for the release goes now (a merge drops it: `go_dash` false).
func unlock(go_dash := true, move := "ostra_well_end") -> void:
	if not locked:
		return
	locked = false
	aim_lock = Vector2.ZERO
	k.play(move)
	KitLooks.of(k.m).release("os_well_gather")
	var go := dash_held and go_dash
	dash_held = false
	if go:
		k.on_dash(false)

## The dome: everyone sees the well's exact size filling over the 1.0s before it opens.
func _tick_tell(dt: float) -> void:
	phase_t += dt
	var tell := float(xd()["tell"])
	var accent := PINK if swollen else DISC_COL
	AimKit.circle(k.h, "x", {
		"at": center, "r": radius, "fill": phase_t / tell, "all": true, "col": DOME_COL, "col2": accent,
		"ticks": true,
	})
	var dome := KitLooks.of(k.m).hold_on("os_well_dome", "well_dome", k.m, center, radius)
	(dome.get_node("Core") as Node3D).visible = swollen
	if phase_t >= tell:
		_open()

func _open() -> void:
	AimKit.hide(k.h, "x")
	KitLooks.of(k.m).release("os_well_dome")
	phase = "open"
	phase_t = 0.0
	tick_left = 0.0
	opens += 1
	unlock(true, "ostra_well_snap")
	k.m.sfx("os_well_hum", center, -3.0, 1.0)
	k.m.fx.flash(center + Vector3(0, 0.6, 0), Color("e8d8ff"), 1.4, 0.1)
	k.m.fx.ring(center, radius, DISC_COL, 0.25)

func _tick_open(dt: float) -> void:
	phase_t += dt
	var dur := float(xd()["time"])
	var left := dur - phase_t
	var disc := KitLooks.of(k.m).hold_on("os_well", "well", k.m, center + Vector3(0, 0.04, 0), radius)
	KitLooks.well_set(disc, phase_t, swollen)
	tick_left -= dt
	if tick_left <= 0.0:
		tick_left += TICK
		_tick_catch(left)
	if left <= 0.0:
		_close()

## Every 0.1s: anyone inside (in sight of the centre) is nicked; the first time, caught and stunned until the
## well closes (one stun, so the status word shows once).
func _tick_catch(left: float) -> void:
	ticks += 1
	var dmg := float(xd()["tick_dmg"]) * k.power("x")
	for f in k.foes_in(center, radius):
		if not k.m.world.los(center + Vector3(0, 0.6, 0), f.pos + Vector3(0, 0.6, 0), center.y + 0.6):
			continue
		var hit := {"src": "abil", "ab": "x"}
		var first := not caught.has(f.get_instance_id())
		if first:
			hit["stun"] = maxf(left, TICK)
		caught[f.get_instance_id()] = f
		f.hurt(dmg, k.h, hit)
		if first:
			_on_catch(f)

## A caught body is drawn to the centre (Displace: online, its own game draws it in), held there until it closes.
func _on_catch(f: Ent) -> void:
	KitLooks.of(k.m).crown(f, float(xd()["time"]))
	var c := _floor(center)
	draws.append(k.m.displace.tow(f, null, {
		"mode": "glide", "to": [c.x, c.y, c.z], "spd": float(xd()["pull"]), "gap": HOLD_R, "hold": true,
		"dur": maxf(float(xd()["time"]) - phase_t, TICK)}))
	if f is Hunter:
		caught_hunters += 1
		HeroUlt.landed(k, f)

func _floor(p: Vector3) -> Vector3:
	return Vector3(p.x, k.m.world.ground_at(p.x, p.z), p.z)

## It just stops: the whirlpool goes at once and a small ring folds in, nothing bursts.
func _close() -> void:
	phase = ""
	KitLooks.of(k.m).release("os_well")
	for rec in draws:
		k.m.displace.stop(rec)
	draws = []
	k.m.fx.ring(center, radius * 0.4, DISC_COL, 0.2)
	k.m.fx.burst(center + Vector3(0, 0.3, 0), Color("2a0a3a"), 10, -3.0, 0.3, 0.0, 0.9)
