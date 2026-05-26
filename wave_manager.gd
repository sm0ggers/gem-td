extends Node

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.0

@onready var grid_manager = $"../GridManager" # Adjust this path to your scene tree

var astar: AStarGrid2D
var current_wave_path: Array[Vector3] = []
var spawn_timer: Timer
var enemies_left_to_spawn: int = 0

func _ready() -> void:
	_setup_spawn_timer()

func _setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

## Builds the path routing through checkpoints using the GridManager's layout
func setup_pathfinding() -> void:
	var profile = grid_manager.MAP_PROFILES[grid_manager.active_profile]
	
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, profile["width"], profile["height"])
	astar.cell_size = Vector2(1, 1)
	
	# 1. CHANGED: Allows the system to calculate diagonal travel costs properly
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	
	# 2. CHANGED: Allows diagonals on open tiles, but blocks cutting between adjacent walls
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	
	astar.update()
	
	# Compile the full tile-coordinate sequence: Spawn -> Checkpoint 1 -> ... -> Exit
	var coord_waypoints: Array[Vector2i] = []
	coord_waypoints.append(profile["spawn"])
	for cp in profile["checkpoints"]:
		coord_waypoints.append(cp)
	coord_waypoints.append(profile["exit"])
	
	# Generate continuous path linking all checkpoints together
	current_wave_path.clear()
	for i in range(coord_waypoints.size() - 1):
		var segment = astar.get_id_path(coord_waypoints[i], coord_waypoints[i+1])
		
		# Skip the first tile on subsequent segments to prevent duplicate coordinates
		if i > 0 and not segment.is_empty():
			segment.remove_at(0)
			
		for coord in segment:
			current_wave_path.append(_tile_to_world_position(coord, profile))

## Converts a Vector2i grid coordinate to the shifted 3D space matching GridManager
func _tile_to_world_position(grid_coord: Vector2i, profile: Dictionary) -> Vector3:
	var offset_x: float = (profile["width"] - 1) / 2.0
	var offset_z: float = (profile["height"] - 1) / 2.0
	# Y position matches the top surface of your grid boxes
	return Vector3(grid_coord.x - offset_x, 0.05, grid_coord.y - offset_z)

## Public function to begin a wave
func start_wave(enemy_count: int) -> void:
	if current_wave_path.is_empty():
		setup_pathfinding()
		
	enemies_left_to_spawn = enemy_count
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if enemies_left_to_spawn <= 0:
		spawn_timer.stop()
		return
		
	if enemy_scene:
		var enemy_instance = enemy_scene.instantiate()
		# Add enemy as a child of the scene tree (e.g., under a YSort or the level root)
		get_parent().add_child(enemy_instance) 
		
		# Give the enemy its map routing
		if enemy_instance.has_method("set_path"):
			enemy_instance.set_path(current_wave_path)
			
		enemies_left_to_spawn -= 1
## Updates the AStar map to block a tile and forces path recalculation
func block_tile(grid_coord: Vector2i) -> void:
	if astar:
		astar.set_point_solid(grid_coord, true)
		_recalculate_active_paths()

func _recalculate_active_paths() -> void:
	var profile = grid_manager.MAP_PROFILES[grid_manager.active_profile]
	
	# Re-compile the master wave path
	var coord_waypoints: Array[Vector2i] = [profile["spawn"]]
	for cp in profile["checkpoints"]:
		coord_waypoints.append(cp)
	coord_waypoints.append(profile["exit"])
	
	current_wave_path.clear()
	for i in range(coord_waypoints.size() - 1):
		var segment = astar.get_id_path(coord_waypoints[i], coord_waypoints[i+1])
		if i > 0 and not segment.is_empty():
			segment.remove_at(0)
		for coord in segment:
			current_wave_path.append(_tile_to_world_position(coord, profile))
			
	# Update any enemies currently alive in the scene tree
	get_tree().call_group("enemies", "update_path_mid_run", current_wave_path, _tile_to_world_position)
