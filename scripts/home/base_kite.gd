class_name BaseKite
extends RefCounted
## Kite Tow, part 1 (briefs/design/GARDEN_MODERN.md 4.2 game 7): a steering course on Kitewind Ridge, only
## with farm_build.json base_mode on and an island of the ridge theme. Press interact at the kite stand and
## your partner (or the first rested Boki out) glides on a kite one loop round the stand through twelve rings.
## A and D steer it left and right of its heading (on the loop: in toward the stand and out); Speed sets the
## pace; a missed ring adds a second to the finish time. The result card shows the time and the rings.
## Flaps and updraft vents are part 2. Tuning: content/rules/base_kite.json. Run is the flight itself (no
## nodes), so --kite-check (tools/kite_check.gd) flies it headless.

const STAND_OFF := Vector3(-2.6, 0, 3.4)     # m from the Training post to the kite stand
const STAND_H := 1.4                          # m, the stand's pole
const REACH := 1.6                            # m from the stand to start a flight
const KITE_UP := 0.9                          # m from the Boki up to its kite
const RING_COL := Color("f2c84a")             # the next ring
const RING_DIM := Color(0.95, 0.85, 0.6, 0.35)
const RING_HIT := Color("7ee08a")
const RING_MISS := Color("8a8a96")

static func rules() -> Dictionary:
	return Content.rules("base_kite")

## The pace along the loop (m/s): Speed alone sets it.
static func pace(rec: Dictionary) -> float:
	var R := rules()
	return float(R["pace"]) * (1.0 + float(rec.get("stats", {}).get("speed", 0)) * float(R["speed_per_point"]))

## One lap: the kite's place on the loop and across it, stepped in time.
class Run:
	var R: Dictionary
	var speed := 0.0                # m/s along the loop
	var lap := 0.0                  # m, the loop's middle line
	var rings: Array = []           # each ring's offset from the middle line (m, + is out)
	var t := 0.0                    # s flown
	var s := 0.0                    # m along the loop
	var off := 0.0                  # m across it, + is out
	var vel := 0.0                  # m/s across it
	var next := 0                   # the next ring to pass
	var got: Array = []             # each passed ring: true when the kite went through it
	var hits := 0
	var misses := 0

	func _init(rec: Dictionary, rng: RandomNumberGenerator) -> void:
		R = BaseKite.rules()
		speed = BaseKite.pace(rec)
		lap = TAU * float(R["loop_r"])
		for i in int(R["rings"]):
			rings.append(rng.randf_range(-float(R["ring_off"]), float(R["ring_off"])))

	## m along the loop to ring i.
	func ring_at(i: int) -> float:
		return lap * (i + 0.5) / rings.size()

	func over() -> bool:
		return s >= lap

	## The finish time: seconds flown plus a second (miss_s) for each missed ring.
	func time() -> float:
		return t + misses * float(R["miss_s"])

	## steer: -1 (A, left of the heading) .. 1 (D, right). Returns "hit" or "miss" for a ring passed, else "".
	func step(dt: float, steer: float) -> String:
		var go := minf(dt, (lap - s) / speed)    # the last step stops on the line, so the time is exact
		t += go
		s += speed * go
		vel = move_toward(vel, steer * float(R["steer"]), float(R["steer_accel"]) * dt)
		var edge := float(R["max_off"])
		off = clampf(off + vel * dt, -edge, edge)
		if absf(off) >= edge:
			vel = 0.0
		if next >= rings.size() or s < ring_at(next):
			return ""
		var hit := absf(off - float(rings[next])) <= float(R["ring_r"])
		next += 1
		got.append(hit)
		if hit:
			hits += 1
			return "hit"
		misses += 1
		return "miss"

## Pays out a finished lap: energy, joy and gems. Returns what the card shows.
static func settle(run: Run, rec: Dictionary) -> Dictionary:
	var R := rules()
	Care.change(rec, "energy", -float(R["energy"]))
	Care.change(rec, "joy", float(R["joy"]))
	var gems := int(R["gems_clean"]) if run.misses == 0 else int(R["gems"])
	Save.d["gems"] = int(Save.d["gems"]) + gems
	return {"rec": rec, "time": run.time(), "hits": run.hits, "misses": run.misses, "gems": gems}

# ------------------------------------------------------------------ on the base
var h                          # the Home screen
var stand: Node3D = null
var run: Run = null
var flier: Dictionary = {}     # the home's kin entry on the kite
var kite: Node3D = null
var hoops: Array = []          # the ring nodes, in order
var card: Control = null
var card_t := 0.0

func _init(home) -> void:
	h = home

## This zone's own stand spot (base_kite.json "spots", tiles x and z), or [].
static func spot() -> Array:
	return rules()["spots"].get(GardenZones.here, [])

## The kite stand on the zone's own spot, else beside the Training post on a ridge island only; called when
## fixtures move.
func place() -> void:
	if is_instance_valid(stand):
		stand.queue_free()
	stand = null
	var S := spot()
	if S.is_empty() and (h.YARD_AT.x < -100.0 or String(HomeLayout.of(Save.d)["theme"]) != String(rules()["theme"])):
		return
	stand = Node3D.new()
	stand.name = "KiteStand"
	stand.position = h.YARD_AT + STAND_OFF if S.is_empty() else Vector3(S[0], 0.0, S[1])
	var g: float = h._ground_h(stand.position.x, stand.position.z)
	stand.position.y = g if g > -50.0 else 0.0
	h.add_child(stand)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.07
	cm.height = STAND_H
	pole.mesh = cm
	pole.material_override = BaseRace.mat(Color("7a5638"))
	pole.position.y = STAND_H * 0.5
	stand.add_child(pole)
	var spool := _kite_mesh(Color("e05a4a"))
	spool.position.y = STAND_H + 0.2
	stand.add_child(spool)

