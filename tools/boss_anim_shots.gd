extends RefCounted
## --boss-anim-shots --shots-dir=<dir> [--boss=<id>]: one strip per lair boss on a real GPU (jobq --needs gpu),
## boss_anim_<id>.png.
## Each row is a move cropped at the match camera, left to right at fixed times: the wake, every attack's
## wind-up into its strike (the fourth frame lands on the hit), the stagger, the phase change and the death.
## --reel-frames also saves every other drawn frame, cropped round the boss at the match camera, as
## <dir>/reel_<id>/NNNNN.jpg, for a clip made off the box: ffmpeg -framerate 30 -i <dir>/reel_<id>/%05d.jpg ...

const CROP := 460                       # px, the square round the boss
const SETTLE_S := 1.0                   # s the camera gets to settle
const FOE_AWAY := 5.0                   # m the player stands from the boss
const REEL := Vector2i(960, 640)        # px, each --reel-frames frame round the boss

var main: Node
var m: Match
var reel := false                       # --reel-frames
var reel_dir := ""                      # where the boss being filmed has its frames
var reel_b: Boss
var reel_n := 0

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var dir := "user://boss_anim_shots"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--boss="):
			only = String(a).substr(7)
		if a == "--reel-frames":
			reel = true
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for o in m.hunters:
		if o != m.player: o.ctrl = "idle"
	m.hud.visible = false
	for id in Data.BOSSES:
		if only == "" or only == id:
			await _boss(dir, id)
	print("BOSSANIMSHOT DONE")
	main.get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await _tick()

## One frame; with --reel-frames every other one is kept, round the boss.
func _tick() -> void:
	await main.get_tree().process_frame
	reel_n += 1
	if reel_b == null or reel_n % 2 == 1:
		return
	var img := main.get_viewport().get_texture().get_image()
	var c := Vector2i(m.cam.unproject_position(reel_b.pos + Vector3(0, 1.4, 0)))
	var x := clampi(c.x - REEL.x / 2, 0, maxi(0, img.get_width() - REEL.x))
	var y := clampi(c.y - REEL.y / 2, 0, maxi(0, img.get_height() - REEL.y))
	img.get_region(Rect2i(x, y, REEL.x, REEL.y)).save_jpg(reel_dir.path_join("%05d.jpg" % (reel_n / 2)), 0.9)

## Waits until `secs` after `t0` on match time, then crops the boss out of the screen into column `col` of row `row`.
func _grab(strip: Image, b: Boss, t0: float, secs: float, col: int, row: int) -> void:
	while m.time - t0 < secs:
		m.cam.focus = b.pos
		await _tick()
	var img := main.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var c := Vector2i(m.cam.unproject_position(b.pos + Vector3(0, 1.4, 0)))
	var x := clampi(c.x - CROP / 2, 0, img.get_width() - CROP)
	var y := clampi(c.y - CROP / 2, 0, img.get_height() - CROP)
	strip.blit_rect(img, Rect2i(x, y, CROP, CROP), Vector2i(col * CROP, row * CROP))

## A move to film: its times in seconds from the trigger, or (negative) fractions of the hit.
func _times(b: Boss, row_name: String) -> Array:
	match row_name:
		"wake": return [0.0, 0.3, 0.6, 0.9, 1.2, 1.5]
		"stagger": return [0.1, 0.5, 0.9, 1.3, 1.7]
		"phase": return [0.05, 0.25, 0.6, 1.0, 1.6, 2.2]
		"death": return [0.1, 0.3, 0.5, 0.75, 1.0, 1.3]
	var h := BossAnim.hit_t(b)
	return [h * 0.25, h * 0.5, h * 0.8, h, h + 0.15, h + 0.4]

func _trigger(b: Boss, row_name: String) -> void:
	b.next_cd = 1e9
	match row_name:
		"wake":
			m.lairs.wake(b.lair, m.player)
		"stagger":
			b.stagger_t = 2.2
		"phase":
			b._phase_up(1)
		"death":
			b.hurt(b.hp + b.max_hp, m.player, {"src": "shot"})
		_:
			b.call("_atk_" + row_name)

func _boss(dir: String, id: String) -> void:
	var L: Dictionary = m.lairs.list.filter(func(x): return x["boss"] == id)[0]
	m.lairs.activate(L)
	if L["state"] == "sealed":
		m.lairs.open(L, m.player, "dial")
	var b: Boss = L["boss_mob"]
	if reel:
		reel_dir = dir.path_join("reel_" + id)
		DirAccess.make_dir_recursive_absolute(reel_dir)
		reel_b = b
		reel_n = 0
	var P: Hunter = m.player
	P.teleport(b.pos + Vector3(FOE_AWAY, 0.5, 0))
	m.cam.focus = b.pos
	await _frames(int(SETTLE_S * 60.0))
	var rows: Array = ["wake"] + BossAnim.ATTACKS[id] + ["stagger", "phase", "death"]
	var strip := Image.create(CROP * 6, CROP * rows.size(), false, Image.FORMAT_RGBA8)
	for r in rows.size():
		var row_name: String = rows[r]
		if row_name != "wake":
			b._clear_attack()
			b.stagger_t = 0.0
		b.dormant = row_name == "wake"
		b.awake_t = 5.0
		await _frames(30)
		_trigger(b, row_name)
		var t0 := m.time
		var times := _times(b, row_name)
		for c in times.size():
			await _grab(strip, b, t0, float(times[c]), c, r)
	strip.save_png(dir.path_join("boss_anim_%s.png" % id))
	print("BOSSANIMSHOT %s %s" % [id, str(rows)])
