extends RefCounted
## --move-feel-check, dashing off a ledge (HunterMove.dash_off_ledge): every Hunter's ground dash run off a 3.2 m
## terrace edge (four terraces) beside the flat test spot. A row per kit, plus the held and chained dashes (Vex's
## held slide, Grimble's three barges, Tenzo's Rock Hop chain). Asserted, as the source plays it: no stop at the lip,
## no height hold (the dash falls as it goes), it ends in the air at least at the shared exit speed, its ground pose
## is cut there, the glider is free within two steps of the end, and a Shift press then fires the air dash.
## Motley's Shift is the Trade (a lob, no travel of his own): it must take him down onto a spot below the edge.

const DT := 1.0 / 60.0
const EXIT_MIN := 0.75  # x run speed: the least a dash may leave you in the air (the old barge plant left 0.65)
## A fitted dash curve (decision 0025: Vex, Kael, Lace) bleeds off through run speed by design, so for those the
## least is the lower of EXIT_MIN and the curve's own end (u = 1): only a cut on top of the curve fails.
const AIR_WAIT := 24  # steps (0.4 s): Grimble's barges go "a beat apart" (dash gap)
const RUNS := [
	["gunslinger", "tap", 0.8],
	["gunslinger", "hold", 2.5],
	["juggernaut", "tap", 0.8],
	["ashwick", "tap", 0.8],
	["tender", "tap", 0.8],
	["dolm", "tap", 1.6],
	["dolm", "chain", 4.0],
	["dolm", "chain", 3.1],
	["archer", "tap", 0.8],
	["dredge", "tap", 0.8],
	["dredge", "chain", 5.8],
	["rimewright", "tap", 0.8],
	["mage", "tap", 0.8],
	["bulwark", "tap", 0.8],
	["thief", "tap", 0.8],
	["ostra", "trade", 0.8],
]

var c  # the move-feel check (its hunter, world and ok())
var p: Hunter
var edge_x := 0.0  # the terrace's edge (x), walked off along +x
var top := 0.0
var low := 0.0


func _init(check) -> void:
	c = check
	p = check.p_v


func run() -> void:
	var w: World = c.w
	var x0 := int(floor(c.flat.x))
	var z0 := int(floor(c.flat.z))
	var lv := int(w.level[w.idx(x0, z0)])
	var carved := []
	for dz in range(-3, 4):
		for dx in range(-8, 1):
			var ci := w.idx(x0 + dx, z0 + dz)
			carved.append([ci, w.level[ci]])
			w.level[ci] = lv + 4
	edge_x = x0 + 1.0
	top = w.ground_at(x0 + 0.5, z0 + 0.5)
	low = w.ground_at(edge_x + 2.5, z0 + 0.5)
	var was := [p.cls, p.arch, p.wid]
	for r in RUNS:
		_row(String(r[0]), String(r[1]), float(r[2]), Vector3(edge_x - float(r[2]), top, z0 + 0.5))
	p.reclass(was[0], was[1], was[2])
	for cv in carved:
		w.level[int(cv[0])] = cv[1]


func _ready_at(id: String, at: Vector3) -> void:
	for wl in c.m.verbs.walls.duplicate():
		c.m.verbs._break_wall(wl)  # (the last run's rocks)
	p.spirit_t = 0.0  # (Lace's tap is a Spirit Walk: a kit swap mid-walk would carry it into the next rows)
	if p.arch != id:
		p.reclass(Arch.weight(id), id, Arch.signature(id))
	c._reset(at)
	p.ak.drop_holds()  # (the last run's chain: a Rock Hop still mid-chain would take this run's first press)
	p.inp["aim"] = Vector3(edge_x + 3.0, low, at.z)
	p.inp["move"] = Vector2(1, 0)


func _dashing() -> bool:
	return p.roll_t > 0.0 or p.ak.in_dash()


