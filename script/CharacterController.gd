extends CharacterBody2D

@export var speed = 100.0
var target_position = Vector2.ZERO
var is_selected = false
var is_sitting = false
var facing_direction = "down"  # New: tracks which way the character is facing
var navigation_path: Array = []
var path_index = 0
var near_chair = null  # New: chair the character is currently near
var current_chair = null  # New: chair the character is currently sitting on
var target_chair = null  # New: target chair (for auto-sitting)
var auto_sit_enabled = false  # New: whether auto-sit is enabled

# AI agent system
var ai_agent: AIAgent

# Obstacle avoidance variables
var stuck_timer = 0.0
var last_position = Vector2.ZERO
var stuck_threshold = 2.0  # Stuck detection time (reduced)
var avoidance_force = Vector2.ZERO
var avoidance_timer = 0.0
var recalculate_count = 0  # Number of path recalculations
var max_recalculate_attempts = 3  # Maximum retry count
var last_avoidance_direction = Vector2.ZERO  # Last avoidance direction
var direction_stability_timer = 0.0  # Direction stability timer

func _ready():
	add_to_group("controllable_characters")
	
	# Create the ChatHistory node
	if not has_node("ChatHistory"):
		var chat_history_scene = load("res://scene/ChatHistory.tscn")
		var chat_history = chat_history_scene.instantiate()
		add_child(chat_history)
	
	# Create the AI agent
	ai_agent = AIAgent.new()
	add_child(ai_agent)
	
	# Create the AI model display label
	create_ai_model_label()
	
	# Set the initial animation
	$AnimatedSprite2D.play("idle_" + facing_direction)

func set_selected(selected: bool):
	is_selected = selected
	# Toggle the AI agent's control state
	ai_agent.toggle_player_control(selected)
	# A selection effect could be added here, e.g. a halo or color change

func move_to(target: Vector2):
	if is_sitting:
		return
		
	# Only reset the target chair state when not in auto-sit mode
	if not auto_sit_enabled:
		target_chair = null
	
	# Compute the path with the navigation system
	var navigation_map = get_world_2d().navigation_map
	
	# Set pathfinding parameters
	var path_params = NavigationPathQueryParameters2D.new()
	path_params.map = navigation_map
	path_params.start_position = global_position
	path_params.target_position = target
	path_params.path_postprocessing = NavigationPathQueryParameters2D.PATH_POSTPROCESSING_CORRIDORFUNNEL # Use the funnel algorithm to optimize the path
	# Note: PATH_SIMPLIFICATION_EDGECENTERED is not available in the current Godot version
	
	# Get the path
	var path_result = NavigationPathQueryResult2D.new()
	NavigationServer2D.query_path(path_params, path_result)
	navigation_path = path_result.path
	
	# If navigation fails, try moving directly
	if navigation_path.is_empty():
		navigation_path = [global_position, target]
	
	# Print debug info
	print("Path point count: ", navigation_path.size())
	print("Start: ", global_position)
	print("End: ", target)
	
	path_index = 0
	target_position = target
	# Reset obstacle avoidance variables
	stuck_timer = 0.0
	last_position = global_position
	avoidance_force = Vector2.ZERO
	avoidance_timer = 0.0
	recalculate_count = 0  # Reset retry count

