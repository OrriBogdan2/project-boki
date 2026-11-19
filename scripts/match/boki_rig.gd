class_name BokiRig
extends Node
## A Boki species drawn from a rigged model (art/kin/<species>/<species>.glb, tools/boki/build_boki.py) instead of
## KinModels' primitives. This node lives beside the model: it picks the body clip from the metas KinPuppet
## already reads, plus "kwork" (chop, mine, carry), "kact" (eat, pet, hop while it leaps or is thrown), "kburst"
## (a factor on the gait's cadence) and a flier's "aloft" and "lift" (BokiFly: hover or glide up there, a flare
## coming down), and plays the face on top of whatever the body does.
## Match body language (the "pose" meta, KinWildPose and KinCompanion) is a layer on Flex over whatever clip runs:
## a startle, a charge, a cower, a knocked-out sway, a lift into the scan beam; BODY_FEEL bends it per body plan.
## A meta "face" (happy, sad, sleepy, angry) overrides the clip's expression. "kwater" (m) is the water over its feet
## this frame: deeper than half its height it floats and swims. See docs/art/kin/RIGGED_BOKI.md.

const PATH := "res://art/kin/%s/%s.glb"
## Where the eyes and the top of the head sit (m), per species: what KinModels.build returns for the accessories.
## "hip" is the height its legs hold it at, which the limb roll stretches: 0 for a Boki without legs. One that "hover"s
## gets a soft shadow on the ground under it. "coat" overrides COAT_LOOK (a matte skin: less fresnel, rim and top
## light, no sheen).
const FRAME := {
	"zippelith": {"head": Vector3(0, 0.357, -0.108), "top": 0.464, "carry": Vector3(0, 0.517, 0.0541),
		"ear_tip": Vector3(0.032, 0.464, 0.0487), "tail_tip": Vector3(0, 0.264, 0.162), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.079, 0.27, 0.0325), "right flank": Vector3(0.079, 0.27, 0.0325),
			"back": Vector3(0, 0.37, 0.0865), "chest": Vector3(0, 0.25, -0.0972)}},
	"xylogator": {"head": Vector3(2.64e-17, 0.357, -0.121), "top": 0.464, "carry": Vector3(2.64e-17, 0.517, 0.0621),
		"ear_tip": Vector3(0.0345, 0.464, 0.056), "tail_tip": Vector3(2.64e-17, 0.264, 0.184), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0852, 0.27, 0.0377), "right flank": Vector3(0.0852, 0.27, 0.0377),
			"back": Vector3(2.64e-17, 0.37, 0.0987), "chest": Vector3(2.64e-17, 0.25, -0.109)}},
	"wickapi.old-chibi-1111": {"head": Vector3(-2.64e-17, 0.357, -0.0912), "top": 0.464, "carry": Vector3(-2.64e-17, 0.517, 0.0466),
		"ear_tip": Vector3(0.031, 0.464, 0.042), "tail_tip": Vector3(-2.64e-17, 0.264, 0.138), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0766, 0.27, 0.0282), "right flank": Vector3(0.0766, 0.27, 0.0282),
			"back": Vector3(-2.64e-17, 0.37, 0.0741), "chest": Vector3(-2.64e-17, 0.25, -0.082)}},
	"wickapi": {"head": Vector3(0, 0.357, -0.11), "top": 0.464, "carry": Vector3(0, 0.517, 0.0541),
		"ear_tip": Vector3(0.0322, 0.464, 0.0487), "tail_tip": Vector3(0, 0.264, 0.163), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0796, 0.27, 0.0323), "right flank": Vector3(0.0796, 0.27, 0.0323),
			"back": Vector3(0, 0.37, 0.0869), "chest": Vector3(0, 0.25, -0.0988)}},
	"voltalon": {"head": Vector3(0, 0.357, -0.102), "top": 0.464, "carry": Vector3(0, 0.517, 0.0529),
		"ear_tip": Vector3(0.0501, 0.464, 0.0478), "tail_tip": Vector3(0, 0.264, 0.156), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.124, 0.27, 0.0323), "right flank": Vector3(0.124, 0.27, 0.0323),
			"back": Vector3(0, 0.37, 0.0839), "chest": Vector3(0, 0.25, -0.0913)}},
	"vespyx": {"head": Vector3(0, 0.357, -0.108), "top": 0.464, "carry": Vector3(0, 0.517, 0.0563),
		"ear_tip": Vector3(0.026, 0.464, 0.0509), "tail_tip": Vector3(0, 0.264, 0.166), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0642, 0.27, 0.0345), "right flank": Vector3(0.0642, 0.27, 0.0345),
			"back": Vector3(0, 0.37, 0.0891), "chest": Vector3(0, 0.25, -0.0967)}},
	"twinklup": {"head": Vector3(0, 0.357, -0.111), "top": 0.464, "carry": Vector3(0, 0.517, 0.058),
		"ear_tip": Vector3(0.0198, 0.464, 0.0524), "tail_tip": Vector3(0, 0.264, 0.17), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0488, 0.27, 0.0355), "right flank": Vector3(0.0488, 0.27, 0.0355),
			"back": Vector3(0, 0.37, 0.0918), "chest": Vector3(0, 0.25, -0.0994)}},
	"truffapir": {"head": Vector3(0, 0.357, -0.201), "top": 0.464, "carry": Vector3(0, 0.517, 0.103),
		"ear_tip": Vector3(0.0309, 0.464, 0.0925), "tail_tip": Vector3(0, 0.264, 0.305), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0764, 0.27, 0.0622), "right flank": Vector3(0.0764, 0.27, 0.0622),
			"back": Vector3(0, 0.37, 0.163), "chest": Vector3(0, 0.25, -0.18)}},
	"torpecone": {"head": Vector3(-2.64e-17, 0.357, -0.194), "top": 0.464, "carry": Vector3(-2.64e-17, 0.517, 0.0992),
		"ear_tip": Vector3(0.0466, 0.464, 0.0894), "tail_tip": Vector3(-2.64e-17, 0.264, 0.295), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.115, 0.27, 0.0601), "right flank": Vector3(0.115, 0.27, 0.0601),
			"back": Vector3(-2.64e-17, 0.37, 0.158), "chest": Vector3(-2.64e-17, 0.25, -0.175)}},
	"tiltster": {"head": Vector3(0, 0.357, -0.195), "top": 0.464, "carry": Vector3(0, 0.517, 0.0993),
		"ear_tip": Vector3(0.0574, 0.464, 0.0895), "tail_tip": Vector3(0, 0.264, 0.295), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.142, 0.27, 0.0601), "right flank": Vector3(0.142, 0.27, 0.0601),
			"back": Vector3(0, 0.37, 0.158), "chest": Vector3(0, 0.25, -0.175)}},
	"teapotamus": {"head": Vector3(0, 0.357, -0.152), "top": 0.464, "carry": Vector3(0, 0.517, 0.0778),
		"ear_tip": Vector3(0.0356, 0.464, 0.0702), "tail_tip": Vector3(0, 0.264, 0.231), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0879, 0.27, 0.0472), "right flank": Vector3(0.0879, 0.27, 0.0472),
			"back": Vector3(0, 0.37, 0.124), "chest": Vector3(0, 0.25, -0.137)}},
	"stratarch": {"head": Vector3(1.32e-17, 0.357, -0.085), "top": 0.464, "carry": Vector3(1.32e-17, 0.517, 0.0427),
		"ear_tip": Vector3(0.0204, 0.464, 0.0384), "tail_tip": Vector3(1.32e-17, 0.264, 0.128), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0504, 0.27, 0.0257), "right flank": Vector3(0.0504, 0.27, 0.0257),
			"back": Vector3(1.32e-17, 0.37, 0.0682), "chest": Vector3(1.32e-17, 0.25, -0.0765)}},
	"starcap": {"head": Vector3(0, 0.357, -0.0834), "top": 0.464, "carry": Vector3(0, 0.517, 0.0429),
		"ear_tip": Vector3(0.0364, 0.464, 0.0386), "tail_tip": Vector3(0, 0.264, 0.127), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0899, 0.27, 0.026), "right flank": Vector3(0.0899, 0.27, 0.026),
			"back": Vector3(0, 0.37, 0.0681), "chest": Vector3(0, 0.25, -0.075)}},
	"stamproo": {"head": Vector3(0, 0.357, -0.0867), "top": 0.464, "carry": Vector3(0, 0.517, 0.0467),
		"ear_tip": Vector3(0.0196, 0.464, 0.0423), "tail_tip": Vector3(0, 0.264, 0.136), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0484, 0.27, 0.029), "right flank": Vector3(0.0484, 0.27, 0.029),
			"back": Vector3(0, 0.37, 0.0734), "chest": Vector3(0, 0.25, -0.0778)}},
	"skidlet": {"head": Vector3(0, 0.357, -0.153), "top": 0.464, "carry": Vector3(0, 0.517, 0.0788),
		"ear_tip": Vector3(0.0257, 0.464, 0.071), "tail_tip": Vector3(0, 0.264, 0.233), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0635, 0.27, 0.0479), "right flank": Vector3(0.0635, 0.27, 0.0479),
			"back": Vector3(0, 0.37, 0.125), "chest": Vector3(0, 0.25, -0.137)}},
	"sirencada": {"head": Vector3(0, 0.357, -0.147), "top": 0.464, "carry": Vector3(0, 0.517, 0.0717),
		"ear_tip": Vector3(0.0899, 0.464, 0.0644), "tail_tip": Vector3(0, 0.264, 0.217), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.222, 0.27, 0.0426), "right flank": Vector3(0.222, 0.27, 0.0426),
			"back": Vector3(0, 0.37, 0.115), "chest": Vector3(0, 0.25, -0.132)}},
	"scopeleon": {"head": Vector3(0, 0.357, -0.307), "top": 0.464, "carry": Vector3(0, 0.517, 0.157),
		"ear_tip": Vector3(0.0521, 0.464, 0.141), "tail_tip": Vector3(0, 0.264, 0.466), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.129, 0.27, 0.095), "right flank": Vector3(0.129, 0.27, 0.095),
			"back": Vector3(0, 0.37, 0.249), "chest": Vector3(0, 0.25, -0.276)}},
	"sawright": {"head": Vector3(0, 0.357, -0.256), "top": 0.464, "carry": Vector3(0, 0.517, 0.131),
		"ear_tip": Vector3(0.0491, 0.464, 0.118), "tail_tip": Vector3(0, 0.264, 0.389), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.121, 0.27, 0.0794), "right flank": Vector3(0.121, 0.27, 0.0794),
			"back": Vector3(0, 0.37, 0.208), "chest": Vector3(0, 0.25, -0.23)}},
	"sandwidow": {"head": Vector3(0, 0.357, -0.114), "top": 0.464, "carry": Vector3(0, 0.517, 0.058),
		"ear_tip": Vector3(0.053, 0.464, 0.0523), "tail_tip": Vector3(0, 0.264, 0.172), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.131, 0.27, 0.0351), "right flank": Vector3(0.131, 0.27, 0.0351),
			"back": Vector3(0, 0.37, 0.0923), "chest": Vector3(0, 0.25, -0.102)}},
	"rollguin": {"head": Vector3(0, 0.357, -0.0904), "top": 0.464, "carry": Vector3(0, 0.517, 0.0461),
		"ear_tip": Vector3(0.0406, 0.464, 0.0416), "tail_tip": Vector3(0, 0.264, 0.137), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.1, 0.27, 0.0279), "right flank": Vector3(0.1, 0.27, 0.0279),
			"back": Vector3(0, 0.37, 0.0734), "chest": Vector3(0, 0.25, -0.0813)}},
	"reelacine": {"head": Vector3(0, 0.357, -0.2), "top": 0.464, "carry": Vector3(0, 0.517, 0.102),
		"ear_tip": Vector3(0.0209, 0.464, 0.0919), "tail_tip": Vector3(0, 0.264, 0.303), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0516, 0.27, 0.0618), "right flank": Vector3(0.0516, 0.27, 0.0618),
			"back": Vector3(0, 0.37, 0.162), "chest": Vector3(0, 0.25, -0.179)}},
	"prismander": {"head": Vector3(0, 0.357, -0.212), "top": 0.464, "carry": Vector3(0, 0.517, 0.108),
		"ear_tip": Vector3(0.0622, 0.464, 0.0976), "tail_tip": Vector3(0, 0.264, 0.322), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.154, 0.27, 0.0655), "right flank": Vector3(0.154, 0.27, 0.0655),
			"back": Vector3(0, 0.37, 0.172), "chest": Vector3(0, 0.25, -0.191)}},
	"postroo": {"head": Vector3(0, 0.357, -0.0822), "top": 0.464, "carry": Vector3(0, 0.517, 0.0424),
		"ear_tip": Vector3(0.0275, 0.464, 0.0382), "tail_tip": Vector3(0, 0.264, 0.125), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0679, 0.27, 0.0257), "right flank": Vector3(0.0679, 0.27, 0.0257),
			"back": Vector3(0, 0.37, 0.0673), "chest": Vector3(0, 0.25, -0.0739)}},
	"polyshroom": {"head": Vector3(0, 0.357, -0.0939), "top": 0.464, "carry": Vector3(0, 0.517, 0.0485),
		"ear_tip": Vector3(0.0381, 0.464, 0.0438), "tail_tip": Vector3(0, 0.264, 0.143), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0941, 0.27, 0.0295), "right flank": Vector3(0.0941, 0.27, 0.0295),
			"back": Vector3(0, 0.37, 0.077), "chest": Vector3(0, 0.25, -0.0844)}},
	"pocketpus": {"head": Vector3(0, 0.357, -0.123), "top": 0.464, "carry": Vector3(0, 0.517, 0.0628),
		"ear_tip": Vector3(0.0307, 0.464, 0.0567), "tail_tip": Vector3(0, 0.264, 0.187), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0759, 0.27, 0.0381), "right flank": Vector3(0.0759, 0.27, 0.0381),
			"back": Vector3(0, 0.37, 0.1), "chest": Vector3(0, 0.25, -0.111)}},
	"pinguin": {"head": Vector3(0, 0.357, -0.0927), "top": 0.464, "carry": Vector3(0, 0.517, 0.0482),
		"ear_tip": Vector3(0.0342, 0.464, 0.0435), "tail_tip": Vector3(0, 0.264, 0.142), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0845, 0.27, 0.0294), "right flank": Vector3(0.0845, 0.27, 0.0294),
			"back": Vector3(0, 0.37, 0.0764), "chest": Vector3(0, 0.25, -0.0833)}},
	"pillaroo": {"head": Vector3(0, 0.357, -0.0555), "top": 0.464, "carry": Vector3(0, 0.517, 0.0325),
		"ear_tip": Vector3(0.0343, 0.464, 0.0295), "tail_tip": Vector3(0, 0.264, 0.0911), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0847, 0.27, 0.0207), "right flank": Vector3(0.0847, 0.27, 0.0207),
			"back": Vector3(0, 0.37, 0.0501), "chest": Vector3(0, 0.25, -0.0496)}},
	"palloth": {"head": Vector3(0, 0.357, -0.0461), "top": 0.464, "carry": Vector3(0, 0.517, 0.0213),
		"ear_tip": Vector3(0.0385, 0.464, 0.0191), "tail_tip": Vector3(0, 0.264, 0.0663), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.095, 0.27, 0.0123), "right flank": Vector3(0.095, 0.27, 0.0123),
			"back": Vector3(0, 0.37, 0.0348), "chest": Vector3(0, 0.25, -0.0416)}},
	"orrisol": {"head": Vector3(0, 0.357, -0.0941), "top": 0.464, "carry": Vector3(0, 0.517, 0.0448),
		"ear_tip": Vector3(0.0182, 0.464, 0.0401), "tail_tip": Vector3(0, 0.264, 0.137), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.045, 0.27, 0.0262), "right flank": Vector3(0.045, 0.27, 0.0262),
			"back": Vector3(0, 0.37, 0.0725), "chest": Vector3(0, 0.25, -0.0849)}},
	"orrinox": {"head": Vector3(0, 0.357, -0.0505), "top": 0.464, "carry": Vector3(0, 0.517, 0.0233),
		"ear_tip": Vector3(0.0404, 0.464, 0.0208), "tail_tip": Vector3(0, 0.264, 0.0725), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0997, 0.27, 0.0135), "right flank": Vector3(0.0997, 0.27, 0.0135),
			"back": Vector3(0, 0.37, 0.0381), "chest": Vector3(0, 0.25, -0.0456)}},
	"oarter": {"head": Vector3(0, 0.357, -0.125), "top": 0.464, "carry": Vector3(0, 0.517, 0.0641),
		"ear_tip": Vector3(0.033, 0.464, 0.0578), "tail_tip": Vector3(0, 0.264, 0.19), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0816, 0.27, 0.039), "right flank": Vector3(0.0816, 0.27, 0.039),
			"back": Vector3(0, 0.37, 0.102), "chest": Vector3(0, 0.25, -0.112)}},
	"oarlet": {"head": Vector3(0, 0.357, -0.134), "top": 0.464, "carry": Vector3(0, 0.517, 0.0687),
		"ear_tip": Vector3(0.0305, 0.464, 0.062), "tail_tip": Vector3(0, 0.264, 0.204), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0752, 0.27, 0.0417), "right flank": Vector3(0.0752, 0.27, 0.0417),
			"back": Vector3(0, 0.37, 0.109), "chest": Vector3(0, 0.25, -0.121)}},
	"narfoil": {"head": Vector3(0, 0.357, -0.198), "top": 0.464, "carry": Vector3(0, 0.517, 0.101),
		"ear_tip": Vector3(0.0486, 0.464, 0.0907), "tail_tip": Vector3(0, 0.264, 0.3), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.12, 0.27, 0.0608), "right flank": Vector3(0.12, 0.27, 0.0608),
			"back": Vector3(0, 0.37, 0.16), "chest": Vector3(0, 0.25, -0.178)}},
	"mycroll": {"head": Vector3(0, 0.357, -0.114), "top": 0.464, "carry": Vector3(0, 0.517, 0.0586),
		"ear_tip": Vector3(0.0387, 0.464, 0.0528), "tail_tip": Vector3(0, 0.264, 0.174), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0955, 0.27, 0.0356), "right flank": Vector3(0.0955, 0.27, 0.0356),
			"back": Vector3(0, 0.37, 0.0931), "chest": Vector3(0, 0.25, -0.103)}},
	"mothlet": {"head": Vector3(0, 0.357, -0.0757), "top": 0.464, "carry": Vector3(0, 0.517, 0.0385),
		"ear_tip": Vector3(0.0317, 0.464, 0.0347), "tail_tip": Vector3(0, 0.264, 0.115), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0783, 0.27, 0.0233), "right flank": Vector3(0.0783, 0.27, 0.0233),
			"back": Vector3(0, 0.37, 0.0614), "chest": Vector3(0, 0.25, -0.0681)}},
	"morelossus": {"head": Vector3(0, 0.357, -0.17), "top": 0.464, "carry": Vector3(0, 0.517, 0.084),
		"ear_tip": Vector3(0.0246, 0.464, 0.0755), "tail_tip": Vector3(0, 0.264, 0.254), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0608, 0.27, 0.0501), "right flank": Vector3(0.0608, 0.27, 0.0501),
			"back": Vector3(0, 0.37, 0.135), "chest": Vector3(0, 0.25, -0.153)}},
	"morelkin": {"head": Vector3(0, 0.357, -0.088), "top": 0.464, "carry": Vector3(0, 0.517, 0.0453),
		"ear_tip": Vector3(0.0298, 0.464, 0.0408), "tail_tip": Vector3(0, 0.264, 0.134), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0736, 0.27, 0.0275), "right flank": Vector3(0.0736, 0.27, 0.0275),
			"back": Vector3(0, 0.37, 0.0719), "chest": Vector3(0, 0.25, -0.0791)}},
	"moatpole": {"head": Vector3(0, 0.357, -0.147), "top": 0.464, "carry": Vector3(0, 0.517, 0.0739),
		"ear_tip": Vector3(0.0423, 0.464, 0.0665), "tail_tip": Vector3(0, 0.264, 0.221), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.104, 0.27, 0.0444), "right flank": Vector3(0.104, 0.27, 0.0444),
			"back": Vector3(0, 0.37, 0.118), "chest": Vector3(0, 0.25, -0.132)}},
	"medushroom": {"head": Vector3(0, 0.357, -0.0688), "top": 0.464, "carry": Vector3(0, 0.517, 0.0353),
		"ear_tip": Vector3(0.0345, 0.464, 0.0319), "tail_tip": Vector3(0, 0.264, 0.105), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0851, 0.27, 0.0215), "right flank": Vector3(0.0851, 0.27, 0.0215),
			"back": Vector3(0, 0.37, 0.0562), "chest": Vector3(0, 0.25, -0.0618)}},
	"marimbite": {"head": Vector3(0, 0.357, -0.256), "top": 0.464, "carry": Vector3(0, 0.517, 0.131),
		"ear_tip": Vector3(0.043, 0.464, 0.118), "tail_tip": Vector3(0, 0.264, 0.388), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.106, 0.27, 0.0792), "right flank": Vector3(0.106, 0.27, 0.0792),
			"back": Vector3(0, 0.37, 0.208), "chest": Vector3(0, 0.25, -0.23)}},
	"lunowl": {"head": Vector3(-2.64e-17, 0.357, -0.0555), "top": 0.464, "carry": Vector3(-2.64e-17, 0.517, 0.0281),
		"ear_tip": Vector3(0.0381, 0.464, 0.0253), "tail_tip": Vector3(-2.64e-17, 0.264, 0.0839), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0942, 0.27, 0.0169), "right flank": Vector3(0.0942, 0.27, 0.0169),
			"back": Vector3(-2.64e-17, 0.37, 0.0448), "chest": Vector3(-2.64e-17, 0.25, -0.05)}},
	"lunink": {"head": Vector3(2.64e-17, 0.357, -0.129), "top": 0.464, "carry": Vector3(2.64e-17, 0.517, 0.0655),
		"ear_tip": Vector3(0.0414, 0.464, 0.059), "tail_tip": Vector3(2.64e-17, 0.264, 0.196), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.102, 0.27, 0.0395), "right flank": Vector3(0.102, 0.27, 0.0395),
			"back": Vector3(2.64e-17, 0.37, 0.105), "chest": Vector3(2.64e-17, 0.25, -0.116)}},
	"luckhop": {"head": Vector3(0, 0.357, -0.0854), "top": 0.464, "carry": Vector3(0, 0.517, 0.0433),
		"ear_tip": Vector3(0.0234, 0.464, 0.039), "tail_tip": Vector3(0, 0.264, 0.129), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0578, 0.27, 0.0262), "right flank": Vector3(0.0578, 0.27, 0.0262),
			"back": Vector3(0, 0.37, 0.0691), "chest": Vector3(0, 0.25, -0.0768)}},
	"lockwren": {"head": Vector3(0, 0.357, -0.145), "top": 0.464, "carry": Vector3(0, 0.517, 0.0748),
		"ear_tip": Vector3(0.0487, 0.464, 0.0675), "tail_tip": Vector3(0, 0.264, 0.222), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.12, 0.27, 0.0455), "right flank": Vector3(0.12, 0.27, 0.0455),
			"back": Vector3(0, 0.37, 0.119), "chest": Vector3(0, 0.25, -0.131)}},
	"lensling": {"head": Vector3(0, 0.357, -0.239), "top": 0.464, "carry": Vector3(0, 0.517, 0.123),
		"ear_tip": Vector3(0.0374, 0.464, 0.111), "tail_tip": Vector3(0, 0.264, 0.365), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0924, 0.27, 0.075), "right flank": Vector3(0.0924, 0.27, 0.075),
			"back": Vector3(0, 0.37, 0.196), "chest": Vector3(0, 0.25, -0.215)}},
	"knotwyrm": {"head": Vector3(0, 0.357, -0.0958), "top": 0.464, "carry": Vector3(0, 0.517, 0.0491),
		"ear_tip": Vector3(0.0602, 0.464, 0.0443), "tail_tip": Vector3(0, 0.264, 0.146), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.149, 0.27, 0.0298), "right flank": Vector3(0.149, 0.27, 0.0298),
			"back": Vector3(0, 0.37, 0.0781), "chest": Vector3(0, 0.25, -0.0862)}},
	"kingpinguin": {"head": Vector3(0, 0.357, -0.123), "top": 0.464, "carry": Vector3(0, 0.517, 0.0623),
		"ear_tip": Vector3(0.0525, 0.464, 0.0561), "tail_tip": Vector3(0, 0.264, 0.186), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.13, 0.27, 0.0377), "right flank": Vector3(0.13, 0.27, 0.0377),
			"back": Vector3(0, 0.37, 0.0993), "chest": Vector3(0, 0.25, -0.11)}},
	"kayak": {"head": Vector3(0, 0.357, -0.153), "top": 0.464, "carry": Vector3(0, 0.517, 0.0829),
		"ear_tip": Vector3(0.0329, 0.464, 0.075), "tail_tip": Vector3(0, 0.264, 0.24), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0812, 0.27, 0.0514), "right flank": Vector3(0.0812, 0.27, 0.0514),
			"back": Vector3(0, 0.37, 0.13), "chest": Vector3(0, 0.25, -0.137)}},
	"jerbolt": {"head": Vector3(0, 0.357, -0.0419), "top": 0.464, "carry": Vector3(0, 0.517, 0.0211),
		"ear_tip": Vector3(0.0242, 0.464, 0.019), "tail_tip": Vector3(0, 0.264, 0.0631), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0598, 0.27, 0.0127), "right flank": Vector3(0.0598, 0.27, 0.0127),
			"back": Vector3(0, 0.37, 0.0337), "chest": Vector3(0, 0.25, -0.0377)}},
	"jerbit": {"head": Vector3(0, 0.357, -0.158), "top": 0.464, "carry": Vector3(0, 0.517, 0.0807),
		"ear_tip": Vector3(0.0307, 0.464, 0.0727), "tail_tip": Vector3(0, 0.264, 0.24), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0759, 0.27, 0.0489), "right flank": Vector3(0.0759, 0.27, 0.0489),
			"back": Vector3(0, 0.37, 0.128), "chest": Vector3(0, 0.25, -0.142)}},
	"hatstag": {"head": Vector3(0, 0.357, -0.0875), "top": 0.464, "carry": Vector3(0, 0.517, 0.0441),
		"ear_tip": Vector3(0.0353, 0.464, 0.0397), "tail_tip": Vector3(0, 0.264, 0.132), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0873, 0.27, 0.0265), "right flank": Vector3(0.0873, 0.27, 0.0265),
			"back": Vector3(0, 0.37, 0.0704), "chest": Vector3(0, 0.25, -0.0787)}},
	"gravigrub": {"head": Vector3(0, 0.357, -0.117), "top": 0.464, "carry": Vector3(0, 0.517, 0.0608),
		"ear_tip": Vector3(0.0348, 0.464, 0.0548), "tail_tip": Vector3(0, 0.264, 0.18), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0859, 0.27, 0.037), "right flank": Vector3(0.0859, 0.27, 0.037),
			"back": Vector3(0, 0.37, 0.0964), "chest": Vector3(0, 0.25, -0.106)}},
	"gravadillo": {"head": Vector3(0, 0.357, -0.212), "top": 0.464, "carry": Vector3(0, 0.517, 0.109),
		"ear_tip": Vector3(0.0413, 0.464, 0.098), "tail_tip": Vector3(0, 0.264, 0.323), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.102, 0.27, 0.0659), "right flank": Vector3(0.102, 0.27, 0.0659),
			"back": Vector3(0, 0.37, 0.173), "chest": Vector3(0, 0.25, -0.191)}},
	"gramofrill": {"head": Vector3(2.64e-17, 0.357, -0.144), "top": 0.464, "carry": Vector3(2.64e-17, 0.517, 0.0739),
		"ear_tip": Vector3(0.0408, 0.464, 0.0666), "tail_tip": Vector3(2.64e-17, 0.264, 0.219), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.101, 0.27, 0.0448), "right flank": Vector3(0.101, 0.27, 0.0448),
			"back": Vector3(2.64e-17, 0.37, 0.118), "chest": Vector3(2.64e-17, 0.25, -0.13)}},
	"gongibbon": {"head": Vector3(0, 0.357, -0.0899), "top": 0.464, "carry": Vector3(0, 0.517, 0.0455),
		"ear_tip": Vector3(0.0354, 0.464, 0.0409), "tail_tip": Vector3(0, 0.264, 0.136), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0874, 0.27, 0.0274), "right flank": Vector3(0.0874, 0.27, 0.0274),
			"back": Vector3(0, 0.37, 0.0725), "chest": Vector3(0, 0.25, -0.0809)}},
	"glockodile": {"head": Vector3(0, 0.357, -0.178), "top": 0.464, "carry": Vector3(0, 0.517, 0.0907),
		"ear_tip": Vector3(0.0338, 0.464, 0.0817), "tail_tip": Vector3(0, 0.264, 0.269), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0836, 0.27, 0.0549), "right flank": Vector3(0.0836, 0.27, 0.0549),
			"back": Vector3(0, 0.37, 0.144), "chest": Vector3(0, 0.25, -0.16)}},
	"gloamwade": {"head": Vector3(0, 0.357, -0.171), "top": 0.464, "carry": Vector3(0, 0.517, 0.0952),
		"ear_tip": Vector3(0.0162, 0.464, 0.0863), "tail_tip": Vector3(0, 0.264, 0.273), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0401, 0.27, 0.0597), "right flank": Vector3(0.0401, 0.27, 0.0597),
			"back": Vector3(0, 0.37, 0.148), "chest": Vector3(0, 0.25, -0.153)}},
	"glaivyx": {"head": Vector3(0, 0.357, -0.139), "top": 0.464, "carry": Vector3(0, 0.517, 0.0693),
		"ear_tip": Vector3(0.0281, 0.464, 0.0624), "tail_tip": Vector3(0, 0.264, 0.208), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0695, 0.27, 0.0416), "right flank": Vector3(0.0695, 0.27, 0.0416),
			"back": Vector3(0, 0.37, 0.111), "chest": Vector3(0, 0.25, -0.125)}},
	"galleotter": {"head": Vector3(0, 0.357, -0.209), "top": 0.464, "carry": Vector3(0, 0.517, 0.107),
		"ear_tip": Vector3(0.0314, 0.464, 0.0962), "tail_tip": Vector3(0, 0.264, 0.317), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0777, 0.27, 0.0647), "right flank": Vector3(0.0777, 0.27, 0.0647),
			"back": Vector3(0, 0.37, 0.17), "chest": Vector3(0, 0.25, -0.188)}},
	"furnacowary": {"head": Vector3(1.32e-17, 0.357, -0.0832), "top": 0.464, "carry": Vector3(1.32e-17, 0.517, 0.043),
		"ear_tip": Vector3(0.0191, 0.464, 0.0388), "tail_tip": Vector3(1.32e-17, 0.264, 0.127), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0473, 0.27, 0.0262), "right flank": Vector3(0.0473, 0.27, 0.0262),
			"back": Vector3(1.32e-17, 0.37, 0.0683), "chest": Vector3(1.32e-17, 0.25, -0.0748)}},
	"frigatee": {"head": Vector3(0, 0.357, -0.194), "top": 0.464, "carry": Vector3(0, 0.517, 0.099),
		"ear_tip": Vector3(0.0549, 0.464, 0.0892), "tail_tip": Vector3(0, 0.264, 0.294), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.136, 0.27, 0.0599), "right flank": Vector3(0.136, 0.27, 0.0599),
			"back": Vector3(0, 0.37, 0.158), "chest": Vector3(0, 0.25, -0.175)}},
	"foalaround": {"head": Vector3(0, 0.357, -0.112), "top": 0.464, "carry": Vector3(0, 0.517, 0.061),
		"ear_tip": Vector3(0.0162, 0.464, 0.0552), "tail_tip": Vector3(0, 0.264, 0.176), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0401, 0.27, 0.0379), "right flank": Vector3(0.0401, 0.27, 0.0379),
			"back": Vector3(0, 0.37, 0.0955), "chest": Vector3(0, 0.25, -0.1)}},
	"fizzlet": {"head": Vector3(0, 0.357, -0.0654), "top": 0.464, "carry": Vector3(0, 0.517, 0.033),
		"ear_tip": Vector3(0.0185, 0.464, 0.0297), "tail_tip": Vector3(0, 0.264, 0.0986), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0456, 0.27, 0.0198), "right flank": Vector3(0.0456, 0.27, 0.0198),
			"back": Vector3(0, 0.37, 0.0526), "chest": Vector3(0, 0.25, -0.0589)}},
	"filefin": {"head": Vector3(0, 0.357, -0.349), "top": 0.464, "carry": Vector3(0, 0.517, 0.179),
		"ear_tip": Vector3(0.0597, 0.464, 0.161), "tail_tip": Vector3(0, 0.264, 0.531), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.148, 0.27, 0.108), "right flank": Vector3(0.148, 0.27, 0.108),
			"back": Vector3(0, 0.37, 0.284), "chest": Vector3(0, 0.25, -0.314)}},
	"fawngus": {"head": Vector3(0, 0.357, -0.148), "top": 0.464, "carry": Vector3(0, 0.517, 0.0756),
		"ear_tip": Vector3(0.0562, 0.464, 0.0682), "tail_tip": Vector3(0, 0.264, 0.224), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.139, 0.27, 0.0458), "right flank": Vector3(0.139, 0.27, 0.0458),
			"back": Vector3(0, 0.37, 0.12), "chest": Vector3(0, 0.25, -0.133)}},
	"ermink": {"head": Vector3(0, 0.357, -0.14), "top": 0.464, "carry": Vector3(0, 0.517, 0.0715),
		"ear_tip": Vector3(0.0363, 0.464, 0.0645), "tail_tip": Vector3(0, 0.264, 0.212), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0898, 0.27, 0.0434), "right flank": Vector3(0.0898, 0.27, 0.0434),
			"back": Vector3(0, 0.37, 0.114), "chest": Vector3(0, 0.25, -0.126)}},
	"echolop": {"head": Vector3(-1.32e-17, 0.357, -0.0768), "top": 0.464, "carry": Vector3(-1.32e-17, 0.517, 0.0394),
		"ear_tip": Vector3(0.0247, 0.464, 0.0355), "tail_tip": Vector3(-1.32e-17, 0.264, 0.117), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0609, 0.27, 0.0239), "right flank": Vector3(0.0609, 0.27, 0.0239),
			"back": Vector3(-1.32e-17, 0.37, 0.0626), "chest": Vector3(-1.32e-17, 0.25, -0.0691)}},
	"dynaboa": {"head": Vector3(-2.64e-17, 0.357, -0.149), "top": 0.464, "carry": Vector3(-2.64e-17, 0.517, 0.0761),
		"ear_tip": Vector3(0.0465, 0.464, 0.0686), "tail_tip": Vector3(-2.64e-17, 0.264, 0.226), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.115, 0.27, 0.0461), "right flank": Vector3(0.115, 0.27, 0.0461),
			"back": Vector3(-2.64e-17, 0.37, 0.121), "chest": Vector3(-2.64e-17, 0.25, -0.134)}},
	"domeleon": {"head": Vector3(0, 0.357, -0.101), "top": 0.464, "carry": Vector3(0, 0.517, 0.0522),
		"ear_tip": Vector3(0.0227, 0.464, 0.0471), "tail_tip": Vector3(0, 0.264, 0.154), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.056, 0.27, 0.0317), "right flank": Vector3(0.056, 0.27, 0.0317),
			"back": Vector3(0, 0.37, 0.0828), "chest": Vector3(0, 0.25, -0.0909)}},
	"cubbat": {"head": Vector3(2.64e-17, 0.357, -0.159), "top": 0.464, "carry": Vector3(2.64e-17, 0.517, 0.0815),
		"ear_tip": Vector3(0.0473, 0.464, 0.0734), "tail_tip": Vector3(2.64e-17, 0.264, 0.242), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.117, 0.27, 0.0494), "right flank": Vector3(0.117, 0.27, 0.0494),
			"back": Vector3(2.64e-17, 0.37, 0.13), "chest": Vector3(2.64e-17, 0.25, -0.143)}},
	"critwom": {"head": Vector3(0, 0.357, -0.171), "top": 0.464, "carry": Vector3(0, 0.517, 0.0842),
		"ear_tip": Vector3(0.0473, 0.464, 0.0757), "tail_tip": Vector3(0, 0.264, 0.254), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.117, 0.27, 0.0502), "right flank": Vector3(0.117, 0.27, 0.0502),
			"back": Vector3(0, 0.37, 0.135), "chest": Vector3(0, 0.25, -0.154)}},
	"coolatee": {"head": Vector3(0, 0.357, -0.148), "top": 0.464, "carry": Vector3(0, 0.517, 0.0754),
		"ear_tip": Vector3(0.0482, 0.464, 0.068), "tail_tip": Vector3(0, 0.264, 0.224), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.119, 0.27, 0.0457), "right flank": Vector3(0.119, 0.27, 0.0457),
			"back": Vector3(0, 0.37, 0.12), "chest": Vector3(0, 0.25, -0.133)}},
	"cometail": {"head": Vector3(1.32e-17, 0.357, -0.146), "top": 0.464, "carry": Vector3(1.32e-17, 0.517, 0.0735),
		"ear_tip": Vector3(0.0247, 0.464, 0.0662), "tail_tip": Vector3(1.32e-17, 0.264, 0.22), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.061, 0.27, 0.0443), "right flank": Vector3(0.061, 0.27, 0.0443),
			"back": Vector3(1.32e-17, 0.37, 0.117), "chest": Vector3(1.32e-17, 0.25, -0.131)}},
	"chimelop": {"head": Vector3(0, 0.357, -0.0872), "top": 0.464, "carry": Vector3(0, 0.517, 0.0444),
		"ear_tip": Vector3(0.0261, 0.464, 0.04), "tail_tip": Vector3(0, 0.264, 0.132), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0645, 0.27, 0.0269), "right flank": Vector3(0.0645, 0.27, 0.0269),
			"back": Vector3(0, 0.37, 0.0707), "chest": Vector3(0, 0.25, -0.0784)}},
	"carrousteed": {"head": Vector3(0, 0.357, -0.0974), "top": 0.464, "carry": Vector3(0, 0.517, 0.0495),
		"ear_tip": Vector3(0.0285, 0.464, 0.0446), "tail_tip": Vector3(0, 0.264, 0.147), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0704, 0.27, 0.0299), "right flank": Vector3(0.0704, 0.27, 0.0299),
			"back": Vector3(0, 0.37, 0.0788), "chest": Vector3(0, 0.25, -0.0876)}},
	"carpenjaw": {"head": Vector3(0, 0.357, -0.139), "top": 0.464, "carry": Vector3(0, 0.517, 0.071),
		"ear_tip": Vector3(0.0329, 0.464, 0.064), "tail_tip": Vector3(0, 0.264, 0.211), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0812, 0.27, 0.043), "right flank": Vector3(0.0812, 0.27, 0.043),
			"back": Vector3(0, 0.37, 0.113), "chest": Vector3(0, 0.25, -0.125)}},
	"canopony": {"head": Vector3(0, 0.357, -0.136), "top": 0.464, "carry": Vector3(0, 0.517, 0.0704),
		"ear_tip": Vector3(0.024, 0.464, 0.0635), "tail_tip": Vector3(0, 0.264, 0.208), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0594, 0.27, 0.0428), "right flank": Vector3(0.0594, 0.27, 0.0428),
			"back": Vector3(0, 0.37, 0.112), "chest": Vector3(0, 0.25, -0.122)}},
	"calderoise": {"head": Vector3(0, 0.357, -0.139), "top": 0.464, "carry": Vector3(0, 0.517, 0.0712),
		"ear_tip": Vector3(0.0418, 0.464, 0.0641), "tail_tip": Vector3(0, 0.264, 0.211), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.103, 0.27, 0.0431), "right flank": Vector3(0.103, 0.27, 0.0431),
			"back": Vector3(0, 0.37, 0.113), "chest": Vector3(0, 0.25, -0.125)}},
	"bullsfrog": {"head": Vector3(0, 0.357, -0.257), "top": 0.464, "carry": Vector3(0, 0.517, 0.131),
		"ear_tip": Vector3(0.0448, 0.464, 0.118), "tail_tip": Vector3(0, 0.264, 0.39), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.111, 0.27, 0.0795), "right flank": Vector3(0.111, 0.27, 0.0795),
			"back": Vector3(0, 0.37, 0.209), "chest": Vector3(0, 0.25, -0.231)}},
	"bullpole": {"head": Vector3(0, 0.357, -0.183), "top": 0.464, "carry": Vector3(0, 0.517, 0.0935),
		"ear_tip": Vector3(0.045, 0.464, 0.0843), "tail_tip": Vector3(0, 0.264, 0.278), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.111, 0.27, 0.0567), "right flank": Vector3(0.111, 0.27, 0.0567),
			"back": Vector3(0, 0.37, 0.149), "chest": Vector3(0, 0.25, -0.164)}},
	"bubblisk": {"head": Vector3(0, 0.357, -0.165), "top": 0.464, "carry": Vector3(0, 0.517, 0.0841),
		"ear_tip": Vector3(0.0397, 0.464, 0.0759), "tail_tip": Vector3(0, 0.264, 0.25), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0981, 0.27, 0.051), "right flank": Vector3(0.0981, 0.27, 0.051),
			"back": Vector3(0, 0.37, 0.134), "chest": Vector3(0, 0.25, -0.148)}},
	"brumetide": {"head": Vector3(0, 0.357, -0.0878), "top": 0.464, "carry": Vector3(0, 0.517, 0.0446),
		"ear_tip": Vector3(0.0304, 0.464, 0.0402), "tail_tip": Vector3(0, 0.264, 0.133), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0752, 0.27, 0.027), "right flank": Vector3(0.0752, 0.27, 0.027),
			"back": Vector3(0, 0.37, 0.0711), "chest": Vector3(0, 0.25, -0.079)}},
	"blotlet": {"head": Vector3(0, 0.357, -0.119), "top": 0.464, "carry": Vector3(0, 0.517, 0.0607),
		"ear_tip": Vector3(0.045, 0.464, 0.0547), "tail_tip": Vector3(0, 0.264, 0.18), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.111, 0.27, 0.0368), "right flank": Vector3(0.111, 0.27, 0.0368),
			"back": Vector3(0, 0.37, 0.0966), "chest": Vector3(0, 0.25, -0.107)}},
	"bladypus": {"head": Vector3(0, 0.357, -0.262), "top": 0.464, "carry": Vector3(0, 0.517, 0.134),
		"ear_tip": Vector3(0.0299, 0.464, 0.121), "tail_tip": Vector3(0, 0.264, 0.399), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0739, 0.27, 0.0813), "right flank": Vector3(0.0739, 0.27, 0.0813),
			"back": Vector3(0, 0.37, 0.214), "chest": Vector3(0, 0.25, -0.236)}},
	"bellowlet": {"head": Vector3(-1.32e-17, 0.357, -0.0877), "top": 0.464, "carry": Vector3(-1.32e-17, 0.517, 0.0441),
		"ear_tip": Vector3(0.0245, 0.464, 0.0397), "tail_tip": Vector3(-1.32e-17, 0.264, 0.132), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0605, 0.27, 0.0265), "right flank": Vector3(0.0605, 0.27, 0.0265),
			"back": Vector3(-1.32e-17, 0.37, 0.0704), "chest": Vector3(-1.32e-17, 0.25, -0.0789)}},
	"bathilus": {"head": Vector3(2.64e-17, 0.357, -0.108), "top": 0.464, "carry": Vector3(2.64e-17, 0.517, 0.0544),
		"ear_tip": Vector3(0.0413, 0.464, 0.049), "tail_tip": Vector3(2.64e-17, 0.264, 0.162), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.102, 0.27, 0.0328), "right flank": Vector3(0.102, 0.27, 0.0328),
			"back": Vector3(2.64e-17, 0.37, 0.0868), "chest": Vector3(2.64e-17, 0.25, -0.097)}},
	"bastling": {"head": Vector3(0, 0.357, -0.135), "top": 0.464, "carry": Vector3(0, 0.517, 0.0691),
		"ear_tip": Vector3(0.0683, 0.464, 0.0623), "tail_tip": Vector3(0, 0.264, 0.205), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.169, 0.27, 0.0418), "right flank": Vector3(0.169, 0.27, 0.0418),
			"back": Vector3(0, 0.37, 0.11), "chest": Vector3(0, 0.25, -0.122)}},
	"bastionpet": {"head": Vector3(5.27e-17, 0.357, -0.129), "top": 0.464, "carry": Vector3(5.27e-17, 0.517, 0.0668),
		"ear_tip": Vector3(0.0706, 0.464, 0.0602), "tail_tip": Vector3(5.27e-17, 0.264, 0.198), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.174, 0.27, 0.0406), "right flank": Vector3(0.174, 0.27, 0.0406),
			"back": Vector3(5.27e-17, 0.37, 0.106), "chest": Vector3(5.27e-17, 0.25, -0.116)}},
	"barokit": {"head": Vector3(0, 0.357, -0.101), "top": 0.464, "carry": Vector3(0, 0.517, 0.0514),
		"ear_tip": Vector3(0.0325, 0.464, 0.0464), "tail_tip": Vector3(0, 0.264, 0.153), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0802, 0.27, 0.0312), "right flank": Vector3(0.0802, 0.27, 0.0312),
			"back": Vector3(0, 0.37, 0.0818), "chest": Vector3(0, 0.25, -0.0904)}},
	"anchorbill": {"head": Vector3(0, 0.357, -0.135), "top": 0.464, "carry": Vector3(0, 0.517, 0.0685),
		"ear_tip": Vector3(0.0388, 0.464, 0.0617), "tail_tip": Vector3(0, 0.264, 0.204), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0958, 0.27, 0.0413), "right flank": Vector3(0.0958, 0.27, 0.0413),
			"back": Vector3(0, 0.37, 0.109), "chest": Vector3(0, 0.25, -0.122)}},
	"pipeworth": {"head": Vector3(0, 0.357, -0.105), "top": 0.464, "carry": Vector3(0, 0.517, 0.054),
		"ear_tip": Vector3(0.0162, 0.464, 0.0487), "tail_tip": Vector3(0, 0.264, 0.16),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0399, 0.27, 0.0328), "right flank": Vector3(0.0399, 0.27, 0.0328),
			"back": Vector3(0, 0.37, 0.0858), "chest": Vector3(0, 0.25, -0.0943)}},
	"barostorm": {"head": Vector3(0, 0.357, -0.149), "top": 0.464, "carry": Vector3(0, 0.517, 0.0765),
		"ear_tip": Vector3(0.026, 0.464, 0.0689), "tail_tip": Vector3(0, 0.264, 0.227),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0644, 0.27, 0.0463), "right flank": Vector3(0.0644, 0.27, 0.0463),
			"back": Vector3(0, 0.37, 0.122), "chest": Vector3(0, 0.25, -0.134)}},
	"selenwhale": {"head": Vector3(0, 0.357, -0.142), "top": 0.464, "carry": Vector3(0, 0.517, 0.0725),
		"ear_tip": Vector3(0.029, 0.464, 0.0654), "tail_tip": Vector3(0, 0.264, 0.215),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0716, 0.27, 0.0439), "right flank": Vector3(0.0716, 0.27, 0.0439),
			"back": Vector3(0, 0.37, 0.115), "chest": Vector3(0, 0.25, -0.127)}},
	"rimefang": {"head": Vector3(0, 0.357, -0.145), "top": 0.464, "carry": Vector3(0, 0.517, 0.0741),
		"ear_tip": Vector3(0.0306, 0.464, 0.0668), "tail_tip": Vector3(0, 0.264, 0.22),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0755, 0.27, 0.0449), "right flank": Vector3(0.0755, 0.27, 0.0449),
			"back": Vector3(0, 0.37, 0.118), "chest": Vector3(0, 0.25, -0.13)}},
	"strobolin": {"head": Vector3(0, 0.357, -0.0715), "top": 0.464, "carry": Vector3(0, 0.517, 0.0372),
		"ear_tip": Vector3(0.0251, 0.464, 0.0335), "tail_tip": Vector3(0, 0.264, 0.11),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.062, 0.27, 0.0227), "right flank": Vector3(0.062, 0.27, 0.0227),
			"back": Vector3(0, 0.37, 0.0589), "chest": Vector3(0, 0.25, -0.0643)}},
	"murmuron": {"head": Vector3(0, 0.357, -0.0828), "top": 0.464, "carry": Vector3(0, 0.517, 0.0403),
		"ear_tip": Vector3(0.0448, 0.464, 0.0362), "tail_tip": Vector3(0, 0.264, 0.122),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.111, 0.27, 0.0239), "right flank": Vector3(0.111, 0.27, 0.0239),
			"back": Vector3(0, 0.37, 0.065), "chest": Vector3(0, 0.25, -0.0746)}},
	"mossbastion": {"head": Vector3(0, 0.357, -0.159), "top": 0.464, "carry": Vector3(0, 0.517, 0.0813),
		"ear_tip": Vector3(0.0511, 0.464, 0.0733), "tail_tip": Vector3(0, 0.264, 0.241),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.126, 0.27, 0.0494), "right flank": Vector3(0.126, 0.27, 0.0494),
			"back": Vector3(0, 0.37, 0.129), "chest": Vector3(0, 0.25, -0.143)}},
	"lanternlong": {"head": Vector3(0, 0.357, -0.0619), "top": 0.464, "carry": Vector3(0, 0.517, 0.0316),
		"ear_tip": Vector3(0.0138, 0.464, 0.0285), "tail_tip": Vector3(0, 0.264, 0.0939),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0341, 0.27, 0.0191), "right flank": Vector3(0.0341, 0.27, 0.0191),
			"back": Vector3(0, 0.37, 0.0503), "chest": Vector3(0, 0.25, -0.0557)}},
	"lodestaff": {"head": Vector3(0, 0.357, -0.0973), "top": 0.464, "carry": Vector3(0, 0.517, 0.0496),
		"ear_tip": Vector3(0.0363, 0.464, 0.0447), "tail_tip": Vector3(0, 0.264, 0.148),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0897, 0.27, 0.03), "right flank": Vector3(0.0897, 0.27, 0.03),
			"back": Vector3(0, 0.37, 0.079), "chest": Vector3(0, 0.25, -0.0875)}},
	"citadoad": {"head": Vector3(0, 0.357, -0.154), "top": 0.464, "carry": Vector3(0, 0.517, 0.0793),
		"ear_tip": Vector3(0.0403, 0.464, 0.0715), "tail_tip": Vector3(0, 0.264, 0.235),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0996, 0.27, 0.0481), "right flank": Vector3(0.0996, 0.27, 0.0481),
			"back": Vector3(0, 0.37, 0.126), "chest": Vector3(0, 0.25, -0.139)}},
	"crofthollow": {"head": Vector3(0, 0.357, -0.135), "top": 0.464, "carry": Vector3(0, 0.517, 0.0687),
		"ear_tip": Vector3(0.0332, 0.464, 0.062), "tail_tip": Vector3(0, 0.264, 0.204),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0819, 0.27, 0.0416), "right flank": Vector3(0.0819, 0.27, 0.0416),
			"back": Vector3(0, 0.37, 0.109), "chest": Vector3(0, 0.25, -0.121)}},
	"effigoon": {"head": Vector3(0, 0.357, -0.0735), "top": 0.464, "carry": Vector3(0, 0.517, 0.0386),
		"ear_tip": Vector3(0.021, 0.464, 0.0349), "tail_tip": Vector3(0, 0.264, 0.113),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0519, 0.27, 0.0236), "right flank": Vector3(0.0519, 0.27, 0.0236),
			"back": Vector3(0, 0.37, 0.061), "chest": Vector3(0, 0.25, -0.066)}},
	"glomworth": {"head": Vector3(0, 0.357, -0.129), "top": 0.464, "carry": Vector3(0, 0.517, 0.0643),
		"ear_tip": Vector3(0.0557, 0.464, 0.0579), "tail_tip": Vector3(0, 0.264, 0.193),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.138, 0.27, 0.0386), "right flank": Vector3(0.138, 0.27, 0.0386),
			"back": Vector3(0, 0.37, 0.103), "chest": Vector3(0, 0.25, -0.116)}},
	"gloamspire": {"head": Vector3(0, 0.357, -0.0895), "top": 0.464, "carry": Vector3(0, 0.517, 0.0438),
		"ear_tip": Vector3(0.0215, 0.464, 0.0394), "tail_tip": Vector3(0, 0.264, 0.133),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0532, 0.27, 0.0261), "right flank": Vector3(0.0532, 0.27, 0.0261),
			"back": Vector3(0, 0.37, 0.0705), "chest": Vector3(0, 0.25, -0.0806)}},
	"anchorhorn": {"head": Vector3(0, 0.357, -0.281), "top": 0.464, "carry": Vector3(0, 0.517, 0.144),
		"ear_tip": Vector3(0.0868, 0.464, 0.13), "tail_tip": Vector3(0, 0.264, 0.427), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.214, 0.27, 0.0871), "right flank": Vector3(0.214, 0.27, 0.0871),
			"back": Vector3(0, 0.37, 0.229), "chest": Vector3(0, 0.25, -0.253)}},
	"gravitank": {"head": Vector3(0, 0.357, -0.151), "top": 0.464, "carry": Vector3(0, 0.517, 0.0768),
		"ear_tip": Vector3(0.0418, 0.464, 0.0692), "tail_tip": Vector3(0, 0.264, 0.228),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.103, 0.27, 0.0464), "right flank": Vector3(0.103, 0.27, 0.0464),
			"back": Vector3(0, 0.37, 0.122), "chest": Vector3(0, 0.25, -0.135)}},
	"vaultara": {"head": Vector3(0, 0.357, -0.19), "top": 0.464, "carry": Vector3(0, 0.517, 0.0967),
		"ear_tip": Vector3(0.0347, 0.464, 0.0872), "tail_tip": Vector3(0, 0.264, 0.288),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0857, 0.27, 0.0585), "right flank": Vector3(0.0857, 0.27, 0.0585),
			"back": Vector3(0, 0.37, 0.154), "chest": Vector3(0, 0.25, -0.171)}},
	"gongrowl": {"head": Vector3(0, 0.357, -0.0719), "top": 0.464, "carry": Vector3(0, 0.517, 0.0331),
		"ear_tip": Vector3(0.0346, 0.464, 0.0296), "tail_tip": Vector3(0, 0.264, 0.103),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0856, 0.27, 0.0191), "right flank": Vector3(0.0856, 0.27, 0.0191),
			"back": Vector3(0, 0.37, 0.0541), "chest": Vector3(0, 0.25, -0.0649)}},
	"howlop": {"head": Vector3(0, 0.357, -0.13), "top": 0.464, "carry": Vector3(0, 0.517, 0.0641),
		"ear_tip": Vector3(0.0564, 0.464, 0.0576), "tail_tip": Vector3(0, 0.264, 0.193),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.139, 0.27, 0.0383), "right flank": Vector3(0.139, 0.27, 0.0383),
			"back": Vector3(0, 0.37, 0.103), "chest": Vector3(0, 0.25, -0.117)}},
	"eclipsowl": {"head": Vector3(2.64e-17, 0.357, -0.126), "top": 0.464, "carry": Vector3(2.64e-17, 0.517, 0.0643),
		"ear_tip": Vector3(0.0327, 0.464, 0.058), "tail_tip": Vector3(2.64e-17, 0.264, 0.191),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0807, 0.27, 0.0389), "right flank": Vector3(0.0807, 0.27, 0.0389),
			"back": Vector3(2.64e-17, 0.37, 0.102), "chest": Vector3(2.64e-17, 0.25, -0.113)}},
	"lyrewing": {"head": Vector3(0, 0.357, -0.0775), "top": 0.464, "carry": Vector3(0, 0.517, 0.0356),
		"ear_tip": Vector3(0.0488, 0.464, 0.0319), "tail_tip": Vector3(0, 0.264, 0.111),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.12, 0.27, 0.0205), "right flank": Vector3(0.12, 0.27, 0.0205),
			"back": Vector3(0, 0.37, 0.0583), "chest": Vector3(0, 0.25, -0.07)}},
	"thistlynx": {"head": Vector3(0, 0.357, -0.0967), "top": 0.464, "carry": Vector3(0, 0.517, 0.0501),
		"ear_tip": Vector3(0.0282, 0.464, 0.0452), "tail_tip": Vector3(0, 0.264, 0.148),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0698, 0.27, 0.0305), "right flank": Vector3(0.0698, 0.27, 0.0305),
			"back": Vector3(0, 0.37, 0.0794), "chest": Vector3(0, 0.25, -0.0869)}},
	"scythant": {"head": Vector3(0, 0.357, -0.151), "top": 0.464, "carry": Vector3(0, 0.517, 0.0772),
		"ear_tip": Vector3(0.031, 0.464, 0.0696), "tail_tip": Vector3(0, 0.264, 0.229),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0766, 0.27, 0.0467), "right flank": Vector3(0.0766, 0.27, 0.0467),
			"back": Vector3(0, 0.37, 0.123), "chest": Vector3(0, 0.25, -0.136)}},
	"shinobant": {"head": Vector3(0, 0.357, -0.119), "top": 0.464, "carry": Vector3(0, 0.517, 0.0585),
		"ear_tip": Vector3(0.0523, 0.464, 0.0526), "tail_tip": Vector3(0, 0.264, 0.177),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.129, 0.27, 0.0348), "right flank": Vector3(0.129, 0.27, 0.0348),
			"back": Vector3(0, 0.37, 0.0941), "chest": Vector3(0, 0.25, -0.107)}},
	"arcestrel": {"head": Vector3(-1.32e-17, 0.357, -0.105), "top": 0.464, "carry": Vector3(-1.32e-17, 0.517, 0.0565),
		"ear_tip": Vector3(0.0209, 0.464, 0.0511), "tail_tip": Vector3(-1.32e-17, 0.264, 0.164),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0516, 0.27, 0.0349), "right flank": Vector3(0.0516, 0.27, 0.0349),
			"back": Vector3(-1.32e-17, 0.37, 0.0888), "chest": Vector3(-1.32e-17, 0.25, -0.0943)}},
	"tidalisk": {"head": Vector3(0, 0.357, -0.113), "top": 0.464, "carry": Vector3(0, 0.517, 0.0575),
		"ear_tip": Vector3(0.0401, 0.464, 0.0518), "tail_tip": Vector3(0, 0.264, 0.171),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0991, 0.27, 0.0348), "right flank": Vector3(0.0991, 0.27, 0.0348),
			"back": Vector3(0, 0.37, 0.0915), "chest": Vector3(0, 0.25, -0.101)}},
	"forgebrock": {"head": Vector3(0, 0.357, -0.106), "top": 0.464, "carry": Vector3(0, 0.517, 0.0365),
		"ear_tip": Vector3(0.0457, 0.464, 0.0318), "tail_tip": Vector3(0, 0.264, 0.132),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.113, 0.27, 0.0175), "right flank": Vector3(0.113, 0.27, 0.0175),
			"back": Vector3(0, 0.37, 0.0651), "chest": Vector3(0, 0.25, -0.0968)}},
	"cisternmander": {"head": Vector3(0, 0.357, -0.225), "top": 0.464, "carry": Vector3(0, 0.517, 0.115),
		"ear_tip": Vector3(0.0555, 0.464, 0.103), "tail_tip": Vector3(0, 0.264, 0.341),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.137, 0.27, 0.0695), "right flank": Vector3(0.137, 0.27, 0.0695),
			"back": Vector3(0, 0.37, 0.183), "chest": Vector3(0, 0.25, -0.202)}},
	"thunderstrich": {"head": Vector3(0, 0.357, -0.0819), "top": 0.464, "carry": Vector3(0, 0.517, 0.0422),
		"ear_tip": Vector3(0.0299, 0.464, 0.0381), "tail_tip": Vector3(0, 0.264, 0.125),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0739, 0.27, 0.0257), "right flank": Vector3(0.0739, 0.27, 0.0257),
			"back": Vector3(0, 0.37, 0.0671), "chest": Vector3(0, 0.25, -0.0736)}},
	"glaciatee": {"head": Vector3(0, 0.357, -0.103), "top": 0.464, "carry": Vector3(0, 0.517, 0.0538),
		"ear_tip": Vector3(0.0389, 0.464, 0.0486), "tail_tip": Vector3(0, 0.264, 0.158),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0961, 0.27, 0.033), "right flank": Vector3(0.0961, 0.27, 0.033),
			"back": Vector3(0, 0.37, 0.0851), "chest": Vector3(0, 0.25, -0.0921)}},
	"dreadnoyak": {"head": Vector3(0, 0.357, -0.213), "top": 0.464, "carry": Vector3(0, 0.517, 0.109),
		"ear_tip": Vector3(0.0354, 0.464, 0.0984), "tail_tip": Vector3(0, 0.264, 0.324),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0875, 0.27, 0.0662), "right flank": Vector3(0.0875, 0.27, 0.0662),
			"back": Vector3(0, 0.37, 0.174), "chest": Vector3(0, 0.25, -0.192)}},
	"geysirbara": {"head": Vector3(0, 0.357, -0.102), "top": 0.464, "carry": Vector3(0, 0.517, 0.0521),
		"ear_tip": Vector3(0.04, 0.464, 0.0469), "tail_tip": Vector3(0, 0.264, 0.155), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0988, 0.27, 0.0315), "right flank": Vector3(0.0988, 0.27, 0.0315),
			"back": Vector3(0, 0.37, 0.0829), "chest": Vector3(0, 0.25, -0.0918)}},
	"embrook": {"head": Vector3(-1.32e-17, 0.357, -0.103), "top": 0.464, "carry": Vector3(-1.32e-17, 0.517, 0.0525),
		"ear_tip": Vector3(0.0217, 0.464, 0.0473), "tail_tip": Vector3(-1.32e-17, 0.264, 0.156),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0537, 0.27, 0.0318), "right flank": Vector3(0.0537, 0.27, 0.0318),
			"back": Vector3(-1.32e-17, 0.37, 0.0835), "chest": Vector3(-1.32e-17, 0.25, -0.0924)}},
	"geodemole": {"head": Vector3(0, 0.357, -0.0961), "top": 0.464, "carry": Vector3(0, 0.517, 0.051),
		"ear_tip": Vector3(0.0325, 0.464, 0.0461), "tail_tip": Vector3(0, 0.264, 0.149),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0802, 0.27, 0.0314), "right flank": Vector3(0.0802, 0.27, 0.0314),
			"back": Vector3(0, 0.37, 0.0804), "chest": Vector3(0, 0.25, -0.0863)}},
	"seamwyrm": {"head": Vector3(0, 0.357, -0.0857), "top": 0.464, "carry": Vector3(0, 0.517, 0.0465),
		"ear_tip": Vector3(0.0341, 0.464, 0.0421), "tail_tip": Vector3(0, 0.264, 0.135),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0843, 0.27, 0.0289), "right flank": Vector3(0.0843, 0.27, 0.0289),
			"back": Vector3(0, 0.37, 0.073), "chest": Vector3(0, 0.25, -0.0769)}},
	"lanceron": {"head": Vector3(0, 0.357, -0.0764), "top": 0.464, "carry": Vector3(0, 0.517, 0.039),
		"ear_tip": Vector3(0.0197, 0.464, 0.0351), "tail_tip": Vector3(0, 0.264, 0.116),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0486, 0.27, 0.0236), "right flank": Vector3(0.0486, 0.27, 0.0236),
			"back": Vector3(0, 0.37, 0.062), "chest": Vector3(0, 0.25, -0.0687)}},
	"glassolotl": {"head": Vector3(0, 0.357, -0.0763), "top": 0.464, "carry": Vector3(0, 0.517, 0.0394),
		"ear_tip": Vector3(0.0237, 0.464, 0.0355), "tail_tip": Vector3(0, 0.264, 0.116),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0587, 0.27, 0.0239), "right flank": Vector3(0.0587, 0.27, 0.0239),
			"back": Vector3(0, 0.37, 0.0625), "chest": Vector3(0, 0.25, -0.0686)}},
	"vespox": {"head": Vector3(0, 0.357, -0.0955), "top": 0.464, "carry": Vector3(0, 0.517, 0.0489),
		"ear_tip": Vector3(0.0165, 0.464, 0.0441), "tail_tip": Vector3(0, 0.264, 0.145),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0409, 0.27, 0.0296), "right flank": Vector3(0.0409, 0.27, 0.0296),
			"back": Vector3(0, 0.37, 0.0778), "chest": Vector3(0, 0.25, -0.0859)}},
	"sporcupine": {"head": Vector3(0, 0.357, -0.124), "top": 0.464, "carry": Vector3(0, 0.517, 0.0631),
		"ear_tip": Vector3(0.0211, 0.464, 0.0568), "tail_tip": Vector3(0, 0.264, 0.188),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.052, 0.27, 0.0381), "right flank": Vector3(0.052, 0.27, 0.0381),
			"back": Vector3(0, 0.37, 0.1), "chest": Vector3(0, 0.25, -0.111)}},
	"basaltoad": {"head": Vector3(0, 0.357, -0.224), "top": 0.464, "carry": Vector3(0, 0.517, 0.114),
		"ear_tip": Vector3(0.0698, 0.464, 0.103), "tail_tip": Vector3(0, 0.264, 0.34), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.172, 0.27, 0.0691), "right flank": Vector3(0.172, 0.27, 0.0691),
			"back": Vector3(0, 0.37, 0.182), "chest": Vector3(0, 0.25, -0.201)}},
	"nimbostrich": {"head": Vector3(0, 0.354, -0.124), "top": 0.496, "carry": Vector3(0, 0.566, 0.0561),
		"ear_tip": Vector3(0.0162, 0.496, 0.0508), "tail_tip": Vector3(0, 0.26, 0.163),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0298, 0.267, 0.0348), "right flank": Vector3(0.0298, 0.267, 0.0348),
			"back": Vector3(0, 0.372, 0.088), "chest": Vector3(0, 0.248, -0.111)}},
	"velvorm": {"head": Vector3(0, 0.354, -0.327), "top": 0.496, "carry": Vector3(0, 0.566, 0.141),
		"ear_tip": Vector3(0.0412, 0.496, 0.128), "tail_tip": Vector3(0, 0.26, 0.419), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.076, 0.267, 0.086), "right flank": Vector3(0.076, 0.267, 0.086),
			"back": Vector3(0, 0.372, 0.224), "chest": Vector3(0, 0.248, -0.294)}},
	"tuatrune": {"head": Vector3(0, 0.354, -0.206), "top": 0.496, "carry": Vector3(0, 0.566, 0.0898),
		"ear_tip": Vector3(0.0267, 0.496, 0.0811), "tail_tip": Vector3(0, 0.26, 0.265),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0492, 0.267, 0.0548), "right flank": Vector3(0.0492, 0.267, 0.0548),
			"back": Vector3(0, 0.372, 0.142), "chest": Vector3(0, 0.248, -0.185)}},
	"threadwyrm": {"head": Vector3(0, 0.357, -0.0958), "top": 0.464, "carry": Vector3(0, 0.517, 0.0491),
		"ear_tip": Vector3(0.0602, 0.464, 0.0443),
		"tail_tip": Vector3(0, 0.264, 0.146), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.149, 0.27, 0.0298), "right flank": Vector3(0.149, 0.27, 0.0298),
			"back": Vector3(0, 0.37, 0.0781), "chest": Vector3(0, 0.25, -0.0862)}},
	"squalltross": {"head": Vector3(0, 0.354, -0.1), "top": 0.496, "carry": Vector3(0, 0.566, 0.0435),
		"ear_tip": Vector3(0.0359, 0.496, 0.0393), "tail_tip": Vector3(0, 0.26, 0.129),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0662, 0.267, 0.0265), "right flank": Vector3(0.0662, 0.267, 0.0265),
			"back": Vector3(0, 0.372, 0.069), "chest": Vector3(0, 0.248, -0.0901)}},
	"spatewader": {"head": Vector3(0, 0.354, -0.204), "top": 0.496, "carry": Vector3(0, 0.566, 0.089),
		"ear_tip": Vector3(0.03, 0.496, 0.0803), "tail_tip": Vector3(0, 0.26, 0.263), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0554, 0.267, 0.0543), "right flank": Vector3(0.0554, 0.267, 0.0543),
			"back": Vector3(0, 0.372, 0.141), "chest": Vector3(0, 0.248, -0.183)}},
	"sentrikat": {"head": Vector3(0, 0.354, -0.0838), "top": 0.496, "carry": Vector3(0, 0.566, 0.0362),
		"ear_tip": Vector3(0.0322, 0.496, 0.0327), "tail_tip": Vector3(0, 0.26, 0.107),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0594, 0.267, 0.022), "right flank": Vector3(0.0594, 0.267, 0.022),
			"back": Vector3(0, 0.372, 0.0574), "chest": Vector3(0, 0.248, -0.0753)}},
	"scaldamus": {"head": Vector3(0, 0.354, -0.219), "top": 0.496, "carry": Vector3(0, 0.566, 0.096),
		"ear_tip": Vector3(0.0333, 0.496, 0.0867), "tail_tip": Vector3(0, 0.26, 0.283),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0615, 0.267, 0.0588), "right flank": Vector3(0.0615, 0.267, 0.0588),
			"back": Vector3(0, 0.372, 0.152), "chest": Vector3(0, 0.248, -0.196)}},
	"orchisloth": {"head": Vector3(0, 0.354, -0.0996), "top": 0.496, "carry": Vector3(0, 0.566, 0.0431),
		"ear_tip": Vector3(0.0244, 0.496, 0.0389), "tail_tip": Vector3(0, 0.26, 0.128),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0451, 0.267, 0.0263), "right flank": Vector3(0.0451, 0.267, 0.0263),
			"back": Vector3(0, 0.372, 0.0684), "chest": Vector3(0, 0.248, -0.0896)}},
	"opalisk": {"head": Vector3(0, 0.354, -0.189), "top": 0.496, "carry": Vector3(0, 0.566, 0.0819),
		"ear_tip": Vector3(0.0334, 0.496, 0.0739), "tail_tip": Vector3(0, 0.26, 0.242),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0617, 0.267, 0.0499), "right flank": Vector3(0.0617, 0.267, 0.0499),
			"back": Vector3(0, 0.372, 0.13), "chest": Vector3(0, 0.248, -0.17)}},
	"nacrolin": {"head": Vector3(0, 0.354, -0.0972), "top": 0.496, "carry": Vector3(0, 0.566, 0.0403),
		"ear_tip": Vector3(0.038, 0.496, 0.0362), "tail_tip": Vector3(0, 0.26, 0.122), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0701, 0.267, 0.024), "right flank": Vector3(0.0701, 0.267, 0.024),
			"back": Vector3(0, 0.372, 0.0646), "chest": Vector3(0, 0.248, -0.0875)}},
	"murmurling": {"head": Vector3(0, 0.354, -0.122), "top": 0.496, "carry": Vector3(0, 0.566, 0.0509),
		"ear_tip": Vector3(0.0196, 0.496, 0.0458), "tail_tip": Vector3(0, 0.26, 0.153),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0362, 0.267, 0.0305), "right flank": Vector3(0.0362, 0.267, 0.0305),
			"back": Vector3(0, 0.372, 0.0814), "chest": Vector3(0, 0.248, -0.11)}},
	"moundvark": {"head": Vector3(0, 0.354, -0.163), "top": 0.496, "carry": Vector3(0, 0.566, 0.0677),
		"ear_tip": Vector3(0.022, 0.496, 0.0609), "tail_tip": Vector3(0, 0.26, 0.205), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0406, 0.267, 0.0404), "right flank": Vector3(0.0406, 0.267, 0.0404),
			"back": Vector3(0, 0.372, 0.109), "chest": Vector3(0, 0.248, -0.147)}},
	"moonloris": {"head": Vector3(0, 0.354, -0.325), "top": 0.496, "carry": Vector3(0, 0.566, 0.141),
		"ear_tip": Vector3(0.0522, 0.496, 0.127), "tail_tip": Vector3(0, 0.26, 0.417), "tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0962, 0.267, 0.0858), "right flank": Vector3(0.0962, 0.267, 0.0858),
			"back": Vector3(0, 0.372, 0.223), "chest": Vector3(0, 0.248, -0.292)}},
	"limpetor": {"head": Vector3(0, 0.354, -0.177), "top": 0.496, "carry": Vector3(0, 0.566, 0.0753),
		"ear_tip": Vector3(0.0463, 0.496, 0.0679), "tail_tip": Vector3(0, 0.26, 0.225),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0853, 0.267, 0.0455), "right flank": Vector3(0.0853, 0.267, 0.0455),
			"back": Vector3(0, 0.372, 0.12), "chest": Vector3(0, 0.248, -0.159)}},
	"kilnbadger": {"head": Vector3(0, 0.354, -0.165), "top": 0.496, "carry": Vector3(0, 0.566, 0.0713),
		"ear_tip": Vector3(0.0236, 0.496, 0.0643), "tail_tip": Vector3(0, 0.26, 0.212),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0435, 0.267, 0.0433), "right flank": Vector3(0.0435, 0.267, 0.0433),
			"back": Vector3(0, 0.372, 0.113), "chest": Vector3(0, 0.248, -0.149)}},
	"heatherhorn": {"head": Vector3(0, 0.354, -0.179), "top": 0.496, "carry": Vector3(0, 0.566, 0.0782),
		"ear_tip": Vector3(0.0355, 0.496, 0.0706), "tail_tip": Vector3(0, 0.26, 0.231),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0654, 0.267, 0.0477), "right flank": Vector3(0.0654, 0.267, 0.0477),
			"back": Vector3(0, 0.372, 0.124), "chest": Vector3(0, 0.248, -0.161)}},
	"glaciyak": {"head": Vector3(0, 0.354, -0.2), "top": 0.496, "carry": Vector3(0, 0.566, 0.0867),
		"ear_tip": Vector3(0.0366, 0.496, 0.0782), "tail_tip": Vector3(0, 0.26, 0.257),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0674, 0.267, 0.0527), "right flank": Vector3(0.0674, 0.267, 0.0527),
			"back": Vector3(0, 0.372, 0.137), "chest": Vector3(0, 0.248, -0.18)}},
	"duskapi": {"head": Vector3(0, 0.354, -0.114), "top": 0.496, "carry": Vector3(0, 0.566, 0.049),
		"ear_tip": Vector3(0.0121, 0.496, 0.0442), "tail_tip": Vector3(0, 0.26, 0.146),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0224, 0.267, 0.0297), "right flank": Vector3(0.0224, 0.267, 0.0297),
			"back": Vector3(0, 0.372, 0.0778), "chest": Vector3(0, 0.248, -0.103)}},
	"casquebill": {"head": Vector3(0, 0.354, -0.155), "top": 0.496, "carry": Vector3(0, 0.566, 0.0666),
		"ear_tip": Vector3(0.0327, 0.496, 0.0601), "tail_tip": Vector3(0, 0.26, 0.198),
		"tip_bone": "hips", "hip": 0.184,
		"marks": {"left flank": Vector3(-0.0602, 0.267, 0.0404), "right flank": Vector3(0.0602, 0.267, 0.0404),
			"back": Vector3(0, 0.372, 0.106), "chest": Vector3(0, 0.248, -0.139)}},
	"cindle": {"head": Vector3(0, 0.427, -0.272), "top": 0.631, "carry": Vector3(0, 0.314, -0.272),
		"ear_tip": Vector3(0.105, 0.72, -0.0899),
		"tail_tip": Vector3(0, 0.66, 0.223), "tip_bone": "tail7", "hip": 0.253,
		"marks": {"left flank": Vector3(-0.0554, 0.276, 0.0305), "right flank": Vector3(0.0554, 0.276, 0.0305),
			"back": Vector3(0, 0.34, 0.0375), "chest": Vector3(0, 0.265, -0.149)}},
	"puddlet": {"head": Vector3(0, 0.209, -0.261), "top": 0.286, "carry": Vector3(0, 0.271, -0.0591),
		"ear_tip": Vector3(0.165, 0.343, -0.16), "tail_tip": Vector3(0, 0.23, 0.275), "tip_bone": "tail5", "hip": 0.127,
		"marks": {"left flank": Vector3(-0.0549, 0.158, -0.0591), "right flank": Vector3(0.0549, 0.158, -0.0591),
			"back": Vector3(0, 0.209, -0.0591), "chest": Vector3(0, 0.132, -0.164)}},
	"burrlet": {"head": Vector3(2.64e-17, 0.204, -0.141), "top": 0.276, "carry": Vector3(2.64e-17, 0.349, -0.0104),
		"ear_tip": Vector3(0.0725, 0.282, -0.0758),
		"tail_tip": Vector3(2.64e-17, 0.235, 0.162), "tip_bone": "tail2", "hip": 0.115,
		"marks": {"left flank": Vector3(-0.102, 0.162, 0.00685), "right flank": Vector3(0.102, 0.162, 0.00685),
			"back": Vector3(2.64e-17, 0.318, 0.00685), "chest": Vector3(2.64e-17, 0.141, -0.0964)}},
	"glintmole": {"head": Vector3(-2.64e-17, 0.248, -0.149), "top": 0.338, "carry": Vector3(-2.64e-17, 0.453, 0.039),
		"ear_tip": Vector3(0.0969, 0.314, -0.0599),
		"tail_tip": Vector3(-2.64e-17, 0.182, 0.227), "tip_bone": "tail2", "hip": 0.134,
		"marks": {"left flank": Vector3(-0.161, 0.2, 0.0637), "right flank": Vector3(0.161, 0.2, 0.0637),
			"back": Vector3(-2.64e-17, 0.308, 0.143), "chest": Vector3(-2.64e-17, 0.17, -0.0944)}},
	"rimeshrew": {"head": Vector3(0, 0.277, -0.222), "top": 0.378, "carry": Vector3(0, 0.429, -0.0152),
		"ear_tip": Vector3(0.0758, 0.378, -0.133),
		"tail_tip": Vector3(0, 0.317, 0.287), "tip_bone": "tail5", "hip": 0.162,
		"marks": {"left flank": Vector3(-0.1, 0.227, 0.00157), "right flank": Vector3(0.1, 0.227, 0.00157),
			"back": Vector3(0, 0.306, 0.0239), "chest": Vector3(0, 0.191, -0.133)}},
	"zephyrak": {"head": Vector3(0, 0.248, -0.0989), "top": 0.341, "carry": Vector3(0, 0.248, 0.00952),
		"ear_tip": Vector3(0.0786, 0.284, -0.0313), "tail_tip": Vector3(0, 0.159, 0.0824),
		"tip_bone": "tail6", "hip": 0.00954,
		"hover": true,
		"marks": {"left flank": Vector3(-0.0235, 0.114, 0.00811), "right flank": Vector3(0.0235, 0.114, 0.00811),
			"back": Vector3(0, 0.171, 0.00811), "chest": Vector3(0, 0.115, -0.0235)}},
	"pebbit": {"head": Vector3(0, 0.259, -0.305), "top": 0.404, "carry": Vector3(0, 0.417, 0.0363),
		"ear_tip": Vector3(0.0807, 0.359, -0.209),
		"tail_tip": Vector3(0, 0.107, 0.356), "tip_bone": "tail4", "hip": 0.166,
		"marks": {"left flank": Vector3(-0.158, 0.25, 0.0215), "right flank": Vector3(0.158, 0.25, 0.0215),
			"back": Vector3(0, 0.385, 0.0363), "chest": Vector3(0, 0.186, -0.157)}},
	"cairnback": {"head": Vector3(0, 0.415, -0.398), "top": 0.641, "carry": Vector3(0, 0.563, 0.306),
		"ear_tip": Vector3(0.301, 0.454, -0.239),
		"tail_tip": Vector3(0, 0.236, 0.471), "tip_bone": "tail2", "hip": 0.284,
		"marks": {"left flank": Vector3(-0.295, 0.38, 0.102), "right flank": Vector3(0.295, 0.38, 0.102),
			"back": Vector3(0, 0.546, 0.295), "chest": Vector3(0, 0.319, -0.182)}},
	"wisplet": {"head": Vector3(0, 0.273, -0.0785), "top": 0.378, "carry": Vector3(0, 0.399, -0.021), "hip": 0.115,
		"ear_tip": Vector3(0.0806, 0.391, -0.0257), "tail_tip": Vector3(0, 0.101, 0.0515), "tip_bone": "tail1",
		"marks": {"left flank": Vector3(-0.0712, 0.157, -0.0079), "right flank": Vector3(0.0712, 0.157, -0.0079),
			"back": Vector3(0, 0.199, 0.0313), "chest": Vector3(0, 0.173, -0.0602)}},
	"gloamshell": {"head": Vector3(0, 0.315, -0.233), "top": 0.453, "carry": Vector3(0, 0.432, 0.034),
		"ear_tip": Vector3(0.031, 0.432, -0.198), "tail_tip": Vector3(0, 0.168, 0.224),
		"tip_bone": "tail2", "hip": 0.147,
		"marks": {"left flank": Vector3(-0.0547, 0.193, -0.0551), "right flank": Vector3(0.0547, 0.193, -0.0551),
			"back": Vector3(0, 0.229, 0.129), "chest": Vector3(0, 0.249, -0.204)}},
	"selenfin": {"head": Vector3(0, 0.466, -0.295), "top": 0.609, "carry": Vector3(0, 0.68, -0.0306),
		"ear_tip": Vector3(0.181, 0.342, -0.0903),
		"tail_tip": Vector3(0, 0.466, 0.302), "tip_bone": "tail3", "hip": 0.0211,
		"hover": true,
		"marks": {"left flank": Vector3(-0.0856, 0.395, -0.0135), "right flank": Vector3(0.0856, 0.395, -0.0135),
			"back": Vector3(0, 0.529, -0.0306), "chest": Vector3(0, 0.315, -0.167)}},
	"zapple": {"head": Vector3(0, 0.432, -0.191), "top": 0.559, "carry": Vector3(0, 0.425, 0.0504),
		"ear_tip": Vector3(0.0882, 0.753, -0.0429),
		"tail_tip": Vector3(0, 0.324, 0.2), "tip_bone": "tail2", "hip": 0.261,
		"marks": {"left flank": Vector3(-0.108, 0.253, 0.0568), "right flank": Vector3(0.108, 0.253, 0.0568),
			"back": Vector3(0, 0.35, 0.0504), "chest": Vector3(0, 0.261, -0.0893)}},
	"hivara": {"head": Vector3(0, 0.272, -0.125), "top": 0.361, "carry": Vector3(0, 0.189, -0.112),
		"ear_tip": Vector3(0.057, 0.423, -0.112), "tail_tip": Vector3(0, 0.158, 0.123),
		"tip_bone": "tail2", "hip": 0.137,
		"marks": {"left flank": Vector3(-0.0516, 0.184, 0.039), "right flank": Vector3(0.0516, 0.184, 0.039),
			"back": Vector3(0, 0.252, 0.0424), "chest": Vector3(0, 0.174, -0.0582)}},
	"caecilith": {"head": Vector3(0, 0.328, -0.146), "top": 0.381, "carry": Vector3(0, 0.152, 0.0473),
		"ear_tip": Vector3(0.0413, 0.369, -0.0734), "tail_tip": Vector3(0, 0.067, 0.126),
		"tip_bone": "tail6", "hip": 0.0509,
		"coat": {"fres": 0.15, "rim_amount": 0.1, "top_light": 0.1, "sheen": 0.0},
		"marks": {"left flank": Vector3(-0.063, 0.185, -0.0712), "right flank": Vector3(0.063, 0.185, -0.0712),
			"back": Vector3(0, 0.212, -0.0186), "chest": Vector3(0, 0.185, -0.123)}},
	"goliathite": {"head": Vector3(0, 0.5, -0.33), "top": 0.668, "carry": Vector3(0, 0.795, 0.147),
		"ear_tip": Vector3(0.085, 0.668, 0.129), "tail_tip": Vector3(0, 0.191, 0.515), "tip_bone": "hips", "hip": 0,
		"marks": {"left flank": Vector3(-0.21, 0.207, 0.0736), "right flank": Vector3(0.21, 0.207, 0.0736),
			"back": Vector3(0, 0.445, 0.258), "chest": Vector3(0, 0.159, -0.368)}},
	"hoarheron": {"head": Vector3(0, 0.384, -0.44), "top": 0.62, "carry": Vector3(0, 0.739, 0.16),
		"ear_tip": Vector3(0.0722, 0.62, 0.14), "tail_tip": Vector3(0, 0.177, 0.56), "tip_bone": "hips", "hip": 0,
		"marks": {"left flank": Vector3(-0.178, 0.192, 0.08), "right flank": Vector3(0.178, 0.192, 0.08),
			"back": Vector3(0, 0.414, 0.28), "chest": Vector3(0, 0.148, -0.4)}},
	"floenatee": {"head": Vector3(0, 0.56, -0.42), "top": 0.7, "carry": Vector3(0, 0.72, -0.05),
		"ear_tip": Vector3(0.06, 0.7, -0.36), "tail_tip": Vector3(0, 0.08, 0.5), "tip_bone": "hips", "hip": 0,
		"marks": {"left flank": Vector3(-0.18, 0.25, 0.0), "right flank": Vector3(0.18, 0.25, 0.0),
			"back": Vector3(0, 0.46, 0.08), "chest": Vector3(0, 0.3, -0.44)}},
	"gibbelle": {"head": Vector3(0, 0.37, -0.15), "top": 0.52, "carry": Vector3(0, 0.6, 0.03),
		"ear_tip": Vector3(0.155, 0.365, -0.05), "tail_tip": Vector3(0, 0.1, 0.17), "tip_bone": "hips", "hip": 0.0,
		"marks": {"left flank": Vector3(-0.16, 0.15, 0.02), "right flank": Vector3(0.16, 0.15, 0.02),
			"back": Vector3(0, 0.25, 0.16), "chest": Vector3(0, 0.24, -0.12)}},
	"glomwort": {"head": Vector3(0, 0.35, -0.111), "top": 0.454, "carry": Vector3(0, 0.507, 0.0572),
		"ear_tip": Vector3(0.0326, 0.454, 0.0516),
		"tail_tip": Vector3(0, 0.258, 0.169), "tip_bone": "hips", "hip": 0.18,
		"marks": {"left flank": Vector3(-0.0805, 0.265, 0.0348), "right flank": Vector3(0.0805, 0.265, 0.0348),
			"back": Vector3(0, 0.363, 0.0907), "chest": Vector3(0, 0.245, -0.0993)}},
	"kestrike": {"head": Vector3(0, 0.423, -0.209), "top": 0.525, "carry": Vector3(0, 0.454, 0.0842), "hip": 0.146,
		"ear_tip": Vector3(0.0891, 0.509, 0.0565), "tail_tip": Vector3(0, 0.104, 0.225), "tip_bone": "tail2",
		"marks": {"left flank": Vector3(-0.0818, 0.178, -0.016), "right flank": Vector3(0.0818, 0.178, -0.016),
			"back": Vector3(0, 0.296, 0.0573), "chest": Vector3(0, 0.276, -0.156)}},
	"kindlewren": {"head": Vector3(0, 0.275, -0.205), "top": 0.391, "carry": Vector3(0, 0.414, -0.0703), "hip": 0.113,
		"ear_tip": Vector3(0.0121, 0.4, -0.0905), "tail_tip": Vector3(0, 0.327, 0.15), "tip_bone": "tail2",
		"marks": {"left flank": Vector3(-0.0737, 0.13, -0.0554), "right flank": Vector3(0.0737, 0.13, -0.0554),
			"back": Vector3(0, 0.235, 0.0342), "chest": Vector3(0, 0.171, -0.171)}},
	"lodestick": {"head": Vector3(0, 0.259, -0.155), "top": 0.331, "carry": Vector3(0, 0.247, 0.00695),
		"ear_tip": Vector3(0.0659, 0.414, -0.151), "tail_tip": Vector3(0, 0.214, 0.16),
		"tip_bone": "tail3", "hip": 0.157,
		"marks": {"left flank": Vector3(-0.0166, 0.163, 0.0154), "right flank": Vector3(0.0166, 0.163, 0.0154),
			"back": Vector3(0, 0.193, 0.0154), "chest": Vector3(0, 0.144, -0.0416)}},
	"marchleaf": {"head": Vector3(0, 0.186, -0.222), "top": 0.236, "carry": Vector3(0, 0.215, 0.00115),
		"ear_tip": Vector3(0.135, 0.294, -0.24), "tail_tip": Vector3(0, 0.161, 0.0662),
		"tip_bone": "tail1", "hip": 0.103,
		"marks": {"left flank": Vector3(-0.0855, 0.14, 0.00579), "right flank": Vector3(0.0855, 0.14, 0.00579),
			"back": Vector3(0, 0.186, 0.00115), "chest": Vector3(0, 0.119, -0.129)}},
	"mossgrade": {"head": Vector3(0, 0.239, -0.237), "top": 0.325, "carry": Vector3(0, 0.386, 0.0459),
		"ear_tip": Vector3(0.0936, 0.319, -0.133), "tail_tip": Vector3(0, 0.197, 0.232),
		"tip_bone": "hips", "hip": 0.123,
		"marks": {"left flank": Vector3(-0.154, 0.209, 0.0459), "right flank": Vector3(0.154, 0.209, 0.0459),
			"back": Vector3(0, 0.288, 0.172), "chest": Vector3(0, 0.154, -0.155)}},
	"nettlynx": {"head": Vector3(0, 0.24, -0.134), "top": 0.319, "carry": Vector3(0, 0.325, 0.0146),
		"ear_tip": Vector3(0.109, 0.411, -0.0629), "tail_tip": Vector3(0, 0.264, 0.124),
		"tip_bone": "tail3", "hip": 0.143,
		"marks": {"left flank": Vector3(-0.0869, 0.183, 0.0166), "right flank": Vector3(0.0869, 0.183, 0.0166),
			"back": Vector3(0, 0.251, 0.0347), "chest": Vector3(0, 0.171, -0.0738)}},
	"thrumbird": {"head": Vector3(0, 0.557, -0.0858), "top": 0.631, "carry": Vector3(0, 0.192, -0.019),
		"ear_tip": Vector3(0.0119, 0.411, 0.0451), "tail_tip": Vector3(0, 0.126, 0.0954),
		"tip_bone": "tail1", "hip": 0.118,
		"hover": true,
		"marks": {"left flank": Vector3(-0.0367, 0.167, 0.0125), "right flank": Vector3(0.0367, 0.167, 0.0125),
			"back": Vector3(0, 0.228, 0.0125), "chest": Vector3(0, 0.204, -0.0622)}},
	"lilybara": {"head": Vector3(0, 0.40, -0.34), "top": 0.6, "carry": Vector3(0, 0.5, 0.14),
		"ear_tip": Vector3(0.11, 0.56, -0.23), "tail_tip": Vector3(0, 0.295, 0.5), "tip_bone": "tail2", "hip": 0.17,
		"marks": {"left flank": Vector3(-0.25, 0.27, 0.1), "right flank": Vector3(0.25, 0.27, 0.1),
			"back": Vector3(0, 0.46, 0.14), "chest": Vector3(0, 0.27, -0.22)}},
	"umbrathere": {"head": Vector3(0, 0.466, -0.157), "top": 0.76, "carry": Vector3(0, 0.28, -0.19), "hip": 0.18,
		"ear_tip": Vector3(0.057, 0.551, -0.157), "tail_tip": Vector3(0.124, 0.029, 0.304), "tip_bone": "tail3",
		"marks": {"left flank": Vector3(-0.16, 0.24, 0.0), "right flank": Vector3(0.16, 0.24, 0.0),
			"back": Vector3(0, 0.31, 0.15), "chest": Vector3(0, 0.29, -0.14)}},
}
## m/s a foot on the ground moves back at speed 1 and model scale 1: [walk, run]. Measured by --boki-anim-audit.
const STRIDE := {
	"cindle": [0.81, 1.48],
	"puddlet": [0.58, 1.15],
	"burrlet": [0.52, 1.00],
	"glintmole": [0.49, 1.04],
	"rimeshrew": [0.49, 1.15],
	"zephyrak": [1.50, 2.90],
	"pebbit": [0.50, 1.09],
	"cairnback": [0.30, 1.04],
	"wisplet": [0.63, 1.32],
	"gloamshell": [1.50, 2.90],
	"selenfin": [1.50, 2.90],
	"zapple": [0.86, 1.70],
	"hivara": [0.64, 1.44],
	"caecilith": [0.15, 0.38],
	"glomwort": [1.50, 2.90],
	"kestrike": [0.33, 0.70],
	"kindlewren": [0.89, 1.70],
	"lodestick": [0.46, 1.62],
	"marchleaf": [0.53, 2.05],
	"mossgrade": [0.34, 0.93],
	"nettlynx": [0.54, 1.03],
	"thrumbird": [1.50, 2.90],
}
## s into the attack clip at speed 1 where the bite or pincers connect, per species (its forms wear the same clip).
## The clip plays at CONTACT / Kin.STRIKE_WINDUP so the contact lands on the hit. Measured by --boki-anim-audit.
const CONTACT := {"cindle": 0.300, "puddlet": 0.333, "burrlet": 0.333}
const FADE := 0.14            # s between body clips
## s between idle, walk and run for a Boki whose gaits hold it at a different stance: the hoverer tips into flight
## and back over a few wingbeats instead of snapping (the idle-to-walk pop, --boki-anim-audit).
const GAIT_FADE := {"thrumbird": 0.45}
const GAITS := ["idle", "walk", "run"]
const FACE_RATE := 14.0       # 1/s the expression eases at
const FACE_SNAP := 0.002      # blend weight: this close to its goal, a face shape stops easing (and being written)
const LOOK_SNAP := 0.0005     # eye UV offset: this close, the eyes stop drifting and their uniform stops being set
const WALK_SPEED := 0.5       # m/s: below this it stands
const RUN_SPEED := 2.2        # m/s: from here it gallops (a walk clip sped up past MAX_CADENCE blurs)
const MAX_CADENCE := 6.0      # step cycles/s a gait may be sped up to: small animals gallop at 6-8, past it blurs
const INK_WIDTH := 0.0011     # the outline per metre of camera distance
const INK_FAR_THIN := 0.5
## Softer than the Hunters' painted look (WardenGlb.PAINTED): fur, not armour, and no wash-out at the match zoom.
const COAT_LOOK := {"far_lift": 0.12, "fres": 0.55, "top_light": 0.45, "rim_amount": 0.25}
const EYE_VALUE := 0.86       # iris brightness: the eye is the first thing read on a small face
## Godot's LODs are cut from the rest pose, where the lids lie folded: they would drop the rows that cover the eye.
const FACE_LOD_BIAS := 1000.0
## The ground shadow of a Boki that hovers or has flown: its size (m, across and along it) and darkness, and how
## far off the ground it lies (m) so it never fights the ground for depth.
const SHADOW_SIZE := Vector2(0.5, 0.86)
const SHADOW_ALPHA := 0.42
const SHADOW_LIFT := 0.012
const EAR_TWITCH := 0.3       # rad an ear flicks asleep
## Share of its height under the water when it floats: water deeper than that at its feet lifts it off the bed and it
## swims (a Water type) or paddles (the rest). One that hovers stays over the water as over the ground.
const SWIM_LINE := 0.5
const PLANT_GAITS := ["walk", "run"]      # the clips whose paws BokiPlant keeps planted
const OWN_BODY := ["chop", "mine", "carry", "tend", "settle", "nap", "wake", "munch", "nudge", "climb", "splash",
	"swim", "paddle", "rush", "brace", "dodge", "stonehop", "spin", "strut", "pose", "bow", "hover", "glide", "flare"]
