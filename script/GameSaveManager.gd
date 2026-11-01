# GameSaveManager.gd - game save manager
# Responsible for saving and loading the data of all characters in the game

extends Node

# Save file path
const SAVE_DIR = "user://saves/"
const SAVE_FILE_EXTENSION = ".json"

# Current save data
var current_save_data = {}

# Signals
signal save_completed(success: bool, message: String)
signal load_completed(success: bool, message: String)

func _ready():
	# Make sure the save directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
	print("[GameSaveManager] Game save manager initialized")

# Save game data
func save_game(save_name: String = "") -> bool:
	if save_name.is_empty():
		save_name = "autosave_" + Time.get_datetime_string_from_system().replace(":", "-")
	
	var save_data = collect_game_data()
	var file_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
		
		current_save_data = save_data
		print("[GameSaveManager] Game saved to: ", file_path)
		save_completed.emit(true, "Game saved successfully: " + save_name)
		return true
	else:
		print("[GameSaveManager Error] Could not create save file: ", file_path)
		save_completed.emit(false, "Save failed: could not create file")
		return false

# Load game data
func load_game(save_name: String) -> bool:
	var file_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		print("[GameSaveManager Error] Save file does not exist: ", file_path)
		load_completed.emit(false, "Save file does not exist: " + save_name)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		if content.strip_edges() != "":
			var data = JSON.parse_string(content)
			if data:
				current_save_data = data
				apply_game_data(data)
				print("[GameSaveManager] Game loaded from save: ", file_path)
				load_completed.emit(true, "Game loaded successfully: " + save_name)
				return true
			else:
				print("[GameSaveManager Error] JSON parsing failed")
				load_completed.emit(false, "Save file is corrupted")
		else:
			print("[GameSaveManager Error] Save file is empty")
			load_completed.emit(false, "Save file is empty")
	else:
		print("[GameSaveManager Error] Could not open save file: ", file_path)
		load_completed.emit(false, "Could not open save file")
	
	return false

# Collect game data
func collect_game_data() -> Dictionary:
	var game_data = {
		"version": "1.0",
		"timestamp": Time.get_unix_time_from_system(),
		"scene_name": get_tree().current_scene.name,
		"characters": [],
		"rooms": {},
		"global_state": {}
	}
	
	# Collect character data
	var characters = get_tree().get_nodes_in_group("character")
	for character in characters:
		var character_data = collect_character_data(character)
		if character_data:
			game_data["characters"].append(character_data)
	
	# Collect room data
	var room_manager = get_node_or_null("/root/Office/RoomManager")
	if room_manager and room_manager.has_method("get_rooms_data"):
		game_data["rooms"] = room_manager.get_rooms_data()
	elif room_manager and room_manager.has_property("rooms"):
		# If there's no dedicated method, read the rooms property directly
		for room_name in room_manager.rooms:
			var room = room_manager.rooms[room_name]
			game_data["rooms"][room_name] = {
				"name": room.name,
				"position": {"x": room.position.x, "y": room.position.y},
				"size": {"x": room.size.x, "y": room.size.y},
				"description": room.description
			}
	
	# Collect global state
	game_data["global_state"] = collect_global_state()
	
	print("[GameSaveManager] Collected data for ", game_data["characters"].size(), " characters")
	return game_data

# Collect a single character's data
func collect_character_data(character: Node) -> Dictionary:
	if not character:
		return {}
	
	var character_data = {
		"name": character.name,
		"position": {"x": character.global_position.x, "y": character.global_position.y},
		"facing_direction": "",
		"is_sitting": false,
		"current_chair": null,
		"is_player_controlled": false,
		"ai_state": {},
		"tasks": [],
		"personality": {}
	}
	
	# Get character controller data
	var controller = character.get_node_or_null("CharacterController")
	if not controller:
		controller = character
	
	if controller:
		# Basic state
		if controller.has_property("facing_direction"):
			character_data["facing_direction"] = controller.facing_direction
		if controller.has_property("is_sitting"):
			character_data["is_sitting"] = controller.is_sitting
		if controller.has_property("current_chair") and controller.current_chair:
			character_data["current_chair"] = controller.current_chair.name
	
	# Get AI agent data
	var ai_agent = character.get_node_or_null("AIAgent")
	if ai_agent:
		character_data["is_player_controlled"] = ai_agent.is_player_controlled if ai_agent.has_property("is_player_controlled") else false
		
		# AI state
		if ai_agent.has_property("current_state"):
			character_data["ai_state"]["current_state"] = ai_agent.current_state
		
		# Task data
		if ai_agent.has_property("current_tasks"):
			character_data["tasks"] = ai_agent.current_tasks.duplicate() if ai_agent.current_tasks else []
		elif ai_agent.has_property("tasks"):
			character_data["tasks"] = ai_agent.tasks.duplicate() if ai_agent.tasks else []
	
	# Get character personality data
	var personality = CharacterPersonality.get_personality(character.name) if CharacterPersonality else {}
	character_data["personality"] = personality
	
	return character_data

