extends RefCounted
## --hunter-unlock-check (alias --class-unlock-check): Hunter unlocks and mastery (docs/decisions/0005,
## content/rules/class_unlock.json, content/rules/hunter_viewer.json).
##   1. the data: 4 starters and a pick of 2, one challenge per Hunter with its tier, 3-5 mastery goals
##      each that mix kinds, every stat measurable, the viewer's kit moves
##   2. mastery rewards are cosmetic only; gliders change no handling
##   3. pick exactly 2 of exactly the 4 starters; challenge-only Hunters can't be picked at creation
##   4. challenge progress makes a Hunter ready (never open by itself); mastery counts per Hunter
##   5. the feats HunterFeats records from the combat signals
##   6. save migration keeps every Hunter a save had unlocked or played
##   7. character creation in the viewer, picking 2
##   8. the viewer cycling abilities on the real model, keys from the bindings
##   9. the Hunters screen: challenge progress, mastery, the glider pick, hold to unlock and the reveal
##  10. locked Hunters playable in the Arena (its Training dummy) and the practice picker
## With --shots-dir=<dir>: creation_pick2, hunters_screen, glider_pick, hold_unlock, reveal_burst and
## viewer_strip as PNGs. Prints HUNTERCHECK lines and "HUNTERCHECK DONE, n checks, failures: n".

const STARTERS := ["juggernaut", "gunslinger", "archer", "ashwick"]
const CHALLENGE_ONLY := ["ostra", "tender", "dolm"]
## Which stats count as which kind of goal (the owner's mix: kit feats, team play, exploration,
## extraction and Boki goals).
const GOAL_KINDS := {
	"kit": ["stuns", "roots", "slows", "burns", "multi3", "far_hits", "air_hits", "slams", "staggers",
			"lowhp_knocks", "knocks", "mobs"],
	"team": ["revives"],
	"exploration": ["chests", "rings"],
	"extraction": ["extracts", "close_out", "best_haul"],
	"boki": ["caught", "kin_hits", "merged_knocks"],
}
## Keys that would make a reward more than a look ("stat" in a goal is what it counts, not a reward).
const POWER_KEYS := ["hp", "health", "dmg", "damage", "speed", "cooldown", "cd", "perk", "ability", "rank",
		"armor", "power", "mult", "bonus", "level", "xp", "glide", "lift", "drag", "fall"]
## The only ways gameplay code may touch a glider skin: draw it, trail it, play its sound.
const GLIDER_CALLS := ["Gliders.mesh", "Gliders.trail", "Gliders.sound", "Gliders.equipped", "Gliders.LIST"]

var bad := 0
var n := 0
var main: Node
var shots := ""

