class_name FarmHints
extends RefCounted
## The farm's one-time hints (FirstTimeHint, content/rules/hints.json "farm"): what the farm tutorial's cut
## steps taught (stone for the house, hammering it up, a Boki's job, the Market, Hob), said once as a toast
## the first time it matters. FarmGuide polls it twice a second; at most one shows per poll, never while a
## panel is open or when visiting. Doing the thing first (FarmTutorial.event) means it never shows.

var h

func _init(home) -> void:
	h = home

func poll() -> void:
	if not h.visit.is_empty() or h.panel_open != "" or not HomeLayout.fs(Save.d):
		return
	for id in FirstTimeHint.ids("farm"):
		if not FirstTimeHint.seen(String(id)) and due(String(id)):
			FirstTimeHint.show(String(id), func(line: String): h._toast(line))
			return

## Does this hint matter right now?
func due(id: String) -> bool:
	var house := FarmHob.house_entry()
	var site := not house.is_empty() and FarmSites.has_site(house)
	match id:
		"stone":
			return site and _left(house, "stone") > FarmSites.have("stone")
		"hammer":
			return site and not FarmSites.stalled(house)
		"task":
			return FarmTutorial.house_built() and not FarmTaskGuide.any_job()
		"buy":
			return _total(Save.d["seeds"]) == 0
		"sell":
			return _total(Save.d["crops"]) > 0
		"hob":
			return h.hob != null and not FarmTutorial.active() and not bool(FarmBuilder.state().get("met", false))
	return false

## How much of material m the site still has to take.
static func _left(e: Dictionary, m: String) -> int:
	var s: Dictionary = e["site"]
	return int((s.get("cost", {}) as Dictionary).get(m, 0)) - int((s.get("paid", {}) as Dictionary).get(m, 0))

static func _total(counts: Dictionary) -> int:
	var n := 0
	for k in counts:
		n += int(counts[k])
	return n
