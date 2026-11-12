extends RefCounted
## --vv-shots --vv-ult: the ultimates' screenshots, taken with tools/vv_shots.gd's match, camera and files. For each
## ult: the telegraph while aiming, the key frame, the impact, and a 6-frame animation strip round the hero.

var vs: RefCounted                # tools/vv_shots.gd

func _init(shots: RefCounted) -> void:
	vs = shots

func run_for(who: String) -> void:
	vs.P.lvl = int(Hunter.ULT_AT[0])
	if who == "mage":
		await _kitefall()
	else:
		await _cinderfall()

func _landing() -> Vector3:
	return vs.T.position + Vector3(0, 0.6, 0)

## Sparkle comes down just short of the target, so her landing pose and the knockback both read.
func _short() -> Vector3:
	return vs.T.pos - Vector3(1.4, 0, 0)

## Kitefall: press at 0, hang from 0.6, the second press at 1.2, the strike at 1.4.
func _kitefall() -> void:
	await vs._reset(7.0)
	vs.P.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(vs.P)
	var slam := {"done": false}
	var spot := _short()
	var each := func(tt: float):
		vs._aim(spot)
		if tt >= 1.2 and not slam["done"]:
			slam["done"] = true
			HunterKeys.ult_pressed(vs.P)
	var marks: Array = vs._strip("ult_anim",
			"Kitefall: the crouch, the launch, hanging arms wide, the dive, the one-knee landing, up into the stance",
			[0.1, 0.28, 0.42, 1.0, 1.32, 1.5])
	marks.append([1.0, "full", "ult_aim",
			"Kitefall aiming: she hangs up high; the gold range ring over the dark disc, the gold crown at the cursor",
			_landing])
	marks.append([1.3, "full", "ult_key",
			"Kitefall key frame: the gold landing circle flashes as she streaks down onto it", _landing])
	marks.append([1.43, "full", "ult_impact",
			"Kitefall impact: a gold pillar out of the sky, shock rings, sparks; the target knocked back with Static",
			_landing])
	await vs._go(2.0, each, marks)

## Cinderfall: the tap at 0, the shell seen falling from 0.8, the impact at 1.6, the patch to 4.6.
func _cinderfall() -> void:
	await vs._reset(8.0)
	vs.P.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(vs.P)
	var marks: Array = vs._strip("ult_anim",
			"Cinderfall: the rifle snapped straight up, the shot's kick, held, back down into his aim",
			[0.02, 0.08, 0.14, 0.25, 0.4, 0.6])
	marks.append([0.9, "full", "ult_aim",
			"Cinderfall telegraph: the ember disc fills with its hot red centre and the bronze rivet ring; the column",
			_landing])
	marks.append([1.52, "full", "ult_key",
			"Cinderfall key frame: the spiked shell drops through the column onto the nearly full disc", _landing])
	marks.append([1.63, "full", "ult_impact",
			"Cinderfall impact: the white-hot column, ember shock rings and spray, DEAD CENTRE on the target",
			_landing])
	marks.append([2.6, "full", "ult_zone",
			"Cinderfall patch: the scorched disc burns with a lit ember rim and flames; the target slowed",
			_landing])
	await vs._go(3.0, func(_tt: float): vs._aim(vs.T.pos), marks)