func ok(cond: bool, what: String) -> void:
	n += 1
	print("HUNTERCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func shot(tree: SceneTree, file: String, frames := 25) -> void:
	if shots == "": return
	for i in frames: await tree.process_frame
	tree.root.get_texture().get_image().save_png("%s/%s.png" % [shots, file])

## A finished-expedition result for Game.apply_result, played as `arch`, with these match stats.
func result(arch: String, extracted: bool, stats := {}, extra := {}) -> Dictionary:
	var r := {"arch": arch, "extracted": extracted, "why": "extracted" if extracted else "knocked out", "knocks": 0,
			"kills": 0, "gems": 0, "seeds": {}, "stats": stats, "lvl": 1, "caught": [], "kin_runs": [], "tonics": 0}
	r.merge(extra, true)
	return r

func new_save(picked := []) -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	if not picked.is_empty():
		ClassUnlock.choose_starters(picked)
		var first := String(picked[0])
		Save.d["cls"] = Arch.weight(first)
		Save.d["arch"] = first
		Save.d["weapon"] = Arch.signature(first)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shots = a.substr(12)
	var tree := main.get_tree()
	if shots != "" and main.fade != null:
		main.fade.reveal(0.05)      # (the boot splash would cover the screenshots)
		for i in 20: await tree.process_frame
	_rules()
	_cosmetic_only()
	_gliders()
	_creation_rules()
	_challenges()
	_mastery()
	_feats()
	_migration()
	await _creation(tree)
	await _viewer(tree)
	await _home(tree)
	await _arena(tree)
	print("HUNTERCHECK DONE, %d checks, failures: %d" % [n, bad])
	tree.quit()

# ---------------------------------------------------------------- 1. the data
func _rules() -> void:
	ok(ClassUnlock.starters() == STARTERS, "exactly the 4 starters, by id: %s" % str(ClassUnlock.starters()))
	ok(ClassUnlock.picks_needed() == 2, "the creation pick is 2 of them")
	ok(CHALLENGE_ONLY.all(func(a): return not ClassUnlock.starters().has(a)),
			"%s are challenge-only" % str(CHALLENGE_ONLY.map(func(a): return Arch.name_of(a))))
	var stats: Dictionary = ClassUnlock.rules()["stats"]
	var no_challenge := Arch.ids().filter(func(a): return not _challenge_ok(String(a), stats))
	ok(no_challenge.is_empty(), "every Hunter has one challenge (a known stat, a target, one line); missing: %s"
			% str(no_challenge))
	ok(STARTERS.all(func(a): return ClassUnlock.tier(a) == "easy"), "an unpicked starter is an easy challenge")
	var others := Arch.ids().filter(func(a): return not STARTERS.has(a) and not CHALLENGE_ONLY.has(a))
	ok(others.all(func(a): return ClassUnlock.tier(String(a)) == "medium"), "the other Hunters are medium")
	var last_medium := 0
	for a in others: last_medium = maxi(last_medium, ClassUnlock.open_needed(String(a)))
	ok(CHALLENGE_ONLY.all(func(a): return ClassUnlock.tier(a) == "hard" and ClassUnlock.open_needed(a) > last_medium),
			"%s are hard and come last (they wait for other Hunters)" % str(CHALLENGE_ONLY))
	ok((ClassUnlock.rules()["unlock"] as Dictionary).values().all(func(c): return String(c["text"]).length() <= 60),
			"each challenge reads in one line")
	var counted: Array = []
	for kind in GOAL_KINDS: counted.append_array(GOAL_KINDS[kind])
	ok(stats.keys().all(func(k): return counted.has(String(k))),
			"every stat a goal can count is one the game measures (HunterFeats or the result)")
	var bad_mastery: Array = Arch.ids().filter(func(a): return not _mastery_ok(String(a), stats))
	ok(bad_mastery.is_empty(), "every Hunter has 3-5 mastery goals of 3 or more kinds, each with a reward; off: %s"
			% str(bad_mastery))
	ok(not stats.has("matches") and not stats.has("glide_s"), "no grind goals (play N matches)")
	ok(is_equal_approx(HoldUnlock.hold_s(), 1.6), "the hold is 1.6 s (%ss)" % HoldUnlock.hold_s())
	# the viewer's moves: every id in hunter_viewer.json is a kit move the animation knows
	var missing: Array = []
	var mv: Dictionary = HunterViewer.rules().get("moves", {})
	for a in mv:
		if not Arch.exists(String(a)): missing.append(String(a))
		for slot in mv[a]:
			for id in mv[a][slot]:
				if HunterViewer.move_len(String(id)) <= 0.0: missing.append("%s.%s:%s" % [a, slot, id])
	ok(missing.is_empty(),
			"every viewer move is a real kit move (HunterAnim.KMOVES / KMovesPair); missing: %s" % str(missing))

# ---------------------------------------------------------------- 2. cosmetic only
func _cosmetic_only() -> void:
	var kinds: Dictionary = ClassUnlock.rules()["reward_kinds"]
	ok(kinds.keys() == ["glider", "skin", "colourway", "emote", "title", "banner", "trail"],
			"reward kinds are looks only: %s" % str(kinds.keys()))
	var power_hits: Array = []
	_scan_power(ClassUnlock.rules()["mastery"], "mastery", power_hits)
	_scan_power(ClassUnlock.rules()["unlock"], "unlock", power_hits)
	ok(power_hits.is_empty(), "nothing in the progression data names a stat or ability: %s" % str(power_hits))
	var ids: Array = []
	var shape_ok := true
	for a in Arch.ids():
		for g in ClassUnlock.mastery(String(a)):
			var rw: Dictionary = g["reward"]
			shape_ok = shape_ok and rw.keys() == ["kind", "id", "name"] and kinds.has(String(rw["kind"]))
			ids.append("%s:%s" % [rw["kind"], rw["id"]])
	ok(shape_ok, "every reward is just {kind, id, name} of a cosmetic kind")
	var unique := {}
	for i in ids: unique[i] = true
	ok(unique.size() == ids.size(), "no reward is given twice")

## Collects every key under `node` that would change power (a stat, ability, perk or level).
func _scan_power(node: Variant, path: String, out: Array) -> void:
	if node is Dictionary:
		for k in node:
			if POWER_KEYS.has(String(k).to_lower()):
				out.append("%s.%s" % [path, k])
			_scan_power(node[k], "%s.%s" % [path, k], out)
	elif node is Array:
		for i in (node as Array).size():
			_scan_power(node[i], "%s[%d]" % [path, i], out)

func _gliders() -> void:
	var extra_keys: Array = []
	for g in Gliders.LIST:
		for k in g:
			if not Gliders.SKIN_KEYS.has(String(k)): extra_keys.append("%s.%s" % [g["id"], k])
	ok(extra_keys.is_empty(), "a glider skin only has look, sound and unlock keys (no handling): %s" % str(extra_keys))
	var reads: Array = _glider_reads("res://scripts/match") + _glider_reads("res://scripts/arch")
	reads += _glider_reads("res://scripts/combat")
	ok(reads.is_empty(), "no gameplay script reads a glider skin beyond its mesh, trail and sound: %s" % str(reads))
	var gl_text := FileAccess.get_file_as_string("res://scripts/core/gliders.gd")
	ok(RegEx.create_from_string("glide_(fall|speed|cap|drag|lift)|GLIDE_").search(gl_text) == null,
			"Gliders holds no glide numbers (they are the movement rules')")
	var mastery_gliders := Gliders.LIST.filter(func(g): return String(g.get("unlock", "")) == "mastery")
	var sourced := mastery_gliders.all(func(g): return _has_source(String(g["id"])))
	ok(mastery_gliders.size() >= 6 and sourced,
			"%d glider designs come from mastery, each from a goal" % mastery_gliders.size())
	var account := Gliders.LIST.filter(func(g): return String(g.get("unlock", "")).contains(":"))
	ok(account.size() >= 2 and account.all(func(g): return String(g.get("how", "")) != ""),
			"%d gliders come from account-wide challenges, each saying how" % account.size())
	var shapes := {}
	for g in Gliders.LIST: shapes[String(g["shape"])] = true
	ok(shapes.has("crane") and shapes.has("boki") and shapes.has("leaf") and shapes.has("kite"),
			"leaf, kite, paper crane and Boki-wing designs: %s" % str(shapes.keys()))
	new_save(["archer", "ashwick"])
	ok(not Gliders.owned("paper_crane") and not Gliders.equip("paper_crane") and Gliders.equipped() == "classic",
			"a mastery glider isn't yours before its goal")
	ok(Gliders.how("paper_crane").contains(Arch.name_of("archer")), "and says how: %s" % Gliders.how("paper_crane"))
	Game.apply_result(result("archer", true, {"rings": 8}))
	ok(Gliders.owned("paper_crane") and Gliders.equip("paper_crane") and Gliders.equipped() == "paper_crane",
			"%s's ring goal gives the Paper Crane, and it equips" % Arch.name_of("archer"))

## Lines in a folder's scripts that touch Gliders other than through GLIDER_CALLS.
func _glider_reads(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("%s/%s" % [dir_path, f])
		for line in text.split("\n"):
			if not line.contains("Gliders."):
				continue
			var stripped := line
			for call_name in GLIDER_CALLS: stripped = stripped.replace(call_name, "")
			if stripped.contains("Gliders."): out.append("%s: %s" % [f, line.strip_edges()])
	for sub in dir.get_directories():
		out.append_array(_glider_reads("%s/%s" % [dir_path, sub]))
	return out

# ---------------------------------------------------------------- 3. the creation pick rules
func _creation_rules() -> void:
	new_save()
	ok(ClassUnlock.needs_starters() and not ClassUnlock.all_open(), "a new save has to make its creation pick")
	ok(ClassUnlock.ready_count() == 0 and not ClassUnlock.can_unlock("thief"), "nothing can be unlocked before it")
	ok(not ClassUnlock.choose_starters(["archer"]), "1 Hunter is not a pick")
	ok(not ClassUnlock.choose_starters(["archer", "archer"]), "the same Hunter twice is not a pick")
	ok(not ClassUnlock.choose_starters(["archer", "juggernaut", "ashwick"]), "3 Hunters is not a pick")
	var outside := Arch.ids().filter(func(a): return not STARTERS.has(a))
	var refused := outside.all(func(a): return not ClassUnlock.choose_starters(["archer", String(a)]))
	ok(refused and ClassUnlock.needs_starters(), "no Hunter outside the 4 starters can be picked at creation")
	ok(CHALLENGE_ONLY.all(func(a): return not ClassUnlock.choose_starters([a, "juggernaut"])),
			"%s can never be picked at creation" % str(CHALLENGE_ONLY.map(func(a): return Arch.name_of(a))))
	ok(ClassUnlock.choose_starters(["gunslinger", "ashwick"]) and ClassUnlock.picks() == ["gunslinger", "ashwick"],
			"picking 2 starters works")
	ok(ClassUnlock.open_ids().size() == 2 and ClassUnlock.is_open("gunslinger") and ClassUnlock.is_open("ashwick"),
			"exactly those 2 are open (%s)" % str(ClassUnlock.open_ids()))
	ok(not ClassUnlock.choose_starters(["archer", "juggernaut"]) and ClassUnlock.open_ids().size() == 2,
			"the pick is made once")
	var locked := Arch.ids().filter(func(a): return not ClassUnlock.is_open(String(a)))
	ok(locked.all(func(a): return _locked_and_says(String(a))), "every other Hunter is locked and says its challenge")

# ---------------------------------------------------------------- 4. challenges
func _challenges() -> void:
	new_save(["archer", "ashwick"])
	ok(ClassUnlock.requirement("juggernaut").begins_with(ClassUnlock.challenge_text("juggernaut"))
			and ClassUnlock.requirement("juggernaut").contains("(0/"),
					"a locked Hunter shows its challenge with a counter: %s" % ClassUnlock.requirement("juggernaut"))
	var target := int(ClassUnlock.challenge("juggernaut")["target"])
	Game.apply_result(result("archer", false, {"slams": target - 1}))
	ok(ClassUnlock.status("juggernaut") == "progress", "part of the challenge: in progress")
	var out := Game.apply_result(result("ashwick", false, {"slams": 1}))
	ok(ClassUnlock.status("juggernaut") == "ready" and not ClassUnlock.is_open("juggernaut"),
			"the challenge done (any Hunter counts): ready, but nothing opens by itself")
	ok(int(out["class_unlock"]["new"]) == 1, "the results report it")
	var strip := ClassCard.results_strip(out)
	ok(_find_meta(strip, "hunter_unlock_ready") != null and _hunter_words(strip),
			"the results screen says a Hunter challenge is done, in Hunter words")
	strip.free()
	ok(ClassUnlock.unlock("juggernaut") and ClassUnlock.is_open("juggernaut"), "unlocking it (the hold's end) opens it")
	ok(not ClassUnlock.unlock("gunslinger"), "an unfinished challenge can't be unlocked")
	ClassUnlock.take_news()
	ok(ClassUnlock.take_news() == 0, "a ready unlock is announced once")
	# a hard one: done, but it waits until enough Hunters are open
	var tender_stat := String(ClassUnlock.challenge("tender")["stat"])
	Game.apply_result(result("archer", true, {}, {tender_stat: int(ClassUnlock.challenge("tender")["target"])}))
	ok(bool(ClassUnlock.challenge_progress("tender")["done"]) and ClassUnlock.status("tender") == "progress"
			and ClassUnlock.requirement("tender").contains("Hunters are open"),
					"a hard challenge done early still waits for %d open Hunters" % ClassUnlock.open_needed("tender"))
	var c := ClassUnlock.state()
	for a in ["gunslinger", "thief", "mage"]: (c["open"] as Array).append(a)
	ok(ClassUnlock.status("tender") == "ready", "with %d open it is ready" % ClassUnlock.open_ids().size())

# ---------------------------------------------------------------- 4b. mastery
func _mastery() -> void:
	new_save(["archer", "ashwick"])
	var g0: Dictionary = ClassUnlock.mastery("archer")[0]
	var stat := String(g0["stat"])
	ok(ClassUnlock.mastery_level("archer") == 0, "mastery starts at level 0")
	var out := Game.apply_result(result("ashwick", true, {stat: int(g0["target"])}))
	ok(ClassUnlock.mastery_level("archer") == 0, "playing another Hunter doesn't count for %s's mastery"
			% Arch.name_of("archer"))
	out = Game.apply_result(result("archer", true, {stat: int(g0["target"])}))
	ok(ClassUnlock.mastery_level("archer") == 1 and ClassUnlock.reward_earned("colourway", String(g0["reward"]["id"])),
			"playing it does: mastery level 1 and its %s" % g0["reward"]["name"])
	var mastered: Array = out["class_unlock"]["mastered"]
	ok(mastered.size() == 1 and String(mastered[0]["id"]) == "archer", "the results list the goal just done")
	var strip := ClassCard.results_strip(out)
	ok(_find_meta(strip, "mastery_done") != null, "and the results screen shows it")
	strip.free()
	var hp_before := float(Data.CLASSES[Arch.weight("archer")]["hp"])
	var def_before := JSON.stringify(Arch.def("archer"))
	Game.apply_result(result("archer", true, {"kin_hits": 99, "rings": 99}, {"downs": 1}))
	ok(ClassUnlock.mastery_level("archer") == ClassUnlock.mastery("archer").size(), "every goal done")
	ok(is_equal_approx(hp_before, float(Data.CLASSES[Arch.weight("archer")]["hp"]))
			and def_before == JSON.stringify(Arch.def("archer")), "full mastery changes no stats or kit data")
	var haul := {"downs": 1, "haul": [1, 2, 3]}
	ok(int(ClassUnlock.match_counts(result("dredge", true, {}, haul))["close_out"]) == 1
			and int(ClassUnlock.match_counts(result("dredge", true, {}, haul))["best_haul"]) == 3,
					"extraction goals count from the result (a close escape, the haul)")
	var best := ClassUnlock.account_stat("best_haul")
	ClassUnlock.tally(ClassUnlock.state()["stats"], {"best_haul": 0})
	ok(ClassUnlock.account_stat("best_haul") == best, "best_ stats keep the best expedition, not a total")

# ---------------------------------------------------------------- 5. the feats from the combat signals
func _feats() -> void:
	var m := Match.new()
	var feats := HunterFeats.new(m)
	var me := Hunter.new()
	var rival := Hunter.new()
	var rival2 := Hunter.new()
	var rival3 := Hunter.new()
	me.team = 0
	for r in [rival, rival2, rival3]: (r as Hunter).team = 1
	rival.pos = Vector3(20, 0, 0)
	feats._on_status(rival, "stun", me, 1.0)
	feats._on_status(rival, "burn", me, 1.0)
	feats._on_status(rival, "burn", me, 1.0)
	ok(int(me.stats.get("stuns", 0)) == 1 and int(me.stats.get("burns", 0)) == 1,
			"a stun and a burn on a rival count, a burn's ticks once (%s)" % str(me.stats))
	feats._on_status(me, "stun", me, 1.0)
	ok(int(me.stats.get("stuns", 0)) == 1, "stunning yourself doesn't")
	feats._on_hit(me, rival, 10.0, ["utility", "smash"])
	ok(int(me.stats.get("far_hits", 0)) == 1, "a hit from 20 m is a far hit")
	feats._on_hit(me, rival2, 10.0, ["utility", "smash"])
	feats._on_hit(me, rival3, 10.0, ["utility", "smash"])
	feats._on_hit(me, rival3, 10.0, ["utility", "smash"])
	ok(int(me.stats.get("multi3", 0)) == 1, "one ability hitting 3 enemies is one multi-hit")
	feats._on_hit(me, rival, 10.0, ["primary"])
	feats._on_hit(me, rival2, 10.0, ["primary"])
	feats._on_hit(me, rival3, 10.0, ["primary"])
	ok(int(me.stats.get("multi3", 0)) == 1, "weapon hits don't make a multi-hit")
	me.grounded = false
	feats._on_hit(me, rival2, 5.0, ["primary"])
	ok(int(me.stats.get("air_hits", 0)) == 1, "a hit while off the ground is an air hit")
	me.merge_st = {"t": 1.0}
	me.hp = me.max_hp * 0.3
	rival2.downed = true
	feats._watch_knock(me, rival2, false)
	ok(int(me.stats.get("merged_knocks", 0)) == 1 and int(me.stats.get("lowhp_knocks", 0)) == 1,
			"a knock while merged and under half health counts for both")
	for e in [me, rival, rival2, rival3, feats, m]: (e as Node).free()

# ---------------------------------------------------------------- 6. migration
func _migration() -> void:
	var old := Save.fresh()
	old.erase("classes")
	old["v"] = 5
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION and bool(old["classes"]["all"]),
			"a v5 save (every Hunter was unlocked then) upgrades to v%d keeping them all" % Save.VERSION)
	Save.d = old
	ok(ClassUnlock.all_open() and Arch.ids().all(func(a): return ClassUnlock.status(String(a)) == "open")
			and not ClassUnlock.needs_starters(), "all twelve open, no creation pick")
	# a v6 save from the first unlock flow: one starter, a free pick spent, and a Hunter played
	new_save()
	Save.d["classes"] = {"all": false, "starter": "thief", "open": ["thief", "dredge"], "early_used": 1, "told": 0,
			"reveal": [], "seen": ["thief"], "xp": 120}
	Save.d["arch"] = "mage"
	ok(ClassUnlock.is_open("thief") and ClassUnlock.is_open("dredge") and ClassUnlock.is_open("mage"),
			"an early-flow save keeps every Hunter it unlocked or played (%s)" % str(ClassUnlock.open_ids()))
	var c := ClassUnlock.state()
	ok(not c.has("early_used") and not c.has("xp") and c["picks"] == ["thief"] and not ClassUnlock.needs_starters(),
			"and drops the old free-pick and account XP keys")
	var path := "user://hunter_check_v5.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	var disk := Save.fresh()
	disk.erase("classes")
	disk["v"] = 5
	f.store_string(JSON.stringify(disk))
	f.close()
	Save.load_from(path)
	ok(bool(Save.d.get("classes", {}).get("all", false)), "loading an old save file from disk keeps everything")
	new_save(["archer", "juggernaut"])
	Game.apply_result(result("archer", true, {"stuns": 3}))
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(Save.d))
	f.close()
	Save.load_from(path)
	ok(not ClassUnlock.all_open() and ClassUnlock.open_ids().size() == 2 and ClassUnlock.hunter_stat("archer",
			"stuns") == 3, "a new save read back keeps its 2 Hunters and its counts")
	DirAccess.remove_absolute(path)