func find(p2: Vector2) -> Dictionary:
	if run != null or not is_instance_valid(stand):
		return {}
	if p2.distance_to(Vector2(stand.position.x, stand.position.z)) > REACH:
		return {}
	return {"kind": "kite"}

func label() -> String:
	return "Fly the Kite Tow with %s" % Save.active_kin().get("name", "your partner")

func flying() -> bool:
	return run != null

func use() -> void:
	var ks: Array = h.hrace.entrants()
	if ks.is_empty():
		h._toast("The Kite Tow needs a rested Boki out on the base")
		return
	flier = ks[0]
	flier["busy"] = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	run = Run.new(flier["rec"], rng)
	kite = _kite_mesh(Color("e05a4a"))
	h.add_child(kite)
	for i in run.rings.size():
		hoops.append(_hoop(i))
	_paint_hoops()
	_place_flier()
	GardenSfx.countdown(h, stand.position)

## Esc lands the kite with no result; true when the flight took the press.
func input(event: InputEvent) -> bool:
	if run == null or not event.is_action_pressed("menu"):
		return false
	_end(false)
	return true

func tick(d: float) -> void:
	if card_t > 0.0:
		card_t -= d
		if card_t <= 0.0 and is_instance_valid(card):
			card.queue_free()
	if run == null:
		return
	var passed := run.step(d, Input.get_axis("left", "right"))
	if passed != "":
		GardenSfx.crowd("good" if passed == "hit" else "miss", flier["pos"])
		_paint_hoops()
	_place_flier()
	if run.over():
		_end(true)

## A point on the loop: s m along it, off m out from its middle line, glide_h above the stand.
func _at(s: float, off: float) -> Vector3:
	var r := float(rules()["loop_r"])
	var a := s / r
	return stand.position + Vector3(cos(a) * (r + off), float(rules()["glide_h"]), -sin(a) * (r + off))

## The way the loop runs at s m along it (counter-clockwise seen from above).
func _heading(s: float) -> Vector3:
	var a := s / float(rules()["loop_r"])
	return Vector3(-sin(a), 0, -cos(a))

func _place_flier() -> void:
	var p := _at(run.s, run.off)
	var fwd := _heading(run.s)
	var n: Node3D = flier["node"]
	n.position = p
	n.rotation.y = atan2(-fwd.x, -fwd.z)
	flier["pos"] = p
	kite.position = p + Vector3(0, KITE_UP, 0)
	kite.rotation = Vector3(0, n.rotation.y, -run.vel * 0.15)     # banks into the turn

## Ring i stands across the loop, its hole along the heading.
func _hoop(i: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = float(rules()["ring_r"]) - 0.06
	tm.outer_radius = float(rules()["ring_r"])
	m.mesh = tm
	var s := run.ring_at(i)
	h.add_child(m)
	m.position = _at(s, float(run.rings[i]))
	m.basis = Basis.looking_at(_heading(s)) * Basis(Vector3.RIGHT, PI * 0.5)
	return m

## The next ring bright, the ones ahead dim, the passed ones green or grey.
func _paint_hoops() -> void:
	for i in hoops.size():
		var c := RING_DIM
		if i == run.next:
			c = RING_COL
		elif i < run.next:
			c = RING_HIT if run.got[i] else RING_MISS
		var mat := BaseRace.mat(c)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if c.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
		hoops[i].material_override = mat

## A flat diamond kite.
func _kite_mesh(c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.03, 0.55)
	m.mesh = bm
	m.material_override = BaseRace.mat(c)
	m.rotation.y = PI * 0.25
	return m

func _end(finished: bool) -> void:
	var res := settle(run, flier["rec"]) if finished else {}
	var land := stand.position + Vector3(0.8, 0, 0.6)
	var g: float = h._ground_h(land.x, land.z)
	land.y = g if g > -50.0 else stand.position.y
	flier["node"].position = land
	flier["pos"] = land
	flier["busy"] = false
	flier["t"] = 1.5
	for n in hoops + [kite]:
		n.queue_free()
	hoops = []
	kite = null
	if finished:
		GardenSfx.crowd("great", land)
		h._emote(flier, "♥", true)
		_card(res)
		Save.save_game()
	run = null
	flier = {}

func _card(res: Dictionary) -> void:
	var rec: Dictionary = res["rec"]
	var total := int(rules()["rings"])
	var lost := float(res["misses"]) * float(rules()["miss_s"])
	if is_instance_valid(card):
		card.queue_free()
	card = BaseRace.result_card(h, [
		["%s lands the Kite Tow in %.1f s!" % [rec["name"], res["time"]], 18, UI.ACCENT_HI],
		["%d of %d rings (+%.0f s for misses)" % [res["hits"], total, lost], 14, UI.INK],
		["%s is beaming (+joy)" % rec["name"], 14, UI.INK],
		["+%d gems%s" % [res["gems"], " for a clean lap" if res["misses"] == 0 else ""], 14, UI.GOLD]])
	card_t = float(rules()["card_s"])
