class_name SummonPad
extends RefCounted
## The Training Grounds' Boki summon pad (DECISIONS 2026-11-09, Boki wisps). Stand on it for a short card: the
## round-vs-critter rule, the Summon key (live key cap) and the pad's Boki, out of its wisp for its species'
## window and then resting for its cooldown (KinSummon, content/rules/boki_summon.json); the HUD's summon ring
## shows the same. Interact on the pad brings the next of three practice Boki, each with its own window. It
## rides as a wisp here even with the wisp setting off, and the practice dummies beside the pad are its
## targets. Where it sits and the three species: content/rules/summon_pad.json.

const SIGN := "SUMMON PAD\nstand on it"
const CARD_LIFT := 3.0         # m above the pad
const COL_PAD := Color("9ad8ff")

var a: Arena
var pad: Vector3
var card: Label3D
var _line := ""                # the label's last text (it is only rewritten when it changes)

static func rules() -> Dictionary:
	return Content.rules("summon_pad")

## Where the pad wants to be, from where you start (metres).
static func offset() -> Vector3:
	var off: Array = rules()["offset"]
	return Vector3(float(off[0]), 0.0, float(off[1]))

func _init(arena: Arena, at: Vector3) -> void:
	a = arena
	pad = at
	var disc := MeshInstance3D.new()
	disc.mesh = Models.flat_quad(2.0 * float(rules()["r"]))
	disc.material_override = Models.ring_mat(COL_PAD, 0.12)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = pad + Vector3(0, 0.05, 0)
	a.m.add_child(disc)
	card = Label3D.new()
	card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	card.font = UI.big
	card.font_size = 30
	card.outline_size = 10
	card.pixel_size = 0.0075
	card.modulate = Color("ffe9b8")
	card.position = pad + Vector3(0, CARD_LIFT, 0)
	a.m.add_child(card)

## Is the player standing on the pad (and up)?
func on_pad() -> bool:
	var P: Hunter = a.m.player
	return not P.downed and P.flat_dist(pad) < float(rules()["r"])

## Interact on the pad: the next practice Boki, as a wisp with its summon ready.
func cycle() -> void:
	var ids: Array = rules()["species"]
	var k: Kin = a.m.player.kin
	var at := ids.find(String(k.species)) if k and not k.dead else -1
	a.set_kin(String(ids[(at + 1) % ids.size()]))
	KinWisp.set_wisp(a.m.player.kin, true)

## Each step: the card while you stand on the pad, else just its name.
func tick() -> void:
	var text := _text() if on_pad() else SIGN
	if text != _line:
		_line = text
		card.text = text

func _text() -> String:
	var k: Kin = a.m.player.kin
	var head := "SUMMON PAD\nYour Boki rides with you as a little critter-shaped glow;\n"
	head += "a Hunter's downed wisp is round. Round = Hunter, critter = Boki.\n"
	if k == null or k.dead or k.summon == null or not (rules()["species"] as Array).has(String(k.species)):
		return head + "%s  ·  bring a practice Boki" % Settings.key_cap("interact")
	var s := k.summon
	var times := "%s: out %d s, rests %d s" % [Data.KIN[k.species]["name"], int(s.dur), int(s.cd_base)]
	var now := "ready: press %s" % Settings.key_cap("summon")
	if s.left > 0.0:
		now = "out: %d s left  ·  %s sends it back" % [ceili(s.left), Settings.key_cap("summon")]
	elif s.out():
		now = "shrinking back"
	elif s.cd > 0.0:
		now = "resting: %d s" % ceili(s.cd)
	return "%s%s\n%s\n%s  ·  next practice Boki" % [head, times, now, Settings.key_cap("interact")]
