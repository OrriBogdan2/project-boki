extends Node
## Online play over the artifact's room (or a BroadcastChannel between browser tabs when testing).
## Each player's game owns its own hunter and kin; the host's game owns monsters, bots and loot.
## Owners send compact snapshots; anyone who hits something they don't own sends the hit to its owner.
## On desktop the same messages go through the Project Boki relay server instead (net_enet.gd,
## scripts/server/relay.gd). The launcher passes `-- --server=host:port --token=<discord token>`.

const VERSION := "0.25.1"        # online play only matches players on the same version; bump on network changes (0.13.0: gear wdrop carries kind/rarity/id, 0.14.0: the "carry" and "zone" events, 0.15.0: the kin snapshot carries its rest seconds; merge augments, 0.16.0: the kit move id rides the hunter snapshot; perk orbs "odrop"/"otake", 0.17.0: a merge release lands the Boki beside you pumped with a 6s rest instead of draining it on your shoulder, and the hunter gets an afterglow, 0.18.0: Boki loss: the "guard" event (a guarding Boki's uid and record), "caught" carries the owner, "gdrop", kcmd "unbond"; a carried Boki rides its carrier's position, 0.19.0: the host re-sends live perk orbs on join; the run level on the hunter snapshot; chest-key carrier flags and the Shrubling state on the monster snapshot, 0.19.1: ext/equal-loadout's GripNet fields, 0.20.0: revive beacons run online with the "bcn" event, 0.21.0: a squad ping ("sping") carries its kind, 0.22.0: the first GitHub Release for the launcher, Nov 5; 0.23.0+: one release per merge batch; 0.24.0: the READY-queue merge of Nov 6, 0.24.1: still title backdrop, 0.25.0: the pre-match lobby: its "pick" and "chat" topics, the roster carries each hunter's arch, 0.24.4: online deaths drop a deathbox: the "box", "brev", "back" and "lost" events; lobby pick turns: the "loaded" topic, "pick" carries "final"; the 2x Hollow Crown (a 305 m map every peer builds from its JSON, its winding sky train) and 30-hunter expeditions, 0.24.5: Limited Ways Out: the "ht" event carries the Heart state enum, early/final squads, ring progress, rush and "take"; the exit list (and its "xc" index) is outposts only, no "key" pickups or rift keys; "xc" "seat" mirrors the quest seats, 0.25.1: rejoin: the hello and join carry a rejoin token, the welcome hands back the player's own snapshot, net ids are the relay's own)

signal peers_changed
signal message(topic: String, data, from: String)

var mode := ""                # "" offline, "room" or "tabs"
var me := ""
var peers := {}               # peer id -> presence dict
var my_presence := {}
var in_match := false
var host := ""
var match_name := ""
var m: Node = null            # the Match while online
var out_hits: Array = []
var out_events: Array = []
var send_t := 0.0
var host_send_t := 0.0
var seen := {}                # nid -> last time we heard about it
var _msg_cb = null
var _peers_cb = null
var started := false
var enet: NetEnet = null      # desktop connection to the relay
var server_addr := ""         # "host:port" of the relay (desktop)
var token := ""               # Discord access token from the launcher
var deny_reason := ""         # why the server refused us, for the lobby to show
## Rejoin (docs/decisions/0022-rejoin.md): the match this game is in is kept in REJOIN_FILE, so after a crash
## or a lost connection the title can offer it back while the relay still holds the Hunter.
const REJOIN_FILE := "user://rejoin.json"
const REJOIN_S := 90.0        # s the relay holds a dropped Hunter (RelayServer.HOLD_S)
const REJOIN_SEEN_S := 5.0    # s between refreshes of the file's last-seen time while in a match
var rejoin := {}              # {server, tok, start (the lobby's start message), seen (unix s)}
var rejoining := false        # the next hello asks for the Hunter back
var back: Array = []          # our Hunter's and Boki's snapshot the relay handed back, until the match uses them
var _seen_t := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--server="): server_addr = a.substr(9)
		if a.begins_with("--token="): token = a.substr(8)
	if server_addr == "":
		server_addr = OS.get_environment("BOKI_SERVER")
	var saved = null
	if FileAccess.file_exists(REJOIN_FILE):
		saved = JSON.parse_string(FileAccess.get_file_as_string(REJOIN_FILE))
	if typeof(saved) == TYPE_DICTIONARY and String(saved.get("server", "")) == server_addr:
		rejoin = saved

