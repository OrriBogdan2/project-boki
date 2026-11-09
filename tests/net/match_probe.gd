extends SceneTree
## Two-client online match test through a relay, headless.
##   godot --headless --path . -s res://tests/net/match_probe.gd -- --server=127.0.0.1:7777 --probe-name=A --probe-host
##   godot --headless --path . -s res://tests/net/match_probe.gd -- --server=127.0.0.1:7777 --probe-name=B
## The host waits for a second player, sends "start" like the lobby does, and both play the match
## for a while. Prints how many snapshots each side received from the other and any remote hunters seen.
var name_ := "probe"
var is_host_ := false
var secs := 25.0
var recv := {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-name="): name_ = a.substr(13)
		if a == "--probe-host": is_host_ = true
		if a.begins_with("--probe-secs="): secs = float(a.substr(13))
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var net = root.get_node("/root/Net")
	var save = root.get_node("/root/Save")
	save.d["name"] = name_
	net.message.connect(_on_msg)
	net.start()
	for i in 80:
		await create_timer(0.1).timeout
		if net.mode == "server": break
	net.set_presence({"name": name_, "cls": "medium", "weapon": "", "ready": true, "lobby": 1, "kin": save.active_kin()})
	print("MP %s connected me=%s" % [name_, net.me])
	if is_host_:
		for i in 100:
			await create_timer(0.2).timeout
			if net.peers.size() >= 2: break
		var ids: Array = net.peers.keys()
		ids.sort()
		var roster := []
		for i in ids.size():
			var p: Dictionary = net.peers[ids[i]]
			roster.append({"peer": ids[i], "team": i, "name": p.get("name", "Hunter"), "cls": "medium", "weapon": "", "kin": p.get("kin", {})})
		var d := {"mid": "t1", "seed": 4242, "host": net.me, "roster": roster, "teams": 2, "squad": 1, "tier": 0}
		net.lobby_emit("start", d)
		_go(d)
	for i in int(secs * 10) + 300:
		await create_timer(0.1).timeout
		if started_at > 0 and Time.get_ticks_msec() - started_at > secs * 1000:
			break
	var m = net.m
	var remotes := 0
	if m and is_instance_valid(m):
		for h in m.get("hunters") if m.get("hunters") != null else []:
			if h.remote: remotes += 1
	print("MP %s done in_match=%s remote_hunters=%d received=%s" % [name_, net.in_match, remotes, JSON.stringify(recv)])
	quit()

var started_at := 0

func _on_msg(topic: String, data, from: String) -> void:
	if topic == "start" and not is_host_ and typeof(data) == TYPE_DICTIONARY:
		_go(data)

func _go(d: Dictionary) -> void:
	started_at = Time.get_ticks_msec()
	var game = root.get_node("/root/Game")
	var net = root.get_node("/root/Net")
	# count what arrives from the other side, by topic
	var orig_m = null
	game.goto("match", {"net": d, "seed": int(d["seed"]), "teams": int(d["teams"]), "squad": int(d["squad"]), "tier": 0, "no_plan": true})
	_watch.call_deferred()

func _watch() -> void:
	var net = root.get_node("/root/Net")
	while true:
		await create_timer(0.5).timeout
		if net.m and is_instance_valid(net.m):
			break
	# wrap net_receive counting via the relay's message signal is not available for match topics,
	# so poll remote hunters' positions instead
	var last := {}
	while true:
		await create_timer(1.0).timeout
		var m = net.m
		if m == null or not is_instance_valid(m):
			return
		for h in m.hunters:
			if h.remote:
				var k := String(h.nid)
				var p: Vector3 = h.global_position
				if last.has(k) and last[k].distance_to(p) > 0.01:
					recv[k] = int(recv.get(k, 0)) + 1
				last[k] = p
