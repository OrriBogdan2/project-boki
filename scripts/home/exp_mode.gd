class_name ExpMode
extends RefCounted
## The expedition panel's extraction mode: Solo (every hunter for themselves) or Trios. The pick is
## Save.d["exp_mode"] ("solo" or "trio", trio when unset) and survives restarts.

const TEXT := {"solo": "30 hunters, every one for themselves", "trio": "10 squads of three"}      # Data.MATCH_PLAYERS

static func is_solo() -> bool:
	return Save.d.get("exp_mode", "trio") == "solo"

## The team and squad counts the match starts with (Data.MATCH_PLAYERS hunters either way).
static func opts() -> Dictionary:
	if is_solo():
		return {"teams": Data.MATCH_PLAYERS, "squad": 1}
	return {"teams": int(ceil(Data.MATCH_PLAYERS / 3.0)), "squad": 3}
