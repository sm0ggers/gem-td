extends StaticBody3D

# Base stats updated with Damage Types and custom projectile identifiers
const GEM_BASE_STATS = {
	"Ruby": {"damage": 25, "range": 4.0, "attack_speed": 1.5, "damage_types": {"Physical": 0.5, "Magic": 0.5}, "proj_type": "Ruby"},
	"Sapphire": {"damage": 12, "range": 5.0, "attack_speed": 1.0, "damage_types": {"Magic": 1.0}, "proj_type": "Sapphire"},
	"Emerald": {"damage": 18, "range": 4.5, "attack_speed": 1.2, "damage_types": {"Physical": 1.0}, "proj_type": "Emerald"},
	"Topaz": {"damage": 30, "range": 3.5, "attack_speed": 1.8, "damage_types": {"Physical": 1.0}, "proj_type": "Topaz"},
	"Diamond": {"damage": 20, "range": 6.0, "attack_speed": 1.1, "damage_types": {"True": 1.0}, "proj_type": "Diamond"},
	"Amethyst": {"damage": 15, "range": 6.5, "attack_speed": 0.8, "damage_types": {"Physical": 1.0}, "proj_type": "Amethyst"},
	"Aquamarine": {"damage": 22, "range": 5.0, "attack_speed": 0.5, "damage_types": {"Physical": 1.0}, "proj_type": "Aquamarine"},
	"Opal": {"damage": 10, "range": 4.0, "attack_speed": 0.5, "damage_types": {"Magic": 1.0}, "proj_type": "Opal"}
}

const TIER_MULTIPLIERS = {
	"Chipped": 1.0, "Flawed": 1.5, "Normal": 2.2, "Flawless": 3.5, "Perfect": 5.0
}

# Runtime variables 
var tier: String = "Chipped" 
var quality: String = "Ruby" 
var damage: int = 0 
var attack_range: float = 0.0 
var base_attack_speed: float = 1.0 
var actual_attack_speed: float = 1.0 # Factoring in aura buffs
var damage_types: Dictionary = {}
var proj_type: String = ""

var is_active: bool = false 
var attack_timer: float = 0.0 
var current_target: Node3D = null 

# Preload your projectile base scene (we'll make this next!)
const PROJECTILE_SCENE = preload("res://projectile.tscn")

@onready var range_detector: Area3D = Area3D.new() 
var aura_detector: Area3D = null

func _ready() -> void:
	_setup_range_detector() 

func initialize_gem(assigned_tier: String, assigned_quality: String) -> void:
	tier = assigned_tier 
	quality = assigned_quality 
	
	var base = GEM_BASE_STATS[quality] 
	var mult = TIER_MULTIPLIERS[tier] 
	
	damage = int(base["damage"] * mult) 
	attack_range = base["range"] 
	base_attack_speed = base["attack_speed"] 
	damage_types = base["damage_types"]
	proj_type = base["proj_type"]
	
	recalculate_attack_speed()
	
	var collision_shape = range_detector.get_child(0) as CollisionShape3D 
	if collision_shape and collision_shape.shape is SphereShape3D: 
		collision_shape.shape.radius = attack_range 

	# If this is an Opal, give it its passive speed aura
	if quality == "Opal":
		_setup_opal_aura()

func recalculate_attack_speed() -> void:
	# Scan for nearby Opal aura instances affecting this tower
	var speed_buff = 1.0
	if has_meta("opal_buff"):
		speed_buff = get_meta("opal_buff") # E.g., 0.85 means 15% faster intervals
	
	actual_attack_speed = base_attack_speed * speed_buff

func activate_tower() -> void:
	is_active = true 

func _setup_range_detector() -> void:
	var col_shape = CollisionShape3D.new() 
	var sphere = SphereShape3D.new() 
	sphere.radius = 1.0 
	col_shape.shape = sphere 
	range_detector.add_child(col_shape) 
	add_child(range_detector) 

func _physics_process(delta: float) -> void:
	if not is_active: return 
	
	if current_target == null or not is_instance_valid(current_target): 
		current_target = _find_next_target() 
		return
		
	if global_position.distance_to(current_target.global_position) > attack_range: 
		current_target = null 
		return
		
	attack_timer += delta 
	if attack_timer >= actual_attack_speed: 
		attack_timer = 0.0 
		_fire_projectile()

func _fire_projectile() -> void:
	if current_target == null or not is_instance_valid(current_target): return
	
	# Create the visual/logical projectile
	var proj = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	
	# Spawn at the peak height of the tower
	proj.global_position = global_position + Vector3(0, 1.5, 0)
	
	# Hand over the specs directly to the projectile script
	proj.launch(current_target, self)

func _find_next_target() -> Node3D: 
	var targets = _get_all_targets_in_range()
	return targets[0] if targets.size() > 0 else null

func _get_all_targets_in_range() -> Array[Node3D]:
	var list: Array[Node3D] = []
	var bodies = range_detector.get_overlapping_areas() 
	for body in bodies: 
		if body.name == "Hitbox" and is_instance_valid(body.get_parent()): 
			list.append(body.get_parent())
	return list

# --- Opal Specific Aura System ---
func _setup_opal_aura() -> void:
	if aura_detector != null: return
	
	aura_detector = Area3D.new()
	var col_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	
	# Opal aura expands based on its tier
	var aura_radius = 6.0 if tier == "Perfect" else 4.0
	sphere.radius = aura_radius
	col_shape.shape = sphere
	aura_detector.add_child(col_shape)
	add_child(aura_detector)
	
	aura_detector.body_entered.connect(_on_tower_entered_aura)
	aura_detector.body_exited.connect(_on_tower_exited_aura)

func _on_tower_entered_aura(body: Node3D) -> void:
	if body != self and body.has_method("recalculate_attack_speed"):
		# Perfect Opal cuts attack delays by 30% (0.7); lower tiers cut by 15% (0.85)
		var buff_value = 0.70 if tier == "Perfect" else 0.85
		body.set_meta("opal_buff", buff_value)
		body.recalculate_attack_speed()

func _on_tower_exited_aura(body: Node3D) -> void:
	if body.has_meta("opal_buff"):
		body.remove_meta("opal_buff")
		if body.has_method("recalculate_attack_speed"):
			body.recalculate_attack_speed()
