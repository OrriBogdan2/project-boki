extends RefCounted
## --cinderstep-shots=<dir>: Cinderstep by day and by night, wide and close at the Stump Shove ledge (run
## with a real renderer, e.g. xvfb-run with --rendering-driver opengl3). Never touches the real save.

const Shots := preload("res://tools/farmbuild_shots.gd")
const WIDE_ZOOM := 2.6        # the whole island in one shot (the same as --home-wide)
const NEAR_ZOOM := 1.0
const NIGHT := 0.9            # day_t of a dark night

func run(m: Node) -> void:
	var dir := "/tmp/cinderstep_shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cinderstep-shots="): dir = a.substr(19)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	for sp in ["zapple", "burrlet", "cindle", "pebbit", "lodestick", "marchleaf"]:
		var rec := Save.new_kin(sp, sp)
		rec["zone"] = "cinderstep"
		Care.ensure(rec)
		d["roster"].append(rec)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	d["zones"]["cinderstep"] = {"open": true}
	HomeLayout.new_fs(d, 5)
	Save.d = d
	var s := Shots.new()
	s.main = m
	s.dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	var home = await m._hb_home("cinderstep")
	s.hm = home
	await s._ready_home(home)
	var spot: Array = GardenZones.info("cinderstep")["shove_at"]
	for t in [[0.5, "day"], [NIGHT, "night"]]:
		home.day_t = t[0]
		home.set_process(true)
		var middle := Vector2(home.world.w, home.world.h) * 0.5
		for look in [[WIDE_ZOOM, middle.x, middle.y, "wide"], [NEAR_ZOOM, spot[0], spot[1], "ledge"]]:
			s._look(home, Vector3(look[1], 0, look[2]), look[0])
			home.day_t = t[0]
			await s._shot("cinderstep_%s_%s" % [t[1], look[3]], "")
	m.get_tree().quit()
