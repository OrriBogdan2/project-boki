extends RefCounted
## --fog-tint-shots --shots-dir=<dir> [--raid=<condition>]: the Hollow Crown at the match camera with the HUD off,
## standing in three biomes (meadow, frost, first other one found): <dir>/<biome>.png. Prints one FOGTINT line per
## shot: mean blue minus mean red (0-255) over the top third (far ground and sky) and the whole frame. Run on a
## real GPU (jobq --needs gpu). The owner's "blue fog" bug: the haze should stay neutral, not drift blue.

const SPAWN_WAIT := 30   # frames before moving anyone (the match puts you on the map)
const SETTLE := 40       # frames at each spot (the camera settles, the fade clears)
const SEED := 5101
const WANT := ["meadow", "frost"]
const STEP := 8.0        # m: grid step of the biome scan

var main: Node
var dir := "user://fog_tint_shots"
var raid := "clear"

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d["first_guide"] = 99
	Settings.set_v("tips", false, false)
	Game.god = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--raid="): raid = String(a).substr(7)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 4, "squad": 1, "tier": 0, "length": 1500.0, "seed": SEED, "no_drop": true, "raid": raid,
		"tut_test": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for i in SPAWN_WAIT:
		await main.get_tree().process_frame
	for spot in _spots(m):
		m.player.teleport(spot[1])
		for i in SETTLE:
			await main.get_tree().process_frame
		var img := main.get_viewport().get_texture().get_image()
		img.save_png(dir.path_join(String(spot[0]) + ".png"))
		var top := _blue_red(img, 0.0, 0.33)
		print("FOGTINT %s %s top_b-r=%+.1f all_b-r=%+.1f" % [raid, spot[0], top, _blue_red(img, 0.0, 1.0)])
	Game.god = false
	main.get_tree().quit()

## [[biome, position]]: the open ground nearest the map centre in each wanted biome, then in one more.
func _spots(m: Match) -> Array:
	var found := {}
	for xi in int(m.world.w / STEP):
		for zi in int(m.world.h / STEP):
			var x := xi * STEP
			var z := zi * STEP
			if m.world.is_void(x, z) or m.world.is_block(x, z) or m.world.in_bush(x, z):
				continue
			var b: String = m.world.biome_at(x, z)
			var p := Vector3(x, m.world.ground_at(x, z), z)
			if not found.has(b) or _off_centre(m, p) < _off_centre(m, found[b]):
				found[b] = p
	var out := []
	for b in WANT:
		if found.has(b):
			out.append([b, found[b]])
	for b in found:
		if out.size() >= 3: break
		if not WANT.has(b):
			out.append([b, found[b]])
	return out

## m: how far `p` is from the middle of the map (the Blight closes in from the edges).
func _off_centre(m: Match, p: Vector3) -> float:
	return Vector2(p.x - m.world.w * 0.5, p.z - m.world.h * 0.5).length()

## Mean blue minus mean red (0-255) over the rows from `top` to `bot` (fractions of the height), right of the minimap.
static func _blue_red(img: Image, top: float, bot: float) -> float:
	var sr := 0.0
	var sb := 0.0
	var n := 0
	for y in range(int(img.get_height() * top), int(img.get_height() * bot), 4):
		for x in range(int(img.get_width() * 0.3), int(img.get_width() * 0.95), 4):   # (no minimap)
			var c := img.get_pixel(x, y)
			sr += c.r
			sb += c.b
			n += 1
	return (sb - sr) / maxf(n, 1) * 255.0
