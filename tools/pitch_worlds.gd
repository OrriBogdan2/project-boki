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
const HUNTER_ARCH := "ostra"  # Motley's archetype (WardenGlb.ART): the best in-game model, on its v95 glb
const HUNTER_CLASS := "medium"
## (m right, m ahead) of the Hunter's landing where the staged Boki stand
## (far enough apart that the Hunter walks, not stands, for most of a take)
const STAGE_AT := [Vector2(-2.0, 3.6), Vector2(2.4, 5.6), Vector2(-0.8, 7.6)]
const STOP_M := 2.9  # m the Hunter stops short of a Boki (it slides ~0.5 m after the keys lift: never under MIN_GAP_M)
const MIN_GAP_M := 2.2  # m: no Boki is ever nearer the Hunter than this, all clip long (the steering keeps STOP_M)
const AVOID_M := 3.4  # m: a Boki the Hunter is not walking to bends its path away from this close
const TREE_GAP_M := 2.8  # m: the staged Boki and the Hunter's legs keep this far off every tree trunk
## m the whole staged group slides sideways, in the order tried, until its walk clears every tree
const TIP_FLIP := 0.15  # rad the view may tip up over a wall before the view-turn is reversed
const ORBIT_RAD := 0.9  # rad the view turns over a zone take
## the turn is the other way where the first one swung the view behind the portal ring (it tipped top-down)
const ORBIT_DIR := {"glasswater": -1.0}
const SHIFTS := [0.0, 2.5, -2.5, 4.5, -4.5, 6.5, -6.5, 8.5, -8.5]
## the hub's market stall and games board (east of the Waystone) and its Burrow mound (west) are primitive-built: out of the
## film (rects: x z width depth)
const HUB_FIXTURES := [Rect2(43.0, 30.5, 5.0, 7.5), Rect2(32.0, 34.5, 3.0, 3.0)]
const PLAIN_DECO := ["snack_patch", "toy_dig"]  # a zone's primitive-built beds (planter, dig patch): out of the film
const PATH_GAP := 2.2  # m: a prop this close to the Hunter's walk (landing -> Boki 0 -> 1 -> 2) is out of the film
const ZONES := ["glasswater", "cinderstep", "hushwood", "ridge"]
const ZONE_OF_SHOT := {12: "glasswater", 13: "cinderstep", 14: "hushwood", 15: "ridge"}
## species, name, the lean type the zone loves
const CAST := {
	"glasswater":
	[
		["floenatee", "Frigatee", "ice"],
		["hoarheron", "Skateron", "ice"],
		["puddlet", "Prismander", "crystal"],
		["rimeshrew", "Rimeshrew", "ice"]
	],
	"cinderstep":
	[
		["kilnbadger", "Anvilbrock", "fire"],
		["scaldamus", "Chuggamus", "fire"],
		["kindlewren", "Kindlewren", "fire"],
		["limpetor", "Buckleron", "steel"]
	],
	"hushwood":
	[
		["gloamshell", "Gloamshell", "dark"],
		["caecilith", "Zippelith", "dark"],
		["umbrathere", "Umbrathere", "psychic"],
		["nettlynx", "Nettlynx", "poison"]
	],
	"ridge":
	[
		["kestrike", "Kestrike", "electric"],
		["thrumbird", "Thrumbird", "sound"],
		["zapple", "Echolop", "sound"],
		["nimbostrich", "Boltstrich", "electric"]
	],
}

var rig
var h: Node = null  # the Home on screen now (it is a new one after every hop)
var hud := false  # --pitch-hud: the farm's HUD is filmed (the other version has none)
var keep_say := false  # shot 17 keeps the Boki's bubble
var _keep: Node3D = null  # shot 17 films the return pad (the stone the ask is about), though it is built of discs
var _pins: Array = []  # [kin record, where it stands]: a staged Boki is held there for the whole take (no wandering off, no errand)
var _cleared: Array = []  # props hidden off the Hunter's walk (kept hidden every frame)
var _show: Array = []  # the Boki nodes that are in the film (all the others are hidden)
var _min_gap := 99.0  # m: the nearest any shown Boki came to the Hunter this take
var _cuts := 0  # hops filmed so far this take
var _frames := 0  # frames this take has run (Engine.get_frames_drawn stays 0 headless)


