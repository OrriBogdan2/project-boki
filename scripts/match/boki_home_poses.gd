class_name BokiHomePoses
extends RefCounted
## The poses of a Boki's day at home (GARDEN.md section 4), authored by body plan, not per species: the plan is
## "quad" (legs front and back), "bird" (wings and hind legs) or "legless" (a body that glides or rolls).
## A pose is a set of angle deltas (rx nose up, ry turn left, rz roll; rad) added on top of the baked idle or sleep,
## so every species keeps its own rest shape and mover. `TWEAK` is the per species part.

## Cycles (and so beats) are whole numbers per clip, so each loop closes on itself.
const BEAT := {"munch": 0.5, "nudge": 1.0, "climb": 0.8, "splash": 0.45, "brace": 0.5, "sniff": 0.5}
## species -> clip -> {"amp": factor on the whole motion, "bones": {bone: [rx, ry, rz] held through it}}.
const TWEAK := {
	"cairnback": {"nudge": {"amp": 0.6}, "climb": {"amp": 0.55}, "splash": {"amp": 0.6}},
	"glintmole": {"munch": {"amp": 1.2}, "nap": {"bones": {"head": [-0.15, 0.0, 0.0]}}},
	"puddlet": {"splash": {"amp": 1.35}},
	"rimeshrew": {"splash": {"amp": 1.1}, "nap": {"bones": {"hips": [0.0, 0.1, 0.0]}}},
	"gloamshell": {"nap": {"bones": {"head": [-0.45, 0.0, 0.0], "neck": [-0.25, 0.0, 0.0]}}, "munch": {"amp": 0.7}},
	"selenfin": {"splash": {"amp": 1.4}, "nap": {"bones": {"tail1": [0.0, 0.3, 0.0]}}},
	"glomwort": {"climb": {"amp": 0.7}, "nudge": {"amp": 0.7}},
	"wisplet": {"climb": {"amp": 1.2}},
	"zephyrak": {"climb": {"amp": 1.1}},
	"lodestick": {"climb": {"amp": 0.7}, "nudge": {"amp": 0.8}},
	"mossgrade": {"climb": {"amp": 0.7}, "nudge": {"amp": 0.8}},
	"nettlynx": {"nudge": {"amp": 1.2}, "climb": {"amp": 1.15}},
}
## The stiff and stocky bodies move less in the games' clips (rush, dodge, stonehop and spin).
const STIFF := {"cairnback": 0.6, "glomwort": 0.7, "lodestick": 0.7, "mossgrade": 0.7, "gloamshell": 0.75}
## Tumble's and Echo Steps' clips (BaseTumble, EchoSteps): one shot each, timed by the games' beat data.
const GAME_CLIPS := ["rush", "brace", "dodge", "stonehop", "spin"]
const WING_JOINTS := ["wing1", "wing", "fwing"]
const WING_TIPS := ["wing2", "hwing"]
const TAIL := ["tail1", "tail2", "tail3", "tail4", "tail5", "tail6"]

var names: Dictionary           # the skeleton's bone names
var plan := "quad"
var species := ""
var clip := ""
var amp := 1.0
var d := {}                     # bone -> Vector3(rx, ry, rz)
var move := Vector3.ZERO        # the body's own shift (m)
var squash := Vector3.ONE       # and its scale
var _n := 1

func _init(bone_names: Dictionary, species_id: String) -> void:
	names = bone_names
	species = species_id
	plan = "legless"
	if names.has("fleg1.L") or names.has("m1leg.L"):
		plan = "quad"
	elif names.has("hleg1.L"):
		plan = "bird"

## Everything the clip does at u (0..1 of its length), with `n` beats in it.
func at(which: String, u: float, n := 1) -> void:
	clip = which
	_n = n
	d = {}
	move = Vector3.ZERO
	squash = Vector3.ONE
	var tw: Dictionary = TWEAK.get(species, {}).get(which, {})
	amp = float(tw.get("amp", 1.0))
	if which in GAME_CLIPS:
		amp *= float(STIFF.get(species, 1.0))
	call("_" + which, u)
	for b in tw.get("bones", {}):
		var a: Array = tw["bones"][b]
		add(b, a[0], a[1], a[2])

