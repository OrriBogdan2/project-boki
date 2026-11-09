extends RefCounted
## --rate-card-check: the "Rate this build" card (item 189). It is due only after 10 minutes of play on
## this version, answering or skipping ends it for that version, and an answer that could not be sent
## stays queued and goes out on the next launch. Uses a scratch file and a fake poster; never touches
## the save or the network.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("RATECARD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _press(node: Node, text: String) -> void:
	for c in node.find_children("*", "Button", true, false):
		if (c as Button).text == text:
			(c as Button).pressed.emit()
			return

func run(main: Node) -> void:
	Save.no_write = true
	Feedback.path = "user://feedback_check.json"
	DirAccess.remove_absolute(Feedback.path)
	var sent: Array = []
	var online := [false]
	Feedback.poster = func(body: Dictionary, done: Callable) -> void:
		if online[0]:
			sent.append(body)
		done.call(online[0])
	ok(not Feedback.due(), "not due with no play time")
	Feedback._counted_ms = Time.get_ticks_msec() - int(Feedback.MIN_MINUTES * 60000.0) - 1000
	ok(Feedback.due(), "due after %d minutes on this version" % int(Feedback.MIN_MINUTES))
	var fired := [0]
	var host := Control.new()
	main.add_child(host)
	RateCard.gate(host, func(): fired[0] += 1)
	ok(fired[0] == 0 and host.get_child_count() == 1, "the card shows instead of continuing")
	var card: Node = host.get_child(0)
	_press(card, "Skip")
	await main.get_tree().process_frame
	ok(fired[0] == 1 and sent.is_empty() and host.get_child_count() == 0, "skip continues and sends nothing")
	ok(not Feedback.due(), "once per version: not due again after a skip")
	RateCard.gate(host, func(): fired[0] += 1)
	ok(fired[0] == 2 and host.get_child_count() == 0, "a second gate passes straight through")
	# offline: an answer is queued, then flushed on the next launch
	var scores := {"combat": 7, "boki": 9, "onboarding": 4, "look": 10}
	Feedback.submit(host, scores, "fun")
	ok(sent.is_empty() and Feedback._load()["queue"].size() == 1, "offline: the answer stays queued")
	online[0] = true
	Feedback.flush(host)
	ok(sent.size() == 1 and Feedback._load()["queue"].is_empty(), "next launch: the queue is sent and emptied")
	var b: Dictionary = sent[0]
	var same := scores.keys().all(func(k): return int(b["scores"][k]) == int(scores[k]))
	ok(b["version"] == Net.VERSION and same and b["note"] == "fun", "payload has version, scores and note")
	ok(b["minutes_played"] >= 10.0 and String(b["player"]) != "", "payload has minutes_played and player")
	ok(JSON.stringify(b).length() < 4096, "payload fits the 4 KB limit")
	DirAccess.remove_absolute(Feedback.path)
	print("RATECARD DONE, failures: ", bad)
	main.get_tree().quit()