## Online play is possible here: the browser room, or a relay server on desktop.
func available() -> bool:
	return Bridge.net_available() or native_available()

func native_available() -> bool:
	return not OS.has_feature("web") and server_addr != ""

func online() -> bool:
	return in_match and mode != ""

func start() -> void:
	if started:
		return
	if not Bridge.net_available():
		if native_available():
			_start_native()
		return
	started = true
	_msg_cb = Bridge.make_callback(_on_js_msg)
	_peers_cb = Bridge.make_callback(_on_js_peers)
	var p = Bridge.js.netStart(_msg_cb, _peers_cb)
	# netStart is async on the page; ask who we are a moment later
	await get_tree().create_timer(1.5).timeout
	mode = "room" if Bridge.js.hasRoom() else "tabs"
	me = str(Bridge.js.whoami())

func set_presence(d: Dictionary) -> void:
	my_presence = d
	if enet:
		enet.send({"k": "pres", "d": d})
	elif Bridge.js:
		Bridge.js.presence(JSON.stringify(d))

func lobby_emit(topic: String, d) -> void:
	if enet:
		enet.send({"k": "emit", "t": topic, "d": d})
	elif Bridge.js:
		Bridge.js.emit(topic, JSON.stringify(d))

# ------------------------------------------------------------------ desktop relay
func _start_native() -> void:
	started = true
	deny_reason = ""
	var parts := server_addr.rsplit(":", true, 1)
	var host_name := parts[0]
	var port := int(parts[1]) if parts.size() > 1 else 7777
	enet = NetEnet.new()
	enet.name = "Enet"
	add_child(enet)
	enet.got.connect(_on_enet)
	enet.closed.connect(_on_enet_closed)
	if enet.open(host_name, port) != OK:
		_on_enet_closed("Couldn't open a connection to %s." % server_addr)
		return
	# say hello once the line is up
	for i in 100:
		if enet == null: return
		if enet.connected: break
		await get_tree().create_timer(0.1).timeout
	if enet and enet.connected:
		var hi := {"k": "hello", "ver": VERSION, "tok": token, "name": Save.d.get("name", "Hunter")}
		if rejoining:
			hi["rj"] = rejoin["tok"]
		enet.send(hi)

func _on_enet(d: Dictionary) -> void:
	match String(d.get("k", "")):
		"welcome":
			me = String(d.get("me", ""))
			mode = "server"
			back = d.get("back", [])
			if not my_presence.is_empty():
				enet.send({"k": "pres", "d": my_presence})
			peers_changed.emit()
		"deny":
			deny_reason = String(d.get("why", "The server refused the connection."))
			peers_changed.emit()
		"peers":
			_on_js_peers([JSON.stringify(d)])
		"msg":
			_on_js_msg([JSON.stringify(d)])

func _on_enet_closed(why: String) -> void:
	if deny_reason == "":
		deny_reason = why
	mode = ""
	started = false
	peers.clear()
	if enet:
		enet.queue_free()
		enet = null
	if in_match and m and is_instance_valid(m) and m.has_method("net_lost"):
		m.net_lost()
	peers_changed.emit()

func _on_js_peers(args) -> void:
	var parsed = JSON.parse_string(str(args[0]))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	me = str(parsed.get("me", me))
	peers.clear()
	for p in parsed.get("peers", []):
		peers[str(p["id"])] = p["p"]
	peers_changed.emit()

func _on_js_msg(args) -> void:
	var parsed = JSON.parse_string(str(args[0]))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var topic: String = parsed.get("t", "")
	var from: String = str(parsed.get("f", ""))
	var data = parsed.get("d", null)
	if topic in ["st", "hit", "ev"]:
		if m and is_instance_valid(m) and in_match:
			m.net_receive(topic, data, from)
		return
	message.emit(topic, data, from)

