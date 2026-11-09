class_name ParticleCount
extends RefCounted
## How many particles the scene is drawing: the VFX budget (docs/PERF.md, under 4,000 on screen at once) is
## counted here, by --perf-bench and --particle-budget-check.

## A CPU emitter built for the full look, cut to the preset in effect: fewer particles that live shorter
## (Settings.QUALITY fx and fx_life; High and Ultra leave it as it is).
static func tune(p: CPUParticles3D) -> void:
	var life := float(Settings.q("fx_life"))
	p.amount = maxi(2, int(round(p.amount * float(Settings.q("fx")))))
	p.lifetime *= life
	p.preprocess *= life

## A GPU emitter simulates amount x amount_ratio particles whether or not it is on screen; a CPU one amount.
static func of(n: Node) -> int:
	if n is GPUParticles3D:
		return int(round((n as GPUParticles3D).amount * (n as GPUParticles3D).amount_ratio))
	return (n as CPUParticles3D).amount

## Particles of every emitting emitter under root, by "parent/name" with the numbering stripped.
static func by_owner(root: Node) -> Dictionary:
	var by := {}
	for cls in ["GPUParticles3D", "CPUParticles3D"]:
		for n in root.find_children("*", cls, true, false):
			if not n.get("emitting") or not (n as Node3D).is_visible_in_tree():
				continue
			var key := "%s/%s" % [_owner(n), String(n.name).rstrip("0123456789@")]
			by[key] = int(by.get(key, 0)) + of(n)
	return by

## The nearest ancestor with a name of its own (the engine names the rest "@Node3D@12").
static func _owner(n: Node) -> String:
	var up := n.get_parent()
	while up != null and String(up.name).begins_with("@"):
		up = up.get_parent()
	return String(up.name).rstrip("0123456789") if up != null else ""

static func total(by: Dictionary) -> int:
	return by.values().reduce(func(a, b): return a + b, 0)
