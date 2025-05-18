# Currently not in use
class_name TileEventData
extends Resource

enum EventType { NONE, CURSED, ENCAMPMENT, MYSTERY }

@export var id: String
@export var name: String
@export var icon: Texture2D
@export_multiline var description: String
@export var type: EventType
