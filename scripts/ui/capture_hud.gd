class_name CaptureHud
extends RefCounted
## What the player reads about capture (docs/decisions/0002): the prompt under the wild Boki, the fill ring
## while you hold and scan, the box counter, and the capsules in the backpack with a Release button.
## Pure presentation over Capture and Hunter.caught; the rules live in capture.gd.

static func _mine(H) -> Hunter:
	return H.m.player

## The interact-bar text for a knocked-out wild Boki beside you.
static func prompt(h: Hunter, k: Kin) -> String:
	var why := Capture.block_reason(h, k)
	if why != "":
		return why
	var key := Settings.key_cap("interact")
	if Capture.active(h):
		return "Scanning… %ds (dash to cancel)" % int(ceil((1.0 - Capture.scan_frac(h)) * float(Capture.rules()["scan_s"])))
	return "Hold %s to scan %s" % [key, Data.KIN[k.species]["name"]]

## Progress of the bar under the prompt: the hold first, then the scan.
static func progress(p: Hunter) -> float:
	return Capture.scan_frac(p) if Capture.active(p) else Capture.hold_frac(p)

## "Box 2/3" and its colour (warm when full).
static func box_text(p: Hunter) -> String:
	return "Box %d/%d" % [p.caught.size(), Capture.box_cap()]

static func box_col(p: Hunter, normal: Color) -> Color:
	return Color("ffb08a") if p.caught.size() >= Capture.box_cap() else normal

## The wild Boki that is knocked out, in the world: its name, how to scan it, the ring while it scans.
static func dazed_label(H, k: Kin, sp: Vector2) -> void:
	var p := _mine(H)
	var nm: String = Data.KIN[k.species]["name"]
	var col := Color(k.sp.get("glow", k.sp["color"])).lerp(Color.WHITE, 0.3)
	H._ctext(sp + Vector2(0, -34), ("%s (left behind)" if k.lost_from != "" else "%s, knocked out") % nm, 15, col, H.big)
	var scanning: bool = p != null and Capture.active(p) and Capture.state(p).get("k") == k
	var beaming := scanning or k.scan_by != null
	if beaming:
		var frac := Capture.scan_frac(p) if scanning else 0.0
		H._arc(sp + Vector2(0, -10), 20.0, frac if scanning else 1.0, Capture.BEAM_COL, 4.0)
		H._ctext(sp + Vector2(0, -52), "Scanning…", 13, Capture.BEAM_COL, H.big)
		return
	if p != null and k.dazed_t < 1e8:
		H._ctext(sp + Vector2(0, -18), "%ds" % int(ceil(k.dazed_t)), 13, Color(H.INK, 0.85), H.big)
	if p != null and p.flat_dist(k) < float(Capture.rules()["range"]) + 3.0:
		H._ctext(sp + Vector2(0, -52), prompt(p, k), 13, H.GOLD, H.big)
		var hf := Capture.hold_frac(p)
		if hf > 0.0:
			H._arc(sp + Vector2(0, -10), 20.0, hf, H.GOLD, 4.0)

## Was this capsule's Release clicked once in the last 3 seconds (the second click confirms)?
static func armed_for(m, p: Hunter, idx: int) -> bool:
	var a: Dictionary = p.get_meta("release_arm", {})
	return not a.is_empty() and idx < p.caught.size() and String(a.get("uid", "x")) == String(p.caught[idx].get("uid", "")) and m.time - float(a.get("t", -9.0)) < 3.0

## The "In your box" section of the backpack: one row per capsule, with Release.
static func pack_section(H, v: VBoxContainer, p: Hunter, rebuild: Callable) -> void:
	v.add_child(UiText.label("%s  ·  captured Bokis ride home in capsules" % box_text(p), 12, H.MUTED, UI.caps))
	if p.caught.is_empty():
		v.add_child(UiText.label("Empty. Knock a wild Boki out, then hold %s beside it to scan it." % Settings.key_cap("interact"), 13, H.MUTED))
		return
	for i in p.caught.size():
		var idx := i
		var rec: Dictionary = p.caught[i]
		var row := UI.hbox(8)
		var nm := UiText.label("%s  ·  %s" % [rec.get("name", "Boki"), Data.KIN[String(rec["species"])]["name"]], 14, H.INK)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var armed := armed_for(H.m, p, idx)
		var bt := UiWidgets.button("Release %s?" % rec.get("name", "it") if armed else "Release", func():
			if armed_for(H.m, p, idx):
				p.remove_meta("release_arm")
				Capture.release(H.m, H.m.player, idx)
			else:
				p.set_meta("release_arm", {"uid": String(p.caught[idx].get("uid", "")), "t": H.m.time})      # first click: ask again
			rebuild.call())
		row.add_child(bt)
		v.add_child(row)
