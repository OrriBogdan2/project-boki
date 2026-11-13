class_name ZoneAway
extends RefCounted
## The "While you were away" card across the garden's zones (briefs/design/GARDEN.md 10.4). Only the
## zone you arrive in is simulated (Econ.catch_up_all(zone)); the others catch up when you reach them.
## The card is the facts already written down, so it lists every zone, each under its name once two are open.

## Shows the card for arriving in the hub or a zone: what the stations made, then the journals, then today's open
## wishes (the first arrival of the day). One card, one close; with nothing new it is the wishes alone.
static func card(h) -> void:
	var lines := CareJournal.arrival(Work.catch_up())
	BaseHud.arrived(lines)      # the base HUD's "what changed" row
	var wishes: Array = GardenWishes.card_lines() if FarmUnlocks.base_mode() and h.visit.is_empty() else []
	if lines.is_empty() and not wishes.is_empty():
		h._show_when_free(wishes, "Today's wishes")
	elif not lines.is_empty():
		h._show_when_free(lines + wishes)

## `work` lines (the start zone's stations) and `found` [[time, zone, line]], oldest first, as card
## lines: flat while one zone is open, else a name per zone with its lines indented under it.
static func grouped(work: Array, found: Array) -> Array:
	if GardenZones.ids().filter(GardenZones.is_open).size() < 2:
		return work + found.map(func(f): return f[2])
	var out: Array = []
	for id in GardenZones.ids():
		var lines: Array = work if id == GardenZones.start() else []
		lines = lines + found.filter(func(f): return f[1] == id).map(func(f): return f[2])
		if not lines.is_empty():
			out.append(String(GardenZones.info(id)["name"]))
			out.append_array(lines.map(func(l): return "  " + String(l)))
	return out
