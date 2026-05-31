# build_manager.gd
extends Node

## Emitted whenever a tower is clicked/queried or building logic updates
signal tower_inspected(tower_node: Node3D, data: Dictionary)
signal choice_phase_ended()

@export var tower_scene: PackedScene
@onready var grid_manager = $"../GridManager"
@onready var wave_manager = $"../WaveManager"
@onready var ui_manager = $"../UIManager"

enum BuildState { PLACING_GEMS, CHOICE_PENDING, WAVE_PHASE }
var current_state: BuildState = BuildState.PLACING_GEMS

## Tracks the current round placement metrics
var max_gems_this_round: int = 5
var current_round_placed_count: int = 0

## Tracks references to nodes built explicitly inside this specific round
var spawned_round_towers: Array[Node3D] = []
## Tracks absolute map coordinates across all historical rounds
var built_tile_coords: Array[Vector2i] = []

# --- CONFIGURABLE ARCHITECTURES ---
var player_level: int = 1
var auto_start_wave: bool = false

## 1. WEIGHTED TIER SPAWN TABLE BY PLAYER LEVEL
## Mapping: level -> Array of weights corresponding exactly to index matches of GemData.TIERS
## Index: [0: Chipped, 1: Flawed, 2: Normal, 3: Flawless, 4: Perfect]
const WEIGHT_TABLE: Dictionary = {
	1: [100,  0,  0,  0,  0], # 100% Chipped
	2: [ 70, 30,  0,  0,  0], # 70% Chipped, 30% Flawed
	3: [ 40, 40, 20,  0,  0], # etc.
	4: [ 20, 30, 40, 10,  0],
	5: [ 10, 20, 40, 25,  5]
}

## 2. MODULAR ADVANCED RECIPES DATABASE
## Maps target Advanced names to an array of ingredient definitions.
const ADVANCED_RECIPES: Dictionary = {
	"Special Tower A": [
		{"tier": "Chipped", "quality": "Ruby"},
		{"tier": "Chipped", "quality": "Sapphire"},
		{"tier": "Flawed", "quality": "Topaz"}
	],
	"Silver Knight": [
		{"tier": "Chipped", "quality": "Diamond"},
		{"tier": "Chipped", "quality": "Opal"},
		{"tier": "Flawed", "quality": "Emerald"}
	]
}

# --- HOVER HIGHLIGHT VARIABLES ---
var hover_indicator: MeshInstance3D
var current_hovered_coord: Vector2i = Vector2i(-1, -1)
var is_game_active: bool = false

func _ready() -> void:
	_setup_hover_indicator()
	
	# Hook up UIManager signals if they aren't bound in the scene tree natively
	if ui_manager:
		tower_inspected.connect(ui_manager._on_tower_inspected)

func _setup_hover_indicator() -> void:
	hover_indicator = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(0.95, 0.95) 
	hover_indicator.mesh = plane_mesh
	
	var material = StandardMaterial3D.new()
	material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.8, 1.0, 0.4) 
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED 
	hover_indicator.material_override = material
	
	hover_indicator.visible = false
	add_child(hover_indicator)

func _unhandled_input(event: InputEvent) -> void:
	if not is_game_active: return
	
	# 1. TRACK HOVER: Capture mouse slides
	if event is InputEventMouseMotion or event is InputEventScreenDrag or event is InputEventScreenTouch:
		var hovered_coord = _get_clicked_grid_coordinate()
		_update_hover_visualization(hovered_coord)
		
	# --- ENGINE-LEVEL SAFETY: Only process cheats in a debug editor environment ---
	if OS.is_debug_build():
		# KEY_SECTION captures the '§' key exactly on European / Mac ISO keyboards!
		if event is InputEventKey and event.pressed and event.keycode == KEY_SECTION:
			var target_coord = _get_clicked_grid_coordinate()
			
			# Ensure we are hovering over a playable tile that isn't occupied yet
			if target_coord != Vector2i(-1, -1) and not target_coord in built_tile_coords:
				var mouse_screen_pos = get_viewport().get_mouse_position()
				
				# Define what happens when a tier/quality choice is clicked in the popup menu
				var spawn_callback = func(tier: String, quality: String):
					_debug_spawn_specific_gem(target_coord, tier, quality)
					print("Cheat Spawning: ", tier, " ", quality, " at grid ", target_coord)
				
				# Call UI manager to display the selection wheel right under the cursor
				if ui_manager.has_method("spawn_debug_cheat_menu"):
					ui_manager.spawn_debug_cheat_menu(mouse_screen_pos, spawn_callback)
				return # Intercept input processing safely
				
	# 2. TRACK CLICK / TOUCH RELEASE: Evaluate normal game placement actions
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		var clicked_coord = _get_clicked_grid_coordinate()
		if clicked_coord == Vector2i(-1, -1): return
		
		var is_mobile: bool = DisplayServer.get_name() in ["Android", "iOS"] or event is InputEventScreenTouch
		if is_mobile:
			if current_hovered_coord == clicked_coord:
				if current_state == BuildState.PLACING_GEMS:
					_handle_placement_click(clicked_coord)
				elif current_state == BuildState.CHOICE_PENDING:
					_handle_choice_click(clicked_coord)
			else:
				_update_hover_visualization(clicked_coord)
		else:
			if current_state == BuildState.PLACING_GEMS:
				_handle_placement_click(clicked_coord)
			elif current_state == BuildState.CHOICE_PENDING:
				_handle_choice_click(clicked_coord)