## Clips that carry the body themselves: home's walking bounce of Body is taken back out under them.
const OWN_HEIGHT := ["hop", "hover", "glide", "flare"]
const LAND_SQUASH := 0.16     # how far a hard landing flattens it (share of its height; widens by 0.6 of that)
## The nap clips (BokiHomeClips), played slower by a bigger Boki (KinNap.slow).
const NAP_CLIPS := ["settle", "nap", "wake"]
const LOOPED := ["idle", "walk", "run", "hop", "sleep", "eat", "pet", "chop", "mine", "carry", "tend"]
## The strut takes steps this much quicker than a walk at the same ground speed (a high, proud step).
const STRUT_CADENCE := 1.25
## Home's job kinds that have their own clip.
const WORK_KINDS := {"chop": "chop", "ore": "mine", "carry": "carry"}
## Blend shapes each expression pushes.
const FACES := {
	"neutral": {},
	"happy": {"happy": 1.0, "m_smile": 1.0},
	"sad": {"sad": 1.0, "m_frown": 1.0},
	"sleepy": {"sleepy": 1.0, "m_o": 0.3},
	"angry": {"angry": 1.0, "m_snarl": 1.0},
	"focus": {"angry": 0.45},
	"cheer": {"m_smile": 0.8},
	"bliss": {"closed": 1.0, "m_smile": 0.55},
	"asleep": {"closed": 1.0, "m_o": 0.22},
	"chew": {"m_chomp": 1.0},
}
## The clip's own expression, or a list of [from, expression] beats over its length (0..1).
const CLIP_FACE := {
	"run": "cheer", "hop": "happy", "attack": "angry", "ability": "angry", "sleep": "asleep", "pet": "bliss",
	"chop": "focus", "mine": "focus", "carry": "cheer", "tend": "focus",
	"eat": [[0.0, "chew"], [0.16, "cheer"], [0.33, "chew"], [0.5, "cheer"], [0.66, "chew"], [0.83, "cheer"]],
	"settle": [[0.0, "sleepy"], [0.6, "asleep"]], "nap": "asleep",
	"wake": [[0.0, "asleep"], [0.2, "sleepy"], [0.7, "cheer"]],
	"munch": "chew", "nudge": "cheer", "climb": "focus", "splash": "happy", "swim": "cheer", "paddle": "focus",
	"rush": "angry", "brace": "focus", "dodge": "cheer", "stonehop": "happy", "spin": "happy",
	"strut": "cheer", "pose": "cheer", "bow": "cheer",
	"crouch": "focus", "burst": "cheer", "sulk": "sad",
	"glide": "cheer", "flare": "focus",
}
## Match body language (KinPuppet's "pose" meta) that shows on the face.
const POSE_FACE := {"growl": "angry", "guard": "focus", "whine": "sad", "nudge": "sad", "comfort": "happy",
	"alert": "focus", "dazed": "sleepy", "scan": "sad"}
