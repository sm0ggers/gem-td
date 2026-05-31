extends Node
#GEMINIbuild test
@export var tower_scene: PackedScene
@onready var grid_manager = $"../GridManager"
@onready var wave_manager = $"../WaveManager"
@onready var ui_manager = $"../UIManager"

const TIERS = ["Chipped", "Flawed", "Normal", "Flawless", "Perfect"]
const QUALITIES = ["Ruby", "Sapphire", "Emerald", "Topaz", "Diamond", "Amethyst", "Aquamarine", "Opal"]

enum BuildState { PLACING_GEMS, CHOICE_PENDING }
var current_state: BuildState = BuildState.PLACING_GEMS

var spawned_round_towers: Array[Node3D] = []
var built_tile_coords: Array[Vector2i] = [] # Tracks occupied grid coordinates

# --- HOVER HIGHLIGHT VARIABLES ---
var hover_indicator: MeshInstance3D
var current_hovered_coord: Vector2i = Vector2i(-1, -1)

# --- Game State Guard ---
var is_game_active: bool = false

func _ready() -> void:
	# 1. Create a simple flat square mesh for the tile highlight frame
	hover_indicator = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(0.95, 0.95) # Slightly smaller than 1.0 for clean visual padding
	hover_indicator.mesh = plane_mesh
	
	# 2. Create a glowing, semi-transparent material overlay
	var material = StandardMaterial3D.new()
	material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.8, 1.0, 0.4) # Soft Cyan with 40% transparency
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Unshaded creates a flat glowing effect
	hover_indicator.material_override = material
	
	# Keep it hidden out of sight until game play explicitly begins
	hover_indicator.visible = false
	add_child(hover_indicator)

func _process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	# Safety check: Don't allow anything if we are still on the main menu
	if not is_game_active: return
	
	# 1. TRACK HOVER: Capture mouse slides, finger drags, or initial mobile taps
	if event is InputEventMouseMotion or event is InputEventScreenDrag or event is InputEventScreenTouch:
		var hovered_coord = _get_clicked_grid_coordinate()
		_update_hover_visualization(hovered_coord)
		
	# 2. TRACK CLICK / TOUCH RELEASE: Evaluate game placement actions
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		var clicked_coord = _get_clicked_grid_coordinate()
		if clicked_coord == Vector2i(-1, -1): return
		
		# Identify if the active device is natively using touch mechanics
		var is_mobile: bool = DisplayServer.get_name() in ["Android", "iOS"] or event is InputEventScreenTouch
		
		if is_mobile:
			# Mobile Logic: Confirmed double-tap workflow
			if current_hovered_coord == clicked_coord:
				if current_state == BuildState.PLACING_GEMS:
					_handle_placement_click(clicked_coord)
				elif current_state == BuildState.CHOICE_PENDING:
					_handle_choice_click(clicked_coord)
			else:
				# First tap acts only as target acquisition highlight
				_update_hover_visualization(clicked_coord)
		else:
			# Desktop Logic: Traditional immediate single-click implementation
			if current_state == BuildState.PLACING_GEMS:
				_handle_placement_click(clicked_coord)
			elif current_state == BuildState.CHOICE_PENDING:
				_handle_choice_click(clicked_coord)

## Smoothly moves the 3D target highlight bounding box over the specified coordinate
func _update_hover_visualization(coord: Vector2i) -> void:
	var profile: MapProfile = grid_manager.active_profile
	if not profile: return

	# Hide the visualization if the player moves out of playable bounds
	if coord == Vector2i(-1, -1) or coord in built_tile_coords:
		hover_indicator.visible = false
		# Preserve active selection status frame on mobile context to prevent touch stuttering
		if DisplayServer.get_name() not in ["Android", "iOS"]:
			current_hovered_coord = Vector2i(-1, -1)
		return
		
	current_hovered_coord = coord
	
	# Coordinate math utilizing the loaded profile metrics
	var offset_x: float = (profile.width - 1) / 2.0
	var offset_z: float = (profile.height - 1) / 2.0
	
	# Lift slightly off the terrain (Y: 0.06) to bypass visual Z-fighting clipping errors
	hover_indicator.global_position = Vector3(coord.x - offset_x, 0.06, coord.y - offset_z)
	hover_indicator.visible = true

