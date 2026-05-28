extends Node3D

# Define the Map Profiles matching classic Dota 2 GemTD parameters
const MAP_PROFILES = {
	"Normal": {
		"width": 37,
		"height": 37,
		"spawn": Vector2i(4, 4),             # Top-Left (4 tiles inward)
		"checkpoints": [
			Vector2i(4, 18),         # CP1: Left side, center height
			Vector2i(32, 18),        # CP2: Right side, center height
			Vector2i(32, 4),         # CP3: Top-Right corner area
			Vector2i(18, 4),         # CP4: Center-Top edge area
			Vector2i(18, 32)         # CP5: Center-Bottom edge area
		],
		"exit": Vector2i(32, 32)             # Bottom-Right (4 tiles inward)   
	},
	"Blitz": {
		"width": 27,
		"height": 27,
		"spawn": Vector2i(13, 2),            # Top-Center (moved 2 tiles down from edge)
		"checkpoints": [
			Vector2i(24, 13),        # Right Checkpoint (moved 2 tiles left)
			Vector2i(2, 13)          # Left Checkpoint (moved 2 tiles right)
		],
		"exit": Vector2i(13, 19)             # Center-Low (7 tiles up from the bottom: 26 - 7 = 19)
	}
}

@export_enum("Normal", "Blitz") var active_profile: String = "Normal"

# Materials for visual debugging
var mat_normal: StandardMaterial3D
var mat_spawn: StandardMaterial3D
var mat_checkpoint: StandardMaterial3D
var mat_exit: StandardMaterial3D

func _ready() -> void:
	_initialize_materials()
	initialize_map(active_profile)

func _initialize_materials() -> void:
	mat_normal = StandardMaterial3D.new()
	mat_normal.albedo_color = Color(0.2, 0.2, 0.2) # Gray
	
	mat_spawn = StandardMaterial3D.new()
	mat_spawn.albedo_color = Color(0.0, 0.8, 0.0) # Green
	
	mat_checkpoint = StandardMaterial3D.new()
	mat_checkpoint.albedo_color = Color(0.0, 0.4, 0.9) # Blue
	
	mat_exit = StandardMaterial3D.new()
	mat_exit.albedo_color = Color(0.8, 0.0, 0.0) # Red

## Clears existing grid tiles and builds a new map based on the profile name
func initialize_map(profile_name: String) -> void:
	if not MAP_PROFILES.has(profile_name):
		push_error("Map profile '" + profile_name + "' does not exist.")
		return
		
	active_profile = profile_name
	_clear_grid()
	
	var config = MAP_PROFILES[profile_name]
	var width: int = config["width"]
	var height: int = config["height"]
	var spawn: Vector2i = config["spawn"]
	var checkpoints: Array = config["checkpoints"]
	var exit: Vector2i = config["exit"]
	
	# Center the grid around the GridManager's origin (optional, but highly recommended for GemTD)
	var offset_x: float = (width - 1) / 2.0
	var offset_z: float = (height - 1) / 2.0
	
	for x in range(width):
		for z in range(height):
			var current_coord = Vector2i(x, z)
			
			# Create the floor tile
			var tile = CSGBox3D.new()
			tile.size = Vector3(0.95, 0.1, 0.95) # Slight gap to see the grid structure clearly
			
			# Assign materials based on coordinate type
			if current_coord == spawn:
				tile.material = mat_spawn
				tile.name = "Tile_Spawn"
			elif current_coord == exit:
				tile.material = mat_exit
				tile.name = "Tile_Exit"
			elif current_coord in checkpoints:
				tile.material = mat_checkpoint
				tile.name = "Tile_Checkpoint_" + str(checkpoints.find(current_coord))
			else:
				tile.material = mat_normal
				tile.name = "Tile_%d_%d" % [x, z]
			
			# Position the tile exactly 1 unit apart
			# In Godot 3D, X is Right/Left and Z is Forward/Back
			tile.position = Vector3(x - offset_x, 0, z - offset_z)
			
			add_child(tile)

func _clear_grid() -> void:
	for child in get_children():
		if child is CSGBox3D:
			child.queue_free()
