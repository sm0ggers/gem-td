extends CharacterBody3D

@export var target_tolerance: float = 0.1

# --- Movement and Speed Variables ---
@export var base_speed: float = 4.0        
var current_speed: float = base_speed      

# Unified pathfinding tracking arrays
var current_path: Array[Vector3] = []
var path_index: int = 0

# --- Health and Resistances ---
@export var max_health: float = 100.0
var current_health: float = max_health

@export var physical_resistance: float = 0.0
@export var magic_resistance: float = 0.0

# Tracks the state of movement right now (can shift mid-round via status effects)
var current_movement_type: EnemyArchetype.MoveType

func _ready() -> void:
	add_to_group("enemies") 
	current_speed = base_speed

func _physics_process(delta: float) -> void:
	if current_path.is_empty() || path_index >= current_path.size():
		return

	var target_position = current_path[path_index]
	target_position.y = global_position.y 

	var distance_to_target = global_position.distance_to(target_position)

	if distance_to_target <= target_tolerance:
		path_index += 1
		if path_index >= current_path.size():
			on_reach_exit()
			return
	else:
		var direction = (target_position - global_position).normalized()
		velocity = direction * current_speed
		
		if direction.length_squared() > 0.001:
			var target_look = global_position + direction
			look_at(target_look, Vector3.UP)
		
		move_and_slide()

func on_reach_exit() -> void:
	queue_free()

## Called by the WaveManager to inject the map routing coordinates
func set_path(new_path: Array[Vector3]) -> void:
	current_path = new_path
	path_index = 0
	if current_path.size() > 0:
		global_position = current_path[0]
	
	# INITIALIZE STATE HERE: Set the current type to match the profile baseline on spawn
	if get_node_or_null("../WaveManager"):
		var active_wave = $"../WaveManager".current_active_wave
		if active_wave and active_wave.enemy_type:
			current_movement_type = active_wave.enemy_type.movement_type

func take_damage(amount: float, damage_type: String) -> void:
	var final_damage: float = amount
	match damage_type:
		"Physical": final_damage = amount * (1.0 - clamp(physical_resistance, 0.0, 1.0))
		"Magic": final_damage = amount * (1.0 - clamp(magic_resistance, 0.0, 1.0))
		"True": final_damage = amount 
			
	current_health -= final_damage
	print(name, " took ", int(final_damage), " ", damage_type, " damage. HP left: ", int(current_health))
	if current_health <= 0: _on_death()

func _on_death() -> void:
	var score_manager = get_node_or_null("/root/Main/ScoreManager") 
	if score_manager and score_manager.has_method("register_kill"):
		score_manager.register_kill()
	queue_free()

func update_path_mid_run(new_path: Array[Vector3], _transformer: Callable) -> void:
	if new_path.is_empty(): return
	current_path = new_path
	var closest_index: int = 0
	var min_distance: float = 99999.0
	for i in range(current_path.size()):
		var dist = global_position.distance_to(current_path[i])
		if dist < min_distance:
			min_distance = dist
			closest_index = i
	path_index = min(closest_index + 1, current_path.size() - 1)
