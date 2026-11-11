extends RefCounted
## --glide-trail-check: a Hunter's glide takes one GlideTrail in their team colour while the glider is open,
## and lets go of it once it folds: none in use LIFE + 0.1 s after. A second glide reuses the pooled trail
## (no node made), and a Hunter on the ground or folded never has one.

const LIFT_M := 12.0           # m up: room for OPEN_S of gliding before the ground
const OPEN_S := 1.0            # s the glider is held open
const GAP_S := GlideTrail.LIFE + 0.1
const COL_EPS := 0.02

var bad := 0
var flow := preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("GLIDETRAIL FAIL %s" % what)
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var m: Match = flow._match(main, Arch.ORDER[0])
	var gt := GlideTrail.of(m)
	gt.set_process(false)
	var h: Hunter = flow.hunter
	for o in m.hunters:
		if o != h:
			o.out = true
	await _steps(main, m, gt, 0.5)
	ok(gt.live() == 0, "a Hunter on the ground has a trail")
	for n in 2:
		await _glide(main, m, gt, h, n + 1)
	print("GLIDETRAIL DONE, failures: %d" % bad)
	main.get_tree().quit()

func _glide(main: Node, m: Match, gt: GlideTrail, h: Hunter, nth: int) -> void:
	h.pos += Vector3(0, LIFT_M, 0)
	h.grounded = false
	h.coyote = 0.0
	await _steps(main, m, gt, 2 * Match.DT)        # (a glide from GROUNDED is refused)
	h.inp["glide"] = true
	await _steps(main, m, gt, OPEN_S)
	var opened := h.gliding
	var live_open := gt.live()
	var col := _ribbon_col(gt)
	h.inp["glide"] = false
	await _steps(main, m, gt, Match.DT)
	var folded := not h.gliding
	await _steps(main, m, gt, GAP_S)
	var want: Color = Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()].lerp(Color.WHITE, GlideTrail.LIGHTEN)
	print("GLIDETRAIL glide %d: opened %s, trails open %d, folded %s, left %d, made %d" % [
		nth, opened, live_open, folded, gt.live(), gt.made()])
	ok(opened, "glide %d: the glider never opened" % nth)
	ok(live_open == 1, "glide %d: %d trails while one glider is open" % [nth, live_open])
	var cols := [col.to_html(false), want.to_html(false)]
	ok(_same(col, want), "glide %d: the ribbon is %s, not the team colour %s" % [nth, cols[0], cols[1]])
	ok(folded, "glide %d: the glider never folded" % nth)
	ok(gt.live() == 0, "glide %d: the trail is still in use %.1f s after the fold" % [nth, GAP_S])
	ok(gt.made() == 1, "glide %d: %d trail nodes made for one glider" % [nth, gt.made()])

func _steps(main: Node, m: Match, gt: GlideTrail, secs: float) -> void:
	for i in maxi(1, roundi(secs / Match.DT)):
		m.step(Match.DT)
		m.player.render(Match.DT, 1.0)     # (the match draws in _process, which a check does not run)
		gt.step(Match.DT)
	await main.get_tree().process_frame

## The colour of the first vertex of the one trail in use (Color.BLACK when none is drawn).
func _ribbon_col(gt: GlideTrail) -> Color:
	for c in gt.get_children():
		var mi := c as MeshInstance3D
		var im := mi.mesh as ImmediateMesh
		if mi.visible and im.get_surface_count() > 0:
			var cols: PackedColorArray = im.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			return cols[0]
	return Color.BLACK

func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < COL_EPS and absf(a.g - b.g) < COL_EPS and absf(a.b - b.b) < COL_EPS
