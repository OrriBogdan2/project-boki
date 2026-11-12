extends RefCounted
## --fish-watch-shots --shots-dir=<dir> [--px=320]: Glint Fishing with your partner, in the engine: seated by
## you at the aim, leaning in on the bite, hopping on a catch, hopping higher on a rare one. One strip,
## fish_watch.png, a frame each. Needs a renderer.

const WAIT_S := 30.0         # s to wait for the zone to load and the partner to walk over
const FRAMES := 4
const CHEER_FRAMES := 40     # frames watched for the top of a hop
const CAM_AHEAD_M := 2.4     # m the camera stands out over the water, 3/4 in front of the partner
const CAM_AWAY_M := 1.2      # m it steps off the partner's side away from you, so you never block it

var main: Node
var px := 320
var out := "shots"
var you := Vector3.ZERO      # where you stand fishing

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--px="): px = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	Content.rules("farm_build")["base_mode"] = true
	var d := Save.fresh()
	(d["roster"] as Array).append(Save.new_kin("zapple", "Pip"))
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	d["zones"]["glasswater"] = {"open": true}
	Save.d = d
	HomeLayout.ensure(d)
	Game.goto("home", {"zone": "glasswater"})
	var gw = await _wait_home()
	if gw == null or gw.hfish == null:
		print("FISH_WATCH_SHOTS_FAIL no rock")
		main.get_tree().quit(1)
		return
	var gf: GlintFishing = gw.hfish
	for k in gw.kins:
		k.erase("indoors")
		k["busy"] = false
	gf.use()
	var pk: Dictionary = gf.who
	var w := 0.0
	while w < WAIT_S and not pk.get("busy", false):
		await main.get_tree().process_frame
		w += main.get_process_delta_time()
	var n: Node3D = pk["node"]
	you = gw.ppos
	gw.root_ui.visible = false     # the partner and the bobber, without the panels over them
	var cam := Camera3D.new()
	gw.add_child(cam)
	cam.make_current()
	var strip := Image.create(px * FRAMES, px * 9 / 16, false, Image.FORMAT_RGBA8)
	await _frame(strip, 0, cam, n)
	var run: GlintFishing.Run = gf.run
	run.hooked = 0
	run.bite_t = 3.0
	run.go(GlintFishing.Run.S.WAIT)
	while not run.ears():
		gf.tick(0.1)
	await _frame(strip, 1, cam, n)
	run.go(GlintFishing.Run.S.SHOW)
	for rare in [false, true]:
		run.casts.append({"how": "caught", "catch": run.glints[0]["catch"], "rare": rare})
		gf._entered(GlintFishing.Run.S.SHOW)
		await _frame(strip, 2 + int(rare), cam, n, true)
	strip.save_png(out.path_join("fish_watch.png"))
	print("FISH_WATCH_SHOTS_DONE")
	Content.rules("farm_build")["base_mode"] = false
	main.get_tree().quit()

## Grabs frame `i` of the strip: the next one, or (for a hop) the one where the Boki is highest.
func _frame(strip: Image, i: int, cam: Camera3D, n: Node3D, hop := false) -> void:
	var best := -1.0
	for _f in (CHEER_FRAMES if hop else 3):
		var ahead := -n.global_transform.basis.z
		var away := (n.global_position - you).normalized()
		cam.global_position = n.global_position + ahead * CAM_AHEAD_M + away * CAM_AWAY_M + Vector3(0, 0.9, 0)
		cam.look_at(n.global_position + Vector3(0, 0.8, 0))
		await main.get_tree().process_frame
		var y: float = (n.get_node("Body") as Node3D).position.y
		if not hop or y > best:
			best = y
			var img: Image = main.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(px, px * 9 / 16)
			strip.blit_rect(img, Rect2i(0, 0, px, px * 9 / 16), Vector2i(i * px, 0))

func _wait_home():
	var t := 0.0
	var was: Node = Game.main.current
	while t < WAIT_S:
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
		var cur = Game.main.current
		if cur != was and is_instance_valid(cur) and cur.get("hway") != null and cur.get("player") != null \
				and cur.get("building") != true and cur.get("root_ui") != null and not Game.main.fade.covered:
			return cur
	return null
