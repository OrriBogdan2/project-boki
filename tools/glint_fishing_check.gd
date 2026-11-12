extends RefCounted
## --glint-fishing-check: Glint Fishing (scripts/home/glint_fishing.gd, GARDEN_MODERN.md 4.2 game 4).
##   1. the windows: Focus sets the ears' warning (0.3 s at 0 to 0.8 s at 100), Power the band
##   2. seeded: the same seed and the same hands play the same session; another seed plays another
##   3. stats matter: a bot with a human reaction time hooks more with Focus 100 than Focus 0, and lands
##      more with Power 100 than Power 0
##   4. a Water lean doubles rare glints
##   5. the sign: the same list all day, sign_n distinct common catches, and it changes over the days;
##      a common glint always pays from the sign; an entry whose item is not in the catalog never bites
##   6. the machine: no move is refused, every session is five casts, early, late and empty-water casts
##      end as such, and the bot's sessions last about two minutes
##   7. settle: each catch is banked (items to the bag, snacks to the pantry), joy, energy, a memory line
##   8. on the rock: Glasswater has the rock and a session started there runs to a result card, its sounds once
##      per event (garden_sfx.gd): cast, bite warning, the reel loop per hook, catch or miss per cast; the Empty
##      holds the rod and casts through it (HunterRod poses via HomeVerbs) and puts it away at the end
## --glint-fishing-shots=<dir> makes a strip of one cast on the Empty instead (a real renderer).
## Never touches the real save.

