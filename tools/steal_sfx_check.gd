extends RefCounted
## --steal-sfx-check: the prize-monster cues (StealSfx, ticked in Mob.sim / Boss.sim). An elite cries once (its
## voice kind's steal_cry_<kind>) the first frame it is at or under StealSfx.CRY_AT of its health and never again;
## each new reel (stagger) plays steal_reel once; a plain monster plays neither; the files exist. Never touches
## the save.

const DT := 1.0 / 60.0

var bad := 0
var m: Match


func ok(cond: bool, what: String) -> void:
	print("STEALSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _heard(n: String) -> int:
	return (Sfx.recent.get(n, []) as Array).size()


func _clear() -> void:
	for n in Sfx.recent.keys():
		if String(n).begins_with("steal_"):
			Sfx.recent.erase(n)
			Sfx.last_played.erase(n)


func _frames(mob: Mob, n: int) -> void:
	for i in n:
		mob.sim(DT)


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 17, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var at: Vector3 = m.player.pos + Vector3(5, 0, 0)
	Sfx.listener = m.player.pos
	for k in StealSfx.CRY_KINDS:
		ok(FileAccess.file_exists("res://audio/steal_cry_%s.wav" % k), "steal_cry_%s.wav exists" % k)
	ok(FileAccess.file_exists("res://audio/steal_reel.wav"), "steal_reel.wav exists")

	# (a) an elite skitter: one cry at the quarter mark, none after; one thud per reel
	var elite := m.spawn_mob("skitter", at)
	elite.rarity = 3
	ok(StealSfx.prize(elite), "(a) a rarity-3 skitter is a prize (%s)" % KeyBonus.mob_source(elite))
	_clear()
	elite.hp = elite.max_hp * 0.5
	_frames(elite, 5)
	ok(_heard("steal_cry_skitter") == 0, "(a) no cry at half health")
	elite.hp = elite.max_hp * StealSfx.CRY_AT
	_frames(elite, 5)
	ok(_heard("steal_cry_skitter") == 1, "(a) one cry at the quarter mark (%d)" % _heard("steal_cry_skitter"))
	_clear()
	elite.hp = elite.max_hp * 0.1
	_frames(elite, 30)
	ok(_heard("steal_cry_skitter") == 0, "(a) no second cry lower down")
	_clear()
	elite.stagger_t = 0.5
	_frames(elite, 3)
	ok(_heard("steal_reel") == 1, "(a) one thud as it starts to reel (%d)" % _heard("steal_reel"))

	# (b) a plain skitter: nothing
	var plain := m.spawn_mob("skitter", at + Vector3(0, 0, 4))
	plain.rarity = 0
	_clear()
	plain.hp = plain.max_hp * 0.1
	plain.stagger_t = 0.5
	_frames(plain, 5)
	var any := 0
	for n in Sfx.recent.keys():
		if String(n).begins_with("steal_"):
			any += (Sfx.recent[n] as Array).size()
	ok(not StealSfx.prize(plain) and any == 0, "(b) a plain skitter: no cry, no thud (%d)" % any)

	print("STEALSFX %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad else 0)
