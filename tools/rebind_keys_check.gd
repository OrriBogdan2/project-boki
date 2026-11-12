extends RefCounted
## --keys-check --keys-part=rebind: every place a key is drawn follows the player's bindings (DECISIONS
## 2026-11-08 "more keybinds"). Each rebindable action gets a new key and an alternate, then:
##   1. Settings: key_cap / key_caps / InputMap / the saved bindings all read the new keys
##   2. a match: the ability bar's key caps, RecastCue's "<KEY> AGAIN" and the hunter / Boki tooltips
##   3. the tutorial: every step's line, detail, strip key cap and scout hint, and the Training Grounds rows
##   4. loading tips, tokens and the kit card's tile caps
##   5. a static sweep over player-facing text in content/ and scripts/ for a default key named in words
##      ("Press E", "(Shift)", "RMB", "right click") instead of read from Settings.key_cap
## The new keys are F-keys, so a default letter still in a text is a hard-coded key.

const ABILITY_BAR := {"sec": "secondary", "dash": "dash", "k1": "signature", "x": "hunter_ult", "r": "ultimate",
	"throw": "throw", "base": "base", "gear0": "gear1", "gear1": "gear2"}
const NAMED := ["fire", "secondary", "signature", "hunter_ult", "dash", "gear1", "ultimate", "throw", "crouch",
	"whistle", "rotate", "interact"]
const TILES := {"dash": "dash", "lmb": "fire", "rmb": "secondary", "e": "signature", "r": "ultimate", "x": "hunter_ult"}
## Texts that name a key on purpose: the Controls page's own mouse-button names, and mouse gestures
## that are not actions (build mode's click and rotate, the Boki box and the map's right click).
const STATIC_OK := ["scripts/core/settings.gd", "scripts/ui/build_keys.gd", "scripts/ui/kinbox_view.gd",
	"scripts/ui/full_map.gd"]
## JSON that holds tuning and footage notes, not text a player reads.
const JSON_SKIP := ["content/dash_flow", "content/rules/kit_parity.json", "content/rules/dash_feel.json",
	"content/rules/heart.json", "content/rules/garden_zones.json"]
const NOTE_KEYS := ["doc", "note", "notes", "source", "evidence", "why", "aug_why"]
## A default key named in words: "Press E", "(Shift)", "on RMB", "right click", "LMB".
const KEYS_RX := "(?:E|Q|R|X|G|F|V|Shift|Space|Ctrl|LMB|RMB)"
const STALE := "(?i:\\b(?:press|hold|tap|release|click)\\s+(?:the\\s+)?)" + KEYS_RX + "\\b|\\(" + KEYS_RX + "\\)" \
		+ "|\\b(?:on|with|using|use|via)\\s+" + KEYS_RX + "\\b|\\bMMB\\b|(?i:\\b(?:right|left)[- ]click\\b)"

var host
var main: Node
var stale: RegEx

func ok(label: String, cond: bool, info := "") -> void:
	host.ok("rebind: " + label, cond, info)

## A pass when `bad` is empty; the first few entries are the failure's info.
func none(label: String, bad: Array) -> void:
	ok(label, bad.is_empty(), str(bad.slice(0, 5)))

func run(h, main_node: Node) -> void:
	host = h
	main = main_node
	stale = RegEx.create_from_string(STALE)
	Settings.reset_all()
	_rebind_all()
	await _match()
	await _tutorial()
	_loading()
	_static_text()
	Settings.reset_all()

