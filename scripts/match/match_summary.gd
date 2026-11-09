class_name MatchSummary
extends RefCounted
## What the results card needs from a match, collected per Hunter as it is played: assists (who hurt a
## Hunter shortly before it went down), healing (Hunter.healed), when each Hunter left, and so the
## squad's finishing place. fill() puts it all on the match result.

const ASSIST_WINDOW := 8.0   # seconds: a rival who hurt the victim this recently before the knock gets an assist
const EXTRACTED_RANK := 1.0e6   # a squad that got out beats every squad that didn't, however late the others fell

## `credit` just hurt `target`: remember it for the assist.
static func on_hurt(credit: Hunter, target: Ent, time: float) -> void:
	if target is Hunter and (target as Hunter).team != credit.team:
		(target as Hunter).hurt_by[credit] = time

## `credit` knocked `victim` down: everyone else who hurt it within the window gets an assist.
static func on_knock(victim: Hunter, credit: Hunter, time: float) -> void:
	for who in victim.hurt_by:
		if who != credit and is_instance_valid(who) and time - float(victim.hurt_by[who]) <= ASSIST_WINDOW:
			(who as Hunter).assists += 1
	victim.hurt_by.clear()

## Your squad's finishing place and how many squads started. Squads that got out beat those that were
## knocked out; within each, the one that left later is higher. Squads still in at the end count as
## the last to leave.
static func placement(hunters: Array, team: int, now: float) -> Vector2i:
	var score := {}
	for h in hunters:
		var gone: bool = h.out or h.extracted
		var left: float = h.left_at if gone else now
		if h.extracted:
			left += EXTRACTED_RANK
		score[h.team] = maxf(score.get(h.team, 0.0), left)
	var place := 1
	for t in score:
		if t != team and score[t] > score[team]:
			place += 1
	return Vector2i(place, score.size())

## Put the card's numbers on the result: your assists and healing, your Boki's summons, your place,
## and a row per squadmate.
static func fill(r: Dictionary, hunters: Array, player: Hunter, now: float) -> void:
	var p := placement(hunters, player.team, now)
	r["place"] = p.x
	r["places"] = p.y
	r["assists"] = player.assists
	r["healing"] = int(player.healed)
	r["summons"] = _summons(player.kin) + _summons(player.kin2)
	var mates: Array = hunters.filter(func(h): return h.team == player.team and h != player)
	r["squad"] = mates.map(_row)

static func _summons(k: Kin) -> int:
	return k.st_throws if k else 0

static func _row(h: Hunter) -> Dictionary:
	return {"name": h.pname, "damage": int(h.dmg_done), "knocks": h.knocks,
			"assists": h.assists, "healing": int(h.healed)}
