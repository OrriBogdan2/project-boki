class_name KMovesVV
extends RefCounted
## Keyed full-body moves of Sparkle (mage) and Vex (gunslinger): same format and channels as
## HunterAnim.KMOVES, looked up by HunterAnim.km_sample. Each is timed to the reference sheet's beats
## (briefs/hero-ref/vireo.md, venator.md; 1 frame = 0.2 s there): anticipation, an exaggerated key pose
## on the release (squash or stretch), an overshoot past it, then the settle. fl / fr place a free hand
## from its shoulder (hw / rw their weight). A hand that holds the weapon moves it with wo / wa / gp
## instead, so the weapon and the hand stay together: for Sparkle that is her right hand, the finger gun
## (no gun model, a pointed finger and a wrist coil).

## Leg poses [hip_l, knee_l, hip_r, knee_r] the moves share.
const LUNGE_L := [0.3, -0.45, -0.1, -0.2]
const LUNGE_R := [-0.1, -0.2, 0.3, -0.45]
const CROUCH := [0.9, -1.5, 0.55, -1.2]
const TUCK := [1.5, -2.0, 1.4, -1.9]
const BRACE := [0.6, -1.05, 0.4, -0.8]
const SLIDE := [-1.2, -0.15, -0.3, -1.8]
const AIM_CROUCH := [0.55, -0.95, -0.2, -0.55]
## Vex's rifle shouldered between rounds: the chest low over the front knee, the stock in the shoulder.
const SHOULDER := {"p": -0.08, "lift": -0.05, "sq": 0.05, "wo": Vector3(0.0, 0.0, 0.02), "legs": AIM_CROUCH, "lw": 0.7}