func _init(r) -> void:
	rig = r


func play(shot: int) -> void:
	RenderingServer.frame_pre_draw.connect(_pre_draw)  # (Home shows its icons again in its own frame: hide after it)
	_save()
	hud = OS.get_cmdline_user_args().has("--pitch-hud")  # the second version of every clip: the game's clean HUD stays on
	Record.set_level(1 if hud else 2)
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
	print("PITCH gap_min=%.2f m (a shown Boki to the Hunter, ground distance)" % _min_gap)


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
	d["cls"] = HUNTER_CLASS
	d["arch"] = HUNTER_ARCH
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "hatched": true, "intro": true, "day1_done": true}
	for z in ZONES:
		d["zones"][z] = {"open": true}
	HomeLayout.new_fs(d, 11)
	HomeLayout.ensure(d)
	Save.d = d


# ------------------------------------------------------------------ the takes
## Shot 11: the Hunter walks up to the Waystone and steps in; the stone lights, the zone cuts in, `zone` is there.
func hop_take(zone: String) -> void:
	await _load(GardenZones.HUB)
	_place(HubWaystone.HUB_AT + STONE_SIDE * 8.0)
	await _wait(0.8)
	rig.mark("portal")
	await _walk(HubWaystone.HUB_AT, 1.8)
	await _wait(0.3)
	await _hop(zone)
	rig.mark("arrived")
	await _wait(0.6)
	for n in 3:
		await _walk(_boki_at(n), STOP_M)
		await _wait(0.35)


## Shots 12-15: the Hunter lands in the zone and walks up to its Boki, one after the other, while the view turns.
func zone_take(zone: String) -> void:
	await _load(zone)
	await _wait(1.0)
	rig.mark(zone)
	var t0 := _frames
	_orbit_start(ORBIT_RAD * float(ORBIT_DIR.get(zone, 1.0)), ZONE_TAKE_S - 1.0)
	var n := 0
	while _frames - t0 < int(ZONE_TAKE_S * FPS):  # Boki to Boki and round again: the Hunter is walking nearly all take
		await _walk(_boki_at(n % 3), STOP_M)
		await _wait(0.35)
		n += 1


## Shot 16: hub -> zone -> hub -> zone, each hop the moment you arrive (the wipes are cut out by the encoder).
func montage() -> void:
	await _load(GardenZones.HUB)
	_place(HubWaystone.HUB_AT + STONE_SIDE * 6.0)
	await _wait(0.5)
	rig.mark("montage")
	await _walk(HubWaystone.HUB_AT, 1.8)
	await _hop("glasswater")
	await _wait(0.9)
	await _hop(GardenZones.HUB)
	_place(HubWaystone.HUB_AT + STONE_SIDE * 5.0)  # lands on the clear side
	await _wait(0.4)
	await _walk(HubWaystone.HUB_AT, 1.8)
	await _hop("ridge")
	await _wait(1.8)


## Shot 17: a Boki that would thrive elsewhere walks ahead of the Hunter to the return pad and waits there with its
## bubble; the Hunter follows (never nearer than STOP_M), presses E, and it walks onto the pad and blinks out.
## (r10: the Boki was pinned to its staged spot and the Hunter landed on the pad, so nothing moved.)
const ASK_BACK := 9.0  # m up-view of the pad the Hunter starts (the pad is straight ahead in the view)
const ASK_SIDE := [0.0, 2.0, -2.0, 4.0, -4.0]  # m sideways tried until the walk to the pad clears every tree