## Pose layers: lean (rad, forward), squat (0..1 of its height, negative stands tall), sway (rad, side to side),
## shiver (rad); `clip` and `rate` replace the idle, walk and run clips and their speed (a lifted Boki kicks).
const LAYER := {
	"alert": {"lean": -0.2, "squat": -0.1},
	"growl": {"lean": 0.2, "squat": 0.1, "shiver": 0.03},
	"whine": {"lean": 0.14, "squat": 0.16, "shiver": 0.03},
	"dazed": {"lean": 0.3, "squat": 0.12, "sway": 0.2, "clip": "idle", "rate": 0.4},
	"scan": {"lean": -0.15, "squat": -0.2, "shiver": 0.03, "clip": "run", "rate": 0.7},
}
## How far each body plan (KinPuppet.BODY) takes the lean and the sway: a flyer or serpent has no spine to tip.
const BODY_FEEL := {"quad": Vector2(1.0, 1.0), "biped": Vector2(1.0, 1.0), "flyer": Vector2(0.6, 1.4),
	"serpent": Vector2(0.5, 1.6), "blob": Vector2(0.5, 1.0)}
const CHASE_POSES := ["growl", "whine"]   # moving at all in these is a run: a charge or a bolt
const LAYER_RATE := 9.0       # 1/s the layer eases in and out at
const SWAY_RATE := 4.0        # rad/s of the knocked-out sway
const SHIVER_RATE := 45.0     # rad/s

