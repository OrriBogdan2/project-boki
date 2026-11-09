extends RefCounted
## --cc-sfx-check: a status landing makes its cue once (docs/AUDIO.md, StatusSfx). Stun, root and slow go
## through Ent.hurt; Dazed, Grounded and Disoriented through KitStatus.apply. Each plays its cue on a
## fresh status and not on a refresh; a status that ran out and lands again inside the throttle stays
## silent, after it plays again; the local player's cue is louder than a foe's; every cue has its file.
## A body another game owns (the attacker's game): the hit or Net event plays the cue here too, and a
## refresh stays silent for the status's length, even past the throttle.
## The match is stepped by hand (no _process), so the timers stay where the check puts them.

var bad := 0
var m: Match
var foe: Hunter

func ok(cond: bool, what: String) -> void:
	print("CCSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	foe = m.hunters.filter(func(x): return x.team != m.player.team)[0]
	foe.hp = foe.max_hp
	Sfx.listener = foe.pos        # in earshot
	for kind in StatusSfx.CUE:
		ok(Sfx._lazy(StatusSfx.CUE[kind]), "%s has its sound file (%s)" % [kind, StatusSfx.CUE[kind]])
	for kind in ["stun", "root", "slow"]:
		_cycle(kind, func(): foe.hurt(1.0, m.player, {kind: 1.0}))
	for kind in ["rat", "gnd", "dsr"]:
		_cycle(kind, func(): KitStatus.apply(foe, kind, 2.0))
	_loudness()
	_remote()
	print("CCSFX %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## Every timer back to zero (a big hit staggers with a slow of its own, which would hide a fresh slow).
func _clear() -> void:
	foe.stun_t = 0.0
	foe.root_t = 0.0
	foe.slow_t = 0.0
	foe.cc_immune_t = 0.0
	for k in ["rat", "gnd", "dsr"]:
		foe.set_meta(k + "_until", 0.0)

## Times the cue was played since the check last cleared it (the engine's own 30 ms repeat gap is lifted).
func _plays(cue: String) -> int:
	return (Sfx.recent.get(cue, []) as Array).size()

func _hit(cue: String, act: Callable) -> int:
	Sfx.last_played.erase(cue)
	act.call()
	return _plays(cue)

## fresh -> 1; refresh -> still 1; ended and lands again inside the throttle -> 1; after the throttle -> 2.
func _cycle(kind: String, act: Callable) -> void:
	var cue: String = StatusSfx.CUE[kind]
	Sfx.recent.erase(cue)
	foe.set_meta("cc_sfx", {})
	_clear()
	ok(_hit(cue, act) == 1, "%s: a new status plays %s once" % [kind, cue])
	ok(_hit(cue, act) == 1, "%s: a refresh while it runs is silent" % kind)
	_clear()
	m.time += StatusSfx.GAP * 0.5
	ok(_hit(cue, act) == 1, "%s: ended and landed again inside %.1f s plays once in all" % [kind, StatusSfx.GAP])
	_clear()
	m.time += StatusSfx.GAP
	ok(_hit(cue, act) == 2, "%s: a new one after the throttle plays again" % kind)
	_clear()

func _loudness() -> void:
	var v := {}
	for who in [m.player, foe]:
		Sfx.recent.clear()
		Sfx.last_played.clear()
		Sfx.listener = who.pos
		who.set_meta("cc_sfx", {})
		StatusSfx.play(who, "root", 1.0)
		v[who] = Sfx.players[(Sfx.next - 1 + Sfx.POOL) % Sfx.POOL].volume_db
	ok(v[m.player] > v[foe] + 3.0, "the local victim hears it louder (%.1f dB vs %.1f dB)" % [v[m.player], v[foe]])

## The attacker's game: foe is owned elsewhere, so Ent.hurt sends the hit and KitStatus.apply the "kst".
func _remote() -> void:
	m.net_on = true
	foe.remote = true
	for kind in ["stun", "root", "slow"]:
		_remote_cycle(kind, func(): foe.hurt(1.0, m.player, {kind: 2.0}))
	for kind in ["rat", "gnd", "dsr"]:
		_remote_cycle(kind, func(): KitStatus.apply(foe, kind, 2.0))
	foe.remote = false
	m.net_on = false
	Net.out_hits.clear()
	Net.out_events.clear()

## fresh -> 1; refreshed past the throttle but inside its 2 s -> still 1; landed after it ran out -> 2.
func _remote_cycle(kind: String, act: Callable) -> void:
	var cue: String = StatusSfx.CUE[kind]
	Sfx.recent.erase(cue)
	foe.set_meta("cc_sfx", {})
	foe.set_meta("cc_sfx_until", {})
	ok(_hit(cue, act) == 1, "remote %s: the attacker hears %s" % [kind, cue])
	m.time += StatusSfx.GAP + 0.2
	ok(_hit(cue, act) == 1, "remote %s: a refresh past the throttle while it runs is silent" % kind)
	m.time += 2.2
	ok(_hit(cue, act) == 2, "remote %s: a new one after it ran out plays again" % kind)
