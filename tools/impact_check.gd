extends RefCounted
## --impact-check: how a hit lands on each of the 12 Hunters (docs/DASHES_AND_ABILITY_FEEL.md §5.4, the impact pass).
## A plain attacker hits a Hunter of each kit from range, in a fight that doesn't involve the player (the per-body
## path every online hit takes), and the check reads what the body does:
##   1. hit-stop comes from Feel's tier table alone: a chip hit holds the body Feel.HITSTOP[1], a repeat inside
##      Feel.HS_MULTI a third of it, a heavy hit (>= 15% of max health) tier 3; a ranged attacker never freezes;
##   2. the hit flash reaches the model's materials on the next frame;
##   3. while the body is frozen its pose holds (the strike frame), then it plays on;
##   4. chip hits don't replay the hit clip (a rifle stream would look stun-locked); a staggering hit plays it;
##   5. a knockback shows the hit pose for as long as the shove slides the body;
##   6. a stun shows the stun clip, even over a move the kit was playing.
## Never touches the save.

const DT := 1.0 / 60.0
const CHIP := 0.03          # share of max health: a rifle round
const HEAVY := 0.2          # share of max health: a heavy hit (Feel tier 3)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("IMPACT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for hero in Arch.ORDER:
		await _hero(main, hero)
	print("IMPACT DONE, failures: %d" % bad)
	main.get_tree().quit()

func _frame(m: Match, hs: Array) -> void:
	m.step(DT)
	for x in hs:
		(x as Hunter).render(DT, 1.0)
		if x.model and x.model.has_node("Warden/Sync"):
			var sync: Node = x.model.get_node("Warden/Sync")
			sync.set_process(false)
			sync.call("_process", DT)

func _clips(h: Hunter) -> WardenClips:
	if h.model == null or not h.model.has_node("Warden/Sync"):
		return null
	return h.model.get_node("Warden/Sync").get("clips") as WardenClips

## A fingerprint of the skeleton's pose: changes whenever any bone moves.
func _pose(c: WardenClips) -> Vector3:
	var acc := Vector3.ZERO
	for i in c.skel.get_bone_count():
		acc += c.skel.get_bone_pose_position(i) * float(i + 1)
		var q := c.skel.get_bone_pose_rotation(i)
		acc += Vector3(q.x, q.y, q.z) * float(i + 1)
	return acc

## The hit clip is on screen: the upper layer or the full-body action plays one of the data's hit clips.
func _hit_shown(c: WardenClips) -> bool:
	var hd: Dictionary = c.d.get("states", {}).get("hit", {})
	var names := [String(hd.get("front", "")), String(hd.get("back", ""))]
	return (c.up_w > 0.3 and String(c._node("anim_u").animation) in names) or (c.act_w > 0.3 and c.cur in names)

func _flash_of(h: Hunter) -> float:
	var top := 0.0
	for mt in h.mats:
		var v = (mt as ShaderMaterial).get_shader_parameter("flash") if mt is ShaderMaterial else null
		if v != null:
			top = maxf(top, float(v))
	return top

