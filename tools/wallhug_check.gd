extends RefCounted
## --wallhug-check: hugging an island's side from the abyss. In SUPERVIVE you rarely sink under an
## island while you're pressed against its wall, as long as there's ground to stand on up there.
## For many grabbable (non-sheer) rims it starts the player just outside the wall over the void, at
## a range of heights around the lip, falling, and holding a key into the wall (straight in, 45 and
## 65 degrees along it), with and without the glider held. Each try ends "caught" (climbed onto the
## top) or "fell" (sank more than a few metres under the lip, or lost to the abyss).
## Counts fixed simulation steps; never touches the save. Prints "WALLHUG caught X of N" and
## "WALLHUG CHECK DONE, failures: N". A failure is a catch rate under TARGET with the keys pushing into
## the wall (straight in or 45 degrees), or under TARGET_GLANCE steering 65 degrees off (mostly along
## it): the ledge rise follows your keys, so steering mostly along a short rim can carry you off its
## end before you're up.

const TARGET := 0.95
const TARGET_GLANCE := 0.7
const DT := 1.0 / 60.0
var bad := 0
var m: Match
var w: World
var P: Hunter

func _edges(n: int) -> Array:
	var out: Array = []
	var seen := {}
	for k in 8000:
		if out.size() >= n: break
		var g := w.random_ground()
		var gi := w.idx(int(floor(g.x)), int(floor(g.z)))
		if seen.has(gi) or w.is_void(g.x, g.z) or w.sheer.has(gi): continue
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var open := true
			for dd in [1.2, 1.8, 2.6, 3.4]:
				for s in [-0.7, 0.0, 0.7]:
					if not w.is_void(g.x + d.x * dd + d.y * s, g.z + d.y * dd + d.x * s): open = false
			if not open: continue
			var ex := g.x; var ez := g.z
			while not w.is_void(ex + d.x * 0.25, ez + d.y * 0.25):
				ex += d.x * 0.25; ez += d.y * 0.25
			var ti := w.idx(int(floor(ex)), int(floor(ez)))
			if w.sheer.has(ti) or w.is_block(ex - d.x * 0.6, ez - d.y * 0.6): continue
			seen[gi] = true
			out.append({"top": w.ground_at(ex - d.x * 0.3, ez - d.y * 0.3), "dir": d, "ex": ex, "ez": ez})
			break
	return out

func _reset(at: Vector3, v: Vector3, top: float) -> void:
	P.out = false; P.gone = false; P.downed = false; P.down_hp = 100.0
	P.teleport(at)
	P.grounded = false; P.vel = v; P.pad = {}; P.grap = {}; P.grap_cd = 0.0; P.roll_t = 0.0
	P.gliding = false; P.glide_fuel = 1.0; P.glide_cd = 0.0; P.knock_t = 0.0; P.fly_t = 0.0
	P.stun_t = 0.0; P.kb_t = -9.0; P.mantle_cd = 0.0; P.shot_down = false; P.air_t = 0.3
	P.dropping = false; P.diving = false; P.last_gy = top
	if "lfloat" in P: P.set("lfloat", {})
	for k in ["glide", "glide_btn", "jump", "dash", "fire"]: P.inp[k] = false
	P.inp["move"] = Vector2.ZERO
	P.hp = P.max_hp

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": true})
	m.set_process(false)
	w = m.world
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		if h != P: h.teleport(Vector3(-500, 50, -500)); h.out = true
	P.ctrl = "local"
	var edges := _edges(40)
	print("WALLHUG %d rims" % edges.size())
	var tot := 0; var caught := 0
	var by := {}
	for e in edges:
		var d: Vector2 = e["dir"]
		var side := Vector2(-d.y, d.x)
		var top: float = e["top"]
		# against the wall at a moderate fall, or a step out from it falling at full speed
		for gap in [0.08, 0.6]:
			for dy in ([0.8, -0.3, -1.0, -2.0, -3.0, -4.0] if gap < 0.3 else [0.8, -1.0, -2.0, -3.0]):
				for ang in [0.0, 45.0, 65.0]:
					for glide in [false, true]:
						var into := (-d).rotated(deg_to_rad(ang))
						var at := Vector3(float(e["ex"]) + d.x * (P.r + gap), top + dy, float(e["ez"]) + d.y * (P.r + gap))
						var vy := (-4.0 if dy > 0.0 else -6.0) if gap < 0.3 else -HunterMove.fall_max
						_reset(at, Vector3(side.x * 1.5 * signf(into.dot(side) + 0.001), vy, side.y * 1.5 * signf(into.dot(side) + 0.001)), top)
						var res := "fell"
						for i in 150:
							P.inp["move"] = into
							P.inp["glide"] = glide
							m.step(DT)
							# (a ledge rise counts once it has put you on top: see the next line)
							pass
							if P.grounded and P.pos.y > top - 0.2:
								res = "caught"; break
							if P.out or P.pos.y < top - Hunter.MANTLE_REACH_ABYSS - 1.5:
								break
							if glide and P.gliding and i > 90 and P.pos.y > top - 1.0:
								res = "held"; break     # the glider holds you at the lip: not under the island
						if res == "fell" and OS.has_environment("WALLHUG_DEBUG"):
							print("WALLHUG   fell: rim (%.1f,%.1f) d%s top %.1f dy %.1f a%d glide %s -> end %s moved %.2f void %s below_lip %s" % [float(e["ex"]), float(e["ez"]), str(d), top, dy, int(ang), glide, str(P.pos.snapped(Vector3(0.01, 0.01, 0.01))), Vector2(P.pos.x - at.x, P.pos.z - at.z).length(), P.over_void(), P.below_lip])
						tot += 1
						var key := "gap%.1f dy%.1f a%d %s" % [gap, dy, int(ang), "glide" if glide else "fall"]
						if not by.has(key): by[key] = [0, 0]
						by[key][1] += 1
						if res != "fell":
							caught += 1
							by[key][0] += 1
	for k in by.keys():
		if by[k][0] < by[k][1]:
			print("WALLHUG   %-22s caught %d of %d" % [k, by[k][0], by[k][1]])
	var rate := float(caught) / maxf(1.0, float(tot))
	print("WALLHUG caught %d of %d (%.1f%%)" % [caught, tot, rate * 100.0])
	var into := [0, 0]; var glance := [0, 0]
	for k in by.keys():
		var g: Array = glance if String(k).contains(" a65 ") else into
		g[0] += by[k][0]; g[1] += by[k][1]
	var ri := float(into[0]) / maxf(1.0, float(into[1])); var rg := float(glance[0]) / maxf(1.0, float(glance[1]))
	print("WALLHUG pushing in (0/45 degrees): %d of %d (%.1f%%), target %.0f%%" % [into[0], into[1], ri * 100.0, TARGET * 100.0])
	print("WALLHUG steering mostly along (65 degrees): %d of %d (%.1f%%), target %.0f%%" % [glance[0], glance[1], rg * 100.0, TARGET_GLANCE * 100.0])
	if ri < TARGET: bad += 1
	if rg < TARGET_GLANCE: bad += 1
	print("WALLHUG CHECK DONE, failures: ", bad)
	main.get_tree().quit()
