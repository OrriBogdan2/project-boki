extends RefCounted
## Grimble's scattergun by range, for --dredge-combo-check (docs/heroes/dredge.md, "Scattergun by range"):
## the burst's aimed first volley and a fully bloomed one at a dummy 2 m, 6 m and at the slugs' stop range.
## The source has 7 slugs and no damage
## falloff with range (only the fixed stop range), so a volley is the same total whatever the distance, shared
## by the pellet rule (the first slug on a target does `pellet_floor` of the volley, the rest split the
## remainder); only how many slugs land changes.

const FACE_TOWARD := -PI / 2.0      # a target east of Grimble facing this way shows him its front

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func run() -> void:
	var r: Array = ak.setup("dredge", 2.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var w: Dictionary = P.wpn
	var pel := int(w["pellets"])
	var full: float = float(w["dmg"]) * pel * m.dmg_mult(P)
	var stop: float = float(w["range"])
	var hit_r: float = T.r + float(w["size"])
	var fan: float = float(w["fan_deg"])
	var shape_ok: bool = pel == 7 and absf(stop - 6.3) < 0.01 and absf(fan - 20.0) < 0.01
	var bloom_max: float = float(w["bloom_max_deg"])
	shape_ok = shape_ok and absf(fan + bloom_max - 30.0) < 0.01
	var shape := "%d slugs, stop %.1f m, fan %.0f degrees" % [pel, stop, fan]
	var shape_label := "gun range: 7 slugs, stop 6.3 m, a fan of 20 degrees after the aimed first volley, 30 at most"
	ok_fn.call(shape_label, shape_ok, shape)
	for bloom: float in [0.0, bloom_max]:
		# the first volley of a burst (no bloom yet) flies straight down the aim line (`aimed_first`)
		var spread: float = 0.0 if bloom == 0.0 and w.get("aimed_first", false) else fan + bloom
		for d: float in [2.0, 6.0, stop - 0.1]:
			_volley(m, P, T, home, d, bloom, spread, full, hit_r)
	await ak.done(m)

## Fires one volley at bloom `bloom` (fan `spread` degrees) at a fresh dummy `d` m east of `home`; checks its damage.
func _volley(
	m: Match, P: Hunter, T: Hunter, home: Vector3, d: float, bloom: float, spread: float, full: float, hit_r: float
) -> void:
	var w: Dictionary = P.wpn
	var pel := int(w["pellets"])
	var landed := 0                   # the slugs whose line passes within the dummy's reach at this distance
	for i in pel:
		var off := deg_to_rad(spread) * (float(i) / float(pel - 1) - 0.5)
		if absf(d * tan(off)) <= hit_r:
			landed += 1
	var floor_k: float = float(w["pellet_floor"])
	var want := full * (floor_k + (landed - 1) * (1.0 - floor_k) / float(pel - 1))
	ak.fresh(T)
	T.teleport(home + Vector3(d, 0, 0))
	T.face = FACE_TOWARD
	P.wbloom = bloom
	P.idle_fire = 0.0              # mid-burst: off the trigger under the reset beat, so the bloom holds
	P.fire_cd = 0.0
	ak.aim_at(P, T.pos)
	P.inp["fire"] = true
	ak.step(m, ak.DT)
	P.inp["fire"] = false
	ak.step(m, 0.8)
	var got: float = ak.dmg(T)
	var label := "gun range: a %.0f degree volley at %.1f m lands %d of 7 slugs for %.1f of the %.1f volley, no falloff"
	ok_fn.call(label % [spread, d, landed, want, full], landed >= 1 and absf(got - want) < 0.15, "got %.2f" % got)
