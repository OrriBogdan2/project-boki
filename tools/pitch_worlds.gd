extends RefCounted
## SCRATCH (private pitch footage, never shipped): the garden's zones and the Waystone hop in the close third-person
## farm view, played with the real keys on a made-up save. Run by tools/pitch_reel.gd (shots 11-17, 1920x1080 60 fps,
## no HUD): 11 hop (hub -> Glasswater, one take), 12-15 one establishing walk per zone, 16 three back-to-back hops.

const FPS := 60
const DAY_T := 0.45  # farm clock: mid-morning all film long
const LEG_S := 6.0  # s at most to a goal
const ZONE_TAKE_S := 8.0  # s a zone's walk lasts at least
## the side the walk up to the Waystone comes from: 30 deg east of south keeps the view level (straight from the south
## the Expeditions ring stands behind the camera and the view tips top-down; probe shot 18)
const STONE_SIDE := Vector3(0.5, 0.0, 0.866)
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
		18:
			await probe()
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
	_place(HubWaystone.HUB_AT + STONE_SIDE * 8.0)
	await _wait(0.8)
	rig.mark("portal")
	await _walk(HubWaystone.HUB_AT, 3.2)
	await _wait(0.3)
	await _hop(zone)
	rig.mark("arrived")
	await _wait(1.0)
	await _walk(_resident_at(zone, 0), 1.9)
	await _wait(3.0)


## Shots 12-15: the Hunter lands in the zone and walks up to its Boki while the view turns.
func zone_take(zone: String) -> void:
	await _load(zone)
	await _wait(1.0)
	rig.mark(zone)
	var t0 := Engine.get_frames_drawn()
	_orbit_start(1.4, 4.5)
	for n in 4:  # walks up to its Boki one after the other (the nearest from where it stands)
		await _walk(_resident_at(zone, n % 2), 1.9)
		await _wait(0.5)
	while Engine.get_frames_drawn() - t0 < int(ZONE_TAKE_S * FPS):
		await _wait(0.5)


## Shot 16: hub -> zone -> hub -> zone, each hop the moment you arrive.
func montage() -> void:
	await _load(GardenZones.HUB)
	_place(HubWaystone.HUB_AT + STONE_SIDE * 6.0)
	await _wait(0.5)
	rig.mark("montage")
	await _walk(HubWaystone.HUB_AT, 3.2)
	await _hop("glasswater")
	await _wait(0.9)
	await _hop(GardenZones.HUB)
	_place(HubWaystone.HUB_AT + STONE_SIDE * 5.0)  # (under the ink: lands on the clear side)
	await _wait(0.4)
	await _walk(HubWaystone.HUB_AT, 3.2)
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


## Shot 18 (headless, no film): from which side the walk up to the Waystone keeps the view level (the farm view
## tips top-down when a wall stands right behind it), and which zone Boki stand clear of water.
func probe() -> void:
	await _load(GardenZones.HUB)
	for i in [1, 11]:
		var a := TAU * float(i) / 12.0
		for r in [6.0, 9.0]:
			_place(HubWaystone.HUB_AT + Vector3(sin(a), 0.0, cos(a)) * r)
			await _wait(0.5)
			var top := 0.0
			var n := 0
			var goal := HubWaystone.HUB_AT
			while n < 6 * FPS and Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).length() > 1.6:
				var way := Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).normalized().rotated(h.cam.yaw)
				_keys(way)
				await rig.main.get_tree().process_frame
				top = maxf(top, h.farm_cam.tip)
				n += 1
			_keys(Vector2.ZERO)
			print("PROBE hub dir=%d r=%.0f tip_max=%.2f end=%.1f yaw=%.2f" % [i, r, top,
				Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).length(), h.cam.yaw])
	for z in ZONES:
		await _load(z)
		await _wait(2.0)
		print("PROBE zone=%s me=%s" % [z, h.ppos])
		for k in h.kins:
			if GardenZones.zone_of(k["rec"]) != z:
				continue
			var p: Vector3 = (k["node"] as Node3D).global_position
			var c := FarmWater.nearest(Save.d, Vector2(p.x, p.z))
			var wet := Vector2(c.x + 0.5, c.y + 0.5).distance_to(Vector2(p.x, p.z)) if c.x >= 0 else 99.0
			print("PROBE   %s at %s water_m=%.1f dist=%.1f" % [k["rec"]["name"], p, wet, p.distance_to(h.ppos)])


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
	for k in c.kins:
		if k.has("emote") and (k["emote"] as Label3D).text != "♥":
			k["emote_t"] = 0.0  # no star, note or question mark over a Boki
	_tick += 1
	if true:  # every frame: a heart can pop up and fill the lens between checks
		for l in c.find_children("*", "Label3D", true, false):
			var t: String = (l as Label3D).text
			var cam: Camera3D = rig.main.get_viewport().get_camera_3d()
			var close := cam != null and (l as Label3D).global_position.distance_to(cam.global_position) < 12.0
			if t != "♥" and not (keep_say and t.length() > 16):  # every word or glyph over the world (signs, names, bubbles)
				(l as Label3D).visible = false
			elif t == "♥" and close:  # a heart right at the lens fills the frame
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
	var out: Array = h.kins.filter(func(k): return GardenZones.zone_of(k["rec"]) == zone and not k.has("indoors") \
		and _dry((k["node"] as Node3D).global_position))
	if out.is_empty():
		return h.ppos + Vector3(0, 0, -4)
	var me: Vector3 = h.ppos
	out.sort_custom(func(a, b): return (a["node"] as Node3D).global_position.distance_to(me) \
		< (b["node"] as Node3D).global_position.distance_to(me))
	return (out[mini(n, out.size() - 1)]["node"] as Node3D).global_position


## Not standing in or right beside the pond (the Hunter would wade in after it).
func _dry(p: Vector3) -> bool:
	var c := FarmWater.nearest(Save.d, Vector2(p.x, p.z))
	return c.x < 0 or Vector2(c.x + 0.5, c.y + 0.5).distance_to(Vector2(p.x, p.z)) > 2.5


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
