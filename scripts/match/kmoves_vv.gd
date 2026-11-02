class_name KMovesVV
extends RefCounted
## Keyed full-body moves of Vireo (mage) and Venator (gunslinger): same format and channels as
## HunterAnim.KMOVES, looked up by HunterAnim.km_sample. Each is timed to the reference sheet's beats
## (briefs/hero-ref/vireo.md, venator.md; 1 frame = 0.2 s there): anticipation, an exaggerated key pose
## on the release (squash or stretch), an overshoot past it, then the settle. fl / fr place a hand from
## its shoulder (hw / rw their weight); for Vireo the right hand is the finger gun (no gun model).

const MOVES := {
	# ---------------------------------------------------------------- Vireo
	# finger bolt, left hand: the torso twists, the left arm flings straight out at the cursor (finger
	# pointed), a snap back at the release, then she settles wide with both arms out (0.8 s cadence)
	"mage_lmb_l": {"keys": [
		[0.00, {"y": -0.15}],
		[0.05, {"y": 0.55, "r": 0.06, "fl": Vector3(0.14, 0.12, -0.56), "hw": 1.0, "lw": 0.8, "legs": [0.25, -0.4, -0.1, -0.2], "sq": -0.15}],
		[0.11, {"y": 0.62, "p": 0.08, "fl": Vector3(0.12, 0.17, -0.48), "hw": 1.0, "lw": 0.8, "legs": [0.25, -0.4, -0.1, -0.2], "sq": 0.1}],
		[0.30, {"y": 0.2, "fl": Vector3(-0.22, 0.02, -0.18), "hw": 0.7, "fr": Vector3(0.22, 0.0, -0.16), "rw": 0.4, "lw": 0.5, "legs": [0.15, -0.3, 0.15, -0.3]}],
		[0.62, {}]]},
	# finger bolt, right hand (the gun hand): the twist the other way, the right arm locked out, a
	# recoil flick of the wrist upward on the release
	"mage_lmb_r": {"keys": [
		[0.00, {"y": 0.15}],
		[0.05, {"y": -0.55, "r": -0.06, "fr": Vector3(-0.14, 0.12, -0.56), "rw": 1.0, "gp": -0.1, "lw": 0.8, "legs": [-0.1, -0.2, 0.25, -0.4], "sq": -0.15}],
		[0.11, {"y": -0.62, "p": 0.08, "fr": Vector3(-0.12, 0.2, -0.47), "rw": 1.0, "gp": 0.35, "lw": 0.8, "legs": [-0.1, -0.2, 0.25, -0.4], "sq": 0.1}],
		[0.30, {"y": -0.2, "fl": Vector3(-0.22, 0.0, -0.16), "hw": 0.4, "fr": Vector3(0.22, 0.02, -0.18), "rw": 0.7, "lw": 0.5, "legs": [0.15, -0.3, 0.15, -0.3]}],
		[0.62, {}]]},
	# Storm Rod held: side-on, the rod raised upright by the right shoulder, the left arm out ahead to aim
	"mage_rmb_hold": {"hold": true, "keys": [
		[0.00, {"lift": 0.04, "sq": -0.2, "fr": Vector3(0.05, 0.45, 0.05), "rw": 1.0}],
		[0.12, {"y": -0.75, "p": 0.12, "fr": Vector3(0.12, 0.52, 0.12), "rw": 1.0, "fl": Vector3(0.05, 0.12, -0.42), "hw": 1.0, "lw": 1.0, "legs": [0.35, -0.55, 0.05, -0.35], "sq": 0.12}],
		[0.8, {"y": -0.85, "p": 0.18, "fr": Vector3(0.14, 0.56, 0.2), "rw": 1.0, "fl": Vector3(0.05, 0.14, -0.44), "hw": 1.0, "lw": 1.0, "legs": [0.4, -0.6, 0.05, -0.4], "sq": 0.18}]]},
	# Storm Rod thrown: an overarm throw (the arm whips over and down past the hip), a stretch into the
	# release, the follow-through bent over the front leg, ~0.4 s to recover
	"mage_rmb": {"keys": [
		[0.00, {"y": -0.85, "p": 0.25, "fr": Vector3(0.14, 0.56, 0.24), "rw": 1.0, "lw": 1.0, "legs": [0.4, -0.6, 0.05, -0.4]}],
		[0.06, {"y": 0.35, "p": -0.45, "fr": Vector3(-0.05, 0.25, -0.6), "rw": 1.0, "fl": Vector3(-0.25, -0.05, 0.15), "hw": 1.0, "lw": 1.0, "legs": [0.8, -0.9, -0.4, -0.2], "sq": -0.3}],
		[0.16, {"y": 0.55, "p": -0.6, "fr": Vector3(-0.15, -0.3, -0.35), "rw": 1.0, "fl": Vector3(-0.25, -0.1, 0.2), "hw": 0.8, "lw": 1.0, "legs": [0.9, -1.0, -0.45, -0.2], "sq": 0.25}],
		[0.42, {"y": 0.15, "p": -0.15, "rw": 0.3, "lw": 0.5, "legs": [0.3, -0.4, -0.1, -0.2]}],
		[0.7, {}]]},
	# Wirerun held: a low sprinter's crouch leaning into the run, both arms swept back, crackling
	"mage_dash": {"hold": true, "keys": [
		[0.00, {"lift": 0.05, "sq": -0.2}],
		[0.12, {"p": -0.5, "lift": -0.14, "sq": 0.35, "legs": [0.9, -1.5, 0.55, -1.2], "lw": 1.0, "fl": Vector3(-0.25, -0.05, 0.38), "hw": 1.0, "fr": Vector3(0.25, -0.05, 0.38), "rw": 1.0}],
		[0.6, {"p": -0.58, "lift": -0.16, "sq": 0.42, "legs": [0.95, -1.6, 0.6, -1.25], "lw": 1.0, "fl": Vector3(-0.28, -0.02, 0.42), "hw": 1.0, "fr": Vector3(0.28, -0.02, 0.42), "rw": 1.0}]]},
	# Wirerun let go: stretched flat out as the streak (the model hides behind the silhouette), arms trailing
	"mage_dash_go": {"keys": [
		[0.00, {"p": -0.6, "sq": 0.4, "legs": [0.95, -1.6, 0.6, -1.25], "lw": 1.0}],
		[0.05, {"p": -0.9, "sq": -0.45, "lift": 0.1, "legs": [0.2, -0.3, -0.5, -0.2], "lw": 1.0, "fl": Vector3(-0.3, -0.12, 0.5), "hw": 1.0, "fr": Vector3(0.3, -0.12, 0.5), "rw": 1.0}],
		[0.4, {"p": -0.85, "sq": -0.4, "lift": 0.1, "legs": [0.2, -0.3, -0.5, -0.2], "lw": 1.0, "fl": Vector3(-0.3, -0.12, 0.5), "hw": 1.0, "fr": Vector3(0.3, -0.12, 0.5), "rw": 1.0}],
		[0.5, {}]]},
	# Wirerun arrival: she re-forms in a crouch (squash), springs up past standing, settles (~0.4 s)
	"mage_dash_land": {"keys": [
		[0.00, {"p": -0.35, "lift": -0.18, "sq": 0.55, "legs": [1.0, -1.6, 0.8, -1.4], "lw": 1.0, "fl": Vector3(-0.35, 0.1, 0.0), "hw": 1.0, "fr": Vector3(0.35, 0.1, 0.0), "rw": 1.0}],
		[0.14, {"p": 0.12, "lift": 0.06, "sq": -0.2, "fl": Vector3(-0.3, 0.2, 0.0), "hw": 0.6, "fr": Vector3(0.3, 0.2, 0.0), "rw": 0.6}],
		[0.42, {}]]},
	# the air dash (her base dash variant): a tumble forward with the arms tucked, a teal streak
	"mage_dash_ex": {"keys": [
		[0.00, {"sq": 0.2, "lw": 0.6, "legs": [0.6, -1.0, 0.5, -0.9]}],
		[0.05, {"fx": -1.5, "sq": -0.2, "lw": 1.0, "legs": [1.5, -2.0, 1.4, -1.9], "fl": Vector3(0.1, -0.2, -0.25), "hw": 1.0, "fr": Vector3(-0.1, -0.2, -0.25), "rw": 1.0}],
		[0.2, {"fx": -6.283, "lw": 1.0, "legs": [1.5, -2.0, 1.4, -1.9], "fl": Vector3(0.1, -0.2, -0.25), "hw": 1.0, "fr": Vector3(-0.1, -0.2, -0.25), "rw": 1.0}],
		[0.36, {"fx": -6.283, "sq": 0.3, "lift": -0.08}],
		[0.5, {"fx": -6.283}]]},
	# Skycall: a one-arm sweep toward the spot, then the hand snapped down as the circle drops
	"mage_e": {"keys": [
		[0.00, {}],
		[0.08, {"p": 0.2, "y": 0.4, "fl": Vector3(-0.1, 0.55, 0.1), "hw": 1.0, "sq": -0.25, "lift": 0.05}],
		[0.16, {"p": -0.4, "y": -0.2, "fl": Vector3(0.12, -0.1, -0.55), "hw": 1.0, "lw": 1.0, "legs": [0.45, -0.8, 0.2, -0.5], "sq": 0.3}],
		[0.45, {"p": -0.15, "fl": Vector3(0.06, 0.0, -0.4), "hw": 0.6, "lw": 0.6, "legs": [0.2, -0.35, 0.1, -0.25]}],
		[0.8, {}]]},
	# a foe goes Live (the passive proc): a finger flicked up to the sky as the bolt drops
	"mage_live": {"keys": [
		[0.00, {}],
		[0.07, {"p": 0.18, "fr": Vector3(-0.05, 0.62, -0.1), "rw": 1.0, "sq": -0.2}],
		[0.3, {"p": 0.1, "fr": Vector3(-0.05, 0.55, -0.1), "rw": 0.8}],
		[0.55, {}]]},
	# ---------------------------------------------------------------- Venator
	# a rifle round: the shoulder takes the kick, the head stays on the sights (light, 0.12 s cadence)
	"gunslinger_lmb": {"keys": [
		[0.00, {"p": 0.06, "gp": 0.18, "y": 0.04}],
		[0.05, {"p": 0.02, "gp": 0.05}],
		[0.12, {}]]},
	# Spike Grenade held: the grenade cocked high over the right shoulder, the rifle hand forward
	"gunslinger_rmb_hold": {"hold": true, "keys": [
		[0.00, {"sq": -0.15}],
		[0.12, {"p": 0.22, "y": -0.5, "fl": Vector3(0.02, 0.62, 0.2), "hw": 1.0, "lw": 1.0, "legs": [0.3, -0.5, 0.0, -0.3], "sq": 0.12}],
		[0.9, {"p": 0.26, "y": -0.55, "fl": Vector3(0.0, 0.66, 0.24), "hw": 1.0, "lw": 1.0, "legs": [0.32, -0.55, 0.0, -0.32], "sq": 0.15}]]},
	# Spike Grenade thrown: a fast overhand (0.2 s commit), the arm whipping through, a stretch at the release
	"gunslinger_rmb": {"keys": [
		[0.00, {"p": 0.26, "y": -0.55, "fl": Vector3(0.0, 0.66, 0.24), "hw": 1.0, "lw": 1.0, "legs": [0.32, -0.55, 0.0, -0.32]}],
		[0.07, {"p": -0.4, "y": 0.45, "fl": Vector3(0.12, 0.2, -0.6), "hw": 1.0, "lw": 1.0, "legs": [0.7, -0.8, -0.4, -0.2], "sq": -0.3}],
		[0.16, {"p": -0.5, "y": 0.55, "fl": Vector3(0.1, -0.25, -0.35), "hw": 0.9, "lw": 1.0, "legs": [0.75, -0.85, -0.4, -0.2], "sq": 0.22}],
		[0.4, {"p": -0.1, "y": 0.1, "hw": 0.3, "lw": 0.4}],
		[0.6, {}]]},
	# Combat Slide: dropped feet-first, the torso leaning back, the rifle kept up and aimed; a scrape squash
	"gunslinger_dash": {"keys": [
		[0.00, {"lift": 0.04, "sq": -0.2}],
		[0.08, {"p": 0.62, "lift": -0.38, "sq": 0.35, "legs": [-1.2, -0.15, -0.3, -1.8], "lw": 1.0, "fl": Vector3(-0.32, -0.3, 0.12), "hw": 0.9}],
		[0.45, {"p": 0.55, "lift": -0.36, "sq": 0.3, "legs": [-1.1, -0.2, -0.3, -1.7], "lw": 1.0, "fl": Vector3(-0.32, -0.32, 0.14), "hw": 0.9}],
		[0.62, {"p": -0.15, "lift": 0.05, "sq": -0.15, "legs": [0.5, -0.9, 0.2, -0.5], "lw": 0.8}],
		[0.85, {}]]},
	# the air dash (his base dash variant): a shoulder-led barrel roll, rifle tucked
	"gunslinger_dash_ex": {"keys": [
		[0.00, {"sq": 0.15}],
		[0.05, {"fz": 1.2, "p": -0.3, "lw": 1.0, "legs": [1.1, -1.6, 1.0, -1.5], "fl": Vector3(0.15, -0.1, -0.2), "hw": 1.0}],
		[0.22, {"fz": 6.283, "p": -0.2, "lw": 1.0, "legs": [1.1, -1.6, 1.0, -1.5]}],
		[0.36, {"fz": 6.283, "sq": 0.3, "lift": -0.08}],
		[0.5, {"fz": 6.283}]]},
	# Ion Cannon: braced low behind the barrel through the 0.6 s cast, the beam goes, the recoil throws
	# the chest back (overshoot) and he settles over ~0.4 s
	"gunslinger_e": {"keys": [
		[0.00, {"sq": -0.1}],
		[0.15, {"p": -0.2, "y": 0.35, "lift": -0.1, "legs": [0.6, -1.05, 0.4, -0.8], "lw": 1.0, "fl": Vector3(0.05, 0.05, -0.48), "hw": 0.9, "sq": 0.2}],
		[0.58, {"p": -0.26, "y": 0.35, "lift": -0.12, "legs": [0.65, -1.1, 0.42, -0.85], "lw": 1.0, "fl": Vector3(0.05, 0.05, -0.48), "hw": 0.9, "sq": 0.28, "gp": -0.05}],
		[0.65, {"p": 0.7, "y": 0.2, "lift": 0.02, "gp": 0.6, "legs": [0.1, -0.25, 0.3, -0.5], "lw": 1.0, "fl": Vector3(0.12, 0.1, -0.3), "hw": 0.7, "sq": -0.3}],
		[0.8, {"p": 0.35, "gp": 0.25, "sq": 0.1, "legs": [0.15, -0.3, 0.2, -0.4], "lw": 0.8}],
		[1.05, {}]]},
	# a knock (the passive proc: Combat Stim): the rifle spun up onto the shoulder, chin up
	"gunslinger_knock": {"keys": [
		[0.00, {}],
		[0.1, {"p": 0.2, "gp": -1.2, "lift": 0.05, "sq": -0.2}],
		[0.35, {"p": 0.1, "gp": -0.9}],
		[0.6, {}]]},
}
