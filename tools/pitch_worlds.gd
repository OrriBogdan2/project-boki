extends RefCounted
## SCRATCH (private pitch footage, never shipped): the garden's zones and the Waystone hop in the close third-person
## farm view, played with the real keys on a made-up save. Run by tools/pitch_reel.gd (shots 11-17, 1920x1080 60 fps,
## no HUD): 11 hop (hub -> Glasswater, one take), 12-15 one establishing walk per zone, 16 three back-to-back hops.

const FPS := 60
const DAY_T := 0.45  # farm clock: mid-morning all film long
const LEG_S := 6.0  # s at most to a goal
const ZONES := ["glasswater", "cinderstep", "hushwood", "ridge"]
const ZONE_OF_SHOT := {12: "glasswater", 13: "cinderstep", 14: "hushwood", 15: "ridge"}
## species, name, the lean type the zone loves
const CAST := {
	"glasswater": [["floenatee", "Frigatee", "ice"], ["hoarheron", "Skateron", "ice"],
		["puddlet", "Prismander", "crystal"], ["rimeshrew", "Rimeshrew", "ice"]],
	"cinderstep": [["kilnbadger", "Anvilbrock", "fire"], ["scaldamus", "Chuggamus", "fire"],
		["kindlewren", "Kindlewren", "fire"], ["limpetor", "Buckleron", "steel"]],
	"hushwood": [["gloamshell", "Gloamshell", "dark"], ["caecilith", "Zippelith", "dark"],
		["umbrathere", "Umbrathere", "psychic"], ["nettlynx", "Nettlynx", "poison"]],
	"ridge": [["kestrike", "Kestrike", "electric"], ["thrumbird", "Thrumbird", "sound"],
		["zapple", "Echolop", "sound"], ["nimbostrich", "Boltstrich", "electric"]],
}

var rig
var h: Node = null  # the Home on screen now (it is a new one after every hop)
var keep_say := false  # shot 17 keeps the Boki's bubble
var _tick := 0


func _init(r) -> void:
	rig = r


func play(shot: int) -> void:
	_save()
	Record.set_level(2)
	match shot:
		11:
			await hop_take("glasswater")
		16:
			await montage()
		17:
			await ask_take()
		_:
			await zone_take(String(ZONE_OF_SHOT[shot]))


## A throwaway save: every zone open, 4 Boki with art living in each, the partner Ash in all.
func _save() -> void:
	Content.rules("farm_build")["base_mode"] = true
	seed(11)
	var d := Save.fresh()
	var rosters: Array = [["cindle", "Ash", "fierce"]]
	for z in ZONES:
		for c in CAST[z]:
			rosters.append(c + [z])
	for i in rosters.size():
		var c: Array = rosters[i]
		var rec := Save.new_kin(String(c[0]), String(c[1]), 700 + i)
		rec["uid"] = "pw%d" % i
		rec["trust"] = 80.0
		for need in Care.NEEDS:
			rec["needs"][need] = 90.0
		if i > 0:
			rec["zone"] = String(c[3])
			rec["lean"] = {String(c[2]): 14.0}
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "hatched": true, "intro": true, "day1_done": true}
	for z in ZONES:
		d["zones"][z] = {"open": true}
	HomeLayout.new_fs(d, 11)
	HomeLayout.ensure(d)
	Save.d = d


# ------------------------------------------------------------------ the takes
## Shot 11: the Hunter walks up to the Waystone and steps in; the stone lights, the ink wipes, `zone` is there.
func hop_take(zone: String) -> void:
	await _load(GardenZones.HUB)
	_place(HubWaystone.HUB_AT + Vector3(0.0, 0.0, 8.0))
	await _wait(0.8)
	rig.mark("portal")
	await _walk(HubWaystone.HUB_AT, 2.1)
	await _wait(0.3)
	await _hop(zone)
	rig.mark("arrived")
	await _wait(1.0)
	await _walk(_resident_at(zone), 2.0)
	await _wait(1.5)


## Shots 12-15: the Hunter lands in the zone and walks up to its Boki while the view turns.
func zone_take(zone: String) -> void:
	await _load(zone)
	await _wait(1.0)
	rig.mark(zone)
	await _walk(_resident_at(zone, 0), 2.0)
	await _wait(0.4)
	_orbit_start(1.1, 3.0)
	await _walk(_resident_at(zone, 1), 2.0)
	await _wait(1.5)


## Shot 16: hub -> zone -> hub -> zone, each hop the moment you arrive.
func montage() -> void:
	await _load(GardenZones.HUB)
	_place(HubWaystone.HUB_AT + Vector3(0.0, 0.0, 6.0))
	await _wait(0.5)
	rig.mark("montage")
	await _walk(HubWaystone.HUB_AT, 2.1)
	await _hop("glasswater")
	await _wait(0.9)
	await _hop(GardenZones.HUB)
	await _wait(0.4)
	await _walk(HubWaystone.HUB_AT, 2.1)
	await _hop("ridge")
	await _wait(1.8)


