class_name FxDot
extends RefCounted
## The one material of the soft round dots (shaders/fx_dot.gdshader): every burst and sparkle uses it. Low and Very Low
## take the shader's height fade on every renderer, so they never pay for a depth copy.

static var _mat: ShaderMaterial
static var _lite := false

static func material() -> ShaderMaterial:
	var lite := Settings.lite()
	if _mat == null or lite != _lite:
		var sh: Shader = load("res://shaders/fx_dot.gdshader")
		if lite:
			sh = sh.duplicate()
			sh.code = "#define DOT_HEIGHT_FADE\n" + sh.code
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_lite = lite
	return _mat
