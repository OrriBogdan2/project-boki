class_name HeartRaidPick
extends RefCounted
## The Heart Raid (prototype) panel, from the expedition panel's footer: what the mode is in two lines and
## how many go (solo, or a squad of 4 with bots in the empty seats). Starting goes through the expedition's
## own start (hunger check, Boki-at-risk warning, loadout), with Home.raid_squad set (scripts/match/heart_raid.gd).

const SQUADS := [[1, "Solo", "Just you and your Boki"], [4, "Squad of 4", "Bots fill the empty seats"]]

static func open(h) -> void:
	var v: VBoxContainer = h._new_panel("Heart Raid (prototype)", 560)
	UI.subtitle(v, "No rival squads. Waves of monsters and the Blight come for the Heart, then its boss rises.")
	var rl := HeartRaid.rules()
	var goal := "Hold out through %d waves, bring down %s, then hold the Heart ring to win." % [
		(rl["waves"] as Array).size(), rl["boss"]["name"]]
	var mins := int(HeartRaid.r("match_s")) / 60
	var lose := " If your squad falls, or the islands fall at %d:00, the raid is lost." % mins
	v.add_child(UI.para(goal + lose, UI.T_SMALL, UI.MUTED))
	for sq in SQUADS:
		var n: int = sq[0]
		var go := func() -> void:
			h.raid_squad = n
			h._confirm_start()
		var tc := UI.tile_card(false, go, 12, HeartRaid.COL)
		var tv := UI.vbox(2)
		tv.add_child(UI.label(String(sq[1]), UI.T_HEAD, UI.INK, UI.big))
		tv.add_child(UI.label(String(sq[2]), UI.T_SMALL, UI.MUTED))
		tc.add_child(tv)
		v.add_child(tc)
	UI.footer_left(v).add_child(UI.ghost("Back to the expedition", h._open_expedition, 0))
