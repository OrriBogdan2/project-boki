extends "res://tools/remote_anim_check.gd"
## --sfx-remote-check: the kit sounds a Hunter plays on its own game play on the other player's game too.
## Two real games over the desktop relay (the --remote-anim-check harness, which this extends): the host's
## hunter casts each of its 12 kits' LMB, RMB, E, R and dash next to the guest, and both games log every
## one-shot Sfx starts (name, where). Every cue the caster's game plays must sound on the watching game
## exactly as often (no echo doubling the local sound and the net event), from where the caster stood,
## also for the moves that clear their anim id. Lines: SFXREMOTE ok|FAIL <what>, then each cast.

const NEAR_M := 3.0          # m: a cue's place on the watcher against where the caster's game put it
const PAIR := Vector3(0.0, 0, 4.0)   # the guest stands this far from the caster (m)
## Cues that are not the cast's: the walk and the ambient ones play on their own on each game.
const NOT_CAST := ["step", "land", "ping", "tick"]

var rows: Array = []      # [name, position]: every one-shot started on this game since the mark

func _init() -> void:
	tag = "SFXREMOTE"
	guest_flag = "--sfx-remote-check=guest"

func run(main_node: Node) -> void:
	Sfx.played.connect(_log)
	await super.run(main_node)

func _sample() -> void:
	if m and m.player:
		Sfx.listener = m.player.pos

func _log(sname: String, at, _db: float, _pitch: float) -> void:
	if at != null:
		rows.append([sname, at])

# ------------------------------------------------------------------ the host
func _host() -> void:
	var G := await _host_up()
	if G == null:
		return _finish()
	for arch in ARCHS:
		for key in KEYS:
			for held in ([false] if key in ["e", "r", "dash"] else [false, true]):
				await _cast_sfx(arch, key, held)
	_finish()

func _cast_sfx(arch: String, key: String, held: bool) -> void:
	var P := m.player
	var what := "%s %s%s" % [arch, key, " held" if held else ""]
	P.reclass(Arch.weight(arch), arch)
	P.unlock_all()
	P.lvl = 6
	_kit(arch)
	P.fire_cd = 0.0
	P.ammo = int(P.wpn.get("mag", 12))
	_clear_walls()
	replies.clear()
	Net.lobby_emit("sx", {"c": "place", "at": [home.x + PAIR.x, home.y, home.z + PAIR.z]})
	await _reply()
	_aim(P.pos + Vector3(6.0, 0, 0))
	await _run(0.5)
	Net.lobby_emit("sx", {"c": "mark"})
	await _run(0.2)
	rows.clear()
	if key == "dash":
		P.inp["dash"] = true      # (as the keyboard does: the sim takes it; _press calls do_dash outside it)
		await _run(DT)
	else:
		await _press(key, held)
	await _run(SETTLE)
	replies.clear()
	Net.lobby_emit("sx", {"c": "log"})
	await _reply()
	var theirs: Array = replies[0].get("log", []) if not replies.is_empty() else []
	var why := _diff(rows, theirs)
	n += 1
	if why != "":
		bad += 1
	var verdict := "FAIL" if why != "" else "ok  "
	print("%s %s %s: %d cues here, %d there %s" % [tag, verdict, what, rows.size(), theirs.size(), why])

## "" when the watcher's cues match the caster's, else what differs: a cue it never played, one it played
## more often than the caster's game did, or one played away from where the caster's game put it.
func _diff(mine: Array, theirs: Array) -> String:
	var want := {}
	for r in mine:
		if _counts(r):
			want[r[0]] = want.get(r[0], []) + [r[1]]
	var got := {}
	for r in theirs:
		if _counts(r):
			got[r[0]] = got.get(r[0], []) + [_v(r[1])]
	var out: Array = []
	for name in want:
		var places: Array = got.get(name, [])
		if places.is_empty():
			out.append("%s missing" % name)
		elif places.size() > want[name].size():
			out.append("%s x%d (caster x%d)" % [name, places.size(), want[name].size()])
		else:
			for p: Vector3 in places:
				if want[name].all(func(w): return Vector2(w.x - p.x, w.z - p.z).length() > NEAR_M):
					out.append("%s at %s, caster's at %s" % [name, _s(p), _s(want[name][0])])
					break
	return "" if out.is_empty() else ("[" + "; ".join(out) + "]")

func _counts(r: Array) -> bool:
	return not NOT_CAST.any(func(w): return String(r[0]).contains(w))

## The walls an earlier cast left (Dolm's rocks) end with a sound on each game: they go before the next cast.
func _clear_walls() -> void:
	for w in m.verbs.walls.duplicate():
		m.verbs._break_wall(w)

# ------------------------------------------------------------------ the guest
func _on_msg(topic: String, data, from: String) -> void:
	if topic == "sx" and typeof(data) == TYPE_DICTIONARY and m and m.player:
		match String(data.get("c", "")):
			"place":
				var a: Array = data["at"]
				_clear_walls()
				_fresh(m.player)
				m.player.teleport(Vector3(a[0], a[1], a[2]))
				Net.lobby_emit("dn_r", {"pos": a})
			"mark":
				rows.clear()
			"log":
				var played := rows.map(func(r): return [r[0], [r[1].x, r[1].y, r[1].z]])
				Net.lobby_emit("dn_r", {"pos": [0, 0, 0], "log": played})
		return
	super._on_msg(topic, data, from)
