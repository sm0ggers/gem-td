extends Node3D

@export_category("Movement Limits")
@export var min_zoom: float = 10.0
@export var max_zoom: float = 50.0
@export var pan_speed_pc: float = 0.05
@export var pan_speed_mobile: float = 0.02
@export var pan_speed_trackpad: float = 0.5
@export var zoom_speed_pc: float = 2.0
@export var zoom_speed_trackpad: float = 15.0

@export_category("Tilt Settings")
@export var min_tilt: float = -80.0  # Look almost straight down (in degrees)
@export var max_tilt: float = -20.0  # Look closer to the horizon (in degrees)
@export var tilt_speed_pc: float = 0.1
@export var tilt_speed_trackpad: float = 0.5

# Node References
@onready var hinge: Node3D = $CameraHinge
@onready var camera: Camera3D = $CameraHinge/Camera3D

# Tracking Variables for Input
var target_zoom: float = 25.0
var zoom_smoothing: float = 10.0

# Target tilt rotation in radians
var target_tilt: float = 0.0
var tilt_smoothing: float = 10.0

# Track active touch events for mobile gestures
var touch_events: Dictionary = {}
var initial_pinch_distance: float = 0.0
var initial_pinch_zoom: float = 25.0

func _ready() -> void:
	target_zoom = camera.position.z
	# Initialize target tilt to whatever the hinge is currently set to
	target_tilt = hinge.rotation.x

func _process(delta: float) -> void:
	# Smoothly interpolate zoom
	camera.position.z = max(min_zoom, min(max_zoom, lerp(camera.position.z, target_zoom, zoom_smoothing * delta)))
	
	# Smoothly interpolate tilt (rotation around the X axis)
	hinge.rotation.x = lerp(hinge.rotation.x, target_tilt, tilt_smoothing * delta)

func _unhandled_input(event: InputEvent) -> void:
	# --- 💻 LAPTOP TRACKPAD GESTURES ---
	
	if event is InputEventPanGesture:
		# MAC SHORTCUT: Hold SHIFT + two-finger scroll to TILT the camera
		if Input.is_key_pressed(KEY_SHIFT):
			_tilt_camera(event.delta.y * tilt_speed_trackpad)
		else:
			_pan_camera(event.delta * pan_speed_trackpad)
		return
		
	if event is InputEventMagnifyGesture:
		var zoom_delta = (event.factor - 1.0) * zoom_speed_trackpad
		target_zoom -= zoom_delta
		return

	# --- 🖥️ PC MOUSE & KEYBOARD INPUT ---
	
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_zoom -= zoom_speed_pc
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_zoom += zoom_speed_pc
				
	if event is InputEventMouseMotion:
		# PC SHORTCUT: Hold SHIFT + Middle-Click Drag to TILT
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and Input.is_key_pressed(KEY_SHIFT):
			_tilt_camera(-event.relative.y * tilt_speed_pc)
		# Regular Middle-Click Drag to PAN
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			_pan_camera(-event.relative * pan_speed_pc)

	# --- 📱 MOBILE TOUCH GESTURES ---
	
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_events[event.index] = event
		else:
			touch_events.erase(event.index)
		if touch_events.size() < 2:
			initial_pinch_distance = 0.0

	if event is InputEventScreenDrag:
		touch_events[event.index] = event
		
		if touch_events.size() == 1:
			_pan_camera(-event.relative * pan_speed_mobile)
			
		elif touch_events.size() == 2:
			# (Optional) You can implement a two-finger vertical swipe for mobile tilt here, 
			# but leaving your working pinch code untouched for now.
			var touches = touch_events.values()
			var current_dist = touches[0].position.distance_to(touches[1].position)
			
			if initial_pinch_distance == 0.0:
				initial_pinch_distance = current_dist
				initial_pinch_zoom = target_zoom
			else:
				var pinch_factor = current_dist / initial_pinch_distance
				target_zoom = initial_pinch_zoom / pinch_factor

## Rotates the CameraHinge on the local X axis to look up or down
func _tilt_camera(amount: float) -> void:
	# Convert degrees limits to radians because Godot's rotation properties use radians internally
	var min_rad = deg_to_rad(min_tilt)
	var max_rad = deg_to_rad(max_tilt)
	
	# Adjust target tilt and clamp it within limits
	target_tilt += deg_to_rad(amount)
	target_tilt = clamp(target_tilt, min_rad, max_rad)

## Moves the rig across the global 3D horizontal X/Z plane
func _pan_camera(relative_motion: Vector2) -> void:
	var forward = global_transform.basis.z
	var right = global_transform.basis.x
	
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	global_position += right * relative_motion.x + forward * relative_motion.y