# ---------------------------------------------------------------- 7. character creation, in the viewer
func _pick_panel(hx: Node) -> Node:
	for ch in hx.bottom.get_children():
		if ch.has_meta("starter_pick") and not ch.is_queued_for_deletion(): return ch
	return null

func _go_button(hx: Node) -> Button:
	var go: Button = null
	for ch in hx.bottom.get_children():
		if ch is Button and not ch.is_queued_for_deletion(): go = ch
	return go

func _click_chip(hx: Node, want: String, tree: SceneTree) -> void:
	var chips: Array = []
	var panel := _pick_panel(hx)
	if panel: _collect_meta(panel, "starter_chip", chips)
	for c in chips:
		if String(c.get_meta("arch")) == want: (c as Button).pressed.emit()
	for i in 4: await tree.process_frame

func _creation(tree: SceneTree) -> void:
	new_save()
	Save.d["tutorial"] = {"intro": true}
	Save.d.erase("look")
	var hx = load("res://scripts/ui/hatch.gd").new()
	main.add_child(hx)
	for i in 8: await tree.process_frame
	ok(hx.stage == "class", "a new save starts character creation on the Hunter pick (stage %s)" % hx.stage)
	var panel: Node = _pick_panel(hx)
	var chips: Array = []
	if panel: _collect_meta(panel, "starter_chip", chips)
	var chip_ids := chips.map(func(c): return String(c.get_meta("arch")))
	ok(chip_ids == STARTERS, "a chip for each of the 4 starters and nothing else (%s)" % str(chip_ids))
	ok(CHALLENGE_ONLY.all(func(a): return not chip_ids.has(a)), "no challenge-only Hunter is offered")
	var go := _go_button(hx)
	ok(go != null and go.disabled, "Start waits for the pick")
	await _click_chip(hx, "archer", tree)
	await _click_chip(hx, "juggernaut", tree)
	await _click_chip(hx, "ashwick", tree)
	ok(hx.starter_picks == ["juggernaut", "ashwick"], "a third click keeps 2 picked (%s)" % str(hx.starter_picks))
	await _click_chip(hx, "juggernaut", tree)
	await _click_chip(hx, "archer", tree)
	ok(hx.starter_picks == ["ashwick", "archer"], "a click on a picked one takes it out")
	panel = _pick_panel(hx)
	var viewer: HunterViewer = panel.get_meta("viewer") if panel else null
	ok(viewer != null and viewer.id == "archer" and viewer.model != null, "the viewer shows the one last clicked")
	ok(panel != null and _no_weight(panel) and _hunter_words(panel), "the pick says Hunter with no weight labels")
	go = _go_button(hx)
	ok(go != null and not go.disabled and go.text.contains(Arch.name_of("ashwick"))
			and go.text.contains(Arch.name_of("archer")), "the button reads: %s" % (go.text if go else "?"))
	await shot(tree, "creation_pick2", 60)
	if go: go.pressed.emit()
	for i in 6: await tree.process_frame
	ok(ClassUnlock.picks() == ["ashwick", "archer"] and ClassUnlock.open_ids().size() == 2 and hx.stage == "create",
			"confirming opens those 2 and moves on to your look (stage %s)" % hx.stage)
	ok(Arch.of_save() == "ashwick", "the first pick is your expedition Hunter")
	hx.queue_free()
	for i in 3: await tree.process_frame

