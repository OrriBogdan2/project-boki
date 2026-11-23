class_name HomeDashSlot
extends Control
## The dash slot at home (farm, town, house): the match bar's DashSlot, drawn by the same code from the
## same numbers (Home.dash is the DashState a Hunter owns too).
## It plays the part of Hud for HudSlot: the per-slot animation state the slot code expects lives here.
## In the garden nothing there needs a dash, so the slot stays away until the player's first dash.

const SLOT := 50.0           # px, the same square as the bottom bar's slots
const USED_KEY := "dash_used"   # tutorial flag: in the garden (base_mode) the slot shows from the first dash
const BOTTOM := 132.0        # px from the screen bottom to the slot's top (clears the key hints)

var home = null            # the Home (untyped: it has no class_name)
var c: CanvasItem = self
var slot_fx := {}
var ready_was := {}
var ready_flash := {}
var hover_spots: Array = []
var slot_text := {}

func _init() -> void:
	name = "DashSlot"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	var room: bool = home.panel_open == "" and not Overlay.is_open()
	var tut: Dictionary = Save.d["tutorial"]
	if room and Input.is_action_just_pressed("dash"):
		tut[USED_KEY] = true
	visible = room and (tut.get(USED_KEY, false) or not FarmUnlocks.base_mode())
	HudSlot.decay(self, delta)
	if visible:
		queue_redraw()

func _draw() -> void:
	hover_spots.clear()
	var dg: Dictionary = home._dodge()
	var dd := Content.class_dodge(Data.class_of_save())
	var icon: String = dd.icon if dd else "dash"
	var col: Color = dd.color if dd else Color("bfe6ff")
	var cap := int(dg["charges"])
	var s := DashSlot.src(home.dash.charges, cap, float(dg["cd"]), home.dash.ex_cd, float(dg["ex_cd"]), icon, col)
	var r := Rect2(Vector2((size.x - SLOT) * 0.5, size.y - BOTTOM), Vector2(SLOT, SLOT))
	DashSlot.draw(self, r, s)

## A dash pressed with nothing to spend: the red pulse and tick, as on the match bar.
func deny() -> void:
	PressDeny.raise(self, "dash")

func _rounded(r: Rect2, col: Color, rad := 10, border := Color(0, 0, 0, 0), bw := 0) -> void:
	c.draw_style_box(HudStyle.box(col, rad, border, bw), r)
