class_name SleepoverPanel
extends RefCounted
## The "send a Boki for a sleepover" rows of the visit panel (docs/decisions/0022-sleepovers.md).

## Adds one button per Boki that can go. done(text) is called after one is sent.
static func fill(v: VBoxContainer, friend_id: String, friend_name: String, done: Callable) -> void:
	v.add_child(UI.label("Send a Boki to stay a day with %s:" % friend_name, 14, UI.MUTED))
	var blocked := ""
	for rec in KinBox.farm():
		blocked = Sleepover.why_not(rec)
		if blocked != "":
			continue
		var r: Dictionary = rec
		v.add_child(UI.button(String(r["name"]), func():
			if Sleepover.send(r, friend_id, friend_name, Time.get_unix_time_from_system()):
				Save.save_game()
				done.call("%s is off to %s's for a day" % [r["name"], friend_name]), 220))
	if blocked != "" and v.get_child_count() == 1:
		v.add_child(UI.label(blocked, 14, UI.MUTED))
