extends Node3D

@onready var grid_manager = $GridManager
@onready var ui_manager = $UIManager
@onready var build_manager = $BuildManager # Added link to your BuildManager node

func _ready() -> void:
	# This tells Godot: "Listen to UIManager. When it emits 'map_type_selected', 
	# immediately run the '_on_ui_map_selected' function below." [cite: 24, 25]
	ui_manager.map_type_selected.connect(_on_ui_map_selected) 
	ui_manager.hero_selected.connect(_on_ui_hero_selected) 

func _on_ui_map_selected(profile_name: String) -> void:
	print("SUCCESS! Main.gd received the button click for: ", profile_name) 
	# This safely triggers your GridManager to build the actual 3D blocks! [cite: 24, 26]
	grid_manager.initialize_map(profile_name) 

func _on_ui_hero_selected(hero_name: String, modifiers: Dictionary) -> void:
	print("Hero chosen: ", hero_name, " with modifiers: ", modifiers) 
	
	# 1. Apply any hero configuration modifiers here (e.g. bonus starting gold)
	# ...
	
	# 2. GOLDEN LINE: Turn on the BuildManager grid tracking safely!
	# This unlocks building mode now that the game has officially entered gameplay state.
	if build_manager:
		build_manager.start_game_building()
		print("BuildManager safety gate unlocked. Tower placement activated!")
	else:
		push_error("Main Script Error: Could not find the BuildManager node!")