static var enabled := true
## How deep a body's baked normal map cuts (a Meshy body has one, docs/art/kin/MESHY_BOKI_RECIPE.md); 0 leaves it out.
static var normal_k := 1.0

var species := ""
var manual := false            # tools pose it by hand: set_clip, seek and set_face, nothing automatic
var root: Node3D
var flex: Node3D
var model: Node3D
var player: AnimationPlayer
var _skel: Skeleton3D
var pace: RigPace              # how often the seen rig (clip, skeleton, face) steps
var face: MeshInstance3D
var eye_mat: ShaderMaterial
var clip := ""
var _shapes := {}              # blend shape name -> index
var _now := {}                 # blend shape name -> weight
var _want := {}
var _face_name := "neutral"
var _flex_y := 0.0
var _pos_prev := Vector3.INF      # (INF: not measured yet)
var _tp := 0                  # the Kin's last teleport count seen (Kin.teleport)
var _speed := 0.0
var _land := LandLean.new()    # the landing squash and the run-start/stop lean laid over the clips
var _pulse := 0
var _shot_left := 0.0
var _shot := ""
var _shot_rate := 1.0          # the speed the shot plays at
var _attacking := false
var _asleep := false
var _aloft := false             # a flier in the air (BokiFly's "aloft" meta)
var _layer := {"lean": 0.0, "squat": 0.0, "sway": 0.0, "shiver": 0.0}
var _layer_t := 0.0
var _feel := Vector2.ONE
var _blink_t := 2.0
var _blink := 0.0
var _look_t := 1.0
var _look := Vector2.ZERO
var _look_to := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _idle := BokiIdle.new()    # its breathing loop's fidgets, see BokiIdle
var _coat: ShaderMaterial
var _shadow: MeshInstance3D
var _flinch := KinFlinch.new()
var _water := 0.0              # m of water over its feet this frame (the root's "kwater", taken each frame)
var _swimmer := false          # a Water type: swims level rather than paddling
var _nap: KinNap
var _ears := PackedInt32Array()     # ear bones the sleep clip keys, twitched on top of it asleep
var _plants := {}              # gait clip -> BokiPlant
var _gait := ""                # the gait whose paws are planted: it eases out after the clip moves on
var _gait_at := 0.0            # s into it
var _gait_rate := 1.0
var _gait_w := 0.0             # how far the planted timing is blended in
static var _shadow_mat: StandardMaterial3D

