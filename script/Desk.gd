extends StaticBody2D

@export var base_z_index: int = 0  # Base Z order
@export var y_threshold: float = 32.0  # Y-axis threshold used to determine front/back ordering

func _ready():
	# Set the initial Z order
	z_index = base_z_index + 1
	
	# Add a timer to update the Z order periodically
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.1  # Update every 0.1 seconds
	timer.timeout.connect(_update_z_order)
	timer.start()

func _update_z_order():
	# Get all characters and chairs
	var characters = get_tree().get_nodes_in_group("controllable_characters")
	var chairs = get_tree().get_nodes_in_group("chairs")  # Chairs must be added to the chairs group
	
	# Get the desk's Y coordinate
	var desk_y = global_position.y
	
	# Check the relationship with characters
	for character in characters:
		if abs(character.global_position.y - desk_y) <= y_threshold:
			if character.global_position.y < desk_y:
				# Character is behind the desk
				z_index = character.z_index + 1
			else:
				# Character is in front of the desk
				z_index = character.z_index - 1
	
	# Check the relationship with chairs
	for chair in chairs:
		if abs(chair.global_position.y - desk_y) <= y_threshold:
			if chair.global_position.y < desk_y:
				# Chair is behind the desk
				z_index = max(z_index, chair.z_index + 1)
			else:
				# Chair is in front of the desk
				z_index = min(z_index, chair.z_index - 1)
