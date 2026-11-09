class_name HomeDashSlot
extends Control
## The dash slot at home (farm, town, house): the match bar's DashSlot, drawn by the same code from the
## same numbers (the home's mirror of the Hunter's dash state: Home.dash_charges, ex_cd, _dodge()).
## It plays the part of Hud for HudSlot: the per-slot animation state the slot code expects lives here.

const SLOT := 50.0           # px, the same square as the bottom bar's slots
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
	visible = home.panel_open == "" and not Overlay.is_open()
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
	var s := DashSlot.src(home.dash_charges, cap, float(dg["cd"]), home.ex_cd, float(dg["ex_cd"]), icon, col)
	var r := Rect2(Vector2((size.x - SLOT) * 0.5, size.y - BOTTOM), Vector2(SLOT, SLOT))
	DashSlot.draw(self, r, s)

## A dash pressed with nothing to spend: the red pulse and tick, as on the match bar.
func deny() -> void:
	PressDeny.raise(self, "dash")

func _rounded(r: Rect2, col: Color, rad := 10, border := Color(0, 0, 0, 0), bw := 0) -> void:
	c.draw_style_box(HudStyle.box(col, rad, border, bw), r)