## True when this species has a rigged model.
static func has(kin_id: String) -> bool:
	return enabled and FRAME.has(kin_id) and ResourceLoader.exists(PATH % [kin_id, kin_id])

## A Water type (wade.json "swim", by its species' theme): it swims level in deep water instead of paddling.
static func swimmer(kin_id: String) -> bool:
	return (BokiWade.rules()["swim"] as Array).has(BokiLines.element_of(kin_id))

## Starts reading every common species' model on a loader thread (a match's start: bots' and wild Boki), so the
## builds take them ready instead of each species' first build reading its .glb on the main thread (~60 ms).
static func fetch_common() -> void:
	if not BackgroundWork.can_read_ahead():
		return
	for sp in Data.common_kin():
		var p := PATH % [sp, sp]
		if has(String(sp)) and not _scenes.has(p) \
				and ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			BackgroundWork.request(p)

static var _ear_bones := {}    # species -> its ear bones keyed in the sleep clip
static var _scenes := {}       # path -> PackedScene, kept so a species' next build doesn't read it again
static func _scene(kin_id: String) -> PackedScene:
	var p := PATH % [kin_id, kin_id]
	if not _scenes.has(p):
		var asked := ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		_scenes[p] = BackgroundWork.take(p) if asked else load(p)
	return _scenes[p] as PackedScene