# Improved avoidance direction calculation - reduces oscillation
func _calculate_avoidance_direction(desired_direction: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var final_direction = desired_direction
	
	# Detect obstacles ahead
	var detection_distance = 35.0
	var front_query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + desired_direction * detection_distance
	)
	front_query.exclude = [self]
	front_query.collision_mask = 1
	
	var front_result = space_state.intersect_ray(front_query)
	
	# If there is an obstacle ahead
	if front_result:
		var obstacle_distance = global_position.distance_to(front_result.position)
		
		# Only avoid when very close
		if obstacle_distance < 30.0:
			# Compute the avoidance direction - using a more stable method
			var obstacle_normal = front_result.normal
			var avoidance_direction = Vector2.ZERO
			
			# Prefer the previous avoidance direction for stability
			if direction_stability_timer > 0 and last_avoidance_direction != Vector2.ZERO:
				avoidance_direction = last_avoidance_direction
				direction_stability_timer -= get_physics_process_delta_time()
			else:
				# Compute a new avoidance direction
				var left_direction = desired_direction.rotated(deg_to_rad(-90))
				var right_direction = desired_direction.rotated(deg_to_rad(90))
				
				# Check whether left and right are clear
				var left_clear = _is_direction_clear(left_direction, 25.0)
				var right_clear = _is_direction_clear(right_direction, 25.0)
				
				if left_clear and not right_clear:
					avoidance_direction = left_direction
				elif right_clear and not left_clear:
					avoidance_direction = right_direction
				elif left_clear and right_clear:
					# Both sides clear: choose the direction closer to the target
					var target_dir = (target_position - global_position).normalized()
					if left_direction.dot(target_dir) > right_direction.dot(target_dir):
						avoidance_direction = left_direction
					else:
						avoidance_direction = right_direction
				else:
					# Neither side clear: use the normal vector
					avoidance_direction = obstacle_normal
				
				# Record the avoidance direction and set the stability time
				last_avoidance_direction = avoidance_direction
				direction_stability_timer = 0.8  # Keep the direction stable for 0.8 seconds
			
			# Smoothly blend directions to reduce oscillation
			var blend_factor = min(1.0, (30.0 - obstacle_distance) / 15.0)  # The closer the obstacle, the stronger the avoidance
			final_direction = desired_direction.lerp(avoidance_direction, blend_factor * 0.6)
			final_direction = final_direction.normalized()
			
			# Set avoidance state
			avoidance_force = avoidance_direction.normalized()
			avoidance_timer = 0.5  # Shorter avoidance duration
	else:
		# Reset the stability timer when there are no obstacles
		direction_stability_timer = 0.0
		last_avoidance_direction = Vector2.ZERO
	
	# If still avoiding, apply a slight avoidance force
	if avoidance_timer > 0:
		final_direction = final_direction.lerp(avoidance_force, 0.3)
		final_direction = final_direction.normalized()
		avoidance_timer -= get_physics_process_delta_time()
	
	return final_direction

# Check whether the given direction is clear
func _is_direction_clear(direction: Vector2, distance: float) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction * distance
	)
	query.exclude = [self]
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

# Detect whether stuck - improved detection logic
func _check_if_stuck(delta: float):
	var movement_threshold = 5.0  # Lower minimum movement distance threshold
	
	if global_position.distance_to(last_position) < movement_threshold:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
		last_position = global_position
		recalculate_count = 0  # Reset retry count
	
	# If stuck for too long and retries remain, recalculate the path
	if stuck_timer > stuck_threshold and navigation_path.size() > 0 and recalculate_count < max_recalculate_attempts:
		print("[CharacterController] %s appears stuck, recalculating path (attempt %d)" % [name, recalculate_count + 1])
		_recalculate_path()
		stuck_timer = 0.0
	elif recalculate_count >= max_recalculate_attempts:
		# Exceeded the maximum retries; try a simple straight-line path
		print("[CharacterController] %s exceeded retry limit, using a straight-line path" % name)
		navigation_path = [global_position, target_position]
		path_index = 0
		stuck_timer = 0.0
		recalculate_count = 0

# Recalculate the path
func _recalculate_path():
	if target_position != Vector2.ZERO:
		recalculate_count += 1
		
		# Try to compute a new path, increasing the offset range with each retry
		var offset_range = 30.0 + (recalculate_count * 20.0)
		var offset_target = target_position + Vector2(randf_range(-offset_range, offset_range), randf_range(-offset_range, offset_range))
		
		# Recalculate the path directly instead of calling move_to, to avoid resetting the counter
		var navigation_map = get_world_2d().navigation_map
		var path_params = NavigationPathQueryParameters2D.new()
		path_params.map = navigation_map
		path_params.start_position = global_position
		path_params.target_position = offset_target
		path_params.path_postprocessing = NavigationPathQueryParameters2D.PATH_POSTPROCESSING_CORRIDORFUNNEL
		
		var path_result = NavigationPathQueryResult2D.new()
		NavigationServer2D.query_path(path_params, path_result)
		navigation_path = path_result.path
		
		if navigation_path.is_empty():
			navigation_path = [global_position, offset_target]
		
		path_index = 0
		print("[CharacterController] %s finished recalculating path, path point count: %d" % [name, navigation_path.size()])

