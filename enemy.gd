extends CharacterBody3D

@export var target_tolerance: float = 0.1

# --- Movement and Speed Variables ---
@export var base_speed: float = 4.0        # The enemy's normal, default speed
var current_speed: float = base_speed      # The speed they are moving right now (can change if slowed)

var path: Array[Vector3] = []
var current_path_index: int = 0

# --- Health and Resistances ---
@export var max_health: float = 100.0
var current_health: float = max_health

# Resistances represented as decimal percentages (0.10 = 10% damage reduction)
@export var physical_resistance: float = 0.0
@export var magic_resistance: float = 0.0

# Pathfinding tracking array
var current_path: Array[Vector3] = []
var path_index: int = 0

func _ready() -> void:
	add_to_group("enemies") # Just in case it wasn't added by the spawner
	current_speed = base_speed

func _physics_process(delta: float) -> void:
	if path.is_empty() || current_path_index >= path.size():
		return

	var target_position = path[current_path_index]
	# Keep the target on the same height level as the enemy to avoid tilting
	target_position.y = global_position.y 

	var distance_to_target = global_position.distance_to(target_position)

	if distance_to_target <= target_tolerance:
		current_path_index += 1
		if current_path_index >= path.size():
			on_reach_exit()
			return
	else:
		# Calculate direction and move using our dynamic current_speed variable
		var direction = (target_position - global_position).normalized()
		velocity = direction * current_speed
		
		# Smoothly rotate to face the direction of movement
		if direction.length_squared() > 0.001:
			var target_look = global_position + direction
			look_at(target_look, Vector3.UP)
		
		move_and_slide()

func on_reach_exit() -> void:
	# TODO: Deduct player lives/health here via a global singleton or signal
	queue_free()

## Called by the WaveManager to inject the map routing coordinates
func set_path(new_path: Array[Vector3]) -> void:
	current_path = new_path
	path_index = 0
	if current_path.size() > 0:
		global_position = current_path[0]

## Processes incoming damage against specific archetype defenses
func take_damage(amount: float, damage_type: String) -> void:
	var final_damage: float = amount
	
	match damage_type:
		"Physical":
			final_damage = amount * (1.0 - clamp(physical_resistance, 0.0, 1.0))
		"Magic":
			final_damage = amount * (1.0 - clamp(magic_resistance, 0.0, 1.0))
		"True":
			# True damage completely ignores enemy resistance percentages
			final_damage = amount 
			
	current_health -= final_damage
	print(name, " took ", int(final_damage), " ", damage_type, " damage. HP left: ", int(current_health))
	
	if current_health <= 0:
		_on_death()

func _on_death() -> void:
	# Notify ScoreManager of a successful kill before deleting the node
	var score_manager = get_node_or_null("/root/Main/ScoreManager") # Adjust path to your Main scene
	if score_manager and score_manager.has_method("register_kill"):
		score_manager.register_kill()
		
	queue_free()

## Called when layout changes mid-wave
func update_path_mid_run(new_path: Array[Vector3], _transformer: Callable) -> void:
	if current_path.is_empty(): return
	# Simple fallback: find closest node on new path and adapt
	current_path = new_path
	path_index = 0 # Forces re-routing along new maze configuration safely


# =============================================================================
# --- STATUS EFFECTS (Added for Sapphire Slows & Emerald Poison) ---
# =============================================================================

## Drops the enemy's movement speed by a percentage for a limited time
func apply_slow(percentage: float, duration: float) -> void:
	current_speed = base_speed * (1.0 - percentage)
	
	# Wait out the duration using a scene tree timer, then reset back to base speed
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		current_speed = base_speed

## Deals repeated chunks of magic damage over time
func apply_poison(damage_per_tick: int, total_ticks: int) -> void:
	for i in range(total_ticks):
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(self):
			take_damage(damage_per_tick, "Magic") # Poison deals secondary Magic damage
