extends RefCounted
## --stomp-film --shots-dir=<dir>: the stomp at the match camera (docs/decisions/0061-stomp-lock.md), in a
## live extraction match under a renderer (jobq --needs gpu). Two takes, each saved as 30 fps frames in
## <dir>/<take>/NNNNN.jpg:
##   full      you stomp a rival's wisp while another rival hits you: you stay locked in, take the hits,
##             and the wisp dies at the end
##   stunned   the same, but the rival stuns you halfway: the stomp breaks and the wisp drifts off alive
## Make the clips off the box: ffmpeg -framerate 30 -i <dir>/<take>/%05d.jpg -c:v libx264 -pix_fmt yuv420p <take>.mp4
## Never writes the save.

const DT := 1.0 / 60.0
const STUN_AT := 1.5          # s into the stunned take's stomp the stun lands
const STUN_FOR := 1.0         # s of stun
const SHOT_EVERY := 0.3       # s between the rival's plain hits (its own gun may stun, ending the take early)
const SHOT_DMG := 6.0

var main: Node
var m: Match
var P: Hunter
var dir := ""
var take_dir := ""
var steps := 0
var frames := 0

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	await _setup()
	await _take("full", false)
	await _take("stunned", true)
	print("STOMPFILM done in %s" % dir)
	main.get_tree().quit(0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.lives = 1
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)

## Flat open ground.
func _roomy() -> Vector3:
	for k in 3000:
		var g := m.world.random_ground()
		var flat := true
		for dx in range(-6, 7, 2):
			for dz in range(-6, 7, 2):
				if m.world.is_void(g.x + dx, g.z + dz) or absf(m.world.ground_at(g.x + dx, g.z + dz) - g.y) > 0.3:
					flat = false
		if flat:
			return g
	return m.world.random_ground()

## One take: P stomps a rival's wisp while the other rival shoots P (and stuns P if `stun`).
func _take(take: String, stun: bool) -> void:
	take_dir = dir.path_join(take)
	DirAccess.make_dir_recursive_absolute(take_dir)
	frames = 0
	var rivals: Array = m.hunters.filter(func(x): return x.team != P.team and not x.out)
	var W: Hunter = rivals[0]
	var E: Hunter = rivals[1]
	for kk in [W.kin, W.kin2, E.kin, E.kin2]:      # no Boki: E's could stun you and spoil the full take
		if kk:
			(kk as Kin).dead = true
			(kk as Kin).visible = false
	var at := _roomy()
	for h in m.hunters:
		if h != P and h != W and h != E and not h.out:
			h.teleport(m.world.free_spot_near(at + Vector3(40, 0, 0), [], 1.0, 0.4, 20.0))
	P.max_hp *= 3.0      # the hits must not knock P down mid-take
	P.hp = P.max_hp
	W.teleport(at)
	P.teleport(at + Vector3(1.2, 0, 0.6))
	E.teleport(at + Vector3(-5.0, 0, 3.0))
	m.knock(W, E, {})
	await _go(0.8)
	P.teleport(W.pos + Vector3(0.6, 0, 0.3))
	P.inp["interact"] = true
	while P.stomp.is_empty():
		await _go(DT)
	P.inp["interact"] = false
	print("STOMPFILM_MARK %s stomp_start frame %d" % [take, frames])
	var t0 := m.time
	var stunned := false
	var shot_t := 0.0
	while not P.stomp.is_empty():
		E.inp["aim"] = P.pos + Vector3(0, 0.9, 0)
		shot_t -= DT
		if shot_t <= 0.0:
			shot_t = SHOT_EVERY
			m.fx.bolt(E.pos + Vector3(0, 1.1, 0), P.pos + Vector3(0, 1.0, 0), Color("ff6a5a"))
			P.hurt(SHOT_DMG, E, {})
		P.inp["move"] = Vector2(1, 0)      # trying to walk off: nothing happens
		if stun and not stunned and m.time - t0 >= STUN_AT:
			stunned = true
			P.hurt(8.0, E, {"stun": STUN_FOR})
			m.fx.word(P.pos + Vector3(0, 2.6, 0), "STUNNED", Color("ffe85a"), true)
			print("STOMPFILM_MARK %s stun frame %d" % [take, frames])
		await _go(DT)
	P.inp["move"] = Vector2.ZERO
	print("STOMPFILM_MARK %s end frame %d wisp_out=%s" % [take, frames, W.out])
	if not W.out:
		W.inp["move"] = Vector2(-1, 0.3)       # the wisp drifts away alive
	await _go(STUN_FOR + 1.0 if stun else 1.5)
	W.inp["move"] = Vector2.ZERO
	P.max_hp /= 3.0

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
		steps += 1
		if steps % 2 == 0:
			main.get_viewport().get_texture().get_image().save_jpg(take_dir.path_join("%05d.jpg" % frames), 0.9)
			frames += 1