## The work clip for a farm Boki (home's kin dictionary, its "job"), or "" when it isn't doing one.
static func work_clip(k: Dictionary) -> String:
	if not k.has("job"):
		return ""
	var job: Dictionary = k["job"]
	if String(job["phase"]) == "to":
		return "carry"
	if String(job["phase"]) != "work":
		return ""
	return String(WORK_KINDS.get(String(job["kind"]), "tend"))

## Adds the model and its driver under `flex`; `c` is KinModels' material set. Returns the head frame, as
## KinModels.build.
static func build(kin_id: String, flex_node: Node3D, c: Dictionary, mats: Array) -> Dictionary:
	var model_root := _scene(kin_id).instantiate() as Node3D
	model_root.name = "Rig"
	flex_node.add_child(model_root)
	var rig := BokiRig.new()
	rig.name = "BokiRig"
	rig.species = kin_id
	rig._feel = BODY_FEEL[KinPuppet.BODY.get(kin_id, "blob")]
	rig.model = model_root
	rig._dress(c, mats)
	if FRAME[kin_id].get("hover", false):
		rig._shadow = _ground_shadow(flex_node)
	flex_node.add_child(rig)
	return FRAME[kin_id]

func _ready() -> void:
	process_priority = 10          # after KinPuppet: this rig poses Flex itself
	flex = get_parent() as Node3D
	root = flex.get_parent().get_parent() as Node3D
	_flex_y = flex.position.y
	_rng.seed = hash(get_instance_id())
	_blink_t = _rng.randf_range(0.8, 3.5)
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_skel = skeleton()
	# BokiDna's modifier would otherwise re-pose (and re-skin) the rig every frame, stepped or not
	_skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	pace = RigPace.new(get_instance_id())
	BokiHomeClips.install(species, player, _skel)
	for n in LOOPED:
		player.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_flinch.plan = String(KinPuppet.BODY.get(species, "blob"))
	_nap = KinNap.new(species)
	if not _ear_bones.has(species):
		_ear_bones[species] = _keyed_ears()
	_ears = _ear_bones[species]
	_swimmer = swimmer(species)
	_copy_coat()
	_skel = skeleton()
	for g in PLANT_GAITS:
		_plants[g] = BokiPlant.of(species, model, _skel, g)
	BokiIdle.build(player, skeleton(), species)
	_idle.rest(_rng)
	set_clip("idle")

