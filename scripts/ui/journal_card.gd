class_name JournalCard
extends RefCounted
## The Boki card's journal section: its CareJournal lines, newest first.

## An empty journal shows nothing (the Likes block above already says how to learn more).
static func add(rec: Dictionary, into: Control) -> void:
	var lines: Array = rec.get("journal", [])
	if lines.is_empty():
		return
	into.add_child(UI.section("Journal", UI.FAINT.lightened(0.2)))
	for i in range(lines.size() - 1, -1, -1):
		into.add_child(UI.para(HomeNotices.bullet(CareJournal.text(lines[i])), 12, UI.MUTED))
