extends "res://tools/archetype_check.gd"
## --ult-pose-check: every Hunter's R pose against its cast lock (docs/heroes/ults.md). Each Hunter casts R in the
## flat training strip with the walk key held the whole time, the model rendered through its clips. The lock is
## measured from the kit (a cast lock, busy, or the walk slowed by the cast) and must match the table. While it
## lasts, the R move owns the body or the upper body (never the bare walk cycle); once it is over, a walking Hunter's
## legs are back on the walk within HAND_BACK (never a full-body pose frozen over a free walk), and a move the kit
## ended (anim_id "") leaves no pose behind. Prints one ULTPOSE line a Hunter. Never touches the save.

const BLEND_IN := 0.12      # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const HAND_BACK := 0.2      # s past the lock the legs are back (WardenClips.FADE_LOCO 0.16 + 2 frames)
const LOCK_TOL := 0.05      # s: the measured lock may be off the table by this (three ticks)
const RUN := 7.0            # s watched after the press (Meeko's channel is 5 s, then its end clip)
const TURN := 1.0           # rad/s: the held walk circles (r about 5 m) so it never leaves the strip
## s each R commits the caster (no walk, or a cast-slowed walk), from docs/heroes/ults.md "Ours"; absent: no lock.
const LOCK := {
	"juggernaut": 1.1,      # Kael: 0.65 guard + 0.1 strike + 0.35 recovery at half speed
	"bulwark": 0.6,         # Albert: 0.4 wind-up + 0.2 slam, planted
	"dredge": 2.0,          # Grimble: walks at 30% in the charge, 20% while firing (an owner rule)
	"rimewright": 3.5,      # Neve: the frost statue
	"mage": 2.5,            # Sparkle: 0.3 crouch, 0.3 rise, 1.7 hover, 0.2 drop
	"ostra": 1.0,           # Motley: the dome telegraph
}

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for id in Arch.ids():
		if WardenClips.data(WardenGlb.art(String(id))).has("loco"):     # (Gil has no clips and no R)
			await _hero(String(id))
	print("ULTPOSE DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _frame(m: Match, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	var sync: Node = P.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)

func _hero(id: String) -> void:
	var r := setup(id, 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: ArchKit = P.ak
	if P.model == null or not P.model.has_node("Warden/Sync"):
		ok("%s ult pose: wears its clips" % id, false)
		return
	var clips: WardenClips = P.model.get_node("Warden/Sync").get("clips")
	for i in 20:
		_frame(m, P)
	HunterKeys.ult_pressed(P)
	var lock_end := 0.0
	var bare: Array = []        # ticks of the lock showing no R pose (the walk cycle while locked)
	var frozen: Array = []      # ticks a free walking Hunter is held in a full-body pose
	var stale: Array = []       # ticks a move the kit ended still shows
	var ended_at := -1.0
	var t := 0.0
	while t < RUN:
		P.inp["move"] = Vector2(sin(t * TURN), cos(t * TURN))
		var was := P.pos
		_frame(m, P)
		t += DT
		var speed := Vector2(P.pos.x - was.x, P.pos.z - was.z).length() / DT
		var full := clips.act_w > 0.5 or (clips.proc_w > 0.5 and not P.anim.km.is_empty())
		var shown := full or clips.up_w > 0.5
		var cast := K.cast_locked() or K.busy() or K.move_k() < 0.99
		if cast:
			lock_end = t
			if t >= BLEND_IN and not shown:
				bare.append(snappedf(t, 0.01))
		elif full and P.grounded and speed >= WardenClips.STILL and t >= maxf(lock_end + HAND_BACK, BLEND_IN):
			frozen.append(snappedf(t, 0.01))
		if K.anim_id != "":
			ended_at = -1.0
		elif ended_at < 0.0:
			ended_at = t
		if ended_at >= 0.0 and t >= ended_at + HAND_BACK and (clips.act_w > 0.5 or clips.up_w > 0.5):
			stale.append(snappedf(t, 0.01))
	var want := float(LOCK.get(id, 0.0))
	print("ULTPOSE %s lock %.2f s (table %.2f)" % [id, lock_end, want])
	ok("%s ult lock: %.2f s as ults.md has it" % [id, want], absf(lock_end - want) <= LOCK_TOL, "%.2f s" % lock_end)
	ok("%s ult pose: committed for the whole lock" % id, bare.is_empty(), "bare at %s" % str(bare.slice(0, 4)))
	ok("%s ult pose: lets go once free (walks, no frozen pose)" % id, frozen.is_empty(),
			"frozen at %s" % str(frozen.slice(0, 4)))
	ok("%s ult pose: an ended move leaves nothing behind" % id, stale.is_empty(),
			"stale at %s" % str(stale.slice(0, 4)))
	m.queue_free()
	await main.get_tree().process_frame