func add(bone: String, rx: float, ry := 0.0, rz := 0.0) -> void:
	if names.has(bone):
		d[bone] = Vector3(rx, ry, rz) + (d[bone] if d.has(bone) else Vector3.ZERO)

## A pair: rx the same, `sweep` forward and `out` away from the body mirrored (L is -x, R +x).
func both(base: String, rx: float, sweep := 0.0, out := 0.0) -> void:
	if names.has(base + ".L"):
		add(base + ".L", rx, sweep, -out)
		add(base + ".R", rx, -sweep, out)
	else:
		add(base, rx, 0.0, 0.0)

func wings(flap: float, sweep := 0.0) -> void:
	for w in WING_JOINTS:
		both(w, 0.0, sweep, flap)
	for w in WING_TIPS:
		both(w, 0.0, sweep * 0.6, flap * 0.5)

func tail(ry: float, rx := 0.0) -> void:
	for t in TAIL:
		add(t, rx, ry, 0.0)

## Whole cycles of this clip's beat in `length` seconds.
static func cycles(which: String, length: float) -> int:
	return maxi(1, roundi(length / float(BEAT.get(which, 1.0))))

## Settle's and wake's shared rest: the curl of a napper.
func _nap(u: float) -> void:
	var s := sin(TAU * u)
	add("head", -0.2, 0.35)
	add("neck", -0.08, 0.2)
	add("spine", 0.04 * s - 0.05, -0.12)
	tail(0.3, 0.0)
	both("ear1", -0.1, 0.0, -0.12)
	squash = Vector3(1.0, 1.0 + 0.025 * s, 1.0)

func _settle(u: float) -> void:
	var w := smoothstep(0.25, 1.0, u)
	var bow := sin(PI * u)
	_nap(0.0)
	for b in d.keys():
		d[b] *= w
	squash = Vector3.ONE
	move.y = -0.02 * bow
	add("spine", -0.14 * bow)
	add("head", -0.25 * bow)
	both("fleg1", -0.22 * bow)
	both("hleg1", 0.12 * bow)
	wings(-0.1 * bow)

func _wake(u: float) -> void:
	var k := 1.0 - smoothstep(0.35, 0.95, u)
	var st := sin(PI * clampf((u - 0.1) / 0.8, 0.0, 1.0))
	var yawn := sin(PI * clampf((u - 0.55) / 0.35, 0.0, 1.0))
	_nap(0.0)
	for b in d.keys():
		d[b] *= k
	squash = Vector3.ONE
	match plan:
		"quad":
			add("root", -0.28 * st)
			both("fleg1", 0.9 * st)
			both("hleg1", -0.12 * st)
			add("spine", 0.1 * st)
			tail(0.0, -0.45 * st)
		"bird":
			add("root", 0.22 * st)
			both("hleg1", -0.15 * st)
			wings(0.7 * st, 0.15 * st)
		_:
			add("spine", 0.4 * st)
	add("head", 0.25 * st + 0.35 * yawn)
	add("neck", 0.15 * yawn)
	move.y = 0.01 * st

func _munch(u: float) -> void:
	var c := TAU * u * float(_n)
	var chew := sin(c)
	match plan:
		"bird":
			var pk := pow(maxf(0.0, sin(c * 0.5)), 2.0)
			add("spine", -0.5 * pk * amp - 0.12)
			add("neck", -0.4 * pk * amp)
			add("head", -0.5 * pk * amp + 0.08 * chew)
			both("hleg1", 0.25 * pk * amp)
			wings(0.1)
		_:
			add("head", -0.55 * amp + 0.1 * chew)
			add("neck", -0.3 * amp)
			add("spine", -0.12 * amp)
			both("fleg1", 0.12)
			both("ear1", 0.0, 0.0, 0.08 * chew)
			move.y = -0.02 * amp
	tail(0.18 * sin(TAU * u))

