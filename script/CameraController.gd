extends Camera2D

@export var follow_speed: float = 5.0  # Camera follow speed
@export var zoom_level: float = 0.8    # Default zoom level (overview, shows more content)
@export var character_zoom: float = 1.5  # Zoom level when following a character
@export var drag_speed: float = 1.0  # Drag movement speed
@export var zoom_speed: float = 0.1  # Mouse wheel zoom speed
@export var min_zoom: float = 0.5  # Minimum zoom level
@export var max_zoom: float = 2.0  # Maximum zoom level

var target: Node2D = null
var original_position: Vector2
var is_dragging: bool = false
var drag_start_position: Vector2
var camera_start_position: Vector2
var manual_position: Vector2  # Position after manual dragging
var is_manual_mode: bool = false  # Whether in manual control mode
var manual_zoom: float = 0.8  # Zoom level in manual mode

func _ready():
		# Set the initial position to the map center (adjust these values for your map size)
		position = Vector2(576, 320)  # This should be your map's center coordinates
		# Save the initial position
		original_position = position
		manual_position = position
		# Set the initial zoom to the overview
		zoom = Vector2(zoom_level, zoom_level)
		make_current()

func _process(delta):
	if is_manual_mode:
		# Manual mode: keep the manually set position and zoom
		position = position.lerp(manual_position, follow_speed * delta)
		zoom = zoom.lerp(Vector2(manual_zoom, manual_zoom), follow_speed * delta)
	elif target:
		# Smoothly follow the target
		position = position.lerp(target.position, follow_speed * delta)
		# Smooth zoom
		zoom = zoom.lerp(Vector2(character_zoom, character_zoom), follow_speed * delta)
	else:
		# If there is no target, return to the original position and zoom
		position = position.lerp(original_position, follow_speed * delta)
		zoom = zoom.lerp(Vector2(zoom_level, zoom_level), follow_speed * delta)

func _input(event):
	# Handle mouse dragging
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# Start dragging
				is_dragging = true
				drag_start_position = event.position
				camera_start_position = position
				# Save the current zoom level
				manual_zoom = zoom.x
			else:
				# End dragging
				is_dragging = false
	
	if event is InputEventMouseMotion and is_dragging:
		# Drag the camera
		var mouse_delta = event.position - drag_start_position
		# Convert screen coordinates to world coordinates (accounting for zoom)
		var world_delta = mouse_delta / zoom.x * drag_speed
		manual_position = camera_start_position - world_delta
		is_manual_mode = true
	
	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in
			zoom_camera(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out
			zoom_camera(-zoom_speed)
	
	# Handle the space key to reset the view
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		restore_view()

func zoom_camera(delta_zoom: float):
	"""Zoom the camera, clamped to the minimum and maximum zoom range"""
	var current_zoom = zoom.x
	var new_zoom = clamp(current_zoom + delta_zoom, min_zoom, max_zoom)
	
	if is_manual_mode:
		# Update manual_zoom in manual mode
		manual_zoom = new_zoom
	elif target:
		# Update character_zoom in character-follow mode
		character_zoom = new_zoom
	else:
		# Update zoom_level in map mode
		zoom_level = new_zoom

func restore_view():
	"""Return to a view centered on the selected character, or center the map if no character is selected"""
	is_manual_mode = false
	if target:
		# Resume following the selected character
		follow_character(target)
	else:
		# Return to the map center
		position = original_position
		zoom = Vector2(zoom_level, zoom_level)

func follow_character(character: Node2D):
	if character:
		target = character
		is_manual_mode = false  # Exit manual mode
	else:
		target = null
