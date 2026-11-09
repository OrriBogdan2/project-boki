class_name BjornLunge
extends RefCounted
## Breaker's swing lunge (docs/heroes/bulwark.md, docs/decisions/0022-breaker-swing-lunge.md): every hammer swing
## pulls him forward along the aim from the swing's start to its impact. The pull is added on top of the speed he
## already runs at along the aim (capped at his run speed), so a running swing travels further than a standing one.
## The Crushing Blow pulls "lunge.d" m (a part charge the short end, a full charge the long end), the 360 Smash's
## spin "lunge.spin_d" m; in the air the pull is "lunge.air_k" of that. Each swing's distance, from the swing to
## the end of its slide, is kept for the checks and shown over him with the full performance overlay on.

## s after the lunge's own time it still counts toward the swing's distance: the exit slide settles in this
const SETTLE_T := 0.3
const READOUT_COL := Color("ffe9a8")

var k: BulwarkKit
var h: Hunter
var m: Node
var st := {}                   # the swing being measured: {from, until, kind}
var last_d := 0.0              # (checks, readout) m the last swing moved him, swing to settled
var last_kind := ""            # "blow" | "spin"
var last_air := false
var count := 0                 # (checks) swings measured

func _init(kit: BulwarkKit) -> void:
	k = kit
	h = kit.h
	m = kit.m

func ld() -> Dictionary:
	return k.lmb_def().get("lunge", {})

## m of pull for a Crushing Blow at charge `charge` (0..1).
func blow_d(charge: float) -> float:
	var d: Array = ld().get("d", [1.4, 2.4])
	return lerpf(float(d[0]), float(d[1]), charge)

## Starts a lunge of `dist` m along `dv`, stacking on his run along it. Standing on the ground he moves `dist` in
## all (the dash's exit slide is taken off its pull); running, his run along the aim carries on through it on top.
## In the air the pull is "air_k" of it and he leaves it at the speed he came in with.
func start(dv: Vector2, dist: float, kind: String) -> void:
	var t := float(ld().get("t", 0.22))
	var air := not h.grounded
	if air:
		dist *= float(ld().get("air_k", 0.55))
	else:
		dist = maxf(0.0, dist - HunterMove.slide(minf(dist / t, h.base_speed * HunterMove.dash_exit_run)))
	var run_v := clampf(Vector2(h.vel.x, h.vel.z).dot(dv), 0.0, h.base_speed)
	h.dash_with({"type": "dash", "speed": run_v + dist / t, "time": t, "invuln": 0.0, "dir": dv,
		"trail": "" if air else "dust"})
	k.step_until = m.time + t
	measure(kind)
	if air:
		st["cap_at"] = m.time + t
		st["cap"] = run_v

## Measures the swing's move without a pull of its own: a swing let go in a dash rides the dash.
func measure(kind: String) -> void:
	count += 1
	st = {"from": h.pos, "until": m.time + float(ld().get("t", 0.22)) + SETTLE_T, "kind": kind, "air": not h.grounded}

## Every step: closes the measured swing once it has settled.
func tick() -> void:
	if st.is_empty():
		return
	if st.has("cap") and m.time >= float(st["cap_at"]) and h.roll_t <= 0.0:
		_air_exit(float(st["cap"]))
		st.erase("cap")
	if m.time < float(st["until"]):
		return
	var a: Vector3 = st["from"]
	last_d = Vector2(h.pos.x - a.x, h.pos.z - a.z).length()
	last_kind = String(st["kind"])
	last_air = bool(st["air"])
	st = {}
	if h.is_local() and Settings.fps_mode() == "full":
		var at := h.pos + Vector3(0, HudPlate.plate_offset(h) + 0.4, 0)
		m.fx.word(at, "%s %.1f m" % [last_kind, last_d], READOUT_COL)

## An air lunge hands back only the speed he had along it: in the air nothing brakes the dash's exit, so it
## would carry the pull on until he lands.
func _air_exit(cap: float) -> void:
	var hv := Vector2(h.vel.x, h.vel.z).limit_length(cap)
	h.vel = Vector3(hv.x, h.vel.y, hv.y)