# ---------------------------------------------------------------- 8. the viewer cycling abilities
func _viewer(tree: SceneTree) -> void:
	new_save(["juggernaut", "archer"])
	var layer := CanvasLayer.new()
	layer.layer = 50
	main.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var host := CenterContainer.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = UI.theme()
	layer.add_child(host)
	var v := HunterViewer.make("juggernaut", Vector2(300, 360))
	host.add_child(v)
	for i in 4: await tree.process_frame
	v.set_process(false)       # (stepped by hand below)
	var want: Array = KitCard.slots_of("juggernaut").filter(func(x): return x != "r") + ["r"]
	ok(HunterViewer.slots_for("juggernaut") == want
			and Arch.ids().all(func(a): return not HunterViewer.slots_for(String(a)).has("x")),
					"no X slot while no Hunter has an X ultimate in data (nothing is bound to X)")
	var jd := Arch.def("juggernaut")
	jd["x"] = {"name": "(check)"}      # room for the X ultimate: a Hunter whose data gains one gets an X row before R
	var with_x := HunterViewer.slots_for("juggernaut")
	jd.erase("x")
	ok(with_x.size() == want.size() + 1 and with_x[-2] == "x" and with_x[-1] == "r",
			"an X ultimate in data shows as its own row, before R (%s)" % str(with_x))
	ok(v.slots == want, "the viewer shows every ability in order: %s" % str(v.slots))
	var keyed := true
	for b in v.rows:
		var slot := String(b.get_meta("slot"))
		var cap := "auto"
		if HunterViewer.SLOT_ACTIONS.has(slot):
			cap = Settings.key_cap(String(HunterViewer.SLOT_ACTIONS[slot]))
		keyed = keyed and _texts(b).has(cap)
	ok(v.rows.size() == want.size() and keyed, "each ability row has its key, from the player's bindings")
	ok(v.pivot.get_child_count() == 1 and v.model.get_parent() == v.pivot and v.vp.own_world_3d,
			"the real Hunter model stands in its own SubViewport")
	var seen: Array = []
	var moves_ok := true
	var spun := v.pivot.rotation.y
	var strip: Array = []
	v.slot_changed.connect(func(s): seen.append(s))
	var slot_s := float(HunterViewer.rules()["slot_s"])
	for k in want.size():
		var slot := v.current_slot()
		var mv := HunterViewer.moves_for("juggernaut", slot)
		# a little into the slot: the kit's own move is on the model
		for i in 6: v.tick(0.05)
		if not mv.is_empty() and v.anim.km_id != String(mv[0]):
			moves_ok = false
			print("  %s plays %s, wanted %s" % [slot, v.anim.km_id, mv[0]])
		if shots != "" and k in [1, 2, 3, 5]:
			v.tick(0.25)
			await tree.process_frame
			await tree.process_frame
			await tree.process_frame
			strip.append(_grab(tree, v))
		var left := slot_s - v.slot_t + 0.01
		while left > 0.0:
			v.tick(minf(0.1, left))
			left -= 0.1
	ok(seen.slice(0, want.size() - 1) == want.slice(1) and v.slot_i == 0,
			"it steps through each ability by itself and loops back (%s)" % str(seen))
	ok(moves_ok, "each ability drives the model with the kit's own move (KMOVES)")
	ok(absf(v.pivot.rotation.y - spun) > 0.5, "the model turns on its turntable")
	ok(v.cap_name.text == String(KitCard.slot_text("juggernaut", v.current_slot())["name"])
			and (v.cap_key.get_child(0) as Label).text != "", "the caption names the ability playing, with its key")
	(v.rows[3] as Button).pressed.emit()
	ok(v.slot_i == 3 and v.current_slot() == String(want[3]), "clicking an ability shows it at once")
	ok(_no_weight(v) and _hunter_words(v), "the viewer has no weight labels or class/hero wording")
	if shots != "" and strip.size() == 4:
		_save_strip(strip, "%s/viewer_strip.png" % shots)
	layer.queue_free()
	for i in 3: await tree.process_frame

