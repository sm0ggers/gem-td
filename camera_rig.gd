extends Node3D

@export_category("Movement Limits")
@export var min_zoom: float = 10.0
@export var max_zoom: float = 50.0
@export var pan_speed_pc: float = 0.05
@export var pan_speed_mobile: float = 0.02
@export var zoom_speed_pc: float = 2.0

# Node References
@onready var hinge: Node3D = $CameraHinge
@onready var camera: Camera3D = $CameraHinge/Camera3D

# Tracking Variables for Input
var target_zoom: float = 25.0
var zoom_smoothing: float = 10.0

# Track active touch events for mobile gestures
var touch_events: Dictionary = {}
var initial_pinch_distance: float = 0.0
var initial_pinch_zoom: float = 25.0

func _ready() -> void:
	target_zoom = camera.position.z

func _process(delta: float) -> void:
	# Smoothly interpolate the camera position to match target zoom
	camera.position.z = max(min_zoom, min(max_zoom, lerp(camera.position.z, target_zoom, zoom_smoothing * delta)))

func _unhandled_input(event: InputEvent) -> void:
	# --- 🖥️ PC MOUSE & KEYBOARD INPUT ---
	
	# Mouse Wheel Zooming
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_zoom -= zoom_speed_pc
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_zoom += zoom_speed_pc
				
	# Middle-Click Drag Panning (or Right-Click if preferred)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_pan_camera(-event.relative * pan_speed_pc)

	# --- 📱 MOBILE TOUCH GESTURES ---
	
	# Handle Screen Touches
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_events[event.index] = event
		else:
			touch_events.erase(event.index)
			
		# Reset pinch data when fingers leave the screen
		if touch_events.size() < 2:
			initial_pinch_distance = 0.0

	# Handle Screen Dragging / Pinch-to-Zoom
	if event is InputEventScreenDrag:
		touch_events[event.index] = event # Update touch position
		
		if touch_events.size() == 1:
			# Single-finger drag: Pan the map around
			_pan_camera(-event.relative * pan_speed_mobile)
			
		elif touch_events.size() == 2:
			# Two-finger touch: Calculate pinch distance to zoom
			var touches = touch_events.values()
			var current_dist = touches[0].position.distance_to(touches[1].position)
			
			if initial_pinch_distance == 0.0:
				initial_pinch_distance = current_dist
				initial_pinch_zoom = target_zoom
			else:
				# Scale factor based on finger pinch distance
				var pinch_factor = current_dist / initial_pinch_distance
				# Invert pinch factor: pinching open makes target_zoom smaller (closer)
				target_zoom = initial_pinch_zoom / pinch_factor

## Moves the rig across the global 3D horizontal X/Z plane
func _pan_camera(relative_motion: Vector2) -> void:
	# Get forward and right directions relative to the rig's current rotation
	var forward = global_transform.basis.z
	var right = global_transform.basis.x
	
	# Zero out the Y axis so panning stays flat on the floor grid
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	# Translate the rig position across the ground
	global_position += right * relative_motion.x + forward * relative_motion.y
