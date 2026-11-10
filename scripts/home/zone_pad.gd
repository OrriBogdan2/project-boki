class_name ZonePad
extends RefCounted
## The two spots that carry Boki between zones (briefs/design/GARDEN.md 10.4), owned by BaseLife and built once
## another zone is open: the return pad, where a Boki sent with "Move to..." walks and blinks out, and where one
## that would thrive elsewhere waits with a bubble (a Watch target, no new state); and the Waystone, where a
## Boki you set down opens the zone list. The pad is a Watch target: `target` has a "pos" like a Boki does.
## A sent Boki carries k["zone_go"] = zone id; an asking one k["zone_ask"] (walking) then k["zone_wait"] (waiting).

const PAD_COLOR := Color("7fc4d8")
const STONE_COLOR := Color("b9a9d8")
const PAD_R := 0.9      # m: the drawn pad's radius
const STONE_R := 1.4    # m: the drawn Waystone's radius

var h                      # the home (home.gd)
var R := GardenZones.rules()
var pad_at := Vector3.INF
var stone_at := Vector3.INF
var target := {}           # the pad as a Watch target
var _asked := {}           # uid -> true: asked once this visit

func _init(home) -> void:
	h = home

## True once another zone is open: only then do the pad and the Waystone stand in the zone.
func active() -> bool:
	return GardenZones.open_ids().size() > 1

func _build() -> void:
	if pad_at != Vector3.INF or not active() or not h.spots.has("portal"):
		return
	var portal: Vector3 = h.spots["portal"]
	pad_at = h.world.free_spot_near(portal + Vector3(4.0, 0, 1.0), [], 2.5, 1.2)
	stone_at = h.world.free_spot_near(portal + Vector3(-4.0, 0, 3.0), [pad_at], 3.0, 1.2)
	target = {"pos": pad_at}
	_disc(pad_at, PAD_R, PAD_COLOR)
	_disc(stone_at, STONE_R, STONE_COLOR)

func _disc(at: Vector3, r: float, col: Color) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.08
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	m.position = at + Vector3(0, 0.04, 0)
	h.add_child(m)

func step(dt: float) -> void:
	_build()
	if pad_at == Vector3.INF:
		return
	for k in h.kins.duplicate():
		if k.has("zone_go"):
			_walk_out(k, dt)

## A Boki on its way to the pad because you sent it: it goes, and blinks out when it gets there (or runs out of time).
func _walk_out(k: Dictionary, dt: float) -> void:
	k["goal"] = pad_at
	k["t"] = 2.0
	k["zone_t"] = float(k.get("zone_t", float(R["walk_secs"]))) - dt
	if not at_pad(k) and float(k["zone_t"]) > 0.0:
		return
	var id := String(k["zone_go"])
	var why := GardenZones.move(k["rec"], id)
	if why != "":
		k.erase("zone_go")
		k.erase("zone_t")
		h._toast(why)
		return
	Save.save_game()
	h._toast("%s went to %s" % [k["rec"]["name"], GardenZones.zone_name(id)])
	h.kins.erase(k)
	(k["node"] as Node3D).queue_free()

func at_pad(k: Dictionary) -> bool:
	return Vector2(k["pos"].x - pad_at.x, k["pos"].z - pad_at.z).length() < float(R["pad_r"])

## You sent `k` to zone `id` ("Move to..."): returns why not, or "" and it walks to the pad.
func send(k: Dictionary, id: String) -> String:
	var why := GardenZones.why_not(k["rec"], id)
	if why == "" and pad_at != Vector3.INF:
		k["zone_go"] = id
		k.erase("zone_ask")
		k.erase("zone_wait")
		k["zone_t"] = float(R["walk_secs"])
		k.erase("chase")
		k.erase("task")
	return why

## A roaming Boki that would thrive in another open zone maybe heads for the pad to ask (once a visit).
func ask(k: Dictionary) -> bool:
	var uid := String(k["rec"]["uid"])
	if pad_at == Vector3.INF or _asked.has(uid) or randf() >= float(R["ask_chance"]):
		return false
	if GardenZones.wants(k["rec"]) == "":
		return false
	_asked[uid] = true
	k["zone_ask"] = true
	k["zone_t"] = float(R["walk_secs"])
	k["goal"] = pad_at
	k["t"] = float(R["walk_secs"]) + 5.0      # the think timer outlasts the walk, so nothing re-aims it
	return true

## One step of a Boki walking to the pad to ask: true once it stands there; it gives up when time runs out.
func asking_arrived(k: Dictionary, dt: float) -> bool:
	k["zone_t"] = float(k["zone_t"]) - dt
	if at_pad(k):
		k.erase("zone_ask")
		return true
	if float(k["zone_t"]) <= 0.0:
		k.erase("zone_ask")
	return false

## It is at the pad: it says what it wants and waits (BaseLife makes it Watch the pad).
func wait(k: Dictionary) -> void:
	var id := GardenZones.wants(k["rec"])
	if id == "":
		k["life_for"] = 0.0
		return
	k["zone_wait"] = id
	k["life_for"] = float(R["ask_secs"])
	k["t"] = float(R["ask_secs"])
	var line := "%s keeps looking at %s. %s: send it?"
	h._say(k, line % [k["rec"]["name"], GardenZones.zone_name(id), Settings.key_cap("interact")], float(R["ask_secs"]))

## You pressed the key on a waiting Boki: send it where it asked. True when that was the press's meaning.
func answer(k: Dictionary) -> bool:
	if not k.has("zone_wait"):
		return false
	var id := String(k["zone_wait"])
	k.erase("zone_wait")
	var why := send(k, id)
	if why != "":
		h._toast(why)
	return true

## A Boki set down at `at`: on the Waystone it opens the zone list for it. True if it did.
func dropped(k: Dictionary, at: Vector3) -> bool:
	_build()
	if stone_at == Vector3.INF or Vector2(at.x - stone_at.x, at.z - stone_at.z).length() > float(R["waystone_r"]):
		return false
	ZoneMove.pick(h, k)
	return true
