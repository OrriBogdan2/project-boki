extends RefCounted
## --move-feel-check's ice rows (decision 0060): the same stop, 90-degree turn, knock slide and every kit's
## plain dash on bare ground, on an Ice Sheet with a plain Boki and on one with a frost Boki (full footing).
## The sheet is added over a flat spot so every run has the same room, and comes out again after. A run is read
## until the hunter stands still. Prints "MFEEL ice ..." rows, then asserts them through the move-feel check `c`.

const FROST := "floenatee"      # theme frost: counters the sheet
const PLAIN := "cindle"          # venom: counters nothing
const ROOM := 12.0               # m: half-width of the sheet round the flat spot
const STILL := 0.05              # m/s: below this the hunter stands
const CAP := 600                 # steps (10 s) a run is read for before giving up on it
const ROWS := ["ground", "ice", "frost"]
const SAME_M := 0.02             # m: a dash travels the same on any footing, and a frost Boki's rows match the ground's
const STOP_MAX_S := 1.0          # s: a let-go from a run is still over within a second on ice
const STOP_MAX_M := 2.5          # m: and inside a body-length or two of road
const TURN_MAX_S := 0.7          # s: a 90 degree turn on ice is slow (ground 0.12) but there
const KNOCK_MAX_M := 8.0         # m: a 10 m/s knock on ice slides out within this
const DASH_SLIDE_MAX_M := 2.5    # m: what a kit dash hands over at run speed slides on ice
const SPIN_SLIDE_MAX_M := 9.0    # m: Bulwark's 360 Smash adds a 6 m/s spin glide on top (kit change: docs/DEBT.md)

var c: Object
var spot := Vector3.ZERO
var quad: Node      # the sheet's surface, the last child the match took when it went in
var res := {}       # "row key" -> value, read back by the asserts

func run(check: Object, flat_spot: Vector3) -> void:
	c = check
	spot = flat_spot
	var tz := TerrainHazards.of(c.m)
	var kin_was: Variant = c.P.kin
	var bare := Kin.new()      # a Boki's type and species are all the sheet reads (not in the tree)
	c.P.kin = bare
	var poly := [[spot.x - ROOM, spot.z - ROOM], [spot.x + ROOM, spot.z - ROOM],
		[spot.x + ROOM, spot.z + ROOM], [spot.x - ROOM, spot.z + ROOM]]
	var before: int = tz.areas.size()
	for row in ROWS:
		if row == "ice":
			tz._add_area("ice", poly)
			quad = c.m.get_child(-1)
		bare.species = FROST if row == "frost" else PLAIN
		bare.sp = Data.KIN[bare.species]
		_basics(row)
		_dashes(row)
	c.m.hitstop = 0.0           # (a dash's hit-stop is left over: the next rows read the first frame)
	c.P.kin = kin_was
	bare.free()
	_take_out(tz, before)
	_judge()

## The sheet comes out again: its tiles back to bare ground and its surface quad freed.
func _take_out(tz: TerrainHazards, count: int) -> void:
	for q in tz.areas[count]["cells"]:
		tz.cell[c.w.idx(q.x, q.y)] = 0
	tz.areas.resize(count)
	quad.queue_free()

## Metres and seconds from here until the hunter stands (keys let go).
func _slide() -> Array:
	var from := Vector2(c.P.pos.x, c.P.pos.z)
	for i in CAP:
		c.m.step(c.DT)
		if c._hv(c.P).length() < STILL:
			return [Vector2(c.P.pos.x, c.P.pos.z).distance_to(from), (i + 1) * c.DT]
	return [Vector2(c.P.pos.x, c.P.pos.z).distance_to(from), CAP * c.DT]

func _basics(row: String) -> void:
	var top: float = c.P.base_speed
	c._reset(spot + Vector3(-ROOM * 0.8, 0, 0))
	c.P.inp["move"] = Vector2(1, 0)
	c._steps(30)
	c.P.inp["move"] = Vector2.ZERO
	var r := _slide()
	res[row + " stop_m"] = r[0]
	res[row + " stop_s"] = r[1]
	print("MFEEL ice %-6s stop from the run: %.2f m in %.2f s" % [row, r[0], r[1]])
	c._reset(spot + Vector3(-ROOM * 0.5, 0, -ROOM * 0.5))
	c.P.inp["move"] = Vector2(1, 0)
	c._steps(30)
	c.P.inp["move"] = Vector2(0, 1)
	var t90 := 99.0
	var x0: float = c.P.pos.x
	for i in 240:
		c.m.step(c.DT)
		var hv: Vector2 = c._hv(c.P)
		if hv.length() >= 0.9 * top and absf(hv.angle_to(Vector2(0, 1))) < deg_to_rad(10.0):
			t90 = (i + 1) * c.DT
			break
	res[row + " turn_s"] = t90
	print("MFEEL ice %-6s 90 degree turn: %.2f s, %.2f m on along the old line"
			% [row, t90, c.P.pos.x - x0])
	c._reset(spot + Vector3(-ROOM * 0.8, 0, 0))
	c.P.vel = Vector3(10.0, 0, 0)
	r = _slide()
	res[row + " knock_m"] = r[0]
	print("MFEEL ice %-6s knock slide from 10 m/s: %.2f m in %.2f s" % [row, r[0], r[1]])

