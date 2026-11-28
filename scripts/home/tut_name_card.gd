class_name TutNameCard
extends RefCounted
## The base tutorial's last step (FarmTutorial "name"): a small card with the naming line (NameStep) for your
## active Boki. Keep renames it; closing the card leaves the name as it was. Either way the step is done.


static func open(h) -> NameStep:
	var rec: Dictionary = Save.active_kin()
	if rec.is_empty():
		FarmTutorial.event("name")
		return null
	var v: VBoxContainer = h._new_panel("Name your Boki", 460)
	v.add_child(UI.label(FarmTutorial.hint_text("name"), 15))
	var step := NameStep.new(String(rec["species"]))
	v.add_child(step)
	step.focus()
	step.named.connect(
		func(nm: String, kept: bool):
			if kept and nm != String(rec["name"]):
				Save.log_event("renamed", rec, {"from": rec["name"]})
				rec["name"] = nm
			FarmTutorial.event("name")
			if kept:
				h._close_panel()
	)
	return step
