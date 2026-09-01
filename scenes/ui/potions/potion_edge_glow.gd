class_name PotionEdgeGlow
extends TextureRect

## Screen-edge veil that flashes when a belt potion is drunk.
## Uses a baked alpha mask instead of a ColorRect shader, so the playfield cannot flash solid.

const FLASH_IN := 0.12
const PEAK_HOLD := 0.2
const FADE_TO_SUBTLE := 1.0
const FADE_OUT := 0.7
const PEAK_INTENSITY := 0.9
const SUBTLE_INTENSITY := 0.2
const TEX_WIDTH := 320
const TEX_HEIGHT := 180
# How far the rim reaches inward, as a fraction of the shorter texture axis.
const EDGE_WIDTH := 0.2

var intensity: float = 0.0:
	set(value):
		intensity = value
		modulate.a = intensity

var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture = _build_vignette_texture()
	self_modulate = Color.WHITE
	intensity = 0.0
	hide()
	EventBus.potion_consume_started.connect(_on_consume_started)


func _on_consume_started(_slot_index: int, potion: Potion) -> void:
	if GameManager.skip_presentation or potion == null:
		return
	_play(_to_glow_color(potion.liquid_color))


func _play(glow_color: Color) -> void:
	if texture == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()

	self_modulate = glow_color
	intensity = 0.0
	show()

	var speed := maxf(GameManager.game_speed, 0.01)
	_tween = create_tween()
	_tween.tween_property(self, "intensity", PEAK_INTENSITY, FLASH_IN / speed).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(PEAK_HOLD / speed)
	_tween.tween_property(self, "intensity", SUBTLE_INTENSITY, FADE_TO_SUBTLE / speed).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	# Ease-in keeps the subtle rim around before it drops away.
	_tween.tween_property(self, "intensity", 0.0, FADE_OUT / speed).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)


func _to_glow_color(liquid: Color) -> Color:
	# Keep the potion hue. Nudge value up so the rim still reads on a bright map.
	var value := clampf(maxf(liquid.v, 0.58) + 0.08, 0.66, 0.95)
	var saturation := clampf(liquid.s, 0.5, 1.0)
	return Color.from_hsv(liquid.h, saturation, value, 1.0)


func _build_vignette_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 17
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.018

	var image := Image.create(TEX_WIDTH, TEX_HEIGHT, false, Image.FORMAT_RGBA8)
	var min_side := float(mini(TEX_WIDTH, TEX_HEIGHT))
	for y in TEX_HEIGHT:
		for x in TEX_WIDTH:
			var dist_x := minf(float(x), float(TEX_WIDTH - 1 - x)) / min_side
			var dist_y := minf(float(y), float(TEX_HEIGHT - 1 - y)) / min_side
			var edge := minf(dist_x, dist_y)
			var veil := 1.0 - _smoothstep(0.0, EDGE_WIDTH, edge)
			var corner := (1.0 - _smoothstep(0.0, EDGE_WIDTH * 1.35, dist_x)) * (
				1.0 - _smoothstep(0.0, EDGE_WIDTH * 1.35, dist_y)
			)
			veil = clampf(veil + corner * 0.6, 0.0, 1.0)
			# Square the falloff so the inner playfield stays clear.
			veil *= veil
			var wisp := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var streak := noise.get_noise_2d(float(x) * 0.45 + 80.0, float(y) * 0.45) * 0.5 + 0.5
			var texture_mod := lerpf(0.42, 1.0, wisp) * lerpf(0.7, 1.0, streak)
			var alpha := clampf(veil * texture_mod, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 0.0 if x < edge0 else 1.0
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
