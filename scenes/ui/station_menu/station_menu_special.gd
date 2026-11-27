class_name StationMenuSpecial
extends VBoxContainer

## One perk on the Station menu. A picked perk ("Pairing: ...") shows its name above the text.

@onready var _name: Label = %Name
@onready var _description: RichTextLabel = %Description


## description is a perk description with {keyword} tokens. Call once the node is in the tree.
func setup(description: String) -> void:
	var colon := description.find(": ")
	_name.visible = colon > 0
	if colon > 0:
		_name.text = description.substr(0, colon)
		description = description.substr(colon + 2)
		# The text after a perk's name starts in lower case.
		description = description.left(1).to_upper() + description.substr(1)
	_description.text = CardKeywordGlossary.to_bbcode(description)