func ask_take() -> void:
	for rec in Save.d["roster"]:
		if String(rec["name"]) == "Skateron":
			rec["lean"] = {"fire": 20.0}
	keep_say = true
	await _load("glasswater")
	var k: Dictionary = h.kins.filter(func(o): return String(o["rec"]["name"]) == "Skateron")[0]
	var pad: Vector3 = h.hway.pad["pos"]
	var fwd2 := Vector2(0.0, -1.0).rotated(h.cam.yaw)
	var fwd := Vector3(fwd2.x, 0.0, fwd2.y)
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var start := pad - fwd * ASK_BACK
	for dx in ASK_SIDE:
		var cand: Vector3 = h.world.free_spot_near(pad - fwd * ASK_BACK + right * dx, [], 1.2, 0.9)
		if _trees_clear(cand, [pad]):
			start = cand
			print("PITCH ask side=%.1f" % dx)
			break
	_pins.clear()  # Skateron walks (every other Boki is out of the film)
	_show.clear()
	_show.append(k["node"])
	_place(start)
	var at: Vector3 = h.world.free_spot_near(
		start + (pad - start).normalized() * 3.6 + right * 1.2, [], 1.2, 0.9
	)
	k.erase("job")
	k["pos"] = at
	k["goal"] = at
	(k["node"] as Node3D).position = at
	_clear_path(start, [at, pad])
	_keep = h.hway.node
	_cleared.erase(_keep)
	_keep.visible = true
	await _wait(0.8)
	rig.mark("ask")
	var tries := 0
	while not h.life._ask(k) and tries < 2000:
		tries += 1
	if not h.life.machine(k).is_in(BaseLife.S.REACT):
		rig.fail("Skateron did not ask")
		return
	var n := 0
	while n < int(7.0 * FPS):  # follow it to the pad, STOP_M behind
		var p3: Vector3 = (k["node"] as Node3D).global_position
		var off := Vector2(p3.x - h.ppos.x, p3.z - h.ppos.z)
		_keys(off.normalized().rotated(h.cam.yaw) if off.length() > STOP_M + 0.3 else Vector2.ZERO)
		await rig.main.get_tree().process_frame
		_tidy()
		n += 1
		if (
			n > FPS
			and Vector2(p3.x - pad.x, p3.z - pad.z).length() < 2.2
			and off.length() <= STOP_M + 0.4
		):
			break
	_keys(Vector2.ZERO)
	var kp: Vector3 = (k["node"] as Node3D).global_position
	print(
		(
			"PITCH ask hunter_walked=%.1f m boki_to_pad=%.1f m frames=%d"
			% [start.distance_to(h.ppos), kp.distance_to(pad), n]
		)
	)
	await _wait(2.2)  # it waits at the pad, the bubble reads
	rig.mark("send")
	h._kin_act(k)  # E: send it where it wants to go
	await _wait(3.0)


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
				var way := Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).normalized().rotated(
					h.cam.yaw
				)
				_keys(way)
				await rig.main.get_tree().process_frame
				top = maxf(top, h.farm_cam.tip)
				n += 1
			_keys(Vector2.ZERO)
			print(
				(
					"PROBE hub dir=%d r=%.0f tip_max=%.2f end=%.1f yaw=%.2f"
					% [i, r, top, Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).length(), h.cam.yaw]
				)
			)
	for z in ZONES:
		await _load(z)
		await _wait(2.0)
		print("PROBE zone=%s me=%s" % [z, h.ppos])
		for k in h.kins:
			if GardenZones.zone_of(k["rec"]) != z:
				continue
			var p: Vector3 = (k["node"] as Node3D).global_position
			var c := FarmWater.nearest(Save.d, Vector2(p.x, p.z))
			var wet := (
				Vector2(c.x + 0.5, c.y + 0.5).distance_to(Vector2(p.x, p.z)) if c.x >= 0 else 99.0
			)
			print(
				(
					"PROBE   %s at %s water_m=%.1f dist=%.1f"
					% [k["rec"]["name"], p, wet, p.distance_to(h.ppos)]
				)
			)


