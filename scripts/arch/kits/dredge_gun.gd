class_name DredgeGun
extends RefCounted
## Grimble's LMB, the scattergun, dressed (the weapon itself fires the slugs): each new volley rocks the body back,
## flashes the muzzle and dresses its slugs (pink streaks that hang as violet dots where they stop). While firing,
## the spread's two edge lines lie on the ground out to the slug range at the gun's real fan (fan_deg + bloom):
## each shot springs them wide, they breathe back in as the bloom settles and turn brass when the next shot will be
## at its tightest; at rest they fold into one aim line.

const SLUG_COL := Color("ff4fa8")      # a hot pink streak in flight
const SLUG_CORE := Color("ffd0ec")
const SLUG_REST := Color("7a4aff")     # a slug hanging at its stop line: solid violet, dark core
const IDLE_T := 0.35                   # s the spread lines hold tight once the bloom settles, before they fold
const FOLD_T := 0.25                   # s the rested spread lines take to fold into the one aim line
const SPREAD_HZ := 5.0                 # Hz: the spread lines' spring (stiff, so they track the gun's real fan)
const SPREAD_DAMP := 0.6               # its damping ratio: a shot's kick overshoots a little, then holds
const SPREAD_COL := Color("fff0f6")    # the spread lines while the fan is wide: a dim pink-white
const TIGHT_COL := Color("e0b040")     # ... and back at its tightest (shoot now): his brass

var k: DredgeKit
var shot_seen := 0              # the last weapon volley dressed
var shot_at := -9.0
var busy_at := -9.0             # the gun last fired, was held or still had bloom (the lines show till IDLE_T after)
var spread_deg := 0.0           # the spread lines' drawn angle: springs to the gun's real fan, 0 when folded
var spread_v := 0.0

func _init(kit: DredgeKit) -> void:
	k = kit

func tick(dt: float) -> void:
	var h := k.h
	if h.wid != "shotgun" or KinMerge.active(h):
		return
	if h.shot_n != shot_seen:
		shot_seen = h.shot_n
		shot_at = k.m.time
		k.volleys += 1
		_dress_volley()
	if not k.pull.is_empty() or h.downed:
		return
	var w: Dictionary = h.wpn
	var rest := float(w.get("fan_deg", 30.0))
	if bool(h.inp.get("fire", false)) or h.wbloom > 0.0:
		busy_at = k.m.time
	var step := minf(dt, 1.0 / 30.0)
	if k.m.time - busy_at < IDLE_T:
		var sw := TAU * SPREAD_HZ
		spread_v += (sw * sw * (rest + h.wbloom - spread_deg) - 2.0 * SPREAD_DAMP * sw * spread_v) * step
		spread_deg = maxf(0.0, spread_deg + spread_v * step)
	else:
		spread_v = 0.0
		spread_deg = move_toward(spread_deg, 0.0, rest / FOLD_T * dt)
	if spread_deg <= 0.5:
		AimKit.line(h, "spread_idle", {"col": SPREAD_COL, "alpha": 0.7})
		return
	var tight := 1.0 - clampf((spread_deg - rest) / float(w.get("bloom_deg", 1.0)), 0.0, 1.0)
	AimKit.cone(
		h, "spread",
		{
			"len": float(w["range"]), "deg": spread_deg, "edges": true, "inner": 0.6,
			"col": SPREAD_COL.lerp(TIGHT_COL, tight), "alpha": lerpf(0.6, 1.1, tight), "hot": 0.2 * tight
		}
	)

func _dress_volley() -> void:
	var h := k.h
	k.play("dr_shot")
	var d2 := h.aim_dir()
	var mz := h.pos + Vector3(d2.x, 0, d2.y) * 1.05 + Vector3(0, 1.0, 0)
	k.fx.orb(mz, DredgeKit.BRASS, DredgeKit.BRASS_HOT, 0.75, 0.07)          # a brass muzzle flash, one frame
	k.fx.sunburst(mz, 0.6, Color("ff8a3a"), DredgeKit.BRASS_HOT, 0.08, true)
	k.m.sfx("dr_shot", h.pos, -5.0 if h.is_local() else -8.0, 1.0)
	if not k.tells_visible():
		return
	var key := "%s_%d" % [h.nid, h.shot_n]
	var i: int = k.m.shots.size() - 1
	var seen := 0
	while i >= 0 and seen < 14:
		var sd: Dictionary = k.m.shots[i]
		i -= 1
		seen += 1
		if sd.get("by") != h or String((sd["x"] as Dictionary).get("pg", "")) != key:
			continue
		k.fx.ride(sd, "slug", SLUG_COL, SLUG_CORE, 0.9, 0.2, func(at: Vector3, expired: bool):
			if expired: k.fx.dot(at, SLUG_REST, 0.26))
