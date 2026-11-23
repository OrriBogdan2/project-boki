extends RefCounted
## --texture-budget-check, the VRAM budget for texture imports (DECISIONS 2026-11-08 performance pass).
## Every texture under res://art/ is one of two kinds. UI art (portraits, title and brand images; the
## UI_PREFIXES) stays lossless with no mipmaps: it is drawn 1:1 on screen. Everything else is sampled by
## a 3D material and must be VRAM compressed with mipmaps, and no source may be larger than MAX_PX.
## A new texture that is lossless, mip-less on a 3D material, or oversized fails here at import time.

const UI_PREFIXES := ["art/brand/", "art/portraits/", "art/splash.png"]
const MAX_PX := 2048               # px: longest side of any shipped texture source
const MODE_LOSSLESS := 0           # compress/mode: lossless
const MODE_VRAM := 2               # compress/mode: VRAM compressed (BPTC, ASTC fallback)

var fails := 0
var seen := 0

func run(main: Node) -> void:
	for imp in _imports("res://art"):
		_judge(imp)
	print("TEXBUDGET %d textures, failures: %d" % [seen, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _imports(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_imports(dir + "/" + d))
	return out

func _judge(imp: String) -> void:
	var cf := ConfigFile.new()
	cf.load(imp)
	if cf.get_value("remap", "importer", "") != "texture":
		return
	seen += 1
	var src: String = cf.get_value("deps", "source_file", imp.trim_suffix(".import"))
	var mode: int = cf.get_value("params", "compress/mode", MODE_LOSSLESS)
	var mips: bool = cf.get_value("params", "mipmaps/generate", false)
	var rel := src.trim_prefix("res://")
	var ui := false
	for p in UI_PREFIXES:
		ui = ui or rel.begins_with(p)
	if ui:
		var bad := mode != MODE_LOSSLESS or mips
		_fail(rel, bad, "UI art must be lossless, no mipmaps (mode %d, mips %s)" % [mode, mips])
		return
	_fail(rel, mode != MODE_VRAM, "3D texture is not VRAM compressed (mode %d)" % mode)
	_fail(rel, not mips, "3D texture has no mipmaps")
	var tex := load(src) as Texture2D
	if tex == null:
		_fail(rel, true, "not imported")
		return
	var side := maxi(tex.get_width(), tex.get_height())
	_fail(rel, side > MAX_PX, "longest side %d px, over %d" % [side, MAX_PX])

func _fail(rel: String, bad: bool, why: String) -> void:
	if bad:
		fails += 1
		print("TEXBUDGET FAIL %s: %s" % [rel, why])
