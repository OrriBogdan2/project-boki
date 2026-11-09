class_name MusicDir
extends RefCounted
## Drives the expedition's layered score (Sfx.play_layers, tools/compose.py LAYERS) from what's
## happening to the player: the calm bed while exploring, the drive stem when a fight is on (you hit
## or got hit lately, or a rival is close and in sight), the boss stem inside a woken boss's arena,
## and the clock stem while extracting or when the islands are about to fall.
## Reads the match, never changes it.

const FIGHT_HOLD := 7.0       # seconds the fight music hangs on after the last shot traded
const RIVAL_NEAR := 13.0
var heat := 0.0               # 0..1, how much of a fight is going on
var last_fight := -99.0
var last_done := 0.0
var started := false

func start(m: Match) -> void:
	CombatBus.ability_used.connect(_ult_duck.bind(m))
	if m.tier >= 2:
		Sfx.play_music("hollow")
		return
	started = true
	Sfx.play_layers("match", {"calm": 1.0, "drive": 0.0, "boss": 0.0, "extract": 0.0})

## A rival's ultimate going off (the wind-up, the cast, or an X ult) dips the score and the beds, so the cast reads.
func _ult_duck(caster: Node, _ability: String, slot: String, m: Match) -> void:
	var rival := caster as Hunter
	if rival != null and slot in ["ult_fuse", "ult", "ultimate"] and m.player != null and rival.team != m.player.team:
		Sfx.duck_for("ult", rival.pos)

## Ambience by place, every quarter second: wind howling up from the abyss as you near an edge (or
## glide over it), the creak and grit of the old ruins among their walls, and now and then a
## creature calling from somewhere out of sight.
var amb_t := 0.0
var call_t := 12.0
var rng := RandomNumberGenerator.new()
const CALLS := ["v_warden", "v_brute", "v_sentinel", "v_spitter"]

func _ambience(m: Match, p: Hunter, dt: float) -> void:
	amb_t -= dt
	if amb_t > 0.0:
		return
	amb_t = 0.25
	var w: World = m.world
	if w == null:
		return
	var voids := 0; var walls := 0; var n := 0
	for r: float in [3.0, 6.0, 9.5]:
		for k in 10:
			var a := TAU * k / 10.0 + r
			var x := p.pos.x + cos(a) * r; var z := p.pos.z + sin(a) * r
			n += 1
			if w.is_void(x, z): voids += 1
			elif w.walls.has(w.idx(int(floorf(x)), int(floorf(z)))): walls += 1
	var abyss := clampf(float(voids) / float(n) * 1.8, 0.0, 1.0)
	if w.is_void(p.pos.x, p.pos.z) or p.gliding or p.dropping: abyss = 1.0
	Sfx.amb_layer("abyss", abyss)
	Sfx.amb_layer("ruins", clampf(float(walls) / 6.0, 0.0, 1.0))
	call_t -= 0.25
	if call_t <= 0.0:
		call_t = rng.randf_range(16.0, 34.0)
		if not p.dropping and not p.riding and m.time - last_fight > 4.0:
			var a2 := rng.randf() * TAU
			var at := p.pos + Vector3(cos(a2), 0, sin(a2)) * 15.0
			Sfx.play(CALLS[rng.randi() % CALLS.size()], at, 3.0, 0.05, rng.randf_range(0.45, 0.62))

func tick(m: Match, dt: float) -> void:
	var p: Hunter = m.player
	if p == null:
		return
	if not p.out and not p.extracted:
		_ambience(m, p, dt)
	if not started:
		return
	var calm := 1.0; var drive := 0.0; var boss := 0.0; var extract := 0.0
	if p.out or p.extracted:
		Sfx.set_layers({"calm": 0.7, "drive": 0.0, "boss": 0.0, "extract": 0.0})
		return
	if not (m.opts.get("training", false) or m.opts.get("tutorial", false)) and not p.dropping and not p.riding:
		if p.dmg_done > last_done + 0.5 or m.time - float(p.hurt_at) < 0.6:
			last_fight = m.time
		last_done = p.dmg_done
		var rival := false
		for h in m.hunters:
			if h.team != p.team and not h.out and not h.extracted and not h.unseen and p.flat_dist(h) < RIVAL_NEAR:
				rival = true; break
		var want := 1.0 if m.time - last_fight < FIGHT_HOLD else (0.65 if rival else 0.0)
		heat = move_toward(heat, want, dt * (2.0 if want > heat else 0.25))
		drive = heat
		if m.lairs and bool(m.lairs.get("music_on")):
			boss = 1.0; drive = maxf(drive, 0.8); calm = 0.6
		var left := m.length - m.time
		if p.extract_prog > 0.0 or left < 45.0:
			extract = 1.0; calm = minf(calm, 0.8)
		if p.downed:
			calm = 0.5; drive *= 0.4; boss *= 0.5
	Sfx.set_layers({"calm": calm, "drive": drive, "boss": boss, "extract": extract})
