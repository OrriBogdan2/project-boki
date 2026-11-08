extends RefCounted
## --prologue-check [--shots-dir=<dir>]: plays the prologue frame by frame (add --fixed-fps 60 for even strips) and
## checks the six storybook panels of origin v3 (briefs/LORE_MASKS.md: Solmere, Malgrave's mask, Kael's uprising,
## Sable drops the Heart, the Hollowing, you drop in), that it runs about 45 s, that each panel names who it
## must, that Kael and the Auburn Knights stand in the uprising's picture, that the Heart hits the vault
## floor, that the Heart below is crimson, and that it ends on the hatch. With --shots-dir (under xvfb with a
## renderer) it also saves a 5-frame strip per panel (start, two key beats, middle, end) as
## <dir>/s<panel>_<n>.png with <dir>/captions.txt.

const CHAPTERS := ["SOLMERE", "THE MASK", "THE UPRISING", "THE THIEF", "THE HOLLOWING", "THE DESCENT"]
## words each panel's line must carry (the round 5 locks: the kingdom, the queen, the guard, the thief)
const NAMES := [["Solmere", "Malgrave"], ["mask", "Wyrmheart"], ["Kael", "Auburn Knights", "Wyrm"], ["Sable", "Heart"],
	["Hollow", "Skylands", "Heart"], ["Relics", "Hunter's Relic", "Boki", "Heart"]]
const RUN_S := Vector2(38.0, 46.0)      # s: the panels' own time, the brief's ~45 s less the fades and title card
const FADE_S := 0.7                     # s: Prologue's fade between panels (_advance)
## each panel's strip: [seconds in (from the end when negative, taken just before the wipe), caption]
const STRIP := [
	[[1.0, "start: Solmere whole at golden hour, a slow push in"], [2.6, "beat: the Crown on its isle"],
		[3.4, "middle: cut low on the Crown"], [5.0, "beat: the push in on the Crown"],
		[-0.2, "end: the Crown in the evening sun"]],
	[[1.0, "start: the vault, the red-and-gold mask over the pedestal"], [2.8, "beat: the mask's eyes kindle"],
		[3.8, "middle: cut low on the Wyrmheart"], [5.2, "beat: the Heart beating, crimson glass"],
		[-0.2, "end: the Heart on its pedestal under the mask"]],
	[[1.0, "start: behind Kael and the Auburn Knights at the Crown's door"],
		[2.6, "beat: the Wyrm rises behind the Crown and roars"],
		[3.5, "middle: cut wide, the sky reddening as it dives"], [4.6, "beat: fire on the towns, the frame shaking"],
		[-0.2, "end: the Wyrm climbs away over the burning land"]],
	[[1.0, "start: Sable at the pedestal"], [1.9, "beat: the Heart in her hands"],
		[2.9, "middle: the quake, the Heart falling"], [3.9, "beat: cut low, the Heart on the floor, the flash"],
		[-0.2, "end: the Heart glowing on the vault floor"]],
	[[1.0, "start: the burning land, the Wyrm circling"], [1.8, "beat: the land splits (flash, jolt, rocks)"],
		[3.2, "middle: the souls burst out of the Crown"], [4.4, "beat: cut low, the isles drifting apart in dust"],
		[-0.2, "end: the isles sinking, rocks falling past"]],
	[[1.0, "start: behind the hunters gliding for the Heart"], [2.8, "beat: the Heart's crimson beam ahead"],
		[4.2, "middle: cut to the reveal over the isles"], [5.6, "beat: two eyes open far down in the clouds"],
		[-0.2, "end: the Wyrm watching the race"]],
]
const FRAME := Vector2i(1280, 720)      # px: the game's window (project.godot), the smallest it frames for
## px: the game's window, a big one, a small one
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(800, 450)]

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
	var chapters: Array = pr.shots.map(func(sh): return String(sh["chapter"]))
	ok(chapters == CHAPTERS, "six panels in order (%s)" % ", ".join(chapters))
	var run := 0.0
	for sh in pr.shots:
		run += float(sh["dur"])
	ok(run >= RUN_S.x and run <= RUN_S.y, "the panels run %.1f s (%.0f s with the fades and title card)"
		% [run, run + FADE_S * pr.shots.size() + 3.6])
	for i in mini(pr.shots.size(), NAMES.size()):
		var text := String(pr.shots[i]["text"])
		var missing: Array = NAMES[i].filter(func(w): return not text.contains(w))
		ok(missing.is_empty() and not text.contains("twelve") and not text.contains("Tyrant"), "%s names %s" % [CHAPTERS[i], ", ".join(NAMES[i])])
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

## Steps through the panels, taking the strip frames and watching THE UPRISING's framing and THE THIEF's beat.
func _play(pr, tree: SceneTree) -> void:
	var kael_in := 0
	var up_frames := 0
	for i in pr.shots.size():
		var dur := float(pr.shots[i]["dur"])
		for n in 5:
			var at := float(STRIP[i][n][0])
			if at < 0.0:
				at += dur
			while pr.shot < i or (pr.shot == i and pr.shot_t < at):
				await tree.process_frame
				if pr.shot == 2 and pr.shot_t > 0.05 and pr.shot_t < 2.3:      # once the cut lands, before the roar
					up_frames += 1
					kael_in += int(pr.knights.visible and _in_frame(pr, pr.knights.get_child(0)))
			await _shot(i, n, pr)
		if i == 1:
			var lit: float = (pr.vault.mask_eyes[0] as ShaderMaterial).get_shader_parameter("glow")
			ok(lit > 1.0, "THE MASK: the mask's eyes kindle (%.2f)" % lit)
		if i == 3:
			ok(pr.vault.cracked and pr.vault.heart.position.y < PrologueVault.PEDESTAL_TOP,
				"THE THIEF: the Heart falls from Sable's hands and hits the floor (%.2f m)" % pr.vault.heart.position.y)
	ok(up_frames > 30 and kael_in > up_frames * 0.9, "THE UPRISING: Kael stands in the picture before the roar"
		+ " (%d of %d frames)" % [kael_in, up_frames])
	ok(not pr.knights.visible, "Kael and the Auburn Knights leave with THE UPRISING")
	var red: Color = pr.heart_light.light_color
	ok(red.r > 0.9 and red.b < 0.5, "THE DESCENT: the Heart below glows crimson (%s)" % red.to_html(false))

## Whether `body` (a standing model) sits wholly inside the picture: the frame edges and the letterbox bars.
func _in_frame(pr, body: Node3D) -> bool:
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var top: float = pr.bar_top.offset_bottom
	var bot: float = vp.y + pr.bar_bot.offset_top
	var cam: Camera3D = pr.cam
	var at := body.global_position
	var side: Vector3 = cam.global_basis.x * 0.5 * body.scale.x
	for p in [at + Vector3(0, 2.0 * body.scale.y, 0), at + side, at - side]:
		var px := cam.unproject_position(p)
		if cam.is_position_behind(p) or px.x < 0.0 or px.x > vp.x or px.y < top or px.y > bot:
			return false
	return true

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

## Item 77: every panel's caption stays fully on screen (wrapped, growing upward) at the game's window, a big
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