# ------------------------------------------------------------------ match
func begin_match(name: String, host_peer: String, match_node: Node, start_msg := {}) -> void:
	match_name = name
	host = host_peer
	m = match_node
	in_match = true
	out_hits.clear(); out_events.clear(); seen.clear()
	if enet:
		if not rejoining:
			# not randi(): the match seeds the global stream with its shared seed, so every player would roll the same
			var tok := Crypto.new().generate_random_bytes(16).hex_encode()
			rejoin = {"server": server_addr, "tok": tok, "start": start_msg}
		rejoining = false
		_save_rejoin()
		enet.send({"k": "join", "room": name, "rj": rejoin["tok"]})
	elif Bridge.js:
		Bridge.js.joinMatch(name)

func end_match() -> void:
	# leaving on purpose gives the slot up; a lost connection keeps the file so the title can offer it
	if enet and mode != "":
		forget_rejoin()
	flush()
	in_match = false
	m = null
	if enet:
		enet.send({"k": "leave"})
	elif Bridge.js:
		Bridge.js.leaveMatch()

func is_host() -> bool:
	return me == host

func owner_of(nid: String) -> String:
	# player-owned ids look like "P<peer>" and "P<peer>k"; everything else belongs to the host
	if nid.begins_with("P"):
		return nid.substr(1).trim_suffix("k")
	return host

func owns(nid: String) -> bool:
	return owner_of(nid) == me

func hit(target_nid: String, d: Array) -> void:
	out_hits.append([target_nid] + d)

func event(e: Array) -> void:
	out_events.append(e)

func _emit(topic: String, d) -> void:
	if enet:
		enet.send({"k": "memit", "t": topic, "d": d}, topic == "st")
	elif Bridge.js:
		Bridge.js.matchEmit(topic, JSON.stringify(d))

func flush() -> void:
	if out_hits.size() > 0:
		_chunks("hit", out_hits)
		out_hits = []
	if out_events.size() > 0:
		_chunks("ev", out_events)
		out_events = []

## Splits a list into messages under the 4KB limit. A header, if given, starts every message.
func _chunks(topic: String, items: Array, header = null) -> void:
	var cur: Array = [] if header == null else [header]
	var size := 40
	for it in items:
		var s := JSON.stringify(it).length() + 1
		if size + s > 3600 and cur.size() > (0 if header == null else 1):
			_emit(topic, cur)
			cur = [] if header == null else [header]
			size = 40
		cur.append(it); size += s
	if cur.size() > (0 if header == null else 1):
		_emit(topic, cur)

# ------------------------------------------------------------------ rejoin
## A match this game dropped out of is still held for it on the relay (as far as this game can tell).
func can_rejoin() -> bool:
	if not native_available() or rejoin.is_empty():
		return false
	return Time.get_unix_time_from_system() - float(rejoin["seen"]) < REJOIN_S

## Reconnects asking for our Hunter back. Returns the match options to start (Game.start_match), or {} when
## the relay no longer holds it (then the saved match is forgotten).
func rejoin_match() -> Dictionary:
	if enet:
		enet.close()
		_on_enet_closed("")
	rejoining = true
	back = []
	_start_native()
	for i in 100:
		if mode == "server" or not started: break
		await get_tree().create_timer(0.1).timeout
	if back.is_empty():
		rejoining = false
		forget_rejoin()
		return {}
	var d: Dictionary = rejoin["start"]
	return {"net": d, "seed": int(d["seed"]), "teams": int(d["teams"]), "squad": int(d["squad"]),
		"tier": int(d.get("tier", 0))}

func forget_rejoin() -> void:
	rejoin = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(REJOIN_FILE))

func _save_rejoin() -> void:
	rejoin["seen"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(REJOIN_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rejoin))

func tick(dt: float) -> void:
	if not online() or m == null:
		return
	_seen_t -= dt
	if _seen_t <= 0.0 and not rejoin.is_empty():
		_seen_t = REJOIN_SEEN_S
		_save_rejoin()
	send_t -= dt
	host_send_t -= dt
	if send_t <= 0.0:
		send_t = 0.1
		var mine: Array = m.net_snapshot(true)
		if mine.size() > 0:
			_chunks("st", mine, {"t": m.time})
		flush()
	if is_host() and host_send_t <= 0.0:
		host_send_t = 0.15
		var world_ents: Array = m.net_snapshot(false)
		if world_ents.size() > 0:
			_chunks("st", world_ents, {"t": m.time})
