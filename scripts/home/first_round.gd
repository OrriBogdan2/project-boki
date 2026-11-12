class_name FirstRound
extends RefCounted
## The garden games' first round (briefs/design/GARDEN.md section 5): the first time Stump Shove, Seek or
## Spark Volley is started on a save (tips on), it runs one short practice round instead: one line names
## the key, the first press (or Esc) ends it, and it pays nothing and costs nothing. Then the real game
## starts as usual on the next press. The Dash has its own practice lap (BaseRace._practice, first_race).
## The flags sit in Save.d.tutorial (first_shove, first_seek, first_volley), set when the round starts,
## so it never comes back; old saves get it once (no migration), unless a Boki already remembers the game.

const DONE := "That was the practice. Start again for the real one"

## True when this game's practice round is due: tips on, not a clean-HUD shot, not yet offered, never played.
static func due(flag: String, memory_kind: String) -> bool:
	if not Settings.get_v("tips") or Record.clean():
		return false
	if Save.d.get("tutorial", {}).get(flag, false):
		return false
	for rec in Save.d.get("roster", []):
		if rec.get("memory", []).any(func(e): return String(e.get("kind", "")) == memory_kind):
			return false
	return true

## Marks the round as offered (once per save).
static func take(flag: String) -> void:
	if not Save.d.has("tutorial"):
		Save.d["tutorial"] = {}
	Save.d["tutorial"][flag] = true

## The one line: "Practice: press E <what>  ·  ESC skips", keys through Settings.key_cap.
static func line(what: String) -> String:
	return "Practice: press %s %s  ·  %s skips" % [Settings.key_cap("interact"), what, Settings.key_cap("menu")]
