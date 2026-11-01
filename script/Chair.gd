extends StaticBody2D

@export var sit_position: Vector2 = Vector2.ZERO  # Position offset of the character when seated
@export var sit_direction: String = "right"  # Direction the character faces when seated
@export var base_z_index: int = 0  # Base Z order
var occupied = false
var current_character = null

func _ready():
	# Add the chair to the chairs group
	add_to_group("chairs")
	# Add an interaction area
	var interaction_area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 32  # Interaction range
	collision_shape.shape = shape
	interaction_area.add_child(collision_shape)
	add_child(interaction_area)
	
	# Connect signals
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	# Set the chair's Z order
	z_index = base_z_index

func _draw():
	# Draw a seat position indicator (only visible in the editor)
	if Engine.is_editor_hint():
		draw_circle(sit_position, 5, Color.RED)
		# Draw a line from the chair center to the seat position
		draw_line(Vector2.ZERO, sit_position, Color.YELLOW, 2)

func _on_body_entered(body: Node2D):
	if body.is_in_group("controllable_characters"):
		body.near_chair = self

func _on_body_exited(body: Node2D):
	if body.is_in_group("controllable_characters") and body.near_chair == self:
		body.near_chair = null

# Check whether the click position is on the chair
func is_clicked_on(click_position: Vector2) -> bool:
	var distance = global_position.distance_to(click_position)
	return distance <= 32.0  # Chair click detection range

# Get the chair's seat position (global coordinates)
func get_sit_position() -> Vector2:
	return global_position + sit_position

func sit_character(character: CharacterBody2D):
	if occupied:
		return false
		
	occupied = true
	current_character = character
	
	# Move the character to the chair's seat position
	character.global_position = global_position + sit_position
	
	# Adjust Z order based on the sitting pose
	if sit_direction == "up":
		# Character is behind the chair
		character.z_index = base_z_index  # Character stays on the base layer
		z_index = base_z_index + 1  # Chair moves above the character
	else:
		# Character is in front of the chair
		character.z_index = base_z_index + 1  # Character is in front of the chair
		z_index = base_z_index  # Chair stays in place
	
	return true

func stand_up():
	if current_character:
		# Compute the character's position after standing up (16px behind the chair)
		var stand_up_offset = Vector2.ZERO
		if sit_direction == "up":
			# Chair faces up: character stands below the chair (behind it)
			stand_up_offset = Vector2(0, 16)
		elif sit_direction == "down":
			# Chair faces down: character stands above the chair (behind it)
			stand_up_offset = Vector2(0, -20)
		elif sit_direction == "left":
			# Chair faces left: character stands to the right of the chair (behind it)
			stand_up_offset = Vector2(16, 0)
		elif sit_direction == "right":
			# Chair faces right: character stands to the left of the chair (behind it)
			stand_up_offset = Vector2(-20, 0)
		
		# Move the character to the position behind the chair
		current_character.global_position = global_position + stand_up_offset
		
		# Reset Z order
		current_character.z_index = base_z_index  # Character returns to the base layer
		z_index = base_z_index  # Chair returns to the default layer
		occupied = false
		current_character = null
		return true
	return false