# ------------------------------------------------------------------ moving about
func _load(zone: String) -> void:
	await rig.main.show_screen("home", {"zone": zone})
	await _arrived()
	await rig.main.fade.reveal(0.01)
	await _wait(1.0)


## Waits for the Home that a screen change builds, then dresses it for film.
func _arrived() -> void:
	while (
		not is_instance_valid(rig.main.current)
		or rig.main.current == h
		or rig.main.current.get("building") == true
	):
		await rig.main.get_tree().process_frame
	h = rig.main.current
	await rig.main.get_tree().process_frame
	rig._crisp_shadows()
	h.farm_cam.k = 1.0  # (a new Home starts on the top-down view and eases to the close one: start close)
	h.farm_cam.pitch = deg_to_rad(float(FarmCam.rules()["pitch_deg"]))
	h.cam.snap(h.ppos)
	_dress_hunter()
	_stage()
	_tidy()


## Up to three of the zone's Boki stand in an open arc ahead of the Hunter, clear of every prop; the others are out of the
## film (hidden), so each shot has 2-3 readable Boki and none inside a sign or post.
## Props that stay in the film (course scenery is hidden, see COURSE_NAMES): a staged Boki is moved off any of them.
const PROP_GAP := 1.7


func _props() -> Array:
	var out: Array = []
	var kin_nodes: Array = []
	for k in h.kins:
		kin_nodes.append(k["node"])
	for n in h.get_children():
		var n3 := n as Node3D
		if (
			n3 == null
			or not n3.visible
			or n3 == h.player
			or n3 in kin_nodes
			or n3.get_script() != null
		):
			continue
		if (
			_is_course(n3)
			or _is_placeholder(n3)
			or n3.get_child_count() == 0
			or n3.position.length() < 1.0
		):
			continue
		if n3.find_children("*", "MeshInstance3D", true, false).is_empty():
			continue
		out.append(n3.position)
	return out


func _clear_of_props(at: Vector3) -> Vector3:
	var props := _props()
	var best := at
	var best_d := -1.0
	for ring in [0.0, 0.9, 1.8, 2.7]:
		for i in 1 if ring == 0.0 else 10:
			var cand := at + Vector3(ring, 0, 0).rotated(Vector3.UP, TAU * i / 10.0)
			cand = h.world.free_spot_near(cand, [], 1.2, 0.9)
			var d := 99.0
			for p in props:
				d = minf(d, Vector2(cand.x - p.x, cand.z - p.z).length())
			if d >= PROP_GAP:
				return cand
			if d > best_d:
				best_d = d
				best = cand
	return best


func _stage() -> void:
	_show.clear()
	_pins.clear()
	_cleared.clear()
	var zone := GardenZones.current()
	var awake: Array = h.kins.filter(func(k): return not k.has("indoors"))
	var mine: Array = awake.filter(func(k): return GardenZones.zone_of(k["rec"]) == zone)
	for k in awake:  # a zone with fewer than three residents borrows the rest: the film shows 2-3 Boki, readable
		if mine.size() < STAGE_AT.size() and not (k in mine):
			mine.append(k)
	print(
		(
			"PITCH stage zone=%s kins=%d staged=%d"
			% [zone, h.kins.size(), mini(STAGE_AT.size(), mine.size())]
		)
	)
	var fwd2 := Vector2(0.0, -1.0).rotated(h.cam.yaw)  # the view's "up", on the ground
	var fwd := Vector3(fwd2.x, 0.0, fwd2.y)
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var placed: Array = []
	for dx in SHIFTS:  # the first sideways slide whose walk (landing -> Boki 0 -> 1 -> 2 -> 0) stays clear of every tree
		placed = _spots(mini(STAGE_AT.size(), mine.size()), right * dx, fwd, right)
		if _trees_clear(h.ppos, placed):
			print("PITCH stage shift=%.1f" % dx)
			break
	for i in placed.size():
		var k: Dictionary = mine[i]
		var at: Vector3 = placed[i]
		k.erase("job")
		k["pos"] = at
		k["goal"] = at
		k["t"] = 600.0
		(k["node"] as Node3D).position = at
		_show.append(k["node"])
		_pins.append([k, at])
	_clear_path(h.ppos, placed)
	_hide_fixtures(zone)


