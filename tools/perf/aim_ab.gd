extends RefCounted
## --bench-ab-aim for --bench-fight (tools/perf_fight.gd): what AimGeo's kept telegraph points save, read inside ONE
## run so pod load and the fight's own variation cancel. The fight alternates blocks of BLOCK frames with the points
## kept (new) and looked up again every frame (old, AimGeo.keep_points off); the aim_draw.gd _process time of every
## frame after SKIP warm-up frames of a block goes to that variant.
## Prints "BENCH ab aim: <variant> aim_draw <ms> over <n> frames".

const BLOCK := 45
const SKIP := 3
const NAMES := ["old", "new"]

var mode := -1
var since := 0
var last_us := 0
var us := [0, 0]
var n := [0, 0]


## Called once per frame before the step, with the running aim_draw.gd total: the change since the last call is the
## frame just drawn, under the variant it was drawn with.
func frame(f: int, aim_total_us: int) -> void:
	if mode >= 0 and since >= SKIP:
		us[mode] += aim_total_us - last_us
		n[mode] += 1
	last_us = aim_total_us
	since += 1
	if f % BLOCK == 0:
		mode = (f / BLOCK) % NAMES.size()
		since = 0
		AimGeo.keep_points = mode == 1


func report() -> void:
	AimGeo.keep_points = true
	var ms := [0.0, 0.0]
	for i in NAMES.size():
		ms[i] = us[i] / 1000.0 / maxi(n[i], 1)
	for i in NAMES.size():
		print(
			"BENCH ab aim: %s aim_draw %.3f ms over %d frames (%+.3f vs old)" % [NAMES[i], ms[i], n[i], ms[i] - ms[0]]
		)
