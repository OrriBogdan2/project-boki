extends SceneTree
## Headless network probe: connects to a relay like a real client and checks presence + messages.
## godot --headless --path . -s res://tests/net/net_probe.gd -- --server=127.0.0.1:7777 --probe-name=A [--probe-send]
var name_ := "probe"
var send_ := false
var got_peers := 0
var got_msgs := []
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-name="): name_ = a.substr(13)
		if a == "--probe-send": send_ = true
	_run.call_deferred()
func _run() -> void:
	var net = root.get_node("/root/Net")
	net.peers_changed.connect(func(): got_peers = net.peers.size())
	net.message.connect(func(t, d, f): got_msgs.append([t, d, f]))
	net.start()
	for i in 60:
		await create_timer(0.1).timeout
		if net.mode == "server": break
	print("PROBE %s mode=%s me=%s deny=%s" % [name_, net.mode, net.me, net.deny_reason])
	net.set_presence({"name": name_, "lobby": 1})
	await create_timer(1.5).timeout
	print("PROBE %s peers=%d" % [name_, net.peers.size()])
	if not send_:
		net.begin_match("kf-test", "x", null)
	if send_:
		net.lobby_emit("hello-all", {"from": name_})
		net.begin_match("kf-test", net.me, null)
		await create_timer(0.3).timeout
		net._emit("st", [{"t": 1}, ["x", 1, 2]])
		net._emit("hit", [["Pzz", 5]])
	await create_timer(4.0 if not send_ else 2.0).timeout
	print("PROBE %s msgs=%s" % [name_, JSON.stringify(got_msgs)])
	quit()
