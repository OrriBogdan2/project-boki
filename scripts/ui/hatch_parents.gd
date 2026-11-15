class_name HatchParents
extends RefCounted
## The parents row on a bred egg's hatch card: both parents' small portraits, then each inherited trait
## (colour, element lean, its best inherited stat, a personality note, rare mutations) with a tiny marker
## for the parent it came from. Reads what Care.breed saved on the baby (rec["gifts"], rec["iv_from"],
## rec["lineage"]["parents"]); Rare, wild and older babies have no gifts, so they get no row.

const MARK := [Color("ffb36a"), Color("7ac8ff")]      # parent a, parent b: the ring on its portrait and its dots
const PORTRAIT_PX := 44.0
const DOT_PX := 12.0

## True if the baby has a parents row to show (bred, with its gifts recorded).
static func has_row(baby: Dictionary) -> bool:
	return not (baby.get("gifts", {}) as Dictionary).is_empty() and (baby.get("parents", []) as Array).size() == 2

## The traits the row lists, in order: [{"what": label, "val": words, "from": parent index or Parentage.BOTH}].
static func traits(baby: Dictionary) -> Array:
	var g: Dictionary = baby["gifts"]
	var sp: Dictionary = Data.KIN.get(String(baby["species"]), {})
	var kind := String(sp.get("name", baby["species"]))
	var out: Array = [{"what": "Kind and colour", "val": kind, "from": int(g["species"])}]
	if g.has("lean"):
		out.append({"what": "Lean", "val": _lean_name(baby), "from": int(g["lean"])})
	var best := _best_stat(baby)
	if best != "":
		var iv: Dictionary = baby["ivs"]
		var stat_words := "%s %d" % [Care.IVS[best]["name"], int(iv[best])]
		out.append({"what": "Best stat", "val": stat_words, "from": int(baby["iv_from"][best])})
	var likes: Dictionary = baby.get("likes", {})
	if likes.has("food"):
		out.append({"what": "Loves", "val": Care.food_name(String(likes["food"])), "from": int(g["food"])})
	if likes.has("play"):
		var play := String(likes["play"])
		out.append({"what": "Likes", "val": String(Care.PLAY_NAMES.get(play, play)), "from": int(g["play"])})
	var muts: Dictionary = g.get("muts", {})
	for id in muts:
		out.append({"what": "Mutation", "val": Mutations.name_of(id), "from": int(muts[id])})
	return out

## The row itself: the two parents side by side, then one line per trait with its parent marker.
static func view(baby: Dictionary, tree: SceneTree) -> Control:
	var v := UI.vbox(3)
	var heads := UI.hbox(14)
	heads.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in [0, 1]:
		heads.add_child(_parent_head(baby, i, tree))
	v.add_child(heads)
	for t in traits(baby):
		var line := UI.hbox(6)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_child(UI.label("%s: %s" % [t["what"], t["val"]], UI.T_SMALL, UI.MUTED))
		line.add_child(_marker(int(t["from"])))
		v.add_child(line)
	return v

## One parent: its portrait (the roster rec by uid; a plain disc if it has left) ringed in its marker colour.
static func _parent_head(baby: Dictionary, i: int, tree: SceneTree) -> Control:
	var uids: Array = (baby.get("lineage", {}) as Dictionary).get("parents", [])
	var rec: Dictionary = Save.kin(String(uids[i])) if uids.size() == 2 and String(uids[i]) != "" else {}
	var col := UI.hbox(5)
	var pic := KinPortrait.view(rec, tree, PORTRAIT_PX)
	pic.add_child(Dot.new(i, DOT_PX))
	col.add_child(pic)
	col.add_child(UI.label(String(baby["parents"][i]), UI.T_SMALL, MARK[i]))
	return col

## The marker after a trait: one parent's dot, or both dots for a gift both parents share.
static func _marker(from: int) -> Control:
	var m := UI.hbox(2)
	for i in ([0, 1] if from == Parentage.BOTH else [from]):
		m.add_child(Dot.new(i, DOT_PX))
	return m

static func _lean_name(baby: Dictionary) -> String:
	var aff := String(Evo.lean(baby)[0])
	return String(Evo.AFF[aff]["name"]) if Evo.AFF.has(aff) else aff.capitalize()

## The highest IV the baby took from a parent ("" if none is recorded).
static func _best_stat(baby: Dictionary) -> String:
	var from: Dictionary = baby.get("iv_from", {})
	var iv: Dictionary = baby.get("ivs", {})
	var best := ""
	for k in Care.IV_KEYS:
		if from.has(k) and iv.has(k) and (best == "" or int(iv[k]) > int(iv[best])):
			best = k
	return best

## A small filled circle in a parent's marker colour.
class Dot extends Control:
	var tint := Color.WHITE
	var px := 0.0
	func _init(parent_i: int, size_px: float) -> void:
		tint = MARK[parent_i]
		px = size_px
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(Vector2(px, px) * 0.5, px * 0.5, Color("1a1620"))
		draw_circle(Vector2(px, px) * 0.5, px * 0.38, tint)
