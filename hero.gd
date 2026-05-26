extends CharacterBody3D

@export var hero_profile: HeroData

var movement_speed: float = 6.0
var max_mana: float = 100.0
var current_mana: float = 0.0
var mana_regen_rate: float = 1.0

func load_hero_stats(data: HeroData) -> void:
	hero_profile = data
	movement_speed = data.move_speed
	max_mana = data.base_mana
	current_mana = max_mana
	mana_regen_rate = data.mana_regen_rate
	print("Loaded Builder Hero: ", data.hero_name)

func _physics_process(delta: float) -> void:
	if current_mana < max_mana:
		current_mana = min(max_mana, current_mana + (mana_regen_rate * delta))
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * movement_speed
		velocity.z = direction.z * movement_speed
		
		var target_look = global_position + direction
		look_at(target_look, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, movement_speed)
		velocity.z = move_toward(velocity.z, 0, movement_speed)

	move_and_slide()