# Collect global state
func collect_global_state() -> Dictionary:
	var global_state = {
		"game_time": Time.get_unix_time_from_system(),
		"settings": {}
	}
	
	# Get settings manager data
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.has_method("get_settings"):
		global_state["settings"] = settings_manager.get_settings()
	
	return global_state

# Apply game data
func apply_game_data(data: Dictionary):
	if not data.has("characters"):
		print("[GameSaveManager Warning] No character data in save")
		return
	
	# Apply character data
	var characters = get_tree().get_nodes_in_group("character")
	for character_data in data["characters"]:
		var character = find_character_by_name(character_data["name"])
		if character:
			apply_character_data(character, character_data)
		else:
			print("[GameSaveManager Warning] Character not found: ", character_data["name"])
	
	# Apply global state
	if data.has("global_state"):
		apply_global_state(data["global_state"])
	
	print("[GameSaveManager] Finished applying game data")

# Apply a single character's data
func apply_character_data(character: Node, data: Dictionary):
	if not character or not data:
		return
	
	# Set position
	if data.has("position"):
		var pos = data["position"]
		character.global_position = Vector2(pos["x"], pos["y"])
	
	# Get the character controller
	var controller = character.get_node_or_null("CharacterController")
	if not controller:
		controller = character
	
	if controller:
		# Set facing direction
		if data.has("facing_direction") and controller.has_property("facing_direction"):
			controller.facing_direction = data["facing_direction"]
		
		# Set sitting state
		if data.has("is_sitting") and controller.has_property("is_sitting"):
			controller.is_sitting = data["is_sitting"]
		
		# Restore chair state
		if data.has("current_chair") and data["current_chair"]:
			var chair = find_chair_by_name(data["current_chair"])
			if chair and controller.has_property("current_chair"):
				controller.current_chair = chair
	
	# Get the AI agent
	var ai_agent = character.get_node_or_null("AIAgent")
	if ai_agent:
		# Set player control state
		if data.has("is_player_controlled") and ai_agent.has_method("toggle_player_control"):
			ai_agent.toggle_player_control(data["is_player_controlled"])
		
		# Restore AI state
		if data.has("ai_state") and data["ai_state"].has("current_state") and ai_agent.has_property("current_state"):
			ai_agent.current_state = data["ai_state"]["current_state"]
		
		# Restore tasks
		if data.has("tasks"):
			if ai_agent.has_property("current_tasks"):
				ai_agent.current_tasks = data["tasks"].duplicate()
			elif ai_agent.has_property("tasks"):
				ai_agent.tasks = data["tasks"].duplicate()
	
	print("[GameSaveManager] Restored character data: ", character.name)

# Apply global state
func apply_global_state(data: Dictionary):
	if not data:
		return
	
	# Apply settings
	if data.has("settings"):
		var settings_manager = get_node_or_null("/root/SettingsManager")
		if settings_manager and settings_manager.has_method("update_settings"):
			settings_manager.update_settings(data["settings"])

# Find a character by name
func find_character_by_name(character_name: String) -> Node:
	var characters = get_tree().get_nodes_in_group("character")
	for character in characters:
		if character.name == character_name:
			return character
	return null

# Find a chair by name
func find_chair_by_name(chair_name: String) -> Node:
	var chairs = get_tree().get_nodes_in_group("chairs")
	for chair in chairs:
		if chair.name == chair_name:
			return chair
	return null

# Get the list of all save files
func get_save_files() -> Array:
	var save_files = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(SAVE_FILE_EXTENSION):
				var save_name = file_name.get_basename()
				save_files.append(save_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	return save_files

# Delete a save file
func delete_save(save_name: String) -> bool:
	var file_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	if FileAccess.file_exists(file_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			var result = dir.remove(save_name + SAVE_FILE_EXTENSION)
			if result == OK:
				print("[GameSaveManager] Deleted save: ", save_name)
				return true
			else:
				print("[GameSaveManager Error] Failed to delete save: ", save_name)
	else:
		print("[GameSaveManager Error] Save file does not exist: ", save_name)
	return false

# Get save info
func get_save_info(save_name: String) -> Dictionary:
	var file_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(content)
		if data:
			return {
				"name": save_name,
				"timestamp": data.get("timestamp", 0),
				"scene_name": data.get("scene_name", "Unknown"),
				"character_count": data.get("characters", []).size(),
				"version": data.get("version", "Unknown")
			}
	return {}
