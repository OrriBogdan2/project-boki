class_name ItemHold
extends RefCounted
## Holding a shaping item at home (briefs/design/GARDEN_MODERN.md 1.3). "Hold" on an item in the bag puts it in your
## hand; walk up to a Boki and its ItemPreviewCard slides in while the model tries the change on for a moment.
## Press interact there to give it (the feed path, home.gd _care_feed); walk away from that Boki and the hold ends,
## the item still in the bag. The feed menu shows the same card when a row is hovered (peek()).
## Distances and times: content/rules/garden_items.json hold. home.gd calls tick() each frame.

static var wanted := ""        # the item the bag's Hold button picked, taken up by the next tick at home

var h                          # the Home screen
var card: ItemPreviewCard
var item := ""                 # the item in your hand ("" = none)
var near := {}                 # the Boki whose card is showing for the held item

func _init(home) -> void:
	h = home
	card = ItemPreviewCard.new(home.ui)
	wanted = ""

static func rules() -> Dictionary:
	return GardenItems.rules()["hold"]

## The bag's Hold button: the item goes in your hand at home.
static func want(id: String) -> void:
	wanted = id

## The feed menu row under the pointer: its card for this Boki, and the try-on.
func peek(rec: Dictionary, id: String, pick := "") -> void:
	if card.key == "%s:%s:%s" % [rec.get("uid", ""), id, pick]:
		return
	card.show_for(rec, id, pick)
	try_on(h._kin_entry(rec), id, pick)

## Each frame; true when it used the interact press (giving the item). can: no panel, chat or build is open.
func tick(can: bool) -> bool:
	if wanted != "":
		item = wanted
		wanted = ""
		h._toast("Holding %s: walk up to a Boki to see what it does" % GardenItems.item_name(item))
	if item == "":
		if h.panel_open == "" and card.showing():
			card.close()
		return false
	if int(Save.d["items"].get(item, 0)) <= 0 or not can or not h.visit.is_empty():
		return false
	var k := _nearest()
	if k.is_empty():
		if not near.is_empty():
			h._toast("You put the %s away" % GardenItems.item_name(item))
			drop()
		return false
	if not is_same(k, near):
		near = k
		card.show_for(k["rec"], item)
		try_on(k, item)
	if not Input.is_action_just_pressed("interact"):
		return false
	h._care_feed(k["rec"], item)
	drop()
	return true

## Ends the hold (the item stays in the bag) and slides the card out.
func drop() -> void:
	item = ""
	near = {}
	card.close()

func _nearest() -> Dictionary:
	var best := {}
	var reach := float(rules()["give_m"])
	for k in h.kins:
		var gap := Vector2(k["pos"].x - h.ppos.x, k["pos"].z - h.ppos.z).length()
		if gap < reach and not k.get("busy", false):
			reach = gap
			best = k
	return best

## For tryon_s the Boki wears what the item would change on it: its new colour (a lean or a rinse) or the path token.
func try_on(k: Dictionary, id: String, pick := "") -> void:
	if k.is_empty():
		return
	var pv := GardenItems.preview(k["rec"], id, pick)
	var d: Dictionary = pv["deltas"]
	var secs := float(rules()["tryon_s"])
	var real: Node3D = k["node"]
	var look: Node3D
	if d.has("lean"):
		look = Models.kin(k["rec"]["species"], GardenItems.after(k["rec"], pv))
		look.transform = real.transform
		h.add_child(look)
		real.visible = false
	elif d.has("path"):
		look = MeshInstance3D.new()
		(look as MeshInstance3D).mesh = Models.sphere(float(rules()["token_m"]), 10)
		(look as MeshInstance3D).material_override = Models.toon(Evo.AFF[GardenItems.aff_of(id)]["tint"])
		look.position = (k["emote"] as Node3D).position * float(rules()["token_at"])
		real.add_child(look)
	else:
		return
	h.get_tree().create_timer(secs).timeout.connect(func():
		if is_instance_valid(real):
			real.visible = true
		look.queue_free())
