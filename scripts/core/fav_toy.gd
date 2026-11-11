class_name FavToy
extends RefCounted
## A Boki's favourite plaything (GARDEN.md sections 4 and 6). Each finished play at a toy adds its seconds to
## rec["toy_time"] = {toy id: seconds} and one to rec["toy_n"]. From fav_after plays on, the toy it has used
## most is its favourite, rec["habit"]["toy"]: it picks that one first when idle (HomeToys.weight), the Boki
## card shows it, and Care.breed passes it on. Older records have none of these keys and no favourite yet.

## The favourite toy id ("" for none yet).
static func of(rec: Dictionary) -> String:
	return String((rec.get("habit", {}) as Dictionary).get("toy", ""))

## A finished play of `secs` at toy_id: add it up, and crown the most-used toy once there are enough plays.
static func log_play(rec: Dictionary, toy_id: String, secs: float) -> void:
	var time: Dictionary = rec.get("toy_time", {})
	time[toy_id] = float(time.get(toy_id, 0.0)) + secs
	rec["toy_time"] = time
	rec["toy_n"] = int(rec.get("toy_n", 0)) + 1
	if int(rec["toy_n"]) < int(Content.rules("toys")["fav_after"]):
		return
	var best := of(rec)
	for id in time:
		if best == "" or float(time[id]) > float(time.get(best, 0.0)):
			best = String(id)
	rec["habit"]["toy"] = best

## A baby's inherited favourite, with inherit_secs of head start so its own first plays don't undo it.
static func inherit(baby: Dictionary, toy_id: String) -> void:
	baby["habit"]["toy"] = toy_id
	baby["toy_time"] = {toy_id: float(Content.rules("toys")["inherit_secs"])}
