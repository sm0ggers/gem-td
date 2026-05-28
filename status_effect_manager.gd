extends Node
class_name StatusEffectManager

# We get a reference to whatever character this component is attached to
@onready var parent_unit = get_parent()

func _ready() -> void:
	# Safety check to make sure it's attached to an enemy or character
	if not parent_unit or not "current_speed" in parent_unit:
		push_warning("StatusEffectManager: Parent node does not have movement variables!")

## Drops the parent's movement speed by a percentage for a limited time
func apply_slow(percentage: float, duration: float) -> void:
	if not is_instance_valid(parent_unit): return
	
	# Alter the parent's speed directly
	parent_unit.current_speed = parent_unit.base_speed * (1.0 - percentage)
	print(parent_unit.name, " was slowed by ", percentage * 100, "%")
	
	# Wait out the duration inside this component
	await get_tree().create_timer(duration).timeout
	
	# Safely return parent back to normal base speed
	if is_instance_valid(parent_unit):
		parent_unit.current_speed = parent_unit.base_speed
		print(parent_unit.name, " slow expired.")

## Deals repeated chunks of magic damage over time
func apply_poison(damage_per_tick: int, total_ticks: int, tick_interval: float = 1.0) -> void:
	for i in range(total_ticks):
		await get_tree().create_timer(tick_interval).timeout
		
		if is_instance_valid(parent_unit) and parent_unit.has_method("take_damage"):
			parent_unit.take_damage(damage_per_tick, "Magic")
		else:
			break # Stop ticking if the enemy dies mid-run

## Pulls a floating or flying enemy kicking and screaming down to the ground plane
func apply_grounded(duration: float) -> void:
	if not is_instance_valid(parent_unit) or not "current_movement_type" in parent_unit: 
		return
	
	# 1. Save whatever their original movement type was so we don't forget it
	var original_type = parent_unit.current_movement_type
	
	# If they are already grounded, don't do anything extra
	if original_type == EnemyArchetype.MoveType.GROUND:
		return
		
	# 2. Crash land! Force their active state to GROUND
	parent_unit.current_movement_type = EnemyArchetype.MoveType.GROUND
	print(parent_unit.name, " has been GROUNDED! They can now take hazard damage.")
	
	# Optional: If it's a flying unit high in the air, snap their visual height down to the ground
	var original_y = parent_unit.global_position.y
	parent_unit.global_position.y = 0.05 # Match the floor height matrix
	
	# 3. Wait out the trap/net duration
	await get_tree().create_timer(duration).timeout
	
	# 4. Release the unit! Revert them back to their original type if they are still alive
	if is_instance_valid(parent_unit):
		parent_unit.current_movement_type = original_type
		parent_unit.global_position.y = original_y # Float/Fly back up into the air visuals
		print(parent_unit.name, " broke free and is airborne again.")
