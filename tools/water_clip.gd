extends RefCounted
## --water-clip: a short clip of the water sounds (WaterSfx) for listening, on the Hollow Crown's
## Saltmere tide pool at the match camera. Record it with Godot's movie writer on a renderer
## (jobq --needs gpu): --fixed-fps 60 --write-movie <dir>/water.avi --water-clip. One match step per
## frame, so sound and picture stay in step. The beats, printed as "WCLIP <s> <what>": walk in from the
## sand, run across (the wading loop rises with speed), stand still (it stops), a dash (spray), a jump
## by each weight class (light, medium, heavy splash), the Boki leaps in and charges, and out onto the
## sand again. Never touches the save.

const POOL := Vector2(21.5, 191.5)     # the tide pool's middle tile (content/maps/hollowcrown.json)
const SHORE_Z := 181.5                 # a sand tile 4.5 m north of the pool's edge

var main: Node
var m: Match
var h: Hunter
var t := 0.0

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"demo_kin": "cindle"})
	m.set_process(false)
	if main.get("fade") != null:
		await main.fade.reveal(0.01)       # the boot splash stays up when a tool starts the match by hand
	if m.hud:
		m.hud.visible = false
	h = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for o in m.hunters:
		if o != h:
			o.ctrl = "idle"                  # out of the way, as tools/cliff_mantle_check.gd: only our sounds
			o.teleport(Vector3(-500, 50, -500))
			o.out = true
	h.unlock_all()
	_become("dolm")
	h.teleport(_at(Vector2(POOL.x, SHORE_Z)))
	await _go(Vector2.ZERO, 1.0, "start on the sand")
	await _go(Vector2(0, 1), 1.8, "walk in, then run across: the wading loop follows speed")
	await _go(Vector2.ZERO, 1.2, "stand still in the water: the loop stops")
	_become("archer")                    # its dash is the shared travel (ArchKit.travel); Dolm's is a Rock Hop
	await _go(Vector2(-1, 0), 0.4, "dash: spray", "dash")
	await _go(Vector2.ZERO, 1.0, "")
	for arch in ["archer", "dolm", "ashwick"]:
		_become(arch)
		await _go(Vector2.ZERO, 1.4, "jump and land, %s: %s splash" % [arch, Arch.weight(arch)], "jump")
	var k: Kin = h.kin
	if k:
		k.start_leap(h.pos + Vector3(2.0, 0, 0), {"time": 0.45, "height": 1.6}, {})
		await _go(Vector2.ZERO, 1.2, "the Boki leaps in: splash")
		k.start_rush(Vector2(1, 0), {"distance": 3.0}, {})
		await _go(Vector2.ZERO, 1.2, "the Boki charges: spray")
	await _go(Vector2(0, -1), 2.6, "run out onto the sand: the loop stops, sand steps")
	print("WCLIP DONE %.1f s" % t)
	main.get_tree().quit()

func _become(arch: String) -> void:
	h.reclass(Arch.weight(arch), arch)

func _at(p: Vector2) -> Vector3:
	return Vector3(p.x, m.world.ground_at(p.x, p.y), p.y)

## Holds `move` for `secs` (pressing `press` on the first step), one step and one drawn frame at a time.
func _go(move: Vector2, secs: float, what: String, press := "") -> void:
	if what != "":
		print("WCLIP %.1f %s" % [t, what])
	var since := Time.get_ticks_msec()
	var waded := false
	var n := int(secs / Match.DT)
	for i in n:
		h.inp["move"] = move
		h.inp["aim"] = h.pos + Vector3(0, 0, -4)
		h.inp["dash"] = press == "dash" and i == 0
		h.inp["jump"] = press == "jump" and i == 0
		m.step(Match.DT)
		t += Match.DT
		await _frame()
		waded = waded or Sfx.loop_on(WaterSfx.wade_key(h.get_instance_id()))
	var heard := []
	for sname: String in Sfx.last_played:
		if sname.begins_with("water_") and int(Sfx.last_played[sname]) >= since:
			heard.append(sname)
	print("WCLIP     heard %s, wading loop %s" % [heard, "on" if waded else "off"])

## Draws one frame without stepping the match again (as tools/mantle_clip.gd).
func _frame() -> void:
	m.hitstop = 0.0
	m.slowmo = 0.0
	m.acc = Match.DT * 0.999 - DashPace.frame_dt(m, Match.DT)
	m._process(Match.DT)
	await main.get_tree().process_frame
