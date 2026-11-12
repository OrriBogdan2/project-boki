extends RefCounted
## --train-halts-shots --shots-dir=<dir>: review shots of the sky train's halts on the Hollow Crown,
## in a live match under a renderer (jobq submit --needs gpu):
##   halts_drop       the opening drop's bird's-eye view: the posts' lamps and light columns over a halt
##   halt_ground_40m  standing 40 m from a halt, train waiting: the post and the pier glow
##   halt_waiting     on the pier with the train stopped: the post, the glow along the pier's edge
##   halt_waiting_stop4/7  two other halts, over darker ground
##   halt_low         the same on the Low preset (the post stays, the glow is gone)
##   approach_far     the train coming in (headlight halo, beam, trail) seen from the pier
##   approach_near    a moment later, nearly at the halt
## <dir>/captions.txt gets "file: caption" per file.

const DT := 1.0 / 60.0

var main: Node
var m: Match
var P: Hunter
var st: SkyTrain
var dir := ""
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var leg := 1
	_set_time(_stop_time(leg) + 3.0)
	m.step(DT)
	var halt: int = st.halts.halt
	var post := Vector3.ZERO
	for b in st.halts.beacons:
		if int(b["halt"]) == halt:
			post = b["pos"]
			break
	var track := st.world.train_at(float(st.world.train_route["stations"][halt]))
	var away := Vector3(post.x - track.x, 0.0, post.z - track.z).normalized()
	P.teleport(post + away * 2.0)
	await _go(0.8)
	_take("halt_waiting", "On the pier, train stopped: the blue post and its lamp, the soft glow on the pier's edge")
	P.teleport(post + away * 40.0)
	await _go(0.6)
	_take("halt_ground_40m", "40 m from the halt on the ground, train waiting: the post and its lamp still read")
	_view(1.0, 3.0)
	P.teleport(post + away * 2.0)
	await _go(0.4)
	_take("halts_drop", "The drop's bird's-eye view over a halt: lamp and light column on the post, the pier glow")
	_view(0.0, 1.0)
	for other in [4, 7]:
		_set_time(_stop_time(other) + 3.0)
		m.step(DT)
		for b in st.halts.beacons:
			if int(b["halt"]) == st.halts.halt:
				P.teleport(b["pos"] + away * 2.0)
				break
		await _go(0.8)
		_take("halt_waiting_stop%d" % other, "Another halt (stop %d): the glow on the pier edge" % other)
	for g in st.halts.glow_nodes:
		g.visible = false
	st.halts.glow_nodes.clear()
	await _go(0.4)
	_take("halt_low", "Low preset: the post stays, the pier glow is dropped")
	_set_time(_stop_time(leg) - 2.6)
	P.teleport(post + away * 3.0)
	await _go(0.1)
	_take("approach_far", "The train coming in: headlight halo and beam ahead, a short trail behind the last car")
	await _go(1.2)
	_take("approach_near", "A moment later, nearly at the halt")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("TRAINHALTSSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	st = m.skytrain
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.lives = 1
		if h != P:
			h.teleport(m.world.random_ground())
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)

## Match time the train stands at the start of stop `i`'s dwell.
func _stop_time(i: int) -> float:
	var t := 0.0
	for j in i:
		t += st.dwell + float(st.legs[j]["t"])
	return t

func _set_time(t: float) -> void:
	m.time = t
	st.tick(0.0)
	st.old = st.cur.duplicate()

## top: 1 looks straight down (the drop), 0 is the usual angle; zoom: how far back.
func _view(top: float, zoom: float) -> void:
	m.cam.top = top
	m.cam.top_to = top
	m.cam.zoom = zoom
	m.cam.zoom_to = zoom

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
