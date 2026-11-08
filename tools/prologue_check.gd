extends RefCounted
## --prologue-check [--shots-dir=<dir>]: plays the prologue frame by frame (add --fixed-fps 60 for even strips) and
## checks the five slides and the owner's lines for 3 and 4, that in THE MASKS every Boki and the hunter stay
## inside the picture (between the letterbox bars) and never stand in each other, that the relic wakes,
## and that it ends on the hatch. With --shots-dir (under xvfb with a renderer) it also saves a 5-frame strip
## per slide (start, two key beats, middle, end) as <dir>/s<slide>_<n>.png with <dir>/captions.txt.

const SUNDERING := "The Hollowing broke the land into the floating Skylands,\nand the Wyrm stole our essence.\n" \
	+ "In time, humans, beasts and skyfolk alike were born without faces.\nWe became a new race: the Empty."
const MASKS := "Our only salvation became the cursed fossils we had tried to destroy:\n" \
	+ "Masks, each carrying the soul of a fallen Hunter of old."
## each slide's strip: [seconds in (from the end when negative, taken just before the wipe), caption]
const STRIP := [
	[[1.0, "start: the land whole at golden hour, a slow push in"], [2.6, "beat: the Crown on its isle"],
		[3.4, "middle: cut to a low angle on the Crown"], [5.0, "beat: the push in on the Crown"],
		[-0.2, "end: the Crown in the evening sun"]],
	[[1.0, "start: the calm before, over the towns to the Crown"],
		[2.6, "beat: the Wyrm rises behind the Crown and roars"],
		[3.5, "middle: cut wide, the sky reddening as it dives"], [4.6, "beat: fire on the towns, the frame shaking"],
		[-0.2, "end: the Wyrm climbs away over the burning land"]],
	[[1.0, "start: the burning land, the Wyrm circling"], [1.8, "beat: the land splits (flash, jolt, rocks)"],
		[3.2, "middle: the Masks burst out of the Crown"], [4.4, "beat: cut low, the isles drifting apart in dust"],
		[-0.2, "end: the isles sinking, rocks falling past"]],
	[[1.0, "start: a hunter at sunrise, the first Boki out of the grass"],
		[2.4, "beat: the lead Boki greets him, he kneels"],
		[3.9, "middle: cut side-on, it rears up to nose the relic in his hands and it wakes"],
		[5.4, "beat: the woken relic hangs glowing in Vex's colour between them"],
		[-0.2, "end: the Boki jump for joy, the Mask rising off him"]],
	[[1.0, "start: behind the hunters gliding for the Heart"], [2.8, "beat: the Heart's beam ahead"],
		[4.2, "middle: cut to the reveal over the isles"], [5.6, "beat: two eyes open far down in the clouds"],
		[-0.2, "end: the Wyrm watching the race"]],
]
const FRAME := Vector2i(1280, 720)      # px: the game's window (project.godot), the smallest it frames for
## px: the game's window, a big one, a small one
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(800, 450)]
const BOKI_GAP := 0.75          # m: the least room between two Boki, or a Boki and the hunter's feet

var bad := 0
var main: Node
var dir := ""
var caps: Array = []

