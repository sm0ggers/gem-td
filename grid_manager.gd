extends Node3D

# 1. Change this from a String enum to a MapProfile object slot!
@export var active_profile: MapProfile

# Materials for visual debugging
var mat_normal: StandardMaterial3D
var mat_spawn: StandardMaterial3D
var mat_checkpoint: StandardMaterial3D
var mat_exit: StandardMaterial3D

func _ready() -> void:
	_initialize_materials()
	
	# 2. Add a quick safety check so it only auto-runs if a file is attached
	if active_profile != null:
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
## Clears existing grid tiles and builds a new map based on the passed profile resource
func initialize_map(profile: MapProfile) -> void:
	# 1. Safety check to make sure a valid data file was actually passed in
	if profile == null:
		push_error("Cannot initialize map: Profile data is null.")
		return
		
	# 2. Track the active profile name (matches your old code's logic)
	active_profile = profile
	_clear_grid()
	
	# 3. Read variables directly from the custom resource object instead of a dictionary
	var width: int = profile.width
	var height: int = profile.height
	var spawn: Vector2i = profile.spawn
	var checkpoints: Array[Vector2i] = profile.checkpoints
	var exit: Vector2i = profile.exit
	
	# 4. Center the grid around the GridManager's origin
	var offset_x: float = (width - 1) / 2.0
	var offset_z: float = (height - 1) / 2.0
	
	# --- The rest of your loop below remains 100% untouched and original! ---
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
			tile.position = Vector3(x - offset_x, 0, z - offset_z)
			
			add_child(tile)

func _clear_grid() -> void:
	for child in get_children():
		if child is CSGBox3D:
			child.queue_free()
