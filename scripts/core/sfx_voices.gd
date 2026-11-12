class_name SfxVoices
extends RefCounted
## Who keeps a voice when the Sfx pool or the loops are full (docs/AUDIO.md, voice priority). Every sound gets a
## rank: yours (no position, flagged mine, or within FRIEND_M of you) rank YOU, your squad's (within FRIEND_M of a
## squadmate) SQUAD, and both always play over the rest; every other sound ranks by its distance from you, the
## nearest first. A new sound with every pool voice busy takes the voice of the farthest sound ranked below it, or
## is not played (yours, with only yours playing, takes the oldest of them); the loops past LOOP_CAP pause, the
## farthest first, and sound again once there is room. Yours and your squad's loops never pause.

const YOU := -2.0                # the rank of your own sounds (any other sound's: metres from you, or SQUAD)
const SQUAD := -1.0              # the rank of your squadmates' sounds
const FRIEND_M := 0.7            # m: a sound this close to you or a squadmate is yours or theirs (inside two
                                 # bodies, Ent.r 0.4, so a rival pressed against them is not)
const LOOP_CAP := 8              # looping voices sounding at once, on top of the pool's (Sfx.POOL)
const CULL_MS := 100             # ms between loop culls (cheap: a sort of the loops, ten times a second)

## A sound that lost its voice (why: &"stolen") or got none (&"full"): for --sfx-voice-check.
signal cut(sname: String, rank: float, why: StringName)

var friends := PackedVector3Array()   # you, then your living squadmates, kept by keep_squad each match frame
var rank := PackedFloat32Array()      # per pool voice: the rank of what it plays
var sound := PackedStringArray()      # per pool voice: the sound it plays
var _cull_at := 0

func _init(pool: int) -> void:
	rank.resize(pool)
	sound.resize(pool)

## The match's frame: you and your living squadmates are the friends.
func keep_squad(hunters: Array, me: Hunter) -> void:
	friends.resize(0)
	if me == null:
		return
	friends.append(me.pos)
	for h: Hunter in hunters:
		if h != me and h.team == me.team and not h.dead:
			friends.append(h.pos)

func rank_of(pos, listener: Vector3, mine := false) -> float:
	if mine or pos == null:
		return YOU
	for i in friends.size():
		var f := friends[i]
		if Vector2(pos.x - f.x, pos.z - f.z).length_squared() < FRIEND_M * FRIEND_M:
			return YOU if i == 0 else SQUAD
	return Vector2(pos.x - listener.x, pos.z - listener.z).length()

## The pool voice for a sound of rank `r` (-1: none, the sound is not played): a free one (from `next` round
## the ring), else the farthest one ranked below it; yours with only yours playing takes `next`.
func pick(players: Array[AudioStreamPlayer], next: int, r: float, sname: String) -> int:
	var n := players.size()
	var worst := -1
	for k in n:
		var i := (next + k) % n
		if not players[i].playing:
			return i
		if worst < 0 or rank[i] > rank[worst]:
			worst = i
	if rank[worst] > r:
		cut.emit(sound[worst], rank[worst], &"stolen")
		return worst
	if r == YOU:
		cut.emit(sound[next], YOU, &"stolen")
		return next
	cut.emit(sname, r, &"full")
	return -1

## Pauses the loops past LOOP_CAP, the farthest first, and resumes the rest (loops: Sfx.loops); at most every
## CULL_MS, or now (a loop just started, so a new one never sounds over the cap).
func cull_loops(loops: Dictionary, listener: Vector3, now_too := false) -> void:
	var now := Time.get_ticks_msec()
	if now < _cull_at and not now_too:
		return
	_cull_at = now + CULL_MS
	var order := []
	for key in loops:
		var p: AudioStreamPlayer = loops[key]["p"]
		if is_instance_valid(p) and p.stream != null:
			order.append([rank_of(loops[key]["pos"], listener), p])
	order.sort_custom(func(a, b): return a[0] < b[0])
	for i in order.size():
		(order[i][1] as AudioStreamPlayer).stream_paused = i >= LOOP_CAP and order[i][0] > SQUAD

## Pool voices and loops sounding now (a paused loop is not).
static func sounding(players: Array[AudioStreamPlayer], loops: Dictionary) -> int:
	var n := 0
	for p in players:
		if p.playing: n += 1
	for key in loops:
		var lp: AudioStreamPlayer = loops[key]["p"]
		if is_instance_valid(lp) and lp.playing and not lp.stream_paused: n += 1
	return n