## One run: Shift toward the edge (tapped, held, or pressed again every 4 steps for a chain), measured until the
## landing below. air_press: from the step after the dash ends, Shift is pressed every step for AIR_WAIT steps with a
## charge back in hand (the air dash run: is it free, or a beat after as the kit's own gap allows).
func _run(id: String, mode: String, at: Vector3, air_press: bool) -> Dictionary:
	_ready_at(id, at)
	var o := {
		"lip_v": 0.0,
		"hover": 0,
		"end": -1,
		"end_air": false,
		"exit_v": 0.0,
		"glide": -1,
		"pose": 0,
		"air_crash": 0,
		"air_dash": false,
		"air_wait": -1,
		"landed": false,
		"tail_v": 0.0
	}
	var off := false
	var was := false
	for i in 150:
		var air_try := air_press and int(o["end"]) >= 0 and i > int(o["end"]) and i <= int(o["end"]) + AIR_WAIT
		if air_try and i == int(o["end"]) + 1:
			p.dashes = p.max_dashes()
		var chain_press := mode == "chain" and i % 4 == 0 and not off
		var air_tap := air_try and not bool(o["air_dash"]) and (i - int(o["end"])) % 2 == 1  # (a tap, not a hold)
		p.inp["dash"] = i == 0 or chain_press or air_tap
		p.inp["dash_down"] = i == 0 or mode == "hold" or bool(p.inp["dash"])
		var v0 := Vector2(p.vel.x, p.vel.z).length()
		var crashes := (p.ak as DolmKit).leap_lands if p.ak is DolmKit else 0
		c.m.step(DT)
		var now := _dashing()
		var cv: Dictionary = p.ak.curved
		if now and not cv.is_empty():
			o["tail_v"] = float(cv["speed"]) * HunterMove.dash_k(cv["curve"], 1.0) * Loco.dash_speed(id)
		if not off and not p.grounded and p.pos.x > edge_x:
			off = true
			o["lip_v"] = v0
		if off and not p.grounded:
			if p.roll_t > 0.0 and absf(p.vel.y) < 0.01 and p.pos.y < top + 0.05:
				o["hover"] = int(o["hover"]) + 1
			if p.ak is DolmKit and (p.ak as DolmKit).leap_lands > crashes:
				o["air_crash"] = int(o["air_crash"]) + 1
		if off and was and not now and int(o["end"]) < 0:
			o["end"] = i
			o["end_air"] = not p.grounded
			o["exit_v"] = Vector2(p.vel.x, p.vel.z).length()
		elif int(o["end"]) >= 0 and not p.grounded:
			if int(o["glide"]) < 0 and p.can_glide():
				o["glide"] = i - int(o["end"])
			if i == int(o["end"]) + 1 and p.ak.anim_id != "" and p.ak.anim_at >= p.ak.dash_press_at:
				o["pose"] = 1
			if air_try and now and not was:
				o["air_dash"] = true
				o["air_wait"] = i - int(o["end"])
		was = now
		if off and p.grounded and p.pos.y < low + 0.05:
			o["landed"] = true
			if not air_press:
				break
	return o


func _row(id: String, mode: String, back: float, at: Vector3) -> void:
	var o := _run(id, mode, at, false)
	var what := "%s %s, %.1f m from the edge" % [id, mode, back]
	if mode == "trade":
		c.ok(bool(o["landed"]), "ledge_dash %s: the Trade takes him down below the edge" % what)
		return
	var exit_k := float(o["exit_v"]) / p.base_speed
	var least_k := EXIT_MIN if float(o["tail_v"]) <= 0.0 else minf(EXIT_MIN, float(o["tail_v"]) / p.base_speed)
	if id == "dolm":
		# Rock Hop is a chain of hops (arcs, not a slide): it must leave the terrace at least at run speed (a hop
		# aimed down the lip still springs up; a skid that runs off it goes at run speed: the 3.1 m chain's first
		# landing skids to the lip), never crash in the air (the crash and the next hop wait for the ground below)
		# and come down there. (2%: the skid's last step ends mid-step.)
		c.ok(
			bool(o["landed"]) and float(o["lip_v"]) >= p.base_speed * 0.98 and int(o["air_crash"]) == 0,
			(
				"ledge_dash %s: lip %.1f m/s, crashes in the air %d, lands below %s"
				% [what, float(o["lip_v"]), int(o["air_crash"]), str(o["landed"])]
			)
		)
		return
	# (Dredge's chain: a press made just before the lip is held through the 0.1 s gap and goes in the air, an air
	# pounce that holds its height for its own 0.2 s: 12 steps, and the exit below is the one that follows it)
	var hover_max := 13 if id == "dredge" and mode == "chain" else 1
	var ok := (
		bool(o["landed"])
		and int(o["hover"]) <= hover_max
		and bool(o["end_air"])
		and exit_k >= least_k - 0.01
		and int(o["glide"]) >= 0
		and int(o["glide"]) <= 2
		and int(o["pose"]) == 0
	)
	var air := _run(id, mode, at, true)
	ok = ok and bool(air["air_dash"])
	var fmt := (
		"ledge_dash %s: lip %.1f m/s, held height %d steps, ends in the air %s at %.3fx run (least %.3fx), "
		+ "glider in %d steps, ground pose after %d, air dash %s (%d steps)"
	)
	c.ok(
		ok,
		(
			fmt
			% [
				what,
				float(o["lip_v"]),
				int(o["hover"]),
				str(o["end_air"]),
				exit_k,
				least_k,
				int(o["glide"]),
				int(o["pose"]),
				str(air["air_dash"]),
				int(air["air_wait"])
			]
		)
	)
