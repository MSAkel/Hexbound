class_name ChefDefinition
extends Resource

# Data for one playable chef. Map geometry is shared. This resource owns identity and the run-long speciality.

enum SpecialityKind {
	NONE,
	SOUS_CHEF,
	SOMMELIER,
	GOURMET_RESTAURANT,
}

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D = null
@export var speciality_kind: SpecialityKind = SpecialityKind.NONE
@export_multiline var speciality_description: String = ""
