extends RefCounted
## --base-life-check (GARDEN.md section 4 and 9.2): with base_mode on, four Boki live 10 simulated minutes on the
## real farm (home.gd _move_kin at 4 steps a second, BaseLife at 10 Hz) with one toy. Two hot tempers and two calm
## ones: at least one friend pair and one rival pair form, no state but Nap lasts over 90 s, the fourth Boki's
## arrival brings the others over (React), at night the three day Boki nap while the nocturnal Zapple stays up,
## no machine refuses a transition, bonds are symmetric, and a v11 save's Boki gain an empty bonds map; the sleepers
## breathe and yawn (BokiNapSfx, _nap_sounds). Then nap spots: a tired Boki walks to a free one, its friend lies
## down beside it, a third takes another. Then raising leans (_axes_part). Never touches the real save.

const SIM_SECS := 600.0  # 10 simulated minutes
const DT := 0.25  # s per farm step (the machines tick at 10 Hz inside it)
const SEEN_BY := 300.0  # s (5 game minutes): a watcher has seen every social act (BaseLife.acts) by now
const SEEN_KINDS := ["play", "nap", "greet", "squabble"]
const NIGHT_AT := 480.0  # s: the last two minutes are night
const ARRIVE_AT := 20.0  # s: the fourth Boki comes out
const LONGEST := 90.0  # s: no state but Nap may last longer
const LET_GO_MIN_FRAMES := 5  # frames the breath check waits at least, however slow they run
const HUNGRY_START := 12.0  # food a Boki starts the left-alone sim with: near the hungry floor (care.json sulky 8)
const ISLAND_SEED := 11  # the farm-start island: a random one moved the nap spots and what the walk runs into
const LET_GO_MS := 1500  # ms of real time a woken Boki's breathing loop may take to stop

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("BASELIFE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _new_save() -> Array:
	var d := Save.fresh()
	var recs: Array = []
	var hot := 0.95  # temper of the two that squabble
	var calm := 0.1
	var specs := [
		["cindle", "Ash", hot], ["basaltoad", "Crag", hot], ["burrlet", "Moss", calm], ["zapple", "Pip", calm]
	]
	seed(7)  # the same four Boki every run: traits, IVs and DNA from these dice, not from the run before
	for i in specs.size():
		var spec: Array = specs[i]
		var rec := Save.new_kin(spec[0], spec[1], 700 + i)
		rec["uid"] = "bl%d" % i  # new_id is clock-based; bonds are keyed by uid
		rec["traits"]["temper"] = spec[2]
		recs.append(rec)
	recs[0]["starter"] = true
	d["roster"] = recs.slice(0, 3)
	d["active"] = recs[0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}  # no base tutorial (Lead)
	Save.d = d
	HomeLayout.new_fs(d, ISLAND_SEED)
	HomeLayout.ensure(d)
	return recs


func _gather(home, at: Vector3) -> void:
	for i in home.kins.size():  # on a fixed 2 m grid: the global dice give another spread every run, even seeded
		var k: Dictionary = home.kins[i]
		var grid := Vector3(float(i % 2) * 2.0 - 1.0, 0, floorf(i * 0.5) * 2.0 - 1.0)
		k["pos"] = home.world.free_spot_near(at + grid, [], 0.8)
		(k["node"] as Node3D).position = k["pos"]


## The rivalry beat (BaseRival, garden_sim.json rivalry): rivals passing close turn, huff and walk on, once a
## cooldown, and never play tag; a pair that is not rivals does nothing.
func _rival_beat(home) -> void:
	var r: Dictionary = BaseRival.rules()
	var a: Dictionary = home.kins[0]
	var b: Dictionary = home.kins[1]
	var c: Dictionary = home.kins[2]
	home.day_t = 0.4
	home.life.night = false
	for k in [a, b, c]:
		for key in ["rival_cd", "play", "eat", "nap_t", "life_at", "life_rival"]:
			k.erase(key)
		(k["life"] as Fsm).go(BaseLife.S.ROAM, "test")
	# the beat walks 4 m away from the other, which only counts on open ground: start from the island's middle
	var mid: Vector2 = home.world.islands[maxi(home.world.island_of(a["pos"].x, a["pos"].z), 0)]["c"]
	a["pos"] = home.world.free_spot_near(Vector3(mid.x, 0, mid.y), [], 0.8)
	(a["node"] as Node3D).position = a["pos"]
	b["pos"] = a["pos"] + Vector3(float(r["pass_m"]) * 0.5, 0, 0)
	c["pos"] = a["pos"] + Vector3(-float(r["pass_m"]) * 0.5, 0, 0)
	BaseLife.add_bond(a["rec"], b["rec"], -1.0 - BaseLife.bond(a["rec"], b["rec"]))
	BaseLife.add_bond(a["rec"], c["rec"], 0.0 - BaseLife.bond(a["rec"], c["rec"]))
	var heard := (
		int(GardenSfx.heard.get("garden_sulk_small", 0))
		+ int(GardenSfx.heard.get("garden_sulk_medium", 0))
		+ int(GardenSfx.heard.get("garden_sulk_large", 0))
	)
	home.life.step(0.2)
	var fa: Fsm = a["life"]
	var fb: Fsm = b["life"]
	var facing := is_same(a["life_at"], b) and is_same(b["life_at"], a)
	ok(
		fa.is_in(BaseLife.S.REACT) and fb.is_in(BaseLife.S.REACT) and facing,
		"rivals passing within %.1f m both turn to each other (React)" % float(r["pass_m"])
	)
	ok(float(a["huff_t"]) > 0.0 and float(b["huff_t"]) > 0.0, "both play the growl clip")
	var after := (
		int(GardenSfx.heard.get("garden_sulk_small", 0))
		+ int(GardenSfx.heard.get("garden_sulk_medium", 0))
		+ int(GardenSfx.heard.get("garden_sulk_large", 0))
	)
	ok(after == heard + 2, "each huffs through the garden SFX (%d cues)" % (after - heard))
	ok((c["life"] as Fsm).is_in(BaseLife.S.ROAM), "a Boki that is not a rival is left alone")
	var gap := BaseLife._dist(a, b)
	for i in int(float(r["beat_s"]) / 0.1) + 2:
		home.life.step(0.1)
	ok(
		fa.is_in(BaseLife.S.ROAM) and fb.is_in(BaseLife.S.ROAM) and not a.has("life_rival"),
		"the beat ends in %.1f s" % float(r["beat_s"])
	)
	ok(Vector2(a["goal"].x - b["pos"].x, a["goal"].z - b["pos"].z).length() > gap, "it walks on, away from the other")
	home.life.step(0.2)
	ok(not fa.is_in(BaseLife.S.REACT), "no repeat inside the cooldown (%.0f s)" % float(r["cooldown_s"]))
	for k in [a, b]:
		(k["life"] as Fsm).go(BaseLife.S.ROAM, "test")
	home.life._tag(a, b)
	ok(not fa.is_in(BaseLife.S.PLAY_WITH) and not fb.is_in(BaseLife.S.PLAY_WITH), "rivals never play tag together")


## You come back (BaseGreet, base_life.json "notice"): a Boki that had you far off for away_s looks at you when you come
## within near_m; at bond rank Close or more it runs to you, follows a few steps, and goes back to roaming. It rolls
## once per return, and the roll is weighted by bond rank.
func _notice_part(home, center: Vector3) -> void:
	var life: BaseLife = home.life
	var r: Dictionary = BaseGreet.rules()
	var kept_chance: float = r["chance"]
	home.day_t = 0.4
	life.night = false
	for k in home.kins:
		for key in ["play", "eat", "nap_t", "life_at", "life_rival", "rival_cd", "notice_away", "life_greet", "led"]:
			k.erase(key)
		k["rec"]["bonds"] = {}
		(k["life"] as Fsm).go(BaseLife.S.ROAM, "test")
	_gather(home, center)
	var k: Dictionary = home.kins[0]
	var m: Fsm = k["life"]
	var away := Vector3(-500, 0, -500)
	var back: Vector3 = home.world.free_spot_near(k["pos"] + Vector3(float(r["near_m"]) - 0.5, 0, 0), [], 0.8)
	r["chance"] = 1.0
	k["rec"]["trust"] = 0.0  # Wary
	home.ppos = away
	for _i in int(float(r["away_s"]) / 0.1) + 5:
		life.step(0.1)
	ok(m.is_in(BaseLife.S.ROAM), "you far off: a roaming Boki does not react")
	home.ppos = back
	life.step(0.1)
	var g: Dictionary = k.get("life_greet", {})
	ok(
		m.is_in(BaseLife.S.GREET) and not g.is_empty() and not g["runs"],
		"back within %.1f m: a Wary Boki looks" % float(r["near_m"])
	)
	for _i in int(float(r["look_s"]) / 0.1) + 3:
		life.step(0.1)
	ok(
		m.is_in(BaseLife.S.ROAM) and not k.has("life_greet"),
		"it looked for %.1f s, then went back to roaming" % float(r["look_s"])
	)
	for _i in 100:
		life.step(0.1)
	ok(m.is_in(BaseLife.S.ROAM), "you stay near: no second greeting until you have been away again")
	k["rec"]["trust"] = 60.0  # Close
	home.ppos = away
	for _i in int(float(r["away_s"]) / 0.1) + 5:
		life.step(0.1)
	k["pos"] = home.world.free_spot_near(back + Vector3(-float(r["near_m"]) + 0.5, 0, 0), [], 0.8)
	(k["node"] as Node3D).position = k["pos"]
	home.ppos = back
	life.step(0.1)
	g = k.get("life_greet", {})
	ok(m.is_in(BaseLife.S.GREET) and not g.is_empty() and g["runs"], "a Close Boki runs over")
	var t := 0.0
	while t < float(r["give_up_s"]) and float(k.get("life_greet", {}).get("reached", 0.0)) < 0.0:
		home._move_kin(DT)
		t += DT
	ok(
		k.has("life_greet") and float(k["life_greet"]["reached"]) >= 0.0 and not k.has("led"),
		"it reached you in %.1f s and slowed to a walk" % t
	)
	home.ppos = home.world.free_spot_near(home.ppos + Vector3(3.0, 0, 0), [], 0.8)
	var gap := BaseLife._dist(k, {"pos": home.ppos})
	for _i in int(float(r["follow_s"]) / DT) + 6:
		home._move_kin(DT)
		if m.is_in(BaseLife.S.ROAM):
			break
	var now := BaseLife._dist(k, {"pos": home.ppos})
	ok(now < gap, "it followed you as you walked off (%.1f m gap, was %.1f)" % [now, gap])
	for _i in int(float(r["follow_s"]) / DT) + 6:
		home._move_kin(DT)
	ok(
		not m.is_in(BaseLife.S.GREET) and not k.has("life_greet") and not k.has("led"),
		"then it went back to what it was doing"
	)
	r["chance"] = kept_chance
	var hits := {0.0: 0, 95.0: 0}
	home.ppos = back  # you stand where you came back (the follow part above walked you off)
	seed(11)
	for trust in hits:
		for _i in 200:
			for key in ["play", "eat", "nap_t", "life_at", "life_rival", "life_greet", "led"]:
				k.erase(key)  # the Boki may have started its own play while it followed you
			m.go(BaseLife.S.ROAM, "test")
			k["rec"]["trust"] = trust
			k["notice_away"] = float(r["away_s"])
			k["pos"] = back + Vector3(-1.0, 0, 0)
			life.step(0.1)
			hits[trust] += 1 if m.is_in(BaseLife.S.GREET) else 0
	var weighed := "bond rank weights it: Soulbound %d of 200 returns, Wary %d" % [hits[95.0], hits[0.0]]
	ok(hits[95.0] > hits[0.0] + 40, weighed)


## Free play sounds (PlaySfx): a tag starts, a catch, a cheer when it runs out, a huff for a squabble; each once, quiet,
## and a zone plays at most MAX_CUES of them inside WINDOW_S however many Boki play.
func _play_sounds(home) -> void:
	var life: BaseLife = home.life
	var a: Dictionary = home.kins[0]
	var b: Dictionary = home.kins[1]
	life.sfx = PlaySfx.new()
	for k in [a, b]:
		k["rec"]["traits"]["temper"] = 0.0  # no squabble by chance
		k.erase("life_at")
		(k["life"] as Fsm).go(BaseLife.S.ROAM, "test")
	BaseLife.add_bond(a["rec"], b["rec"], 0.5 - BaseLife.bond(a["rec"], b["rec"]))
	b["pos"] = a["pos"] + Vector3(0.5, 0, 0)
	var gos := _cues("garden_go")
	life._tag(a, b)
	ok(
		_cues("garden_go") == gos + 1 and (a["life"] as Fsm).is_in(BaseLife.S.PLAY_WITH),
		"a tag starting plays one go cue"
	)
	life.sfx.tick(PlaySfx.WINDOW_S)
	var scuffs := _cues("tumble_push")
	life._tag_tick(a, a["life"])
	ok(
		_cues("tumble_push") == scuffs + 1 and b.get("life_it", false),
		"a catch plays one scuff and passes the chase on"
	)
	life.sfx.tick(PlaySfx.WINDOW_S)
	a["life_for"] = 0.0
	var cheers := _cues("garden_cheer_good")
	life._tag_tick(a, a["life"])
	life._tag_tick(b, b["life"])
	ok(_cues("garden_cheer_good") == cheers + 1, "a game of tag running out plays one cheer, not one per Boki")
	life.sfx.tick(PlaySfx.WINDOW_S)
	var huffs := _cues("garden_sulk_small") + _cues("garden_sulk_medium") + _cues("garden_sulk_large")
	life._squabble(a, b)
	var after := _cues("garden_sulk_small") + _cues("garden_sulk_medium") + _cues("garden_sulk_large")
	ok(after == huffs + 1, "a squabble plays one huff in the Boki's size (%d)" % (after - huffs))
	life.sfx.tick(PlaySfx.WINDOW_S)
	var was := life.sfx.dropped
	var played := _cues("garden_go")
	for i in 10:
		life.sfx.tag_start(a["rec"], a["pos"])
	ok(
		_cues("garden_go") - played == PlaySfx.MAX_CUES and life.sfx.dropped - was == 10 - PlaySfx.MAX_CUES,
		"ten Boki starting at once play %d cues in a zone window, the rest held back" % PlaySfx.MAX_CUES
	)
	var here := GardenZones.here
	GardenZones.here = "other_zone"
	life.sfx.tag_start(a["rec"], a["pos"])
	GardenZones.here = here
	ok(_cues("garden_go") - played == PlaySfx.MAX_CUES + 1, "another zone has its own allowance")
	life.sfx.tick(PlaySfx.WINDOW_S)
	life.sfx.tag_start(a["rec"], a["pos"])
	ok(_cues("garden_go") - played == PlaySfx.MAX_CUES + 2, "the allowance comes back once the window has passed")


func _cues(sname: String) -> int:
	return int(GardenSfx.heard.get(sname, 0))


## BokiNapSfx: of 30 Boki asleep around you only the nearest few breathe, within the loop's reach; a bigger
## Boki breathes lower; the night's sleepers breathe near you, and at dawn they yawn and the woken ones' loops let go.
func _nap_sounds(home) -> void:
	var pile := []
	for i in 30:
		pile.append({"pos": Vector3(float(i % 6) * 1.2, 0, float(int(i / 6.0)) * 1.2)})
	var heard := BokiNapSfx.heard(pile, Vector3.ZERO)
	var reach := float(Sfx.sound_reach.get(BokiNapSfx.LOOP, 0.0))
	var inside := heard.all(func(k): return Vector2(k["pos"].x, k["pos"].z).length() < reach)
	ok(
		heard.size() == BokiNapSfx.MAX_HEARD and inside and is_same(heard[0], pile[0]),
		"of 30 asleep only the %d nearest breathe, all within %.0f m" % [heard.size(), reach]
	)
	var by_cm: Array = home.kins.map(func(k): return k["rec"])
	by_cm.sort_custom(func(a, b): return float(Unique.size_info(a)["cm"]) < float(Unique.size_info(b)["cm"]))
	var lower := true
	for i in by_cm.size() - 1:
		lower = lower and BokiNapSfx.pitch_of(by_cm[i + 1]) <= BokiNapSfx.pitch_of(by_cm[i])
	ok(lower, "a bigger Boki breathes lower (%s)" % [by_cm.map(func(r): return "%.2f" % BokiNapSfx.pitch_of(r))])
	var sleeper: Dictionary = home.kins.filter(func(k): return float(k.get("nap_t", 0.0)) > 0.0)[0]
	for key in Sfx.loops.keys():  # the sim's loops still held (HOLD_MS of real time) are not tonight's sleepers
		if String(key).begins_with("nap:"):
			Sfx.loop_stop(key)
	Sfx.listener = sleeper["pos"]
	# holds from earlier steps lapse on the wall clock (250 ms), not on these fixed steps
	for key in Sfx.loops.keys():
		if String(key).begins_with("nap:"):
			Sfx.loop_stop(key)
	home._move_kin(DT)
	var on := Sfx.loops.keys().filter(func(key): return String(key).begins_with("nap:"))
	ok(
		on.size() >= 1 and on.size() <= BokiNapSfx.MAX_HEARD,
		"the night's sleepers near you breathe (%d loops)" % on.size()
	)
	home.day_t = 0.3
	Sfx.last_played.erase(BokiNapSfx.YAWN)
	for i in int(10.0 / DT):
		Sfx.listener = sleeper["pos"]
		home._move_kin(DT)
		if Sfx.last_played.has(BokiNapSfx.YAWN):
			break
	ok(Sfx.last_played.has(BokiNapSfx.YAWN), "a Boki waking at dawn yawns")
	# Sfx.loop_hold lets go HOLD_MS of real time after the last hold; give the frames up to LET_GO_MS to run it
	var t0 := CheckClock.own_msec()
	var left := _awake_breaths(home)
	var frames := 0
	# a loaded box can run only a frame or two in LET_GO_MS: wait for LET_GO_MS_MIN_FRAMES frames as well
	while not left.is_empty() and (CheckClock.own_msec() - t0 < LET_GO_MS or frames < LET_GO_MIN_FRAMES):
		await main.get_tree().process_frame
		frames += 1
		left = _awake_breaths(home)
	ok(left.is_empty(), "an awake Boki's breath lets go within %d ms (%d still on)" % [LET_GO_MS, left.size()])


## The breathing loops still on for Boki that are awake.
func _awake_breaths(home) -> Array:
	var awake: Array = (
		home
		. kins
		. filter(func(k): return float(k.get("nap_t", 0.0)) <= 0.0)
		. map(func(k): return "nap:" + String(k["rec"]["uid"]))
	)
	return Sfx.loops.keys().filter(func(key): return key in awake)


## The nap part's two spot tiles (_spots_part) are open ground on center's island.
func _nap_ground(w, center: Vector3) -> bool:
	var cx := int(center.x)
	var cz := int(center.z)
	for o: Array in [[4, 0], [-4, 3]]:
		var x: float = cx + int(o[0]) + 0.5
		var z: float = cz + int(o[1]) + 0.5
		if w.is_void(x, z) or w.is_block(x, z) or w.island_of(x, z) != w.island_of(center.x, center.z):
			return false
	return true


## Nap spots (garden_zones.json nap, set here around the gathering place: the farm island is random).
func _spots_part(home, center: Vector3) -> void:
	var zone: Dictionary = GardenZones.info(GardenZones.start())
	var kept: Array = zone["nap"]
	var cx := int(center.x)
	var cz := int(center.z)
	zone["nap"] = [["sunny rock", cx + 4, cz], ["under a tree", cx - 4, cz + 3]]
	var life: BaseLife = home.life
	life.r_v["doze"] = 0.0  # these places are for tired naps: a random company doze would send a Boki elsewhere
	life.r_v["doze_pile"] = 0.0
	seed(11)
	home.day_t = 0.4
	for k in home.kins:
		k["nap_t"] = 0.0
		life.machine(k).go(BaseLife.S.ROAM, "test")
		k["rec"]["bonds"] = {}
		Care.need(k["rec"], "joy")
		k["rec"]["needs"]["joy"] = 90.0
	_gather(home, center)
	# each starts a step from its place: how far from it a Boki lies down varies with the walk, and so did this row
	var starts := [Vector3(cx + 3.0, 0, cz + 0.5), Vector3(cx + 3.0, 0, cz + 1.5), Vector3(cx - 2.5, 0, cz + 3.5)]
	for n in starts.size():
		var k: Dictionary = home.kins[n]
		k["pos"] = home.world.free_spot_near(starts[n], [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
	var keys: Array = home.kins.map(func(k): return k["rec"].keys())
	var a: Dictionary = home.kins[0]
	var b: Dictionary = home.kins[1]
	var c: Dictionary = home.kins[2]
	BaseLife.add_bond(a["rec"], b["rec"], 0.6)
	for k in [a, b, c]:
		life._nap(k, "tired")
	var sa: Dictionary = a.get("life_spot", {})
	var sb: Dictionary = b.get("life_spot", {})
	var sc: Dictionary = c.get("life_spot", {})
	ok(not sa.is_empty() and int(sa["slot"]) == 0, "a tired Boki heads for a free nap spot")
	ok(
		not sb.is_empty() and sb["i"] == sa.get("i") and int(sb["slot"]) == 1,
		"its friend (bond 0.6) takes the place beside it"
	)
	ok(not sc.is_empty() and sc["i"] != sa.get("i") and int(sc["slot"]) == 0, "a third Boki takes the other spot")
	var t := 0.0
	while t < float(life.r_v["spot_walk"]) + 1.0 and [a, b, c].any(func(k): return float(k.get("nap_t", 0.0)) <= 0.0):
		home._move_kin(DT)
		t += DT
	var on := [a, b, c].filter(
		func(k):
			return (
				k.has("life_spot")
				and float(k["nap_t"]) > 0.0
				and BaseLife._dist(k, {"pos": k["life_spot"]["pos"]}) < BaseLife.SPOT_AT * 2.0
			)
	)
	ok(on.size() == 3, "all three walked there and lie down on their places in %.1f s (%d of 3)" % [t, on.size()])
	var was := BaseLife.bond(a["rec"], b["rec"])
	for i in 20:
		home._move_kin(DT)
	ok(BaseLife.bond(a["rec"], b["rec"]) > was, "napping side by side, the friends' bond grows")
	ok(home.kins.map(func(k): return k["rec"].keys()) == keys, "nothing of it is saved: the records gain no key")
	zone["nap"] = kept


## Raising leans (BaseAxes, base_axes.json): 10 days of each care style give the rows below, ten days of play make a
## busy Boki and ten of feeding alone a lazy one, and a lazier Boki naps more often on its own than a busy one.
func _axes_part(home) -> void:
	var axes := Content.rules("base_axes")
	var rows := {}
	for style in axes["styles"]:
		var rec := Save.new_kin("burrlet", style)
		for day in 10:
			for kind in axes["styles"][style]:
				BaseAxes.care(rec, kind)
		rows[style] = rec
		var scales: Array = axes["weights"].keys().map(func(a): return "%s x%.2f" % [a, BaseAxes.mult(rec, a)])
		print("BASELIFE axes %-8s %s %s" % [style, rec["raised"], ", ".join(scales)])
	var cap := float(axes["cap"])
	ok(rows["none"]["raised"].values().all(func(v): return v == 0.0), "no care leaves every axis at 0")
	ok(
		rows.values().all(func(r): return r["raised"].values().all(func(v): return absf(v) <= cap + 0.0001)),
		"no axis leaves +-%.1f" % cap
	)
	ok(
		BaseAxes.mult(rows["player"], "play") > 1.2 and BaseAxes.mult(rows["feeder"], "nap") > 1.1,
		"play makes a Boki busy (plays more), feeding alone a lazy one (naps more)"
	)
	ok(
		BaseAxes.mult(rows["trainer"], "chase") > 1.4 and BaseAxes.mult(rows["cuddler"], "chase") < 1.0,
		"training makes a bold, rough Boki that chases more; cuddling a gentle one that chases less"
	)
	ok(BaseAxes.mult(rows["trainer"], "cling") < 0.7, "a bold Boki clings to you less")
	ok(
		rows["player"]["journal"].size() == 1 and rows["none"]["journal"].is_empty(),
		"crossing a band writes one journal line (%s)" % [rows["player"]["journal"]]
	)
	var life: BaseLife = home.life
	var a: Dictionary = home.kins[0]
	home.day_t = 0.4
	life.night = false
	a["rec"]["needs"]["energy"] = 100.0
	a["rec"]["needs"]["food"] = 100.0
	for k in home.kins:
		if k != a:
			k["busy"] = true
	var naps := {}
	for who in ["feeder", "player"]:
		a["rec"]["raised"] = rows[who]["raised"]
		naps[who] = 0
		for i in 400:
			a.erase("nap_t")
			(a["life"] as Fsm).go(BaseLife.S.ROAM, "test")
			life.choose(a)
			naps[who] += 1 if (a["life"] as Fsm).is_in(BaseLife.S.NAP) else 0
	ok(
		naps["feeder"] > naps["player"] + 10,
		"400 thinks: the lazy Boki naps %d times, the busy one %d" % [naps["feeder"], naps["player"]]
	)
	a["rec"]["raised"] = {"bold": 0.0, "busy": 0.0, "gentle": 0.0}
	for k in home.kins:
		k.erase("busy")


## Left alone: hungry Boki, a bare pantry, no patch and no bowl. Over the same 10 simulated minutes every one eats
## from a wild tree on its own, and none ends pinned at the hungry floor.
func _left_alone(home) -> void:
	var floor_food := float(Care.sulky()["food"])
	Save.d["crops"] = {}
	Save.d["items"] = {}
	home.day_t = 0.4
	seed(11)
	for k in home.kins:
		for key in ["eat", "life_eat", "nap_t", "life_spot", "life_at"]:
			k.erase(key)
		(k["life"] as Fsm).go(BaseLife.S.ROAM, "test")
		k["rec"]["needs"]["food"] = HUNGRY_START
		k["rec"]["needs"]["energy"] = 100.0
	_gather(home, home.kins[0]["pos"])
	var lowest := {}
	var t := 0.0
	while t < SIM_SECS:
		home._move_kin(DT)
		t += DT
		for k in home.kins:
			var uid := String(k["rec"]["uid"])
			var food := Care.need(k["rec"], "food")
			lowest[uid] = minf(float(lowest.get(uid, 100.0)), food)
	for k in home.kins:
		var uid := String(k["rec"]["uid"])
		var food := Care.need(k["rec"], "food")
		ok(
			food > floor_food + 10.0,
			(
				"%s left alone ate on its own (food %.0f, lowest %.0f, floor %.0f)"
				% [k["rec"]["name"], food, lowest[uid], floor_food]
			)
		)


func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(11)
	var old := Save.fresh()
	old["v"] = 11
	old["roster"] = [{"uid": "old1", "species": "zapple", "name": "Old", "traits": {}, "trust": 35.0}]
	var upgraded := Save.migrate(old) and int(old["v"]) == Save.VERSION
	var bonds = old["roster"][0].get("bonds")
	ok(
		upgraded and bonds is Dictionary and (bonds as Dictionary).is_empty(),
		"a v11 save upgrades and its Boki gain an empty bonds map"
	)
	var rules: Dictionary = Content.rules("farm_build")
	rules["base_mode"] = true
	seed(11)  # the four Boki roll their own uids, sizes and traits: same four every run
	var recs := _new_save()
	var home = await main._hb_home()
	ok(home.life != null, "base_mode on: the farm runs BaseLife")
	# The farm's own _process steps the Boki by real frame time, which varies with machine load: from here the
	# check steps them alone (fixed DT), and draws from a stream seeded after the build frames.
	home.set_process(false)
	seed(11)
	home.day_t = 0.4
	home.ppos = Vector3(-500, 0, -500)  # you are away: nobody clings to you
	var center: Vector3 = home.world.random_ground(0)
	for _i in 60:  # (the nap part puts its two spots 4 m either side: open ground here, whatever the draws before)
		if _nap_ground(home.world, center):
			break
		center = home.world.random_ground(0)
	Save.d["layout"]["deco"].append({"id": "toy_ball", "u": 990001, "px": center.x + 3.0, "pz": center.z})
	ok(home.life.toy_spots().size() == 1, "the placed ball is the one toy the machine knows (HomeToys owns the toys)")
	_gather(home, center)
	var longest := {}  # state name -> longest s seen
	var reacted := false
	var night_frames := 0
	var day_asleep := 0
	var pip_awake := 0
	var refused := 0
	var t := 0.0
	var seen_early := {}  # social act -> how many had happened by SEEN_BY
	while t < SIM_SECS:
		if t < ARRIVE_AT and t + DT >= ARRIVE_AT:
			for kk in home.kins:
				refused += (kk["life"] as Fsm).refused
			Save.d["roster"].append(recs[3])
			home._spawn_kin()
			_gather(home, center)
		if t >= NIGHT_AT:
			home.day_t = 0.0
		home._move_kin(DT)
		t += DT
		if seen_early.is_empty() and t >= SEEN_BY:
			seen_early = home.life.acts.duplicate()
			print("BASELIFE acts to %.0f s: %s\n%s" % [t, seen_early, "\n".join(home.life.act_log)])
		for k in home.kins:
			if not k.has("life"):
				continue
			var fsm: Fsm = k["life"]
			if not fsm.is_in(BaseLife.S.NAP):
				longest[fsm.state_name()] = maxf(float(longest.get(fsm.state_name(), 0.0)), fsm.since)
			reacted = reacted or fsm.is_in(BaseLife.S.REACT)
			if t >= NIGHT_AT + 15.0:
				if k["rec"]["species"] == "zapple":
					pip_awake += 0 if fsm.is_in(BaseLife.S.NAP) else 1
				else:
					day_asleep += 1 if fsm.is_in(BaseLife.S.NAP) else 0
		night_frames += 1 if t >= NIGHT_AT + 15.0 else 0
	for k in home.kins:
		refused += (k["life"] as Fsm).refused
	print(home.life.readout())
	var friends := 0
	var rivals := 0
	var symmetric := true
	for i in recs.size():
		for j in range(i + 1, recs.size()):
			var b := BaseLife.bond(recs[i], recs[j])
			symmetric = symmetric and is_equal_approx(b, BaseLife.bond(recs[j], recs[i]))
			friends += 1 if b >= float(home.life.r_v["friend_at"]) else 0
			rivals += 1 if b <= float(home.life.r_v["rival_at"]) else 0
	ok(friends >= 1, "at least one friend pair formed (%d)" % friends)
	ok(rivals >= 1, "at least one rival pair formed (%d)" % rivals)
	ok(symmetric, "every bond is the same both ways")
	var over: Array = longest.keys().filter(func(s): return float(longest[s]) > LONGEST)
	ok(over.is_empty(), "no state but Nap lasts over %.0f s (longest %s)" % [LONGEST, longest])
	ok(reacted, "the fourth Boki's arrival brought the others over to look (React)")
	ok(
		day_asleep >= night_frames * 3 * 0.8,
		"at night the three day Boki nap (%d of %d frames)" % [day_asleep, night_frames * 3]
	)
	ok(
		pip_awake >= night_frames * 0.5,
		"the nocturnal Zapple stays up at night (%d of %d frames)" % [pip_awake, night_frames]
	)
	for kind in SEEN_KINDS:
		ok(
			int(seen_early.get(kind, 0)) >= 1,
			"a watcher sees %s within %.0f s (%d times)" % [kind, SEEN_BY, int(seen_early.get(kind, 0))]
		)
	ok(refused == 0, "no machine refused a transition (%d)" % refused)
	await _nap_sounds(home)
	_spots_part(home, center)
	_rival_beat(home)
	_play_sounds(home)
	_notice_part(home, center)
	_axes_part(home)
	_left_alone(home)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("BASELIFE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
