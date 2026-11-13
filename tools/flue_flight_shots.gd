extends "res://tools/glide_shots.gd"
## --flue-flight-shots --shots-dir=<dir> [--size=360]: Cinder's Flue Flight in a live training match, for the clip map
## (content/rules/warden_anim/cinder.json): the take-off hover, the steady flight, a hard turn left then right, the
## early landing and the settle. <dir>/{back,side}/f000.png... at 15 fps (the glide shots' match and camera), one
## FLUE_SHOT line a frame with the move, the bank and the body's tilt. Needs a renderer.

const FLY_AT := 0.6        # s: the cast (the title splash is gone)
const LEFT_AT := 1.2       # s: the aim swings left of the heading
const RIGHT_AT := 1.7      # s: and right of it
const LAND_AT := 2.2       # s: X again
const END_AT := 3.0        # s: the settle is long over
const SWING := 1.5         # rad: how far the aim sits off the heading in a turn
const REACH := 24.0        # m: the flight's ground she looks for (about 22.7 m flown), so the landing is on land

func run(main: Node) -> void:
	tree = main.get_tree()
	Save.no_write = true
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--size="): px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	await _flight(main, out)
	print("FLUE_FLIGHT_SHOTS_DONE")
	tree.quit()

func _flight(main: Node, dir: String) -> void:
	var m := await _start(main, "ashwick", dir)
	var h: Hunter = m.player
	h.lvl = 6
	var sync := _sync(h)
	var k := h.ak as AshwickKit
	var heading := _over_ground(m, h.pos)
	var step := 0
	while step * Match.DT < END_AT:
		var t := step * Match.DT
		var turn := 0.0
		if t >= LEFT_AT and t < RIGHT_AT: turn = -SWING
		elif t >= RIGHT_AT and t < LAND_AT: turn = SWING
		h.inp["aim"] = h.pos + heading.rotated(Vector3.UP, turn) * 8.0 + Vector3(0, 0.9, 0)
		if step == roundi(FLY_AT / Match.DT):
			k.cd["x"] = 0.0
			HunterKeys.ult_pressed(h)
		if step == roundi(LAND_AT / Match.DT):
			HunterKeys.ult_pressed(h)
		m.step(Match.DT)
		h.render(Match.DT, 1.0)
		h.model.basis = Basis(Vector3.UP, h.face).scaled_local(h.model.scale)
		if sync:
			sync._process(Match.DT)
		if step % EVERY == 0:
			var i := step / EVERY
			print("FLUE_SHOT f%03d %-8s bank=%5.1f %s" % [i, k.anim_id, rad_to_deg(h.anim.glide_bank), _body(h)])
			_aim(h, 180.0, 0.25)
			await _grab(dir.path_join("back/f%03d.png" % i))
			_aim(h, 90.0, 0.35)     # (above the grass)
			await _grab(dir.path_join("side/f%03d.png" % i))
		step += 1
	m.queue_free()
	await tree.process_frame

## Of 16 headings, the one with the most ground under the next REACH metres (no abyss under the flight).
func _over_ground(m: Match, from: Vector3) -> Vector3:
	var best := Vector3.RIGHT
	var most := -1
	for i in 16:
		var d := Vector3.RIGHT.rotated(Vector3.UP, TAU * i / 16.0)
		var n := 0
		for r in int(REACH):
			var p := from + d * float(r + 1)
			if m.world.ground_at(p.x, p.z) > World.VOID + 1.0:
				n += 1
		if n > most:
			most = n
			best = d
	return best
