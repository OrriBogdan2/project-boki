extends RefCounted
## --ui-focus-check: UiFocus owns "who has the keys" (briefs/STATE_MACHINES.md M6).
##   1. nothing open: every combat key and movement reaches the hunter in the same frame
##   2. the backpack, map, talk bar, a drill, build mode and the pause menu each hold the keys: nothing gets through
##   3. closed again: the keys pass on the very next press
##   4. the Tab scoreboard is not a holder: it passes movement and combat
##   5. HUD windows exclude each other (map vs backpack) and closing one frees the keys
## Run with a temporary XDG_DATA_HOME.

var bad := 0
var m: Match
const KEYS := ["dash", "jump", "signature", "ultimate", "util1", "secondary"]

func ok(cond: bool, what: String) -> void:
	print("UIFOCUS %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	for i in 30:
		m.step(Match.DT)
	_open_close()
	_board()
	_exclusive()
	UiFocus.reset()
	print("UIFOCUS DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Presses every combat key and a move key on one frame; returns how many reached the hunter.
func _reach() -> int:
	m.pending_input.clear()
	var held := KEYS + ["right"]
	for a in held: Input.action_press(a)
	m._gather_input()
	for a in held: Input.action_release(a)
	var n := 0
	for k in ["dash", "jump", "sig", "util1", "ult", "sec"]:
		if m.pending_input.has(k): n += 1
	if (m.player.inp["move"] as Vector2).length() > 0.1: n += 1
	return n

func _open_close() -> void:
	ok(_reach() == 7, "no panel open: 6 combat keys and movement reach the hunter")
	m.hud.toggle_pack()
	ok(UiFocus.panel == UiFocus.PACK and _reach() == 0, "backpack open: nothing reaches the hunter")
	m.hud.toggle_pack()
	ok(UiFocus.keys_free() and _reach() == 7, "backpack closed: every key passes again")
	m.hud.full_map.open()
	ok(UiFocus.panel == UiFocus.MAP and _reach() == 0, "map open: nothing reaches the hunter")
	m.hud.close_map()
	ok(_reach() == 7, "map closed: every key passes again")
	UiFocus.chat = true
	ok(UiFocus.kind() == UiFocus.Kind.CHAT and _reach() == 0, "chat open eats the keys")
	UiFocus.chat = false
	ok(_reach() == 7, "chat closed passes the keys")
	UiFocus.train = true
	ok(UiFocus.kind() == UiFocus.Kind.TRAIN and _reach() == 0, "a drill running holds the keys")
	UiFocus.train = false
	UiFocus.build = true
	ok(UiFocus.kind() == UiFocus.Kind.BUILD and _reach() == 0, "build mode holds the keys")
	UiFocus.build = false
	Overlay.open_pause("home")
	ok(UiFocus.kind() == UiFocus.Kind.OVERLAY and _reach() == 0, "the pause menu holds the keys")
	Overlay.close()
	ok(UiFocus.keys_free() and _reach() == 7, "pause closed: every key passes again")

func _board() -> void:
	Input.action_press("scores")
	ok(UiFocus.keys_free() and _reach() == 7, "Tab scoreboard held: movement and combat still pass")
	Input.action_release("scores")

func _exclusive() -> void:
	m.hud.full_map.open()
	m.hud.toggle_pack()
	var pack_won: bool = UiFocus.panel == UiFocus.PACK and not m.hud.map_open() and m.hud.pack_open()
	ok(pack_won, "the backpack takes focus: the map steps aside")
	m.hud.full_map.open()
	var map_won: bool = UiFocus.panel == UiFocus.MAP and m.hud.map_open() and not m.hud.pack_open()
	ok(map_won, "the map takes it back: the backpack closes")
	m.hud.close_map()
	ok(UiFocus.keys_free(), "closing the last window frees the keys")
