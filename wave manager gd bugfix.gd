extends Node

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.0

@onready var grid_manager = $"../GridManager"
@onready var score_manager = $"../ScoreManager"

# --- GEMTD WAVE CORE DATA ---

const CREEP_ARCHETYPES = {"Normal": {"base_health": 100.0, "base_speed": 2.5, "physical_res": 0.10, "magic_res": 0.10, "color": Color(0.2, 0.6, 0.9)}, "Runner": {"base_health": 60.0, "base_speed": 4.5, "physical_res": 0.05, "magic_res": 0.05, "color": Color(0.2, 0.9, 0.3)}, "Armored": {"base_health": 180.0, "base_speed": 1.8, "physical_res": 0.45, "magic_res": 0.0, "color": Color(0.6, 0.4, 0.2)}, "Boss": {"base_health": 1000.0, "base_speed": 2.0, "physical_res": 0.25, "magic_res": 0.25, "color": Color(0.9, 0.1, 0.1)}}

const CLASSIC_WAVES = [{"type": "Normal", "count": 10}, {"type": "Normal", "count": 12}, {"type": "Runner", "count": 8}, {"type": "Normal", "count": 15}, {"type": "Boss", "count": 1}]

const BLITZ_WAVES = [
	{"type": "Normal", "count": 5}, 
	{"type": "Runner", "count": 10}, 
	{"type": "Armored", "count": 6}, 
	{"type": "Boss", "count": 1}
]

# --- RUNTIME VARIABLES ---

# --- RUNTIME VARIABLES ---


var astar: AStarGrid2D 
var current_wave_path: Array[Vector3] = []
var spawn_timer: Timer 

var current_wave_number: int = 1 
var active_game_mode: String = "Classic" # Set via UIManager selection [cite: 10]
var extra_enemies_modifier: int = 0 

# Tracking the specific sequence to spawn for the current active round
var active_wave_type: String = "Normal" 
var enemies_left_to_spawn: int = 0

func _ready() -> void: 
	_setup_spawn_timer() 
	if score_manager: 
		score_manager.wave_modifier_changed.connect(_on_difficulty_changed) 

func _setup_spawn_timer() -> void: 
	spawn_timer = Timer.new() 
	spawn_timer.wait_time = spawn_interval 
	spawn_timer.timeout.connect(_on_spawn_timer_timeout) 
	add_child(spawn_timer) 

func _on_difficulty_changed(new_modifier: int) -> void: 
	extra_enemies_modifier = new_modifier 

# --- EXPORTED PATHFINDING LOGIC --- 

func setup_pathfinding() -> void:
	var profile = grid_manager.MAP_PROFILES[grid_manager.active_profile]
	
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, profile["width"], profile["height"])
	astar.cell_size = Vector2(1, 1)
	
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	
	var coord_waypoints: Array[Vector2i] = []
	coord_waypoints.append(profile["spawn"])
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

func _tile_to_world_position(grid_coord: Vector2i, profile: Dictionary) -> Vector3:
	var offset_x: float = (profile["width"] - 1) / 2.0
	var offset_z: float = (profile["height"] - 1) / 2.0
	return Vector3(grid_coord.x - offset_x, 0.05, grid_coord.y - offset_z)

# --- WAVE EXECUTION ENGINE ---

## Triggers the game loop sequence for the current round
func start_next_wave() -> void:
	if current_wave_path.is_empty():
		setup_pathfinding()
	
	# Fallback to schedule profiles based on selected game mode
	var schedule = CLASSIC_WAVES if active_game_mode == "Classic" else BLITZ_WAVES
	
	# Safety check: Reset or stop if game exceeded scheduled bounds
	if current_wave_number > schedule.size():
		print("Victory! All scheduled waves complete.")
		return
		
	var wave_data = schedule[current_wave_number - 1]
	active_wave_type = wave_data["type"]
	
	# Apply ScoreManager modification only if it isn't a boss round
	if active_wave_type == "Boss":
		enemies_left_to_spawn = wave_data["count"]
	else:
		enemies_left_to_spawn = max(1, wave_data["count"] + extra_enemies_modifier)
		
	print("Starting Wave ", current_wave_number, " (", active_wave_type, "). Spawning: ", enemies_left_to_spawn)
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if enemies_left_to_spawn <= 0:
		spawn_timer.stop()
		current_wave_number += 1 # Advance sequence index for next execution
		return
		
	if enemy_scene:
		var enemy_instance = enemy_scene.instantiate()
		
		# 1. Fetch properties from database and compute dynamic exponential scaling
		var archetype = CREEP_ARCHETYPES[active_wave_type]
		var growth_rate: float = 1.25 if active_wave_type == "Boss" else 1.15
		var final_hp = archetype["base_health"] * pow(growth_rate, current_wave_number - 1)
		
		# 2. Assign attributes to enemy node instance
		enemy_instance.max_health = final_hp
		enemy_instance.current_health = final_hp
		enemy_instance.physical_resistance = archetype["physical_res"]
		enemy_instance.magic_resistance = archetype["magic_res"]
		
		# 3. Add to hierarchy and route pathing
		get_parent().add_child(enemy_instance)
		enemy_instance.add_to_group("enemies") # Critical for AOE / Chains!
		
		if enemy_instance.has_method("set_path"):
			enemy_instance.set_path(current_wave_path)
			
		# 4. Color the placeholder visual mesh based on identity profile
		var mesh = enemy_instance.get_node_or_null("CSGSphere3D")
		if mesh and mesh is CSGSphere3D:
			var material = StandardMaterial3D.new()
			material.albedo_color = archetype["color"]
			mesh.material = material
			
		enemies_left_to_spawn -= 1

# --- GRID MANAGEMENT FUNCTIONS ---

func block_tile(grid_coord: Vector2i) -> void:
	if astar:
		astar.set_point_solid(grid_coord, true)
		_recalculate_active_paths()

func _recalculate_active_paths() -> void:
	var profile = grid_manager.MAP_PROFILES[grid_manager.active_profile]
	
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
			
	get_tree().call_group("enemies", "update_path_mid_run", current_wave_path, _tile_to_world_position)
