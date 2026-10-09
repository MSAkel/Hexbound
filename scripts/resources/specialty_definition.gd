class_name SpecialtyDefinition
extends Resource

# Data for one playable specialty. Map geometry is shared. This resource owns identity and run passives.

enum PassiveKind {
	NONE,
	SOUS_CHEF,
	SOMMELIER,
	GOURMET_RESTAURANT,
}

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D = null
@export var passive_kind: PassiveKind = PassiveKind.NONE
@export_multiline var passive_description: String = ""