# --- INDEPENDENT SELECTION HANDLERS (Left Margin Cleared) ---

## Handles selection actions safely by finding the targeted node and routing to native menu loaders
func _handle_choice_click(coord: Vector2i) -> void:
	# Check objects placed in the parent tree
	var targeted_tower: Node3D = null
	for child in get_parent().get_children():
		if child.has_meta("grid_coord") and child.get_meta("grid_coord") == coord:
			targeted_tower = child as Node3D
			break
			
	# FIXED: Bypasses manual dictionary packing entirely, forwarding the tower node 
	# straight into your pre-built, robust inspection pipeline!
	if targeted_tower:
		_inspect_and_open_menu(targeted_tower)
		print("Inspecting tower via native _inspect_and_open_menu pipeline.")
	else:
		print("No valid tower node tracked at position: ", coord)


func start_game_building() -> void:
	is_game_active = true
	current_state = BuildState.PLACING_GEMS
	current_round_placed_count = 0
	spawned_round_towers.clear()
	print("Game Mode started! Grid placement enabled.")

func _process_interaction_at_coord(coord: Vector2i) -> void:
	match current_state:
		BuildState.PLACING_GEMS:
			_handle_placement_click(coord)
		BuildState.CHOICE_PENDING, BuildState.WAVE_PHASE:
			var clicked_tower = _get_tower_node_at(coord)
			if clicked_tower:
				_inspect_and_open_menu(clicked_tower)

func _handle_placement_click(coord: Vector2i) -> void:
	if coord in built_tile_coords: return
	var profile: MapProfile = grid_manager.active_profile
	if not profile or coord == profile.spawn or coord == profile.exit or coord in profile.checkpoints: return
	if not tower_scene: return
	
	_spawn_single_random_gem(coord)

## Spawns gem using your weighted structures and tracking systems
func _spawn_single_random_gem(target_coord: Vector2i) -> void:
	var tower_instance = tower_scene.instantiate() as StaticBody3D
	get_parent().add_child(tower_instance)
	
	var profile: MapProfile = grid_manager.active_profile
	var offset_x: float = (profile.width - 1) / 2.0
	var offset_z: float = (profile.height - 1) / 2.0
	tower_instance.global_position = Vector3(target_coord.x - offset_x, 0.1, target_coord.y - offset_z)
	
	# Create data resource instance
	var gem_data = GemData.new()
	gem_data.tier = _roll_weighted_tier()
	gem_data.quality = GemData.QUALITIES[randi() % GemData.QUALITIES.size()]
	gem_data.placement_timestamp = Time.get_ticks_msec()
	
	# Inject data into your tower instance
	tower_instance.set_meta("gem_data", gem_data)
	tower_instance.set_meta("grid_coord", target_coord)
	
	# Instantly apply baseline primitive visualization wrappers
	if tower_instance.has_method("initialize_visuals"):
		tower_instance.initialize_visuals(false, false)
	
	wave_manager.block_tile(target_coord)
	built_tile_coords.append(target_coord)
	spawned_round_towers.append(tower_instance)
	
	# Pass modification tracking check through an override filter method
	_evaluate_placement_increment()

## 2. INTERCEPTABLE COUNTER WRAPPER
## Modifies and checks step boundaries, providing clean hooks for unique skills or relics
func _evaluate_placement_increment() -> void:
	var value_to_add = 1
	
	current_round_placed_count += value_to_add
	print("Placed round gem. Total count towards limit: ", current_round_placed_count, "/", max_gems_this_round)
	
	if current_round_placed_count >= max_gems_this_round:
		current_state = BuildState.CHOICE_PENDING
		print("Max gems placed! Choice Phase Pending. Inspect a round gem to decide.")