## Public function your MainMenu script can call when Classic or Blitz is clicked!
func start_game_building() -> void:
	is_game_active = true
	current_state = BuildState.PLACING_GEMS
	print("Game Mode started! Grid placement enabled.")

## Handles placing a single gem down (up to 5 total)
func _handle_placement_click(coord: Vector2i) -> void:
	if coord in built_tile_coords: return
	
	var profile: MapProfile = grid_manager.active_profile
	if not profile: return
	
	if coord == profile.spawn or coord == profile.exit or coord in profile.checkpoints:
		return
		
	if tower_scene == null:
		push_error("BuildManager Error: tower_scene PackedScene is not assigned in the Inspector!")
		return
		
	_spawn_single_random_gem(coord)
	
	if spawned_round_towers.size() >= 5:
		current_state = BuildState.CHOICE_PENDING
		print("5 Gems placed! Now, click on the ONE gem you want to KEEP.")

## Spawns a unique random gem at the specified tile
func _spawn_single_random_gem(target_coord: Vector2i) -> void:
	var tower_instance = tower_scene.instantiate() as StaticBody3D
	get_parent().add_child(tower_instance)
	
	var profile: MapProfile = grid_manager.active_profile
	var offset_x: float = (profile.width - 1) / 2.0
	var offset_z: float = (profile.height - 1) / 2.0
	
	tower_instance.global_position = Vector3(target_coord.x - offset_x, 0.1, target_coord.y - offset_z)
	
	var random_tier = TIERS[randi() % TIERS.size()]
	var random_quality = QUALITIES[randi() % QUALITIES.size()]
	
	tower_instance.set_meta("grid_coord", target_coord)
	tower_instance.set_meta("tier", random_tier)
	tower_instance.set_meta("quality", random_quality)
	tower_instance.name = "%s_%s" % [random_tier, random_quality]
	
	_apply_tower_color(tower_instance, Color(0.9, 0.7, 0.1))
	
	wave_manager.block_tile(target_coord)
	built_tile_coords.append(target_coord)
	spawned_round_towers.append(tower_instance)
	
	print("Placed gem %d: %s %s" % [spawned_round_towers.size(), random_tier, random_quality])

## Detects if the player clicked on one of the 5 active round gems to keep it
func _handle_choice_click(coord: Vector2i) -> void:
	var chosen_tower: Node3D = null
	
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
			
			if tower.has_method("initialize_gem"):
				tower.initialize_gem(tower.get_meta("tier"), tower.get_meta("quality"))
				tower.activate_tower()
		else:
			tower.name = "Rock_Wall"
			_apply_tower_color(tower, Color(0.3, 0.3, 0.3)) # Gray for Rock
			
	spawned_round_towers.clear()
	current_state = BuildState.PLACING_GEMS
	print("Round complete. Ready to place 5 more!")

## Raycast logic helper
func _get_clicked_grid_coordinate() -> Vector2i:
	var camera = get_viewport().get_camera_3d()
	if not camera: return Vector2i(-1, -1)
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	var drop_plane = Plane(Vector3.UP, 0.0)
	var intersection_world_pos = drop_plane.intersects_ray(ray_origin, ray_normal)
	
	if intersection_world_pos:
		var profile: MapProfile = grid_manager.active_profile
		if not profile: return Vector2i(-1, -1)
		
		var grid_x = round(intersection_world_pos.x + ((profile.width - 1) / 2.0))
		var grid_z = round(intersection_world_pos.z + ((profile.height - 1) / 2.0))
		
		if grid_x >= 0 and grid_x < profile.width and grid_z >= 0 and grid_z < profile.height:
			return Vector2i(grid_x, grid_z)
	return Vector2i(-1, -1)

## Visual helper
func _apply_tower_color(node: Node3D, color: Color) -> void:
	var mesh_node = node.get_node_or_null("Mesh")
	if mesh_node:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color # Clean assignment!
		mesh_node.material_override = mat

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
