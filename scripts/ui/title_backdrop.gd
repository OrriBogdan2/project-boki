class_name TitleBackdrop
extends Control
## The title screen's backdrop: the Hunters' painted splashes (Portraits.art_path, like every screen), one at a time,
## each held still and crossfading to the next, in place of a 3D scene. (The slow push-in and pan was removed
## Nov 6: the owner read it as screen shake, mostly the lurch when a fresh, un-zoomed splash faded in over a
## zoomed, panned one. It stays still: no drift, so nothing here depends on Screen shake.)

const ORDER := ["juggernaut", "gunslinger", "mage", "archer", "bulwark", "rimewright",
	"ostra", "thief", "dolm", "ashwick", "dredge", "tender"]
const HOLD := 7.0            # s each splash is on screen
const FADE := 1.4            # s of crossfade into the next

var shown: Array = []        # [TextureRect, age]
var idx := 0
var age := 0.0

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _ready() -> void:
	_next()
	shown[0][0].modulate.a = 1.0

func _next() -> void:
	var tr := TextureRect.new()
	tr.texture = load(Portraits.art_path(ORDER[idx % ORDER.size()], true))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate.a = 0.0
	add_child(tr)
	shown.append([tr, 0.0])
	idx += 1

func _process(delta: float) -> void:
	delta = minf(delta, 0.1)   # a hitch never skips the crossfade
	age += delta
	if age >= HOLD:
		age = 0.0
		_next()
	for s in shown.duplicate():
		var tr: TextureRect = s[0]
		s[1] = float(s[1]) + delta
		tr.size = size
		tr.position = Vector2.ZERO
		if s != shown.back():
			continue
		tr.modulate.a = minf(1.0, float(s[1]) / FADE)
	# the older ones go once the newest is fully in
	while shown.size() > 1 and float(shown.back()[1]) >= FADE:
		(shown[0][0] as Node).queue_free()
		shown.pop_front()
