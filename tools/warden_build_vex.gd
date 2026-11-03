extends RefCounted
## Vex's interim mesh (tools/warden_build.gd): where her parts sit on her turnaround sheet
## (docs/art/gen/wardens/venatrix_turnaround.png, 3168x1344: front, side, back on one ground line).
## Pixel rows and columns are the sheet's. The sheet draws the mechanical arm and the slate shoulder plate
## on her right; her Warden block (docs/art/gen/index.md) and the splash put them on her LEFT, so the body
## is taken mirrored (MIRROR_BODY) while the head keeps the mechanical eye on her right as drawn.

const ARCH := "gunslinger"
const ART := "vex"
const SHEET := "res://docs/art/gen/wardens/venatrix_turnaround.png"
const MIRROR_BODY := true
## Each view's centre column (the body's axis) on the sheet.
const CX := {"front": 432, "side": 1655, "back": 2810}
## Sheet row -> rig landmark (tools/warden_build.gd _landmarks): soles, knees, hip joints, shoulders, neck, crown.
## (No shoulder row: the rig's neck stands well above its arm pivots, so hips to neck map evenly. The crown
## row sits in the beret, so beret and all she stands at the sheet height.)
const ROWS := [[1290, "sole"], [965, "knee"], [705, "hip"], [245, "neck"], [88, "crown"]]
const BERET_TOP := 75
## Atlas crops {view: [x, y, w, h]}: the whole figure scaled to the atlas width, the head at full size below.
const BODY_CROPS := {"front": [120, 60, 600, 1240], "side": [1480, 60, 320, 1240], "back": [2470, 60, 660, 1240]}
const HEAD_CROPS := {"front": [345, 60, 175, 212], "side": [1560, 60, 210, 212], "back": [2715, 60, 185, 212]}

## The parts. rows: sheet rows top to bottom; half: the most a front (or side) half-width may take in px,
## by row; k: width in metres per pixel as a multiple of the part's height scale (a hero's chunkier build).
const TORSO := {"rows": [258, 712], "half": [[258, 70], [300, 118], [420, 112], [560, 92], [712, 98]],
	"side_half": 112, "k": 1.45}
const HEAD := {"rows": [BERET_TOP - 4, 262], "half": [[70, 82], [262, 60]], "side_half": 92, "k": 1.0}
## Legs from the hip down: the sheet's left leg is her right (mirrored: the model's left).
const LEGS := {"rows": [700, 1292], "half": [[700, 62], [1200, 58], [1292, 72]], "side_half": 70,
	"toe_half": 125, "toe_row": 1225, "k": 1.4, "x_front": {"L": 350, "R": 515}}
## Arms on the front view: shoulder, elbow, wrist, fingertips (x, y). The sheet's left arm is the
## mechanical one (her right as drawn; mirrored: the model's left).
const ARMS := {
	"L": {"pts": [Vector2(305, 312), Vector2(245, 520), Vector2(212, 700), Vector2(195, 790)], "half": 62},
	"R": {"pts": [Vector2(555, 322), Vector2(615, 520), Vector2(668, 672), Vector2(690, 745)], "half": 42},
}
const ARM_K := 1.5
## The oversized slate shoulder plate over the mechanical arm, from the side view (the eye sigil faces out).
const PLATE := {"side": "L", "centre": Vector2(1597, 336), "radius_px": 72.0, "size": Vector3(0.15, 0.13, 0.16),
	"offset": Vector3(-0.035, 0.035, 0.0)}
## The orange signal scarf's tail: a flat orange patch on the front view to paint it with.
const SCARF := {"patch": Vector2(600, 260), "len": 0.55, "width": 0.1}
## Palette -> toon slot (painted colours sampled off the sheet): each face takes the nearest one's slot.
const PALETTE := [
	["skin", Color("c08a70")], ["skin", Color("8e5e48")], ["hair", Color("4a2e24")],
	["cloth", Color("2c2e4c")], ["cloth", Color("d0602c")], ["cloth", Color("8a7a5e")], ["cloth", Color("c0aa8c")],
	["metal", Color("586675")], ["metal", Color("4a4c50")], ["metal", Color("b08a40")],
	["leather", Color("2c2521")], ["leather", Color("313137")],
]
## The mechanical eye's glow: the brightest warm orange on the head (the scarf's orange stays cloth).
const GLOW_MIN := Vector3(0.94, 0.59, 0.0)
const GLOW_MAX_B := 0.55
