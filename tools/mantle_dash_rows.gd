extends RefCounted
## --mantle-check rows: a dash meets a rim. Each starter (Lace, Kael, Vex, Albert) dashes, from the ground and
## in the air, head-on into a rim 0.6, 1.0, 1.5 and 2.0 m above its feet, keys held into it. A row reads what
## happened at the face (mantle, step, stop, slide or bounce), the speed over the lip, and the time lost against
## the same dash on flat ground covering the same distance.
## Ledges are always responsive (DECISIONS): every rim in the hunter's reach (MANTLE_REACH 1.5 m, 2.4 m for a
## tall climber) is mantled, and the dash hands over as the source's mini-mantle does (MantleCarry): the rest of
## the dash is dropped, at least KEEP of its speed comes over the lip, and no more time is lost than the rise.
## A rim out of reach is never climbed (what the wall does to the dash then is the table's, not asserted).
## The rows carve their own patch: terraces are 0.8 m, so a ground row's floor between them is a stair tile
## the dash runs along (its slope runs across the dash, so the feet keep one height).

const HEROES := ["archer", "juggernaut", "gunslinger", "bulwark"]
const HEIGHTS := [0.6, 1.0, 1.5, 2.0]
const RUN_UP := 1.5          # m from the dasher's centre to the face at the press
const GOAL := 1.5            # m past the face, on top: the row's finish line
const MAX_T := 2.0           # s: a row that hasn't finished by then never does
const LOST_SLACK := 0.12     # s a dash may lose past the rise itself: the slower run on from the lip (KEEP), a step
const BASE := 2              # terrace the patch's floor stands on
const DT := Match.DT

var bad := 0
var rows: Array = []
var m: Match
var w: World
var h: Hunter
var cx := 0
var cz := 0

func ok(cond: bool, msg: String) -> void:
	print("MCHECK %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		bad += 1

## Runs every row; returns the failures.
func run(main: Node) -> int:
	for hero in HEROES:
		for air in [false, true]:
			for ht in HEIGHTS:
				_match(main, hero)      # (each row its own match: a Spirit Walk's leftovers slow the next run)
				var flat := _dash(0.0, air)
				var row := _dash(ht, air)
				row["hero"] = String(Arch.def(hero).get("base_name", hero))
				row["air"] = air
				row["flat"] = flat["t"]
				row["lost"] = -1.0
				if float(row["t"]) < MAX_T and float(flat["t"]) < MAX_T:
					row["lost"] = float(row["t"]) - float(flat["t"])
				row["reach"] = Hunter.MANTLE_REACH
				if HunterMove.climbs_tall(h):
					row["reach"] = Hunter.MANTLE_REACH + Hunter.TALL_CLIMB_EXTRA
				rows.append(row)
				main.remove_child(m)
				m.queue_free()
	_report()
	return bad

func _match(main: Node, hero: String) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight(hero), "arch": hero, "weapon": Arch.signature(hero)})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	h = m.player
	h.ctrl = "local"
	h.unlock_all()
	for o in m.hunters:
		if o != h:
			o.ctrl = "idle"
			o.teleport(h.pos + Vector3(60, 0, 60))
	for kk in [h.kin, h.kin2]:
		if kk:
			m.kins.erase(kk)
			kk.queue_free()
	h.kin = null
	h.kin2 = null
	w = m.world
	cx = int(floor(h.pos.x))
	cz = int(floor(h.pos.z))

