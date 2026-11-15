class_name BaseShowcase
extends RefCounted
## The showcase wall beside the race post (briefs/design/GARDEN.md 5.1): a win in the Dash pins a small
## portrait of the winner, its name, the date and that week's twist. Up to MAX frames; the oldest
## drops off. Saved as Save.d["showcase"] = [{name, species, date, twist, img}] (img = base64 PNG,
## "" when there were no pixels); a missing key means an empty wall, so old saves need no migration.
## The visit snapshot carries it (Social.profile_doc) so friends see the same wall.

const MAX := 6               # frames on the wall
const IMG := 64              # px, side of a saved portrait
const CROP := 220            # px of screen cut around the winner before shrinking
const IMG_CHARS := 12000     # longest base64 portrait a visitor accepts (untrusted)
const WALL_OFF := Vector3(-0.6, 0, 2.4)   # m from the race post
const COLS := 3
const FRAME := 0.55          # m, a frame's side
const GAP := 0.12            # m between frames

## Pins a win on the wall (oldest drops off). Returns the new entry.
static func add(rec: Dictionary, tw: Dictionary, img := "") -> Dictionary:
	var e := {"name": String(rec["name"]), "species": String(rec["species"]),
		"date": Time.get_date_string_from_system(), "twist": String(tw.get("name", "")), "img": img}
	var wall: Array = Save.d.get("showcase", [])
	wall.append(e)
	Save.d["showcase"] = wall.slice(maxi(0, wall.size() - MAX))
	return e

## A small PNG (base64) of the screen around a world point; "" with no pixels (headless).
static func snap(vp: Viewport, cam: Camera3D, at: Vector3) -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var img := vp.get_texture().get_image()
	if img == null:
		return ""
	var c := cam.unproject_position(at)
	var x := clampi(int(c.x) - CROP / 2, 0, maxi(0, img.get_width() - CROP))
	var y := clampi(int(c.y) - CROP / 2, 0, maxi(0, img.get_height() - CROP))
	var part := img.get_region(Rect2i(x, y, CROP, CROP))
	part.resize(IMG, IMG, Image.INTERPOLATE_LANCZOS)
	return Marshalls.raw_to_base64(part.save_png_to_buffer())

static func texture(b64: String) -> Texture2D:
	if b64 == "" or b64.length() > IMG_CHARS:
		return null
	var raw := Marshalls.base64_to_raw(b64) if b64.length() % 4 == 0 else PackedByteArray()
	var img := Image.new()
	if raw.is_empty() or img.load_png_from_buffer(raw) != OK or img.get_width() > IMG or img.get_height() > IMG:
		return null
	return ImageTexture.create_from_image(img)

## A visitor's wall is untrusted: safe shapes, at most MAX frames.
static func clean(src) -> Array:
	var out: Array = []
	for ev in Social.arr_of(src).slice(0, MAX):
		var e := Social.dict_of(ev)
		var img := Social.txt_of(e.get("img"), "", IMG_CHARS)
		out.append({"name": Social.say_of(e.get("name"), "Kin", 14), "species": Social.txt_of(e.get("species"), "", 24),
			"date": Social.txt_of(e.get("date"), "", 10), "twist": Social.say_of(e.get("twist"), "", 24), "img": img})
	return out

## The wall as a node at pos: a board and one frame per entry, newest last.
static func build(pos: Vector3, wall: Array) -> Node3D:
	var n := Node3D.new()
	n.name = "Showcase"
	n.position = pos
	var rows := 2
	var w := COLS * (FRAME + GAP) + GAP
	var h := rows * (FRAME + GAP) + GAP
	n.add_child(_quad(Vector2(w, h), Color("6a4c34"), null, Vector3(0, h * 0.5 + 0.3, 0)))
	for i in mini(wall.size(), MAX):
		var e: Dictionary = wall[i]
		var cx := (i % COLS - (COLS - 1) * 0.5) * (FRAME + GAP)
		var cy := h - GAP - FRAME * 0.5 - (i / COLS) * (FRAME + GAP) + 0.3
		var tex := texture(String(e.get("img", "")))
		var paper := Color("e8dcc0") if tex == null else Color.WHITE
		n.add_child(_quad(Vector2(FRAME, FRAME), paper, tex, Vector3(cx, cy, 0.01)))
		var cap := Label3D.new()
		cap.text = "%s\n%s" % [e["name"], e["date"]]
		cap.font_size = 24
		cap.pixel_size = 0.0035
		cap.modulate = Color("f4e9cf")
		cap.position = Vector3(cx, cy - FRAME * 0.5 - 0.06, 0.02)
		cap.no_depth_test = false
		n.add_child(cap)
	return n

static func _quad(wh: Vector2, col: Color, tex: Texture2D, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = wh
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.albedo_texture = tex
	m.material_override = mat
	m.position = at
	return m