func _physics_process(delta):
	# AI-controlled characters and selected characters can both move
	if not is_selected and ai_agent.is_player_controlled:
		return
		
	# Handle keyboard input - only the selected character responds to keyboard input
	var input_direction = Vector2.ZERO
	if is_selected:
		input_direction.x = Input.get_axis("move_left", "move_right")
		input_direction.y = Input.get_axis("move_up", "move_down")
		input_direction = input_direction.normalized()
	
	if input_direction != Vector2.ZERO:
		# Keyboard control takes priority; cancel pathfinding
		navigation_path.clear()
		target_position = Vector2.ZERO
		velocity = input_direction * speed
		
		if abs(input_direction.x) > abs(input_direction.y):
			facing_direction = "right" if input_direction.x > 0 else "left"
	elif navigation_path.size() > 0:
		# Move along the computed path
		if path_index < navigation_path.size():
			var next_point = navigation_path[path_index]
			var direction = (next_point - global_position).normalized()
			
			# Improved obstacle avoidance logic
			var final_direction = _calculate_avoidance_direction(direction)
			
			# Adjust speed by distance, slowing down near the destination
			var distance_to_target = global_position.distance_to(next_point)
			var adjusted_speed = speed
			
			# Slow down when approaching the destination
			if path_index == navigation_path.size() - 1 and distance_to_target < 50:
				adjusted_speed = lerp(speed * 0.4, speed, distance_to_target / 50)
			
			# Make sure direction is not zero
			if final_direction != Vector2.ZERO:
				velocity = final_direction * adjusted_speed
			else:
				velocity = Vector2.ZERO
			
			# Update facing direction
			if abs(final_direction.x) > abs(final_direction.y):
				facing_direction = "right" if final_direction.x > 0 else "left"
			
			# Move to the next point after reaching a waypoint - dynamically adjusted threshold
			var base_threshold = 12.0
			var speed_factor = velocity.length() / speed
			var arrival_threshold = base_threshold * max(0.5, speed_factor)  # The faster the speed, the larger the threshold
			
			if global_position.distance_to(next_point) < arrival_threshold:
				path_index += 1
				
				# If there's a next waypoint, adjust direction in advance
				if path_index < navigation_path.size():
					var next_next_point = navigation_path[path_index]
					var next_direction = (next_next_point - global_position).normalized()
					# Smoother turning
					final_direction = final_direction.lerp(next_direction, 0.2)
			
			# Detect whether stuck
			_check_if_stuck(delta)
		else:
			# Reached the destination
			navigation_path.clear()
			velocity = Vector2.ZERO
			
			# Check whether to auto-sit
			_check_auto_sit()
	else:
		velocity = Vector2.ZERO
	
	# Update animation
	update_animation()
	
	if not is_sitting:
		move_and_slide()

func _unhandled_input(event):
	if not is_selected:
		return
		
	if event.is_action_pressed("sit"):
		if near_chair and not is_sitting:
			# If near a chair and not seated, try to sit on it
			sit_on_chair(near_chair)
		elif current_chair and is_sitting:
			# If already sitting on a chair, stand up
			stand_up_from_chair()
		else:
			# Regular sit/stand
			toggle_sit()

func sit_on_chair(chair):
	if chair.sit_character(self):
		is_sitting = true
		current_chair = chair
		target_position = Vector2.ZERO
		velocity = Vector2.ZERO
		facing_direction = chair.sit_direction
		
		# Play the sit animation for the corresponding direction
		var anim_name = "sit_" + facing_direction
		if facing_direction == "up":
			anim_name = "sit_up"
		elif facing_direction == "down":
			anim_name = "sit_down"
			
		$AnimatedSprite2D.play(anim_name)
		return true
	return false

func stand_up_from_chair():
	if current_chair and current_chair.stand_up():
		is_sitting = false
		current_chair = null
		
		# Reset Z order
		z_index = 0
		
		# Choose the stand-up animation based on the previous sitting pose
		var anim_name = "stand_" + facing_direction
		if facing_direction == "up":
			anim_name = "stand_up"
		elif facing_direction == "down":
			anim_name = "stand_down"
			
		$AnimatedSprite2D.play(anim_name)
		
		# Wait for the stand-up animation to finish
		await $AnimatedSprite2D.animation_finished
		
		# Switch to the idle animation
		$AnimatedSprite2D.play("idle_" + facing_direction)
		
		# Reset navigation variables
		navigation_path.clear()
		path_index = 0
		target_position = global_position
		velocity = Vector2.ZERO

func toggle_sit():
	# Only allow free sitting when not near a chair
	if near_chair:
		return
		
	is_sitting = !is_sitting
	var animated_sprite = $AnimatedSprite2D
	
	if is_sitting:
		target_position = Vector2.ZERO
		velocity = Vector2.ZERO
		animated_sprite.play("sit_" + facing_direction)
	else:
		animated_sprite.play("idle_" + facing_direction)