## Moves the rig on by `dt`: the clip, then the skeleton's modifiers (BokiDna) over it. The only way it moves.
func advance(dt: float) -> void:
	player.advance(dt)
	_twitch_ears()         # (over the clip's pose, before the skeleton takes it)
	_plant_feet(dt)
	_skel.advance(dt)

## The model's skeleton.
func skeleton() -> Skeleton3D:
	return model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

## The expression right now: one of FACES.
func set_face(which: String) -> void:
	_face_name = which
	_want = FACES.get(which, {})

## Plays a body clip by name, crossfading from the last one.
func set_clip(which: String, fade := FADE) -> void:
	if which == clip:
		return
	clip = which
	player.play(which, fade)

## Tools: holds the body at `at` (s) of the current clip and the face fully on its expression.
func seek(at: float) -> void:
	player.seek(at, true)
	_skel.advance(0.0)
	for s in _shapes:
		_now[s] = float(_want.get(s, 0.0))
		face.set_blend_shape_value(int(_shapes[s]), float(_now[s]))

func _process(dt: float) -> void:
	if dt <= 0.0:
		return
	if manual:
		advance(dt)
		return
	if not root.is_visible_in_tree():
		return
	_flinch.update(root, dt)
	_water = float(root.get_meta("kwater", 0.0))
	if _water > 0.0:
		root.remove_meta("kwater")        # set again by whatever moves it through water next frame
	_keep_flex(dt)
	_track_speed(dt)
	_pick_clip(dt)
	var t := pace.step(dt)
	if t > 0.0:
		_face_step(t)
		advance(t)

## KinPuppet squashes and leans Flex for primitive bodies; here the clips do that, so only its width roll, the jolt
## of a hit (KinFlinch) and a landing's squash with a lean as it starts and stops (LandLean) stay.
func _keep_flex(dt: float) -> void:
	var girth := float(root.get_meta("girth", 1.0))
	_land.step(dt, root.global_position)
	var sq := _land.squash * LAND_SQUASH
	var squat: float = _layer["squat"]
	var swing := _layer_t * SWAY_RATE
	var sway := float(_layer["sway"])
	flex.rotation = _flinch.rot + Vector3(-float(_layer["lean"]) - _land.lean + cos(swing) * sway * 0.4, 0.0,
		sin(swing) * sway + sin(_layer_t * SHIVER_RATE) * float(_layer["shiver"]))
	var wide := _flinch.wide * (1.0 + squat * 0.5)
	flex.scale = Vector3(girth * wide, _flinch.tall * (1.0 - squat), lerpf(1.0, girth, 0.5) * wide) \
		* Vector3(1.0 + sq * 0.6, 1.0 - sq, 1.0 + sq * 0.6)
	flex.position = Vector3(0, _flex_y, 0) + _flinch.shove
	var body := flex.get_parent() as Node3D
	if clip in OWN_BODY:
		body.rotation = Vector3.ZERO          # home's work poses swing Body: here the clip does the swinging
	if clip == "carry":
		var held := root.get_node_or_null("Held") as Node3D
		if held:
			held.position = FRAME[species]["carry"]
	var lift := float(root.get_meta("lift", 0.0))
	if lift > 0.0 and _shadow == null:
		_shadow = _ground_shadow(flex)           # a flier's first time up: from now on its shadow marks the ground
	var afloat := _float_lift()
	model.position.y = 0.0
	if clip in OWN_HEIGHT or afloat > 0.0:
		# the clip hops or floats, not home
		model.position.y = afloat / flex.global_basis.y.length() - body.position.y
	if _shadow:
		_shadow.global_position.y = root.global_position.y - lift + _water + SHADOW_LIFT
	var cam := get_viewport().get_camera_3d() as CamRig
	if cam:
		model.global_basis = cam.char_lean() * flex.global_basis      # toward the camera, like the Hunters: faces read

