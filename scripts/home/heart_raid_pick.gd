class_name HeartRaidPick
extends RefCounted
## The Heart Raid (prototype) panel, from the expedition panel's footer: what the mode is in two lines, the
## difficulty (Normal, Hard, Nightmare: what each changes and which raid Boki it opens) and how many go (solo,
## or a squad of 4 with bots in the empty seats). Starting goes through the expedition's own start (hunger
## check, Boki-at-risk warning, loadout), with Home.raid_squad set and this difficulty
## (scripts/match/heart_raid.gd). The online lobby's raid button cycles the same difficulty.

const SQUADS := [[1, "Solo", "Just you and your Boki"], [4, "Squad of 4", "Bots fill the empty seats"]]
const BOKI_WORDS := {"normal": "its common Boki", "hard": "its rare Boki too", "nightmare": "its very rare Boki too"}

static var difficulty := "normal"   # the last one picked (this session; the lobby reads it too)

static func open(h) -> void:
	var v: VBoxContainer = h._new_panel("Heart Raid (prototype)", 560)
	UI.subtitle(v, "No rival squads. Waves of monsters and the Blight come for the Heart, then its boss rises.")
	var rl := HeartRaid.rules()
	var goal := "Hold out through %d waves, bring down %s, then hold the Heart ring to win." % [
		(rl["waves"] as Array).size(), rl["boss"]["name"]]
	var mins := int(HeartRaid.r("match_s")) / 60
	var lose := " If your squad falls, or the islands fall at %d:00, the raid is lost." % mins
	v.add_child(UI.para(goal + lose, UI.T_SMALL, UI.MUTED))
	var row := UI.hbox(6)
	for d in HeartRaid.difficulties():
		var pick := func() -> void:
			difficulty = d
			open(h)
		var b := UI.button(HeartRaid.diff_name(d), pick)
		b.theme_type_variation = "SegOn" if d == difficulty else "Seg"
		row.add_child(b)
	v.add_child(row)
	v.add_child(UI.para(describe(difficulty), UI.T_SMALL, HeartRaid.COL))
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

## One line on a difficulty, from the rules: how much tougher, and which of the raid's Boki can turn up.
static func describe(d: String) -> String:
	var dd: Dictionary = HeartRaid.rules()["difficulty"][d]
	var s := "%s: monsters with %d%% health and %d%% damage, %d%% more of them" % [
		dd["name"], roundi(float(dd["hp"]) * 100.0), roundi(float(dd["dmg"]) * 100.0),
		roundi((float(dd["count"]) - 1.0) * 100.0)]
	if dd.has("boss_extra"):
		s += "; the boss has an extra attack"
	return s + ". The raid gives %s." % BOKI_WORDS[d]

## The next difficulty round the ladder (the lobby's raid button).
static func cycle() -> void:
	var ladder := HeartRaid.difficulties()
	difficulty = ladder[(ladder.find(difficulty) + 1) % ladder.size()]