## 1. LUCK ENGINE WEIGHT FILTER
func _roll_weighted_tier() -> String:
	var current_weights = WEIGHT_TABLE.get(player_level, WEIGHT_TABLE[1])
	var total_weight = 0
	for w in current_weights:
		total_weight += w
		
	var roll = randi() % total_weight
	var running_sum = 0
	
	for i in range(current_weights.size()):
		running_sum += current_weights[i]
		if roll < running_sum:
			return GemData.TIERS[i]
			
	return GemData.TIERS[0]

func _inspect_and_open_menu(tower: Node3D) -> void:
	var gem_data: GemData = tower.get_meta("gem_data") if tower.has_meta("gem_data") else null
	if not gem_data: return
	
	var context_data = {
		"tower_node": tower,
		"display_name": gem_data.get_display_name(),
		"tier": gem_data.tier,
		"quality": gem_data.quality,
		"is_advanced": gem_data.is_advanced_tower,
		"is_from_current_round": tower in spawned_round_towers,
		"can_downgrade": GemData.TIERS.find(gem_data.tier) > 0 and not gem_data.is_advanced_tower,
		"can_merge": _check_merge_availability(gem_data),
		"one_shot_recipes": _get_valid_one_shot_recipes()
	}
	
	tower_inspected.emit(tower, context_data)

# --- 4. CHOICES IMPLEMENTATION SUB-LOGICS ---

func execute_choice_keep(chosen_tower: Node3D) -> void:
	var gem_data: GemData = chosen_tower.get_meta("gem_data")
	_activate_and_keep_gem(chosen_tower, gem_data.tier, gem_data.quality)
	_convert_remaining_round_gems_to_rocks(chosen_tower)
	_finalize_building_round()

func execute_choice_downgrade(chosen_tower: Node3D) -> void:
	var gem_data: GemData = chosen_tower.get_meta("gem_data")
	var current_idx = GemData.TIERS.find(gem_data.tier)
	var lower_tier = GemData.TIERS[max(0, current_idx - 1)]
	
	_activate_and_keep_gem(chosen_tower, lower_tier, gem_data.quality)
	_convert_remaining_round_gems_to_rocks(chosen_tower)
	_finalize_building_round()

func _check_merge_availability(checking_gem: GemData) -> bool:
	if current_state != BuildState.CHOICE_PENDING: return false
	if checking_gem.is_advanced_tower: return false
	
	var matching_count = 0
	for tower in spawned_round_towers:
		var data: GemData = tower.get_meta("gem_data")
		if data and data.tier == checking_gem.tier and data.quality == checking_gem.quality:
			matching_count += 1
	return matching_count >= 2

func execute_choice_merge(chosen_tower: Node3D) -> void:
	var gem_data: GemData = chosen_tower.get_meta("gem_data")
	var current_idx = GemData.TIERS.find(gem_data.tier)
	var next_tier = GemData.TIERS[min(GemData.TIERS.size() - 1, current_idx + 1)]
	
	_activate_and_keep_gem(chosen_tower, next_tier, gem_data.quality)
	_convert_remaining_round_gems_to_rocks(chosen_tower)
	_finalize_building_round()

func _get_valid_one_shot_recipes() -> Array[String]:
	if current_state != BuildState.CHOICE_PENDING: return []
	
	var pool_signatures = []
	for tower in spawned_round_towers:
		var data: GemData = tower.get_meta("gem_data")
		if data and not data.is_advanced_tower:
			pool_signatures.append({"tier": data.tier, "quality": data.quality})
			
	var valid_recipes: Array[String] = []
	
	for recipe_name in ADVANCED_RECIPES:
		var ingredients: Array = ADVANCED_RECIPES[recipe_name]
		var temp_pool = pool_signatures.duplicate()
		var match_successful = true
		
		for ing in ingredients:
			var found_idx = -1
			for j in range(temp_pool.size()):
				if temp_pool[j].tier == ing.tier and temp_pool[j].quality == ing.quality:
					found_idx = j
					break
			if found_idx != -1:
				temp_pool.remove_at(found_idx)
			else:
				match_successful = false
				break
				
		if match_successful:
			valid_recipes.append(recipe_name)
			
	return valid_recipes

func execute_choice_one_shot(chosen_tower: Node3D, recipe_name: String) -> void:
	_transform_into_advanced(chosen_tower, recipe_name)
	_convert_remaining_round_gems_to_rocks(chosen_tower)
	_finalize_building_round()

