class_name MusicDir
extends RefCounted
## Drives the expedition's layered score (Sfx.play_layers, tools/compose.py LAYERS) from what's
## happening to the player: the calm bed while exploring, the drive stem when a fight is on (you hit
## or got hit lately: InCombat, or a rival is close and in sight), the boss stem inside a woken boss's arena,
## and the clock stem while extracting or when the islands are about to fall. Three stingers mark the
## run: the last squad standing (you are in it), and the run's end (out, or taken out), each with the
## stems falling away under it. Reads the match, never changes it.

const MIN_DWELL := 2.0        # seconds the drive goal stays put once it changed (a fade-out can't flicker)
const RIVAL_NEAR := 13.0      # m: a rival this close and in sight lifts the drive layer
const RIVAL_LEAVE := 16.0     # m: ...and it takes this much distance to let go of it again (hysteresis)
const HEAT_UP := 3.0          # drive layer rise, per second (full in 0.33 s)
const HEAT_DOWN := 0.25       # drive layer fall, per second (4 s to silence)
const UNDER := 0.15           # how much of the stems is left while a sting plays
var heat := 0.0               # 0..1, how much of a fight is going on
var goal := 0.0               # where heat is heading: 1 fight, 0.65 rival close, 0 calm
var goal_at := -99.0          # match time the goal last changed
var rival_close := false
var started := false
var ended := false            # the run-end sting has played
var last_said := false        # the last-squad sting has played

func start(m: Match) -> void:
	if m.tier >= 2:
		Sfx.play_music("hollow")
		return
	started = true
	Sfx.play_layers("match", {"calm": 1.0, "drive": 0.0, "boss": 0.0, "extract": 0.0})

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
		if not p.dropping and not p.riding and not InCombat.is_in(p):
			var a2 := rng.randf() * TAU
			var at := p.pos + Vector3(cos(a2), 0, sin(a2)) * 15.0
			Sfx.play(CALLS[rng.randi() % CALLS.size()], at, 3.0, 0.05, rng.randf_range(0.45, 0.62))

## A trade lifts the goal to full at once; every other change (a fight fading, a rival coming or
## going) waits MIN_DWELL after the last one, and a fight only fades once you are out of combat (InCombat).
func _steer(now: float, fighting: bool) -> void:
	var want := 1.0 if fighting else (0.65 if rival_close else 0.0)
	if want == goal or (want < 1.0 and now - goal_at < MIN_DWELL):
		return
	goal = want
	goal_at = now

## The last squad standing is yours (Exits.on_last_team): one sting, once.
func last_squad() -> void:
	if not last_said and not ended:
		last_said = true
		Sfx.sting("last")

func tick(m: Match, dt: float) -> void:
	var p: Hunter = m.player
	if p == null:
		return
	if m.result.get("ending", false):
		if not ended:
			ended = true
			Sfx.sting("extract" if m.result.get("extracted", false) else "out")
		Sfx.set_layers({"calm": 0.0, "drive": 0.0, "boss": 0.0, "extract": 0.0})
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
		var reach := RIVAL_LEAVE if rival_close else RIVAL_NEAR
		rival_close = false
		for h in m.hunters:
			if h.team != p.team and not h.out and not h.extracted and not h.unseen and p.flat_dist(h) < reach:
				rival_close = true; break
		_steer(m.time, InCombat.is_in(p))
		heat = move_toward(heat, goal, dt * (HEAT_UP if goal > heat else HEAT_DOWN))
		drive = heat
		if m.lairs and bool(m.lairs.get("music_on")):
			boss = 1.0; drive = maxf(drive, 0.8); calm = 0.6
		var left := m.length - m.time
		if p.extract_prog > 0.0 or left < 45.0:
			extract = 1.0; calm = minf(calm, 0.8)
		if p.downed:
			calm = 0.5; drive *= 0.4; boss *= 0.5
	var under := UNDER if Sfx.sting_on() else 1.0
	Sfx.set_layers({"calm": calm * under, "drive": drive * under, "boss": boss * under, "extract": extract * under})
