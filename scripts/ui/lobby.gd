extends Control
## Online lobby: everyone who has the game open shows up here. Ready up, and whoever presses Start hosts.
## Opened from the Training Grounds duel ring (opts "duel") it is the duel line instead: no teams or
## Start, and the hunters in it pair off in the order they sort, two by two, into the duel room.

var opts := {}
var list_box: VBoxContainer
var status: Label
var ready_btn: Button
var start_btn: Button
var is_ready := false
var mode := "ffa"
var mode_btns := {}
var duel := false
var line_key := "lobby"      # the presence key that puts you in this list: "lobby", or "duel" on the duel line
var started := false

func setup(o: Dictionary) -> void:
	opts = o
	duel = bool(o.get("duel", false))
	line_key = "duel" if duel else "lobby"

func _ready() -> void:
	Sfx.play_music("title")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(center)
	var pb := UI.scroll_panel("Duel online" if duel else "Play online", 640, _back, "Back")
	var panel: PanelContainer = pb[0]
	var v: VBoxContainer = pb[1]
	center.add_child(panel)
	UI.pop_in(panel)
	status = panel.get_meta("sub")
	UI.subtitle(v, "Connecting...")
	v.add_child(UI.section("In the duel line" if duel else "Hunters here"))
	list_box = UI.vbox(6)
	list_box.add_child(UI.para("Looking for hunters with the game open...", UI.T_SMALL, UI.FAINT))
	v.add_child(list_box)
	v.add_child(UI.spacer(2))
	if duel:
		var how := "Your duel starts as soon as another hunter is in the line. To fight a friend, both of you"
		v.add_child(UI.para(how + " open Duel online from the Training Grounds duel ring."))
		_listen()
		return
	v.add_child(UI.section("Teams"))
	var modes := UI.hbox(2)
	var track := PanelContainer.new()
	track.add_theme_stylebox_override("panel", UiFrame.sunk(UI.WELL, UI.R_SMALL + 5).padded(3, 3))
	track.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	track.add_child(modes)
	for m in [["ffa", "Everyone for themselves"], ["duo", "Teams of 2"], ["trio", "Teams of 3"]]:
		var key: String = m[0]
		var b := UI.button(m[1], func(): mode = key; _refresh_modes())
		mode_btns[key] = b
		modes.add_child(b)
	v.add_child(track)
	v.add_child(UI.para("Empty spots are filled with bots, up to 4 squads. Whoever presses Start hosts the match and runs the monsters, so keep the game open and in front."))
	ready_btn = UI.button("I'm ready", _toggle_ready, 160, "check")
	UI.footer(v).add_child(ready_btn)
	start_btn = UI.footer_primary(v, "Start the match", _start, 220, "portal")
	_refresh_modes()
	_listen()

func _listen() -> void:
	Net.peers_changed.connect(_refresh)
	Net.message.connect(_on_msg)
	Net.start()
	await get_tree().create_timer(1.8).timeout
	_announce()
	_refresh()

## Esc goes back, like the X.
func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("menu") and not Overlay.is_open():
		get_viewport().set_input_as_handled()
		_back()

## Back to the farm, or from the duel line back to the Training Grounds.
func _back() -> void:
	if duel:
		Game.start_match(Match.arena_opts())
	else:
		Game.goto("home")

func _exit_tree() -> void:
	if duel and Net.my_presence.has("duel"):
		var p := Net.my_presence.duplicate()
		p.erase("duel")
		Net.set_presence(p)       # out of the line (into a duel, or back): nobody pairs with you any more
	if Net.peers_changed.is_connected(_refresh):
		Net.peers_changed.disconnect(_refresh)
	if Net.message.is_connected(_on_msg):
		Net.message.disconnect(_on_msg)

func _refresh_modes() -> void:
	for k in mode_btns:
		mode_btns[k].theme_type_variation = "SegOn" if k == mode else "Seg"

func _announce() -> void:
	var k := Save.active_kin()
	var arch := ClassUnlock.online_arch(Arch.of_save())      # (Settings > Demo > All masks open is offline only)
	var cls: String = opts.get("cls", Data.class_of_save())
	var weapon: String = Save.d.get("weapon", "")
	if arch != Arch.of_save():
		cls = Arch.weight(arch)
		weapon = Arch.signature(arch)
	Net.set_presence({"name": Save.d.get("name", "Hunter"), "cls": cls, "weapon": weapon, "arch": arch, "ready": is_ready,
		line_key: 1,
		"kin": {"species": k.get("species", "cindle"), "level": int(k.get("level", 1)), "name": k.get("name", "Boki"), "traits": k.get("traits", {}), "trust": float(k.get("trust", 50))}})

func _toggle_ready() -> void:
	is_ready = not is_ready
	ready_btn.text = "Ready" if is_ready else "I'm ready"
	ready_btn.theme_type_variation = "Chosen" if is_ready else ""
	_announce()

