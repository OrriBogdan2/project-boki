class_name GlintFishing
extends RefCounted
## Glint Fishing (briefs/design/GARDEN_MODERN.md 4.2 game 4), solo with your partner on a rock in a zone
## with a spot (Glasswater Shallows). Five casts. Hold interact and the cast swings out over the water
## and back; let go on a glint. Wait: your Boki's ears go up before the bite (Focus gives 0.3 to 0.8 s
## of warning); press then to hook it, too early spooks it, too late and it got away. Then hold and let
## go to keep the line's tension inside the band while the glint pulls (Power widens the band) until it
## is landed. A sign by the rock lists what is biting today (the day number picks it); a Water lean
## doubles rare glints. Catches are banked like garden prizes: this is the item tap for home players.
## Tuning: content/rules/glint_fishing.json.
##
## One explicit state machine (briefs/STATE_MACHINES.md), Run.state: only Run.go() writes it, and a
## move the TABLE lacks is refused and counted (--glint-fishing-check asserts none).
##   AIM  -> WAIT   the cast landed on a glint
##        -> SHOW   it plopped into empty water
##   WAIT -> REEL   hooked: pressed with the ears up, before late_s after the bite
##        -> SHOW   spooked (pressed before the ears) or got away (no press in time)
##   REEL -> SHOW   landed, or the line slipped
##   SHOW -> AIM    the next cast
##        -> DONE   five casts (or time ran out)
## Run has no nodes and reads the button as a bool each step, so the check plays whole sessions headless.

const REACH := 1.8                # m from the rock to start fishing
const ROCK_R := 0.7               # m, the rock's radius
const GLINT_R := 0.08             # m, a glint's radius
const LINE_W := 0.015             # m, the line's thickness
const ROD_UP := 0.6               # m above the ground the line leaves your Boki

static func rules() -> Dictionary:
	return Content.rules("glint_fishing")

## Seconds of warning before the bite: warn_s from Focus 0 to Focus 100.
static func warn_s(rec: Dictionary) -> float:
	var w: Array = rules()["warn_s"]
	return lerpf(float(w[0]), float(w[1]), _stat(rec, "focus"))

## Half the width of the good tension band: band from Power 0 to Power 100.
static func band(rec: Dictionary) -> float:
	var b: Array = rules()["band"]
	return lerpf(float(b[0]), float(b[1]), _stat(rec, "power"))

static func _stat(rec: Dictionary, s: String) -> float:
	return clampf(float(rec["stats"].get(s, 0)) / 100.0, 0.0, 1.0)

## Chance one glint is rare: doubled for a Boki whose leading lean is Water.
static func rare_chance(rec: Dictionary) -> float:
	var R := rules()
	return float(R["rare"]) * (float(R["water_rare"]) if Evo.lean(rec)[0] == "water" else 1.0)

## A list entry can bite only once what it pays exists (an item id in the catalog, a food in Data.CROPS).
static func can_bite(e: Dictionary) -> bool:
	if String(e["kind"]) == "snack":
		return Data.CROPS.has(String(e["id"]))
	return GardenItems.has(String(e["id"]))

static func rares() -> Array:
	return rules()["rare_list"].filter(can_bite)

static func day_of(now: float) -> int:
	return int(now / float(rules()["day_s"]))

## What the sign says is biting on a garden day: sign_n common entries, picked by the day number.
static func biting(day: int) -> Array:
	var pool: Array = rules()["common"].filter(can_bite)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["glint", day])
	var out: Array = []
	while out.size() < int(rules()["sign_n"]) and not pool.is_empty():
		var e := pick(pool, rng)
		out.append(e)
		pool.erase(e)
	return out

