class_name HobModel
extends NpcModel
## Hob Brackenridge, the farm's builder, as a person (FarmHob places and drives him): an old adventurer turned
## builder in a patched ochre coat and a goggled wide-brim hat, a braided grey beard, a blueprint satchel and a
## big mallet across his back (art/npcs/hob, design: docs/art/npcs/PIPELINE.md). The body, poses, labels and
## portrait are NpcModel's. Poses: "idle", "wave", "talk", "point" (turns to point_at), "hammer", "walk".
## Over him: his name until you have talked to him, a "!" when he has something for you, a speech bubble (shout).

func _init() -> void:
	super("hob", FarmBuilder.full_name())
	name = "Hob"

## His face for the talk box.
static func face(px: float) -> TextureRect:
	return NpcModel.portrait(HobModel.new(), px)