## Where the first `n` Boki stand with the group slid `slide` sideways: open ground, clear of props, apart from each other.
func _spots(n: int, slide: Vector3, fwd: Vector3, right: Vector3) -> Array:
	var placed: Array = []
	for i in n:
		var at: Vector3 = h.ppos + slide + right * STAGE_AT[i].x + fwd * STAGE_AT[i].y
		placed.append(_clear_of_props(h.world.free_spot_near(at, placed, 1.5, 1.1)))
	return placed


## Does the walk start -> stops[0] -> stops[1] -> ... -> stops[0] keep TREE_GAP_M off every tree trunk?
func _trees_clear(start: Vector3, stops: Array) -> bool:
	var pts: Array = [start] + stops
	if stops.size() > 1:
		pts.append(stops[0])
	for t in h.world.tree_spots:
		var q := Vector2(t.x, t.z)
		for i in pts.size() - 1:
			var a := Vector2(pts[i].x, pts[i].z)
			var b := Vector2(pts[i + 1].x, pts[i + 1].z)
			if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < TREE_GAP_M:
				return false
	return true


## Plain-box stand-ins are not filmed (the repo has no stall, board, hut or planter model to swap in: the vendor packs hold
## dungeon and halloween sets only): the hub's market stall and games board, a zone's roofed hut and its snack-patch bed.
func _hide_fixtures(zone: String) -> void:
	var kin_nodes: Array = []
	for k in h.kins:
		kin_nodes.append(k["node"])
	var beds: Array = []
	for d in GardenZones.info(zone).get("build", {}).get("deco", []):
		if String(d[0]) in PLAIN_DECO:
			beds.append(Vector2(float(d[1]) + 1.0, float(d[2]) + 1.0))
	for n in h.get_children():
		var n3 := n as Node3D
		if (
			n3 == null
			or n3 == h.player
			or n3 in kin_nodes
			or n3 == h.get("world")
			or n3.get_script() != null
		):
			continue
		var at := Vector2(n3.position.x, n3.position.z)
		var hide: bool = false
		if h.zone == GardenZones.HUB and n3.position.length() > 1.0:
			for r in HUB_FIXTURES:
				hide = hide or (r as Rect2).has_point(at)
		for b in beds:
			hide = hide or at.distance_to(b) < 1.0
		if h.zone != GardenZones.HUB:
			for m in n3.find_children("*", "MeshInstance3D", true, false):
				hide = hide or (m as MeshInstance3D).mesh is PrismMesh
		if hide:
			print("PITCH fixture-hide %s at %s" % [n3.name, n3.position])
			n3.visible = false
			_cleared.append(n3)