## The patch: flat ground at BASE, a rim 5 tiles deep from z = cz + 1 at `rim_lv`, and the run-up column x = cx
## a stair rising across x (or level ground when `rise` is false).
func _carve(rim_lv: int, rise: bool) -> void:
	var isl: int = w.island[w.idx(cx, cz)]
	for dz in range(-10, 7):
		for dx in range(-5, 6):
			var i := w.idx(cx + dx, cz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = rim_lv if dz >= 1 else BASE
			w.island[i] = isl
			w.walls.erase(i)
			w.props.erase(i)
			w.stairs.erase(i)
			if dx == 0 and dz < 1 and rise:
				w.stairs[i] = Vector2i(1, 0)

## Where a ground row's floor can be for a rim `ht` above it: [rim level over BASE, stair fraction]. A stair
## reads one step higher across the body (its slope times the radius), which walls the body in, unless the
## body's high side already hangs over the level column beside it; heights a stair can't make run the nearest one.
func _floor_for(ht: float) -> Array:
	var lo := 1.0 - h.r + 0.02
	var best := []
	var bd := 1e9
	for k in [1, 2, 3]:
		var fx: float = k - ht / World.LEVEL
		if fx >= lo and fx < 1.0:
			return [k, fx]
		for f in [0.0, lo]:
			var d := absf((k - float(f)) * World.LEVEL - ht)
			if d < bd:
				bd = d
				best = [k, f]
	return best

## A fresh start for the next run: the last run's Spirit Walk out (its end would take her back to its start), a
## new kit with no cooldowns, standing (or hanging still in the air) at `at`.
func _reset(at: Vector3, air: bool) -> void:
	for i in 300:
		if h.spirit_t <= 0.0 and h.roll_t <= 0.0:
			break
		h.inp["move"] = Vector2.ZERO
		m.step(DT)
	h.set_arch(h.arch)
	h.ak.cd_off = true
	h.teleport(at)
	h.vel = Vector3.ZERO
	h.grounded = not air
	h.air_t = 0.4 if air else 0.0
	h.last_gy = BASE * World.LEVEL if air else at.y
	h.lfloat = {}
	h.pad = {}
	h.grap = {}
	h.grap_cd = 0.0
	h.mantle_cd = 0.0
	h.roll_t = 0.0
	h.spirit_t = 0.0
	h.dashes = 2.0
	h.gliding = false
	h.kb_t = -9.0
	h.stun_t = 0.0
	h.knock_t = 0.0
	for k in ["glide", "jump", "dash", "fire"]:
		h.inp[k] = false

## One dash at a rim `ht` above the feet (0: no rim, the flat reference): {t, how, ht, v_in, v_lip, kept}.
func _dash(ht: float, air: bool) -> Dictionary:
	var rim_lv := BASE
	var fx := 0.5
	if ht > 0.0:
		rim_lv = BASE + int(ceil(ht / World.LEVEL - 0.001))
	if ht > 0.0 and not air:
		var fl := _floor_for(ht)
		rim_lv = BASE + int(fl[0])
		fx = float(fl[1])
	var lip := rim_lv * World.LEVEL
	_carve(rim_lv, not air and fx > 0.0 and ht > 0.0)
	var x := cx + fx
	var y := w.ground_at(x, cz)
	if air:
		y = lip - ht if ht > 0.0 else BASE * World.LEVEL + 1.2
	_reset(Vector3(x, y, cz + 1.0 - RUN_UP), air)
	var face := cz + 1.0
	var top := lip if ht > 0.0 else -1e9
	var out := {"t": MAX_T, "how": "stop", "ht": 0.0, "v_in": 0.0, "v_lip": 0.0, "kept": false}
	if ht > 0.0:
		out["ht"] = snappedf(lip - y, 0.01)
	var t := 0.0
	var floated := false
	var z_touch := INF
	var back := 0.0
	var side := 0.0
	while t < MAX_T:
		h.inp["move"] = Vector2(0, 1)
		h.inp["dash"] = t == 0.0
		m.step(DT)
		t += DT
		if h.mantling() and not floated:
			floated = true
			out["v_in"] = float(h.lfloat.get("v_in", 0.0))
		if ht > 0.0 and z_touch == INF and h.pos.z >= face - h.r - 0.05 and h.pos.y < lip - 0.05:
			z_touch = h.pos.z
		if z_touch != INF:
			back = maxf(back, z_touch - h.pos.z)
			side = maxf(side, absf(h.pos.x - x))
		if float(out["v_lip"]) == 0.0 and h.pos.z >= face + 0.3 and h.pos.y >= top - 0.1:
			out["v_lip"] = Vector2(h.vel.x, h.vel.z).length()
			out["kept"] = h.roll_t > 0.0
		if h.pos.z >= face + GOAL and h.pos.y >= top - 0.1:
			out["t"] = t
			break
	if ht <= 0.0:
		out["how"] = "flat"
	elif float(out["t"]) < MAX_T and floated:
		out["how"] = "mantle"
	elif float(out["t"]) < MAX_T:
		out["how"] = "climb" if h.spirit_t > 0.0 else "step"
	elif back > 0.15:
		out["how"] = "bounce"
	elif side > 0.3:
		out["how"] = "slide"
	return out

func _report() -> void:
	print("MCHECK dash into a rim: hero | from | rim m | what | time lost s (flat run s) | speed in -> over the lip m/s"
		+ " | dash still on")
	var miss := []
	var slow := []
	var shed := []
	var wrong := []
	for r in rows:
		var from := "air" if r["air"] else "ground"
		var what := "%s %s %.2fm" % [r["hero"], from, r["ht"]]
		var lost := "%.2f" % r["lost"] if r["lost"] >= 0.0 else "never"
		var kept := "yes" if r["kept"] else "no"
		print("MCHECK   %s | %s | %.2f | %s | %s (%.2f) | %.1f -> %.1f | %s"
			% [r["hero"], from, r["ht"], r["how"], lost, r["flat"], r["v_in"], r["v_lip"], kept])
		# the rise a dash starts: thrown up to clear the lip at the suction cap ([footage] rim to top ~0.2 s)
		var rise := (MantleCarry.dash_lift(float(r["ht"])) - HunterMove.mantle_vy_cap) / Hunter.H_GRAV
		if float(r["ht"]) > float(r["reach"]) + 0.01:
			if r["lost"] >= 0.0:
				wrong.append(what)
		elif r["lost"] < 0.0:
			miss.append(what)
		elif r["lost"] > rise + LOST_SLACK:
			slow.append("%s %.2fs > %.2fs" % [what, r["lost"], rise + LOST_SLACK])
		if r["how"] == "mantle" and float(r["v_lip"]) < MantleCarry.KEEP * float(r["v_in"]) - 0.2:
			shed.append(what)
	ok(miss.is_empty(), "a dash into a rim in reach gets on top, every starter, ground and air (missed: %s)"
		% str(miss))
	ok(slow.is_empty(), "...losing no more than its rise and %.2fs against the same dash on flat ground (slower: %s)"
		% [LOST_SLACK, str(slow)])
	ok(shed.is_empty(), "...and at least %.1fx the dash's speed comes over the lip (MiniMantle; short: %s)"
		% [MantleCarry.KEEP, str(shed)])
	ok(wrong.is_empty(), "a rim out of reach (MANTLE_REACH, more for a tall climber) is never climbed (climbed: %s)"
		% str(wrong))