func _grab(tree: SceneTree, c: Control) -> Image:
	var img := tree.root.get_texture().get_image()
	var r := Rect2i(c.get_global_rect())
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r)

func _save_strip(frames: Array, path: String) -> void:
	var w := 0
	var h := 0
	for f in frames:
		w += (f as Image).get_width() + 8
		h = maxi(h, (f as Image).get_height())
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.03, 0.03, 0.05))
	var x := 0
	for f in frames:
		var fi: Image = f
		fi.convert(Image.FORMAT_RGBA8)
		out.blit_rect(fi, Rect2i(Vector2i.ZERO, fi.get_size()), Vector2i(x, 0))
		x += fi.get_width() + 8
	out.save_png(path)

# ---------------------------------------------------------------- 9. the Hunters screen and the hold
func _home(tree: SceneTree) -> void:
	new_save(["archer", "ashwick"])
	# some play: Zedran's challenge done (ready to hold), Venator's half way, Pin's ring goal done
	var jt := int(ClassUnlock.challenge("juggernaut")["target"])
	var gt := int(ClassUnlock.challenge("gunslinger")["target"])
	Game.apply_result(result("archer", true, {"slams": jt, "far_hits": gt / 2, "rings": 8, "stuns": 5}))
	var hm = await main._hb_home()
	for i in 30: await tree.process_frame
	var items: Array = hm.hub_items().filter(func(it): return String(it[0]) == "hero")
	ok(not items.is_empty() and String(items[0][1]) == "Hunters", "the farm's bar button is Hunters")
	hm._close_panel()
	var ev := InputEventAction.new()
	ev.action = "hero"
	ev.pressed = true
	hm._unhandled_input(ev)
	await tree.process_frame
	ok(hm.panel_open == "Hunters", "J opens the Hunters screen (%s)" % hm.panel_open)
	var by := _statuses(hm)
	ok(by.size() == Arch.ids().size(), "every Hunter has a tile (%d)" % by.size())
	var mixed: bool = by.get("juggernaut", "") == "ready" and by.get("gunslinger", "") == "progress"
	ok(mixed and by.get("dredge", "") == "locked", "ready, in progress and locked tiles (%s)" % str(by))
	var sel := String(hm.get_meta("hunters_sel"))
	var hu: HoldUnlock = hm.get_meta("hold_unlock") if hm.has_meta("hold_unlock") else null
	ok(sel == "juggernaut" and hu != null and is_instance_valid(hu) and hu.id == sel,
			"the ready Hunter is shown first, with Hold to unlock (%s)" % sel)
	ok(_no_weight(hm.panel_host) and _hunter_words(hm.panel_host),
			"the Hunters screen has no weight labels and says Hunter, not class or hero")
	if hu == null:
		hm.queue_free()
		return
	# --- a partial hold cancels
	var viewer: HunterViewer = hm.get_meta("hunter_viewer")
	hu.set_process(false)
	viewer.set_process(false)
	hu.press()
	for i in int(HoldUnlock.hold_s() * 0.55 / 0.05):
		hu.tick(0.05)
		viewer.tick(0.05)
	ok(hu.k > 0.45 and hu.k < 0.7 and hu.slide >= 1.0 and viewer.power_k > 0.4,
			"holding: the bar slides out and fills (%.2f), the Hunter powers up (%.2f)" % [hu.k, viewer.power_k])
	ok(not ClassUnlock.is_open(sel), "half a hold unlocks nothing")
	await shot(tree, "hold_unlock", 4)
	var cancelled := [false]
	hu.cancelled.connect(func(_id): cancelled[0] = true)
	hu.release()
	for i in 20:
		hu.tick(0.05)
		viewer.tick(0.05)
	ok(cancelled[0] and hu.k == 0.0 and viewer.power_k == 0.0 and not ClassUnlock.is_open(sel),
			"letting go early cancels: the bar drains, nothing opens")
	# --- a full hold unlocks it and bursts
	var done := [false]
	hu.done.connect(func(_id): done[0] = true)
	hu.press()
	for i in int(HoldUnlock.hold_s() / 0.05) + 3:
		hu.tick(0.05)
		viewer.tick(0.05)
	ok(done[0] and hu.finished and ClassUnlock.is_open(sel), "a full hold unlocks %s" % Arch.name_of(sel))
	ok(viewer.burst_t >= 0.0, "the viewer bursts")
	var rv: ClassReveal = null
	for i in 90:
		await tree.process_frame
		for c in hm.get_children(): if c is ClassReveal and not c.is_queued_for_deletion(): rv = c
		if rv: break
	ok(rv != null and rv.id == sel, "then the reveal plays for it")
	if rv:
		ok(_texts(rv.root).any(func(t): return t == "NEW HUNTER") and _no_weight(rv.root),
				"the reveal says NEW HUNTER, with no weight label")
		if shots != "":
			await tree.create_timer(0.15).timeout
			tree.root.get_texture().get_image().save_png("%s/reveal_burst.png" % shots)
		rv._finish(false)
		for i in 6: await tree.process_frame
	ok(hm.panel_open == "Hunters", "Later goes back to the Hunters screen")
	ok(ClassReveal.maybe_show(hm) == null, "and the reveal never plays twice")
	# --- a locked Hunter: its challenge with progress, and its mastery list
	HomeClasses.open(hm, "gunslinger")
	await tree.process_frame
	var cb := _find_meta(hm.panel_host, "challenge_block")
	ok(cb != null and String(cb.get_meta("challenge_block")) == "gunslinger" and float(cb.get_meta("frac")) > 0.4,
			"a locked Hunter shows its challenge and progress bar")
	ok(_any_text(hm.panel_host, "%d/%d" % [gt / 2, gt]) and _any_text(hm.panel_host, "Easy challenge"),
			"with its counter and tier")
	var ml := _find_meta(hm.panel_host, "mastery_list")
	ok(ml != null and _count_meta(ml, "mastery_goal") == ClassUnlock.mastery("gunslinger").size(),
			"and its mastery goals with their rewards")
	await shot(tree, "hunters_screen", 50)
	# --- an open Hunter with a mastery glider earned: the glider pick
	HomeClasses.open(hm, "archer")
	await tree.process_frame
	ml = _find_meta(hm.panel_host, "mastery_list")
	ok(ml != null and int(ml.get_meta("level")) >= 1, "%s's mastery level shows (%s)" % [Arch.name_of("archer"),
			str(ml.get_meta("level")) if ml else "?"])
	var pick := _find_meta(hm.panel_host, "glider_pick")
	var crane: Button = null
	var chips: Array = []
	if pick: _collect_meta(pick, "glider", chips)
	for c in chips: if String(c.get_meta("glider")) == "paper_crane": crane = c
	ok(crane != null and not crane.disabled, "the glider pick offers the earned Paper Crane")
	if crane: crane.pressed.emit()
	await tree.process_frame
	ok(Gliders.equipped() == "paper_crane", "a click glides on it")
	await shot(tree, "glider_pick", 40)
	HomeClasses.open(hm, "dredge")
	await tree.process_frame
	pick = _find_meta(hm.panel_host, "glider_pick")
	chips = []
	if pick: _collect_meta(pick, "glider", chips)
	var patch := chips.filter(func(c): return String(c.get_meta("glider")) == "patchwork")
	ok(patch.size() == 1 and (patch[0] as Button).disabled and String((patch[0] as Button).tooltip_text).contains(
			Arch.name_of("dredge")), "an unearned mastery glider shows greyed with how to earn it")
	# play an open one from the screen; a locked one can't be
	var old_model: Node3D = hm.player
	HomeClasses._click(hm, sel)
	await tree.process_frame
	ok(Arch.of_save() == sel and hm.player != old_model,
			"an unlocked Hunter can be played from the screen; the farm hunter turns into it")
	HomeHero.pick(hm, "bulwark")
	ok(Arch.of_save() == sel, "a locked one can't be")
	hm._open_expedition()
	await tree.process_frame
	ok(_disabled_buttons(hm.panel_host).size() >= 1 and _no_weight(hm.panel_host),
			"the expedition panel picks a Hunter (locked ones disabled) with no weight tabs")
	hm._close_panel()
	var tr: HomeTraining = hm.training
	tr.try = {"arch": "bulwark", "cls": Arch.weight("bulwark")}
	tr.apply_try()
	tr.set_my_class()
	ok(Arch.of_save() == sel, "'Set as my Hunter' refuses a locked Hunter")
	tr.try = {}
	hm._close_panel()
	hm.queue_free()
	for i in 3: await tree.process_frame

