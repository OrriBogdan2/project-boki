extends "res://tools/mob_pose_shots.gd"
## --mob-fight-clip --shots-dir=<dir> [--kinds=a,b] [--group]: each monster in a real match chasing the still player,
## taking three hits and dying, as the game draws it (jobq --needs gpu). One frame dir per monster,
## <dir>/<kind>/NNNNN.jpg, or <dir>/group/ with --group (all at once).
## Run on the fixed step so the clip plays at 60 fps:
##   godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 60 --path . -- --mob-fight-clip --shots-dir=<dir>
## then ffmpeg -framerate 60 -i <dir>/<kind>/%05d.jpg <kind>.mp4. Old vs new: run it on both trees and hstack the clips.

const CLIP_W := 960               # px, the frame around the fight
const CLIP_H := 540
const START_M := 6.5              # m from the player a monster starts
const HIT_FRAMES := [100, 190, 280]    # the frames the hits land on, counted from the spawn
const KILL_FRAME := 420           # the frame the last blow lands on
const END_FRAMES := 520           # the clip ends here, after the death move and dissolve
const HIT_FRAC := 0.12            # of the monster's hp, each hit


func run(mn: Node) -> void:
	var kinds := await setup(mn)
	if "--group" in OS.get_cmdline_user_args():
		await _fight("group", kinds)
	else:
		for k in kinds:
			await _fight(String(k), [k])
	print("MOBFIGHTCLIP DONE")
	main.get_tree().quit()


func _fight(label: String, kinds: Array) -> void:
	var P: Hunter = m.player
	var dir := out_dir.path_join(label)
	DirAccess.make_dir_recursive_absolute(dir)
	_clear_stage([])
	var anchor := _open_ground(P.pos)
	P.teleport(anchor)
	m.opts["sim_keep"] = true     # a death or an exit in the world never ends the match under the clip
	await _frames(60)
	var mobs: Array[Mob] = []
	for i in kinds.size():
		var a := -PI / 3.0 + (i - (kinds.size() - 1) * 0.5) * 0.5
		var at := P.pos + Vector3(sin(a), 0, -cos(a)) * START_M
		var mb := m.spawn_mob(String(kinds[i]), Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
		mb.tgt = P
		mb.st = "chase"
		mobs.append(mb)
	for f in END_FRAMES:
		P.vel = Vector3.ZERO     # a blow never shoves the player off the island: the fight stays in frame
		P.pos = anchor
		var mid := P.pos
		for mb in mobs:
			mid += mb.pos
		mid /= float(mobs.size() + 1)
		m.cam.focus = m.cam.focus.lerp(mid, 0.1)
		_clear_stage(mobs)
		for mb in mobs:
			if is_instance_valid(mb) and not mb.dead and HIT_FRAMES.has(f):
				mb.hurt(float(mb.md["hp"]) * HIT_FRAC, P)
			if is_instance_valid(mb) and not mb.dead and f == KILL_FRAME:
				mb.hurt(float(mb.md["hp"]), P)
		await main.get_tree().process_frame
		if m.over:
			print("MOBFIGHTCLIP ended early at frame %d: %s" % [f, m.result])
			break
		await _shoot(dir, f, mid)
	for mb in mobs:
		if is_instance_valid(mb) and not mb.dead:
			mb.hp = 0.0
			mb.dead = true
			mb._cancel_tele()
			mb.visible = false
	print("MOBFIGHTCLIP %s %d frames" % [label, END_FRAMES])


## The CLIP_W x CLIP_H window round `mid` on the frame just drawn, as <dir>/NNNNN.jpg.
func _shoot(dir: String, n: int, mid: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	var c := Vector2i(m.cam.unproject_position(mid + Vector3(0, 0.8, 0)))
	var x := clampi(c.x - CLIP_W / 2, 0, img.get_width() - CLIP_W)
	var y := clampi(c.y - CLIP_H / 2, 0, img.get_height() - CLIP_H)
	img.get_region(Rect2i(x, y, CLIP_W, CLIP_H)).save_jpg(dir.path_join("%05d.jpg" % n), 0.9)


## The standing ground within 14 m of `from` with the most solid ground round it (ring of 12 m), so the fight has room.
func _open_ground(from: Vector3) -> Vector3:
	var best := from
	var best_score := -1
	for dx in range(-14, 15, 2):
		for dz in range(-14, 15, 2):
			var x := from.x + dx
			var z := from.z + dz
			if m.world.is_void(x, z) or m.world.is_block(x, z):
				continue
			var score := 0
			for i in 16:
				var a := TAU * i / 16.0
				for r: float in [4.0, 8.0, 12.0]:
					var qx := x + sin(a) * r
					var qz := z + cos(a) * r
					if not m.world.is_void(qx, qz) and not m.world.is_block(qx, qz):
						score += 1
			if score > best_score:
				best_score = score
				best = Vector3(x, 0, z)
	return Vector3(best.x, m.world.ground_at(best.x, best.z) + 0.2, best.z)


## Only this fight's monsters, the player and the ground are in the shot: every other monster is put down, the
## chests and drops are hidden, and the player stays on their feet.
func _clear_stage(keep: Array) -> void:
	for o in m.mobs:
		if is_instance_valid(o) and not keep.has(o) and not o.dead:
			o.hp = 0.0
			o.dead = true
			o._cancel_tele()
			o.visible = false
	for pk in m.pickups:
		if pk.get("node") != null:
			pk["node"].visible = false
	for c in m.chests:
		if c.get("node") != null:
			c["node"].visible = false
	m.player.hp = m.player.max_hp
