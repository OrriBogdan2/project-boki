extends RefCounted
## --mob-pose-shots --shots-dir=<dir> [--kinds=a,b]: each monster in a real match on the start island, shot as the
## game plays it (jobq --needs gpu). Spawned beside the still player (god mode, kin off), it is cropped once per
## state: mob_pose_<kind>.png = idle | walk | windup (its last frame) | strike, left to right (blank: never seen).

const CROP := 340         # px, the square around the monster
const WAIT_S := 14.0      # s a monster gets to show all four states
const ORDER := ["idle", "walk", "windup", "strike"]

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
	var dir := "user://mob_pose_shots"
	var kinds := ["skitter", "spitter", "bomber", "glimmer", "warden", "brute", "sentinel"]
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--kinds="):
			kinds = Array(String(a).substr(8).split(","))
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for o in m.hunters:  # only the player stays, and nothing fires at the monster
		if o != m.player:
			o.ctrl = "idle"
			o.visible = false
	for k in m.kins:
		k.dead = true
		k.visible = false
	m.hud.visible = false
	var P: Hunter = m.player
	var best := Vector2.INF
	for isl in m.world.islands:  # the island the player starts on: step 8 m in from its edge
		var c2: Vector2 = isl["c"]
		if c2.distance_to(Vector2(P.pos.x, P.pos.z)) < best.distance_to(Vector2(P.pos.x, P.pos.z)):
			best = c2
	if best != Vector2.INF:
		var to := (best - Vector2(P.pos.x, P.pos.z)).limit_length(8.0)
		var q := Vector2(P.pos.x, P.pos.z) + to
		if not m.world.is_void(q.x, q.y) and not m.world.is_block(q.x, q.y):
			P.teleport(Vector3(q.x, m.world.ground_at(q.x, q.y) + 1.0, q.y))
	m.cam.user_zoom = float(CamWheel.rules()["min"])  # the wheel's closest view
	await _frames(30)
	P.process_mode = Node.PROCESS_MODE_DISABLED  # the player stands still and never fires back
	for k in kinds:
		await _case(dir, String(k))
	print("MOBPOSESHOT DONE")
	main.get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame


func _case(dir: String, kind: String) -> void:
	var P: Hunter = m.player
	m.cam.focus = P.pos
	await _frames(60)
	var mb := m.spawn_mob(kind, _ground(P.pos, 4.5))
	var strip := Image.create(CROP * ORDER.size(), CROP, false, Image.FORMAT_RGBA8)
	var got := {}
	var t0 := m.time
	var wind_img: Image = null  # the latest windup frame: kept when the windup ends, so the fullest gather shows
	while got.size() < ORDER.size() and m.time - t0 < WAIT_S and is_instance_valid(mb) and not mb.dead:
		await main.get_tree().process_frame
		var t := m.time - t0
		if t < 1.2:
			mb.root_t = 0.1  # held in place: its idle loop, not a wander
		if mb.st in ["lunge", "recover"]:
			mb.stagger_t = 0.0  # the blow itself, not the stagger a whiffed slam opens
		var s: int = MobAnim.state_of(mb)
		if s != MobAnim.WINDUP and wind_img != null and not got.has("windup"):
			strip.blit_rect(wind_img, Rect2i(0, 0, CROP, CROP), Vector2i(ORDER.find("windup") * CROP, 0))
			got["windup"] = true
		var nm := ""
		if s == MobAnim.IDLE and t > 0.8 and t < 1.2:
			nm = "idle"
		elif s == MobAnim.WALK or s == MobAnim.RUN:
			nm = "walk"
		elif s == MobAnim.WINDUP:
			nm = "windup"
		elif s == MobAnim.STRIKE and MobAnim.phase_of(mb, s, 0.0) > 0.15:
			nm = "strike"
		if not got.has("windup") and wind_img == null and mb.st in ["idle", "chase"] and t > 5.0:
			mb.tgt = P
			mb._begin_attack()  # a held-off monster (engaged cap, hiding) still shows its attack
		if nm == "" or got.has(nm):
			continue
		var crop := await _grab(mb)
		if nm == "windup":
			wind_img = crop
			continue
		strip.blit_rect(crop, Rect2i(0, 0, CROP, CROP), Vector2i(ORDER.find(nm) * CROP, 0))
		got[nm] = true
	if wind_img != null and not got.has("windup"):  # a bomber's fuse ends in the blast
		strip.blit_rect(wind_img, Rect2i(0, 0, CROP, CROP), Vector2i(ORDER.find("windup") * CROP, 0))
		got["windup"] = true
	strip.save_png(dir.path_join("mob_pose_%s.png" % kind))
	print("MOBPOSESHOT %s %s" % [kind, str(got.keys())])
	if is_instance_valid(mb) and not mb.dead:  # gone quietly: no blast, no drops piling up for the next one
		mb.hp = 0.0
		mb.dead = true
		mb._cancel_tele()
		mb.visible = false
	await _frames(60)


## The CROP square around the monster on the frame just drawn.
func _grab(mb: Mob) -> Image:
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var c := Vector2i(m.cam.unproject_position(mb.pos + Vector3(0, 0.8, 0)))
	var x := clampi(c.x - CROP / 2, 0, img.get_width() - CROP)
	var y := clampi(c.y - CROP / 2, 0, img.get_height() - CROP)
	return img.get_region(Rect2i(x, y, CROP, CROP))


## A ground spot `d` m from `at`, north-east first (in front of the camera), never over the void.
func _ground(at: Vector3, d: float) -> Vector3:
	for i in 16:
		var a := -PI / 3.0 + i * TAU / 16.0
		var q := at + Vector3(sin(a), 0, -cos(a)) * d
		if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z):
			return Vector3(q.x, m.world.ground_at(q.x, q.z), q.z)
	return at + Vector3(0, 0, -d)

