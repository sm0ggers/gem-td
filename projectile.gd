extends Node3D

var target: Node3D = null
var source_tower: Node3D = null

var speed: float = 15.0
var damage: int = 0
var damage_types: Dictionary = {}
var proj_type: String = ""
var tier: String = ""

# Trackers for bouncing mechanics
var bounced_targets: Array[Node3D] = []
var bounces_left: int = 0

# For the linear piercing spear (Diamond)
var is_linear_projectile: bool = false
var linear_direction: Vector3 = Vector3.ZERO
var pierced_enemies: Array[Node3D] = []
var lifetime: float = 2.0

func launch(new_target: Node3D, tower: Node3D) -> void:
	target = new_target
	source_tower = tower
	damage = tower.damage
	damage_types = tower.damage_types
	proj_type = tower.proj_type
	tier = tower.tier
	
	# Configure specific projectile modifications based on tier adjustments
	if proj_type == "Amethyst":
		bounces_left = 2 if tier == "Perfect" else 1 # Tier 5 gets 2 bounces instead of 1!
		bounced_targets.append(target)
		
	if proj_type == "Diamond":
		is_linear_projectile = true
		# Calculate vector path coordinates along the floor plan (Y-axis neutralized)
		var origin = global_position
		var destination = target.global_position
		linear_direction = (destination - origin).normalized()
		linear_direction.y = 0 # Ensures the spear flies level horizontally
		
		# Rotate projectile mesh toward target heading direction
		look_at(global_position + linear_direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	if is_linear_projectile:
		_process_linear_movement(delta)
	else:
		_process_homing_movement(delta)

func _process_homing_movement(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free() # Clears out smoothly if enemy vaporizes mid-flight
		return
		
	# Fly directly toward target center frame coordinates
	var target_pos = target.global_position + Vector3(0, 0.5, 0)
	global_position = global_position.move_toward(target_pos, speed * delta)
	
	if global_position.distance_to(target_pos) < 0.2:
		_impact_target(target)

func _process_linear_movement(delta: float) -> void:
	# Advance straight forward through spatial coordinates
	global_position += linear_direction * speed * delta
	
	# Trace collisions against enemy 3D hitboxes manually along our line path
	_check_linear_collisions()
	
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _check_linear_collisions() -> void:
	# Scan for objects in the level scene space hierarchy
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not pierced_enemies.has(enemy):
			# Measure spatial proximity to verify a hit
			var dist = global_position.distance_to(enemy.global_position)
			if dist < 1.5: # Hitbox collision tolerance radius
				pierced_enemies.append(enemy)
				_deal_damage_pool(enemy, damage)

func _impact_target(hit_enemy: Node3D) -> void:
	# Handle standard baseline damage delivery maps
	if proj_type != "Diamond":
		_deal_damage_pool(hit_enemy, damage)
		
	# Apply unique custom elemental payloads 
	match proj_type:
		"Sapphire":
			if hit_enemy.has_method("apply_slow"):
				# Tier 5 Perfect Sapphire bumps slowing effect to 50%; lower tiers use 30%
				var slow_percentage = 0.50 if tier == "Perfect" else 0.30
				hit_enemy.apply_slow(slow_percentage, 2.0)
				
		"Ruby":
			# Triggers a secondary explosion damage perimeter around target point coordinates
			var splash_radius = 3.5 if tier == "Perfect" else 2.0
			_trigger_splash_damage(hit_enemy.global_position, splash_radius)
			
		"Emerald":
			if hit_enemy.has_method("apply_poison"):
				# Tier 5 passes a scaled poison dot tick load 
				var poison_tick = int(damage * 0.50) if tier == "Perfect" else int(damage * 0.25)
				hit_enemy.apply_poison(poison_tick, 4)
				
		"Topaz":
			# Split fire targeting arrays out to extra targets instantly
			_trigger_topaz_chain(hit_enemy)
			
		"Amethyst":
			if bounces_left > 0:
				_find_next_bounce_target()
				return # Don't destroy projectile yet, it needs to fly to next target!

	# Delete projectile on impact unless it's waiting to complete an Amethyst bounce
	if proj_type != "Amethyst":
		queue_free()

func _deal_damage_pool(enemy: Node3D, total_dmg: int) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"): return
	
	# Distribute split elemental components safely
	for dmg_type in damage_types.keys():
		var percentage = damage_types[dmg_type]
		var distributed_amount = int(total_dmg * percentage)
		enemy.take_damage(distributed_amount, dmg_type)

# --- Elemental Traits Implementations ---

func _trigger_splash_damage(center_point: Vector3, radius: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			# Let's ensure our ground effects check doesn't hit flying units!
			if enemy.has_meta("is_flying"):
				continue # Skips running splash processing on air units entirely!
				
			if center_point.distance_to(enemy.global_position) <= radius:
				_deal_damage_pool(enemy, damage)

func _trigger_topaz_chain(primary_enemy: Node3D) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		if hit_count >= 2: break
		if is_instance_valid(enemy) and enemy != primary_enemy:
			# Only jump to enemies that are relatively near the target explosion point
			if primary_enemy.global_position.distance_to(enemy.global_position) <= 4.0:
				_deal_damage_pool(enemy, damage)
				hit_count += 1

func _find_next_bounce_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var next_target: Node3D = null
	var closest_dist = 999.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or bounced_targets.has(enemy): continue
		
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist and dist <= 6.0:
			closest_dist = dist
			next_target = enemy
			
	if next_target != null:
		bounces_left -= 1
		bounced_targets.append(next_target)
		target = next_target # Update homing focus over to new bouncing track element!
	else:
		queue_free() # No valid secondary targets in area, clean up frame structure
