extends RefCounted
## --ridge-shots --shots-dir=<dir>: Kitewind Ridge (GARDEN.md 10.2, theme "ridge") for review. ridge_day.png and
## ridge_night.png show the demo base on the ridge (post, two updraft vents, the ripe snack patch); ridge_track.png
## shows a Dash on the ridge course (glide gaps, updraft climb). Needs a renderer. Never touches the real save.

const DAY := 0.42           # day_t for the day shot
const NIGHT := 0.97         # day_t for the night shot
const ZOOM_BASE := 1.25     # camera zoom (0.8 close .. 1.6 wide)
const ZOOM_TRACK := 0.75
const WIPE_S := 1.2           # s for the ink wipe to clear before a shot
const RACE_SECS := 6.0      # s of racing before the course shot
const WAIT_FRAMES := 900    # frames to wait at most for the home to build

var bad := 0
var main: Node
var dir := "/tmp/ridge_shots"

func ok(cond: bool, what: String) -> void:
	print("RIDGE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _shot(home, shot: String) -> void:
	for i in 3:
		await main.get_tree().process_frame
	if main.fade:
		main.fade.reveal(0.05)
	await main.get_tree().create_timer(WIPE_S).timeout
	home._close_panel()
	if home.guide and home.guide.tracker:
		home.guide.tracker.visible = false
	home.hover_box.visible = false
	home.prompt_box.visible = false
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot])
	print("RIDGE shot %s" % shot)

func _ready(home) -> void:
	for i in WAIT_FRAMES:
		if home.root_ui != null and home.hb != null and home.player != null:
			break
		await main.get_tree().process_frame

func _look(home, at: Vector3, zoom: float) -> void:
	home.ppos = at
	home.player.position = at
	home.cam.zoom_to = zoom
	home.cam.zoom = zoom
	home.cam.snap(at)

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	await _base()
	await _track()
	FarmUnlocks.rules()["base_mode"] = false
	print("RIDGE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The demo base on the ridge, by day and by night.
func _base() -> void:
	Save.d = BaseDemo.save("ridge")
	var home = await main._hb_home()
	await _ready(home)
	BaseDemo.new().stage(home)
	var ids: Array = home.toys.toys().map(func(t): return t["id"])
	ids.sort()
	ok(ids == ["toy_post", "toy_vent", "toy_vent"] and HomeLayout.count_of(SnackPatch.ID, Save.d) == 1,
			"the ridge base has its post, two vents and a snack patch (%s)" % str(ids))
	_look(home, HomeLayout.LANDING + Vector3(-2.5, 0, -2.5), ZOOM_BASE)
	home.day_t = DAY
	await _shot(home, "ridge_day")
	home.day_t = NIGHT
	await main.get_tree().create_timer(0.5).timeout
	await _shot(home, "ridge_night")
	home.queue_free()
	await main.get_tree().process_frame

## A Dash on the ridge course, a few seconds in.
func _track() -> void:
	var d := Save.fresh()
	for i in 3:
		var k := Save.new_kin(["kestrike", "zapple", "cindle"][i], ["Kes", "Pip", "Ash"][i])
		Care.ensure(k)
		k["level"] = 5
		d["roster"].append(k)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	d["layout"]["theme"] = "ridge"
	Save.d = d
	HomeLayout.ensure(Save.d)
	FarmUnlocks.rules()["base_mode"] = true
	var home = await main._hb_home()
	await _ready(home)
	home.day_t = DAY
	var race: BaseRace = home.hrace
	for k in home.kins:
		k.erase("indoors")
	race.use()
	var t := 0.0
	while race.run != null and t < RACE_SECS:
		race.tick(0.1)
		t += 0.1
	ok(race.run != null, "the ridge Dash is running after %.0f s" % RACE_SECS)
	race.bar.card.visible = false
	_look(home, race.start + Vector3(BaseRace.LOOP_W * 0.5, 0, -1.5), ZOOM_TRACK)
	await _shot(home, "ridge_track")
	home.queue_free()
	await main.get_tree().process_frame
