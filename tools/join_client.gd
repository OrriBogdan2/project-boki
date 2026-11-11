extends RefCounted
## --join-server=<host>:<port> --join-token=<tok>: a headless player for the server checks. It
## joins a dedicated match server through OnlineSession, plays its hunter with the bot brain and
## quits when the match ends. --join-queue=<matchmaker url> --join-mode=duel queues through the
## matchmaker instead (the end-to-end check). --join-leave-after=<s> drops the line that long into
## the match (a disconnect mid-match). Status lines on stdout:
##   BOKI_CLIENT pid=<pid> / state=<..> / refused reason=<code> / playing team=<t> / left / end won=<bool>

var main: Node
var session: OnlineSession
var leave_after := -1.0
var played := false

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	var host := ""
	var port := 7777
	var token := ""
	var queue_url := ""
	var mode := "duel"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--join-server="):
			host = a.substr(14).get_slice(":", 0)
			port = int(a.substr(14).get_slice(":", 1))
		if a.begins_with("--join-token="): token = a.substr(13)
		if a.begins_with("--join-queue="): queue_url = a.substr(13)
		if a.begins_with("--join-mode="): mode = a.substr(12)
		if a.begins_with("--join-name="): Save.d["name"] = a.substr(12)
		if a.begins_with("--join-leave-after="): leave_after = float(a.substr(19))
	print("BOKI_CLIENT pid=%d" % OS.get_process_id())
	session = OnlineSession.get_session()
	session.changed.connect(_on_change)
	Game.screen_changed.connect(_on_screen)
	if queue_url != "":
		session.queue_for(mode, [{"id": "test", "url": queue_url}])
	else:
		session.join(host, port, token)

func _on_change() -> void:
	print("BOKI_CLIENT state=%s msg=%s" % [session.state, session.message])
	if session.state == "error":
		print("BOKI_CLIENT refused reason=%s" % session.error_code)
		_quit()
	elif session.state == "match" and not played:
		played = true
		_play()

## The match is built: hand the hunter to the bot brain, and leave when told to.
func _play() -> void:
	var m: Match = null
	while m == null or m.player == null or not m.is_processing():
		await main.get_tree().process_frame
		m = Game.main.current as Match
		if session.state != "match":
			return
	m.player.ctrl = "bot"
	m.player.ai = m.bot_brain.new_mind(m.rng, 0.7)
	print("BOKI_CLIENT playing team=%d" % m.player.team)
	if leave_after > 0.0:
		await main.get_tree().create_timer(leave_after).timeout
		if session.state == "match":
			session.cancel()
			Net.leave()
			print("BOKI_CLIENT left")
			_quit()

func _on_screen(screen: String) -> void:
	if screen == "results":
		var r: Dictionary = Game.last_result
		print("BOKI_CLIENT end won=%s why=%s" % [r.get("extracted", false), r.get("why", "")])
		_quit()

func _quit() -> void:
	await main.get_tree().create_timer(0.3).timeout
	main.get_tree().quit(0)