func _track_speed(dt: float) -> void:
	var gp := root.global_position
	var tp := int(root.get_meta("tp", 0))
	if _pos_prev == Vector3.INF or tp != _tp:
		_tp = tp          # put somewhere (burst, re-bloom, blink, swap): not a run, so the speed stays as it was
		_pos_prev = gp
		return
	var v := Vector2(gp.x - _pos_prev.x, gp.z - _pos_prev.z).length() / dt      # rising or sinking is no stride
	_pos_prev = gp
	_speed = lerpf(_speed, v, 1.0 - exp(-10.0 * dt))

func _pick_clip(dt: float) -> void:
	var p: int = root.get_meta("pulse", 0)
	if p != _pulse:
		_pulse = p
		_start_shot("ability")
	var attacking := String(root.get_meta("kstate", "")) == "attack"
	if attacking and not _attacking:
		_start_shot("attack", float(CONTACT.get(species, Kin.STRIKE_WINDUP)) / Kin.STRIKE_WINDUP)
	_attacking = attacking
	_shot_left -= dt
	var asleep := _lying()
	_nap.update(root, asleep, dt)       # its settle, nap and wake run slower for a bigger Boki
	if asleep != _asleep:
		_asleep = asleep
		if _speed < WALK_SPEED:
			_start_shot("settle" if asleep else "wake")
	var aloft := bool(root.get_meta("aloft", false))
	if aloft != _aloft:
		_aloft = aloft
		if not aloft:
			_start_shot("flare")
		elif _shot == "flare":
			_shot_left = 0.0          # up again before the flare is done
	var feel: Dictionary = LAYER.get(String(root.get_meta("pose", "")), {})
	_step_layer(feel, dt)
	var want := _state_clip()
	if want in GAITS and feel.has("clip"):
		want = feel["clip"]
	if want == "idle":
		want = _idle.step(dt, player, clip, _rng)       # a fidget now and then, never over an action
	else:
		_idle.rest(_rng)
	set_clip(want, gait_fade() if want in GAITS and clip in GAITS else FADE)
	player.speed_scale = _shot_rate if want == _shot and _shot_left > 0.0 else 1.0
	if want in NAP_CLIPS:
		player.speed_scale /= _nap.slow
	if feel.has("rate"):
		player.speed_scale = float(feel["rate"])
		return
	if want not in ["run", "walk", "carry", "strut"]:
		return
	# the world scale: a size roll's bigger Boki takes longer steps
	var stride: float = ((STRIDE.get(species, [1.5, 2.9]) as Array)[1 if want == "run" else 0]
			* model.global_basis.z.length())
	var quick := STRUT_CADENCE if want == "strut" else 1.0
	var burst := float(root.get_meta("kburst", 1.0))      # the Relay Cup's launch: the legs go faster for a moment
	player.speed_scale = clampf(quick * _speed / stride * burst, 0.6, MAX_CADENCE * player.get_animation(want).length)

## s the rig takes to hand one gait over to another.
func gait_fade() -> float:
	return GAIT_FADE.get(species, FADE)

## Plants the walk's or run's paws (BokiPlant), easing in after the clip starts and out after it ends.
func _plant_feet(dt: float) -> void:
	if clip == _gait:
		_gait_at = player.current_animation_position
		_gait_rate = player.speed_scale
		_gait_w = move_toward(_gait_w, 1.0, dt / FADE)
	else:
		_gait_at += dt * _gait_rate
		_gait_w = move_toward(_gait_w, 0.0, dt / FADE)
		if _gait_w == 0.0:
			_gait = clip if clip in PLANT_GAITS else ""
	if _gait_w > 0.0:
		plant(_gait, _gait_at, _gait_rate, _gait_w)

## Poses `gait`'s legs at `at` s into it, playing at `rate` x, with the paws planted at this Boki's speed and size.
func plant(gait: String, at: float, rate: float, weight := 1.0) -> void:
	(_plants[gait] as BokiPlant).pose(_skel, at, rate, _speed, model.global_basis.z.length(), weight)

## Eases the pose layer toward what the pose asks (zero for none); lean and sway scale with the body plan.
func _step_layer(feel: Dictionary, dt: float) -> void:
	_layer_t += dt
	for key in _layer:
		var mult := 1.0
		if key == "lean":
			mult = _feel.x
		elif key == "sway":
			mult = _feel.y
		var want := float(feel.get(key, 0.0)) * mult
		_layer[key] = lerpf(float(_layer[key]), want, 1.0 - exp(-LAYER_RATE * dt))

## Plays a one-off clip, at `rate` times its speed.
func _start_shot(which: String, rate := 1.0) -> void:
	_shot = which
	_shot_rate = rate
	_shot_left = player.get_animation(which).length / rate * (_nap.slow if which in NAP_CLIPS else 1.0)

## The root ear bones the nap clip keys (ear, ear1.L, not ear2.L down the same ear nor an ear_glow): the clip
## sets them every frame, so a twitch on top never builds up.
func _keyed_ears() -> PackedInt32Array:
	var out := PackedInt32Array()
	var anim := player.get_animation("nap")
	for i in anim.get_track_count():
		var bone := _skel.find_bone(String(anim.track_get_path(i).get_concatenated_subnames()))
		if bone >= 0 and anim.track_get_type(i) == Animation.TYPE_ROTATION_3D and _is_ear(bone) \
				and not _is_ear(_skel.get_bone_parent(bone)):
			out.append(bone)
	return out

func _is_ear(bone: int) -> bool:
	var bone_name := _skel.get_bone_name(bone) if bone >= 0 else ""
	return bone_name.begins_with("ear") and not bone_name.begins_with("ear_")

## Asleep, an ear flicks now and then (KinNap.twitch), on top of the nap clip's pose.
func _twitch_ears() -> void:
	if _nap.twitch <= 0.0 or clip != "nap":
		return
	var turn := Quaternion(Vector3.BACK, sin(_nap.twitch * TAU) * EAR_TWITCH)
	for b in _ears:
		_skel.set_bone_pose_rotation(b, _skel.get_bone_pose_rotation(b) * turn)

## Asleep at home (kstate) or fainted in a match (kdown): no clip of its own, so it settles down, naps and wakes.
func _lying() -> bool:
	return String(root.get_meta("kstate", "")) == "sleep" or bool(root.get_meta("kdown", false))

func _state_clip() -> String:
	if _aloft:
		return "glide" if _speed >= WALK_SPEED else "hover"
	if _shot == "flare" and _shot_left > 0.0:
		return _shot          # it touches down before it does what it came down for
	var swim := _swim_clip()
	if swim != "":
		return swim
	if _lying():
		return _shot if _shot == "settle" and _shot_left > 0.0 else "nap"
	var work := String(root.get_meta("kwork", ""))
	if work != "":
		return work
	var act := String(root.get_meta("kact", ""))
	if act == "hop" and not player.has_animation("hop"):
		return "run"          # a Boki in the air (Kin.render) without a hop clip runs through it
	if act != "":
		return act
	if _shot_left > 0.0:
		return _shot
	if root.get_meta("happy", false):
		return "hop"
	if _speed >= RUN_SPEED or (_speed >= WALK_SPEED and String(root.get_meta("pose", "")) in CHASE_POSES):
		return "run"
	return "walk" if _speed >= WALK_SPEED else "idle"

## "swim" or "paddle" while the water is deeper than SWIM_LINE of its height, else "".
func _swim_clip() -> String:
	if _water <= _afloat() or FRAME[species].get("hover", false):
		return ""
	return "swim" if _swimmer else "paddle"

## m of it under the water when it floats: SWIM_LINE of its height (FRAME "top") at its size in the world.
func _afloat() -> float:
	return SWIM_LINE * float(FRAME[species]["top"]) * flex.global_basis.y.length()

## m the model rises off the bed: afloat in deep water, onto the surface for one that hovers.
func _float_lift() -> float:
	if FRAME[species].get("hover", false):
		return _water
	return maxf(0.0, _water - _afloat())

func _clip_face() -> String:
	var over := String(root.get_meta("face", ""))
	if over != "":
		return over
	var pf := String(POSE_FACE.get(String(root.get_meta("pose", "")), ""))
	if pf != "":
		return pf
	if root.get_meta("dazed", false):
		return "sad"
	var cf: Variant = CLIP_FACE.get(clip, "")
	if cf is Array:
		var length := player.current_animation_length
		var k := fposmod(player.current_animation_position, length) / length
		var best := "neutral"
		for beat in cf:
			if float(beat[0]) <= k:
				best = String(beat[1])
		return best
	if String(cf) != "":
		return String(cf)
	return "neutral"

func _face_step(dt: float) -> void:
	set_face(_clip_face())
	_blink_t -= dt
	if _blink_t <= 0.0:
		_blink_t = _rng.randf_range(1.8, 4.6)
		_blink = 1.0
	_blink = maxf(0.0, _blink - dt * 7.0)
	var k := 1.0 - exp(-FACE_RATE * dt)
	var shut_already := _want.has("closed") or _want.has("happy")
	for s in _shapes:
		var goal := float(_want.get(s, 0.0))
		if s == "blink" and not shut_already:
			goal = sin(_blink * PI)
		var was := float(_now[s])
		var w := lerpf(was, goal, k if s != "blink" else 1.0)
		if absf(w - goal) < FACE_SNAP:
			w = goal
		if w != was:       # an unchanged weight isn't written: the face mesh is only re-deformed while it moves
			_now[s] = w
			face.set_blend_shape_value(int(_shapes[s]), w)
	_look_t -= dt
	if _look_t <= 0.0:
		_look_t = _rng.randf_range(1.2, 3.8)
		_look_to = Vector2(_rng.randf_range(-0.09, 0.09), _rng.randf_range(-0.05, 0.05))
	if _look != _look_to:
		_look = _look.lerp(_look_to, 1.0 - exp(-12.0 * dt))
		if _look.distance_to(_look_to) < LOOK_SNAP:
			_look = _look_to
		eye_mat.set_shader_parameter("look", _look)

## Wears the game's materials: the painted atlas under the Boki toon light, the glow and the eye in its own colours.
func _dress(c: Dictionary, mats: Array) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if inst.get_blend_shape_count() > 0 or inst.mesh.get_blend_shape_count() > 0:
			face = inst
			inst.lod_bias = FACE_LOD_BIAS
			for i in inst.mesh.get_blend_shape_count():
				var nm := String(inst.mesh.get_blend_shape_name(i))
				_shapes[nm] = i
				_now[nm] = 0.0
		for si in inst.mesh.get_surface_count():
			inst.set_surface_override_material(si, _material_for(inst.mesh.surface_get_material(si), c, mats))

func _material_for(src: Material, c: Dictionary, mats: Array) -> Material:
	var id := String(src.resource_name)
	if id == "boki_glow":
		return c["glow"]
	if id == "boki_eye":
		eye_mat = ShaderMaterial.new()
		eye_mat.shader = preload("res://shaders/boki_eye.gdshader")
		var iris := c["eye"].get_meta("iris", Color("9de23a")) as Color
		eye_mat.set_shader_parameter("iris", Color.from_hsv(iris.h, minf(iris.s * 1.15, 1.0), EYE_VALUE))
		return eye_mat
	if id == "boki_lit":
		return _lit_material(src, c)
	var m := Models.toon(Color.WHITE, false)
	Models.hero_look(m)
	m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("albedo_tex", (src as BaseMaterial3D).albedo_texture)
	for k in WardenGlb.PAINTED:
		m.set_shader_parameter(k, WardenGlb.PAINTED[k])
	var look: Dictionary = COAT_LOOK.merged(FRAME[species].get("coat", {}), true)
	for k in look:
		m.set_shader_parameter(k, look[k])
	m.set_shader_parameter("rim_color", (c["body"] as ShaderMaterial).get_shader_parameter("rim_color"))
	var relief := (src as BaseMaterial3D).normal_texture
	if relief and normal_k > 0.0:
		m.set_shader_parameter("normal_tex", relief)
		m.set_shader_parameter("use_nrm", true)
		m.set_shader_parameter("normal_k", normal_k)
	if id == "boki_coat":
		_coat = m
		m.next_pass = _ink()
	mats.append(m)
	return m

## A painted part that glows: its own colours, shifted with the species' glow (a shimmer's caps).
func _lit_material(src: Material, c: Dictionary) -> Material:
	var m := Models.toon(Color.WHITE, false, 0.55)
	m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("albedo_tex", (src as BaseMaterial3D).albedo_texture)
	var base: Color = Data.KIN[species]["glow"]
	var now := (c["glow"] as ShaderMaterial).get_shader_parameter("albedo") as Color
	m.set_shader_parameter("albedo", _tint(now, base))
	return m

## A soft dark oval on the ground under `flex`: what keeps a floating body reading as standing there.
static func _ground_shadow(flex_node: Node3D) -> MeshInstance3D:
	if _shadow_mat == null:
		var grad := GradientTexture2D.new()
		grad.fill = GradientTexture2D.FILL_RADIAL
		grad.fill_from = Vector2(0.5, 0.5)
		grad.fill_to = Vector2(1.0, 0.5)
		grad.gradient = Gradient.new()
		grad.gradient.set_color(0, Color(0, 0, 0, 1))
		grad.gradient.set_color(1, Color(0, 0, 0, 0))
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.albedo_texture = grad
		_shadow_mat.albedo_color = Color(0, 0, 0, SHADOW_ALPHA)
	var plane := PlaneMesh.new()
	plane.size = SHADOW_SIZE
	var shadow := Models.part(flex_node, plane, _shadow_mat, Vector3(0, SHADOW_LIFT, 0), Vector3.ONE, Vector3.ZERO,
		"GroundShadow")
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shadow

static func _ink() -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = Models.OUTLINE
	ink.set_shader_parameter("width", INK_WIDTH)
	ink.set_shader_parameter("far_thin", INK_FAR_THIN)
	return ink

## Coat marks and the colour shift land on KinModels' body material (Unique.dress, after build): take them on.
func _copy_coat() -> void:
	var mats: Array = root.get_meta("mats", [])
	if mats.is_empty() or _coat == null:
		return
	var body := mats[0] as ShaderMaterial
	var base: Color = Data.KIN[species]["color"]
	var now := body.get_shader_parameter("albedo") as Color
	_coat.set_shader_parameter("albedo", _tint(now, base))
	if body.get_shader_parameter("mark_kind") == null:
		return
	var marks := ShaderMaterial.new()
	marks.shader = preload("res://shaders/boki_marks.gdshader")
	for k in ["mark_kind", "mark_color", "mark_seed", "mark_scale", "mark_amt", "mark_glow"]:
		marks.set_shader_parameter(k, body.get_shader_parameter(k))
	marks.next_pass = _coat.next_pass
	_coat.next_pass = marks

## How far a colour has moved from the species' own (white: not at all), to multiply a painted atlas with.
static func _tint(now: Color, base: Color) -> Color:
	return Color(now.r / maxf(base.r, 0.01), now.g / maxf(base.g, 0.01), now.b / maxf(base.b, 0.01))
