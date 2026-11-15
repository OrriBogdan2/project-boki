class_name FirstCapture
extends RefCounted
## The first capturable wild Boki a player meets in a real match (never the tutorial match): one hint through
## Match._tip (said once per save: Save.d["tutorial"]["first_capture"]), a marker over that Boki until you start
## scanning it or walk out of range, and one line on why if that first scan fails.
## State: the local hunter's meta "fc" = {nid, marked}.

const KEY := "first_capture"

## A save that has caught a Boki or seen the old scan hint is not taught again. Keyed by its own field, so it
## runs at load for any save (no version step).
static func migrate(data: Dictionary) -> void:
	var tut = data.get("tutorial")
	if typeof(tut) != TYPE_DICTIONARY or tut.has(KEY):
		return
	var stats = data.get("stats")
	if tut.get("catch", false) or (typeof(stats) == TYPE_DICTIONARY and int(stats.get("caught", 0)) > 0):
		tut[KEY] = true

static func _in_range(p: Hunter, k: Kin) -> bool:
	return p.flat_dist(k) < float(Capture.rules()["range"])

static func hint_text(k: Kin) -> String:
	return "%s  ·  %s  ·  Hold %s to capture it: it comes home with you if you get out" % [
			k.sp["name"], String(k.sp["type"]).capitalize(), Settings.key_cap("interact")]

## Each frame from Match._tips: the hint at the first capturable wild Boki in range, then the marker's upkeep.
static func tick(m) -> void:
	var p: Hunter = m.player
	var st: Dictionary = p.get_meta("fc", {})
	if not st.is_empty():
		_follow(m, p, st)
	elif not Save.d["tutorial"].get(KEY, false) and not m.opts.get("training", false):
		for k in m.kins:
			if k.owner_h == null and _in_range(p, k) and Capture.block_reason(p, k) == "":
				m._tip(KEY, hint_text(k))
				p.set_meta("fc", {"nid": k.nid, "marked": true})
				return

static func _follow(m, p: Hunter, st: Dictionary) -> void:
	var kv = m.ents_by_id.get(st["nid"], null)
	if not is_instance_valid(kv) or (kv.dead and Capture.state(p).is_empty()):
		p.remove_meta("fc")
	elif st["marked"] and (not Capture.state(p).is_empty() or not _in_range(p, kv)):
		st["marked"] = false

## Is the marker on this Boki?
static func marked(p: Hunter, k: Kin) -> bool:
	var st: Dictionary = p.get_meta("fc", {})
	return not st.is_empty() and st["marked"] and st["nid"] == k.nid

## The first failed scan after the hint says why (true if it did; the generic line then stays quiet).
static func fail(m, h: Hunter, why: String) -> bool:
	var st: Dictionary = h.get_meta("fc", {})
	var key := Settings.key_cap("interact")
	var line := ""
	var reach := int(Capture.rules()["cancel_range"])
	match why:
		"dash": line = "You dashed, so the scan stopped: hold %s beside it to try again" % key
		"cc": line = "Something knocked you out of the scan: hold %s to try again" % key
		"far": line = "Too far from it (stay within %d m): hold %s to try again" % [reach, key]
		"gone": line = "It woke up and got away"
	if st.is_empty() or line == "" or not h.is_local() or m.hud == null:
		return false
	h.remove_meta("fc")
	m.hud.toast(line, Color("ffd89a"))
	return true