func _statuses(hm: Node) -> Dictionary:
	var grid: GridContainer = hm.get_meta("classes_grid")
	var by := {}
	for c in grid.get_children(): by[String(c.get_meta("arch"))] = String(c.get_meta("class_status"))
	return by

# ---------------------------------------------------------------- 10. locked Hunters stay playable in the Arena
func _arena(tree: SceneTree) -> void:
	new_save(["archer", "juggernaut"])
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("ashwick"))
	m.set_process(false)
	var P: Hunter = m.player
	ok(P != null and P.arch == "ashwick" and m.arena != null, "the Arena starts you as a locked Hunter")
	var dummy_names: Array = m.hunters.filter(func(h): return h != P).map(func(h): return String(h.pname))
	ok(dummy_names.has("Training dummy") and not dummy_names.any(func(nm): return nm.contains("Heavy")),
			"the Arena's big dummy is the Training dummy (%s)" % str(dummy_names))
	m.arena.set_arch("dredge")
	ok(P.arch == "dredge", "and swaps to another locked one")
	m.arena.open_menu()
	await tree.process_frame
	var ml: Node = m.arena.menu_layer
	ok(ml != null and _no_weight(ml) and _texts(ml).any(func(t): return String(t).to_lower().begins_with("hunter")),
			"the Arena's L loadout lists Hunters with no weight letters")
	m.arena.close_menu()
	var holder := Control.new()
	main.add_child(holder)
	var grid := HeroGrid.build(holder, func(_a): pass, func(_a): pass, func(_a): pass, false)
	ok(grid.get_child_count() == Arch.ids().size() and _no_weight(holder) and _hunter_words(holder),
			"the practice picker shows all %d Hunters, no weight labels" % grid.get_child_count())
	holder.queue_free()
	var arch_before := String(Save.d.get("arch", ""))
	ok(not HeroGrid.save_pick("ashwick") and String(Save.d.get("arch", "")) == arch_before,
			"trying a locked Hunter in practice doesn't make it your expedition Hunter")
	m.queue_free()
	for i in 3: await tree.process_frame

