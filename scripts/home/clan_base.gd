class_name ClanBase
extends RefCounted
## A clan's shared base (docs/specs/CLANS.md sections 3 and 5.2). Going there is a visit (home.gd's visit
## path) to an island built from the clan: every member gets a corner with a signpost, a little of their
## house decor and some of their Boki, all from the island snapshot they already publish (no new writes);
## the showcase wall shows the Boki in clanbase/<gid>, cleaned by Social.clean_clanbase.

const SLOTS := 24               # corner places round the island; at least Social.CLAN_CAP so every member fits
const KIN_BUDGET := 24          # corner Boki on the island at most (each runs the farm kin AI), split across members
const KIN_PER_CORNER := 3       # a corner's Boki when the clan is small enough
# where a corner's house decor stands, in metres beside the sign
const DECOR_AT := [Vector3(1.0, 0, 0.4), Vector3(-1.0, 0, 0.4)]
const RING := 0.62              # corners sit at this fraction of the home island's radius
const DECOR_SCALE := 0.45       # house furniture is room-sized; shrunk to sit beside a signpost
const WALL_GAP := 0.9           # metres between Boki on the showcase wall

## Reads the clan's members, roll and base doc, then goes there. The house gifts go to the founder.
static func open(gid: String, gdoc: Dictionary) -> void:
	var founder := Social.txt_of(gdoc.get("founder"))
	Social.guild_members(gid, func(members: Array):
		Social.clan_roster(gid, founder, func(roll: Array):
			Social.get_doc("clanbase/" + gid, func(d: Dictionary):
				Game.goto("home", {"visit": snapshot(gid, gdoc, members, roll, d), "visit_id": founder}))))

## The visit snapshot: shaped like Social.clean_island's, named for the clan; its Boki are the corners' Boki.
## members: [{id, d}] as Social.guild_members gives them; roll: Social.clan_roster rows; base_doc: raw clanbase doc.
static func snapshot(gid: String, gdoc: Dictionary, members: Array, roll: Array, base_doc: Dictionary) -> Dictionary:
	var cs := corners(gid, members, roll)
	var kin: Array = []
	for c in cs:
		kin.append_array(c["kin"])
	var ids: Array = members.map(func(m): return m["id"])
	var snap := Social.clean_island({})
	snap["name"] = Social.say_of(gdoc.get("name"), "Clan", 24)
	snap["guild"] = gid
	snap["roster"] = kin
	snap["clan_base"] = {"corners": cs, "showcase": Social.clean_clanbase(base_doc, ids)["showcase"]}
	return snap

## One corner per member: {id, name, slot, kin, decor}. A member's corner seed (from the roll, or the one
## they'd be given) picks the slot; the next free slot if two seeds collide.
static func corners(gid: String, members: Array, roll: Array) -> Array:
	var seeds := {}
	for r in roll:
		seeds[r["id"]] = r["corner_seed"]
	var sorted := members.slice(0, Social.CLAN_CAP)
	sorted.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	var per := clampi(KIN_BUDGET / maxi(1, sorted.size()), 1, KIN_PER_CORNER)
	var taken := {}
	var out: Array = []
	for m in sorted:
		var id: String = m["id"]
		var corner_seed: int = seeds.get(id, Social.clan_for(gid, id, "member", 0.0)["corner_seed"])
		var slot := corner_seed % SLOTS
		while taken.has(slot):
			slot = (slot + 1) % SLOTS
		taken[slot] = true
		var kin: Array = []
		for rec in (m["d"]["roster"] as Array).slice(0, per):
			var k: Dictionary = rec.duplicate()
			k["owner"] = id
			kin.append(k)
		out.append({"id": id, "name": m["d"]["name"], "slot": slot, "kin": kin,
			"decor": (m["d"]["decor"] as Array).slice(0, DECOR_AT.size())})
	return out

## home.gd calls this once a visit is built; it draws nothing unless the visit is a clan base.
static func draw(home: Node3D, world: World, kins: Array, base: Dictionary) -> void:
	if base.is_empty():
		return
	var root := Node3D.new()
	root.name = "ClanBase"
	home.add_child(root)
	var isl: Dictionary = world.islands[0]
	var mid: Vector2 = isl["c"]
	var rad: float = float(isl["r"]) * RING
	var taken: Array = []
	var names := {}
	for corner in base["corners"]:
		names[corner["id"]] = corner["name"]
		var a := TAU * int(corner["slot"]) / SLOTS
		var want := Vector3(mid.x + cos(a) * rad, 0, mid.y + sin(a) * rad)
		var at := world.free_spot_near(want, taken, 2.0)
		taken.append(at)
		_corner(root, corner, at, a)
		_gather(world, kins, String(corner["id"]), at)
	var wall_at := world.free_spot_near(Vector3(mid.x, 0, mid.y), taken, 3.0)
	_wall(root, base["showcase"], names, wall_at)

## A signpost with the member's name, facing the middle, and their decor beside it.
static func _corner(root: Node3D, corner: Dictionary, at: Vector3, a: float) -> void:
	var holder := Node3D.new()
	holder.name = "Corner_" + String(corner["id"])
	holder.position = at
	holder.rotation.y = -a - PI * 0.5
	root.add_child(holder)
	holder.add_child(Models.signpost([String(corner["name"])]))
	for i in corner["decor"].size():
		var e: Dictionary = corner["decor"][i]
		var f := Models.furniture(String(e["id"]))
		f.scale = Vector3.ONE * DECOR_SCALE
		f.position = DECOR_AT[i]
		f.rotation.y = int(e["r"]) * PI * 0.5
		holder.add_child(f)

## The member's Boki start out in their corner.
static func _gather(world: World, kins: Array, who: String, at: Vector3) -> void:
	var near: Array = [at]
	for kd in kins:
		if (kd["rec"] as Dictionary).get("owner", "") != who:
			continue
		var p := world.free_spot_near(at, near, 1.2)
		near.append(p)
		(kd["node"] as Node3D).position = p
		kd["pos"] = p

## A long shelf with each showcased Boki standing on it, its name and its keeper's (names: member id -> name).
static func _wall(root: Node3D, wall: Array, names: Dictionary, at: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "ShowcaseWall"
	holder.position = at
	root.add_child(holder)
	var width := maxf(3.0, wall.size() * WALL_GAP + 0.6)
	Models.part(holder, Models.box(width, 1.8, 0.15), Models.toon(Color("8a5a35")), Vector3(0, 0.9, -0.35))
	Models.part(holder, Models.box(width, 0.12, 0.6), Models.toon(Color("c49a6a")), Vector3(0, 0.5, 0))
	var title := Label3D.new()
	title.text = "Showcase wall"
	title.font = UI.big
	title.font_size = 40
	title.pixel_size = 0.01
	title.position = Vector3(0, 2.05, -0.25)
	holder.add_child(title)
	for i in wall.size():
		var rec: Dictionary = wall[i]
		var x := (i - (wall.size() - 1) * 0.5) * WALL_GAP
		var k := Models.kin(String(rec["species"]), rec)
		k.scale = Vector3.ONE * 0.5
		k.position = Vector3(x, 0.56, 0)
		holder.add_child(k)
		var tag := Label3D.new()
		tag.text = "%s\n%s" % [rec["name"], names.get(rec["owner"], "")]
		tag.font_size = 24
		tag.pixel_size = 0.006
		tag.position = Vector3(x, 0.3, 0.32)
		holder.add_child(tag)
