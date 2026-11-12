extends RefCounted
## --impact-check: how a hit lands on each Hunter with clips (docs/DASHES_AND_ABILITY_FEEL.md §5.4, the impact pass;
## Gil's rig has no clips yet and is skipped, as in --clip-check).
## A plain attacker hits a Hunter of each kit from range, in a fight that doesn't involve the player (the per-body
## path every online hit takes), and the check reads what the body does:
##   1. the hold is the hit's ImpactWeight tier alone: a light hit holds the body hold_s("light"), a repeat inside
##      repeat_s its repeat_k share, a heavy hit hold_s("heavy"); a ranged attacker never holds;
##   2. the hit flash reaches the model's materials on the next frame;
##   3. while the body is held its pose holds (the strike frame), then it plays on;
##   4. light hits only flinch (a rifle stream would look stun-locked); a staggering hit plays the hit clip;
##   5. a knockback shows the hit pose for as long as the shove slides the body;
##   6. a stun shows the stun clip, even over a move the kit was playing;
##   7. the player's own LMB from 1.8 m (the strike frame per Hunter): the struck body holds; a ranged weapon never
##      holds its shooter.
## --impact-shots --shots-dir=<dir> [--wardens=a,b]: the same strike (a heavy hit on a standing Hunter) and stun (over
## its first kit move) in the renderer, <dir>/<id>_strike.png and <id>_stun.png, frames 1/30 s apart. Needs a renderer.
## Never touches the save.

const DT := 1.0 / 60.0
const CHIP := 0.03          # share of max health: a rifle round (light)
const HEAVY := 0.2          # share of max health: a staggering hit; as a payoff it lands heavy
const SHOT_HEROES := ["gunslinger", "juggernaut", "archer", "ashwick"]     # --impact-shots default: Vex, Kael, Lace, Cinder
const SHOT_FRAMES := 16     # strip frames, every other 60 Hz step
const SHOT_PX := 256        # px: one strip frame (a square from the middle of the screen)
const SHOT_ROW := 8         # frames per strip row

var bad := 0
var shots := ""             # --impact-shots: where the strips go ("" = the check)
var film: Array = []        # the frames of the strip being shot