# ---------------------------------------------------------------- helpers
func _challenge_ok(id: String, stats: Dictionary) -> bool:
	var c := ClassUnlock.challenge(id)
	var has_stat := stats.has(String(c.get("stat", "")))
	return has_stat and int(c.get("target", 0)) >= 1 and ClassUnlock.challenge_text(id) != ""

## 3-5 goals, each a known stat with a target and a reward, of at least 3 different kinds.
func _mastery_ok(id: String, stats: Dictionary) -> bool:
	var goals := ClassUnlock.mastery(id)
	if goals.size() < 3 or goals.size() > 5:
		return false
	var kinds := {}
	for g in goals:
		if not stats.has(String(g["stat"])) or int(g["target"]) < 1 or not g.has("reward"):
			return false
		for k in GOAL_KINDS:
			if (GOAL_KINDS[k] as Array).has(String(g["stat"])): kinds[k] = true
	return kinds.size() >= 3

func _has_source(glider_id: String) -> bool:
	return not ClassUnlock.reward_source("glider", glider_id).is_empty()

func _locked_and_says(id: String) -> bool:
	return ClassUnlock.status(id) == "locked" and ClassUnlock.requirement(id) != ""

func _count_meta(n: Node, key: String) -> int:
	var found: Array = []
	_collect_meta(n, key, found)
	return found.size()