## Hides every prop within PATH_GAP of the Hunter's walk, so it never stops beside a crate or target.
func _clear_path(start: Vector3, stops: Array) -> void:
	var legs: Array = []
	var prev := start
	for p in stops:
		legs.append([prev, p])
		prev = p
	if stops.size() > 1:
		legs.append([prev, stops[0]])
	var kin_nodes: Array = []
	for k in h.kins:
		kin_nodes.append(k["node"])
	for n in h.get_children():
		var n3 := n as Node3D
		if (
			n3 == null
			or not n3.visible
			or n3 == h.player
			or n3 in kin_nodes
			or n3.get_script() != null
		):
			continue
		var meshes: Array = n3.find_children("*", "MeshInstance3D", true, false)
		if n3 is MeshInstance3D:
			meshes.append(n3)
		if meshes.is_empty() or n3 == h.get("world") or n3.name == ZoneAir.NAME:
			continue
		var big := false  # ground, cliffs and ponds stay; props and lone trees on the walk go (Motley walked through a trunk)
		for m in meshes:
			var sz: Vector3 = (
				(m as MeshInstance3D).get_aabb().size
				* (m as Node3D).global_transform.basis.get_scale()
			)
			big = big or maxf(sz.x, sz.z) > 4.5 or sz.y > 7.0
		if big:
			continue
		var q := Vector2(n3.position.x, n3.position.z)
		for leg in legs:
			var a := Vector2(leg[0].x, leg[0].z)
			var b := Vector2(leg[1].x, leg[1].z)
			if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < PATH_GAP:
				print("PITCH path-clear hide %s at %s" % [n3.name, n3.position])
				n3.visible = false
				_cleared.append(n3)
				break


## The staged Boki's spot `n` (where it stands now).
func _boki_at(n: int) -> Vector3:
	if _show.is_empty():
		return h.ppos + Vector3(0, 0, -4)
	return (_show[mini(n, _show.size() - 1)] as Node3D).global_position


## The farm wears your Unmasked (a cloaked Empty); the film shows a finished hunter on its game glb, built as Home does.
func _dress_hunter() -> void:
	var at: Vector3 = h.player.position
	var rot: Vector3 = h.player.rotation
	h.player.queue_free()
	h.player = Models.hunter(HUNTER_CLASS, Data.TEAM_COLORS[0], h._weapon(), "", {}, HUNTER_ARCH)
	h.player.position = at
	h.player.rotation = rot
	h.add_child(h.player)
	print("PITCH hunter arch=%s glb=%s" % [HUNTER_ARCH, WardenGlb.ART.get(HUNTER_ARCH, "?")])


func _tidy() -> void:
	var c: Node = rig.main.current
	if not is_instance_valid(c) or c.get("ppos") == null:
		return
	_frames += 1
	for n in _show:
		if is_instance_valid(n):
			var at: Vector3 = (n as Node3D).global_position
			_min_gap = minf(_min_gap, Vector2(at.x - c.ppos.x, at.z - c.ppos.z).length())
	if _frames % 10 == 0 and c.get("farm_cam") != null and c.farm_cam.tip > 0.05:  # the view tipped up over a wall
		print("PITCH_TIP frame=%d tip=%.2f at=%s" % [_frames, c.farm_cam.tip, c.ppos])
	c.day_t = DAY_T
	c.talk_cd = 1e9  # no chatter bubbles
	for k in c.kins:
		k["emote_t"] = 0.0  # no star, note, question mark or heart over a Boki
	_hide_marks(c)


func _pre_draw() -> void:
	var c: Node = rig.main.current
	if is_instance_valid(c) and c.get("ppos") != null and c.get("player") != null:
		_hide_marks(c)
		for pin in _pins:
			var k: Dictionary = pin[0]
			var nv: Variant = k["node"]
			if not is_instance_valid(nv):  # (the Home of a finished hop is freed: its Boki with it)
				continue
			var node := nv as Node3D
			node.position = pin[1]
			k["pos"] = pin[1]
			k["goal"] = pin[1]
			k["t"] = 600.0
			k.erase("job")


## Every frame: no word or glyph over the world (signs, names, bubbles), no billboard icon (a heart, z, work mark), no
## zone air (its wind streaks and glints read as grey bars and specks), no haze quad on the hunter, no UI layer.
const COURSE_NAMES := ["RacePost", "RelayStand", "KiteStand"]


func _is_course(n: Node) -> bool:
	for nm in COURSE_NAMES:
		if String(n.name).begins_with(nm):
			return true
	return false