func ok(cond: bool, what: String) -> void:
	print("PROLOGUE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
		RenderingServer.render_loop_enabled = false      # drawn only for the strip frames (a soft renderer is slow)
	main.get_window().size = FRAME      # headless runs start on a square window; frame it as the game does
	await main.show_screen("prologue", {"then": "hatch"})
	var pr = main.current
	var tree := main.get_tree()
	if main.fade:
		main.fade.reveal(0.05)      # the boot splash still covers a screen made straight from a tool
	if pr == null or not ("shots" in pr):
		ok(false, "the prologue opens")
		tree.quit(1)
		return
	ok(pr.shots.size() == 5, "five slides (%d)" % pr.shots.size())
	ok(String(pr.shots[2]["text"]) == SUNDERING, "THE HOLLOWING reads the owner's line")
	ok(String(pr.shots[3]["text"]) == MASKS, "THE MASKS reads the owner's line")
	await _captions_fit(pr, tree)
	main.get_window().size = FRAME
	await _play(pr, tree)
	for i in 900:
		if main.current != pr:
			break
		await tree.process_frame
	var hatch: bool = main.current != pr and main.current.get_script().resource_path.ends_with("hatch.gd")
	ok(hatch, "the prologue ends on the hatch")
	if dir != "":
		var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
		for c in caps:
			f.store_line(c)
		f.close()
	print("PROLOGUE done, %d failed" % bad)
	RenderingServer.render_loop_enabled = true
	tree.quit(1 if bad else 0)

## Steps through the slides, taking the strip frames and watching THE MASKS's framing every frame.
func _play(pr, tree: SceneTree) -> void:
	var worst_gap := 99.0
	var out_frames := 0
	var first_out := ""
	var boki_frames := 0
	for i in 5:
		var dur := float(pr.shots[i]["dur"])
		for n in 5:
			var at := float(STRIP[i][n][0])
			if at < 0.0:
				at += dur
			while pr.shot < i or (pr.shot == i and pr.shot_t < at):
				await tree.process_frame
				if pr.shot != 3:
					continue
				boki_frames += 1
				worst_gap = minf(worst_gap, _boki_gap(pr))
				var out := _out_of_frame(pr)
				if pr.shot_t > 1.2 and out != "":
					out_frames += 1
					if first_out == "":
						first_out = ", first %s at %.1f s" % [out, pr.shot_t]
			await _shot(i, n, pr)
	ok(boki_frames > 100 and out_frames == 0, "THE MASKS: every Boki and the hunter stay inside the frame"
		+ " (%d of %d frames out%s)" % [out_frames, boki_frames, first_out])
	ok(worst_gap >= BOKI_GAP, "THE MASKS: no Boki stands in the hunter or another Boki (closest %.2f m)" % worst_gap)
	ok(pr.boki.relic_k > 0.9, "THE MASKS: the relic wakes (%.2f)" % pr.boki.relic_k)

## The least ground distance between any two Boki, or a Boki and the hunter, while they are out.
func _boki_gap(pr) -> float:
	var g := 99.0
	var bodies: Array = [pr.boki.kin_hunter]
	for k in pr.boki.kin_nodes:
		if (k as Node3D).visible:
			bodies.append(k)
	for a in bodies.size():
		for b in range(a + 1, bodies.size()):
			var d: Vector3 = (bodies[a] as Node3D).global_position - (bodies[b] as Node3D).global_position
			g = minf(g, Vector2(d.x, d.z).length())
	return g

## Which of the hunter and the Boki out pokes past the picture (the frame edges or the letterbox bars): its
## name, or "" when all of them sit wholly inside.
func _out_of_frame(pr) -> String:
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var top: float = pr.bar_top.offset_bottom
	var bot: float = vp.y + pr.bar_bot.offset_top
	var cam: Camera3D = pr.cam
	var bodies: Array = [[pr.boki.kin_hunter, 1.8, 0.45, "the hunter"]]
	for i in pr.boki.kin_nodes.size():
		var k: Node3D = pr.boki.kin_nodes[i]
		if k.visible:
			bodies.append([k, 0.9, 0.45, String(PrologueBoki.BOKI_SPOTS[i][0])])
	for b in bodies:
		var at: Vector3 = (b[0] as Node3D).global_position
		var side: Vector3 = cam.global_basis.x * float(b[2])
		for p in [at + Vector3(0, float(b[1]), 0), at + side, at - side]:
			var px := cam.unproject_position(p)
			var off_x := px.x < 0.0 or px.x > vp.x
			if cam.is_position_behind(p) or off_x or px.y < top or px.y > bot:
				return String(b[3])
	return ""

func _shot(i: int, n: int, pr) -> void:
	if dir == "":
		return
	RenderingServer.render_loop_enabled = true
	for k in 2:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = main.get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	if img.get_width() > 1280:
		img.resize(1280, int(img.get_height() * 1280.0 / img.get_width()))
	var file := "s%d_%d.png" % [i + 1, n + 1]
	img.save_png(dir.path_join(file))
	caps.append("%s: %s, %.1f s in. %s" % [file, String(pr.shots[i]["chapter"]), pr.shot_t, String(STRIP[i][n][1])])

## Item 77: every slide's caption stays fully on screen (wrapped, growing upward) at the game's window, a big
## one and a small one. With --shots-dir each is saved as <dir>/caption_<width>_s<slide>.png.
func _captions_fit(pr, tree: SceneTree) -> void:
	var worst := 0.0
	var lines := 0
	for size in WINDOWS:
		main.get_window().size = size
		for i in 3:
			await tree.process_frame
		for i in pr.shots.size():
			pr.caption.text = String(pr.shots[i]["text"])
			pr.caption.visible_ratio = 1.0
			pr.caption.modulate.a = 1.0
			for n in 2:
				await tree.process_frame
			# (canvas units: the window's stretch applies)
			var view: Rect2 = pr.caption.get_viewport().get_visible_rect()
			var box: Rect2 = pr.caption.get_global_rect()
			var over := maxf(maxf(view.position.x - box.position.x, view.position.y - box.position.y),
				maxf(box.end.x - view.end.x, box.end.y - view.end.y))
			worst = maxf(worst, over)
			lines = maxi(lines, pr.caption.get_line_count())
			if dir != "":
				RenderingServer.render_loop_enabled = true
				await tree.process_frame
				await tree.process_frame
				tree.root.get_texture().get_image().save_png(dir.path_join("caption_%d_s%d.png" % [size.x, i + 1]))
				RenderingServer.render_loop_enabled = false
	ok(worst <= 0.5, "every caption stays on screen at %s (worst overhang %.1f px, up to %d lines)"
		% [str(WINDOWS), worst, lines])