func _nudge(u: float) -> void:
	var p := sin(TAU * u * float(_n))
	var lunge := pow(maxf(0.0, p), 2.0) * amp
	var tap := pow(maxf(0.0, sin(TAU * u * float(_n) - 0.5)), 2.0) * amp
	move.z = -0.06 * lunge
	add("head", -0.4 * lunge)
	add("neck", -0.2 * lunge)
	add("spine", -0.1 * lunge)
	match plan:
		"quad":
			add("root", -0.12 * lunge)
			add("fleg1.L", 0.7 * tap)
			add("fleg1.R", 0.7 * pow(maxf(0.0, sin(TAU * u * float(_n) - 3.6)), 2.0) * amp)
			both("hleg1", -0.2 * lunge)
		"bird":
			move.y = 0.03 * lunge
			both("hleg1", 0.3 * lunge)
			wings(0.35 * lunge)
		_:
			add("root", -0.1 * lunge)
	tail(0.3 * sin(TAU * u * float(_n) * 2.0))

func _climb(u: float) -> void:
	var s := sin(TAU * u * float(_n))
	match plan:
		"quad":
			add("root", 0.55 * amp + 0.05 * s)
			add("spine", 0.2 * amp)
			add("head", 0.2)
			add("fleg1.L", (1.3 + 0.5 * s) * amp)
			add("fleg1.R", (1.3 - 0.5 * s) * amp)
			add("hleg1.L", -0.35 * amp - 0.15 * s)
			add("hleg1.R", -0.35 * amp + 0.15 * s)
			move.y = 0.06 * amp + 0.03 * s
			wings(0.5 + 0.3 * s)
		"bird":
			add("root", 0.35 * amp)
			both("hleg1", 0.5 * amp + 0.2 * s)
			move.y = 0.08 * amp + 0.03 * s
			wings(0.6 + 0.6 * sin(TAU * u * float(_n) * 2.0), 0.2)
		_:
			add("root", 0.25 * amp)
			add("spine", 0.5 * amp, 0.25 * s)
			add("head", 0.2)
			move.y = 0.04 * amp + 0.02 * s
			wings(0.5 + 0.5 * sin(TAU * u * float(_n) * 2.0), 0.15)
	tail(0.25 * s)

func _splash(u: float) -> void:
	var s := sin(TAU * u * float(_n))
	var s2 := sin(TAU * u * float(_n) * 2.0)
	move.y = 0.015 * s2 * amp
	add("head", 0.0, 0.35 * s * amp)
	add("root", 0.0, 0.0, 0.08 * s * amp)
	both("ear1", 0.0, 0.0, 0.25 * s2 * amp)
	match plan:
		"quad":
			add("fleg1.L", (0.35 + 0.6 * s) * amp)
			add("fleg1.R", (0.35 - 0.6 * s) * amp)
		"bird":
			wings(0.7 * amp + 0.4 * s2 * amp)
		_:
			add("root", 0.0, 0.0, 0.25 * s * amp)
			add("spine", 0.0, 0.35 * sin(TAU * u * float(_n) + 1.0) * amp)
			add("head", 0.15 * s2 * amp)
	tail(0.5 * sin(TAU * u * float(_n) + 2.0) * amp)