## Flat ground round the player (the victim stands 6 m off it, the hitter 9 m past that); returns the centre.
func _flat(m: Match, P: Hunter) -> Vector3:
	var w: World = m.world
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	var hi: int = w.idx(hx, hz)
	var lv: int = int(w.level[hi]) if w.kind[hi] != World.T_VOID else 0
	for dz in range(-4, 16):
		for dx in range(-8, 16):
			if not w.inb(hx + dx, hz + dz): continue
			var i: int = w.idx(hx + dx, hz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = lv
			w.island[i] = w.island[hi]
			w.stairs.erase(i); w.walls.erase(i); w.props.erase(i); w.bush.erase(i)
	var home := Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	P.teleport(home); P.vel = Vector3.ZERO
	return home

func _settle(m: Match, hs: Array, n: int) -> void:
	for i in n:
		_frame(m, hs)

func _hero(main: Node, hero: String) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
			"cls": Arch.weight(hero), "arch": hero, "weapon": Arch.signature(hero)})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var at := _flat(m, P) + Vector3(0, 0, 6)
	var V: Hunter = m.make_hunter("V", 6, Arch.weight(hero), "Victim", "idle", {}, at,
			{"arch": hero, "weapon": Arch.signature(hero)})
	var A: Hunter = m.make_hunter("A", 7, "medium", "Hitter", "idle", {}, at + Vector3(9, 0, 0), {"arch": "none"})
	for x in [V, A]:
		x.armor = 0.0; x.max_armor = 0.0
	var hs := [V, A]
	_settle(m, hs, 30)
	var c := _clips(V)
	ok(c != null, "%s: wears its clips" % hero)
	if c == null:
		m.queue_free()
		await main.get_tree().process_frame
		return
	var mh := V.max_hp
	# 1. hit-stop from Feel's tier table alone
	V.hp = mh
	V.hurt(mh * CHIP, A, {"src": "primary"})
	var chip_t := V.freeze_t
	ok(absf(chip_t - float(Feel.HITSTOP[1][1])) < 0.002, "%s: a chip hit holds the body %.3f s (Feel T1 %.3f)" % [hero, chip_t, Feel.HITSTOP[1][1]])
	ok(A.freeze_t <= 0.0, "%s: a ranged attacker never freezes (%.3f s)" % [hero, A.freeze_t])
	var shown_chip := false
	var flash := 0.0
	for i in 6:
		_frame(m, hs)
		flash = maxf(flash, _flash_of(V))
		shown_chip = shown_chip or _hit_shown(c)
	ok(flash > 0.5, "%s: the hit flash reaches the model (%.2f)" % [hero, flash])
	V.hurt(mh * CHIP, A, {"src": "primary"})
	ok(absf(V.freeze_t - float(Feel.HITSTOP[1][1]) / 3.0) < 0.002, "%s: a repeat inside %.2f s holds a third (%.3f s)" % [hero, Feel.HS_MULTI, V.freeze_t])
	for i in 12:
		_frame(m, hs)
		shown_chip = shown_chip or _hit_shown(c)
	ok(not shown_chip, "%s: chip hits don't replay the hit clip" % hero)
	_settle(m, hs, 60)
	# 2-4. a heavy hit: tier 3, the pose holds through the freeze, then the hit clip plays
	V.hp = mh
	V.inp["move"] = Vector2.ZERO
	_frame(m, hs)
	V.hurt(mh * HEAVY, A, {"src": "primary"})
	var heavy_t := V.freeze_t
	ok(absf(heavy_t - float(Feel.HITSTOP[3][1])) < 0.002, "%s: a heavy hit holds the body %.3f s (Feel T3 %.3f)" % [hero, heavy_t, Feel.HITSTOP[3][1]])
	_frame(m, hs)
	var p0 := _pose(c)
	_frame(m, hs)
	var held := _pose(c).distance_to(p0) < 0.0005
	ok(held, "%s: the pose holds while the hit-stop runs" % hero)
	var shown_heavy := false
	for i in 20:
		_frame(m, hs)
		shown_heavy = shown_heavy or _hit_shown(c)
	ok(shown_heavy, "%s: a staggering hit plays the hit clip" % hero)
	ok(_pose(c).distance_to(p0) > 0.0005, "%s: the body plays on after the hit-stop" % hero)
	_settle(m, hs, 60)
	# 5. a knockback: the hit pose holds while the shove slides the body
	V.hp = mh
	V.hurt(1.0, A, {"src": "primary", "kb": Vector2(-14.0, 0.0)})
	var slid := 0
	var posed := 0
	for i in 30:
		_frame(m, hs)
		if V.knock_t > 0.0 and V.freeze_t <= 0.0:      # (the hit-stop holds the frame the shove landed on)
			slid += 1
			if _hit_shown(c): posed += 1
	ok(slid > 0 and posed >= slid - 2, "%s: a knockback shows the hit pose while it slides (%d of %d frames)" % [hero, posed, slid])
	_settle(m, hs, 30)
	# 6. stunned mid-move: the stun clip wins
	var moves: Array = (c.d.get("kmoves", {}) as Dictionary).keys()
	var stun_clip := String(c.d.get("states", {}).get("stun", ""))
	var stunned := 0
	if not moves.is_empty():
		V.ak.play(String(moves[0]))
		_frame(m, hs)
		V.hurt(1.0, A, {"src": "primary", "stun": 0.6})
		for i in 20:
			_frame(m, hs)
			if c.cur == stun_clip and c.act_w > 0.5: stunned += 1
	ok(moves.is_empty() or stunned >= 10, "%s: stunned in its %s move, the stun clip shows (%d of 20 frames)" % [
			hero, moves[0] if moves.size() > 0 else "-", stunned])
	print("IMPACT %s chip %.3f s, heavy %.3f s, flash %.2f, pose held %s, chip clip %s, heavy clip %s, knock pose %d/%d" % [
			hero, chip_t, heavy_t, flash, held, shown_chip, shown_heavy, posed, slid])
	m.queue_free()
	await main.get_tree().process_frame
