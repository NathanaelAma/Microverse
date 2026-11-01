extends Node

var current_character: CharacterBody2D = null
var dialog_manager: Node
const DIALOG_DISTANCE = 100.0  # Distance threshold for triggering a conversation

# GodUI reference
var god_ui: Control = null

func _ready():
	dialog_manager = get_node("/root/DialogManager")  # Get the dialog manager reference
	# Get all controllable characters
	for character in get_tree().get_nodes_in_group("controllable_characters"):
		character.set_selected(false)
	
	# Defer getting the GodUI reference until the scene is fully loaded
	call_deferred("_init_godui_reference")

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Convert screen coordinates to global coordinates
		var camera = get_viewport().get_camera_2d()
		var click_position = event.position
		if camera:
			click_position = get_viewport().get_canvas_transform().affine_inverse() * click_position
			
		var clicked_character = get_clicked_character(click_position)
		var clicked_chair = get_clicked_chair(click_position)
		
		if clicked_character:
			select_character(clicked_character)
		elif clicked_chair and current_character:
			# A chair was clicked: move the current character to it and sit down automatically
			if current_character.has_method("move_to_chair"):
				if current_character.move_to_chair(clicked_chair):
					print("[CharacterManager] %s started moving to chair %s" % [current_character.name, clicked_chair.name])
				else:
					print("[CharacterManager] %s cannot move to chair %s (it may be occupied)" % [current_character.name, clicked_chair.name])
			else:
				# Backward compatibility: move directly to the chair's position
				current_character.move_to(clicked_chair.global_position)
		elif current_character:
			current_character.move_to(click_position)

func get_clicked_character(click_position):
	var space = get_tree().root.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = click_position
	query.collision_mask = 1  # Set the appropriate collision layer
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space.intersect_point(query)
	for collision in result:
		var collider = collision.collider
		if collider.is_in_group("controllable_characters"):
			return collider
	return null

# Get the chair at the clicked position
func get_clicked_chair(click_position):
	# Get all chairs in the scene
	var chairs = get_tree().get_nodes_in_group("chairs")
	for chair in chairs:
		if chair.has_method("is_clicked_on") and chair.is_clicked_on(click_position):
			return chair
	return null

# Get another character near the given character
func get_nearby_character(character: CharacterBody2D) -> CharacterBody2D:
	for other in get_tree().get_nodes_in_group("controllable_characters"):
		if other != character:
			var distance = character.global_position.distance_to(other.global_position)
			if distance <= DIALOG_DISTANCE:
				return other
	return null

func select_character(character: CharacterBody2D):
	# If the clicked character is the currently selected one, deselect it and return to the overview
	if character == current_character:
		current_character.set_selected(false)
		current_character = null
		
		# Return the camera to the overview
		var camera = get_viewport().get_camera_2d()
		if camera and camera.has_method("follow_character"):
			camera.follow_character(null)
		
		# Sync the GodUI left sidebar (deselect)
		_sync_godui_selection(null)
		return
	
	# Select the new character
	if current_character:
		current_character.set_selected(false)
	
	current_character = character
	current_character.set_selected(true)
	
	# Camera follows the newly selected character
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("follow_character"):
		camera.follow_character(character)
	
	# Sync the GodUI left sidebar
	_sync_godui_selection(character)

# Initialize the GodUI reference
func _init_godui_reference():
	# Try to find the GodUI node in the scene tree
	god_ui = get_tree().get_first_node_in_group("godui")
	if not god_ui:
		# If not found by group, try finding it by path
		var canvas_layer = get_tree().get_first_node_in_group("canvas_layer")
		if canvas_layer:
			god_ui = canvas_layer.get_node_or_null("GodUI")
		else:
			# Finally, try finding it directly from the root node
			var office_scene = get_tree().current_scene
			if office_scene:
				var canvas_layers = office_scene.find_children("*", "CanvasLayer")
				for layer in canvas_layers:
					var ui = layer.get_node_or_null("GodUI")
					if ui:
						god_ui = ui
						break
	
	if god_ui:
		print("[CharacterManager] Found the GodUI node")
	else:
		print("[CharacterManager] Warning: GodUI node not found")

# Sync GodUI's character selection
func _sync_godui_selection(character: CharacterBody2D):
	if not god_ui:
		return
	
	# Get the list of all controllable characters
	var all_characters = get_tree().get_nodes_in_group("controllable_characters")
	
	if character == null:
		# Deselect and clear GodUI's selection
		if god_ui.has_method("clear_character_selection"):
			god_ui.clear_character_selection()
		else:
			# If there's no dedicated clear method, set selected_character to null and update the details
			god_ui.selected_character = null
			if god_ui.has_method("_update_character_detail"):
				god_ui._update_character_detail()
	else:
		# Select a character and sync it to GodUI
		var character_index = all_characters.find(character)
		if character_index >= 0:
			# Update GodUI's selected character
			god_ui.selected_character = character
			# Update the character list selection state
			if god_ui.character_list and god_ui.character_list.has_method("select"):
				god_ui.character_list.select(character_index)
			# Update the character detail display
			if god_ui.has_method("_update_character_detail"):
				god_ui._update_character_detail()