## Rush, over Tumble's charge: u 0..0.6 coils and scrapes (the rival's tell shows this), 0.6..1 lunges and hits.
func _rush(u: float) -> void:
	var coil := smoothstep(0.0, 0.5, u) * (1.0 - smoothstep(0.58, 0.68, u))
	var lunge := smoothstep(0.58, 0.8, u)
	var scrape := sin(TAU * u * 4.0) * coil
	move.y = -0.04 * coil * amp
	move.z = (0.05 * coil - 0.16 * lunge) * amp
	add("head", (-0.3 * coil - 0.1 * lunge) * amp)
	add("neck", -0.15 * coil * amp)
	both("ear1", 0.0, 0.0, (-0.2 * coil - 0.3 * lunge) * amp)
	match plan:
		"quad":
			add("root", (-0.1 * coil - 0.18 * lunge) * amp)
			add("spine", -0.1 * coil * amp)
			add("fleg1.L", (0.6 * maxf(0.0, scrape) - 0.3 * lunge) * amp)
			add("fleg1.R", (0.6 * maxf(0.0, -scrape) - 0.3 * lunge) * amp)
			both("hleg1", (-0.35 * coil - 0.2 * lunge) * amp)
		"bird":
			add("root", (0.2 * coil - 0.3 * lunge) * amp)
			both("hleg1", (0.3 * coil - 0.2 * lunge) * amp)
			wings((0.4 * coil + 0.7 * lunge) * amp, 0.3 * lunge * amp)
		_:
			add("root", (0.3 * coil - 0.35 * lunge) * amp)
			add("spine", (-0.25 * coil + 0.3 * lunge) * amp)
	tail(0.2 * scrape, (0.2 * coil + 0.45 * lunge) * amp)

## Brace, over Tumble's charge: squats low by 0.3 and holds the guard with a shiver (whole cycles, so it loops clean).
func _brace(u: float) -> void:
	var s := smoothstep(0.0, 0.3, u)
	var shiver := sin(TAU * u * float(_n)) * 0.03 * s
	move.y = -0.07 * s * amp
	squash = Vector3(1.0 + 0.06 * s * amp, 1.0 - 0.1 * s * amp, 1.0 + 0.06 * s * amp)
	add("head", -0.3 * s * amp, shiver)
	add("neck", -0.12 * s * amp)
	both("ear1", 0.0, 0.0, -0.4 * s * amp)
	match plan:
		"quad":
			both("fleg1", 0.25 * s * amp, 0.0, 0.3 * s * amp)
			both("hleg1", -0.15 * s * amp)
			add("spine", -0.12 * s * amp)
		"bird":
			wings(-0.5 * s * amp, 0.4 * s * amp)
			add("root", -0.12 * s * amp)
		_:
			add("spine", -0.3 * s * amp)
	tail(-0.35 * s * amp + shiver * 4.0)

## Dodge, over Tumble's charge: footwork sway while it comes (0..0.6), a crouch, a hop aside as it lands (0.68..0.94).
func _dodge(u: float) -> void:
	var sway := sin(TAU * u * 3.0) * (1.0 - smoothstep(0.45, 0.62, u))
	var crouch := smoothstep(0.5, 0.66, u) * (1.0 - smoothstep(0.66, 0.7, u))
	var air := sin(PI * clampf((u - 0.68) / 0.26, 0.0, 1.0))
	var land := sin(PI * clampf((u - 0.94) / 0.06, 0.0, 1.0))
	move.y = (0.2 * air - 0.04 * crouch) * amp
	move.x = (0.16 * air + 0.03 * sway) * amp
	var sq := (crouch + land) * amp
	squash = Vector3(1.0 + 0.08 * sq, 1.0 - 0.12 * sq, 1.0 + 0.08 * sq)
	add("head", 0.15 * air * amp, 0.3 * air * amp)
	add("root", 0.0, 0.0, (0.3 * air + 0.06 * sway) * amp)
	both("ear1", 0.0, 0.0, 0.3 * air * amp)
	match plan:
		"quad":
			both("fleg1", (0.8 * air + 0.2 * sway) * amp)
			both("hleg1", -0.5 * air * amp)
		"bird":
			wings(0.9 * air * amp, 0.2 * air * amp)
			both("hleg1", 0.4 * air * amp)
		_:
			add("spine", 0.4 * air * amp, 0.3 * sway * amp)
	tail(0.5 * air * amp + 0.2 * sway)

