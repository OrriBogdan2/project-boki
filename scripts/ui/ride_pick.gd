class_name RidePick
extends RefCounted
## Who rides with you, in one place before you leave (the expedition panel at home and the pre-match
## lobby): the riding Boki's portrait, its carry passive, its summon window (KinSummon), what its care
## gives it on the run and which way it leans (the same lines in each swap tile's hover card) and a swap from
## your garden roster. The rider is Save "active" (Save.active_kin), the Boki the match brings.
## How many ride: COUNT. One is the current rule (Match.TWO_KIN off, KinSummon: one Boki per Hunter);
## DECISIONS 2026-11-09 leaves more open ("default is one"), so this only shows it.

const COUNT := 1           # Boki that ride with you per run
const PIC := 64.0          # px: the rider's portrait
const SWAP_PIC := 40.0     # px: one Boki in the swap row
const SWAP_ROW_H := 52.0   # px: height of the scrolling swap row

## The Boki you can swap in: your garden roster, minus any held away (KinLoss).
static func choices() -> Array:
	return (Save.d["roster"] as Array).filter(func(r): return KinLoss.selectable(r))

## Makes this Boki the one that rides. False if it isn't yours or can't go (held away).
static func swap(uid: String) -> bool:
	var r := Save.kin(uid)
	if r.is_empty() or not KinLoss.selectable(r):
		return false
	Save.d["active"] = uid
	Save.save_game()
	return true

static func wisps() -> bool:
	return bool(Settings.get_v("boki_wisps"))

## The rule line: how many ride, and how.
static func rule_line() -> String:
	if wisps():
		return "One Boki rides with you, a wisp at your shoulder: its carry bonus is always on, " \
			+ "and it fights beside you when summoned."
	return "One Boki comes with you and walks beside you."

static func carry_line(rec: Dictionary) -> String:
	return KinText.carry(KinLib.kin(String(rec["species"])))

## "Summon: out 10 s, rest 60 s" (its species' window and cooldown).
static func summon_line(rec: Dictionary) -> String:
	var t := KinSummon.times(KinLib.kin(String(rec["species"])))
	return "Summon: out %d s, rest %d s%s" % [int(t.x), int(t.y), "" if wisps() else "  (with Boki wisps on)"]

## "Care: +4% damage, +10% health, skill 3% faster": what its raising gives it on the run (Care.match_mods:
## trained Power, Guard, Speed, Focus, how it is feeling and its bond). Quiet stats are left out.
static func care_line(rec: Dictionary) -> String:
	var m := Care.match_mods(rec)
	var bits := PackedStringArray()
	for pair in [["dmg", "damage"], ["hp", "health"], ["speed", "speed"]]:
		var pct := roundi((float(m[pair[0]]) - 1.0) * 100.0)
		if pct != 0:
			bits.append("%+d%% %s" % [pct, pair[1]])
	var cd := roundi((1.0 - float(m["cd"])) * 100.0)
	if cd != 0:
		bits.append("skill %d%% faster" % cd)
	return "Care: " + (", ".join(bits) if not bits.is_empty() else "no bonus yet")

## "Leans Fierce: fights hard": the form it is growing toward (Evo.leading).
static func lean_line(rec: Dictionary) -> String:
	var a: Dictionary = Evo.AFF[Evo.leading(rec)]
	return "Leans %s: %s" % [a["name"], a["why"]]

## Hover text for one Boki in the swap row: name, summon tempo, care and lean.
static func tip(rec: Dictionary, title: String) -> String:
	var head := "%s  ·  level %d" % [title, int(rec.get("level", 1))]
	return "\n".join([head, summon_line(rec), care_line(rec), lean_line(rec)])

## The panel. locked_why: "" lets you swap; otherwise why you can't now (shown in place of the swap row).
## changed runs after a swap so the caller can rebuild.
static func build(host: Node, locked_why: String, changed: Callable) -> Control:
	var box := UI.vbox(6)
	box.add_child(UI.section("Riding with you  ·  %d of %d" % [COUNT, COUNT]))
	box.add_child(UI.para(rule_line()))
	var rec := Save.active_kin()
	if rec.is_empty():
		box.add_child(UI.para("No Boki can come with you right now.", UI.T_SMALL, UI.BAD))
		return box
	box.add_child(_rider(host, rec))
	if locked_why != "":
		box.add_child(UI.para(locked_why, UI.T_SMALL, UI.FAINT))
	elif choices().size() > 1:
		box.add_child(_swap_row(host, rec, changed))
	return box

static func _rider(host: Node, rec: Dictionary) -> Control:
	var card := UI.card(UI.CARD, 10, 10)
	card.set_meta("ride_uid", rec["uid"])
	var row := UI.hbox(12)
	card.add_child(row)
	var pic := KinPortrait.view(rec, host.get_tree(), PIC)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pic)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var sp: Dictionary = Data.KIN[rec["species"]]
	var nl := UI.label(Data.kin_title(String(rec["name"]), String(sp["name"])), 17, UI.INK, UI.big)
	nl.clip_text = true
	info.add_child(nl)
	info.add_child(UI.label("Level %d  ·  trust %d" % [int(rec.get("level", 1)), int(rec["trust"])], 12, UI.MUTED))
	info.add_child(UI.para(carry_line(rec), 12, KinRules.cat_color("sustain").lerp(UI.INK, 0.35)))
	info.add_child(UI.para(summon_line(rec), 12, UI.TEAL))
	info.add_child(UI.para(care_line(rec), 12, UI.GOLD))
	info.add_child(UI.para(lean_line(rec), 12, UI.MUTED))
	return card

## Your garden Boki as little portraits: click one to make it the rider.
static func _swap_row(host: Node, rec: Dictionary, changed: Callable) -> Control:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, SWAP_ROW_H)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var row := UI.hbox(6)
	sc.add_child(row)
	for r in choices():
		var uid := String(r["uid"])
		var sp: Dictionary = Data.KIN[r["species"]]
		var t := UI.tile_card(uid == String(rec["uid"]), func(): if swap(uid): changed.call(), 2, Color(sp["color"]))
		var title := Data.kin_title(String(r["name"]), String(sp["name"]))
		t.tooltip_text = tip(r, title)
		t.set_meta("swap_uid", uid)
		t.add_child(KinPortrait.view(r, host.get_tree(), SWAP_PIC))
		row.add_child(t)
	return sc
