class_name FirstRelic
extends RefCounted
## Your first Relic (Lace, Kael or Vex). The fight path picks it on the hatch island (Hatch, MaskMoment); the
## garden path skips that and picks it here, the first time you step to the portal: the same three cards
## (HobOffer), then the Relic drifts out of the portal to you and goes on (MaskBeat, the put-on beat without the
## swap, as Hob's second Relic does), and the expedition panel opens.

const PANEL := "Relic"        # Home.panel_open while the pick and the put-on run (you stand still)
const FROM_PORTAL := Vector3(0.0, 1.8, 0.0)      # m above the portal's spot: where the Relic leaves from

## Makes `id` your Hunter: the weight class, the weapon, saved.
static func wear(id: String) -> void:
	Save.d["arch"] = id
	Save.d["cls"] = Arch.weight(id)
	Save.d["weapon"] = Arch.signature(id)
	Save.save_game()

## The pick over the farm; `then` runs once it is on.
static func offer(h, then: Callable) -> void:
	var v: VBoxContainer = h._new_panel(PANEL, 820)
	var picked := func(id: String):
		h._close_panel()
		_put_on(h, id, then)
	var pick := HobOffer.new(ClassUnlock.starters(), FarmBuilder.rules()["talk"], "starter_title",
			func(id): return ClassUnlock.choose_starters([id]), picked)
	v.add_child(pick.build())

static func _put_on(h, id: String, then: Callable) -> void:
	wear(id)
	h.panel_open = PANEL
	if h.hub:
		h.hub.visible = false
	var relic := MaskRelic.make(id)
	h.add_child(relic)
	relic.global_position = h.spots["portal"] + FROM_PORTAL
	MaskBeat.play(relic, h.player, func(_body): _done(h, then), false)

static func _done(h, then: Callable) -> void:
	h.panel_open = ""
	if h.hub:
		h.hub.visible = true
	h._refresh_top()
	then.call()
