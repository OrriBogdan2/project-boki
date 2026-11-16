class_name JournalCard
extends RefCounted
## The Boki card's journal section: its CareJournal lines, newest first.

static func add(rec: Dictionary, into: Control) -> void:
	into.add_child(UI.section("Journal", UI.FAINT.lightened(0.2)))
	var lines: Array = rec.get("journal", [])
	if lines.is_empty():
		into.add_child(UI.para("Nothing yet: feed it and play with it.", 12, UI.FAINT))
	for i in range(lines.size() - 1, -1, -1):
		into.add_child(UI.para(HomeNotices.bullet(CareJournal.text(lines[i])), 12, UI.MUTED))
