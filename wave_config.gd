extends Resource
class_name WaveConfig

@export var wave_title: String = "Wave 1"
@export var enemy_type: EnemyArchetype  # Links directly to our archetype resource!
@export var enemy_count: int = 10
@export var spawn_interval: float = 1.0