func ok(cond: bool, what: String) -> void:
	print("IMPACT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node, mode: String = "check") -> void:
	Save.no_write = true
	var heroes: Array = Arch.ORDER
	if mode == "shots":
		heroes = SHOT_HEROES
		for a in OS.get_cmdline_user_args():
			if String(a).begins_with("--shots-dir="):
				shots = String(a).trim_prefix("--shots-dir=")
			elif String(a).begins_with("--wardens="):
				heroes = Array(String(a).trim_prefix("--wardens=").split(","))
		DirAccess.make_dir_recursive_absolute(shots)
	for hero in heroes:
		if not WardenClips.data(WardenGlb.art(String(hero))).has("loco"):
			print("IMPACT skip %s: no clips yet (the rig's poses drive it)" % hero)
			continue
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

## The hit clip owns the body: the upper layer or the full-body action plays one of the data's hit clips (the
## additive flinch of a light hit doesn't count).
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
	var hx := int(floor(P.pos.x))
	var hz := int(floor(P.pos.z))
	var hi: int = w.idx(hx, hz)
	var lv: int = int(w.level[hi]) if w.kind[hi] != World.T_VOID else 0
	for dz in range(-4, 16):
		for dx in range(-8, 16):
			if not w.inb(hx + dx, hz + dz): continue
			var i: int = w.idx(hx + dx, hz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = lv
			w.island[i] = w.island[hi]
			w.stairs.erase(i)
			w.walls.erase(i)
			w.props.erase(i)
			w.bush.erase(i)
	var home := Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	P.teleport(home)
	P.vel = Vector3.ZERO
	return home

## The player's own LMB on the hitter, parked 1.8 m in front: what it holds (the game's freeze for the player,
## the struck body's own hold).
func _strike(m: Match, P: Hunter, A: Hunter, hero: String) -> void:
	var a_at := A.pos
	A.teleport(P.pos + Vector3(0, 0, -1.8))
	A.vel = Vector3.ZERO
	A.hp = A.max_hp
	P.inp["aim"] = A.pos + Vector3(0, 0.9, 0)
	var top_p := 0.0
	var top_a := 0.0
	var hp0 := A.hp
	for i in 50:
		P.inp["fire"] = i < 30
		m.hitstop = 0.0
		m.step(DT)
		top_p = maxf(top_p, m.hitstop)
		top_a = maxf(top_a, A.freeze_t)
	P.inp["fire"] = false
	var melee := bool(P.wpn.get("melee", false))
	var w := ImpactWeight.of_ability(hero, "lmb")
	var what := "%s's LMB (%s, %s): hit %s, you hold %.3f s, the target %.3f s" % [
			hero, "melee" if melee else "ranged", w, A.hp < hp0, top_p, top_a]
	ok(A.hp < hp0 and top_a > 0.0 and top_a <= ImpactWeight.hold_s(w) + 0.002 and (melee or top_p <= 0.0),
			"%s (the struck body holds its tier; a ranged hit never holds you)" % what)
	m.hitstop = 0.0
	A.teleport(a_at)
	A.hp = A.max_hp
	_settle(m, [A], 30)

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
		x.armor = 0.0
		x.max_armor = 0.0
	var hs := [V, A]
	_settle(m, hs, 30)
	var c := _clips(V)
	ok(c != null, "%s: wears its clips" % hero)
	if c != null and shots != "":
		await _shoot(m, V, A, hs, hero)
	elif c != null:
		_impact(m, P, V, A, hs, hero, c)
	m.queue_free()
	await main.get_tree().process_frame

func _impact(m: Match, P: Hunter, V: Hunter, A: Hunter, hs: Array, hero: String, c: WardenClips) -> void:
	var mh := V.max_hp
	var light := ImpactWeight.hold_s("light")
	var heavy := ImpactWeight.hold_s("heavy")
	# 1. the hold from the hit's weight alone
	V.hp = mh
	V.hurt(mh * CHIP, A, {"src": "primary"})
	var chip_t := V.freeze_t
	ok(absf(chip_t - light) < 0.002, "%s: a light hit holds the body %.3f s (light %.3f)" % [hero, chip_t, light])
	ok(A.freeze_t <= 0.0, "%s: a ranged attacker never holds (%.3f s)" % [hero, A.freeze_t])
	var shown_chip := false
	var flash := 0.0
	for i in 6:
		_frame(m, hs)
		flash = maxf(flash, _flash_of(V))
		shown_chip = shown_chip or _hit_shown(c)
	ok(flash > 0.5, "%s: the hit flash reaches the model (%.2f)" % [hero, flash])
	V.hurt(mh * CHIP, A, {"src": "primary"})
	var share := light * ImpactWeight.cap("repeat_k")
	ok(absf(V.freeze_t - share) < 0.002, "%s: a repeat inside %.2f s holds %.3f s (%.3f)" % [
			hero, ImpactWeight.cap("repeat_s"), share, V.freeze_t])
	for i in 12:
		_frame(m, hs)
		shown_chip = shown_chip or _hit_shown(c)
	ok(not shown_chip, "%s: light hits only flinch (the hit clip waits for a staggering hit)" % hero)
	_settle(m, hs, 60)
	# 2-4. a heavy hit: the pose holds through the hold, then the hit clip plays
	V.hp = mh
	V.inp["move"] = Vector2.ZERO
	_frame(m, hs)
	V.hurt(mh * HEAVY, A, {"src": "primary", "payoff": true})
	var heavy_t := V.freeze_t
	ok(absf(heavy_t - heavy) < 0.002, "%s: a heavy hit holds the body %.3f s (heavy %.3f)" % [hero, heavy_t, heavy])
	_frame(m, hs)
	var p0 := _pose(c)
	_frame(m, hs)
	var held := _pose(c).distance_to(p0) < 0.0005
	ok(held, "%s: the pose holds on the strike frame while the hold runs" % hero)
	var shown_heavy := false
	for i in 20:
		_frame(m, hs)
		shown_heavy = shown_heavy or _hit_shown(c)
	ok(shown_heavy, "%s: a staggering hit plays the hit clip" % hero)
	ok(_pose(c).distance_to(p0) > 0.0005, "%s: the body plays on after the hold" % hero)
	_settle(m, hs, 60)
	# 5. a knockback: the hit pose holds while the shove slides the body
	V.hp = mh
	V.hurt(1.0, A, {"src": "primary", "kb": Vector2(-14.0, 0.0)})
	var slid := 0
	var posed := 0
	for i in 30:
		_frame(m, hs)
		if V.knock_t > 0.0 and V.freeze_t <= 0.0:      # (the hold keeps the frame the shove landed on)
			slid += 1
			if _hit_shown(c): posed += 1
	ok(slid > 0 and posed >= slid - 2,
			"%s: a knockback shows the hit pose while it slides (%d of %d frames)" % [hero, posed, slid])
	_settle(m, hs, 30)
	_strike(m, P, A, hero)
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
	print("IMPACT %s light %.3f s, heavy %.3f s, flash %.2f, pose held %s, light clip %s, heavy clip %s, knock %d/%d" % [
			hero, chip_t, heavy_t, flash, held, shown_chip, shown_heavy, posed, slid])

# ------------------------------------------------------------------ --impact-shots
## The strike: two frames standing, then a heavy hit (the held frames, then the hit clip). The stun: its first kit
## move, stunned 0.1 s in.
func _shoot(m: Match, V: Hunter, A: Hunter, hs: Array, hero: String) -> void:
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.fov = 35.0
	cam.position = V.pos + Vector3(4.2, 3.4, 5.6)
	cam.look_at(V.pos + Vector3(0, 1.1, 0))
	cam.make_current()
	_settle(m, hs, 30)
	film.clear()
	for i in 4:
		await _shot_frame(m, hs, i)
	V.hurt(V.max_hp * HEAVY, A, {"src": "primary", "payoff": true})
	for i in range(4, SHOT_FRAMES * 2):
		await _shot_frame(m, hs, i)
	_sheet().save_png(shots.path_join("%s_strike.png" % hero))
	_settle(m, hs, 60)
	var moves: Array = (_clips(V).d.get("kmoves", {}) as Dictionary).keys()
	if moves.is_empty():
		return
	film.clear()
	V.ak.play(String(moves[0]))
	for i in 6:
		await _shot_frame(m, hs, i)
	V.hurt(1.0, A, {"src": "primary", "stun": 0.6})
	for i in range(6, SHOT_FRAMES * 2):
		await _shot_frame(m, hs, i)
	_sheet().save_png(shots.path_join("%s_stun.png" % hero))
	print("IMPACT shots %s: strike, stun over %s" % [hero, moves[0]])

## One 60 Hz step; every other one goes on the strip.
func _shot_frame(m: Match, hs: Array, i: int) -> void:
	_frame(m, hs)
	await RenderingServer.frame_post_draw
	if i % 2 == 1:
		var img := m.get_viewport().get_texture().get_image()
		var side := mini(img.get_width(), img.get_height())
		var sq := img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
		sq.resize(SHOT_PX, SHOT_PX, Image.INTERPOLATE_LANCZOS)
		film.append(sq)

func _sheet() -> Image:
	var rows := ceili(float(film.size()) / SHOT_ROW)
	var out := Image.create(SHOT_PX * SHOT_ROW, SHOT_PX * rows, false, (film[0] as Image).get_format())
	for i in film.size():
		out.blit_rect(film[i], Rect2i(0, 0, SHOT_PX, SHOT_PX), Vector2i((i % SHOT_ROW) * SHOT_PX, (i / SHOT_ROW) * SHOT_PX))
	return out
