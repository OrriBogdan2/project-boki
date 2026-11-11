class_name TryRelic
extends Node
## "Try" on a second-pick card (HobOffer): the Training Grounds loader (Match.arena_opts) with that Hunter for
## TRY_S seconds, then back to Hob's same card. Nothing is saved or spent: the Arena is a training match, and
## the pick is made only by Take. The Grounds' own hints stay up (keys line, kit card); this adds a countdown.

const NAME := "TryRelic"
const TRY_S := 60.0            # s in the Grounds before it hands you back to the card
const LABEL_Y := 36.0          # px: the countdown, under the Grounds' keys line

## The Relic whose card to return to (set by start, cleared by HobOffer once it is back on screen).
static var back_to := ""

var m: Match
var left_s := TRY_S
var countdown: Label

## Opens the Grounds as this Hunter and remembers the card to come back to.
static func start(hunter_id: String) -> void:
	back_to = hunter_id
	var o := Match.arena_opts(hunter_id)
	o["try_relic"] = true
	Game.start_match(o)

## Called by Match when a try session starts: the timer that ends it.
static func arm(match_node: Match) -> TryRelic:
	var t := TryRelic.new()
	t.name = NAME
	t.m = match_node
	match_node.add_child(t)
	t.countdown = UI.label("", 18, Color("f3eee2"), UI.big)
	t.countdown.add_theme_constant_override("outline_size", 6)
	t.countdown.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	t.countdown.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	t.countdown.grow_horizontal = Control.GROW_DIRECTION_BOTH
	t.countdown.position.y = LABEL_Y
	var layer := CanvasLayer.new()
	layer.layer = 41
	layer.add_child(t.countdown)
	t.add_child(layer)
	t._show()
	return t

func _process(dt: float) -> void:
	if m.paused or m.over:
		return
	left_s -= dt
	_show()
	if left_s <= 0.0:
		set_process(false)
		Practice.leave(m, true)

func _show() -> void:
	var secs := ceili(maxf(left_s, 0.0))
	countdown.text = "Trying %s  ·  %d s  ·  Leave to go back" % [HeroTitle.base_name(back_to), secs]
