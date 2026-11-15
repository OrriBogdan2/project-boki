class_name NestReveal
extends RefCounted
## The moment a pair's egg appears in the Nesting Nook: a soft glow ring spreads over the nest (decor,
## not a gameplay ring), a few sparkles rise in the egg's type colour (DexView.type_col), and the egg
## wobbles once. One call per egg, all through the shared Fx pools and one tween.

const RING_R := 1.1          # m, how far the glow ring spreads (about the nest's rim)
const RING_S := 0.9          # s, how long the ring takes to spread and fade
const SPARKS := 12           # particles in the one sparkle burst
const WOBBLE := 0.2          # rad, the first tip of the wobble (each swing back is smaller)
const WOBBLE_S := 0.7        # s, the whole wobble

static func play(fx: Fx, nest: Node3D, sp: String) -> void:
	var col := DexView.type_col(DexView.type_of(sp))
	fx.ring(nest.global_position, RING_R, Color(col, 0.6), RING_S)
	# sparkles drift up slowly and hang a moment, not a blast
	var above := nest.global_position + Vector3(0, 0.5, 0)
	fx.burst(above, col.lightened(0.3), SPARKS, 1.6, 1.0, 0.6, 0.6, Vector3.UP, 45.0)
	var shell: Node3D = nest.get_node("Shell")
	var tw := shell.create_tween().set_trans(Tween.TRANS_SINE)
	for tip in [WOBBLE, -WOBBLE * 0.6, WOBBLE * 0.25, 0.0]:
		tw.tween_property(shell, "rotation:z", tip, WOBBLE_S / 4.0)