const SESSIONS := 120
const DT := 1.0 / 30.0           # s per step
const REACT := [0.2, 0.9]        # s, the bot's reaction to the ears going up (a uniform roll)
const LOOK_S := 0.25             # s between the bot's looks at the line while reeling
const AIM_M := 0.15              # m, how close to its glint the bot lets go of the cast
const HOOK_GAIN := 0.15          # Focus 100 must hook at least this share more casts than Focus 0
const LAND_GAIN := 0.1           # Power 100 must land at least this share more reels than Power 0
const LENGTH_S := [60.0, 150.0]  # s, a bot session's average length must fall in here
const WAIT_S := 30.0             # s to wait for the zone to load

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FISH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--glint-fishing-shots="):
			await load("res://tools/glint_fishing_shots.gd").new().run(m, String(a).substr(22))
			return
	Save.no_write = true
	Save.d = Save.fresh()
	_windows()
	_seeded()
	_stats()
	_water()
	_sign()
	_machine()
	_settle()
	await _on_rock()
	print("FISH DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _rec(focus: int, power: int) -> Dictionary:
	var r := Save.new_kin("zapple", "Pip")
	Care.ensure(r)
	r["stats"]["focus"] = focus
	r["stats"]["power"] = power
	return r

## Plays one session with bot hands: aims at the best glint (rare first), hooks a human reaction time
## after the ears go up, and reels by looking at the line every LOOK_S. Returns the Run.
func _play(rec: Dictionary, seed: int) -> GlintFishing.Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var hands := RandomNumberGenerator.new()
	hands.seed = seed * 31 + 7
	var r := GlintFishing.Run.new(rec, 20000, rng)
	var react := 0.0
	var look := 0.0
	var hold := false
	var was := r.state
	while not r.over() and r.t < 400.0:
		if r.state != was and r.state == GlintFishing.Run.S.WAIT:
			react = hands.randf_range(REACT[0], REACT[1])
		was = r.state
		match r.state:
			GlintFishing.Run.S.AIM:
				var want: Dictionary = r.glints[0]
				for g in r.glints:
					if g["rare"] and not want["rare"]:
						want = g
				hold = not (r.held and absf(r.reach() - float(want["d"])) < AIM_M)
			GlintFishing.Run.S.WAIT:
				hold = r.ears() and r.state_t >= r.bite_t - r.warn + react
			GlintFishing.Run.S.REEL:
				look -= DT
				if look <= 0.0:
					look = LOOK_S
					hold = r.tension < 0.5
			_:
				hold = false
		r.step(DT, hold)
	return r

func _windows() -> void:
	var dull := GlintFishing.warn_s(_rec(0, 0))
	var sharp := GlintFishing.warn_s(_rec(100, 0))
	ok(is_equal_approx(dull, 0.3) and is_equal_approx(sharp, 0.8),
		"Focus 0 warns %.2f s, Focus 100 %.2f s" % [dull, sharp])
	var weak := GlintFishing.band(_rec(0, 0))
	var strong := GlintFishing.band(_rec(0, 100))
	ok(strong > weak and is_equal_approx(weak, 0.1), "Power widens the band: %.2f at 0, %.2f at 100" % [weak, strong])

func _seeded() -> void:
	var a := _play(_rec(50, 50), 4242)
	var b := _play(_rec(50, 50), 4242)
	var c := _play(_rec(50, 50), 4243)
	ok(str(a.casts) == str(b.casts) and is_equal_approx(a.t, b.t), "the same seed plays the same session")
	ok(str(a.casts) != str(c.casts) or not is_equal_approx(a.t, c.t), "another seed plays another")

## Share of casts on a glint that were hooked, and share of hooked ones landed.
func _rates(focus: int, power: int) -> Array:
	var on := 0
	var hooked := 0
	var landed := 0
	for i in SESSIONS:
		for c in _play(_rec(focus, power), 1000 + i).casts:
			if c["how"] != "miss":
				on += 1
			if c["how"] in ["caught", "slip"]:
				hooked += 1
			if c["how"] == "caught":
				landed += 1
	return [float(hooked) / maxi(1, on), float(landed) / maxi(1, hooked)]

func _stats() -> void:
	var low := _rates(0, 50)
	var high := _rates(100, 50)
	ok(high[0] - low[0] >= HOOK_GAIN, "Focus hooks more: %.2f at 0, %.2f at 100" % [low[0], high[0]])
	var weak := _rates(50, 0)
	var strong := _rates(50, 100)
	ok(strong[1] - weak[1] >= LAND_GAIN and weak[1] > 0.0,
		"Power lands more: %.2f at 0, %.2f at 100" % [weak[1], strong[1]])

func _rare_share(rec: Dictionary) -> float:
	var rare := 0
	var n := 0
	for i in SESSIONS * 4:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + i
		var r := GlintFishing.Run.new(rec, 20000, rng)
		for g in r.glints:
			n += 1
			rare += 1 if g["rare"] else 0
	return float(rare) / n

func _water() -> void:
	var dry := _rec(50, 50)
	var wet := _rec(50, 50)
	wet["lean"] = {"water": 12.0}
	var a := _rare_share(dry)
	var b := _rare_share(wet)
	ok(Evo.lean(wet)[0] == "water" and b / a > 1.7 and b / a < 2.3,
		"a Water lean doubles rare glints: %.3f to %.3f" % [a, b])

func _sign() -> void:
	var R := GlintFishing.rules()
	var today := GlintFishing.biting(20000)
	ok(str(today) == str(GlintFishing.biting(20000)) and today.size() == int(R["sign_n"]),
		"the same %d catches all day" % today.size())
	var ids := today.map(func(e): return e["id"])
	ok(ids.all(func(id): return ids.count(id) == 1) and today.all(func(e): return R["common"].has(e)),
		"they are distinct common catches")
	var days := {}
	for d in 10:
		days[str(GlintFishing.biting(20000 + d))] = true
	ok(days.size() > 1, "the sign changes over ten days (%d lists)" % days.size())
	var off_sign := 0
	for i in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = 300 + i
		var r := GlintFishing.Run.new(_rec(50, 50), 20000, rng)
		for g in r.glints:
			if not g["rare"] and not r.sign_list.has(g["catch"]):
				off_sign += 1
	ok(off_sign == 0, "a common glint always pays from the sign")
	var missing: Array = R["rare_list"].filter(func(e): return not GardenItems.has(String(e["id"])))
	ok(GlintFishing.rares().all(func(e): return GardenItems.has(String(e["id"])))
		and missing.all(func(e): return not GlintFishing.rares().has(e)),
		"items not in the catalog never bite (%s)" % ", ".join(missing.map(func(e): return e["id"])))

func _machine() -> void:
	var refused := 0
	var five := 0
	var total := 0.0
	for i in SESSIONS:
		var r := _play(_rec(50, 50), 500 + i)
		refused += r.refused
		five += 1 if r.over() and r.casts.size() == 5 else 0
		total += r.t
	ok(refused == 0 and five == SESSIONS, "no move refused, %d of %d sessions are five casts" % [five, SESSIONS])
	var avg := total / SESSIONS
	ok(avg >= LENGTH_S[0] and avg <= LENGTH_S[1], "a session lasts %.0f s on average" % avg)
	ok(_one("early") == "early", "a press before the ears spooks it")
	ok(_one("late") == "late", "no press after the bite and it gets away")
	ok(_one("miss") == "miss", "a cast on empty water plops")

## One cast played to end a given way; returns how it ended.
func _one(how: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var r := GlintFishing.Run.new(_rec(50, 50), 20000, rng)
	var R := GlintFishing.rules()
	var want := float(r.glints[0]["d"])
	if how == "miss":
		want = -1.0
		var x := float(R["near_m"])
		while want < 0.0 and x <= float(R["far_m"]):
			if r.glints.all(func(g): return absf(float(g["d"]) - x) > float(R["aim_m"]) + AIM_M):
				want = x
			x += 0.05
	while r.state == GlintFishing.Run.S.AIM and r.t < 10.0:
		r.step(DT, not (r.held and absf(r.reach() - want) < AIM_M))
	while r.state == GlintFishing.Run.S.WAIT:
		r.step(DT, how == "early" and r.state_t > 0.2 and not r.ears())
	return String(r.casts[-1]["how"]) if not r.casts.is_empty() else "none"

func _settle() -> void:
	Save.d = Save.fresh()
	var rec := _rec(80, 80)
	Care.change(rec, "joy", 40.0 - Care.need(rec, "joy"))
	Care.change(rec, "energy", 80.0 - Care.need(rec, "energy"))
	var r := _play(rec, 77)
	var got := r.caught()
	var res := GlintFishing.settle(r)
	var banked := 0
	for e in got:
		var store: Dictionary = Save.d["crops"] if String(e["kind"]) == "snack" else Save.d["items"]
		banked += 1 if int(store.get(e["id"], 0)) > 0 else 0
	ok(not got.is_empty() and banked == got.size() and res["got"] == got, "%d catches banked" % got.size())
	ok(Care.need(rec, "joy") > 40.0 and Care.need(rec, "energy") < 80.0, "joy up, energy down")
	ok(str(rec["memory"]).contains("glints"), "it remembers the session")

func _on_rock() -> void:
	Content.rules("farm_build")["base_mode"] = true
	var d := Save.fresh()
	for spec in [["zapple", "Pip"], ["cindle", "Ash"]]:
		(d["roster"] as Array).append(Save.new_kin(spec[0], spec[1]))
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	d["zones"]["glasswater"] = {"open": true}
	Save.d = d
	HomeLayout.ensure(d)
	Game.goto("home", {"zone": "glasswater"})
	var gw = await _arrived(Game.main.current)
	ok(gw != null and gw.hfish != null and is_instance_valid(gw.hfish.rock), "Glasswater has the fishing rock")
	if gw == null or gw.hfish == null or not is_instance_valid(gw.hfish.rock):
		return
	var gf: GlintFishing = gw.hfish
	ok(gf.find(Vector2(gf.rock.position.x, gf.rock.position.z)) == {"kind": "fishing"}, "the rock offers fishing")
	for k in gw.kins:
		k.erase("indoors")
		k["busy"] = false
	GardenSfx.heard.clear()
	gf.use()
	ok(gf.run != null, "a session starts with your partner")
	var r: GlintFishing.Run = gf.run
	var t := 0.0
	var posed := {}              # the Empty's rod poses seen (HomeVerbs: a one-shot over the held pose)
	while gf.run != null and t < float(GlintFishing.rules()["max_s"]) + 30.0:
		gf.holding = _hands(r)
		gf.tick(DT)
		t += DT
		posed[gw.verbs.act if gw.verbs.act != "" else gw.verbs.stance] = true
	ok(posed.has("wait") and posed.has("cast"), "the Empty holds the rod and casts (poses seen: %s)" % [posed.keys()])
	ok(gw.verbs.stance == "" and gw.verbs.act == "", "the rod is put away when fishing ends")
	ok(gf.run == null and is_instance_valid(gf.card), "it ends with a result card (%.1f s, bot hands)" % t)
	_sounds(r)
	Content.rules("farm_build")["base_mode"] = false

## The bot's hold for the rock's session (as _play, no reaction delay): aim at the first glint, hook when the
## ears go up, keep the line near the middle.
func _hands(r: GlintFishing.Run) -> bool:
	match r.state:
		GlintFishing.Run.S.AIM:
			return not (r.held and absf(r.reach() - float(r.glints[0]["d"])) < AIM_M)
		GlintFishing.Run.S.WAIT:
			return r.ears()
		GlintFishing.Run.S.REEL:
			return r.tension < 0.5
	return false

func _heard(sname: String) -> int:
	return int(GardenSfx.heard.get(sname, 0))

## The session's sounds (garden_sfx.gd), once per event: a cast per cast, the reel per glint hooked (and stopped
## after), the Boki's bite warning at least once per hook, a catch per glint landed and a miss per cast lost.
func _sounds(r: GlintFishing.Run) -> void:
	var n := r.casts.size()
	var landed := r.caught().size()
	var hooked := r.casts.filter(func(c): return c["how"] in ["caught", "slip"]).size()
	ok(_heard("fish_cast") == n, "sound: a cast per cast (%d)" % n)
	var ends := [_heard("fish_catch"), _heard("fish_miss")]
	ok(ends == [landed, n - landed], "sound: a catch per glint landed, a miss per cast lost (%s)" % [ends])
	var reels := _heard("fish_reel")
	ok(reels == hooked and not Sfx.loop_on("fish_reel"), "sound: the reel per hook, off after (%d)" % hooked)
	var bites := _heard("fish_bite")
	ok(bites >= hooked and bites <= n, "sound: the bite warning before every hook (%d, %d hooks)" % [bites, hooked])

func _arrived(was: Node):
	var t := 0.0
	while t < WAIT_S:
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
		var cur = Game.main.current
		if cur != was and is_instance_valid(cur) and cur.get("hway") != null and cur.get("player") != null \
				and cur.get("building") != true and cur.get("root_ui") != null and not Game.main.fade.covered:
			return cur
	return null
