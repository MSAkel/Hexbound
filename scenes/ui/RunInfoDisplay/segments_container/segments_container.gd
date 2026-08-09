extends PanelContainer

const SEGMENT_RESULTS_SCENE := preload(
	"res://scenes/ui/RunInfoDisplay/segments_container/segment_results.tscn"
)

@onready var segment_results_list: VBoxContainer = $VBoxContainer/SegmentResultsList


func _ready() -> void:
	call_deferred("_build_segment_rows")


## Creates one segment_results row for each map segment after the board is generated.
func _build_segment_rows() -> void:
	var tile_map := get_tree().get_first_node_in_group("hex_map_group") as HexTileMap
	if tile_map == null:
		return

	for child in segment_results_list.get_children():
		child.queue_free()

	for segment_index in tile_map.get_segment_count():
		var row: PanelContainer = SEGMENT_RESULTS_SCENE.instantiate()
		row.segment_index = segment_index
		segment_results_list.add_child(row)
