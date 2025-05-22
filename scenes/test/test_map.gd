extends HexTileMap

func _ready() -> void:
	# Call the parent's _ready to set up the map
	super._ready()
	
	# Explore all non-water tiles
	for x in width:
		for y in height:
			var coords = Vector2i(x, y)
			if map_data.has(coords):
				var h = map_data[coords]
				if h.terrain_type != hex.TerrainType.WATER:
					explore_tile(h) 
