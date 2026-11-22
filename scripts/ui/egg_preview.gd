class_name EggPreview
extends RefCounted
## What an egg's card says about the Boki inside (the new-player egg pick): its picture, its name and
## its type. A mystery egg shows the same picture as a dark silhouette and no name, but its real type.

const PIC := 72.0       # px: the portrait on the card

## species: what hatches. mystery: show a silhouette and "???" instead of the picture and name.
static func build(species: String, mystery: bool, tree: SceneTree) -> Control:
	var row := UI.hbox(10)
	var pic := KinPortrait.view({"species": species, "level": 5}, tree, PIC)
	pic.name = "Picture"
	if mystery:
		pic.modulate = DexView.SILHOUETTE
	row.add_child(pic)
	var info := UI.vbox(4)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var boki := UI.title("???" if mystery else String(Data.KIN[species]["name"]), UI.T_HEAD, UI.INK)
	boki.name = "BokiName"
	info.add_child(boki)
	var chip := DexView.type_chip(DexView.type_of(species))
	chip.name = "TypeChip"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(chip)
	row.add_child(info)
	return row