func _refresh() -> void:
	if not is_instance_valid(list_box):
		return
	for c in list_box.get_children():
		c.queue_free()
	var how: String = {"room": "to the room", "server": "to the Project Boki server"}.get(Net.mode, "on this computer")
	if Net.mode != "":
		status.text = "Connected %s. %d player%s here." % [how, Net.peers.size(), "" if Net.peers.size() == 1 else "s"]
	elif Net.deny_reason != "":
		status.text = Net.deny_reason
	else:
		status.text = "Connecting..."
	for id in Net.peers:
		var p: Dictionary = Net.peers[id]
		if not p.has(line_key):
			continue
		var row := UI.card(UI.CARD, 10, 12)
		var h := UI.hbox(12); row.add_child(h)
		h.add_child(UI.IconDot.new("paw", Data.KIN.get(p.get("kin", {}).get("species", "cindle"), Data.KIN["cindle"])["color"], 20.0))
		var nm := UI.label("%s%s" % [p.get("name", "Hunter"), "  (you)" if id == Net.me else ""], UI.T_BODY, UI.ACCENT_HI if id == Net.me else UI.INK, UI.semi)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(nm)
		var kin: Dictionary = p.get("kin", {})
		var info := UI.label("%s · %s" % [Arch.label(String(p.get("arch", ""))), Data.KIN.get(kin.get("species", "cindle"), Data.KIN["cindle"])["name"]], 14, UI.MUTED)
		info.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(info)
		var ready: bool = p.get("ready", false)
		if not duel:
			h.add_child(UI.tag("Ready" if ready else "Not ready", UI.GOOD if ready else UI.MUTED))
		list_box.add_child(row)
	if duel:
		_pair()

func _start() -> void:
	if Net.mode == "":
		return
	var squad: int = {"ffa": 1, "duo": 2, "trio": 3}[mode]
	var ids: Array = []
	for id in Net.peers:
		var p: Dictionary = Net.peers[id]
		if p.has("lobby") and (p.get("ready", false) or id == Net.me):
			ids.append(id)
	if not ids.has(Net.me):
		ids.append(Net.me)
	ids.sort()
	var roster := []
	for i in ids.size():
		var id: String = ids[i]
		var p: Dictionary = Net.peers.get(id, Net.my_presence)
		if id == Net.me:
			p = Net.my_presence
		roster.append({"peer": id, "team": i / squad, "name": p.get("name", "Hunter"), "arch": p.get("arch", ""), "cls": p.get("cls", "medium"), "weapon": p.get("weapon", ""), "kin": p.get("kin", {})})
	var teams := maxi(int(ceil(float(ids.size()) / squad)), int(ceil(Data.MATCH_PLAYERS / float(squad))))
	var d := {"mid": "%d" % (Time.get_ticks_msec() % 100000000), "seed": randi(), "host": Net.me, "roster": roster, "teams": mini(teams, Data.MATCH_PLAYERS), "squad": squad, "tier": int(opts.get("tier", 0))}
	Net.lobby_emit("start", d)
	_go(d)

## Who is in the duel line: you and every hunter whose presence says "duel".
static func duel_line(peers: Dictionary, me: String) -> Array:
	var line: Array = [me]
	for id in peers:
		if peers[id].has("duel") and not line.has(id):
			line.append(id)
	return line

## The duel line pairs off in id order, two by two; the first of each pair hosts and starts it.
static func duel_partner(line: Array, me: String) -> String:
	var ids := line.duplicate()
	ids.sort()
	var i := ids.find(me)
	return String(ids[i + 1]) if i >= 0 and i % 2 == 0 and i + 1 < ids.size() else ""

## The start message of a duel between this game (team 0, hosting) and `other` (team 1).
static func duel_start(me: Dictionary, other: Dictionary) -> Dictionary:
	var roster := []
	for p in [me, other]:
		roster.append({"peer": p["peer"], "team": roster.size(), "name": p.get("name", "Hunter"),
			"arch": p.get("arch", ""), "cls": p.get("cls", "medium"), "weapon": p.get("weapon", ""), "kin": p.get("kin", {})})
	var o := Match.duel_opts()
	return {"mid": "d%d" % (Time.get_ticks_msec() % 100000000), "seed": int(o["seed"]), "host": me["peer"],
		"roster": roster, "teams": 2, "squad": 1, "tier": 0, "duel": true}

## The match a duel start message opens: the duel room with both players in it.
static func duel_match(d: Dictionary) -> Dictionary:
	var o := Match.duel_opts()
	o.merge({"net": d, "teams": 2}, true)
	return o

func _pair() -> void:
	if started or Net.mode == "" or not Net.my_presence.has("duel"):
		return       # (not until this game has announced itself in the line)
	var other := duel_partner(duel_line(Net.peers, Net.me), Net.me)
	if other == "":
		return
	var mine: Dictionary = Net.my_presence.duplicate()
	mine["peer"] = Net.me
	var theirs: Dictionary = Net.peers[other].duplicate()
	theirs["peer"] = other
	var d := duel_start(mine, theirs)
	Net.lobby_emit("start", d)
	_go(d)

func _on_msg(topic: String, data, _from: String) -> void:
	if topic != "start" or typeof(data) != TYPE_DICTIONARY:
		return
	for r in data.get("roster", []):
		if String(r["peer"]) == Net.me:
			_go(data)
			return

func _go(d: Dictionary) -> void:
	if started:
		return
	started = true
	Save.d["cls"] = opts.get("cls", Save.d.get("cls", "medium"))
	if d.get("duel", false):
		Game.start_match(duel_match(d))
		return
	Game.start_match({"net": d, "seed": int(d["seed"]), "teams": int(d["teams"]), "squad": int(d["squad"]), "tier": int(d.get("tier", 0))})
