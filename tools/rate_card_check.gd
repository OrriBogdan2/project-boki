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
	ok(JSON.stringify(b).length() < 8192, "payload fits the 8 KB limit")
	# F8 quick notes: queued with their context, sent with the queue, and a quit tries to send them
	var ctx := QuickNote.context()
	ok(ctx["version"] == Net.VERSION and ctx.has("preset") and ctx.has("fps"), "context: version, preset, fps")
	ok(QuickNote.screenshot(main.get_viewport()).length() <= Feedback.SHOT_MAX, "the screenshot fits the cap")
	var listed: bool = Settings.ACTIONS.any(func(a): return a[0] == "quick_note")
	ok(InputMap.has_action("quick_note") and listed, "F8 is a rebindable action")
	online[0] = false
	Feedback.add_note("jump felt late", {"hunter": "vex", "boki": "cindle", "t": 31.5, "pos": [1.0, 2.0]}, "abc")
	Feedback.add_note("x".repeat(400), {}, "y".repeat(Feedback.SHOT_MAX + 1))
	ok(sent.size() == 1 and Feedback.queued() == 2, "notes only queue: nothing is sent yet")
	QuickNote.open(host)
	var box: Node = host.get_child(host.get_child_count() - 1)
	var edit: LineEdit = box.find_children("*", "LineEdit", true, false)[0]
	ok(QuickNote.typing and not main.get_tree().paused, "the box opens without pausing the tree")
	edit.text_submitted.emit("  tree clips the camera ")
	await main.get_tree().process_frame
	ok(not QuickNote.typing and Feedback.queued() == 3, "Enter saves the line and closes the box")
	QuickNote.open(host)
	edit = host.get_child(host.get_child_count() - 1).find_children("*", "LineEdit", true, false)[0]
	edit.text_submitted.emit("   ")
	ok(not QuickNote.typing and Feedback.queued() == 3, "an empty line saves nothing")
	var left := [0]
	online[0] = true
	RateCard.gate(host, func(): left[0] += 1)
	ok(left[0] == 1 and sent.size() == 4 and Feedback.queued() == 0, "quit sends the queued notes, then carries on")
	var n: Dictionary = sent[1]
	var whole: bool = n["note"] == "jump felt late" and n["ctx"]["hunter"] == "vex" and n["shot"] == "abc"
	ok(n["kind"] == "note" and whole, "a note carries its text, context and screenshot")
	ok(sent[2]["note"].length() == Feedback.NOTE_MAX and sent[2]["shot"] == "", "long note cut, big shot dropped")
	ok(sent[3]["note"] == "tree clips the camera" and not sent[3].has("scores"), "the line is trimmed; no scores")
	ok(JSON.stringify(n).length() < 8192, "a note fits the server's 8 KB limit")
	DirAccess.remove_absolute(Feedback.path)
	print("RATECARD DONE, failures: ", bad)
	main.get_tree().quit()
