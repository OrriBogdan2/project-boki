extends RefCounted
## --lmb-anim-sync-check: a basic attack's clip lands its strike when the shot leaves. Each Hunter in the training strip
## taps LMB (the bow draws and looses) at a dummy; the frame the round or strike spawns (a Match shot of the Hunter's,
## or the first damage) is set against the frame the attack clip's weapon hand moves fastest (Meshy's clip on its own
## skeleton, or the contract clip). The strike must come within SYNC_MS of the spawn: a clip that swings after its
## shot has gone looks late, and no attack clip may begin once the shot is already gone.
## Cinder's lance (CHANNELLED) is held: its first puff is the spawn.
## Tenzo and Kael are checked again with LMB held (HELD).

const AKCheck := preload("res://tools/archetype_check.gd")
const SYNC_MS := 50.0  # ms: the clip's strike may trail or lead the spawn by this much
const PRESS_F := 6  # frame the key goes down
const SPAN_F := 90  # frames (1.5 s) watched after the press
const DIST := 3.0  # m to the dummy
const LOOK_BACK := 12  # frames before the spawn the strike is looked for (an earlier one fails anyway)
const CHANNELLED := ["ashwick"]  # a held stream: its first puff is the spawn, the hold clip's first play the swing

## Held-LMB variants, checked again with the key held this many frames: Tenzo's lane punch, Kael's Searing Wave
const HELD := {"dolm": 40, "juggernaut": 60}

var kitchk: AKCheck
var bad := 0
var _hit := -1


func ok(cond: bool, what: String) -> void:
	if not cond:
		print("LMBSYNC FAIL ", what)
		bad += 1


