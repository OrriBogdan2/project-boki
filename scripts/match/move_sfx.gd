class_name MoveSfx
extends RefCounted
## A Hunter's footsteps, jumps and landings, heard as in the source: placed where they happen (Sfx pans
## them) and fading with distance. What they sound like comes from the ground underfoot (StepSurface), the
## Hunter's weight class (HeroSfx: jump_/land_ light, medium, heavy) and its height (pitch). Levels are in
## content/rules/move_sfx.json: enemies louder than you so you hear them coming, quieter in a fight.
## Footsteps ride the run cycle's foot strikes (HunterAnim.stepped), silent while sneaking or unseen.
## Under steps and dashes sits each Hunter's own foley (its gear: chain, skates, wings), a row per Hunter in
## content/rules/hunter_foley.json, louder the faster it moves and capped in voices for a crowd.

static func rules() -> Dictionary:
	return Content.rules("move_sfx")

## Pitch for an archetype's height: 1.0 at the reference height (and for one not listed), lower when taller.
static func pitch(arch: String) -> float:
	var r := rules()
	var d := float((r["height_m"] as Dictionary).get(arch, r["ref_height_m"])) - float(r["ref_height_m"])
	return clampf(1.0 - d * float(r["pitch_per_m"]), float(r["pitch_min"]), float(r["pitch_max"]))

## `base` dB moved by who is moving (you, a friend, an enemy) and whether they are fighting.
static func level(h: Hunter, base: float) -> float:
	var r := rules()
	var p: Hunter = h.m.player
	var role := "ally"
	if h == p:
		role = "own"
	elif p != null and h.team != p.team:
		role = "enemy"
	var fight: bool = h.m.time - maxf(h.hurt_at, maxf(h.swing_at, h.cast_at)) < float(r["fight_s"])
	return base + float((r["role_db"] as Dictionary)[role]) + (float(r["fight_db"]) if fight else 0.0)

## The foot strike's sound on what is underfoot.
static func footstep(h: Hunter) -> void:
	var m: Match = h.m
	if m == null or m.world == null or h.unseen or h.crouch:
		return
	var surf := StepSurface.at(m.world, m.skytrain, h.pos)
	var vol := StepSurface.vol_db(h, surf, level(h, float(rules()["step_db"])))
	Sfx.play(StepSurface.cue(h, surf), h.pos, vol, 0.08, pitch(h.arch), float(rules()["step_reach_m"]))
	var speed_k := clampf(Vector2(h.vel.x, h.vel.z).length() / maxf(h.base_speed, 0.1), 0.0, 1.0)
	foley(h, "foley", "step_db", float(foley_rules()["walk_db"]) * (1.0 - speed_k), float(rules()["step_reach_m"]))

## A dash's foley: the Hunter's gear whipping along.
static func dash(h: Hunter) -> void:
	foley(h, "foley_dash", "dash_db", 0.0)

static func foley_rules() -> Dictionary:
	return Content.rules("hunter_foley")

## The row of foley data for archetype `arch` (empty if it has none).
static func foley_row(arch: String) -> Dictionary:
	return (foley_rules()["rows"] as Dictionary).get(arch, {})

static var foley_ms: Array[int] = []     # when the latest foley sounds started (the voice cap's window)

## `h`'s foley `kind` ("foley" or "foley_dash") at `row_key` + `trim_db` dB, placed at it and out to `reach`
## (0 = the usual). At most voice_cap start per voice_window_ms across everyone.
static func foley(h: Hunter, kind: String, row_key: String, trim_db: float, reach := 0.0) -> void:
	var row := foley_row(h.arch)
	var cue := HeroSfx.of(h, kind, "")
	if row.is_empty() or cue == "":
		return
	var carry := reach if reach > 0.0 else Sfx.hear_range
	if Vector2(h.pos.x - Sfx.listener.x, h.pos.z - Sfx.listener.z).length() > carry:
		return
	var fr := foley_rules()
	var now := Time.get_ticks_msec()
	while not foley_ms.is_empty() and now - foley_ms[0] > int(fr["voice_window_ms"]):
		foley_ms.pop_front()
	if foley_ms.size() >= int(fr["voice_cap"]):
		return
	foley_ms.append(now)
	Sfx.play(cue, h.pos, level(h, float(fr["base_db"]) + float(row[row_key]) + trim_db), 0.08, pitch(h.arch), reach)

## A landing at `vol_db`: the weight class's thud with the ground's step under it.
static func land(h: Hunter, vol_db: float) -> void:
	_weighted(h, "land", vol_db, 1.0)

## A jump's push at `vol_db` (`pitch_mul` for the air jump's higher one): the class's jump, the ground's step under it.
static func jump(h: Hunter, vol_db: float, pitch_mul := 1.0) -> void:
	_weighted(h, "jump", vol_db, pitch_mul)

static func _weighted(h: Hunter, kind: String, vol_db: float, pitch_mul: float) -> void:
	var m: Match = h.m
	var vol := level(h, vol_db) + HeroSfx.class_db(h)
	var p := pitch(h.arch) * pitch_mul
	m.sfx(HeroSfx.weighted(h, kind, kind), h.pos, vol, p)
	if m.world != null:
		var surf := StepSurface.at(m.world, m.skytrain, h.pos)
		Sfx.play(StepSurface.cue(h, surf), h.pos, vol + float(rules()["surface_layer_db"]), 0.08, p)
