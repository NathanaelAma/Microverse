extends Node

# Declare the Room class as globally accessible
class_name Room

# Stores all room info
var rooms: Dictionary = {}

func _ready():
	call_deferred("_init_rooms")
# Initialize room info
func _init_rooms():
	rooms.clear()
	for area in get_tree().get_nodes_in_group("room_area"):
		var room_name = area.room_name
		var room_desc = area.room_desc
		var collision_shape = area.get_node("CollisionShape2D")
		var shape = collision_shape.shape
		# Compute the room center = Area2D global position + CollisionShape2D relative position
		var position = area.global_position + collision_shape.position
		var size = Vector2.ZERO
		if shape is RectangleShape2D:
			size = shape.extents * 2
		else:
			size = Vector2(100, 100)
		var room_data = RoomData.new(room_name, position, size, room_desc)
		rooms[area.name] = room_data
		#print("Room: ", room_name, " position: ", position, " size: ", size)
# Get the room the character is currently in
func get_current_room(current_rooms: Dictionary, character_position: Vector2) -> RoomData:
	print("Character position: ", character_position.x, ",", character_position.y)
	for room in current_rooms.values():
		if is_position_in_room(character_position, room):
			return room
	return null

# Check whether a position is inside a room
func is_position_in_room(pos: Vector2, room: RoomData) -> bool:
	# Make sure the room data is valid
	if room == null or room.position == Vector2.ZERO:
		return false
	
	# Compute the room bounds
	var left = room.position.x - room.size.x / 2
	var right = room.position.x + room.size.x / 2
	var top = room.position.y - room.size.y / 2
	var bottom = room.position.y + room.size.y / 2
	
	# Check whether the position is within the room bounds
	return pos.x >= left and pos.x <= right and pos.y >= top and pos.y <= bottom

# Get important locations in a room
func get_room_important_locations(room_name: String) -> Dictionary:
	if rooms.has(room_name):
		return rooms[room_name].important_locations
	return {}
