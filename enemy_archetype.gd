extends Resource
class_name EnemyArchetype

# This creates a drop-down list choice in the Inspector panel
enum MoveType { GROUND, FLOATING, FLYING }

@export var type_name: String = "Normal"
@export var movement_type: MoveType = MoveType.GROUND  # Sets GROUND as the starting option

@export var base_health: float = 100.0
@export var base_speed: float = 4.0

# Decimal percentages (e.g., 0.15 means 15% damage reduction)
@export_range(0.0, 1.0) var physical_resistance: float = 0.0
@export_range(0.0, 1.0) var magic_resistance: float = 0.0

@export var display_color: Color = Color.WHITE
