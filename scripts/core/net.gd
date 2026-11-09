extends Node
## Online play over the artifact's room (or a BroadcastChannel between browser tabs when testing).
## Each player's game owns its own hunter and kin; the host's game owns monsters, bots and loot.
## Owners send compact snapshots; anyone who hits something they don't own sends the hit to its owner.
## On desktop the same messages go through the Project Boki relay server instead (net_enet.gd,
## scripts/server/relay.gd). The launcher passes `-- --server=host:port --token=<discord token>`.

const VERSION := "0.29.0"        # online play only matches players on the same version; bump on network changes (0.13.0: gear wdrop carries kind/rarity/id, 0.14.0: the "carry" and "zone" events, 0.15.0: the kin snapshot carries its rest seconds; merge augments, 0.16.0: the kit move id rides the hunter snapshot; perk orbs "odrop"/"otake", 0.17.0: a merge release lands the Boki beside you pumped with a 6s rest instead of draining it on your shoulder, and the hunter gets an afterglow, 0.18.0: Boki loss: the "guard" event (a guarding Boki's uid and record), "caught" carries the owner, "gdrop", kcmd "unbond"; a carried Boki rides its carrier's position, 0.19.0: the host re-sends live perk orbs on join; the run level on the hunter snapshot; chest-key carrier flags and the Shrubling state on the monster snapshot, 0.19.1: ext/equal-loadout's GripNet fields, 0.20.0: revive beacons run online with the "bcn" event, 0.21.0: a squad ping ("sping") carries its kind, 0.22.0: the first GitHub Release for the launcher, Nov 5; 0.23.0+: one release per merge batch; 0.24.0: the READY-queue merge of Nov 6, 0.24.1: still title backdrop, 0.25.0: the pre-match lobby: its "pick" and "chat" topics, the roster carries each hunter's arch, 0.27.0: the kin snapshot carries the Boki wisp flag, 0.28.0: and the Boki summon seconds, 0.29.0: and the guardian flag)

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

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--server="): server_addr = a.substr(9)
		if a.begins_with("--token="): token = a.substr(8)
	if server_addr == "":
		server_addr = OS.get_environment("BOKI_SERVER")

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
		enet.send({"k": "hello", "ver": VERSION, "tok": token, "name": Save.d.get("name", "Hunter")})

func _on_enet(d: Dictionary) -> void:
	match String(d.get("k", "")):
		"welcome":
			me = String(d.get("me", ""))
			mode = "server"
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
func begin_match(name: String, host_peer: String, match_node: Node) -> void:
	match_name = name
	host = host_peer
	m = match_node
	in_match = true
	out_hits.clear(); out_events.clear(); seen.clear()
	if enet:
		enet.send({"k": "join", "room": name})
	elif Bridge.js:
		Bridge.js.joinMatch(name)

func end_match() -> void:
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

func tick(dt: float) -> void:
	if not online() or m == null:
		return
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
