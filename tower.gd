# tower.gd
extends StaticBody3D

# ... Kept your original GEM_BASE_STATS, TIER_MULTIPLIERS constants ...
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

var tier: String = "Chipped" 
var quality: String = "Ruby" 
var damage: int = 0 
var attack_range: float = 0.0 
var base_attack_speed: float = 1.0 
var actual_attack_speed: float = 1.0 
var damage_types: Dictionary = {}
var proj_type: String = ""

var is_active: bool = false 
var attack_timer: float = 0.0 
var current_target: Node3D = null 

const PROJECTILE_SCENE = preload("res://projectile.tscn")
@onready var range_detector: Area3D = Area3D.new() 
var aura_detector: Area3D = null

## Internal visual container link setup
var visual_mesh_instance: MeshInstance3D

func _ready() -> void:
	_setup_range_detector() 
	
	# Programmatically prepare the baseline visual placeholder container if empty
	visual_mesh_instance = get_node_or_null("Mesh") as MeshInstance3D
	if not visual_mesh_instance:
		visual_mesh_instance = MeshInstance3D.new()
		visual_mesh_instance.name = "Mesh"
		add_child(visual_mesh_instance)

# --- 3. VISUAL PLACEHOLDERS FOR TOWERS AND ROCKS ---
# Replace this function inside your tower.gd script

# --- 3. CORRECTED VISUAL PLACEHOLDERS FOR TOWERS AND ROCKS ---
func initialize_visuals(is_kept: bool, is_rock: bool) -> void:
	if not visual_mesh_instance: return
	
	var gem_data: GemData = get_meta("gem_data") if has_meta("gem_data") else null
	if not gem_data: return
	
	var material = StandardMaterial3D.new()
	
	# STATE A: The round building phase ended and this gem became a permanent Rock Wall barrier
	if is_rock:
		var box = BoxMesh.new()
		box.size = Vector3(0.8, 1.2, 0.8)
		visual_mesh_instance.mesh = box
		material.albedo_color = Color(0.35, 0.35, 0.35) # Solid rock grey
		material.roughness = 0.9
		visual_mesh_instance.material_override = material
		return
		
	# STATE B & C: Advanced Towers or Standard Gems (Visible during placement AND after selection)
	if gem_data.is_advanced_tower:
		# Custom unique shape for advanced combined towers
		var sphere = SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.3
		visual_mesh_instance.mesh = sphere
		material.albedo_color = Color(1.0, 1.0, 1.0) # Sparkling clear white base
		material.emission_enabled = true
		material.emission = Color(0.5, 0.0, 0.5)
	else:
		# Map the randomized Gem Quality to unique geometric shapes immediately!
		match gem_data.quality:
			"Ruby":
				var cyl = CylinderMesh.new()
				cyl.top_radius = 0.0; cyl.bottom_radius = 0.4; cyl.height = 1.0
				visual_mesh_instance.mesh = cyl
			"Diamond":
				var sph = SphereMesh.new()
				sph.radius = 0.4; sph.height = 0.8
				visual_mesh_instance.mesh = sph
			"Sapphire":
				var prism = PrismMesh.new()
				prism.size = Vector3(0.7, 0.9, 0.7)
				visual_mesh_instance.mesh = prism
			"Emerald":
				var box = BoxMesh.new()
				box.size = Vector3(0.6, 0.9, 0.6)
				visual_mesh_instance.mesh = box
			_: # Fallback general capsule shape for Topaz, Amethyst, Aquamarine, Opal
				var cap = CapsuleMesh.new()
				cap.radius = 0.25; cap.height = 0.9
				visual_mesh_instance.mesh = cap
				
		# Color palette mapping matching their Gem Qualities
		var color_map = {
			"Ruby": Color(0.9, 0.1, 0.1),
			"Sapphire": Color(0.1, 0.2, 0.9),
			"Emerald": Color(0.1, 0.8, 0.2),
			"Topaz": Color(0.9, 0.6, 0.1), # Orange-gold Topaz
			"Diamond": Color(0.85, 0.95, 1.0),
			"Amethyst": Color(0.6, 0.1, 0.8),
			"Aquamarine": Color(0.3, 0.8, 0.9),
			"Opal": Color(0.8, 0.7, 0.6)
		}
		
		var target_color = color_map.get(gem_data.quality, Color(1, 1, 1))
		
		# Set transparency rules based on whether they are finalized or just placement pool gems
		var alpha_val = 1.0
		if not is_kept:
			# If it's an undecided round choice, make it ghosted/semi-transparent (40% opacity)
			alpha_val = 0.40
		else:
			# If chosen/kept, set opacity scaling based purely on its upgraded Tier level
			match gem_data.tier:
				"Chipped": alpha_val = 0.6
				"Flawed": alpha_val = 0.7
				"Normal": alpha_val = 0.8
				"Flawless": alpha_val = 0.9
				"Perfect": alpha_val = 1.0
			
		material.albedo_color = Color(target_color.r, target_color.g, target_color.b, alpha_val)
		material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA if alpha_val < 1.0 else StandardMaterial3D.TRANSPARENCY_DISABLED
		material.roughness = 0.15
		material.metallic = 0.2
		
	visual_mesh_instance.material_override = material

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

	if quality == "Opal":
		_setup_opal_aura()

# ... Kept your original attack loops, projectiles, and Opal Aura routines exactly intact ...
func recalculate_attack_speed() -> void:
	var speed_buff = 1.0
	if has_meta("opal_buff"): speed_buff = get_meta("opal_buff")
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
	var proj = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(0, 1.5, 0)
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

func _setup_opal_aura() -> void:
	if aura_detector != null: return
	aura_detector = Area3D.new()
	var col_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	var aura_radius = 6.0 if tier == "Perfect" else 4.0
	sphere.radius = aura_radius
	col_shape.shape = sphere
	aura_detector.add_child(col_shape)
	add_child(aura_detector)
	aura_detector.body_entered.connect(_on_tower_entered_aura)
	aura_detector.body_exited.connect(_on_tower_exited_aura)

func _on_tower_entered_aura(body: Node3D) -> void:
	if body != self and body.has_method("recalculate_attack_speed"):
		var buff_value = 0.70 if tier == "Perfect" else 0.85
		body.set_meta("opal_buff", buff_value)
		body.recalculate_attack_speed()

func _on_tower_exited_aura(body: Node3D) -> void:
	if body.has_meta("opal_buff"):
		body.remove_meta("opal_buff")
		if body.has_method("recalculate_attack_speed"):
			body.recalculate_attack_speed()
