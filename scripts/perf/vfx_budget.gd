class_name VfxBudget
extends RefCounted
## How many particles are on screen, against the budget (the performance pass: under 4k). The pooled
## emitters of Fx and HeroVfx hold their own caps (HeroVfx.MAX_LIVE, the bursts' amount x quality);
## this counts what really draws, for --perf-bench and the budget check.

const LIMIT := 4000      # particles drawn at once, all emitters

## Particles the visible, emitting emitters under `root` are drawing (CPU: their amount; GPU: amount x ratio).
static func live(root: Node) -> int:
	var total := 0
	for n in root.find_children("*", "GPUParticles3D", true, false):
		var g := n as GPUParticles3D
		if g.emitting and g.is_visible_in_tree():
			total += int(g.amount * g.amount_ratio)
	for n in root.find_children("*", "CPUParticles3D", true, false):
		var c := n as CPUParticles3D
		if c.emitting and c.is_visible_in_tree():
			total += c.amount
	return total
