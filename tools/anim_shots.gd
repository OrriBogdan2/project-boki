extends "res://tools/clip_shots.gd"
## --anim-shots --shots-dir=<dir> [--wardens=a,b] [--frames=8] [--size=240]: every Hunter's walk, run, idle and two
## attacks at the match camera (--close: a side view at hip height, to read the arms and feet), for the
## animation audit (docs/art/ANIM_QUALITY_AUDIT.md) and its before/after strips.
## <dir>/<id>/<strip>/fNNN.png, strips walk, run (the game's own locomotion hand-off at WALK_MPS and RUN_MPS, seen
## from the side with a scrolling floor, so a sliding foot slides against it), idle and atk1, atk2 (the keyed clip,
## forced).
## Needs a renderer.

const WALK_MPS := 2.2      # m/s: an analog-stick walk
const RUN_MPS := 4.65      # m/s: full stick, content/rules/hunter_move.json
const LOCO_FPS := 10.0     # frames/s of the walk and run strips
const WARM_S := 1.0        # s of locomotion before the strip starts, so the blend has settled
const SIDE_YAW := -PI / 2.0     # facing screen right
const POST_SPACING := 0.5       # m between floor posts
const POST_COUNT := 14
const DT := 1.0 / 30.0
## The two attacks each strip shows: the primary shots and one more (clip names of content/rules/warden_anim).
const ATTACKS := {
	"archer": ["loose", "perfect"], "ashwick": ["lance", "shot"], "bulwark": ["lmb_throw", "lmb_slam"],
	"dolm": ["lmb_throw", "lmb_punch"], "dredge": ["shot", "throw"], "gunslinger": ["lmb", "rmb"],
	"juggernaut": ["slash_r", "slam"], "mage": ["lmb_l", "rmb"], "ostra": ["orb", "snap"],
	"rimewright": ["dart_r", "dart_heavy"], "tender": ["shot_r", "seed"], "thief": ["lmb_r", "vault_r"],
}

var posts: Array = []

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	var frames := 8
	var close := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--frames="): frames = int(a.substr(9))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
		if a == "--close": close = true
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 8.0
	cam.position = Vector3(0, 21.0, 9.4)
	if close:
		cam.fov = 14.0
		cam.position = Vector3(0, 1.0, 12.0)
	cam.look_at(Vector3(0, 0.8 if not close else 1.0, 0))
	_posts()
	for id in ids:
		await _hunter(String(id), out.path_join(String(id)), frames)
	print("ANIM_SHOTS_DONE ", ids.size())
	tree.quit()

func _posts() -> void:
	var mat := Models.toon(Color("1c2a14"), false)
	for i in POST_COUNT:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.02, 0.5)
		post.mesh = box
		post.material_override = mat
		post.position = Vector3((i - POST_COUNT / 2.0) * POST_SPACING, 0.01, 0.35)
		holder.add_child(post)
		posts.append(post)

func _scroll(mps: float, dt: float) -> void:
	var span := POST_COUNT * POST_SPACING
	for p in posts:
		p.position.x = fposmod((p as Node3D).position.x - mps * dt + span / 2.0, span) - span / 2.0

func _hunter(id: String, dir: String, frames: int) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 20:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	if clips == null:
		model.queue_free()
		return
	model.rotation.y = SIDE_YAW
	await _loco(model, sync, dir.path_join("walk"), WALK_MPS, frames)
	await _loco(model, sync, dir.path_join("run"), RUN_MPS, frames)
	var lc: Dictionary = clips.d["loco"]
	await _keyed(model, sync, clips, dir.path_join("idle"), String(lc["idle"]), frames)
	var atk: Array = ATTACKS[id]
	for i in 2:
		await _keyed(model, sync, clips, dir.path_join("atk%d" % (i + 1)), String(atk[i]), frames)
	model.queue_free()

## The game's own locomotion hand-off: the state carries the speed, WardenClips blends and scales the walk or run.
func _loco(model: Node3D, sync: Node, dir: String, mps: float, frames: int) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var fw := Vector3(-sin(SIDE_YAW), 0.0, -cos(SIDE_YAW))
	model.set_meta(WardenClips.STATE, {"vel": fw * mps, "face": SIDE_YAW, "grounded": true})
	for k in int(WARM_S / DT):
		sync.call("_process", DT)
		_scroll(mps, DT)
	var steps := int(round(1.0 / (LOCO_FPS * DT)))
	for i in frames:
		for k in steps:
			sync.call("_process", DT)
			_scroll(mps, DT)
		await _grab(dir.path_join("f%03d.png" % i))
	model.set_meta(WardenClips.STATE, {})

## A keyed clip, `frames` even steps from its start to just before its end (a loop's seam is the step after the last).
func _keyed(model: Node3D, sync: Node, clips: WardenClips, dir: String, clip: String, frames: int) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var length := clips.lib.get_animation(clip).length
	clips.force = {"clip": clip, "t": 0.0}
	for k in 8:
		sync.call("_process", DT)
	for i in frames:
		clips.force = {"clip": clip, "t": minf(length * i / frames, length - 0.001)}
		sync.call("_process", DT)
		await _grab(dir.path_join("f%03d.png" % i))
	clips.force = {}