## Primitive-built stand-ins (blank signs, bare logs, the flat shallows slab) are not filmed; glb-built props stay.
func _is_placeholder(n: Node3D) -> bool:
	if n.name == "Shallows":
		return true
	if n.get_script() != null or n is MeshInstance3D or n is MultiMeshInstance3D:
		return false
	var meshes := n.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return false
	var only_cyl := true
	var plain := meshes.size() <= 4
	for m in meshes:
		var ms: Mesh = (m as MeshInstance3D).mesh
		if not ms is CylinderMesh:
			only_cyl = false
		if ms is ArrayMesh or ms is PlaneMesh or ms is QuadMesh:
			plain = false
	var has_label := not n.find_children("*", "Label3D", false, false).is_empty()
	var round_part := false
	for m in meshes:
		round_part = round_part or (m as MeshInstance3D).mesh is SphereMesh
	return (has_label and not round_part and meshes.size() <= 5) or only_cyl or plain


func _hide_marks(c: Node) -> void:
	if not is_instance_valid(c.get("player")):
		return
	var kin_nodes: Array = []
	for k in c.kins:
		kin_nodes.append(k["node"])
	for n in c.get_children():
		var n3 := n as Node3D
		if (
			n3 != null
			and n3 != c.player
			and n3 != _keep
			and not (n3 in kin_nodes)
			and _is_placeholder(n3)
		):
			n3.visible = false
	for n in c.get_children():
		if _is_course(n):
			(n as Node3D).visible = false
	var hrace: Object = c.get("hrace")
	var bases: Array = [hrace, c.get("hkite")]
	if hrace != null:
		bases.append(hrace.get("relay"))
	for b in bases:
		if b == null:
			continue
		for f in ["post", "wall", "stand"]:
			var v: Variant = b.get(f)
			if v is Node3D and is_instance_valid(v):
				(v as Node3D).visible = false
	for k in c.kins:
		(k["node"] as Node3D).visible = _show.is_empty() or (k["node"] in _show)
	for n3 in _cleared:
		if is_instance_valid(n3):
			(n3 as Node3D).visible = false
	for l in c.find_children("*", "Label3D", true, false):
		var t: String = (l as Label3D).text
		if not (keep_say and t.length() > 16):
			(l as Label3D).visible = false
	for sp in c.find_children("*", "Sprite3D", true, false):
		(sp as Sprite3D).visible = false
	var air := c.get_node_or_null(ZoneAir.NAME) as Node3D
	if air != null:
		air.visible = false
	var crack := c.get_node_or_null("crack") as Node3D  # (Cinderstep's glowing ground cracks read as flat yellow strips)
	if crack != null:
		crack.visible = false
	var ring := c.player.get_node_or_null("TeamRing") as Node3D
	if ring != null:
		ring.visible = false
	for q in c.player.find_children("*", "MeshInstance3D", true, false):
		var mi := q as MeshInstance3D
		if (
			mi.mesh is QuadMesh
			or String(mi.name).begins_with("orbit_cards")
			or String(mi.name).begins_with("Halo")
		):
			mi.visible = false
	if c.get("ui") != null:
		(c.ui as CanvasLayer).visible = hud


func _wait(secs: float) -> void:
	for _i in maxi(1, roundi(secs * FPS)):
		await rig.main.get_tree().process_frame
		_tidy()


func _place(p: Vector3) -> void:
	var at: Vector3 = h.world.free_spot_near(p, [], 1.2, 0.9)
	h.ppos = at
	h.player.position = at
	h.cam.snap(at)


## Press the Waystone's hop (the zone cards' pick). The ink wipe is not filmed: the take marks cut_N_out (the stone has
## lit up and begun to fade) and cut_N_in (the wipe is gone, the new zone clear) and the encoder joins them with a
## short dissolve, so no black or ragged wipe frame is in the clip.
func _hop(zone: String) -> void:
	var from := h
	if not h.hway.hop(zone):
		rig.fail("hop to %s refused" % zone)
		return
	_cuts += 1
	await _wait(float(GardenZones.rules()["hop_fade_s"]) - 0.1)
	rig.mark("cut%d_out" % _cuts)
	await _wait(0.1)
	await _arrived()
	if h == from:
		rig.fail("no new Home after the hop to %s" % zone)
	var fade: ScreenFade = rig.main.fade
	while fade.covered or fade.rect.color.a > 0.01:
		await rig.main.get_tree().process_frame
		_tidy()
	await _wait(0.2)
	rig.mark("cut%d_in" % _cuts)