# --- 5. MID-WAVE & MID-BUILD RE-COMBINATIONS ENGINE ---

func get_available_recipes_for_tower(tower: Node3D) -> Array[String]:
	var gem_data: GemData = tower.get_meta("gem_data") if tower.has_meta("gem_data") else null
	if not gem_data or gem_data.is_advanced_tower: return []
	
	var options: Array[String] = []
	for recipe_name in ADVANCED_RECIPES:
		var ingredients = ADVANCED_RECIPES[recipe_name]
		for ing in ingredients:
			if ing.tier == gem_data.tier and ing.quality == gem_data.quality:
				if not options.has(recipe_name):
					options.append(recipe_name)
	return options

func is_recipe_fully_available(clicked_tower: Node3D, recipe_name: String) -> bool:
	var ingredients: Array = ADVANCED_RECIPES[recipe_name].duplicate()
	var clicked_data: GemData = clicked_tower.get_meta("gem_data")
	
	for i in range(ingredients.size()):
		if ingredients[i].tier == clicked_data.tier and ingredients[i].quality == clicked_data.quality:
			ingredients.remove_at(i)
			break
			
	var map_towers = _get_all_active_towers_on_map()
	var targeted_ingredient_nodes: Array[Node3D] = []
	
	for ing in ingredients:
		var found_match: bool = false
		for t in map_towers:
			if t == clicked_tower or t in targeted_ingredient_nodes: continue
			var data: GemData = t.get_meta("gem_data")
			if data and data.tier == ing.tier and data.quality == ing.quality and not data.is_advanced_tower:
				targeted_ingredient_nodes.append(t)
				found_match = true
				break
		if not found_match:
			return false
			
	return true

func execute_mid_wave_combination(clicked_tower: Node3D, recipe_name: String) -> bool:
	var ingredients: Array = ADVANCED_RECIPES[recipe_name].duplicate()
	var clicked_data: GemData = clicked_tower.get_meta("gem_data")
	
	for i in range(ingredients.size()):
		if ingredients[i].tier == clicked_data.tier and ingredients[i].quality == clicked_data.quality:
			ingredients.remove_at(i)
			break
			
	var map_towers = _get_all_active_towers_on_map()
	var targeted_ingredient_nodes: Array[Node3D] = []
	
	for ing in ingredients:
		var candidates: Array[Node3D] = []
		for t in map_towers:
			if t == clicked_tower or t in targeted_ingredient_nodes: continue
			var data: GemData = t.get_meta("gem_data")
			if data and data.tier == ing.tier and data.quality == ing.quality and not data.is_advanced_tower:
				candidates.append(t)
				
		if candidates.is_empty():
			print("Missing required active ingredients on map for: ", recipe_name)
			return false
			
		candidates.sort_custom(func(a, b): 
			return a.get_meta("gem_data").placement_timestamp < b.get_meta("gem_data").placement_timestamp
		)
		targeted_ingredient_nodes.append(candidates[0])
		
	_transform_into_advanced(clicked_tower, recipe_name)
	
	for node in targeted_ingredient_nodes:
		node.name = "Rock_Wall"
		if node.has_method("initialize_visuals"):
			node.initialize_visuals(false, true)
			
	print("Advanced Combination Complete: Successful build of ", recipe_name)
	return true

# --- CORE SETTERS UTILITIES ---

func _activate_and_keep_gem(tower: Node3D, target_tier: String, target_quality: String) -> void:
	var gem_data: GemData = tower.get_meta("gem_data")
	gem_data.tier = target_tier
	gem_data.quality = target_quality
	tower.name = "Active_%s_%s" % [target_tier, target_quality]
	
	if tower.has_method("initialize_visuals"):
		tower.initialize_visuals(true, false)
	if tower.has_method("initialize_gem"):
		tower.initialize_gem(target_tier, target_quality)
		tower.activate_tower()

func _transform_into_advanced(tower: Node3D, recipe_name: String) -> void:
	var gem_data: GemData = tower.get_meta("gem_data")
	gem_data.is_advanced_tower = true
	gem_data.advanced_name = recipe_name
	tower.name = "Advanced_" + recipe_name.replace(" ", "_")
	
	if tower.has_method("initialize_visuals"):
		tower.initialize_visuals(true, false)
	if tower.has_method("initialize_gem"):
		tower.initialize_gem("Perfect", "Diamond") 
		tower.activate_tower()

func _convert_remaining_round_gems_to_rocks(chosen_tower: Node3D) -> void:
	for tower in spawned_round_towers:
		if tower != chosen_tower:
			tower.name = "Rock_Wall"
			if tower.has_method("initialize_visuals"):
				tower.initialize_visuals(false, true)