func update_animation():
	var animated_sprite = $AnimatedSprite2D
	if is_sitting:
		return
		
	if velocity == Vector2.ZERO:
		# Play the idle animation matching the last movement direction
		var idle_anim = "idle_" + facing_direction
		animated_sprite.play(idle_anim)
	else:
		if abs(velocity.x) > abs(velocity.y):
			if velocity.x > 0:
				animated_sprite.play("run_right")
				facing_direction = "right"
			else:
				animated_sprite.play("run_left")
				facing_direction = "left"
		else:
			if velocity.y > 0:
				animated_sprite.play("run_down")
				facing_direction = "down"
			else:
				animated_sprite.play("run_up")
				facing_direction = "up"

# Move to a chair and sit down automatically
func move_to_chair(chair):
	if is_sitting or not chair or chair.occupied:
		return false
	
	# Set the target chair and the auto-sit flag
	target_chair = chair
	auto_sit_enabled = true
	
	# Compute the chair's approach position (a set distance in front of the chair)
	var approach_position = _calculate_chair_approach_position(chair)
	
	# Move to the approach position
	move_to(approach_position)
	
	print("[CharacterController] %s started moving to chair: %s" % [name, chair.name])
	return true

# Compute the chair's approach position
func _calculate_chair_approach_position(chair) -> Vector2:
	var chair_pos = chair.global_position
	var current_pos = global_position
	
	# Compute the direction from the current position to the chair
	var direction_to_chair = (chair_pos - current_pos).normalized()
	
	# If very close to the chair (under 25 pixels), return the chair position directly
	var distance_to_chair = current_pos.distance_to(chair_pos)
	if distance_to_chair <= 25.0:
		return chair_pos

	# Otherwise, find an approach position within 25 pixels around the chair
	# Approach from the current direction, keeping a 25-pixel distance
	var approach_offset = -direction_to_chair * 25.0
	
	return chair_pos + approach_offset

# Check whether to auto-sit
func _check_auto_sit():
	if not auto_sit_enabled or not target_chair:
		return
	
	# Check whether the target chair is still available
	if target_chair.occupied:
		print("[CharacterController] %s's target chair is occupied, canceling auto-sit" % name)
		target_chair = null
		auto_sit_enabled = false
		return
	
	# Check whether within the chair's interaction range - using a larger range
	var distance_to_chair = global_position.distance_to(target_chair.global_position)
	print("[CharacterController] %s distance to chair: %.1f pixels" % [name, distance_to_chair])
	
	# Use a reasonable interaction range (about half the character's size), or check whether inside the chair's interaction area
	if distance_to_chair <= 20.0 or near_chair == target_chair:
		# Try to sit on the chair
		print("[CharacterController] %s trying to sit on the chair..." % name)
		if sit_on_chair(target_chair):
			print("[CharacterController] %s auto-sat on the chair successfully" % name)
		else:
			print("[CharacterController] %s could not sit on the chair" % name)
		
		# Reset auto-sit state
		target_chair = null
		auto_sit_enabled = false
	else:
		# Too far away, but don't move again to avoid an infinite loop
		# Try sitting directly, since it may be a precision issue
		print("[CharacterController] %s is fairly far from the chair (%.1f), trying to sit directly" % [name, distance_to_chair])
		if sit_on_chair(target_chair):
			print("[CharacterController] %s sat on the chair successfully" % name)
		else:
			print("[CharacterController] %s could not sit on the chair, canceling auto-sit" % name)
		
		# Reset auto-sit state
		target_chair = null
		auto_sit_enabled = false

# Create the AI model display label
func create_ai_model_label():
	# Check whether an AI model label already exists
	if has_node("AIModelLabel"):
		return
	
	# Load the AI model label scene
	var ai_label_scene = load("res://scene/ui/AIModelLabel.tscn")
	if ai_label_scene:
		var ai_label = ai_label_scene.instantiate()
		ai_label.name = "AIModelLabel"
		
		# Set the label position (below the character)
		ai_label.position = Vector2(0, 40)  # 40 pixels below the character
		
		# Add to the character node
		add_child(ai_label)
		
		# Connect to SettingsManager's settings updated signal
		var settings_manager = get_node_or_null("/root/SettingsManager")
		if settings_manager and settings_manager.has_signal("settings_changed"):
			settings_manager.settings_changed.connect(_on_ai_settings_changed)
		
		print("[CharacterController] AI model label created: ", name)
	else:
		print("[CharacterController Error] Could not load the AI model label scene")

# Settings updated callback
func _on_ai_settings_changed(new_settings):
	var ai_label = get_node_or_null("AIModelLabel")
	if ai_label and ai_label.has_method("refresh_display"):
		ai_label.refresh_display()
		print("[CharacterController] AI model label updated: ", name)