## The nth Boki living in `zone` (not the partner), where it stands now.
func _resident_at(zone: String, n := 0) -> Vector3:
	var out: Array = h.kins.filter(
		func(k):
			return (
				GardenZones.zone_of(k["rec"]) == zone
				and not k.has("indoors")
				and _dry((k["node"] as Node3D).global_position)
			)
	)
	if out.is_empty():
		return h.ppos + Vector3(0, 0, -4)
	var me: Vector3 = h.ppos
	out.sort_custom(
		func(a, b):
			return (
				(a["node"] as Node3D).global_position.distance_to(me)
				< (b["node"] as Node3D).global_position.distance_to(me)
			)
	)
	return (out[mini(n, out.size() - 1)]["node"] as Node3D).global_position


## Not standing in or right beside the pond (the Hunter would wade in after it).
func _dry(p: Vector3) -> bool:
	var c := FarmWater.nearest(Save.d, Vector2(p.x, p.z))
	return c.x < 0 or Vector2(c.x + 0.5, c.y + 0.5).distance_to(Vector2(p.x, p.z)) > 2.5


## Walks to within `near` m of `goal` (xz) with the real keys, each frame turned into the view's own terms.
func _walk(goal: Vector3, near: float) -> void:
	var left := int(LEG_S * FPS)
	while left > 0 and Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).length() > near:
		_keys(_steer(goal).rotated(h.cam.yaw))
		await rig.main.get_tree().process_frame
		_tidy()
		_orbit_step()
		left -= 1
	_keys(Vector2.ZERO)


## The way to `goal`, bent round any other staged Boki that is within AVOID_M (so none comes within MIN_GAP_M).
func _steer(goal: Vector3) -> Vector2:
	var me := Vector2(h.ppos.x, h.ppos.z)
	var dir := (Vector2(goal.x, goal.z) - me).normalized()
	for n in _show:
		var p3: Vector3 = (n as Node3D).global_position
		var p := Vector2(p3.x, p3.z)
		var d := me.distance_to(p)
		if d >= AVOID_M or p.distance_to(Vector2(goal.x, goal.z)) < 0.5:
			continue
		var away := (me - p) / maxf(d, 0.01)
		var side := dir.orthogonal()
		if side.dot(away) < 0.0:
			side = -side
		var k := clampf((AVOID_M - d) / (AVOID_M - MIN_GAP_M - 0.2), 0.0, 1.0)
		dir = (dir + (side + away) * 1.6 * k).normalized()
	return dir


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
var _flip_at := -999  # the frame of the last reversal (a tipped view takes a moment to settle)
var _flips := 0  # times this take the turn was reversed off a wall


func _orbit_start(turn: float, secs: float) -> void:
	_flips = 0
	_turn_left = int(secs * FPS)
	_turn_px = -turn / float(FarmCam.rules()["orbit_per_px"]) / float(_turn_left)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	h._unhandled_input(press)


func _orbit_step() -> void:
	if _turn_left <= 0:
		return
	if h.farm_cam.tip > TIP_FLIP and _flips < 2 and _frames - _flip_at > FPS:  # the turn swung the view behind a wall (it tipped top-down): turn back
		_turn_px = -_turn_px
		_flips += 1
		_flip_at = _frames
		print("PITCH orbit flipped at tip=%.2f" % h.farm_cam.tip)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(_turn_px, 0.0)
	h._unhandled_input(move)
	_turn_left -= 1
	if _turn_left == 0:
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_RIGHT
		release.pressed = false
		h._unhandled_input(release)
