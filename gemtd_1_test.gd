extends Node3D

@onready var grid_manager = $GridManager
@onready var ui_manager = $UIManager
@onready var build_manager = $BuildManager # Added link to your BuildManager node

func _ready() -> void:
	# This tells Godot: "Listen to UIManager. When it emits 'map_type_selected', 
	# immediately run the '_on_ui_map_selected' function below." [cite: 24, 25]
	ui_manager.map_type_selected.connect(_on_ui_map_selected) 
	ui_manager.hero_selected.connect(_on_ui_hero_selected) 

func _on_ui_map_selected(profile: MapProfile) -> void:
	print("Passing map profile through middle layer: ", profile.profile_name)
	# Safely hands off the object directly to the waiting GridManager
	if $GridManager:
		$GridManager.initialize_map(profile)

func _on_ui_hero_selected(profile: HeroData) -> void:
	print("Passing hero data through middle layer: ", profile.hero_name)
	
	# Uses the helper function we wrote inside HeroData to get the old dictionary structure
	var modifiers: Dictionary = profile.get_modifiers_dict()
	
	# --- Your original economy/gameplay logic below this line remains exactly the same! ---
	
	# 1. Apply any hero configuration modifiers here (e.g. bonus starting gold)
	# ...
	
	# 2. GOLDEN LINE: Turn on the BuildManager grid tracking safely!
	# This unlocks building mode now that the game has officially entered gameplay state.
	if build_manager:
		build_manager.start_game_building()
		print("BuildManager safety gate unlocked. Tower placement activated!")
	else:
		push_error("Main Script Error: Could not find the BuildManager node!")
