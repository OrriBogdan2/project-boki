class_name BokiSpeech
extends RefCounted
## Sizes for every Boki speech bubble, in one place. The farm's 3D bubble was too big, so it scales by
## SCALE; the match HUD bubble keeps its readable pixel size.

const SCALE := 0.68          # of the farm bubble's old size
const FARM_PIXEL := 0.0105   # m per font pixel before SCALE
const MATCH_PX := 15         # the match HUD bubble's text size
