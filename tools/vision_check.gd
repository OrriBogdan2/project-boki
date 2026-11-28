extends RefCounted
## --vision-check: the sight wedge (Match.sees, shaders/vis.gdshaderinc, docs/specs/VISION_LOOK.md). The wedge is
## 90 degrees wide and the shader draws the same angle; a rival just inside its side is seen, just outside is
## not; one right behind you is (the near circle); crouching hides you at a range a standing rival is seen from;
## a hiding rival (crouched, in grass) shows no plate unless revealed, downed or a teammate; a rival out past the
## wedge's side who shoots or is hit is seen for the reveal's time inside her own soft lit circle (RevealLight), which
## fades out with it. Outside sight is a neutral grey fog in every weather (no blue behind you): the fog
## colour has no tint constant, and every lit world shader greys its light, shadow tint and ambient where fogged
## (a blue cast fails here; GPU numbers in docs/specs/VISION_LOOK.md). Never touches the save.

const WEDGE_DEG := 90.0  # degrees: a wide cone in front of you
const SIDE_IN := 40.0  # degrees off your aim: inside the cone's side (45)
const SIDE_OUT := 55.0  # degrees off your aim: outside it
const SIDE_M := 10.0  # m: how far out the side probes stand (inside VIEW_RANGE, outside the near circle)
const FAR_M := 18.0  # m: past the crouched range (14), inside the standing one (24)
const BEHIND_M := 1.5  # m: inside the near circle (NEAR_SENSE 2.0)
const REVEAL_R := 2.0  # m: a revealed rival's lit circle (docs/specs/VISION_LOOK.md)
const SHOT_REVEAL := 1.2  # s: a shot or a strike gives you away this long
const HIT_REVEAL := 1.0  # s: so does being hit
const AWAY_DEG := 130.0  # degrees off your aim: well outside the wedge
## The lit world shaders that draw the fog: each greys its light where fogged (shaders/vis.gdshaderinc)
const FOG_LIT := ["terrain", "grass", "flora", "wall", "wall_v1", "toon"]
const FOG_DARK := Vector2(0.45, 0.8)  # albedo scale outside sight: a slight dark fog, not the flat dim, not black
const FOG_GREY := Vector2(0.3, 0.8)  # grey share: clearly between own colours (0) and full grey (1)

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("VISION %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_wedge_rule()
	var m := Match.new()
	main.add_child(m)
	m.start(
		{
			"teams": 2,
			"squad": 2,
			"tier": 0,
			"length": 1e9,
			"seed": 5101,
			"no_drop": true,
			"raid": "clear"
		}
	)
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
	# the player's teammate steps out while the wedge is probed (a team shares sight)
	var mates := m.hunters.filter(func(h): return h != m.player and h.team == m.player.team)
	for h in mates:
		h.out = true
	_sight(m)
	for h in mates:
		h.out = false
	_plates(m)
	_reveal(m)
	_grey_fog(m)
	_aim_line(m)
	m.queue_free()
	print("VISION DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)


func _wedge_rule() -> void:
	var want := snappedf(cos(deg_to_rad(WEDGE_DEG * 0.5)), 0.001)
	var deg := rad_to_deg(acos(Match.VIEW_COS)) * 2.0
	ok(is_equal_approx(snappedf(Match.VIEW_COS, 0.001), want), "the wedge is %.0f degrees" % deg)
	var src := FileAccess.get_file_as_string("res://shaders/vis.gdshaderinc")
	var cos_s := str(Match.VIEW_COS)
	ok(
		src.contains("const float VIS_COS = %s;" % cos_s),
		"the shader draws the rule's wedge (VIS_COS %s)" % cos_s
	)
	var reveal_s := String.num(REVEAL_R, 1)
	ok(
		src.contains("const float VIS_REVEAL_R = %s;" % reveal_s),
		"a revealed rival's circle is %s m" % reveal_s
	)
	var near_s := String.num(Match.NEAR_SENSE, 1)
	ok(
		src.contains("const float VIS_NEAR = %s;" % near_s),
		"the shader lights the near circle (%s m)" % near_s
	)
	# owner 11-26: no line where sight meets the fog: 1.6 m+ fades and a crease-free union, never max()
	var soft := (
		src.contains("const float VIS_SOFT = 1.4;")
		and src.contains("const float VIS_NEAR_SOFT = 1.6;")
		and src.contains("return vis_union(near_v, cone);")
		and not src.contains("lit = max(lit,")
	)
	ok(soft, "the fog's edges are 1.6 m+ soft fades with no crease (no line behind you)")


## A ground point `deg` off the aim direction `a` (radians), `d` metres from the player; INF if not open ground at
## the player's height in clear line of sight.
func _spot(m: Match, pl: Hunter, a: float, deg: float, d: float) -> Vector3:
	var b := a + deg_to_rad(deg)
	var q := pl.pos + Vector3(cos(b), 0, sin(b)) * d
	if (
		m.world.is_void(q.x, q.z)
		or m.world.is_block(q.x, q.z)
		or m.world.in_bush(q.x, q.z)
		or m.in_smoke(q)
	):
		return Vector3.INF
	q.y = m.world.ground_at(q.x, q.z)
	if absf(q.y - pl.pos.y) > 0.5 or not m.world.los(pl.pos, q, pl.pos.y + 1.1):
		return Vector3.INF
	return q


func _sight(m: Match) -> void:
	var pl := m.player
	for i in 32:
		var a := TAU * i / 32.0
		var s := [
			_spot(m, pl, a, SIDE_IN, SIDE_M),
			_spot(m, pl, a, -SIDE_IN, SIDE_M),
			_spot(m, pl, a, SIDE_OUT, SIDE_M),
			_spot(m, pl, a, 0.0, FAR_M),
			_spot(m, pl, a, 180.0, BEHIND_M)
		]
		if s.has(Vector3.INF):
			continue
		pl.inp["aim"] = pl.pos + Vector3(cos(a), 0, sin(a)) * 6.0
		var both := m.sees(pl.team, s[0]) and m.sees(pl.team, s[1])
		ok(both, "%.0f degrees off your aim, %.0f m out: seen on both sides" % [SIDE_IN, SIDE_M])
		ok(not m.sees(pl.team, s[2]), "%.0f degrees off, %.0f m out: hidden" % [SIDE_OUT, SIDE_M])
		var far_ok := m.sees(pl.team, s[3]) and not m.sees(pl.team, s[3], true)
		ok(far_ok, "%.0f m ahead: seen standing, hidden crouched" % FAR_M)
		ok(m.sees(pl.team, s[4]), "%.1f m straight behind you: seen (the near circle)" % BEHIND_M)
		return
	ok(false, "an open spot for every probe round the spawn (seed 5101)")


func _plates(m: Match) -> void:
	var pl := m.player
	var foe: Hunter = null
	var mate: Hunter = null
	for h in m.hunters:
		if h != pl and h.team != pl.team and foe == null:
			foe = h
		if h != pl and h.team == pl.team and mate == null:
			mate = h
	if foe == null:
		ok(false, "a rival to read a plate on")
		return
	foe.pos = pl.pos + Vector3(4, 0, 0)
	foe.crouch = false
	var open := not m.world.in_bush(foe.pos.x, foe.pos.z) and not m.in_smoke(foe.pos)
	ok(not open or not HudPlate.hidden(m, foe), "a rival standing in the open shows a plate")
	foe.crouch = true
	ok(HudPlate.hidden(m, foe), "a crouched rival shows no plate")
	foe.reveal_t = 1.0
	ok(not HudPlate.hidden(m, foe), "a revealed rival shows one again")
	foe.reveal_t = 0.0
	foe.downed = true
	ok(not HudPlate.hidden(m, foe), "a downed rival always shows one")
	foe.downed = false
	foe.crouch = false
	var bush := _bush_near(m, pl.pos)
	if bush != Vector3.INF:
		foe.pos = bush
		ok(HudPlate.hidden(m, foe), "a rival standing in tall grass shows no plate")
	if mate:
		mate.crouch = true
		ok(not HudPlate.hidden(m, mate), "a crouched teammate keeps theirs")
		mate.crouch = false


func _bush_near(m: Match, at: Vector3) -> Vector3:
	for r in range(2, 60, 2):
		for i in 16:
			var q := at + Vector3(cos(TAU * i / 16.0), 0, sin(TAU * i / 16.0)) * r
			if m.world.in_bush(q.x, q.z):
				return q
	return Vector3.INF


## How strongly `h`'s reveal circle is drawn, with `unseen` set as Match._update_vision sets it.
func _lit(m: Match, h: Hunter) -> float:
	h.unseen = not m.can_see(m.player.team, h)
	return RevealLight.strength(m, h)


func _reveal(m: Match) -> void:
	var pl := m.player
	var foe: Hunter = null
	var mate: Hunter = null
	for h in m.hunters:
		if h.team == pl.team:
			if h != pl:
				mate = h
		elif foe == null:
			foe = h
	if mate:
		mate.out = true  # your teammate's sight would see her too
	for i in 32:
		var a := TAU * i / 32.0
		var q := _spot(m, pl, a, AWAY_DEG, SIDE_M)
		if q == Vector3.INF:
			continue
		pl.inp["aim"] = pl.pos + Vector3(cos(a), 0, sin(a)) * 6.0
		foe.teleport(q)
		foe.crouch = false
		foe.reveal_t = 0.0
		var away := "%.0f degrees off your aim, %.0f m out" % [AWAY_DEG, SIDE_M]
		ok(_lit(m, foe) == 0.0 and foe.unseen, away + ": hidden, no circle")
		foe.inp["aim"] = pl.pos
		foe.atk.fire()
		ok(
			foe.reveal_t >= SHOT_REVEAL,
			"her shot gives her away for %.1f s (%.2f)" % [SHOT_REVEAL, foe.reveal_t]
		)
		ok(_lit(m, foe) == 1.0 and not foe.unseen, "she is seen, inside her own lit circle")
		foe.reveal_t = 0.0
		foe.hurt(1.0, pl)
		ok(
			foe.reveal_t >= HIT_REVEAL and m.can_see(pl.team, foe),
			"being hit gives her away for %.1f s" % HIT_REVEAL
		)
		foe.reveal_t = RevealLight.FADE * 0.5
		ok(
			is_equal_approx(_lit(m, foe), 0.5),
			"the circle fades out over the reveal's last %.1f s" % RevealLight.FADE
		)
		foe.reveal_t = 0.0
		ok(_lit(m, foe) == 0.0 and foe.unseen, "once it runs out she is hidden again, no circle")
		if mate:
			mate.out = false
			mate.reveal_t = SHOT_REVEAL
			ok(_lit(m, mate) == 0.0, "a teammate who shoots gets no circle")
		return
	ok(false, "an open spot %.0f degrees off your aim (seed 5101)" % AWAY_DEG)


## No blue (or any hue) outside sight: the fog colour multiplies by greys only (the albedo and the light part-grey),
## and each lit world shader writes the fog share for light(), greys the light colour and the cool shadow tint there,
## and swaps the ambient for its grey.
func _grey_fog(m: Match) -> void:
	var src := FileAccess.get_file_as_string("res://shaders/vis.gdshaderinc")
	var at := src.find("vec3 vis_apply(")
	var body := src.substr(at, src.find("\n}", at) - at)
	var tints := 0
	var re := RegEx.create_from_string("vec3\\(([-0-9.]+), *([-0-9.]+), *([-0-9.]+)\\)")
	for r in re.search_all(body):
		var x := float(r.get_string(1))
		if not (
			is_equal_approx(x, float(r.get_string(2)))
			and is_equal_approx(x, float(r.get_string(3)))
		):
			tints += 1
	var greys := body.contains("vis_grey(c, vis_greyness) * vis_dark")
	ok(
		at >= 0 and tints == 0 and not src.contains("VIS_COOL") and greys,
		"the fog colour is grey only: no tint in vis_apply (%d)" % tints
	)
	ok(
		RaidLook.VIS_DARK >= FOG_DARK.x and RaidLook.VIS_DARK <= FOG_DARK.y,
		(
			"the fog is slightly dark: albedo x%.2f (%.2f-%.2f)"
			% [RaidLook.VIS_DARK, FOG_DARK.x, FOG_DARK.y]
		)
	)
	ok(
		RaidLook.VIS_GREY >= FOG_GREY.x and RaidLook.VIS_GREY <= FOG_GREY.y,
		(
			"the fog is partly grey, not full, not none: %.2f (%.2f-%.2f)"
			% [RaidLook.VIS_GREY, FOG_GREY.x, FOG_GREY.y]
		)
	)
	for n in FOG_LIT:
		var s := FileAccess.get_file_as_string("res://shaders/%s.gdshader" % n)
		var light := s.substr(s.find("void light()"))
		var greyed := (
			s.contains("vis_f = ")
			and light.contains("vis_grey(LIGHT_COLOR, vis_f)")
			and not light.contains("* LIGHT_COLOR")
		)
		var tone_ok := (
			not light.contains("* tone;") and not light.contains("DIFFUSE_LIGHT += rim_color")
		)
		var amb_ok := (
			s.contains("AO = vis_ao(vis_f)")
			and s.contains("EMISSION += vis_ambient(c, vis_f, VERTEX, INV_VIEW_MATRIX)")
		)
		ok(
			greyed and tone_ok and amb_ok,
			"%s greys its light, shadow tint, ambient and haze outside sight" % n
		)
	var amb := RaidLook.vis_amb(m.env.environment)
	ok(amb > 0.05 and amb < 2.0, "the ambient's grey is set for the fog (vis_amb %.3f)" % amb)


## The shared aim line points down the cone's centre (vis_dir = aim_dir()): a far cursor, one close to the body (inside
## the dead zone, aim_dir keeps the last good direction) and an aim lock that differs from the cursor.
func _aim_line(m: Match) -> void:
	var pl := m.player
	var saved_ak := pl.ak
	pl.out = false
	pl.downed = false
	var cases := {
		"far": Vector3(7, 0, -3), "close": Vector3(0.4, 0, 0.3), "locked": Vector3(-6, 0, 2)
	}
	var lock := GDScript.new()
	lock.source_code = "extends ArchKit\nfunc aim_lock() -> Vector2: return Vector2(0.0, 1.0)\n"
	lock.reload()
	for key in cases:
		pl.ak = lock.new() if key == "locked" else null
		pl.inp["aim"] = pl.pos + cases[key]
		m._update_aim(1.0)
		var along: Vector3 = -m.aim_line.global_transform.basis.z  # look_at aims -Z
		var line := Vector2(along.x, along.z).normalized()
		var off := rad_to_deg(line.angle_to(pl.aim_dir())) if m.aim_line.visible else 0.0
		var seen: bool = m.aim_line.visible and absf(off) < 1.0
		ok(seen, "aim line vs cone centre, %s cursor: %.2f degrees apart" % [key, off])
	pl.ak = saved_ak
