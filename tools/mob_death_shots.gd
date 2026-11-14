extends RefCounted
## --mob-death-shots --shots-dir=<dir>: death strips on a real GPU (jobq --needs gpu). One strip per case, the
## same spot cropped at fixed times after the kill: mob_death_<case>.png, left to right (see TIMES). Cases: a
## skitter, a warden, a lair boss, and a wiped camp of skitters (the staggered kill).

const TIMES := [0.0, 0.1, 0.2, 0.3, 0.45, 0.6, 0.9]     # s after the kill
const CROP := 520                                       # px, the square around the screen centre
const STAND_FRAMES := 20                                # frames the foes are drawn alive before the kill
const SETTLE_S := 1.0                                   # s the camera gets to settle on the spot

var main: Node
var m: Match

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var dir := "user://mob_death_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
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
	await _case(dir, "skitter", 1)
	await _case(dir, "warden", 1)
	await _case(dir, "boss", 1)
	await _case(dir, "camp", 5)
	print("MOBDEATHSHOT DONE")
	main.get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## The foes to kill: `n` monsters (or the first lair's boss) a few metres ahead of the player.
func _foes(kind_s: String, n: int) -> Array:
	var P: Hunter = m.player
	if kind_s == "boss":
		var L: Dictionary = m.lairs.list[0]
		m.lairs.activate(L)
		if L["state"] == "sealed":
			m.lairs.open(L, m.player, "dial")
		var b: Boss = L["boss_mob"]
		b.dormant = false
		b.stagger_t = 0.0
		return [b]
	var at := P.pos + Vector3(0, 0, -3.0)
	var out: Array = []
	var mob_kind := "skitter" if kind_s == "camp" else kind_s
	for i in n:
		out.append(m.spawn_mob(mob_kind, at + Vector3((i % 3 - 1) * 1.0, 0, (i / 3) * 1.0)))
	return out

func _case(dir: String, kind_s: String, n: int) -> void:
	var P: Hunter = m.player
	if kind_s == "boss":
		var L: Dictionary = m.lairs.list[0]
		P.teleport(L["c"] + Vector3(L["out"].x, 0, L["out"].y) * 3.0 + Vector3(0, 1.0, 0))
	m.cam.focus = P.pos
	await _frames(int(SETTLE_S * 60.0))
	var foes := _foes(kind_s, n)
	await _frames(STAND_FRAMES)
	var mid := Vector3.ZERO
	for mb in foes:
		mid += mb.pos / foes.size()
	var strip := Image.create(CROP * TIMES.size(), CROP, false, Image.FORMAT_RGBA8)
	for mb in foes:
		mb.hurt(mb.hp + mb.max_hp, P, {"src": "shot"})
	var t0 := m.time
	for i in TIMES.size():
		while m.time - t0 < float(TIMES[i]):
			await main.get_tree().process_frame
		var img := main.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var c := Vector2i(m.cam.unproject_position(mid + Vector3(0, 0.8, 0)))
		var x := clampi(c.x - CROP / 2, 0, img.get_width() - CROP)
		var y := clampi(c.y - CROP / 2, 0, img.get_height() - CROP)
		strip.blit_rect(img, Rect2i(x, y, CROP, CROP), Vector2i(i * CROP, 0))
	strip.save_png(dir.path_join("mob_death_%s.png" % kind_s))
	print("MOBDEATHSHOT %s" % kind_s)
