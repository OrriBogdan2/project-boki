class_name StealCall
extends RefCounted
## A stolen kill, said in the message lane: when the squad that did most of the damage to a worthwhile
## monster (a lair boss, an elite, a key carrier) loses the last hit to another squad, the loser reads
## "<Hunter> stole the <monster>" and the stealer reads "Stolen: <monster>", with a key mark if the
## monster carried one. Ordinary kills and kills nobody contested say nothing. The credit is the same
## as ever (Match.on_mob_dead: the Hunter, or a Boki's owner), so the XP and the drops follow it.

const LOSER_COL := Color("ff9a6a")
const STEALER_COL := Color("ffd27a")

## The squad that did most (over half) of the damage to `mb`, or -1 when no squad did.
static func top_team(mb: Mob) -> int:
	var total := 0.0
	for t in mb.damage_by:
		total += float(mb.damage_by[t])
	for t in mb.damage_by:
		if float(mb.damage_by[t]) > total * 0.5:
			return int(t)
	return -1

## The one line `viewer_team` reads for `mb` dying to `killer`, as {text, col, prio, icon, won}; {} for none.
## `won`: the viewer's squad took the kill (its sting, StealSfx).
## `carried`: it held a chest key when it died.
static func line(mb: Mob, killer: Hunter, viewer_team: int, carried: bool) -> Dictionary:
	if killer == null or (KeyBonus.mob_source(mb) == "monster" and not carried):
		return {}
	var lost := top_team(mb)
	if lost < 0 or lost == killer.team:
		return {}
	var name_txt := String(mb.md.get("name", "monster"))
	var prio := MsgLane.HIGH if mb is Boss else MsgLane.NORMAL
	var icon := "key" if carried else ""
	if viewer_team == lost:
		var text := "%s stole the %s" % [killer.pname, name_txt.trim_prefix("The ")]
		return {"text": text, "col": LOSER_COL, "prio": prio, "icon": icon, "won": false}
	if viewer_team == killer.team:
		return {"text": "Stolen: %s" % name_txt, "col": STEALER_COL, "prio": prio, "icon": icon, "won": true}
	return {}

## Called as `mb` dies, before its key drops (the carrying mark goes with the drop).
static func on_dead(m: Match, mb: Mob, killer: Ent) -> void:
	if m.hud == null or m.player == null or not killer is Hunter:
		return
	var s := line(mb, killer as Hunter, m.player.team, KeyCarry.carries(mb))
	if not s.is_empty():
		m.hud.msgs.push(s["text"], s["col"], s["prio"], 0.0, s["icon"])
		StealSfx.sting(s["won"])