## Every kit's plain ground dash, keys let go once it starts: its travel and the metres it then slides.
func _dashes(row: String) -> void:
	var was: Array = [c.P.cls, c.P.arch]
	for id in Arch.ids():
		c.P.reclass(Arch.weight(id), id)
		c._steps(40)
		c._reset(spot + Vector3(-ROOM * 0.8, 0, 0))
		c.P.inp["move"] = Vector2(1, 0)
		c.P.inp["dash"] = true
		var start := Vector2.INF
		for i in CAP:
			var before := Vector2(c.P.pos.x, c.P.pos.z)
			c.m.step(c.DT)
			c.P.inp["dash"] = false
			if c.P.roll_t > 0.0:
				c.P.inp["move"] = Vector2.ZERO
				if start == Vector2.INF: start = before
			elif start != Vector2.INF or i > 90:
				break
		if start == Vector2.INF:
			continue            # (a kit that swaps or flies instead of a ground dash)
		var dist := Vector2(c.P.pos.x, c.P.pos.z).distance_to(start)
		var out: float = c._hv(c.P).length()
		var r := _slide()
		res["%s dash %s" % [row, id]] = dist
		res["%s slide %s" % [row, id]] = r[0]
		print("MFEEL ice %-6s dash %-10s travel %.2f m, out at %.1f m/s, slides %.2f m in %.2f s"
				% [row, id, dist, out, r[0], r[1]])
	c.P.reclass(was[0], was[1])

func _frost_like_ground(key: String) -> bool:
	return absf(float(res["frost " + key]) - float(res["ground " + key])) <= SAME_M

func _judge() -> void:
	var like := true
	for k in ["stop_m", "stop_s", "turn_s", "knock_m"]:
		like = like and _frost_like_ground(k)
	c.ok(like, "ice with a frost Boki: stop, turn and knock read as bare ground")
	var sm: float = res["ice stop_m"]
	var ss: float = res["ice stop_s"]
	c.ok(ss <= STOP_MAX_S and sm <= STOP_MAX_M and sm > 3.0 * res["ground stop_m"],
		"ice, plain Boki: a stop is slick (%.2f m, %.2f s) but over inside %.1f s and %.1f m"
			% [sm, ss, STOP_MAX_S, STOP_MAX_M])
	var t: float = res["ice turn_s"]
	c.ok(t <= TURN_MAX_S and t > 2.0 * res["ground turn_s"],
		"ice, plain Boki: a 90 degree turn takes %.2f s (ground %.2f, at most %.1f)"
			% [t, res["ground turn_s"], TURN_MAX_S])
	var kn: float = res["ice knock_m"]
	c.ok(kn <= KNOCK_MAX_M and kn > 3.0 * res["ground knock_m"],
		"ice, plain Boki: a 10 m/s knock slides %.1f m (ground %.1f, at most %.0f)"
			% [kn, res["ground knock_m"], KNOCK_MAX_M])
	var kits := 0
	for key in res:
		if not String(key).begins_with("ground dash "):
			continue
		var id := String(key).trim_prefix("ground dash ")
		kits += 1
		var cap := SPIN_SLIDE_MAX_M if id == "bulwark" else DASH_SLIDE_MAX_M
		var travel: float = res[key]
		var travel_ok := _frost_like_ground("dash " + id) and absf(res["ice dash " + id] - travel) <= SAME_M
		var slide: float = res["ice slide " + id]
		c.ok(travel_ok and slide <= cap and _frost_like_ground("slide " + id),
			"ice dash %-10s travels %.2f m on all three, slides %.2f m on ice (ground %.2f, at most %.1f)"
				% [id, travel, slide, res["ground slide " + id], cap])
	c.ok(kits >= 10, "ice rows: %d kit dashes measured" % kits)