func _finalize_building_round() -> void:
	spawned_round_towers.clear()
	current_round_placed_count = 0
	current_state = BuildState.WAVE_PHASE
	choice_phase_ended.emit()
	
	if auto_start_wave:
		print("Auto-Start Wave Enabled. Launching combat sequence instantly...")
		if wave_manager:
			wave_manager.start_next_wave()
	else:
		print("Round finished. Waiting for manual Start Wave trigger.")

func reset_for_next_building_round() -> void:
	current_state = BuildState.PLACING_GEMS
	print("Ready to place gems for the next round!")

# --- HELPER SEARCH METRICS ---

func _update_hover_visualization(coord: Vector2i) -> void:
	var profile: MapProfile = grid_manager.active_profile
	if not profile: return

	if coord == Vector2i(-1, -1) or coord in built_tile_coords:
		hover_indicator.visible = false
		if DisplayServer.get_name() not in ["Android", "iOS"]:
			current_hovered_coord = Vector2i(-1, -1)
		return
		
	current_hovered_coord = coord
	var offset_x: float = (profile.width - 1) / 2.0
	var offset_z: float = (profile.height - 1) / 2.0
	hover_indicator.global_position = Vector3(coord.x - offset_x, 0.06, coord.y - offset_z)
	hover_indicator.visible = true

func _get_clicked_grid_coordinate() -> Vector2i:
	var camera = get_viewport().get_camera_3d()
	if not camera: return Vector2i(-1, -1)
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	var drop_plane = Plane(Vector3.UP, 0.0)
	var intersection_world_pos = drop_plane.intersects_ray(ray_origin, ray_origin + ray_normal * 1000.0)
	
	if intersection_world_pos:
		var profile: MapProfile = grid_manager.active_profile
		if not profile: return Vector2i(-1, -1)
		var grid_x = round(intersection_world_pos.x + ((profile.width - 1) / 2.0))
		var grid_z = round(intersection_world_pos.z + ((profile.height - 1) / 2.0))
		if grid_x >= 0 and grid_x < profile.width and grid_z >= 0 and grid_z < profile.height:
			return Vector2i(grid_x, grid_z)
	return Vector2i(-1, -1)

func _get_tower_node_at(coord: Vector2i) -> Node3D:
	for child in get_parent().get_children():
		if child.has_meta("grid_coord") and child.get_meta("grid_coord") == coord:
			return child as Node3D
	return null

func _get_all_active_towers_on_map() -> Array[Node3D]:
	var active_list: Array[Node3D] = []
	for child in get_parent().get_children():
		if child.has_meta("gem_data") and child.name.begins_with("Active_"):
			active_list.append(child)
	return active_list

## Debug helper to place an already finalized active gem instantly for recipe testing
func _debug_spawn_specific_gem(target_coord: Vector2i, target_tier: String, target_quality: String) -> void:
	if tower_scene == null: return
	
	var tower_instance = tower_scene.instantiate() as StaticBody3D
	get_parent().add_child(tower_instance)
	
	var profile: MapProfile = grid_manager.active_profile
	var offset_x: float = (profile.width - 1) / 2.0
	var offset_z: float = (profile.height - 1) / 2.0
	
	tower_instance.global_position = Vector3(target_coord.x - offset_x, 0.1, target_coord.y - offset_z)
	
	# Instantiate and populate the essential GemData resource wrapper expected by recipe checks
	var gem_data = GemData.new()
	gem_data.tier = target_tier
	gem_data.quality = target_quality
	gem_data.placement_timestamp = Time.get_ticks_msec()
	
	tower_instance.set_meta("grid_coord", target_coord)
	tower_instance.set_meta("tier", target_tier)
	tower_instance.set_meta("quality", target_quality)
	tower_instance.set_meta("gem_data", gem_data)
	
	# Name it as an Active gem so it bypasses unconfirmed round states
	tower_instance.name = "Active_%s_%s" % [target_tier, target_quality]
	
	# Pass information onto internal initialization scripts
	if tower_instance.has_method("initialize_gem"):
		tower_instance.initialize_gem(target_tier, target_quality)
	if tower_instance.has_method("activate_tower"):
		tower_instance.activate_tower()
		
	# Block the coordinate inside the pathfinding array
	wave_manager.block_tile(target_coord)
	built_tile_coords.append(target_coord)
	
	# Refresh visuals immediately to match its randomized attributes
	if tower_instance.has_method("initialize_visuals"):
		tower_instance.initialize_visuals(true, false)
