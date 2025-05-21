extends Node

# Boon selection signals
signal boon_selected(boon)  # Emitted when a boon is selected
signal boon_deselected(boon)  # Emitted when a boon is deselected
signal boon_slots_changed(current: int, max: int)  # Emitted when slot usage changes

# Game state signals
signal game_started(selected_boons: Array)  # Emitted when game starts with selected boons
signal game_paused  # Emitted when game is paused
signal game_resumed  # Emitted when game is resumed
signal game_ended  # Emitted when game ends

# Resource signals
signal gold_changed(new_amount: int)  # Emitted when gold amount changes
signal food_changed(new_amount: int)  # Emitted when food amount changes
signal essence_changed(type: String, new_amount: int)  # Emitted when essence amount changes

# Building signals
signal building_constructed(building_type: String)  # Emitted when a building is constructed
signal building_upgraded(building_type: String)  # Emitted when a building is upgraded

# Merchant signals
signal merchant_item_purchased(item_type: String)  # Emitted when an item is purchased
signal merchant_discount_changed(new_discount: float)  # Emitted when merchant discount changes

# Exploration signals
signal tile_explored(position: Vector2)  # Emitted when a new tile is explored
signal tile_discovered(position: Vector2)  # Emitted when a new tile is discovered

# Curse signals
signal curse_discovered(curse_type: String)  # Emitted when a curse is discovered
signal curse_requirements_changed(curse_type: String, new_requirements: Dictionary)  # Emitted when curse requirements change 