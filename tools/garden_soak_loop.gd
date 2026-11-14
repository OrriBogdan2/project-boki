extends RefCounted
## The part of --garden-soak that proves the whole garden loop (GARDEN.md): a Soul Shrine the retired Elder stays
## by, a friends pair that lays a Nook egg which hatches wearing the Elder's gift, and one away gap whose card
## lists what the garden gave. Run by garden_soak.gd, which owns the clock, the report and the failure count.

const SHRINE_LOT := {"x": 41, "z": 35, "r": 0}   # the Soul Shrine lot (grid cell, turn) near the landing
const LAY_DAY := 2                # in-game day the pair lays its egg
const HATCH_DAY := 3              # in-game day the egg is ripe and hatches
const AWAY_DAY := 15              # in-game day the player is gone for AWAY_H hours
const AWAY_H := 7.0               # hours away: more than one gift_every_h, under gift_max of them
const NEAR_SHARE := 0.8           # share of the Elder's time that must be spent near the Shrine
const PARENTS := ["Pip", "Moss"]  # the pair (BaseDemo friends)
const BABY_SPECIES := "puddlet"   # a kind nobody on the farm is, so the baby stays out on it (not in the Burrow)
const HATCH_FRAMES := 900         # frames to wait at most for the hatch to finish

var soak                          # the --garden-soak run (ok, t, home)
var egg_gift := {}                # the gift laid on the egg
var baby := {}                    # the hatched record
var near := 0                     # steps the Elder was near the Shrine, once it arrived
var arrived := 0                  # steps since it arrived
var far_max := 0.0                # m, farthest it was from the Shrine once it arrived

func _init(run) -> void:
	soak = run

## The save before the farm builds: the Shrine standing, the pair Grown and friends.
func prepare(d: Dictionary) -> void:
	d["buildings"].append("shrine")
	d["layout"]["b"]["shrine"] = SHRINE_LOT.duplicate()
	for rec in d["roster"]:
		if PARENTS.has(String(rec["name"])):
			rec["level"] = NookRules.GROWN_LV
			rec["trust"] = 60.0

func stage() -> void:
	var h = soak.home
	h.hg.demo_place("nesting_nook", HomeLayout.LANDING + BaseDemo.NOOK_AT)
	h._sync_fixtures()
	h.hinc.refresh()
	soak.ok(h.lots.has("shrine") and h.lots["shrine"]["at"] != h.FAR, "the Soul Shrine stands on the farm")
	soak.ok(Mentor.is_mentor(_kin("Gran")["rec"]), "the Elder is a retired mentor")

func _kin(nm: String) -> Dictionary:
	for k in soak.home.kins:
		if String(k["rec"]["name"]) == nm:
			return k
	return {}

## Each step: how close the Elder keeps to the Shrine.
func watch() -> void:
	_dismiss_cards()
	var elder := _kin("Gran")
	if elder.is_empty():
		return
	var shrine: Vector3 = soak.home.lots["shrine"]["at"]
	var d := Vector2(elder["pos"].x - shrine.x, elder["pos"].z - shrine.z).length()
	var close: bool = d < 4.0 + float(soak.home.life.R["mentor_radius"])
	if close and arrived == 0:
		arrived = 1
	elif arrived > 0:
		arrived += 1
		near += 1 if close else 0
		far_max = maxf(far_max, d)

## The hatch's reveal and naming cards wait for a click, and the farm waits for them: the player clicks at once.
func _dismiss_cards() -> void:
	var h = soak.home
	if h.panel_open == "reveal":
		for c in h.get_children():
			if c is KinReveal:
				c.proceed.emit()
				return
	elif h.panel_open != "":
		h._close_panel()
		h.building_now = false

## The player's day: lay the egg, hatch it, be away once.
func day(n: int) -> void:
	if n == LAY_DAY:
		_lay()
	elif n == HATCH_DAY:
		_hatch()
	elif n == AWAY_DAY:
		_away()

func _lay() -> void:
	var a: Dictionary = _kin(PARENTS[0])["rec"]
	var b: Dictionary = _kin(PARENTS[1])["rec"]
	var why := NookRules.pair_why(a, b)
	soak.ok(why == "", "the friends %s and %s may breed (%s)" % [PARENTS[0], PARENTS[1], why])
	soak.home._make_egg(a, b)
	var egg: Dictionary = Save.d["egg"]
	egg["sp"] = BABY_SPECIES
	egg_gift = egg.get("gift", {})
	soak.ok(String(egg_gift.get("from", "")) == "Gran", "a Nook egg is laid with the Elder's gift (%s)" % str(egg_gift))
	soak.ok((_kin("Gran")["rec"]["mentor"] as Dictionary)["gifted"] == true, "the Elder's gift is spent")

func _hatch() -> void:
	if Save.d["egg"].is_empty():
		return
	Save.d["egg"]["t"] = 0.0      # real unix time cannot be sped up: ripen the egg instead
	soak.home._hatch_nest_egg()

## Frames for the hatch animation (it runs in real frames, not farm steps) to put the baby out on the farm.
func finish() -> void:
	for i in HATCH_FRAMES:
		if Save.d["roster"].any(func(r): return r.has("gift") and not _kin(String(r["name"])).is_empty()):
			return
		await soak.main.get_tree().process_frame

## After the run: the hatch finished, the baby wears the gift and lives on the farm, the Elder stayed by the Shrine.
func report() -> void:
	for rec in Save.d["roster"]:
		if rec.has("gift"):
			baby = rec
	soak.ok(Save.d["egg"].is_empty() and not baby.is_empty(), "the egg hatched")
	if not baby.is_empty():
		var line := Mentor.line(baby["gift"])
		soak.ok(not egg_gift.is_empty() and line == Mentor.line(egg_gift), "the baby wears the gift: %s" % line)
		soak.ok(baby["parents"] == PARENTS, "the baby knows its parents %s" % str(baby["parents"]))
		var out: bool = not _kin(String(baby["name"])).is_empty() or KinBox.is_boxed(baby)
		soak.ok(out, "the baby lives on the farm (%s)" % baby["name"])
	soak.ok(arrived > 0 and near >= arrived * NEAR_SHARE,
			"the Elder stays near the Shrine (%d of %d steps, farthest %.1f m)" % [near, arrived, far_max])

## One away gap: the last arrival goes back AWAY_H hours, and the arrival card must list the gifts.
func _away() -> void:
	var gap := AWAY_H * 3600.0
	Save.d["away_seen"] = Time.get_unix_time_from_system() - gap
	var lines: Array = CareJournal.arrival(Work.catch_up())
	var text := "\n".join(lines)
	var gifts := lines.filter(func(l): return String(l).contains("saved you a snack")).size()
	soak.ok(gifts == GardenAway.gift_count(gap) and gifts > 0,
			"the away card lists the %.0f h gap: %d snack gifts, %d lines" % [AWAY_H, gifts, lines.size()])
	soak.ok(not text.contains("died") and not text.contains("starv"), "the away card says nothing of loss")
	var again: Array = CareJournal.arrival([]).filter(func(l): return String(l).contains("saved you a snack"))
	soak.ok(again.is_empty(), "the next arrival starts from now")