const MOVES := {
	# ---------------------------------------------------------------- Sparkle
	# finger bolt, left hand: the hand drawn back to the chest (wound up the other way), flung straight
	# out at the cursor with the finger pointed (a stretch), snapped up by the recoil, settled by 0.35
	"mage_lmb_l": {"keys": [
		[0.00, {}],
		[0.03, {"y": -0.3, "sq": 0.15, "fl": Vector3(0.14, 0.02, -0.08), "hw": 1.0}],
		[0.06, {"y": 0.6, "r": 0.06, "sq": -0.2, "fl": Vector3(0.12, 0.25, -0.62), "hw": 1.0,
			"legs": LUNGE_L, "lw": 0.8}],
		[0.09, {"y": 0.62, "p": 0.12, "sq": 0.05, "fl": Vector3(0.12, 0.4, -0.5), "hw": 1.0,
			"legs": LUNGE_L, "lw": 0.8}],
		[0.2, {"y": 0.45, "p": 0.04, "fl": Vector3(0.1, 0.26, -0.55), "hw": 0.9, "legs": LUNGE_L, "lw": 0.6}],
		[0.35, {}]]},
	# finger bolt, right hand (the gun hand): the same beats with the finger gun itself, pulled in to the
	# chest, punched out, the wrist flicked up about 15 degrees by the recoil
	"mage_lmb_r": {"keys": [
		[0.00, {}],
		[0.03, {"y": 0.3, "sq": 0.15, "wo": Vector3(-0.1, 0.06, 0.3)}],
		[0.06, {"y": -0.6, "r": -0.06, "sq": -0.2, "wo": Vector3(0.0, 0.08, -0.02), "legs": LUNGE_R, "lw": 0.8}],
		[0.09, {"y": -0.62, "p": 0.12, "gp": 0.27, "wo": Vector3(0.0, 0.12, 0.02), "legs": LUNGE_R, "lw": 0.8}],
		[0.2, {"y": -0.45, "gp": 0.1, "wo": Vector3(0.0, 0.05, 0.0), "legs": LUNGE_R, "lw": 0.6}],
		[0.35, {}]]},
	# Storm Rod held: side-on, the rod hand raised high by the right shoulder, the left arm out ahead to aim
	"mage_rmb_hold": {"hold": true, "keys": [
		[0.00, {"lift": 0.04, "sq": -0.2, "wo": Vector3(0.05, 0.3, 0.2)}],
		[0.12, {"y": -0.75, "p": 0.12, "wo": Vector3(0.08, 0.55, 0.36), "gp": -0.6,
			"fl": Vector3(0.05, 0.14, -0.44), "hw": 1.0, "legs": [0.35, -0.55, 0.05, -0.35], "lw": 1.0, "sq": 0.12}],
		[0.8, {"y": -0.85, "p": 0.18, "wo": Vector3(0.08, 0.58, 0.4), "gp": -0.6,
			"fl": Vector3(0.05, 0.16, -0.46), "hw": 1.0, "legs": [0.4, -0.6, 0.05, -0.4], "lw": 1.0, "sq": 0.18}]]},
	# Storm Rod thrown: an overarm throw (the arm whips over and down past the hip), a stretch into the
	# release, the follow-through bent over the front leg, ~0.4 s to recover
	"mage_rmb": {"keys": [
		[0.00, {"y": -0.85, "p": 0.25, "wo": Vector3(0.08, 0.58, 0.4), "gp": -0.6, "legs": [0.4, -0.6, 0.05, -0.4],
			"lw": 1.0}],
		[0.06, {"y": 0.35, "p": -0.45, "wo": Vector3(-0.05, 0.3, -0.02), "gp": 0.2,
			"fl": Vector3(-0.25, -0.05, 0.15), "hw": 1.0, "legs": [0.8, -0.9, -0.4, -0.2], "lw": 1.0, "sq": -0.3}],
		[0.16, {"y": 0.55, "p": -0.6, "wo": Vector3(-0.1, -0.2, 0.12), "gp": 0.5,
			"fl": Vector3(-0.25, -0.1, 0.2), "hw": 0.8, "legs": [0.9, -1.0, -0.45, -0.2], "lw": 1.0, "sq": 0.25}],
		[0.42, {"y": 0.15, "p": -0.15, "legs": [0.3, -0.4, -0.1, -0.2], "lw": 0.5}],
		[0.7, {}]]},
	# Wirerun held: a low sprinter's crouch leaning into the run, both arms swept back, crackling
	"mage_dash": {"hold": true, "keys": [
		[0.00, {"lift": 0.05, "sq": -0.2}],
		[0.12, {"p": -0.5, "lift": -0.14, "sq": 0.35, "legs": CROUCH, "lw": 1.0,
			"fl": Vector3(-0.25, -0.05, 0.38), "hw": 1.0, "wo": Vector3(0.1, -0.15, 0.4), "gp": -0.8}],
		[0.6, {"p": -0.58, "lift": -0.16, "sq": 0.42, "legs": CROUCH, "lw": 1.0,
			"fl": Vector3(-0.28, -0.02, 0.42), "hw": 1.0, "wo": Vector3(0.12, -0.15, 0.42), "gp": -0.8}]]},
	# Wirerun let go: stretched flat out as the streak (the model hides behind the silhouette), arms trailing
	"mage_dash_go": {"keys": [
		[0.00, {"p": -0.6, "sq": 0.4, "legs": CROUCH, "lw": 1.0}],
		[0.05, {"p": -0.9, "sq": -0.45, "lift": 0.1, "legs": [0.2, -0.3, -0.5, -0.2], "lw": 1.0,
			"fl": Vector3(-0.3, -0.12, 0.5), "hw": 1.0, "wo": Vector3(0.12, -0.2, 0.45), "gp": -0.8}],
		[0.4, {"p": -0.85, "sq": -0.4, "lift": 0.1, "legs": [0.2, -0.3, -0.5, -0.2], "lw": 1.0,
			"fl": Vector3(-0.3, -0.12, 0.5), "hw": 1.0, "wo": Vector3(0.12, -0.2, 0.45), "gp": -0.8}],
		[0.5, {}]]},
	# Wirerun arrival: she re-forms in a crouch (squash), springs up past standing, settles (~0.4 s)
	"mage_dash_land": {"keys": [
		[0.00, {"p": -0.35, "lift": -0.18, "sq": 0.55, "legs": [1.0, -1.6, 0.8, -1.4], "lw": 1.0,
			"fl": Vector3(-0.35, 0.1, 0.0), "hw": 1.0}],
		[0.14, {"p": 0.12, "lift": 0.06, "sq": -0.2, "fl": Vector3(-0.3, 0.2, 0.0), "hw": 0.6}],
		[0.42, {}]]},
	# the air dash (her base dash variant): a tumble forward with the arms tucked
	# Skycall: the left arm sweeps out toward the spot, then flicks up high through the 0.3 s flick window
	# (the drag is being picked) and stays raised through the 0.8 s countdown (mage_e_snap brings it down)
	"mage_e": {"keys": [
		[0.00, {}],
		[0.07, {"p": 0.15, "y": 0.5, "fl": Vector3(-0.3, 0.1, 0.1), "hw": 1.0, "sq": 0.15}],
		[0.14, {"p": -0.3, "y": -0.25, "fl": Vector3(0.12, 0.05, -0.6), "hw": 1.0, "legs": [0.45, -0.8, 0.2, -0.5],
			"lw": 1.0, "sq": -0.2}],
		[0.3, {"p": 0.25, "y": -0.1, "fl": Vector3(0.05, 0.62, -0.18), "hw": 1.0, "legs": [0.2, -0.35, 0.1, -0.25],
			"lw": 0.8, "sq": -0.25, "lift": 0.06}],
		[0.5, {"p": 0.2, "fl": Vector3(0.05, 0.58, -0.15), "hw": 1.0, "legs": [0.2, -0.35, 0.1, -0.25], "lw": 0.6}],
		[1.15, {"p": 0.2, "fl": Vector3(0.05, 0.58, -0.15), "hw": 1.0}],
		[1.4, {}]]},
	# Skycall strike: the raised hand snapped down to the ground as the bolt lands, a squash, the settle
	"mage_e_snap": {"keys": [
		[0.00, {"p": 0.2, "fl": Vector3(0.05, 0.58, -0.15), "hw": 1.0}],
		[0.06, {"p": -0.45, "fl": Vector3(0.1, -0.25, -0.5), "hw": 1.0, "legs": BRACE, "lw": 1.0, "sq": 0.35,
			"lift": -0.1}],
		[0.3, {"p": -0.2, "fl": Vector3(0.08, -0.15, -0.4), "hw": 0.6, "legs": [0.3, -0.5, 0.2, -0.4], "lw": 0.6}],
		[0.55, {}]]},
	# a foe goes Live (the passive proc): the left hand flicked up to the sky as the bolt drops
	"mage_live": {"keys": [
		[0.00, {}],
		[0.07, {"p": 0.18, "fl": Vector3(0.05, 0.62, -0.1), "hw": 1.0, "sq": -0.2}],
		[0.3, {"p": 0.1, "fl": Vector3(0.05, 0.55, -0.1), "hw": 0.8}],
		[0.55, {}]]},
	# the gum (MageGum): head and bubble only, the keyed clip does the work; the rig just waits it out
	"mage_gum": {"keys": [[0.0, {}], [1.2, {}]]},
	# Kitefall (X), on the sheet's 10 fps beats. The crouch (f28-f31, 0.3 s): knees deep, arms swept down and
	# back, a squash that loads the launch
	"mage_x": {"hold": true, "keys": [
		[0.00, {"sq": -0.1}],
		[0.1, {"p": -0.3, "lift": -0.12, "sq": 0.3, "legs": CROUCH, "lw": 1.0,
			"fl": Vector3(-0.3, -0.25, 0.3), "hw": 1.0, "wo": Vector3(0.15, -0.3, 0.3), "gp": 0.6}],
		[0.3, {"p": -0.42, "lift": -0.2, "sq": 0.5, "legs": TUCK, "lw": 1.0,
			"fl": Vector3(-0.32, -0.3, 0.36), "hw": 1.0, "wo": Vector3(0.18, -0.32, 0.34), "gp": 0.7}]]},
	# launched (f32-f46): a stretch up out of the crouch, then she hangs with both arms flung wide and up,
	# legs trailing together, a slow float
	"mage_x_air": {"hold": true, "keys": [
		[0.00, {"p": 0.2, "sq": -0.5, "legs": [-0.2, -0.1, -0.15, -0.1], "lw": 1.0,
			"fl": Vector3(-0.1, 0.62, -0.05), "hw": 1.0, "wo": Vector3(0.1, 0.6, 0.0), "gp": -1.2}],
		[0.2, {"p": 0.1, "sq": -0.2, "legs": [0.3, -0.7, 0.1, -0.5], "lw": 1.0,
			"fl": Vector3(-0.55, 0.35, 0.0), "hw": 1.0, "wo": Vector3(0.5, 0.35, 0.0), "gp": -0.5}],
		[0.4, {"p": 0.05, "sq": -0.15, "legs": [0.35, -0.8, 0.15, -0.6], "lw": 1.0,
			"fl": Vector3(-0.58, 0.4, 0.02), "hw": 1.0, "wo": Vector3(0.52, 0.4, 0.02), "gp": -0.55}]]},
	# the strike (f47-f49): head first down the bolt, both fists driven down, stretched long
	"mage_x_dive": {"hold": true, "keys": [
		[0.00, {"p": 0.05, "fl": Vector3(-0.58, 0.4, 0.02), "hw": 1.0, "wo": Vector3(0.52, 0.4, 0.02)}],
		[0.1, {"p": 0.9, "sq": -0.45, "legs": [-0.3, -0.1, -0.3, -0.1], "lw": 1.0,
			"fl": Vector3(-0.05, -0.3, -0.5), "hw": 1.0, "wo": Vector3(0.05, -0.3, -0.5), "gp": 1.0}]]},
	# the landing (f49-f51): a deep squash on one knee with a fist on the ground, then up into her stance
	# with the arms out (she can attack again at once)
	"mage_x_land": {"keys": [
		[0.00, {"p": 0.55, "lift": -0.25, "sq": 0.6, "legs": [1.1, -1.8, 0.4, -1.3], "lw": 1.0,
			"fl": Vector3(-0.1, -0.55, -0.35), "hw": 1.0, "wo": Vector3(0.12, -0.4, -0.3), "gp": 0.9}],
		[0.1, {"p": 0.4, "lift": -0.2, "sq": 0.45, "legs": [1.0, -1.6, 0.4, -1.2], "lw": 1.0,
			"fl": Vector3(-0.15, -0.5, -0.3), "hw": 1.0, "wo": Vector3(0.12, -0.35, -0.25), "gp": 0.7}],
		[0.3, {"p": -0.1, "lift": 0.04, "sq": -0.15, "fl": Vector3(-0.4, 0.15, 0.0), "hw": 0.7}],
		[0.5, {}]]},
	# ---------------------------------------------------------------- Vex
	# a rifle round (footage 0007-0036, 0067-0072: the rifle stays shouldered at the chest on the cursor, the
	# recoil shows in the gun and the muzzle, the body barely moves; standing she sinks into a low wide aim
	# crouch, walking the legs keep walking). Every round restarts it on the shouldered pose: the stock kicks
	# into the shoulder and the muzzle flips up by 0.025 s, back on the aim by 0.09 (the next round is at
	# 0.12). After the last round the rifle stays up a beat, then she eases out of the crouch by 0.55.
	"gunslinger_lmb": {"stance": true, "keys": [
		[0.00, SHOULDER],
		[0.025, {"p": 0.03, "y": 0.04, "lift": -0.04, "sq": 0.06, "gp": 0.24, "wo": Vector3(0.0, 0.02, 0.08),
			"legs": AIM_CROUCH, "lw": 0.7}],
		[0.09, SHOULDER],
		[0.3, SHOULDER],
		[0.55, {}]]},
	# Burr Charge: fired from the cannon's launcher, no throw. A hard kick up the arm and the chest driven back, her
	# free hand staying out of it, then back on the aim by 0.3
	"gunslinger_rmb": {"stance": true, "keys": [
		[0.00, SHOULDER],
		[0.04, {"p": 0.1, "y": 0.1, "lift": -0.06, "sq": 0.1, "gp": 0.55, "wo": Vector3(0.0, 0.05, 0.18),
			"legs": AIM_CROUCH, "lw": 0.7}],
		[0.18, SHOULDER],
		[0.3, SHOULDER],
		[0.5, {}]]},
	# Combat Slide: dropped feet-first, leaning back (no further than 0.45, so she stays upright enough to
	# aim), both hands left on the rifle so it stays up and aimed; a scrape squash, then the stand-up
	"gunslinger_dash": {"keys": [
		[0.00, {"lift": 0.04, "sq": -0.2}],
		[0.08, {"p": 0.42, "lift": -0.3, "sq": 0.3, "legs": SLIDE, "lw": 1.0}],
		[0.45, {"p": 0.4, "lift": -0.28, "sq": 0.25, "legs": SLIDE, "lw": 1.0}],
		[0.62, {"p": -0.15, "lift": 0.05, "sq": -0.15, "legs": [0.5, -0.9, 0.2, -0.5], "lw": 0.8}],
		[0.85, {}]]},
	# the air dash (her base dash variant): a shoulder-led barrel roll, rifle tucked
	"gunslinger_dash_ex": {"keys": [
		[0.00, {"sq": 0.15}],
		[0.05, {"fz": 1.2, "p": -0.3, "legs": [1.1, -1.6, 1.0, -1.5], "lw": 1.0}],
		[0.22, {"fz": 6.283, "p": -0.2, "legs": [1.1, -1.6, 1.0, -1.5], "lw": 1.0}],
		[0.36, {"fz": 6.283, "sq": 0.3, "lift": -0.08}],
		[0.5, {"fz": 6.283}]]},
	# Ion Cannon: braced low behind the barrel through the 0.6 s cast, the beam goes, the recoil throws
	# the chest back (overshoot) and she settles over ~0.4 s
	"gunslinger_e": {"keys": [
		[0.00, {"sq": -0.1}],
		[0.15, {"p": -0.2, "y": 0.35, "lift": -0.1, "legs": BRACE, "lw": 1.0, "sq": 0.2}],
		[0.58, {"p": -0.26, "y": 0.35, "lift": -0.12, "legs": [0.65, -1.1, 0.42, -0.85], "lw": 1.0, "sq": 0.28,
			"gp": -0.05}],
		[0.65, {"p": 0.7, "y": 0.2, "lift": 0.02, "gp": 0.6, "wo": Vector3(0.0, 0.05, 0.12),
			"legs": [0.1, -0.25, 0.3, -0.5], "lw": 1.0, "sq": -0.3}],
		[0.8, {"p": 0.35, "gp": 0.25, "sq": 0.1, "legs": [0.15, -0.3, 0.2, -0.4], "lw": 0.8}],
		[1.05, {}]]},
	# Cinderfall (X, f29 on the sheet): the rifle snapped straight up over her head in 0.1 s, the shot kicks it
	# and squashes her a little, held up a beat, then back down into her aim by 0.6 s
	"gunslinger_x": {"keys": [
		[0.00, {"sq": -0.1}],
		[0.1, {"p": 0.3, "gp": 1.5, "wo": Vector3(0.0, 0.45, 0.1), "lift": 0.05, "sq": -0.25,
			"fl": Vector3(0.05, 0.5, -0.05), "hw": 1.0, "legs": BRACE, "lw": 0.8}],
		[0.14, {"p": 0.22, "gp": 1.25, "wo": Vector3(0.0, 0.32, 0.12), "lift": -0.06, "sq": 0.3,
			"fl": Vector3(0.05, 0.42, -0.02), "hw": 1.0, "legs": BRACE, "lw": 1.0}],
		[0.3, {"p": 0.26, "gp": 1.4, "wo": Vector3(0.0, 0.42, 0.1), "sq": 0.05,
			"fl": Vector3(0.05, 0.48, -0.05), "hw": 1.0, "legs": BRACE, "lw": 0.8}],
		[0.6, {}]]},
	# a knock (the passive proc: Hot Streak): the rifle spun up onto the shoulder, chin up
	"gunslinger_knock": {"keys": [
		[0.00, {}],
		[0.1, {"p": 0.2, "gp": -1.2, "lift": 0.05, "sq": -0.2}],
		[0.35, {"p": 0.1, "gp": -0.9}],
		[0.6, {}]]},
}
