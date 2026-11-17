extends RefCounted
## --levelup-reel: a level-up in a fight at the match camera, for the owner's video. Lisette trades shots
## with a rival on open ground who shoots back; her XP sits just under the next level so the fight's own hits level her
## up (2 -> 3 once, then 5 -> 6 with the ultimate opening). Run it under the movie writer (one frame per step):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path . --fixed-fps 60 \
##       --write-movie <dir>/levelup.avi -- --levelup-reel
## Prints LEVELUP_REEL_MARK lines with the frame each level-up lands on. Never writes the save.

const DT := 1.0 / 60.0
const FIGHT_S := 4.5           # s of fighting around each level-up
const XP_SHORT := 25.0         # XP left to the next level when a fight starts (a few hits)

var main: Node
var m: Match
var P: Hunter
var R: Hunter
var frame := 0

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true,
			"arch": "archer", "cls": Arch.weight("archer"), "weapon": Arch.signature("archer")})
	m.set_process(false)
	P = m.player
	R = m.hunters.filter(func(x): return x != P)[0]
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var at := m.world.random_ground()
	for k in 2000:
		at = m.world.random_ground()
		if not m.world.is_void(at.x + 7.0, at.z) and absf(m.world.ground_at(at.x + 7.0, at.z) - at.y) < 0.3:
			break
	P.teleport(at)
	R.teleport(m.world.free_spot_near(at + Vector3(7, 0, 0), [], 1.0, 0.45, 2.0))
	await _fight(2)
	await _fight(5)
	print("LEVELUP_REEL done, %d frames" % frame)
	main.get_tree().quit(0)

## Fight until `from` turns into `from + 1` on a hit, then a little after.
func _fight(from: int) -> void:
	P.lvl = from
	P.xp = float(Hunter.XP_TO[from]) - XP_SHORT
	P.hp = P.max_hp
	R.hp = R.max_hp
	R.ctrl = "idle"
	var marked := false
	var t := 0.0
	while t < FIGHT_S:
		P.inp["aim"] = R.pos
		P.inp["fire"] = fmod(t, 0.9) < 0.6
		P.inp["move"] = Vector2(0, 1 if fmod(t, 2.0) < 1.0 else -1) * 0.5
		R.inp["aim"] = P.pos
		R.inp["fire"] = fmod(t + 0.4, 1.1) < 0.5
		m.step(DT)
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		R.hp = maxf(R.hp, R.max_hp * 0.3)      # (keep the fight going)
		P.hp = maxf(P.hp, P.max_hp * 0.4)
		if not marked and P.lvl > from:
			marked = true
			print("LEVELUP_REEL_MARK %d -> %d at frame %d" % [from, P.lvl, frame])
		t += DT
		frame += 1
		await main.get_tree().process_frame
