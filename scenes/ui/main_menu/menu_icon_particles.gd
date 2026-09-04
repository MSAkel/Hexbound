extends GPUParticles2D

## Packs ingredient and kitchenware card icons into a particle spritesheet.

const CELL_SIZE := 64
const MENU_CARD_TYPES: Array[TileCard.TileCardType] = [
	TileCard.TileCardType.INGREDIENT,
	TileCard.TileCardType.KITCHENWARE,
]


func _ready() -> void:
	var icons := _collect_icons()
	if icons.is_empty():
		push_warning("Main menu particles found no ingredient or kitchenware icons.")
		return

	# Square grid so GPU particles can pick a random atlas frame per spawn.
	var column_count := maxi(1, ceili(sqrt(icons.size())))
	var row_count := maxi(1, ceili(float(icons.size()) / float(column_count)))
	_pad_icons_to_grid(icons, column_count * row_count)
	texture = _build_atlas(icons, column_count, row_count)
	_apply_frame_material(column_count, row_count)

	var host := get_parent() as Control
	if host != null:
		host.resized.connect(_fit_emitter_to_host)
	_fit_emitter_to_host()


func _collect_icons() -> Array[Texture2D]:
	var icons: Array[Texture2D] = []
	var seen_paths: Dictionary = {}
	for card: TileCard in GameManager.tile_cards_pool:
		if card == null or card.icon == null:
			continue
		if card.type not in MENU_CARD_TYPES:
			continue
		var icon_path := card.icon.resource_path
		if icon_path != "" and seen_paths.has(icon_path):
			continue
		if icon_path != "":
			seen_paths[icon_path] = true
		icons.append(card.icon)
	return icons


func _pad_icons_to_grid(icons: Array[Texture2D], frame_count: int) -> void:
	# Unused atlas cells would otherwise spawn as blank particles.
	var source_count := icons.size()
	if source_count == 0:
		return
	while icons.size() < frame_count:
		icons.append(icons[icons.size() % source_count])


func _build_atlas(icons: Array[Texture2D], column_count: int, row_count: int) -> ImageTexture:
	var atlas := Image.create(column_count * CELL_SIZE, row_count * CELL_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))

	for index in icons.size():
		var source := _copy_icon_image(icons[index])
		if source == null:
			continue
		source.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_LANCZOS)
		var dest := Vector2i((index % column_count) * CELL_SIZE, int(index / column_count) * CELL_SIZE)
		atlas.blit_rect(source, Rect2i(Vector2i.ZERO, Vector2i(CELL_SIZE, CELL_SIZE)), dest)

	return ImageTexture.create_from_image(atlas)


func _copy_icon_image(icon: Texture2D) -> Image:
	var source := icon.get_image()
	if source == null:
		return null
	source = source.duplicate()
	if source.is_compressed():
		source.decompress()
	if source.get_format() != Image.FORMAT_RGBA8:
		source.convert(Image.FORMAT_RGBA8)
	return source


func _apply_frame_material(column_count: int, row_count: int) -> void:
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.particles_animation = true
	canvas_mat.particles_anim_h_frames = column_count
	canvas_mat.particles_anim_v_frames = row_count
	# Hold one random frame for the whole lifetime instead of flipping icons.
	canvas_mat.particles_anim_loop = false
	material = canvas_mat

	var process_mat := process_material as ParticleProcessMaterial
	if process_mat == null:
		return
	process_mat.anim_offset_min = 0.0
	process_mat.anim_offset_max = 1.0
	process_mat.anim_speed_min = 0.0
	process_mat.anim_speed_max = 0.0


func _fit_emitter_to_host() -> void:
	var host := get_parent() as Control
	var view_size := host.size if host != null and host.size.x > 0.0 else get_viewport_rect().size
	# Spawn just above the menu so icons rain down across the full width.
	position = Vector2(view_size.x * 0.5, -float(CELL_SIZE))

	var process_mat := process_material as ParticleProcessMaterial
	if process_mat != null:
		process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process_mat.emission_box_extents = Vector3(view_size.x * 0.5, 8.0, 1.0)

	visibility_rect = Rect2(-view_size.x, -128.0, view_size.x * 2.0, view_size.y + 256.0)
	# Fill the screen immediately so the rain is already falling on first frame.
	preprocess = lifetime