func run(main: Node) -> void:
	kitchk = AKCheck.new()
	kitchk.main = main
	CombatBus.hit_landed.connect(_on_hit)
	print("LMBSYNC %-10s %-9s | spawn ms | clip start ms | strike ms | offset ms" % ["hunter", "path"])
	for arch in Arch.ORDER:
		await _hunter(String(arch))
		if HELD.has(arch):
			await _hunter(String(arch), int(HELD[arch]))
	print("LMBSYNC DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _on_hit(_by: Node, _on: Node, _amount: float, _tags: Array) -> void:
	_hit = 0


func _hunter(arch: String, hold_f := 0) -> void:
	var r := kitchk.setup(arch, DIST)
	var m: Match = r[0]
	var hunter: Hunter = r[1]
	var target: Hunter = r[2]
	var nat := hunter.model.get_node_or_null("Warden/Native") as WardenNative
	var sync := hunter.model.get_node_or_null("Warden/Sync") as Node
	for n in [nat, sync]:
		if n:
			n.set_process(false)
	var hands := _hands(nat)
	var seen := [m.shots.size(), hunter.shot_n, hunter.swing_n]
	var spawn := -1
	var start := -1
	var lead := -1.0  # s into the attack clip it started (-1: a kit move lays its clip, or the contract path)
	var prev := {}
	var speed := {}  # frame -> how far the fastest hand moved in it
	var held := hold_f
	if hold_f <= 0:
		held = 30 if hunter.wpn.has("draw") or arch in CHANNELLED else 3
	_hit = -1
	for f in SPAN_F:
		hunter.inp["fire"] = f >= PRESS_F and f < PRESS_F + held
		kitchk.aim_at(hunter, target.pos)
		target.hp = target.max_hp
		m.step(kitchk.DT)
		hunter.render(kitchk.DT, 1.0)
		for n in [nat, sync]:
			if n:
				n._process(kitchk.DT)
		if spawn < 0 and f >= PRESS_F and (_streamed(hunter) if arch in CHANNELLED else _spawned(m, hunter, seen)):
			spawn = f
		if f < PRESS_F:
			continue
		if start < 0 and nat and (nat.attack_left > 0.0 or nat.cur == "kmove" or nat.moves.upper_on):
			start = f
			lead = nat.attack_lead if nat.cur == "attack" else -1.0
		for i in hands.size():
			var p := _at(hunter.model, nat, hands[i])
			if prev.has(i):
				speed[f] = maxf(float(speed.get(f, 0.0)), p.distance_to(prev[i]))
			prev[i] = p
	var best := 0.0
	var at := -1
	var last := SPAN_F
	if arch in CHANNELLED and start >= 0:  # (the hold's loop bucks the hand on: only the clip into it counts)
		var clip := String(nat.plays[WardenNativeMoves.KEY % _hold_move()])
		last = start + ceili(nat.player.get_animation(clip).length / kitchk.DT)
	for f in speed:
		if f >= spawn - LOOK_BACK and f <= last and float(speed[f]) > best:
			best = float(speed[f])
			at = f
	if lead >= 0.0:  # the clip's own strike (a blend into it moves the hand too): where the swing lands from its start
		var rate := float(nat.d.get("attack_rate", 1.0))
		var lands := (_clip_strike(nat, String(nat.plays["attack"])) - lead) / rate
		at = start + roundi(lands / kitchk.DT)
	var ms := func(fr: int) -> float: return float(fr - PRESS_F) * kitchk.DT * 1000.0
	var off: float = (ms.call(at) - ms.call(spawn)) if at >= 0 and spawn >= 0 else INF
	var late: bool = start > spawn and spawn >= 0  # the clip begins after the shot has gone
	if true:  # (every Hunter: the stream too)
		var tag := " held" if hold_f else ""
		var msg := "%s%s: the strike is %.0f ms off the spawn (limit %.0f)"
		ok(absf(off) <= SYNC_MS + 0.5, msg % [arch, tag, off, SYNC_MS])
		ok(not late, "%s: the clip starts at %.0f ms, the shot left at %.0f" % [arch, ms.call(start), ms.call(spawn)])
	var mode := "contract"
	if nat:
		mode = "held" if hold_f > 0 else "native"
	print(
		(
			"LMBSYNC %-10s %-9s | %8.0f | %13.0f | %9.0f | %9.0f"
			% [HeroTitle.base_name(arch), mode, ms.call(spawn), ms.call(start), ms.call(at), off]
		)
	)
	m.queue_free()


## A round or strike left this frame: a Match shot, a landed hit, or the Hunter's own shot / swing counter moved.
func _spawned(m: Match, hunter: Hunter, seen: Array) -> bool:
	return m.shots.size() > seen[0] or _hit == 0 or hunter.shot_n != seen[1] or hunter.swing_n != seen[2]


## The weapon hand's bones: Meshy's (data "hand" and its twin side) or the contract rig's two hands.
func _hands(nat: WardenNative) -> Array:
	if nat:
		var h1 := nat.skel.get_bone_name(nat.hand)
		var twin := nat.skel.find_bone(h1.replace("Right", "Left") if "Right" in h1 else h1.replace("Left", "Right"))
		return [nat.hand] if twin < 0 else [nat.hand, twin]
	return [WardenGlb.BONES["hand.R"], WardenGlb.BONES["hand.L"]]


## Where a hand is in the Hunter's own frame (so a step forward does not count).
func _at(model: Node3D, nat: WardenNative, hand) -> Vector3:
	if nat:
		return nat.skel.get_bone_global_pose(int(hand)).origin
	return model.to_local((model.get_node(String(hand)) as Node3D).global_position)


## When in the clip (s) the weapon hand moves fastest, the clip sampled alone on the skeleton.
func _clip_strike(nat: WardenNative, clip: String) -> float:
	var length := nat.player.get_animation(clip).length
	var hands := _hands(nat)
	nat.player.play(clip)
	var best := 0.0
	var at := 0.0
	var prev := {}
	var t := 0.0
	while t < length:
		nat.player.seek(t, true)
		nat.player.advance(0.0)
		for i in hands.size():
			var p := _at(null, nat, hands[i])
			if prev.has(i) and p.distance_to(prev[i]) > best:
				best = p.distance_to(prev[i])
				at = t
			prev[i] = p
		t += kitchk.DT
	return at


## The stream's first puff left the Hunter's hand (Cinder's Torch Lance).
func _streamed(hunter: Hunter) -> bool:
	return hunter.ak.get("hose") != null and int(hunter.ak.hose.emitted) > 0


## The kit move a held stream shows (Cinder: "as_lance").
func _hold_move() -> String:
	return "as_lance"