## Shot 17: a Boki that would thrive elsewhere goes to wait at the return pad with its bubble.
func ask_take() -> void:
	for rec in Save.d["roster"]:
		if String(rec["name"]) == "Skateron":
			rec["lean"] = {"fire": 20.0}
	keep_say = true
	await _load("glasswater")
	var k: Dictionary = h.kins.filter(func(o): return String(o["rec"]["name"]) == "Skateron")[0]
	var tries := 0
	while not h.life._ask(k) and tries < 2000:
		tries += 1
	rig.mark("ask")
	await _walk(h.hway.pad["pos"], 3.0)
	await _wait(6.0)


# ------------------------------------------------------------------ moving about
func _load(zone: String) -> void:
	await rig.main.show_screen("home", {"zone": zone})
	await _arrived()
	await rig.main.fade.reveal(0.01)
	await _wait(1.0)


## Waits for the Home that a screen change builds, then dresses it for film.
func _arrived() -> void:
	while not is_instance_valid(rig.main.current) or rig.main.current == h or rig.main.current.get("building") == true:
		await rig.main.get_tree().process_frame
	h = rig.main.current
	await rig.main.get_tree().process_frame
	rig._crisp_shadows()
	h.farm_cam.k = 1.0  # (a new Home starts on the top-down view and eases to the close one: start close)
	h.farm_cam.pitch = deg_to_rad(float(FarmCam.rules()["pitch_deg"]))
	h.cam.snap(h.ppos)
	_tidy()


func _tidy() -> void:
	var c: Node = rig.main.current
	if not is_instance_valid(c) or c.get("ppos") == null:
		return
	c.day_t = DAY_T
	c.talk_cd = 1e9  # no chatter bubbles
	_tick += 1
	if _tick % 3 == 0 and not keep_say:
		for l in c.find_children("*", "Label3D", true, false):
			var t: String = (l as Label3D).text
			if t.length() > 16 or t == "★":  # Boki bubbles, notice boards, the partner star: text in the frame
				(l as Label3D).visible = false
	if c.get("ui") != null:
		(c.ui as CanvasLayer).visible = false


func _wait(secs: float) -> void:
	for _i in maxi(1, roundi(secs * FPS)):
		await rig.main.get_tree().process_frame
		_tidy()


func _place(p: Vector3) -> void:
	var at: Vector3 = h.world.free_spot_near(p, [], 1.2, 0.9)
	h.ppos = at
	h.player.position = at
	h.cam.snap(at)


## Press the Waystone's hop (the zone cards' pick) and film through the wipe to the Home that follows.
func _hop(zone: String) -> void:
	var from := h
	if not h.hway.hop(zone):
		rig.fail("hop to %s refused" % zone)
		return
	await _wait(0.1)
	await _arrived()
	if h == from:
		rig.fail("no new Home after the hop to %s" % zone)
	await rig.main.get_tree().process_frame


## The nth Boki living in `zone` (not the partner), where it stands now.
func _resident_at(zone: String, n := 0) -> Vector3:
	var out: Array = h.kins.filter(func(k): return GardenZones.zone_of(k["rec"]) == zone and not k.has("indoors"))
	if out.is_empty():
		return h.ppos + Vector3(0, 0, -4)
	var me: Vector3 = h.ppos
	out.sort_custom(func(a, b): return (a["node"] as Node3D).global_position.distance_to(me) \
		< (b["node"] as Node3D).global_position.distance_to(me))
	return (out[mini(n, out.size() - 1)]["node"] as Node3D).global_position


## Walks to within `near` m of `goal` (xz) with the real keys, each frame turned into the view's own terms.
func _walk(goal: Vector3, near: float) -> void:
	var left := int(LEG_S * FPS)
	while left > 0 and Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).length() > near:
		var way := Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).normalized().rotated(h.cam.yaw)
		_keys(way)
		await rig.main.get_tree().process_frame
		_tidy()
		_orbit_step()
		left -= 1
	_keys(Vector2.ZERO)


func _keys(mv: Vector2) -> void:
	Input.action_press("right", maxf(mv.x, 0.0))
	Input.action_press("left", maxf(-mv.x, 0.0))
	Input.action_press("down", maxf(mv.y, 0.0))
	Input.action_press("up", maxf(-mv.y, 0.0))
	if mv == Vector2.ZERO:
		for a in ["right", "left", "down", "up"]:
			Input.action_release(a)


# a slow right-drag turn of the view: `turn` radians over `secs`, one step a frame (while walking or waiting)
var _turn_left := 0
var _turn_px := 0.0


func _orbit_start(turn: float, secs: float) -> void:
	_turn_left = int(secs * FPS)
	_turn_px = -turn / float(FarmCam.rules()["orbit_per_px"]) / float(_turn_left)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	h._unhandled_input(press)


func _orbit_step() -> void:
	if _turn_left <= 0:
		return
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(_turn_px, 0.0)
	h._unhandled_input(move)
	_turn_left -= 1
	if _turn_left == 0:
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_RIGHT
		release.pressed = false
		h._unhandled_input(release)
