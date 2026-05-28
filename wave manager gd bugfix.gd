extends Node

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.0

@onready var grid_manager = $"../GridManager"
@onready var score_manager = $"../ScoreManager"

# --- GEMTD WAVE CORE DATA ---

# Updated to reference the new Enum values from EnemyArchetype
const CREEP_ARCHETYPES = {
	"Normal": {
		"base_health": 100.0,
		"base_speed": 2.5,
		"physical_res": 0.10,
		"magic_res": 0.10,
		"color": Color(0.2, 0.6, 0.9),
		"movement_type": 0 # EnemyArchetype.MoveType.GROUND
	},
	"Runner": {
		"base_health": 60.0,
		"base_speed": 4.5,
		"physical_res": 0.05,
		"magic_res": 0.05,
		"color": Color(0.2, 0.9, 0.3),
		"movement_type": 0 # EnemyArchetype.MoveType.GROUND
	},
	"Armored": {
		"base_health": 180.0,
		"base_speed": 1.8,
		"physical_res": 0.45,
		"magic_res": 0.0,
		"color": Color(0.6, 0.4, 0.2),
		"movement_type": 0 # EnemyArchetype.MoveType.GROUND
	},
	"Boss": {
		"base_health": 1000.0,
		"base_speed": 2.0,
		"physical_res": 0.25,
		"magic_res": 0.25,
		"color": Color(0.9, 0.1, 0.1),
		"movement_type": 0 # EnemyArchetype.MoveType.GROUND
	}
}

const CLASSIC_WAVES = [
	{"type": "Normal", "count": 10},
	{"type": "Normal", "count": 12},
	{"type": "Runner", "count": 8},
	{"type": "Normal", "count": 15},
	{"type": "Boss", "count": 1}
]

const BLITZ_WAVES = [
	{"type": "Normal", "count": 5}, 
	{"type": "Runner", "count": 10}, 
	{"type": "Armored", "count": 6}, 
	{"type": "Boss", "count": 1}
]

# --- RUNTIME VARIABLES ---

var astar: AStarGrid2D 
var current_wave_path: Array[Vector3] = []
var spawn_timer: Timer 

var current_wave_number: int = 1 
var active_game_mode: String = "Normal" # FIXED: Set default matching profile dictionary names ("Normal" or "Blitz")
var extra_enemies_modifier: int = 0 

# Tracking the specific sequence to spawn for the current active round
var active_wave_type: String = "Normal" 
var enemies_left_to_spawn: int = 0

func _ready() -> void: 
	_setup_spawn_timer() 
	if score_manager: 
		score_manager.wave_modifier_changed.connect(_on_difficulty_changed)
	
	# Automatically run navigation setup on launch so it doesn't wait for wave click
	if grid_manager:
		# Small delay to make sure GridManager finished building visual blocks first
		await get_tree().process_frame
		setup_pathfinding()

func _setup_spawn_timer() -> void: 
	spawn_timer = Timer.new() 
	spawn_timer.wait_time = spawn_interval 
	spawn_timer.timeout.connect(_on_spawn_timer_timeout) 
	add_child(spawn_timer) 

func _on_difficulty_changed(new_modifier: int) -> void: 
	extra_enemies_modifier = new_modifier 

# --- EXPORTED PATHFINDING LOGIC --- 

func setup_pathfinding() -> void:
	# Grab the active MapProfile object directly from the grid manager
	var profile: MapProfile = grid_manager.active_profile
	if not profile: return # Safety check
	
	astar = AStarGrid2D.new()
	# Read dimensions natively using object dot-notation
	astar.region = Rect2i(0, 0, profile.width, profile.height)
	astar.cell_size = Vector2(1, 1)
	
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	
	# Run initial coordinates building
	_recalculate_active_paths()

# CHANGED: Parameter type updated from Dictionary to MapProfile object
func _tile_to_world_position(grid_coord: Vector2i, profile: MapProfile) -> Vector3:
	# Read width and height safely from the resource object
	var offset_x: float = (profile.width - 1) / 2.0
	var offset_z: float = (profile.height - 1) / 2.0
	return Vector3(grid_coord.x - offset_x, 0.05, grid_coord.y - offset_z)

# --- WAVE EXECUTION ENGINE ---

## Triggers the game loop sequence for the current round
func start_next_wave() -> void:
	if current_wave_path.is_empty():
		setup_pathfinding()
	
	# FIXED: Match dynamic schedule safely against current runtime setup string
	var schedule = CLASSIC_WAVES if active_game_mode == "Normal" else BLITZ_WAVES
	
	if current_wave_number > schedule.size():
		print("Victory! All scheduled waves complete.")
		return
		
	var wave_data = schedule[current_wave_number - 1]
	active_wave_type = wave_data["type"]
	
	if active_wave_type == "Boss":
		enemies_left_to_spawn = wave_data["count"]
	else:
		enemies_left_to_spawn = max(1, wave_data["count"] + extra_enemies_modifier)
		
	print("Starting Wave ", current_wave_number, " (", active_wave_type, "). Spawning: ", enemies_left_to_spawn)
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if enemies_left_to_spawn <= 0:
		spawn_timer.stop()
		current_wave_number += 1 
		return
		
	if enemy_scene:
		var enemy_instance = enemy_scene.instantiate()
		
		var archetype = CREEP_ARCHETYPES[active_wave_type]
		var growth_rate: float = 1.25 if active_wave_type == "Boss" else 1.15
		var final_hp = archetype["base_health"] * pow(growth_rate, current_wave_number - 1)
		
		# Assign baseline attributes
		enemy_instance.max_health = final_hp
		enemy_instance.current_health = final_hp
		enemy_instance.base_speed = archetype["base_speed"]
		enemy_instance.physical_resistance = archetype["physical_res"]
		enemy_instance.magic_resistance = archetype["magic_res"]
		
		# MODULAR FIX: Set the active movement type state on the enemy body
		if "current_movement_type" in enemy_instance:
			enemy_instance.current_movement_type = archetype["movement_type"]
		
		get_parent().add_child(enemy_instance)
		enemy_instance.add_to_group("enemies") 
		
		if enemy_instance.has_method("set_path"):
			enemy_instance.set_path(current_wave_path)
			
		# Visual coloration
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
	# Grab the active MapProfile object directly from the grid manager
	var profile: MapProfile = grid_manager.active_profile
	if not profile: return
	
	# Read properties cleanly directly from the object fields
	var coord_waypoints: Array[Vector2i] = [profile.spawn]
	for cp in profile.checkpoints:
		coord_waypoints.append(cp)
	coord_waypoints.append(profile.exit)
	
	current_wave_path.clear()
	for i in range(coord_waypoints.size() - 1):
		var segment = astar.get_id_path(coord_waypoints[i], coord_waypoints[i+1])
		if i > 0 and not segment.is_empty():
			segment.remove_at(0)
		for coord in segment:
			current_wave_path.append(_tile_to_world_position(coord, profile))
			
	get_tree().call_group("enemies", "update_path_mid_run", current_wave_path, _tile_to_world_position)
