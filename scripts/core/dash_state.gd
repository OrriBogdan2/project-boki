class_name DashState
extends RefCounted
## The dash numbers of one mover: its short-dash charges and its long (air) dash cooldown, with the
## regen tick and the spend rules. A match Hunter and the garden's Home each own one, so a Shift is
## spent, recharged and cooled down by this code in both (DECISIONS 11-11: one movement profile).

var charges := 2.0   # short dashes ready; a fraction is the next one recharging
var ex_cd := 0.0     # s until the long dash (Shift in the air, or with the charges spent) is ready

## How many short dashes a class's dodge holds (its dodge ability, else its class row).
static func base_charges(dd: AbilityDef, cdat: Dictionary) -> float:
	return float(dd.charges) if dd else float(cdat["dashes"])

## s a short dash takes to come back, before ranks, gear and kit changes.
static func base_regen(dd: AbilityDef) -> float:
	return dd.cooldown if dd else Hunter.DASH_REGEN

## s the long dash takes to come back, from a class row.
static func long_cd(cdat: Dictionary) -> float:
	return float(cdat.get("ex_cd", Hunter.EX_DASH_CD))

## A class's dodge as the garden runs it, the match's numbers at rank 1: charges, recharge, the short dash
## (speed, time) and the long one (ex_cd, ex_time, ex_dist).
static func profile(ck: String) -> Dictionary:
	var dd := Content.class_dodge(ck)
	var cdat: Dictionary = Data.CLASSES.get(ck, {})
	var out := {
		"charges": float(cdat.get("dashes", 2)), "cd": Hunter.DASH_REGEN,
		"speed": Hunter.DASH_SPEED, "time": Hunter.DASH_TIME,
		"ex_cd": long_cd(cdat),
		"ex_time": float(cdat.get("ex_time", Hunter.DASH_TIME * 1.45)),
		"ex_dist": float(cdat.get("ex_dist", 5.0)),
	}
	if dd:
		out["charges"] = dd.charges
		out["cd"] = dd.cooldown
		for e in dd.effects:
			if typeof(e) == TYPE_DICTIONARY and String(e.get("type", "")) == "dash":
				out["speed"] = float(e.get("speed", out["speed"]))
				out["time"] = float(e.get("time", out["time"]))
				break
	return out

## Recharges the charges toward `cap` (one per `regen` s; `regen` is unread at the cap) and cools the long dash.
func tick(dt: float, cap: float, regen: float) -> void:
	if charges < cap:
		charges = minf(cap, charges + dt / regen)
	ex_cd = maxf(0.0, ex_cd - dt)

## Shift takes the long dash in the air, or on the ground with no whole charge left.
func wants_long(grounded: bool) -> bool:
	return not grounded or charges < 1.0

## Spends one short dash; false (nothing spent) with none ready.
func spend_short() -> bool:
	if charges < 1.0:
		return false
	charges -= 1.0
	return true

## Starts the long dash's cooldown; false (nothing spent) while it is still cooling.
func spend_long(cd: float) -> bool:
	if ex_cd > 0.0:
		return false
	ex_cd = cd
	return true