func _key(k: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	return e

func _cap_of(k: int) -> String:
	return OS.get_keycode_string(k).to_upper()

# ------------------------------------------------------------------ 1. the bindings
func _rebind_all() -> void:
	for i in NAMED.size():
		Settings.rebind(NAMED[i], _key(KEY_F1 + i), 0)
		Settings.rebind(NAMED[i], _key(KEY_F13 + i), 1)
	var bad: Array = []
	for i in NAMED.size():
		var a: String = NAMED[i]
		var want := "%s / %s" % [_cap_of(KEY_F1 + i), _cap_of(KEY_F13 + i)]
		var evs := InputMap.action_get_events(a)
		var held := evs.size() == 2 and (evs[0] as InputEventKey).physical_keycode == KEY_F1 + i
		if Settings.key_cap(a) != _cap_of(KEY_F1 + i) or Settings.key_caps(a) != want or not held:
			bad.append("%s: %s | %s | %d events" % [a, Settings.key_cap(a), Settings.key_caps(a), evs.size()])
	none("LMB, RMB, E, R, Shift, Q, X, G, crouch, whistle, rotate, interact take a new key and an alternate", bad)
	var saved := Settings.v["keys"] as Dictionary
	ok("and the bindings are saved", NAMED.all(func(a): return saved.has(a) and (saved[a] as Array).size() == 2))
	var rest := 0
	bad.clear()
	for a in Settings.ACTIONS:
		if a[0] in NAMED: continue
		Settings.rebind(a[0], _key(KEY_F1 + rest % 12), 0)
		Settings.rebind(a[0], _key(KEY_F13 + rest % 12), 1)
		if Settings.key_cap(a[0]) != _cap_of(KEY_F1 + rest % 12) or InputMap.action_get_events(a[0]).size() != 2:
			bad.append(a[0])
		rest += 1
	none("every other action takes a key and an alternate too (%d)" % rest, bad)

# ------------------------------------------------------------------ 2. a match
func _redraw(m: Match) -> void:
	TextCache.seen.clear()
	TextCache.recording = true
	for i in 12:
		m.hud.c.queue_redraw()
		m.hud.panels.queue_redraw()
		await main.get_tree().process_frame
	TextCache.recording = false

func _stale_in(texts: Array) -> Array:
	return texts.filter(func(t): return stale.search(String(t)) != null)

func _match() -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 1, "tier": 0, "seed": 5, "no_drop": true})
	for i in 60: m.step(1.0 / 60.0)
	var P: Hunter = m.player
	P.lvl = int(Hunter.ULT_AT[0])
	HudSlot.shown_keys.clear()
	await _redraw(m)
	var wrong: Array = []
	for id in HudSlot.shown_keys:
		if ABILITY_BAR.has(id) and String(HudSlot.shown_keys[id]) != Settings.key_cap(ABILITY_BAR[id]):
			wrong.append("%s %s" % [id, HudSlot.shown_keys[id]])
	var drawn: Array = HudSlot.shown_keys.keys()
	ok("the ability bar shows the new keys (%s)" % [drawn], wrong.is_empty() and drawn.size() >= 5, str(wrong))
	ok("the dash slot shows %s" % _cap_of(KEY_F5), String(HudSlot.shown_keys.get("dash", "")) == _cap_of(KEY_F5))
	_recast_keys()
	P.ak.cue["w"] = RecastCue.window("e", 2.0, 3.0, P.pos)
	await _redraw(m)
	var again: Array = TextCache.seen.filter(func(t): return String(t).contains("AGAIN"))
	ok("the recast label is drawn with the Utility key", again.has("%s AGAIN" % _cap_of(KEY_F3)), str(again))
	P.ak.cue.erase("w")
	var texts: Array = TextCache.seen.duplicate()
	for id in ["sec", "k1", "r", "dash"]:
		for line in m.hud._tip_lines(id, P): texts.append(String(line[0]))
	none("no hunter slot text or tooltip names a default key (%d texts)" % texts.size(), _stale_in(texts))
	m.free()

func _recast_keys() -> void:
	var bad: Array = []
	for slot_id in RecastCue.KEYS:
		var cap := Settings.key_cap(RecastCue.KEYS[slot_id])
		if RecastCue.key_of(slot_id) != cap or not cap.begins_with("F"): bad.append("%s %s" % [slot_id, cap])
	none("RecastCue's '<KEY> AGAIN' reads the bound key on every slot", bad)

