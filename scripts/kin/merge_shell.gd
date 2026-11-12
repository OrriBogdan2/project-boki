class_name MergeShell
extends RefCounted
## The shell: health the merge gives on top of your own (docs/decisions/0003). It starts when the form
## goes live, by weight class (content/rules/merge_forms.json shell_base) times the form's `shell_k`.
## Damage hits the shell first and never touches your health while it stands; a hit that breaks it is
## swallowed whole. When it breaks the merge ends early (no ultimate) and the Boki pops out beside you.
## The values live in Hunter.merge_st {shell, shell_max}; other games get them in the hunter snapshot (KinNet).

static func size_for(cls: String, form: Dictionary) -> float:
	var base: Dictionary = MergeForm.data()["shell_base"]
	var k := float((form["def"] as Dictionary).get("shell_k", 1.0))
	return roundf(float(base.get(cls, base["medium"])) * k)

## The form went live: raise the shell.
static func start(h: Hunter) -> void:
	var st: Dictionary = h.merge_st
	var mx := size_for(h.cls, st["form"])
	st["shell"] = mx
	st["shell_max"] = mx

## [current, max] of the shell this hunter wears ([0, 0] when none). Remote hunters read the synced meta.
static func view(h: Hunter) -> Vector2:
	if not h.merge_st.is_empty():
		return Vector2(float(h.merge_st.get("shell", 0.0)), float(h.merge_st.get("shell_max", 0.0)))
	return Vector2(float(h.get_meta("shell", 0.0)), float(h.get_meta("shell_max", 0.0)))

## Hunter._mitigate: the hit goes into the shell first. Returns what is left for the rest of the defences (0 while it holds).
## Falls and heat go through (as they do past a kin shield). A hit the shell took still counts as a hit
## (truces, extraction interrupts): the caller gets opts["soaked"] and a token 0.01 instead of nothing.
static func absorb(h: Hunter, d: float, opts := {}) -> float:
	if h.merge_st.is_empty() or float(h.merge_st.get("shell", 0.0)) <= 0.0 or d <= 0.0:
		return d
	if opts.get("src", "") in ["fall", "heat"]:
		return d
	var st: Dictionary = h.merge_st
	var sh := float(st["shell"])
	var a := minf(sh, d)
	st["shell"] = sh - a
	h.flash_t = 0.06
	opts["soaked"] = a
	var col: Color = (st["form"] as Dictionary)["glow"]
	h.m.fx.number(h.pos + Vector3(0, 1.8, 0), a, col, false)
	h.m.fx.burst(h.pos + Vector3(0, 1.0, 0), col, 3, 2.5, 0.25)
	if float(st["shell"]) <= 0.0:
		KinMerge.end(h, "shell")
	return 0.0          # (Hunter._mitigate turns this into the token 0.01)
