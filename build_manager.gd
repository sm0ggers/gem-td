extends Node

@export var tower_scene: PackedScene
@onready var grid_manager = $"../GridManager"
@onready var wave_manager = $"../WaveManager"

const TIERS = ["Chipped", "Flawed", "Normal", "Flawless", "Perfect"]
const QUALITIES = ["Ruby", "Sapphire", "Emerald", "Topaz", "Diamond", "Amethyst", "Aquamarine", "Opal"]

enum BuildState { PLACING_GEMS, CHOICE_PENDING }
var current_state: BuildState = BuildState.PLACING_GEMS

var spawned_round_towers: Array[Node3D] = []
var built_tile_coords: Array[Vector2i] = [] # Tracks occupied grid coordinates

# --- Game State Guard ---
# This stops placement clicks completely until the player picks a game mode!
var is_game_active: bool = false

# Cleaned up: Removed the input check from _process completely so it doesn't fight the UI
func _process(_delta: float) -> void:
	pass

# Cleaned up: Using _unhandled_input ensures that if a UI Button catches the click, 
# this function is automatically skipped, preventing accidental placement crashes!
func _unhandled_input(event: InputEvent) -> void:
	# 1. Safety check: Don't allow building if we are still on the main menu
	if not is_game_active: return
	
	if event.is_action_pressed("click"):
		var clicked_coord = _get_clicked_grid_coordinate()
		if clicked_coord == Vector2i(-1, -1): 
			return # Clicked outside the map bounds
			
		if current_state == BuildState.PLACING_GEMS:
			_handle_placement_click(clicked_coord)
		elif current_state == BuildState.CHOICE_PENDING:
			_handle_choice_click(clicked_coord)

## Public function your MainMenu script can call when Classic or Blitz is clicked!
func start_game_building() -> void:
	is_game_active = true
	current_state = BuildState.PLACING_GEMS
	print("Game Mode started! Grid placement enabled.")

## Handles placing a single gem down (up to 5 total)
func _handle_placement_click(coord: Vector2i) -> void:
	# Don't build on top of old towers, spawns, or exits
	if coord in built_tile_coords: return
	var profile = grid_manager.MAP_PROFILES[grid_manager.active_profile]
	if coord == profile["spawn"] or coord == profile["exit"] or coord in profile["checkpoints"]:
		return
		
	# Double-check guard to ensure we don't try to instantiate a null scene asset
	if tower_scene == null:
		push_error("BuildManager Error: tower_scene PackedScene is not assigned in the Inspector!")
		return
		
	# Spawn ONE random gem
	_spawn_single_random_gem(coord)
	
	# If we have reached 5 gems, shift state so the player must choose one
	if spawned_round_towers.size() >= 5:
		current_state = BuildState.CHOICE_PENDING
		print("5 Gems placed! Now, click on the ONE gem you want to KEEP.")

## Spawns a unique random gem at the specified tile
func _spawn_single_random_gem(target_coord: Vector2i) -> void:
	var tower_instance = tower_scene.instantiate() as StaticBody3D
	get_parent().add_child(tower_instance)
	
	# Position calculation matching our GridManager shift
	var offset_x: float = (grid_manager.MAP_PROFILES[grid_manager.active_profile]["width"] - 1) / 2.0
	var offset_z: float = (grid_manager.MAP_PROFILES[grid_manager.active_profile]["height"] - 1) / 2.0
	tower_instance.global_position = Vector3(target_coord.x - offset_x, 0.1, target_coord.y - offset_z)
	
	# Roll properties
	var random_tier = TIERS[randi() % TIERS.size()]
	var random_quality = QUALITIES[randi() % QUALITIES.size()]
	
	# Attach information to the object
	tower_instance.set_meta("grid_coord", target_coord)
	tower_instance.set_meta("tier", random_tier)
	tower_instance.set_meta("quality", random_quality)
	tower_instance.name = "%s_%s" % [random_tier, random_quality]
	
	# Make it stand out visually as an undecided gem (e.g., Yellow/Gold)
	_apply_tower_color(tower_instance, Color(0.9, 0.7, 0.1))
	
	# Update pathfinding blocks instantly
	wave_manager.block_tile(target_coord)
	built_tile_coords.append(target_coord)
	spawned_round_towers.append(tower_instance)
	
	print("Placed gem %d: %s %s" % [spawned_round_towers.size(), random_tier, random_quality])

## Detects if the player clicked on one of the 5 active round gems to keep it
func _handle_choice_click(coord: Vector2i) -> void:
	var chosen_tower: Node3D = null
	
	# Look through our current 5 gems to see if the clicked tile matches any of them
	for tower in spawned_round_towers:
		if tower.get_meta("grid_coord") == coord:
			chosen_tower = tower
			break
			
	if chosen_tower != null:
		_confirm_choice(chosen_tower)

func _confirm_choice(chosen_tower: Node3D) -> void:
	for tower in spawned_round_towers:
		if tower == chosen_tower:
			tower.name = "Active_" + tower.name
			_apply_tower_color(tower, Color(0, 1, 1)) # Cyan for Active
			print("Kept: ", tower.get_meta("tier"), " ", tower.get_meta("quality"))
			
			# IMPORTANT LINK: Tell your new tower initialization rules who it is!
			if tower.has_method("initialize_gem"):
				tower.initialize_gem(tower.get_meta("tier"), tower.get_meta("quality"))
				tower.activate_tower()
		else:
			tower.name = "Rock_Wall"
			_apply_tower_color(tower, Color(0.3, 0.3, 0.3)) # Gray for Rock
			
	# Clear the temporary list and reset state back to building for the next round
	spawned_round_towers.clear()
	current_state = BuildState.PLACING_GEMS
	print("Round complete. Ready to place 5 more!")

## Raycast logic helper (Same as before)
func _get_clicked_grid_coordinate() -> Vector2i:
	var camera = get_viewport().get_camera_3d()
	if not camera: return Vector2i(-1, -1)
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	var drop_plane = Plane(Vector3.UP, 0.0)
	var intersection_world_pos = drop_plane.intersects_ray(ray_origin, ray_normal)
	
	if intersection_world_pos:
		var profile = grid_manager.MAP_PROFILES[grid_manager.active_profile]
		var grid_x = round(intersection_world_pos.x + ((profile["width"] - 1) / 2.0))
		var grid_z = round(intersection_world_pos.z + ((profile["height"] - 1) / 2.0))
		if grid_x >= 0 and grid_x < profile["width"] and grid_z >= 0 and grid_z < profile["height"]:
			return Vector2i(grid_x, grid_z)
	return Vector2i(-1, -1)

## Visual helper (Same as before)
func _apply_tower_color(node: Node3D, color: Color) -> void:
	var mesh_node = node.get_node_or_null("Mesh")
	if mesh_node:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mesh_node.material_override = mat

@onready var ui_manager = $"../UIManager"

func inspect_tower_at_tile(coord: Vector2i) -> void:
	var selected_tower = _get_tower_node_at(coord) 
	if selected_tower != null:
		var data = {
			"name": selected_tower.name,
			"damage": selected_tower.get_meta("damage") if selected_tower.has_meta("damage") else 0,
			"range": selected_tower.get_meta("range") if selected_tower.has_meta("range") else 0.0
		}
		ui_manager.display_tower_stats(data)
	else:
		ui_manager.display_tower_stats({})

func _get_tower_node_at(coord: Vector2i) -> Node3D:
	for child in get_parent().get_children():
		if child.has_meta("grid_coord"):
			if child.get_meta("grid_coord") == coord:
				return child as Node3D
	return null
