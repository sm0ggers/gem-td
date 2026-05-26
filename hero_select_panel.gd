extends Control

# Preload your saved character data resources from Phase 1
const GREMLIN_DATA = preload("res://gremlin_hero.tres")
const MASON_DATA = preload("res://mason_hero.tres")
const GEMOLOGIST_DATA = preload("res://gemologist_hero.tres")

# Preload the master hero scene we built in Phase 2
const HERO_SCENE = preload("res://hero.tscn")

# 1. Connect your UI Button pressed() signals to these functions:
func _on_miner_button_pressed() -> void:
	_spawn_chosen_hero(GREMLIN_DATA)

func _on_sprinter_button_pressed() -> void:
	_spawn_chosen_hero(MASON_DATA)

func _on_mage_button_pressed() -> void:
	_spawn_chosen_hero(GEMOLOGIST_DATA)

# 2. This handles spawning the scene into your Main world map
func _spawn_chosen_hero(selected_data: HeroData) -> void:
	var new_hero = HERO_SCENE.instantiate()
	
	# Add the hero as a child of the Main scene
	var main_scene = get_tree().current_scene
	main_scene.add_child(new_hero)
	
	# Center of your 37x37 grid map layout
	new_hero.global_position = Vector3(18.5, 0.0, 18.5) 
	
	# Inject the resource stats into the hero script
	new_hero.load_hero_stats(selected_data)
	
	# Hide the selection menu so the player can see the map and start playing
	visible = false
