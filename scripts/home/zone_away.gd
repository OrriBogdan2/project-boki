class_name ZoneAway
extends RefCounted
## The "While you were away" card across the garden's zones (briefs/design/GARDEN.md 10.4). Only the
## zone you arrive in is simulated (Econ.catch_up_all(zone)); the others catch up when you reach them.
## The card is the facts already written down, so it lists every zone, each under its name once two are open.

## Arriving in the hub or a zone: what the stations made, then the journals, then today's open wishes (the first
## arrival of the day). In the garden the return is the one plain line on the HUD card (BaseCard) and never a panel
## over the Boki; the wishes are their own card. Other homes keep the one "While you were away" card.
static func card(h) -> void:
	var lines := CareJournal.arrival(Work.catch_up())
	BaseCard.arrived(lines)
	var base := FarmUnlocks.base_mode()
	var wishes: Array = GardenWishes.card_lines() if base and h.visit.is_empty() else []
	if base:
		if not wishes.is_empty():
			h._show_when_free(wishes, "Today's wishes")
	elif not lines.is_empty():
		h._show_when_free(lines)

## The facts in card lines, without the zone names that group them when two zones are open.
static func facts(lines: Array) -> Array:
	var names := GardenZones.ids().map(func(id): return String(GardenZones.info(id)["name"]))
	return lines.filter(func(l): return String(l) not in names).map(func(l): return String(l).strip_edges())

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