## One weighted pick ({} from an empty list).
static func pick(list: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for e in list:
		total += int(e["w"])
	if total <= 0:
		return {}
	var at := rng.randi_range(1, total)
	for e in list:
		at -= int(e["w"])
		if at <= 0:
			return e
	return list[0]

static func sign_text(day: int) -> String:
	var lines: Array = ["Biting today"]
	for e in biting(day):
		lines.append(GardenPrizes.entry_name(e))
	var rare: Array = rares().map(GardenPrizes.entry_name)
	if not rare.is_empty():
		lines.append("Rarely: " + ", ".join(rare))
	return "\n".join(lines)

class Run:
	enum S { AIM, WAIT, REEL, SHOW, DONE }
	const TABLE := {S.AIM: [S.WAIT, S.SHOW], S.WAIT: [S.REEL, S.SHOW], S.REEL: [S.SHOW],
			S.SHOW: [S.AIM, S.DONE], S.DONE: []}
	const JOLT_K := 0.4             # a jolt moves the tension by pull times this at once

	var R: Dictionary
	var rec: Dictionary             # your Boki
	var rng: RandomNumberGenerator
	var sign_list: Array            # today's common catches
	var state := S.AIM
	var state_t := 0.0              # s in this state
	var refused := 0                # moves the TABLE turned down
	var t := 0.0
	var held := false               # the button last step
	var glints: Array = []          # this cast's: {d (m out), side (m off the line), rare, catch}
	var swing := 0.0                # s the button has been held this aim
	var hooked := -1                # index in glints of the one on the line
	var bite_t := 0.0               # s into WAIT of the bite
	var warn := 0.0                 # s the ears are up before it
	var tension := 0.5
	var in_band_t := 0.0            # s inside the band this reel
	var slip_t := 0.0               # s outside it in a row
	var pull_dir := 1.0
	var swell_t := 0.0              # s into this swell of the pull
	var swell_len := 1.0
	var casts: Array = []           # one {how, catch} a cast: how = caught, miss, early, late or slip

	func _init(who: Dictionary, day: int, r: RandomNumberGenerator) -> void:
		R = GlintFishing.rules()
		rec = who
		rng = r
		sign_list = GlintFishing.biting(day)
		warn = GlintFishing.warn_s(rec)
		_lay_glints()

	## The only writer of `state`: false (and counted) when the TABLE lacks the move.
	func go(next: S) -> bool:
		if not TABLE[state].has(next):
			refused += 1
			return false
		state = next
		state_t = 0.0
		return true

	func over() -> bool:
		return state == S.DONE

	## m out from the rock the cast lands if you let go now: it swings near_m to far_m and back.
	func reach() -> float:
		var u := pingpong(swing / float(R["swing_s"]), 1.0)
		return lerpf(float(R["near_m"]), float(R["far_m"]), u)

	## True while your Boki's ears are up (the bite is coming, or here).
	func ears() -> bool:
		return state == S.WAIT and state_t >= bite_t - warn

	func half_band() -> float:
		return GlintFishing.band(rec)

	## How many casts landed something.
	func caught() -> Array:
		return casts.filter(func(c): return c["how"] == "caught").map(func(c): return c["catch"])

	func step(dt: float, hold: bool) -> void:
		var pressed := hold and not held
		var let_go := held and not hold
		held = hold
		t += dt
		state_t += dt
		match state:
			S.AIM:
				if hold:
					swing += dt
				elif let_go and swing > 0.0:
					_cast()
			S.WAIT:
				if pressed:
					if ears():
						_hook()
					else:
						_end_cast("early")
				elif state_t > bite_t + float(R["late_s"]):
					_end_cast("late")
			S.REEL:
				_reel(dt, hold)
			S.SHOW:
				if state_t >= float(R["show_s"]):
					if casts.size() >= int(R["casts"]) or t >= float(R["max_s"]):
						go(S.DONE)
					else:
						_lay_glints()
						go(S.AIM)

	## Lays the next cast's glints, one in each equal stretch of the water so they never overlap.
	func _lay_glints() -> void:
		glints = []
		swing = 0.0
		hooked = -1
		var n := int(R["glints"])
		var near := float(R["near_m"])
		var stretch := (float(R["far_m"]) - near) / n
		var aim := float(R["aim_m"])
		var rare_list := GlintFishing.rares()
		for i in n:
			var rare := not rare_list.is_empty() and rng.randf() < GlintFishing.rare_chance(rec)
			var d := near + stretch * i + rng.randf_range(aim * 0.5, maxf(aim * 0.5, stretch - aim * 0.5))
			var side := rng.randf_range(-1.0, 1.0) * float(R["spread_m"])
			var c := GlintFishing.pick(rare_list if rare else sign_list, rng)
			glints.append({"d": d, "side": side, "rare": rare, "catch": c})

	func _cast() -> void:
		var d := reach()
		var best := -1
		for i in glints.size():
			var off := absf(float(glints[i]["d"]) - d)
			if off <= float(R["aim_m"]) and (best < 0 or off < absf(float(glints[best]["d"]) - d)):
				best = i
		if best < 0:
			_end_cast("miss")
			return
		hooked = best
		var w: Array = R["wait_s"]
		bite_t = rng.randf_range(float(w[0]), float(w[1]))
		go(S.WAIT)

	func _hook() -> void:
		tension = 0.5
		in_band_t = 0.0
		slip_t = 0.0
		_swell()
		go(S.REEL)

	func _swell() -> void:
		var s: Array = R["pull_s"]
		swell_t = 0.0
		swell_len = rng.randf_range(float(s[0]), float(s[1]))
		pull_dir = -1.0 if rng.randf() < 0.5 else 1.0
		if rng.randf() < float(R["jolt"]):
			tension = clampf(tension + pull_dir * _pull() * JOLT_K, 0.0, 1.0)

	## Tension per second the glint drags at the top of a swell.
	func _pull() -> float:
		var k := float(R["rare_pull"]) if glints[hooked]["rare"] else 1.0
		return float(R["pull"]) * k

	func _reel(dt: float, hold: bool) -> void:
		swell_t += dt
		if swell_t >= swell_len:
			_swell()
		var drag := pull_dir * _pull() * sin(PI * swell_t / swell_len)
		tension = clampf(tension + (float(R["rise"]) if hold else -float(R["fall"])) * dt + drag * dt, 0.0, 1.0)
		if absf(tension - 0.5) <= half_band():
			in_band_t += dt
			slip_t = 0.0
		else:
			slip_t += dt
		if in_band_t >= float(R["land_s"]):
			_end_cast("caught")
		elif slip_t >= float(R["slip_s"]):
			_end_cast("slip")

	func _end_cast(how: String) -> void:
		var c: Dictionary = glints[hooked]["catch"] if hooked >= 0 else {}
		casts.append({"how": how, "catch": c, "rare": hooked >= 0 and glints[hooked]["rare"]})
		go(S.SHOW)

## Pays out a finished session: banks each catch, joy for each and trust if any, energy, a memory line.
static func settle(run: Run) -> Dictionary:
	var R := rules()
	var got := run.caught()
	for e in got:
		GardenPrizes.bank(e)
	Care.change(run.rec, "energy", -float(R["energy"]))
	Care.change(run.rec, "joy", float(R["joy"]) * got.size())
	var trust := float(R["trust"]) if not got.is_empty() else 0.0
	Save.remember(run.rec, "fishing", "landed %d of %d glints off the rock" % [got.size(), run.casts.size()], trust)
	return {"got": got, "casts": run.casts.size()}

# ------------------------------------------------------------------ on the base
var h                          # the Home screen
var spot: Dictionary = {}      # this zone's rock (glint_fishing.json spots), {} for none
var rock: Node3D = null
var glint_nodes: Array = []    # MeshInstance3D, one per glint
var bobber: MeshInstance3D = null
var line: MeshInstance3D = null
var mats: Dictionary = {}      # common, rare: the glints' two shared materials
var run: Run = null
var who: Dictionary = {}       # the home's kin entry fishing with you
var holding := false
var last := Run.S.DONE         # the state the view last drew
var bar: ColorRect = null
var marker: ColorRect = null
var band_rect: ColorRect = null
var card: Control = null
var card_t := 0.0

func _init(home) -> void:
	h = home

## The rock, its sign and the glints' nodes, on this zone's spot (nothing in a zone without one).
func place() -> void:
	if is_instance_valid(rock):
		rock.queue_free()
	rock = null
	glint_nodes = []
	spot = rules()["spots"].get(GardenZones.here, {})
	if spot.is_empty():
		return
	rock = Node3D.new()
	rock.name = "GlintRock"
	rock.position = Vector3(spot["at"][0], 0.0, spot["at"][1])
	h.add_child(rock)
	var stone := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = ROCK_R
	sm.height = ROCK_R
	stone.mesh = sm
	stone.material_override = BaseRace.mat(Color("8d9aa3"))
	rock.add_child(stone)
	var post := Label3D.new()
	post.text = sign_text(day_of(Time.get_unix_time_from_system()))
	post.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	post.font_size = 28
	post.pixel_size = 0.006
	post.position = Vector3(spot["sign"][0], 1.3, spot["sign"][1]) - rock.position
	rock.add_child(post)
	mats = {false: _glow(Color("bff4ff")), true: _glow(Color("ffd24a"))}
	var gm := SphereMesh.new()
	gm.radius = GLINT_R
	gm.height = GLINT_R
	for i in int(rules()["glints"]) + 1:
		var g := MeshInstance3D.new()
		g.mesh = gm
		g.visible = false
		rock.add_child(g)
		glint_nodes.append(g)
	bobber = glint_nodes.pop_back()
	bobber.material_override = BaseRace.mat(Color("e8504a"))
	line = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(LINE_W, LINE_W, 1.0)
	line.mesh = lm
	line.material_override = BaseRace.mat(Color("eeeeee"))
	line.visible = false
	rock.add_child(line)

static func _glow(c: Color) -> StandardMaterial3D:
	var m := BaseRace.mat(c)
	m.emission_enabled = true
	m.emission = c
	return m

func find(p2: Vector2) -> Dictionary:
	if run != null or not is_instance_valid(rock):
		return {}
	if p2.distance_to(Vector2(rock.position.x, rock.position.z)) > REACH:
		return {}
	return {"kind": "fishing"}

func label() -> String:
	return "Go Glint Fishing with %s" % Save.active_kin().get("name", "your partner")

func use() -> void:
	var ak := Save.active_kin()
	var ks: Array = h.hrace.entrants().filter(func(k): return k["rec"] == ak)
	if ks.is_empty():
		h._toast("Glint Fishing needs your partner rested and out here")
		return
	who = ks[0]
	who["busy"] = true
	var dice := RandomNumberGenerator.new()
	dice.randomize()
	run = Run.new(ak, day_of(Time.get_unix_time_from_system()), dice)
	holding = false
	last = Run.S.DONE
	_open_bar()
	var at := _water(0.0, -ROCK_R - 0.3)
	at.y = maxf(0.0, h._ground_h(at.x, at.z))
	who["node"].position = at
	who["node"].rotation.y = atan2(_dir().x, _dir().y)
	who["pos"] = at
	h._toast("Hold %s to swing the cast, let go on a glint" % Settings.key_cap("interact"))

## A press or release: true when fishing took it.
func input(event: InputEvent) -> bool:
	if run == null:
		return false
	if event.is_action_pressed("menu"):
		_end(false)
		return true
	if event.is_action_pressed("interact"):
		holding = true
		return true
	if event.is_action_released("interact"):
		holding = false
		return true
	return false

func tick(d: float) -> void:
	if card_t > 0.0:
		card_t -= d
		if card_t <= 0.0 and is_instance_valid(card):
			card.queue_free()
	if run == null:
		return
	var was_ears := run.ears()
	var was := last
	run.step(d, holding)
	if run.ears() and not was_ears:
		h._emote(who, "!", true)
	if run.state == Run.S.WAIT and run.state_t >= run.bite_t and run.state_t - d < run.bite_t:
		h.verbs.play("bite")
	if run.state != last:
		_entered(run.state)
	_draw_water()
	GlintSfx.tick(h, run, was, was_ears, _sfx_at())
	if run.over():
		_end(true)

func _entered(s: Run.S) -> void:
	var from := last
	last = s
	bar.visible = s == Run.S.REEL
	h.verbs.hold("reel" if s == Run.S.REEL else "wait")
	if from == Run.S.AIM:
		h.verbs.play("cast")
	match s:
		Run.S.REEL:
			h._toast("Hooked! Hold and let go to keep the line in the band")
		Run.S.SHOW:
			var c: Dictionary = run.casts[-1]
			var lines := {"miss": "Plop: nothing there", "early": "Too soon: it darted off",
					"late": "Too late: it got away", "slip": "The line slipped"}
			var got: String = lines.get(c["how"], "")
			if c["how"] == "caught":
				got = "Landed %s!" % GardenPrizes.entry_name(c["catch"])
				h.verbs.play("land")
			h._toast("Cast %d of %d: %s" % [run.casts.size(), int(rules()["casts"]), got])
			h._emote(who, "♥" if c["how"] == "caught" else "…", true)

## Where the line meets the water, for the sounds: the bobber while it shows, else where the swing was let go.
func _sfx_at() -> Vector3:
	return bobber.global_position if bobber.visible else _water(run.reach(), 0.0)

## m along the cast and m to its side, from the rock, as a point on the water.
func _water(along: float, side: float) -> Vector3:
	var dir := _dir()
	var p := rock.position + Vector3(dir.x, 0.0, dir.y) * along + Vector3(-dir.y, 0.0, dir.x) * side
	p.y = ZoneDress.SHEET_Y + GLINT_R * 0.5
	return p

func _dir() -> Vector2:
	return Vector2(spot["toward"][0], spot["toward"][1]).normalized()

## The glints bob on the water while you aim and wait; the bobber shows where the cast is (or sits).
func _draw_water() -> void:
	var aiming := run.state == Run.S.AIM
	for i in glint_nodes.size():
		var g: MeshInstance3D = glint_nodes[i]
		var on := i < run.glints.size() and (aiming or (run.state == Run.S.WAIT and i == run.hooked))
		g.visible = on
		if on:
			var gl: Dictionary = run.glints[i]
			g.material_override = mats[gl["rare"]]
			g.position = _water(gl["d"], gl["side"]) - rock.position + Vector3(0, 0.03 * sin(run.t * 3.0 + i), 0)
	var out := run.reach() if aiming else 0.0
	if run.hooked >= 0 and run.state in [Run.S.WAIT, Run.S.REEL]:
		out = float(run.glints[run.hooked]["d"]) * (1.0 - 0.15 * run.tension if run.state == Run.S.REEL else 1.0)
	bobber.visible = out > 0.0 and (not aiming or run.held)
	line.visible = bobber.visible and not aiming
	if not bobber.visible:
		return
	bobber.position = _water(out, 0.0) - rock.position
	if line.visible:
		var tip := _line_start() - rock.position
		line.position = (tip + bobber.position) * 0.5
		line.scale = Vector3(1, 1, tip.distance_to(bobber.position))
		line.look_at(bobber.global_position)
	if run.state == Run.S.REEL:
		var w := bar.size.x
		band_rect.position.x = w * (0.5 - run.half_band())
		band_rect.size.x = w * run.half_band() * 2.0
		marker.position.x = w * run.tension - marker.size.x * 0.5

## Where the line leaves: your rod's tip, or your Boki's reach while the rod is away.
func _line_start() -> Vector3:
	var rod_tip := HunterRod.tip(h.p_anim) if h.p_anim != null else null
	if rod_tip != null:
		return rod_tip.global_position
	return who["node"].position + Vector3(0, ROD_UP, 0)

## The tension bar: the band in green, the line's tension as a white marker.
func _open_bar() -> void:
	bar = ColorRect.new()
	bar.color = Color(0.06, 0.07, 0.1, 0.85)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.custom_minimum_size = Vector2(360, 22)
	bar.size = bar.custom_minimum_size
	bar.position = Vector2(-180, -120)
	bar.visible = false
	band_rect = ColorRect.new()
	band_rect.color = Color(0.45, 0.85, 0.5, 0.8)
	band_rect.size = Vector2(0, 22)
	bar.add_child(band_rect)
	marker = ColorRect.new()
	marker.color = UI.INK
	marker.size = Vector2(6, 22)
	bar.add_child(marker)
	h.root_ui.add_child(bar)

func _end(finished: bool) -> void:
	var res := settle(run) if finished else {}
	who["busy"] = false
	who["t"] = 1.5
	GlintSfx.stop()
	h.verbs.hold("")
	if is_instance_valid(bar):
		bar.queue_free()
	for g in glint_nodes:
		g.visible = false
	bobber.visible = false
	line.visible = false
	if finished:
		_card(res)
		Save.save_game()
	run = null
	who = {}

func _card(res: Dictionary) -> void:
	if is_instance_valid(card):
		card.queue_free()
	var rows: Array = [["Glint Fishing: %d of %d landed" % [res["got"].size(), res["casts"]], 18, UI.ACCENT_HI]]
	for e in res["got"]:
		rows.append([GardenPrizes.entry_name(e), 14, UI.GOLD if String(e["kind"]) == "item" else UI.INK])
	if res["got"].is_empty():
		rows.append(["Nothing this time. The glints come back tomorrow, and so does the sign.", 14, UI.MUTED])
	card = BaseRace.result_card(h, rows)
	card_t = float(rules()["card_s"])
