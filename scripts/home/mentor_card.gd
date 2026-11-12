class_name MentorCard
extends RefCounted
## The "Retire as mentor" action on an Elder's card (base_mode only; Mentor, GARDEN.md section 3).

static func add(h, row: Container, rec: Dictionary) -> void:
	if not FarmUnlocks.base_mode() or Care.stage_name(rec) != "Elder":
		return
	if Mentor.is_mentor(rec):
		row.add_child(UI.label("Mentor at the Soul Shrine", UI.T_SMALL, UI.FAINT))
		return
	var why := Mentor.why_not(rec)
	var b := UI.ghost("Retire as mentor", func():
		UI.confirm(h.panel_host.get_parent(), "Retire %s?" % rec["name"],
			"It stays at the Soul Shrine and passes one gift to the next egg. Nothing is lost.", "Retire",
			func():
				Mentor.retire(rec)
				Save.save_game()
				h._toast("%s retired to the Soul Shrine" % rec["name"])
				h._open_kin(rec), false))
	b.disabled = why != ""
	b.tooltip_text = why
	row.add_child(b)
