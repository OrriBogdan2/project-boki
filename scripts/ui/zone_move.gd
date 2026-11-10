class_name ZoneMove
## "Move to...": a small list of the zones a Boki could go to, from its card or when you set it down on the
## Waystone (briefs/design/GARDEN.md 10.4). A zone that is shut or full is listed greyed with the reason.

## On a Boki card: the link, offered only on a base with another zone open, for a Boki out in this zone that
## isn't your partner.
static func add_link(h, row: Control, rec: Dictionary) -> void:
	if not h.visit.is_empty() or h.life == null or not h.life.pad.active() or GardenZones.is_partner(rec):
		return
	for k in h.kins:
		if k["rec"] == rec:
			row.add_child(UI.ghost("Move to...", func(): pick(h, k), 0, "paw"))
			return

static func pick(h, k: Dictionary) -> void:
	var layer := UI.Modal.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cc)
	var p := UI.sheet(380)
	cc.add_child(p)
	var v := UI.vbox(UI.GAP_BIG)
	p.add_child(v)
	v.add_child(UI.title("Move %s to..." % k["rec"]["name"], 24))
	for id in (GardenZones.rules()["zones"] as Dictionary):
		if id == GardenZones.here:
			continue
		var why := GardenZones.why_not(k["rec"], id)
		var go := func():
			layer.queue_free()
			var left: String = h.life.pad.send(k, id)
			if left != "": h._toast(left)
		var b := UI.ghost(GardenZones.zone_name(id), go, 0, "paw")
		b.disabled = why != ""
		b.tooltip_text = why
		v.add_child(b)
	v.add_child(UI.ghost("Cancel", layer.queue_free))
	layer.set_meta("modal", true)
	h.root_ui.add_child(layer)
