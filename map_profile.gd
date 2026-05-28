extends Resource
class_name MapProfile

@export var profile_name: String = "Normal"
@export var width: int = 37
@export var height: int = 37
@export var spawn: Vector2i = Vector2i(4, 4)
@export var checkpoints: Array[Vector2i] = []
@export var exit: Vector2i = Vector2i(32, 32)