## Stone hop, over one hop (Echo Steps' hop_s): squashed on the stone at both ends, legs tucked at the top. The base
## draws the arc, so the clip only shapes the body.
func _stonehop(u: float) -> void:
	var up := sin(PI * u)
	var low := 1.0 - up
	squash = Vector3(1.0 + 0.08 * low * amp, 1.0 - 0.12 * low * amp, 1.0 + 0.08 * low * amp)
	add("head", 0.2 * up * amp)
	both("ear1", 0.0, 0.0, 0.3 * up * amp)
	match plan:
		"quad":
			both("fleg1", 0.6 * up * amp)
			both("hleg1", -0.5 * up * amp)
		"bird":
			wings(0.8 * up * amp)
			both("hleg1", 0.5 * up * amp)
		_:
			add("spine", 0.35 * up * amp)
	tail(0.0, 0.3 * up * amp)

## Spin, over two beats of Echo Steps' bpm: one full turn on the spot, a little lift, arms or wings out.
func _spin(u: float) -> void:
	var up := sin(PI * u)
	add("root", 0.0, TAU * smoothstep(0.0, 1.0, u))
	move.y = 0.1 * up * amp
	add("head", 0.15 * up * amp)
	both("ear1", 0.0, 0.0, 0.35 * up * amp)
	match plan:
		"quad":
			both("fleg1", 0.5 * up * amp, 0.0, 0.3 * up * amp)
			both("hleg1", -0.3 * up * amp)
		"bird":
			wings(0.9 * up * amp)
		_:
			add("spine", 0.3 * up * amp)
	tail(0.7 * up * amp)

## The nose-down walk of Seek, laid over the walk: head and neck low, a nod a step, ears back, tail low.
func _sniff(u: float) -> void:
	var c := TAU * u * float(_n)
	var nod := sin(c)
	match plan:
		"bird":
			add("spine", -0.3 * amp)
			add("neck", -0.45 * amp + 0.1 * nod)
			add("head", -0.5 * amp + 0.12 * nod)
			wings(-0.1)
		"quad":
			add("root", -0.1 * amp)
			add("spine", -0.1 * amp)
			add("neck", -0.4 * amp + 0.08 * nod)
			add("head", -0.55 * amp + 0.14 * nod)
			both("ear1", 0.0, 0.0, 0.12)
		_:
			add("spine", -0.3 * amp)
			add("head", -0.5 * amp + 0.14 * nod)
	tail(0.0, -0.2 * amp)

## The Dash's jump over the gap, laid over the run: forelegs reach, hind legs trail, the back arches, one stretch.
func _leap(u: float) -> void:
	var s := sin(TAU * u)
	match plan:
		"bird":
			add("root", 0.15 * amp)
			both("hleg1", -0.5 * amp)
			wings(0.9 * amp + 0.35 * sin(2.0 * TAU * u), 0.15)
		"quad":
			both("fleg1", 0.8 * amp)
			both("hleg1", -0.7 * amp)
			add("spine", -0.12 * amp)
			add("head", 0.18 * amp)
			wings(0.6 + 0.3 * s)
		_:
			add("spine", -0.25 * amp, 0.15 * s)
			add("head", 0.2 * amp)
	tail(0.1 * s, -0.25 * amp)

## Spark Volley's swing over a hop: wind the near fore limb up, snap it down through the seed, body twisting with it.
func _bat(u: float) -> void:
	var wind := sin(PI * clampf(u / 0.5, 0.0, 1.0))
	var hit := smoothstep(0.45, 0.6, u) * (1.0 - smoothstep(0.7, 1.0, u))
	match plan:
		"bird":
			wings(1.0 * wind * amp - 0.7 * hit * amp, 0.2 * hit)
		"quad":
			add("fleg1.R", 1.8 * wind * amp - 1.1 * hit * amp)
			add("fleg1.L", 0.3 * wind * amp)
			add("spine", -0.2 * hit * amp, -0.35 * hit * amp)
			add("head", -0.2 * hit * amp)
		_:
			add("spine", 0.3 * wind * amp - 0.5 * hit * amp, 0.4 * hit * amp)
			add("head", -0.2 * hit * amp)
	tail(0.4 * hit)