# ------------------------------------------------------------------ 3. the tutorial
func _tutorial() -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	var tu: Tutorial = m.tut
	var texts: Array = []
	var off: Array = []
	var capped := 0
	for i in Tutorial.steps().size():
		tu.step = i
		tu._words()
		texts.append_array([tu.text, tu.detail, tu.scout_hint()])
		if Tutorial.KEYS.has(tu.id()) and tu.id() != "land":
			capped += 1
			if tu.key_cap != Settings.key_cap(Tutorial.KEYS[tu.id()]): off.append(tu.id())
	tu.step = 0
	tu._words()
	ok("the move step's strip cap is the bound move keys ('%s')" % tu.key_cap,
			tu.key_cap == tu._wasd() and tu.key_cap.begins_with("F"))
	ok("the strip's key cap is the bound key on %d steps" % capped, capped > 0 and off.is_empty(), str(off))
	for row in m.train_rows(): texts.append(String(row[1]))
	none("tutorial lines, details, hints, training rows name no default key (%d)" % texts.size(), _stale_in(texts))
	m.free()

# ------------------------------------------------------------------ 4. loading tips, tokens, kit card
func _loading() -> void:
	var texts: Array = []
	for tip in load("res://scripts/ui/loading.gd").TIPS: texts.append(Settings.fill_keys(String(tip)))
	none("loading tips name no default key (%d tips)" % texts.size(), _stale_in(texts))
	var sample := ["Press E again", "Hold Shift to aim", "Dash (Shift)", "on RMB", "your right click"]
	var fine := ["Press F5 again", "hold F13", "F2 AGAIN", "Press it again"]
	ok("the sweep's pattern catches the old wording and not a rebound key",
			sample.all(func(t): return stale.search(t) != null) and fine.all(func(t): return stale.search(t) == null))
	ok("the kit card's tile caps follow the bindings",
			TILES.keys().all(func(k): return KitCard._cap(k) == Settings.key_cap(TILES[k])))
	ok("no loading tip leaves a {token} unfilled", not texts.any(func(t): return String(t).contains("{")))
	var moved := Settings.fill_keys("{jump} {crouch} {interact} {util1}")
	var caps: Array = ["jump", "crouch", "interact", "util1"].map(func(a): return Settings.key_cap(a))
	ok("tokens fill from the bindings ('%s')" % moved, moved == " ".join(caps))

# ------------------------------------------------------------------ 5. the static sweep
func _files(dir: String, ext: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext): out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_files(dir.path_join(d), ext, out)

func _strings(v, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Array:
		for x in v: _strings(x, out)
	elif v is Dictionary:
		for k in v:
			if not String(k).begins_with("_") and not String(k) in NOTE_KEYS: _strings(v[k], out)

func _static_text() -> void:
	var hits: Array = []
	var jsons: Array = []
	_files("res://content", ".json", jsons)
	for f in jsons:
		if JSON_SKIP.any(func(s): return String(f).begins_with("res://" + s)): continue
		var strs: Array = []
		_strings(JSON.parse_string(FileAccess.get_file_as_string(f)), strs)
		for s in _stale_in(strs): hits.append("%s: %s" % [String(f).substr(6), String(s).left(60)])
	none("no JSON text names a default key (%d files)" % jsons.size(), hits)
	var gds: Array = []
	_files("res://scripts", ".gd", gds)
	var lit := RegEx.create_from_string("\"(?:[^\"\\\\\\n]|\\\\.)*\"")
	hits.clear()
	for f in gds:
		var rel := String(f).substr(6)
		if rel in STATIC_OK or rel == "scripts/main.gd": continue
		var ln := 0
		for line in FileAccess.get_file_as_string(f).split("\n"):
			ln += 1
			if line.strip_edges().begins_with("#"): continue
			for mt in lit.search_all(line):
				if stale.search(mt.get_string()) != null: hits.append("%s:%d %s" % [rel, ln, mt.get_string().left(50)])
	none("no script text names a default key (%d files)" % gds.size(), hits)