func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label: out.append((n as Label).text)
	elif n is Button: out.append((n as Button).text)
	if n is Control and String((n as Control).tooltip_text) != "": out.append((n as Control).tooltip_text)
	for c in n.get_children(): out.append_array(_texts(c))
	return out

## No Light/Medium/Heavy label (a weight name on its own, as a tag, a suffix or "X weight") and no
## "weight" anywhere. Ability names that happen to use the word ("Heavy Shot") are not labels.
func _no_weight(n: Node) -> bool:
	var rx := RegEx.create_from_string("(?i)\\bweight\\b|^(light|medium|heavy)$|\\((light|medium|heavy)\\)"
			+ "|·\\s*[LMH]$|\\b(light|medium|heavy)\\s+(weight|class|frame)\\b")
	var hits: Array = []
	for t in _texts(n):
		for line in String(t).split("\n"):
			if rx.search(line.strip_edges()) != null: hits.append(line)
	if not hits.is_empty(): print("  weight label: %s" % str(hits))
	return hits.is_empty()

## Says Hunter: no "class", "classes", "hero" or "heroes" in what the player reads.
func _hunter_words(n: Node) -> bool:
	var rx := RegEx.create_from_string("(?i)\\b(class|classes|hero|heroes|archetypes?)\\b")
	var hits: Array = _texts(n).filter(func(t): return rx.search(String(t)) != null)
	if not hits.is_empty(): print("  old wording: %s" % str(hits))
	return hits.is_empty()

func _find_meta(n: Node, key: String) -> Node:
	if n.has_meta(key): return n
	for c in n.get_children():
		var f := _find_meta(c, key)
		if f: return f
	return null

func _collect_meta(n: Node, key: String, out: Array) -> void:
	if n.has_meta(key): out.append(n)
	for c in n.get_children(): _collect_meta(c, key, out)

func _any_text(n: Node, needle: String) -> bool:
	return _texts(n).any(func(t): return String(t).contains(needle))

func _disabled_buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button and (n as Button).disabled: out.append(n)
	for c in n.get_children(): out.append_array(_disabled_buttons(c))
	return out
