extends Node

class_name AIAgent

# Character perception radius
const PERCEPTION_RADIUS = 200

# Character states
enum State {
	IDLE,
	MOVING,
	TALKING
}

# Current state
var current_state = State.IDLE

# Whether this character is controlled by the player
var is_player_controlled = false

# Character node references
@onready var character = get_parent()
@onready var character_controller = character
@onready var dialog_manager = get_node("/root/DialogManager")
@onready var character_manager = get_node("/root/CharacterManager")

# Timer for periodic AI decisions
var decision_timer: Timer

# Use the autoloaded singleton directly
@onready var api_manager = get_node("/root/APIManager")

# Perception-related references
@onready var room_manager = get_node("/root/Office/RoomManager")

func _ready():
	# Create and configure the decision timer
	decision_timer = Timer.new()
	decision_timer.wait_time = 60  # Make a decision every minute
	decision_timer.one_shot = false
	add_child(decision_timer)
	decision_timer.timeout.connect(_on_decision_timer_timeout)
	decision_timer.start()
	
	# Create a one-shot timer so the first decision happens after 10 seconds
	var initial_delay = Timer.new()
	initial_delay.wait_time = 10.0
	initial_delay.one_shot = true
	add_child(initial_delay)
	initial_delay.timeout.connect(func(): make_decision())
	initial_delay.start()

# Toggle player control
func toggle_player_control(enabled: bool):
	is_player_controlled = enabled
	if enabled:
		# Stop AI decisions
		decision_timer.stop()
		current_state = State.IDLE
	else:
		# Resume AI decisions
		decision_timer.start()

# Make a decision when the timer fires
func _on_decision_timer_timeout():
	if not is_player_controlled:
		make_decision()

# Build the scene description
func generate_scene_description() -> String:
	var description = ""
	# Get current room info
	var current_room = room_manager.get_current_room(room_manager.rooms, character.global_position)
	if current_room:
		description += "You are currently in " + current_room.name + "."
		description += "\n" + current_room.description
	
	# Get environment info
	var environment_info = get_environment_info()
	description += "\n" + environment_info
	
	# Get objects and characters in the room
	var room_objects = get_room_objects(current_room)
	var room_characters = get_room_characters(current_room)
	
	# Describe objects
	if room_objects.size() > 0:
		description += "\nThe room contains the following objects:"
		for obj in room_objects:
			var item_info = get_object_info(obj)
			description += "\n- " + item_info
	
	# Describe characters
	if room_characters.size() > 0:
		description += "\nThe following characters are in the room:"
		for char in room_characters:
			# Get the character's position/job title
			var char_personality = CharacterPersonality.get_personality(char.name)
			var position = char_personality.get("position", "Unknown position")
			
			description += "\n- " + char.name + " (" + position + ")"
			if char.has_method("get_current_state"):
				description += " - Status: " + char.get_current_state()
	
	# Add map awareness info
	description += "\n\nMap information:"
	for room_name in room_manager.rooms:
		var room = room_manager.rooms[room_name]
		var distance = character.global_position.distance_to(room.position)
		# Compute room bounds
		var left = room.position.x - room.size.x / 2
		var right = room.position.x + room.size.x / 2
		var top = room.position.y - room.size.y / 2
		var bottom = room.position.y + room.size.y / 2
		
		description += "\n- " + room.name + ": "
		description += "center (" + str(int(room.position.x)) + ", " + str(int(room.position.y)) + ")"
		description += ", bounds [left: " + str(int(left)) + ", right: " + str(int(right)) + ", top: " + str(int(top)) + ", bottom: " + str(int(bottom)) + "]"
		description += ", about " + str(int(distance)) + " meters away"
		description += ", direction: " + get_direction_description(character.global_position, room.position)
		
		# Add characters in that room
		var room_chars = get_room_characters(room)
		if room_chars.size() > 0:
			description += ", characters in room: "
			for i in range(room_chars.size()):
				var char = room_chars[i]
				var char_personality = CharacterPersonality.get_personality(char.name)
				var position = char_personality.get("position", "Unknown position")
				if i > 0:
					description += ", "
				description += char.name + "(" + position + ")"
	
	return description

# Get objects in a room
func get_room_objects(room: RoomData) -> Array:
	var room_objects = []
	var objects = get_tree().get_nodes_in_group("interactable")
	
	for obj in objects:
		if room and room_manager.is_position_in_room(obj.global_position, room):
			room_objects.append(obj)
	
	return room_objects

# Get characters in a room
func get_room_characters(room: RoomData) -> Array:
	var room_characters = []
	var characters = get_tree().get_nodes_in_group("character")
	
	for char in characters:
		if char != character and room and room_manager.is_position_in_room(char.global_position, room):
			room_characters.append(char)
	
	return room_characters

# Get a direction description
func get_direction_description(from_pos: Vector2, to_pos: Vector2) -> String:
	var direction = to_pos - from_pos
	var angle = rad_to_deg(direction.angle())
	
	if angle >= -22.5 and angle < 22.5:
		return "east"
	elif angle >= 22.5 and angle < 67.5:
		return "northeast"
	elif angle >= 67.5 and angle < 112.5:
		return "north"
	elif angle >= 112.5 and angle < 157.5:
		return "northwest"
	elif angle >= 157.5 or angle < -157.5:
		return "west"
	elif angle >= -157.5 and angle < -112.5:
		return "southwest"
	elif angle >= -112.5 and angle < -67.5:
		return "south"
	else:
		return "southeast"

# Get environment info
func get_environment_info() -> String:
	# Get the current scene name
	var current_scene = get_tree().current_scene.name
	var environment_info = ""
	
	# Provide a different environment description per scene
	match current_scene:
		"Office":
			environment_info = "This is a modern company with several work areas, meeting rooms, and break areas. The office is bright and minimalist, with large windows overlooking the scenery outside."
		"School":
			environment_info = "This is a school."
		"Jail":
			environment_info = "This is a prison."
		_:
			# Default description
			environment_info = "."
	
	# Add time-of-day info
	var time = Time.get_time_dict_from_system()
	var hour = time.hour
	var time_description = ""
	
	if hour >= 6 and hour < 9:
		time_description = "It is early morning; the office is just starting the day's work."
	elif hour >= 9 and hour < 12:
		time_description = "It is late morning; the office is at peak working hours."
	elif hour >= 12 and hour < 14:
		time_description = "It is lunchtime; some colleagues may have gone out to eat."
	elif hour >= 14 and hour < 18:
		time_description = "It is afternoon; everyone is focused on work."
	elif hour >= 18 and hour < 21:
		time_description = "It is evening; some colleagues are getting ready to leave."
	else:
		time_description = "It is night; only a few people are working overtime in the office."
	
	environment_info += "\n" + time_description
	return environment_info

# Get object info and function
func get_object_info(obj: Node2D) -> String:
	var info = obj.name
	
	# Add a function description based on object type
	if obj is StaticBody2D:
		# Check the object type and add the matching description
		if "Chair" in obj.name or obj.is_in_group("chairs"):
			info += " (a chair, you can sit down to rest or work)"
			# Check whether the chair is occupied
			if obj.has_method("is_occupied") and obj.is_occupied():
				info += ", currently in use"
			else:
				info += ", currently free"
		elif "Desk" in obj.name:
			info += " (an office desk, you can work here and keep a computer and documents on it)"
		elif "Computer" in obj.name:
			info += " (a computer, used for work, checking email, or browsing the web)"
		elif "Printer" in obj.name:
			info += " (a printer, used to print documents)"
		elif "CoffeeMachine" in obj.name:
			info += " (a coffee machine, provides coffee for a pick-me-up)"
		elif "WaterDispenser" in obj.name:
			info += " (a water dispenser, for a drink of water)"
		elif "Sofa" in obj.name:
			info += " (a sofa, you can sit down to relax)"
		elif "Whiteboard" in obj.name:
			info += " (a whiteboard, used for meetings, discussions, or jotting down ideas)"
		elif "Bookshelf" in obj.name:
			info += " (a bookshelf holding various books and materials)"
		elif "FileCabinet" in obj.name:
			info += " (a file cabinet holding important documents and records)"
		elif "Plant" in obj.name:
			info += " (a potted plant that livens up the office)"
		else:
			# Default description
			info += " (an office item)"
	
	# Add distance info
	var distance = int(obj.global_position.distance_to(character.global_position))
	info += ", about " + str(distance) + " meters away"
	
	return info

# Tracks whether we are waiting for an API response
var waiting_responses = {}

# Get detailed character status info
func get_character_status_info(char_node = null) -> String:
	# Use the given character node, or the current character if none
	var target_character = char_node if char_node else character
	var status_info = ""
	
	# Basic status info
	var money = target_character.get_meta("money", 0)
	var mood = target_character.get_meta("mood", "Normal")
	var health = target_character.get_meta("health", "Good")
	
	status_info += "\n\nPersonal status:"
	status_info += "\n- Savings: " + str(money) + " yuan"
	status_info += "\n- Mood: " + mood
	status_info += "\n- Health: " + health
	
	# Use MemoryManager to get formatted memories
	status_info += MemoryManager.get_formatted_memories_for_prompt(target_character)
	
	# Emotional relationship info
	var relations = target_character.get_meta("relations", {})
	if relations.size() > 0:
		status_info += "\n\nFeelings toward other colleagues:"
		for target_name in relations:
			var relation = relations[target_name]
			var emotion_type = relation["type"] if relation.has("type") else "Unknown"
			var strength = relation["strength"] if relation.has("strength") else 0
			var strength_desc = ""
			if strength < -5:
				strength_desc = "strong"
			elif strength < 0:
				strength_desc = "slight"
			elif strength == 0:
				strength_desc = "neutral"
			elif strength <= 5:
				strength_desc = "slight"
			else:
				strength_desc = "strong"
			
			status_info += "\n- Toward " + target_name + ": " + strength_desc + " " + emotion_type + " (strength: " + str(strength) + ")"
	
	return status_info

# Get the company employee roster string
func get_company_employees_info() -> String:
	var employees_info = "\n\nCompany employee roster and positions:"
	
	# Iterate over all character configs in CharacterPersonality
	for character_name in CharacterPersonality.PERSONALITY_CONFIG:
		var personality = CharacterPersonality.PERSONALITY_CONFIG[character_name]
		employees_info += "\n- " + character_name + ": " + personality["position"]
	
	employees_info += "\nNote: when generating any content, only mention the employees listed above; do not invent new character names."
	return employees_info

# Get the company basic info string
func get_company_basic_info() -> String:
	var company_info = "\n\nCompany background:"
	company_info += "\nYour company's main product is the mini-game \"CountSheep\"."
	company_info += "\nGame slogan: Can't Sleep? Count Sheep"
	company_info += "\nGameplay: users count the little sheep jumping across their phone screen, then tap a 3x3 grid of number buttons to enter the count and score points."
	company_info += "\nThe game is currently very popular, attracting lots of trendy young people who pay for sheep skins and button skins."
	return company_info

# Get character task info
func get_character_task_info(char_node = null) -> String:
	# Use the given character node, or the current character if none
	var target_character = char_node if char_node else character
	var task_info = ""
	
	# Get the task list
	var tasks = target_character.get_meta("tasks", [])
	
	if tasks.is_empty():
		task_info += "\n\nCurrent task status: no tasks"
		return task_info
		
	# Sort tasks by desire level (high to low)
	tasks.sort_custom(func(a, b): return a["priority"] > b["priority"])
	
	task_info += "\n\nCurrent task list (sorted by desire level):"
	
	# Show the 3 most important tasks
	var display_count = min(3, tasks.size())
	for i in range(display_count):
		var task = tasks[i]
		task_info += "\n%d. %s (desire level: %d/10)" % [i + 1, task["description"], task["priority"]]
		
	# If there are more tasks, show the total
	if tasks.size() > display_count:
		task_info += "\n...%d more tasks pending" % (tasks.size() - display_count)
		
	task_info += "\n\nTask advice: you should prioritize the tasks with the highest desire level."
	
	# Check whether daily tasks need refreshing
	_check_and_refresh_daily_tasks(target_character)
	
	return task_info

# Check and refresh daily tasks
func _check_and_refresh_daily_tasks(character_node):
	if not character_node:
		return
		
	# Get the last refresh time
	var last_refresh = character_node.get_meta("last_task_refresh", 0)
	var current_time = Time.get_unix_time_from_system()
	
	# Compute the time difference (seconds)
	var time_diff = current_time - last_refresh
	
	# Refresh tasks if more than 24 hours (86400 seconds) have passed
	if time_diff >= 86400:
		_refresh_daily_tasks(character_node)

# Refresh daily tasks
func _refresh_daily_tasks(character_node):
	if not character_node:
		return
		
	# Get the current task list
	var tasks = character_node.get_meta("tasks", [])
	
	# Keep incomplete tasks
	var incomplete_tasks = []
	for task in tasks:
		if not task.get("completed", false):
			incomplete_tasks.append(task)
			
	# Re-sort tasks (by priority, high to low)
	incomplete_tasks.sort_custom(func(a, b): return a["priority"] > b["priority"])
	
	# If there are fewer than 3 tasks, generate new ones automatically
	while incomplete_tasks.size() < 3:
		# Generate a random task
		var new_task = _generate_random_task(character_node)
		if new_task:
			incomplete_tasks.append(new_task)
		else:
			break
			
	# Update the task list
	character_node.set_meta("tasks", incomplete_tasks)
	
	# Update the refresh time
	character_node.set_meta("last_task_refresh", Time.get_unix_time_from_system())
	
	# Add a task-refresh memory
	var memory_text = "You updated today's task plan; you have %d tasks to complete." % incomplete_tasks.size()
	MemoryManager.add_memory(character_node, memory_text, MemoryManager.MemoryType.TASK, MemoryManager.MemoryImportance.NORMAL)
	
	print("[AIAgent] Tasks refreshed for %s, now has %d tasks" % [character_node.name, incomplete_tasks.size()])

# Generate a random task
func _generate_random_task(character_node):
	if not character_node:
		return null
		
	# Get the character's persona
	var personality = CharacterPersonality.get_personality(character_node.name)
	
	# Generate tasks suited to the character's position and personality
	var tasks_pool = []
	
	# General tasks
	tasks_pool.append("Check email")
	tasks_pool.append("Tidy up the workspace")
	tasks_pool.append("Chat with colleagues")
	tasks_pool.append("Attend a meeting")
	tasks_pool.append("Take a short break")
	tasks_pool.append("Prepare for tomorrow's work")
	tasks_pool.append("Reply to important emails")
	tasks_pool.append("Organize documents")
	tasks_pool.append("Learn a new skill")
	tasks_pool.append("Think about ways to improve work")
	tasks_pool.append("Update the boss on work progress")
	tasks_pool.append("Help a colleague solve a problem")
	tasks_pool.append("Draw up a work plan")
	tasks_pool.append("Summarize today's work")
	tasks_pool.append("Prepare a work report")
	
	# Add position-specific tasks
	if personality["position"].to_lower().contains("manager") or personality["position"].to_lower().contains("supervisor"):
		tasks_pool.append("Review team reports")
		tasks_pool.append("Assign work tasks")
		tasks_pool.append("Evaluate team performance")
		tasks_pool.append("Develop department strategy")
		tasks_pool.append("Coordinate with other departments")
	elif personality["position"].to_lower().contains("sales"):
		tasks_pool.append("Contact potential customers")
		tasks_pool.append("Prepare a sales demo")
		tasks_pool.append("Follow up on sales leads")
		tasks_pool.append("Update customer records")
		tasks_pool.append("Develop a sales strategy")
	elif personality["position"].to_lower().contains("tech") or personality["position"].to_lower().contains("engineer"):
		tasks_pool.append("Fix technical issues")
		tasks_pool.append("Develop a new feature")
		tasks_pool.append("Do a code review")
		tasks_pool.append("Write technical documentation")
		tasks_pool.append("Run system tests")
	elif personality["position"].to_lower().contains("human resources") or personality["position"].to_lower().contains("hr"):
		tasks_pool.append("Review resumes")
		tasks_pool.append("Schedule interviews")
		tasks_pool.append("Handle employee issues")
		tasks_pool.append("Organize a team activity")
		tasks_pool.append("Update employee records")
	
	# Pick a random task
	var random_task = tasks_pool[randi() % tasks_pool.size()]
	
	# Generate a random priority (1-10)
	var random_priority = randi() % 10 + 1
	
	# Create the task object
	return {
		"description": random_task,
		"priority": random_priority,
		"created_at": Time.get_unix_time_from_system(),
		"completed": false
	}

# Make a decision and act on it
func make_decision():
	# If waiting for an API response, skip this decision
	if character.name in waiting_responses and waiting_responses[character.name]:
		print("[AIAgent] %s is still waiting for the previous API response, skipping this decision" % character.name)
		return
	# If in a conversation, make an in-conversation decision instead
	if dialog_manager.is_character_in_conversation(character):
		print("[AIAgent] %s is in a conversation, making a conversation decision" % character.name)
		await make_conversation_decision()
		return
	
	# Check and initialize the task system
	await _check_and_initialize_tasks()
	
	# Generate the scene description
	var scene_description = generate_scene_description()
	print("[AIAgent] Scene description for %s:\n%s" % [character.name, scene_description])
	
	# Get the character's persona
	var personality = CharacterPersonality.get_personality(character.name)
	
	# Get detailed character status info
	var status_info = get_character_status_info(character)
	
	# Get task info
	var task_info = get_character_task_info(character)
	
	# Build the prompt
	var prompt = "You are an office employee named %s. Your position is: %s. Your personality: %s. Your speaking style: %s. Your job duties: %s. Your work habits: %s." % [
		character.name,
		personality["position"],
		personality["personality"],
		personality["speaking_style"],
		personality["work_duties"],
		personality["work_habits"]
	]
	
	# Add company background and the employee roster
	prompt += get_company_basic_info()
	prompt += get_company_employees_info()
	prompt += status_info  # Add detailed status info
	prompt += task_info   # Add task info
	prompt += "\n" + scene_description
	prompt += "\nBased on your position, personality, current personal status (including mood, health, and finances), memories, relationships, current task list, and current surroundings, consider the most reasonable action in this situation."
	prompt += "\nPay special attention: your decision should be influenced by the following factors:"
	prompt += "\n- Your mood may affect your behavioral tendencies"
	prompt += "\n- Your health may limit what you are able to do"
	prompt += "\n- Your finances may affect how sensitive you are to money-related topics"
	prompt += "\n- Your memories affect how you judge the current situation"
	prompt += "\n- Your feelings toward colleagues affect whether you want to interact with them"
	prompt += "\n- You should prioritize tasks with a high desire level"
	prompt += "\n- Your action should relate to your current most important task"
	prompt += "\n\nBased on all of the above, what action do you want to take? Choose one of the following options:"
	prompt += "\n1. Adjust tasks (reschedule or change the priority of current tasks)"
	prompt += "\n2. Continue the current task (work on the most important current task)"
	prompt += "\nReply with only the number 1 or 2, with no other text."
	
	# Use APIManager to generate the AI decision
	var character_name = character.name if character else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Create a unique callback connection per character
	# Disconnect any existing connection to avoid duplicate connections
	if http_request.request_completed.is_connected(_on_decision_request_completed):
		http_request.request_completed.disconnect(_on_decision_request_completed)
	
	# Use a callback bound to this character
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_decision_request_completed(result, response_code, headers, body, character)
	)
	waiting_responses[character.name] = true

# Handle the API response
func _on_decision_request_completed(result, _response_code, headers, body, char_node = null):
	# Use the given character node, or the current character if none
	var target_character = char_node if char_node else character
	
	# Reset waiting state
	waiting_responses[target_character.name] = false
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] HTTP request for %s failed, error code: %s, using default decision" % [target_character.name, result])
		_execute_default_decision(target_character)
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] JSON parsing failed for %s, using default decision" % target_character.name)
		_execute_default_decision(target_character)
		return
	
	# Parse the response through APIConfig
	var decision = _parse_ai_response(response, target_character)
	if decision == "":
		print("[AIAgent] Failed to parse API response for %s, using default decision" % target_character.name)
		_execute_default_decision(target_character)
		return
	
	decision = decision.strip_edges()
	
	# Act on the decision
	print("[AIAgent] Decision result for %s: %s" % [target_character.name, decision])
	match decision:
		"1":  # Adjust tasks
			print("[AIAgent] %s decided to adjust tasks" % target_character.name)
			await _adjust_tasks(target_character)
		"2":  # Continue current task
			print("[AIAgent] %s decided to continue the current task" % target_character.name)
			await _continue_current_task(target_character)
		_:
			print("[AIAgent] Invalid decision: ", decision)

# In-conversation decision
func make_conversation_decision():
	# If waiting for an API response, skip this decision
	if character.name in waiting_responses and waiting_responses[character.name]:
		print("[AIAgent] %s is still waiting for the previous API response, skipping conversation decision" % character.name)
		return
	
	# Get the current conversation partner
	var conversation_partner = _get_conversation_partner(character)
	if not conversation_partner:
		print("[AIAgent] %s could not get a conversation partner" % character.name)
		return
	
	# Get chat history
	var chat_history = ""
	if character.has_node("ChatHistory"):
		var history_node = character.get_node("ChatHistory")
		chat_history = history_node.get_recent_conversation_with(conversation_partner.name, 10)
	
	# Get the character's persona
	var personality = CharacterPersonality.get_personality(character.name)
	
	# Get detailed character status info
	var status_info = get_character_status_info(character)
	
	# Get task info
	var task_info = get_character_task_info(character)
	
	# Build the conversation decision prompt
	var prompt = "You are an office employee named %s. Your position is: %s. Your personality: %s. Your speaking style: %s." % [
		character.name,
		personality["position"],
		personality["personality"],
		personality["speaking_style"]
	]
	
	# Add company background and the employee roster
	prompt += get_company_basic_info()
	prompt += get_company_employees_info()
	prompt += status_info
	prompt += task_info
	
	# Add current conversation info
	prompt += "\n\nYou are talking with %s." % conversation_partner.name
	
	# Add chat history
	if chat_history != "":
		prompt += "\n\nYour recent conversation:\n" + chat_history
	else:
		prompt += "\n\nThis is the start of your conversation."
	
	# Add decision options
	prompt += "\n\nBased on your personality, current status, task list, and the conversation so far, decide whether you should continue this conversation:"
	prompt += "\n- If the conversation helps you complete your tasks, or you feel it is worth continuing, choose to continue"
	prompt += "\n- If you feel the conversation has gone on long enough, or you have more important things to do, choose to end it"
	prompt += "\n\nChoose one of the following options:"
	prompt += "\n1. Continue the conversation (stay in the current conversation)"
	prompt += "\n2. End the conversation (politely wrap up the current conversation)"
	prompt += "\nReply with only the number 1 or 2, with no other text."
	
	# Use APIManager to generate the AI decision
	var character_name = character.name if character else "Unknown"
	print(prompt)
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Connect the callback
	if http_request.request_completed.is_connected(_on_conversation_decision_completed):
		http_request.request_completed.disconnect(_on_conversation_decision_completed)
	
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_conversation_decision_completed(result, response_code, headers, body, character, conversation_partner)
	)
	waiting_responses[character.name] = true

# Handle the conversation decision API response
func _on_conversation_decision_completed(result, _response_code, headers, body, char_node, partner_node):
	# Reset waiting state
	waiting_responses[char_node.name] = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Conversation decision HTTP request for %s failed, error code: %s" % [char_node.name, result])
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Conversation decision JSON parsing failed for %s" % char_node.name)
		return
	
	# Parse the response through APIConfig
	var decision = _parse_ai_response(response, char_node)
	if decision == "":
		print("[AIAgent] Failed to parse conversation decision API response for %s" % char_node.name)
		return
	
	decision = decision.strip_edges()
	
	# Act on the decision
	print("[AIAgent] Conversation decision result for %s: %s" % [char_node.name, decision])
	match decision:
		"1":  # Continue conversation
			print("[AIAgent] %s decided to continue the conversation" % char_node.name)
			# Do nothing; keep the conversation going
		"2":  # End conversation
			print("[AIAgent] %s decided to end the conversation" % char_node.name)
			await _generate_farewell_message(char_node, partner_node)
		_:
			print("[AIAgent] Invalid conversation decision: ", decision)

# Generate a farewell message and end the conversation
func _generate_farewell_message(char_node, partner_node):
	# Get the character's persona
	var personality = CharacterPersonality.get_personality(char_node.name)
	
	# Get chat history
	var chat_history = ""
	if char_node.has_node("ChatHistory"):
		var history_node = char_node.get_node("ChatHistory")
		chat_history = history_node.get_recent_conversation_with(partner_node.name, 5)
	
	# Build the farewell message prompt
	var prompt = "You are an office employee named %s. Your position is: %s. Your personality: %s. Your speaking style: %s." % [
		char_node.name,
		personality["position"],
		personality["personality"],
		personality["speaking_style"]
	]
	
	prompt += "\n\nYou are talking with %s, and you have now decided to end this conversation." % partner_node.name
	
	if chat_history != "":
		prompt += "\n\nWhat the two of you just said:\n" + chat_history
	
	prompt += "\n\nPlease write one polite farewell line to end this conversation. Requirements:"
	prompt += "\n- Match your personality and speaking style"
	prompt += "\n- Natural and friendly tone"
	prompt += "\n- Moderate length (1-2 sentences)"
	prompt += "\n- Don't explain why you are leaving; just say goodbye politely"
	prompt += "\n\nReply with the farewell line only, without anything else."
	
	# Use APIManager to generate the farewell message
	var character_name = char_node.name if char_node else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Connect the callback
	if http_request.request_completed.is_connected(_on_farewell_message_completed):
		http_request.request_completed.disconnect(_on_farewell_message_completed)
	
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_farewell_message_completed(result, response_code, headers, body, char_node, partner_node)
	)
	waiting_responses[char_node.name] = true

# Handle the farewell message API response
func _on_farewell_message_completed(result, _response_code, headers, body, char_node, partner_node):
	# Reset waiting state
	waiting_responses[char_node.name] = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Farewell message HTTP request for %s failed, error code: %s" % [char_node.name, result])
		# Use the default farewell message
		_send_farewell_and_end_conversation(char_node, partner_node, "Alright, I've got other things to get to. Talk later.")
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Farewell message JSON parsing failed for %s" % char_node.name)
		_send_farewell_and_end_conversation(char_node, partner_node, "Alright, I've got other things to get to. Talk later.")
		return
	
	# Parse the response through APIConfig
	var farewell_message = _parse_ai_response(response, char_node)
	if farewell_message == "":
		print("[AIAgent] Failed to parse farewell message API response for %s" % char_node.name)
		farewell_message = "Alright, I've got other things to get to. Talk later."
	
	farewell_message = farewell_message.strip_edges()
	print("[AIAgent] Farewell message generated by %s: %s" % [char_node.name, farewell_message])
	
	# Send the farewell message and end the conversation
	_send_farewell_and_end_conversation(char_node, partner_node, farewell_message)

# Send the farewell message and end the conversation
func _send_farewell_and_end_conversation(char_node, partner_node, farewell_message):
	# Send the farewell message through DialogManager
	var dialog_manager = get_node("/root/DialogManager")
	if dialog_manager:
		# Create a dialog bubble showing the farewell message
		var dialog_bubble_scene = preload("res://scene/ui/DialogBubble.tscn")
		var dialog_bubble = dialog_bubble_scene.instantiate()
		get_tree().root.add_child(dialog_bubble)
		dialog_bubble.target_node = char_node
		dialog_bubble.show_dialog(farewell_message)
		
		# Save the farewell message to chat history
		var formatted_message = char_node.name + ": " + farewell_message
		if char_node.has_node("ChatHistory"):
			var char_history = char_node.get_node("ChatHistory")
			char_history.add_message(partner_node.name, formatted_message)
		if partner_node.has_node("ChatHistory"):
			var partner_history = partner_node.get_node("ChatHistory")
			partner_history.add_message(char_node.name, formatted_message)
		
		# Wait briefly so the message is visible
		await get_tree().create_timer(1.0).timeout
		
		# End the conversation
		dialog_manager.end_character_conversations(char_node)
	else:
		print("[AIAgent] Could not get DialogManager, ending the conversation directly")
		# If DialogManager is unavailable, try fetching it again and ending the conversation
		var fallback_dialog_manager = get_node("/root/DialogManager")
		if fallback_dialog_manager:
			fallback_dialog_manager.end_character_conversations(char_node)

# Generate thinking content
func generate_thinking_content(char_node = null):
	# Use the given character node, or the current character if none
	var target_character = char_node if char_node else character
	
	# If waiting for an API response, skip
	if target_character.name in waiting_responses and waiting_responses[target_character.name]:
		print("[AIAgent] %s is still waiting for the previous API response, skipping thought generation" % target_character.name)
		return
	
	# Generate the scene description
	var scene_description = generate_scene_description()
	
	# Get the character's persona
	var personality = CharacterPersonality.get_personality(target_character.name)
	
	# Get detailed character status info
	var status_info = get_character_status_info(target_character)
	
	# Get current task info
	var tasks_info = ""
	var metadata = target_character.get_meta("character_data", {})
	var tasks = metadata.get("tasks", [])
	if tasks.size() > 0:
		# Get incomplete tasks
		var active_tasks = []
		for task in tasks:
			if not task.get("completed", false):
				active_tasks.append(task)
		
		if active_tasks.size() > 0:
			# Sort by priority
			active_tasks.sort_custom(func(a, b): return a.priority > b.priority)
			tasks_info += "\n\nYour current task list:"
			for i in range(min(active_tasks.size(), 3)):
				var task = active_tasks[i]
				tasks_info += "\n%d. %s (desire level: %d)" % [i+1, task.description, task.priority]
	
	# Build a simplified thinking prompt
	var prompt = "You are %s. Position: %s. Personality: %s. Speaking style: %s." % [
		target_character.name,
		personality["position"],
		personality["personality"],
		personality["speaking_style"]
	]
	
	# Only add the key personal status info
	var money = target_character.get_meta("money", 0)
	var mood = target_character.get_meta("mood", "Normal")
	var health = target_character.get_meta("health", "Good")
	prompt += "\nCurrent status: mood %s, health %s, savings %d yuan." % [mood, health, money]
	
	# Add the most important task info
	if tasks_info != "":
		prompt += tasks_info
	
	# Add the most recent important memory (only the last one)
	var recent_memories = MemoryManager.get_recent_memories(target_character, 24)
	if recent_memories.size() > 0:
		var recent_memory = MemoryManager._format_memory_for_display(recent_memories[recent_memories.size() - 1])
		prompt += "\nRecent memory: " + recent_memory
	
	prompt += "\n\nNow express your inner thoughts at this moment in the first person. Requirements:"
	prompt += "\n1. Reflect your personality and speaking style"
	prompt += "\n2. Consider your current status and tasks"
	prompt += "\n3. A short inner monologue of 30-60 words"
	prompt += "\n4. Return only pure inner thoughts, without any description of surroundings, actions, or narration"
	prompt += "\n5. Let it flow naturally like a real inner voice"
	
	print(prompt)
	# Use APIManager to generate thinking content
	var character_name = target_character.name if target_character else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Disconnect any existing connection to avoid duplicate connections
	if http_request.request_completed.is_connected(_on_thinking_request_completed):
		http_request.request_completed.disconnect(_on_thinking_request_completed)
	
	# Use a callback bound to this character
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_thinking_request_completed(result, response_code, headers, body, target_character)
	)
	waiting_responses[target_character.name] = true

# Check and initialize the task system
func _check_and_initialize_tasks():
	# Check whether the character already has task data
	var metadata = character.get_meta("character_data", {})
	if not metadata.has("tasks") or metadata["tasks"].size() == 0:
		print("[AIAgent] %s has no task data, generating initial tasks" % character.name)
		await _generate_initial_tasks()
	else:
		print("[AIAgent] %s already has %d tasks" % [character.name, metadata["tasks"].size()])

# Generate initial tasks
func _generate_initial_tasks():
	# If waiting for an API response, skip
	if character.name in waiting_responses and waiting_responses[character.name]:
		return
	
	# Get the character's persona
	var personality = CharacterPersonality.get_personality(character.name)
	
	# Get detailed character status info
	var status_info = get_character_status_info(character)
	
	# Build the task generation prompt
	var prompt = "You are an office employee named %s. Your position is: %s. Your personality: %s. Your speaking style: %s. Your job duties: %s. Your work habits: %s." % [
		character.name,
		personality["position"],
		personality["personality"],
		personality["speaking_style"],
		personality["work_duties"],
		personality["work_habits"]
	]
	
	# Add company background and the employee roster
	prompt += get_company_basic_info()
	prompt += get_company_employees_info()
	prompt += status_info
	prompt += "\n\nBased on your position, personality, and current status, list the 3 tasks you most want to do right now. These tasks should:"
	prompt += "\n- Fit your position and job duties"
	prompt += "\n- Reflect your personality traits"
	prompt += "\n- Take into account your current mood, health, and finances"
	prompt += "\n- Include both work tasks and personal matters"
	prompt += "\n- Be described in one sentence each (10-30 words)"
	prompt += "\n\nOutput in the following format, one task per line: task description|desire level (a number from 1-10)"
	prompt += "\nFor example:"
	prompt += "\nFinish this month's sales report|8"
	prompt += "\nDiscuss the new project plan with colleagues|6"
	prompt += "\nOrganize the files on my desk|4"
	prompt += "\n\nGenerate 3 tasks:"
	
	# Use APIManager to generate tasks
	var character_name = character.name if character else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Disconnect any existing connection
	if http_request.request_completed.is_connected(_on_generate_tasks_completed):
		http_request.request_completed.disconnect(_on_generate_tasks_completed)
	
	# Connect the callback
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_generate_tasks_completed(result, response_code, headers, body, character)
	)
	waiting_responses[character.name] = true

# Handle the task generation API response
func _on_generate_tasks_completed(result, _response_code, headers, body, char_node = null):
	var target_character = char_node if char_node else character
	
	# Reset waiting state
	waiting_responses[target_character.name] = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Task generation HTTP request for %s failed, error code: %s" % [target_character.name, result])
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Task generation JSON parsing failed for %s" % target_character.name)
		return
	
	# Parse the AI-generated tasks
	var task_content = _parse_ai_response(response, target_character)
	if task_content == "":
		print("[AIAgent] Failed to parse task generation API response for %s, using default tasks" % target_character.name)
		_generate_default_tasks(target_character)
		return
	
	print("[AIAgent] Tasks generated for %s:\n%s" % [target_character.name, task_content])
	
	# Parse the task list
	var tasks = []
	var lines = task_content.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.length() > 0 and "|" in line:
			var parts = line.split("|")
			if parts.size() >= 2:
				var description = parts[0].strip_edges()
				var priority_str = parts[1].strip_edges()
				var priority = int(priority_str) if priority_str.is_valid_int() else 5
				
				# Clamp priority to the 1-10 range
				priority = max(1, min(10, priority))
				
				tasks.append({
					"description": description,
					"priority": priority,
					"created_at": Time.get_unix_time_from_system(),
					"completed": false
				})
	
	# If fewer than 3 tasks were parsed, fill in with random tasks
	while tasks.size() < 3:
		tasks.append(_generate_random_task(target_character))
	
	# Sort by priority
	tasks.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Save tasks to the character's metadata
	var metadata = target_character.get_meta("character_data", {})
	metadata["tasks"] = tasks
	target_character.set_meta("character_data", metadata)
	
	# Add a task-generation memory
	var memory_text = "You made a new task plan for yourself with %d important tasks, and you're ready to get started." % tasks.size()
	MemoryManager.add_memory(target_character, memory_text, MemoryManager.MemoryType.TASK, MemoryManager.MemoryImportance.NORMAL)
	
	print("[AIAgent] %s successfully generated and saved %d tasks" % [target_character.name, tasks.size()])

# Adjust tasks
func _adjust_tasks(char_node = null):
	var target_character = char_node if char_node else character
	
	# If waiting for an API response, skip
	if target_character.name in waiting_responses and waiting_responses[target_character.name]:
		return
	
	# Get current tasks
	var metadata = target_character.get_meta("character_data", {})
	var tasks = metadata.get("tasks", [])
	
	if tasks.size() == 0:
		print("[AIAgent] %s has no tasks to adjust" % target_character.name)
		return
	
	# Get the character's persona and status
	var personality = CharacterPersonality.get_personality(target_character.name)
	var status_info = get_character_status_info(target_character)
	var scene_description = generate_scene_description()
	
	# Build the task adjustment prompt
	var prompt = "You are an office employee named %s. Your position is: %s. Your personality: %s." % [
		target_character.name,
		personality["position"],
		personality["personality"]
	]
	
	# Add company background and the employee roster
	prompt += get_company_basic_info()
	prompt += get_company_employees_info()
	prompt += status_info
	prompt += "\n" + scene_description
	prompt += "\n\nYour current task list:"
	for i in range(min(tasks.size(), 5)):
		var task = tasks[i]
		prompt += "\n%d. %s (desire level: %d)" % [i+1, task.description, task.priority]
	
	prompt += "\n\nGiven your current status, surroundings, and mood, do you need to adjust the priority of these tasks?"
	prompt += "\nChoose from the following options:"
	prompt += "\n1. Keep the current task priorities unchanged"
	prompt += "\n2. Rearrange task priorities"
	prompt += "\n3. Add a new urgent task"
	prompt += "\nReply with only the number 1, 2, or 3, with no other text."
	
	# Use APIManager to generate the decision
	var character_name = target_character.name if target_character else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Disconnect any existing connection
	if http_request.request_completed.is_connected(_on_adjust_tasks_completed):
		http_request.request_completed.disconnect(_on_adjust_tasks_completed)
	
	# Connect the callback
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_adjust_tasks_completed(result, response_code, headers, body, target_character)
	)
	waiting_responses[target_character.name] = true

# Handle the task adjustment API response
func _on_adjust_tasks_completed(result, _response_code, headers, body, char_node = null):
	var target_character = char_node if char_node else character
	
	# Reset waiting state
	waiting_responses[target_character.name] = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Task adjustment HTTP request for %s failed" % target_character.name)
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Task adjustment JSON parsing failed for %s" % target_character.name)
		return
	
	# Parse the decision
	var decision = _parse_ai_response(response, target_character)
	if decision == "":
		print("[AIAgent] Failed to parse task adjustment API response for %s" % target_character.name)
		return
	
	decision = decision.strip_edges()
	print("[AIAgent] Task adjustment decision for %s: %s" % [target_character.name, decision])
	
	match decision:
		"1":  # Keep unchanged
			print("[AIAgent] %s decided to keep the current task priorities" % target_character.name)
			# Add a memory
			_add_memory(target_character, "You reviewed your current task list and decided to keep the existing priorities.")
		"2":  # Rearrange
			print("[AIAgent] %s decided to rearrange task priorities" % target_character.name)
			await _rearrange_task_priorities(target_character)
		"3":  # Add a new task
			print("[AIAgent] %s decided to add a new urgent task" % target_character.name)
			await _add_urgent_task(target_character)
		_:
			print("[AIAgent] Invalid task adjustment decision for %s: %s" % [target_character.name, decision])

# Continue the current task
func _continue_current_task(char_node = null):
	var target_character = char_node if char_node else character
	
	# If waiting for an API response, skip
	if target_character.name in waiting_responses and waiting_responses[target_character.name]:
		return
	
	# Get the current most important task
	var metadata = target_character.get_meta("character_data", {})
	var tasks = metadata.get("tasks", [])
	
	# Filter incomplete tasks and sort by priority
	var active_tasks = []
	for task in tasks:
		if not task.get("completed", false):
			active_tasks.append(task)
	
	if active_tasks.size() == 0:
		print("[AIAgent] %s has no incomplete tasks" % target_character.name)
		# Generate new tasks
		await _generate_initial_tasks()
		return
	
	# Sort by priority
	active_tasks.sort_custom(func(a, b): return a.priority > b.priority)
	var current_task = active_tasks[0]
	
	# Get the character's persona and status
	var personality = CharacterPersonality.get_personality(target_character.name)
	var status_info = get_character_status_info(target_character)
	var scene_description = generate_scene_description()
	
	# Build the task execution prompt
	var prompt = "You are an office employee named %s. Your position is: %s. Your personality: %s." % [
		target_character.name,
		personality["position"],
		personality["personality"]
	]
	
	# Add company background and the employee roster
	prompt += get_company_basic_info()
	prompt += get_company_employees_info()
	prompt += status_info
	prompt += "\n" + scene_description
	prompt += "\n\nYour current most important task is: %s (desire level: %d)" % [current_task.description, current_task.priority]
	prompt += "\n\nWhat concrete action do you need to take to complete this task? Choose from the following options:"
	prompt += "\n1. Move somewhere (go find a relevant person or object)"
	prompt += "\n2. Talk to a character (discuss something related to the task)"
	prompt += "\n3. Think and plan (think about how to complete the task where you are)"
	prompt += "\n4. Complete the task (the task can now be marked as done)"
	prompt += "\nReply with only the number 1, 2, 3, or 4, with no other text."
	
	# Use APIManager to generate the decision
	var character_name = target_character.name if target_character else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Disconnect any existing connection
	if http_request.request_completed.is_connected(_on_continue_task_completed):
		http_request.request_completed.disconnect(_on_continue_task_completed)
	
	# Connect the callback
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_continue_task_completed(result, response_code, headers, body, target_character, current_task)
	)
	waiting_responses[target_character.name] = true

# Handle the continue-task API response
func _on_continue_task_completed(result, _response_code, headers, body, char_node = null, current_task = null):
	var target_character = char_node if char_node else character
	
	# Reset waiting state
	waiting_responses[target_character.name] = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Continue-task HTTP request for %s failed" % target_character.name)
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Continue-task JSON parsing failed for %s" % target_character.name)
		return
	
	# Parse the decision
	var decision = _parse_ai_response(response, target_character)
	if decision == "":
		print("[AIAgent] Failed to parse continue-task API response for %s" % target_character.name)
		return
	
	decision = decision.strip_edges()
	print("[AIAgent] Task execution decision for %s: %s" % [target_character.name, decision])
	
	match decision:
		"1":  # Move
			print("[AIAgent] %s decided to move to complete the task: %s" % [target_character.name, current_task.description])
			await _execute_task_movement(target_character, current_task)
		"2":  # Talk
			print("[AIAgent] %s decided to talk to complete the task: %s" % [target_character.name, current_task.description])
			await _execute_task_conversation(target_character, current_task)
		"3":  # Think
			print("[AIAgent] %s decided to think about how to complete the task: %s" % [target_character.name, current_task.description])
			await _execute_task_thinking(target_character, current_task)
		"4":  # Complete task
			print("[AIAgent] %s decided to mark the task as complete: %s" % [target_character.name, current_task.description])
			_complete_task(target_character, current_task)
		_:
			print("[AIAgent] Invalid task execution decision for %s: %s" % [target_character.name, decision])

# Helper to parse the AI response
# Must parse with the AI settings of the character that sent the request: a character may use a different API type than the global one
func _parse_ai_response(response, char_node = null) -> String:
	var target_character = char_node if is_instance_valid(char_node) else character
	var character_name = target_character.name if target_character else ""
	if not response is Dictionary:
		print("[AIAgent] API response for %s is not a JSON object" % character_name)
		return ""
	return APIConfig.parse_response(api_manager.get_api_type_for(character_name), response, character_name)

# Helper to add a memory
func _add_memory(target_character, content: String):
	# Add the memory through MemoryManager
	MemoryManager.add_memory(target_character, content, MemoryManager.MemoryType.PERSONAL, MemoryManager.MemoryImportance.NORMAL)

# Execute task-related movement
func _execute_task_movement(target_character, current_task):
	# If waiting for an API response, skip
	if target_character.name in waiting_responses and waiting_responses[target_character.name]:
		return
	
	# Get the character's persona and status
	var personality = CharacterPersonality.get_personality(target_character.name)
	var scene_description = generate_scene_description()
	
	# Build the movement decision prompt
	var prompt = "You are an office employee named %s. Your position is: %s." % [
		target_character.name,
		personality["position"]
	]
	
	# Add company background and the employee roster
	prompt += get_company_basic_info()
	prompt += get_company_employees_info()
	prompt += "\n" + scene_description
	prompt += "\n\nYour current task is: %s" % current_task.description
	prompt += "\n\nWhere do you need to move to complete this task? Based on the objects in your surroundings and the employee roster, choose the most suitable target."
	prompt += "\nReply with only the target's name, with no other text. If there is no suitable target, reply 'No suitable target'."
	print(prompt)
	# Use APIManager to generate the decision
	var character_name = target_character.name if target_character else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Disconnect any existing connection
	if http_request.request_completed.is_connected(_on_task_movement_completed):
		http_request.request_completed.disconnect(_on_task_movement_completed)
	
	# Connect the callback
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_task_movement_completed(result, response_code, headers, body, target_character, current_task)
	)
	waiting_responses[target_character.name] = true

# Handle the task movement API response
func _on_task_movement_completed(result, _response_code, headers, body, char_node = null, current_task = null):
	var target_character = char_node if char_node else character
	
	# Reset waiting state
	waiting_responses[target_character.name] = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Task movement HTTP request for %s failed" % target_character.name)
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Task movement JSON parsing failed for %s" % target_character.name)
		return
	
	# Parse the target
	var target_name = _parse_ai_response(response, target_character)
	if target_name == "":
		print("[AIAgent] Failed to parse task movement API response for %s" % target_character.name)
		return
	
	target_name = target_name.strip_edges()
	print("[AIAgent] %s chose to move to: %s" % [target_character.name, target_name])
	
	if target_name.to_lower().contains("no suitable target"):
		print("[AIAgent] %s found no suitable movement target" % target_character.name)
		_add_memory(target_character, "You wanted to complete the task '%s', but there was no suitable place to move to in your surroundings." % current_task.description)
		return
	
	# Try to find the target and move to it
	var target_info = _find_target_by_name(target_name)
	if not target_info.is_empty():
		var target_display_name = ""
		match target_info.type:
			"object":
				target_display_name = target_info.target.name + " (object)"
			"character":
				target_display_name = target_info.target.name + " (character)"
			"room":
				target_display_name = target_info.target.name + " (room)"
		print("[AIAgent] %s started moving to %s to complete the task" % [target_character.name, target_display_name])
		move_to_target(target_info, target_character)
		_add_memory(target_character, "To complete the task '%s', you moved to %s." % [current_task.description, target_display_name])
	else:
		print("[AIAgent] %s could not find a target named '%s'" % [target_character.name, target_name])
		# Target not found in the current room; ask whether to search other rooms
		await _handle_target_not_found(target_character, target_name, current_task)

# Find a target by name
func _find_target_by_name(target_name: String):
	# Get the current room
	var current_room = room_manager.get_current_room(room_manager.rooms, character.global_position)
	if not current_room:
		return {}
	
	# Search characters
	var room_characters = get_room_characters(current_room)
	for char in room_characters:
		if char.name.to_lower().contains(target_name.to_lower()) or target_name.to_lower().contains(char.name.to_lower()):
			return {"type": "character", "target": char}
	
	# Search objects
	var room_objects = get_room_objects(current_room)
	for obj in room_objects:
		if obj.name.to_lower().contains(target_name.to_lower()) or target_name.to_lower().contains(obj.name.to_lower()):
			return {"type": "object", "target": obj}
	
	# Search rooms
	for room_name in room_manager.rooms:
		var room = room_manager.rooms[room_name]
		if room.name.to_lower().contains(target_name.to_lower()) or target_name.to_lower().contains(room.name.to_lower()):
			return {"type": "room", "target": room}
	
	return {}

# Execute task-related conversation
func _execute_task_conversation(target_character, current_task):
	# If waiting for an API response, skip
	if target_character.name in waiting_responses and waiting_responses[target_character.name]:
		return
	
	# Get all characters (except self)
	var all_characters = get_tree().get_nodes_in_group("characters")
	var available_chars = []
	for char in all_characters:
		if char != target_character:
			available_chars.append(char)
	
	if available_chars.size() == 0:
		print("[AIAgent] %s has no other characters to talk to" % target_character.name)
		_add_memory(target_character, "You wanted to complete the task '%s' by talking to someone, but there was nobody else in the company." % current_task.description)
		return
	
	# Get the character's persona
	var personality = CharacterPersonality.get_personality(target_character.name)
	
	# Build the conversation-partner prompt, including each character's precise location
	var prompt = "You are an office employee named %s. Your position is: %s." % [
		target_character.name,
		personality["position"]
	]
	
	# Add company background and the employee roster
	prompt += get_company_basic_info()
	prompt += get_company_employees_info()
	prompt += "\n\nYour current task is: %s" % current_task.description
	prompt += "\n\nThe following colleagues in the company are available to talk to:"
	for char in available_chars:
		var char_personality = CharacterPersonality.get_personality(char.name)
		var char_room = room_manager.get_current_room(room_manager.rooms, char.global_position)
		var room_name = char_room.name if char_room else "Unknown location"
		var distance = target_character.global_position.distance_to(char.global_position)
		prompt += "\n- %s (%s, location: %s, distance: %.0f meters)" % [char.name, char_personality["position"], room_name, distance]
	
	prompt += "\n\nTo complete this task, who would you most like to talk to? Explain your reasoning, then write only the character's name on the last line."
	
	# Use APIManager to generate the decision
	var character_name = target_character.name if target_character else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Disconnect any existing connection
	if http_request.request_completed.is_connected(_on_task_conversation_completed):
		http_request.request_completed.disconnect(_on_task_conversation_completed)
	
	# Connect the callback
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_task_conversation_completed(result, response_code, headers, body, target_character, current_task, available_chars)
	)
	waiting_responses[target_character.name] = true

# Handle the task conversation API response
func _on_task_conversation_completed(result, _response_code, headers, body, char_node = null, current_task = null, available_chars = []):
	var target_character = char_node if char_node else character
	
	# Reset waiting state
	waiting_responses[target_character.name] = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Task conversation HTTP request for %s failed" % target_character.name)
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Task conversation JSON parsing failed for %s" % target_character.name)
		return
	
	# Parse the chosen character
	var chosen_name = _parse_ai_response(response, target_character)
	if chosen_name == "":
		print("[AIAgent] Failed to parse task conversation API response for %s" % target_character.name)
		return
	
	# Extract the character name from the response (last line)
	var lines = chosen_name.strip_edges().split("\n")
	if lines.size() > 0:
		chosen_name = lines[-1].strip_edges()
	
	print("[AIAgent] %s chose to talk to %s" % [target_character.name, chosen_name])
	
	# Find the matching character
	var chosen_character = null
	for char in available_chars:
		if char.name.to_lower().contains(chosen_name.to_lower()) or chosen_name.to_lower().contains(char.name.to_lower()):
			chosen_character = char
			break
	
	if chosen_character:
		# Check whether the target character is in the same room
		var current_room = room_manager.get_current_room(room_manager.rooms, target_character.global_position)
		var target_room = room_manager.get_current_room(room_manager.rooms, chosen_character.global_position)
		
		if current_room == target_room:
			# Same room: start talking right away
			print("[AIAgent] %s and %s are in the same room, starting conversation" % [target_character.name, chosen_character.name])
			initiate_conversation(chosen_character, target_character)
			_add_memory(target_character, "To complete the task '%s', you talked with %s." % [current_task.description, chosen_character.name])
		else:
			# Not in the same room: move directly to the target character's exact position
			var target_room_name = target_room.name if target_room else "Unknown location"
			print("[AIAgent] %s needs to move to %s to talk with %s" % [target_character.name, target_room_name, chosen_character.name])
			
			# Move directly to the target character's position
			if target_character.has_method("move_to"):
				# Get the target character's exact coordinates
				var target_pos = chosen_character.global_position
				print("[AIAgent] %s moving to (%s, %s) to find %s" % [target_character.name, target_pos.x, target_pos.y, chosen_character.name])
				target_character.move_to(target_pos)
				
				# Add a memory
				_add_memory(target_character, "To complete the task '%s', you need to find %s and talk to them; you are heading to their location in %s (%.0f, %.0f)." % [current_task.description, chosen_character.name, target_room_name, target_pos.x, target_pos.y])
				
				# Use a smarter arrival detection mechanism
				_start_movement_tracking(target_character, chosen_character, current_task)
			else:
				print("[AIAgent] %s cannot move, conversation failed" % target_character.name)
				_add_memory(target_character, "You wanted to find %s and talk to them to complete the task '%s', but you couldn't move." % [chosen_character.name, current_task.description])
	else:
		print("[AIAgent] %s could not find a character named '%s'" % [target_character.name, chosen_name])
		# Default to talking with the first character
		if available_chars.size() > 0:
			var default_char = available_chars[0]
			print("[AIAgent] %s defaulting to a conversation with %s" % [target_character.name, default_char.name])
			
			# Apply the same room check and movement logic for the default character
			var current_room = room_manager.get_current_room(room_manager.rooms, target_character.global_position)
			var target_room = room_manager.get_current_room(room_manager.rooms, default_char.global_position)
			
			if current_room == target_room:
				# Same room: start talking right away
				initiate_conversation(default_char, target_character)
				_add_memory(target_character, "To complete the task '%s', you talked with %s." % [current_task.description, default_char.name])
			else:
				# Not in the same room: move to the default character's position
				if target_character.has_method("move_to"):
					var target_pos = default_char.global_position
					var target_room_name = target_room.name if target_room else "Unknown location"
					print("[AIAgent] %s moving to (%s, %s) to find default character %s" % [target_character.name, target_pos.x, target_pos.y, default_char.name])
					target_character.move_to(target_pos)
					_add_memory(target_character, "To complete the task '%s', you need to find %s and talk to them; you are heading to their location in %s (%.0f, %.0f)." % [current_task.description, default_char.name, target_room_name, target_pos.x, target_pos.y])
					_start_movement_tracking(target_character, default_char, current_task)
				else:
					_add_memory(target_character, "You wanted to talk to someone to complete the task '%s', but couldn't move to a suitable conversation partner." % current_task.description)

# Execute task-related thinking
func _execute_task_thinking(target_character, current_task):
	# If waiting for an API response, skip
	if target_character.name in waiting_responses and waiting_responses[target_character.name]:
		return
	
	# Get the character's persona
	var personality = CharacterPersonality.get_personality(target_character.name)
	var status_info = get_character_status_info(target_character)
	var scene_description = generate_scene_description()
	
	# Build the thinking prompt
	var prompt = "You are an office employee named %s. Your position is: %s. Your personality: %s. Your speaking style: %s." % [
		target_character.name,
		personality["position"],
		personality["personality"],
		personality["speaking_style"]
	]
	
	# Add company background and the employee roster
	prompt += get_company_basic_info()
	prompt += get_company_employees_info()
	prompt += status_info
	prompt += "\n" + scene_description
	prompt += "\n\nYour current task is: %s (desire level: %d)" % [current_task.description, current_task.priority]
	prompt += "\n\nThink about how to complete this task. Consider the following:"
	prompt += "\n- What steps are needed to complete this task?"
	prompt += "\n- What resources or help do you need?"
	prompt += "\n- What difficulties might you run into?"
	prompt += "\n- How does your current status affect carrying out the task?"
	prompt += "\n\nDescribe your thought process in the first person, reflecting your personality and speaking style (100-180 words)."
	
	# Use APIManager to generate thinking content
	var character_name = target_character.name if target_character else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Disconnect any existing connection
	if http_request.request_completed.is_connected(_on_task_thinking_completed):
		http_request.request_completed.disconnect(_on_task_thinking_completed)
	
	# Connect the callback
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_task_thinking_completed(result, response_code, headers, body, target_character, current_task)
	)
	waiting_responses[target_character.name] = true

# Handle the task thinking API response
func _on_task_thinking_completed(result, _response_code, headers, body, char_node = null, current_task = null):
	var target_character = char_node if char_node else character
	
	# Reset waiting state
	waiting_responses[target_character.name] = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Task thinking HTTP request for %s failed" % target_character.name)
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Task thinking JSON parsing failed for %s" % target_character.name)
		return
	
	# Parse the thinking content
	var thinking_content = _parse_ai_response(response, target_character)
	if thinking_content == "":
		print("[AIAgent] Failed to parse task thinking API response for %s" % target_character.name)
		return
	
	thinking_content = thinking_content.strip_edges()
	print("[AIAgent] %s's thoughts on the task '%s':\n%s" % [target_character.name, current_task.description, thinking_content])
	
	# Add a thinking memory
	_add_memory(target_character, "You thought about how to complete the task '%s': %s" % [current_task.description, thinking_content])

# Complete a task
func _complete_task(target_character, current_task):
	# Get the character's metadata
	var metadata = target_character.get_meta("character_data", {})
	var tasks = metadata.get("tasks", [])
	
	# Find the task and mark it as complete
	for i in range(tasks.size()):
		var task = tasks[i]
		if task.description == current_task.description and task.created_at == current_task.created_at:
			task["completed"] = true
			task["completed_at"] = Time.get_unix_time_from_system()
			break
	
	# Save the updated task list
	metadata["tasks"] = tasks
	target_character.set_meta("character_data", metadata)
	
	# Add a task-completion memory
	_add_memory(target_character, "You successfully completed the task: %s. It feels very rewarding!" % current_task.description)
	
	print("[AIAgent] %s completed the task: %s" % [target_character.name, current_task.description])

# Rearrange task priorities (placeholder)
func _rearrange_task_priorities(target_character):
	print("[AIAgent] %s rearranging task priorities (not yet implemented)" % target_character.name)
	_add_memory(target_character, "You reconsidered how your tasks are prioritized.")

# Add an urgent task (placeholder)
func _add_urgent_task(target_character):
	print("[AIAgent] %s adding an urgent task (not yet implemented)" % target_character.name)
	_add_memory(target_character, "You realized there is an urgent task that needs handling.")

# Handle the thinking content API response
func _on_thinking_request_completed(result, _response_code, headers, body, char_node = null):
	# Use the given character node, or the current character if none
	var target_character = char_node if char_node else character
	
	# Reset waiting state
	waiting_responses[target_character.name] = false
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Thinking content HTTP request for %s failed, error code: %s" % [target_character.name, result])
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Thinking content JSON parsing failed for %s" % target_character.name)
		return
	
	# Parse the response through APIConfig
	var thinking_content = _parse_ai_response(response, target_character)
	if thinking_content == "":
		print("[AIAgent] Failed to parse thinking content API response for %s" % target_character.name)
		return
	
	thinking_content = thinking_content.strip_edges()
	
	# Show the thinking content
	print("[AIAgent] Thinking content of %s:\n%s" % [target_character.name, thinking_content])
	
	# More handling of thinking content can go here, e.g. showing it in the UI or affecting character state

# Choose a random target (objects in the room, other characters, and other rooms)
func _choose_random_target() -> Dictionary:
	var all_targets = []
	var current_room = room_manager.get_current_room(room_manager.rooms, character.global_position)
	
	# Add objects in the current room
	var room_objects = get_room_objects(current_room)
	for obj in room_objects:
		all_targets.append({"type": "object", "target": obj, "position": obj.global_position})
	
	# Add other characters in the current room
	var room_characters = get_room_characters(current_room)
	for char in room_characters:
		all_targets.append({"type": "character", "target": char, "position": char.global_position})
	
	# Add other rooms as targets
	for room_name in room_manager.rooms:
		var room = room_manager.rooms[room_name]
		# Exclude the current room
		if current_room == null or room.name != current_room.name:
			all_targets.append({"type": "room", "target": room, "position": room.position})
	
	if all_targets.size() > 0:
		all_targets.shuffle()
		return all_targets[0]
	
	return {}

# Move to a target position (supports objects, characters, and rooms)
func move_to_target(target_info: Dictionary, char_node = null):
	# Use the given character node, or the current character if none
	var target_character = char_node if char_node else character
	var target_controller = target_character
	
	if target_info.is_empty():
		print("[AIAgent] %s has no valid movement target" % target_character.name)
		return
	
	if current_state != State.MOVING:
		current_state = State.MOVING
		var target_name = ""
		var target_position = Vector2.ZERO
		
		match target_info.type:
			"object":
				target_name = target_info.target.name + " (object)"
				# Move near the object, with a small offset to avoid overlapping
				target_position = target_info.target.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			"character":
				target_name = target_info.target.name + " (character)"
				# Move near the character, keeping a reasonable distance
				target_position = target_info.target.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
			"room":
				target_name = target_info.target.name + " (room)"
				# Move to the room's center coordinates
				target_position = target_info.target.position
		
		print("[AIAgent] %s started moving to %s" % [target_character.name, target_name])
		target_controller.move_to(target_position)

# Start a conversation
func initiate_conversation(other_character: Node2D, char_node = null):
	# Use the given character node, or the current character if none
	var target_character = char_node if char_node else character
	
	if current_state != State.TALKING:
		current_state = State.TALKING
		print("[AIAgent] %s is trying to start a conversation with %s" % [target_character.name, other_character.name])
		character_manager.current_character = target_character
		dialog_manager._try_start_conversation()

# Execute the default decision (used when the API fails)
func _execute_default_decision(target_character):
	print("[AIAgent] %s is using the default decision logic" % target_character.name)
	
	# Get current tasks
	var tasks = target_character.get_meta("tasks", [])
	if tasks.is_empty():
		# If there are no tasks, generate default tasks
		_generate_default_tasks(target_character)
		return
	
	# Randomly choose a decision (1 or 2)
	var random_decision = randi() % 2 + 1
	var decision = str(random_decision)
	
	print("[AIAgent] Default decision result for %s: %s" % [target_character.name, decision])
	match decision:
		"1":  # Adjust tasks
			print("[AIAgent] %s decided to adjust tasks (default)" % target_character.name)
			_adjust_tasks_default(target_character)
		"2":  # Continue current task
			print("[AIAgent] %s decided to continue the current task (default)" % target_character.name)
			_continue_current_task_default(target_character)

# Generate default tasks (used when the API fails)
func _generate_default_tasks(target_character):
	print("[AIAgent] %s generating the default task list" % target_character.name)
	
	# Create 10 default tasks
	var default_tasks = []
	for i in range(10):
		var task = _generate_random_task(target_character)
		if task:
			default_tasks.append(task)
	
	# Sort by priority
	default_tasks.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Save tasks to the character's metadata
	target_character.set_meta("tasks", default_tasks)
	
	# Add a task-generation memory
	var memories = target_character.get_meta("memories", [])
	memories.append("You made a new task plan for yourself with %d important tasks, and you're ready to get started." % default_tasks.size())
	target_character.set_meta("memories", memories)
	
	print("[AIAgent] %s generated %d default tasks" % [target_character.name, default_tasks.size()])

# Default task adjustment logic
func _adjust_tasks_default(target_character):
	print("[AIAgent] %s performing default task adjustment" % target_character.name)
	
	# Randomly choose an adjustment type
	var adjustment_type = randi() % 3 + 1
	match adjustment_type:
		1:  # Keep unchanged
			print("[AIAgent] %s decided to keep the current task priorities (default)" % target_character.name)
			_add_memory(target_character, "You reviewed your current task list and decided to keep the existing priorities.")
		2:  # Rearrange
			print("[AIAgent] %s decided to rearrange task priorities (default)" % target_character.name)
			_rearrange_task_priorities_default(target_character)
		3:  # Add a new task
			print("[AIAgent] %s decided to add a new urgent task (default)" % target_character.name)
			_add_urgent_task_default(target_character)

# Default continue-current-task logic
func _continue_current_task_default(target_character):
	print("[AIAgent] %s performing default task continuation logic" % target_character.name)
	
	var tasks = target_character.get_meta("tasks", [])
	if tasks.is_empty():
		print("[AIAgent] %s has no tasks to execute, generating new tasks" % target_character.name)
		_generate_default_tasks(target_character)
		return
	
	# Get the highest-priority task
	var current_task = tasks[0]
	print("[AIAgent] %s continuing task: %s (default)" % [target_character.name, current_task.description])
	
	# Add a memory
	_add_memory(target_character, "You kept focusing on your current most important task: %s" % current_task.description)
	
	# Randomly choose an execution type
	var execution_type = randi() % 2 + 1
	match execution_type:
		1:  # Move to a relevant location
			_execute_task_movement_default(target_character, current_task)
		2:  # Talk to a relevant character
			_execute_task_conversation_default(target_character, current_task)

# Default task priority rearrangement
func _rearrange_task_priorities_default(target_character):
	var tasks = target_character.get_meta("tasks", [])
	if tasks.size() < 2:
		return
	
	# Randomly reshuffle the priority of the first few tasks
	for i in range(min(3, tasks.size())):
		tasks[i].priority = randi() % 10 + 1
	
	# Re-sort
	tasks.sort_custom(func(a, b): return a.priority > b.priority)
	target_character.set_meta("tasks", tasks)
	
	_add_memory(target_character, "You readjusted your task priorities and are now focusing on what matters most.")
	print("[AIAgent] %s rearranged task priorities (default)" % target_character.name)

# Default urgent task addition
func _add_urgent_task_default(target_character):
	var urgent_tasks = [
		"Handle urgent emails",
		"Attend an ad-hoc meeting",
		"Deal with an unexpected problem",
		"Help a colleague finish their work",
		"Prepare an important report"
	]
	
	var urgent_task = {
		"description": urgent_tasks[randi() % urgent_tasks.size()],
		"priority": randi() % 3 + 8,  # High priority 8-10
		"created_at": Time.get_unix_time_from_system(),
		"completed": false
	}
	
	var tasks = target_character.get_meta("tasks", [])
	tasks.append(urgent_task)
	tasks.sort_custom(func(a, b): return a.priority > b.priority)
	target_character.set_meta("tasks", tasks)
	
	_add_memory(target_character, "You added a new urgent task: %s" % urgent_task.description)
	print("[AIAgent] %s added an urgent task: %s (default)" % [target_character.name, urgent_task.description])

# Default task movement
func _execute_task_movement_default(target_character, current_task):
	# Move to a random room
	var room_names = room_manager.rooms.keys()
	if room_names.size() > 0:
		var random_room_name = room_names[randi() % room_names.size()]
		var room = room_manager.rooms[random_room_name]
		# The CharacterController script is attached directly to the character's root node
		if target_character and target_character.has_method("move_to"):
			print("[AIAgent] %s moving to %s to work on the task (default)" % [target_character.name, random_room_name])
			target_character.move_to(room.position)
			_add_memory(target_character, "You moved to %s to work on the task: %s" % [random_room_name, current_task.description])

# Default task conversation
func _execute_task_conversation_default(target_character, current_task):
	# Talk to a random character
	var characters = get_tree().get_nodes_in_group("character")
	var available_chars = []
	for char in characters:
		if char != target_character:
			available_chars.append(char)
	
	if available_chars.size() > 0:
		var random_char = available_chars[randi() % available_chars.size()]
		print("[AIAgent] %s talking with %s to work on the task (default)" % [target_character.name, random_char.name])
		initiate_conversation(random_char, target_character)

# Handle the case where the target cannot be found
func _handle_target_not_found(target_character, target_name: String, current_task):
	# If waiting for an API response, skip
	if target_character.name in waiting_responses and waiting_responses[target_character.name]:
		return
	
	# Get the character's persona
	var personality = CharacterPersonality.get_personality(target_character.name)
	
	# Get the list of all rooms
	var room_names = []
	for room_name in room_manager.rooms:
		room_names.append(room_name)
	
	# Build the decision prompt
	var prompt = "You are an office employee named %s. Your position is: %s." % [
		target_character.name,
		personality["position"]
	]
	
	prompt += "\n\nYour current task is: %s" % current_task.description
	prompt += "\nYou want to find '%s' to complete this task, but this target is not in the current room." % target_name
	prompt += "\n\nThe company has the following rooms: %s" % ", ".join(room_names)
	prompt += "\n\nChoose your action:"
	prompt += "\n1. Go to another room to look for '%s'" % target_name
	prompt += "\n2. Stay where you are and reschedule the task"
	prompt += "\n\nReply with only the number 1 or 2, with no other text."
	
	print(prompt)
	
	# Use APIManager to generate the decision
	var character_name = target_character.name if target_character else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Disconnect any existing connection
	if http_request.request_completed.is_connected(_on_target_not_found_decision_completed):
		http_request.request_completed.disconnect(_on_target_not_found_decision_completed)
	
	# Connect the callback
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_target_not_found_decision_completed(result, response_code, headers, body, target_character, target_name, current_task)
	)
	waiting_responses[target_character.name] = true

# Handle the target-not-found decision API response
func _on_target_not_found_decision_completed(result, _response_code, headers, body, char_node = null, target_name: String = "", current_task = null):
	var target_character = char_node if char_node else character
	
	# Reset waiting state
	waiting_responses[target_character.name] = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Target-not-found decision HTTP request for %s failed" % target_character.name)
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Target-not-found decision JSON parsing failed for %s" % target_character.name)
		return
	
	# Parse the decision
	var decision = _parse_ai_response(response, target_character)
	if decision == "":
		print("[AIAgent] Failed to parse target-not-found decision API response for %s" % target_character.name)
		return
	
	decision = decision.strip_edges()
	print("[AIAgent] Target-not-found decision for %s: %s" % [target_character.name, decision])
	
	match decision:
		"1":  # Search other rooms
			print("[AIAgent] %s decided to search other rooms for '%s'" % [target_character.name, target_name])
			await _choose_room_to_search(target_character, target_name, current_task)
		"2":  # Reschedule the task
			print("[AIAgent] %s decided to reschedule the task" % target_character.name)
			_add_memory(target_character, "You were going to find '%s' to complete the task '%s', but couldn't find it, so you need to reschedule the task." % [target_name, current_task.description])
			await _reschedule_task(target_character, current_task, target_name)
		_:
			print("[AIAgent] Invalid target-not-found decision for %s: %s" % [target_character.name, decision])
			_add_memory(target_character, "You wanted to find '%s' to complete a task, but couldn't find this target." % target_name)

# Choose a room to search
func _choose_room_to_search(target_character, target_name: String, current_task):
	# If waiting for an API response, skip
	if target_character.name in waiting_responses and waiting_responses[target_character.name]:
		return
	
	# Get the character's persona
	var personality = CharacterPersonality.get_personality(target_character.name)
	
	# Get the current room
	var current_room = room_manager.get_current_room(room_manager.rooms, target_character.global_position)
	var current_room_name = current_room.name if current_room else "Unknown room"
	
	# Get the list of all rooms (excluding the current one)
	var room_names = []
	for room_name in room_manager.rooms:
		if room_name != current_room_name:
			room_names.append(room_name)
	
	if room_names.size() == 0:
		print("[AIAgent] %s has no other rooms to search" % target_character.name)
		_add_memory(target_character, "You wanted to search other rooms for '%s', but there were no other rooms to go to." % target_name)
		return
	
	# Build the room selection prompt
	var prompt = "You are an office employee named %s. Your position is: %s." % [
		target_character.name,
		personality["position"]
	]
	
	prompt += "\n\nYour current task is: %s" % current_task.description
	prompt += "\nYou want to find '%s' to complete this task, but couldn't find it in the current room '%s'." % [target_name, current_room_name]
	prompt += "\n\nYou can search the following rooms:"
	for i in range(room_names.size()):
		prompt += "\n%d. %s" % [i + 1, room_names[i]]
	
	prompt += "\n\nChoose the room you want to go to. Reply with only the corresponding number (1-%d), with no other text." % room_names.size()
	
	print(prompt)
	
	# Use APIManager to generate the decision
	var character_name = target_character.name if target_character else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Disconnect any existing connection
	if http_request.request_completed.is_connected(_on_room_choice_completed):
		http_request.request_completed.disconnect(_on_room_choice_completed)
	
	# Connect the callback
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_room_choice_completed(result, response_code, headers, body, target_character, target_name, current_task, room_names)
	)
	waiting_responses[target_character.name] = true

# Handle the room choice API response
func _on_room_choice_completed(result, _response_code, headers, body, char_node = null, target_name: String = "", current_task = null, room_names: Array = []):
	var target_character = char_node if char_node else character
	
	# Reset waiting state
	waiting_responses[target_character.name] = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Room choice HTTP request for %s failed" % target_character.name)
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Room choice JSON parsing failed for %s" % target_character.name)
		return
	
	# Parse the choice
	var choice = _parse_ai_response(response, target_character)
	if choice == "":
		print("[AIAgent] Failed to parse room choice API response for %s" % target_character.name)
		return
	
	choice = choice.strip_edges()
	print("[AIAgent] Room chosen by %s: %s" % [target_character.name, choice])
	
	# Validate the choice
	var choice_index = choice.to_int() - 1
	if choice_index >= 0 and choice_index < room_names.size():
		var selected_room_name = room_names[choice_index]
		var selected_room = room_manager.rooms[selected_room_name]
		
		print("[AIAgent] %s started moving to %s to look for '%s'" % [target_character.name, selected_room_name, target_name])
		
		# Move to the chosen room
		if target_character and target_character.has_method("move_to"):
			target_character.move_to(selected_room.position)
			_add_memory(target_character, "To find '%s' and complete the task '%s', you moved to %s." % [target_name, current_task.description, selected_room_name])
	else:
		print("[AIAgent] Invalid room choice for %s: %s" % [target_character.name, choice])
		_add_memory(target_character, "You wanted to pick a room to search for '%s', but the choice was invalid." % target_name)

# Reschedule a task
func _reschedule_task(target_character, current_task, failed_target_name: String):
	# If waiting for an API response, skip
	if target_character.name in waiting_responses and waiting_responses[target_character.name]:
		return
	
	# Get the character's persona
	var personality = CharacterPersonality.get_personality(target_character.name)
	
	# Get the scene description
	var scene_description = generate_scene_description()
	
	# Build the task rescheduling prompt
	var prompt = "You are an office employee named %s. Your position is: %s." % [
		target_character.name,
		personality["position"]
	]
	
	# Add company background and the employee roster
	prompt += get_company_basic_info()
	prompt += get_company_employees_info()
	prompt += "\n" + scene_description
	
	prompt += "\n\nYour original task was: %s" % current_task.description
	prompt += "\nBut you couldn't find '%s' to complete this task." % failed_target_name
	prompt += "\n\nPlease come up with a new task. This task should:"
	prompt += "\n1. Suit your position and current surroundings"
	prompt += "\n2. Be achievable in your current surroundings"
	prompt += "\n3. Make sense for office work"
	prompt += "\n\nReply with only the new task's description, with no other text."
	
	print(prompt)
	
	# Use APIManager to generate the new task
	var character_name = target_character.name if target_character else "Unknown"
	var http_request = await api_manager.generate_dialog(prompt, character_name)
	
	# Disconnect any existing connection
	if http_request.request_completed.is_connected(_on_reschedule_task_completed):
		http_request.request_completed.disconnect(_on_reschedule_task_completed)
	
	# Connect the callback
	http_request.request_completed.connect(func(result, response_code, headers, body): 
		_on_reschedule_task_completed(result, response_code, headers, body, target_character, current_task)
	)
	waiting_responses[target_character.name] = true

# Handle the task rescheduling API response
func _on_reschedule_task_completed(result, _response_code, headers, body, char_node = null, old_task = null):
	var target_character = char_node if char_node else character
	
	# Reset waiting state
	waiting_responses[target_character.name] = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[AIAgent] Task rescheduling HTTP request for %s failed" % target_character.name)
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response:
		print("[AIAgent] Task rescheduling JSON parsing failed for %s" % target_character.name)
		return
	
	# Parse the new task
	var new_task_description = _parse_ai_response(response, target_character)
	if new_task_description == "":
		print("[AIAgent] Failed to parse task rescheduling API response for %s" % target_character.name)
		return
	
	new_task_description = new_task_description.strip_edges()
	print("[AIAgent] New rescheduled task for %s: %s" % [target_character.name, new_task_description])
	
	# Update the task
	var metadata = target_character.get_meta("character_data", {})
	if not metadata.has("current_task"):
		metadata["current_task"] = {}
	
	metadata["current_task"]["description"] = new_task_description
	metadata["current_task"]["start_time"] = Time.get_unix_time_from_system()
	target_character.set_meta("character_data", metadata)
	
	_add_memory(target_character, "Since you couldn't find the target, you rescheduled a new task: %s" % new_task_description)
	print("[AIAgent] Task for %s updated to: %s" % [target_character.name, new_task_description])

# Get the character's conversation partner
func _get_conversation_partner(character: CharacterBody2D) -> CharacterBody2D:
	if not dialog_manager or not dialog_manager.dialog_service:
		return null
	
	# Get the list of conversation IDs the character is in
	var conversation_ids = dialog_manager.dialog_service.get_character_conversations(character)
	if conversation_ids.is_empty():
		return null
	
	# Get the partner from the first conversation
	var conversation_id = conversation_ids[0]
	var active_conversations = dialog_manager.dialog_service.active_conversations
	if not active_conversations.has(conversation_id):
		return null
	
	var conversation = active_conversations[conversation_id]
	if conversation.speaker == character:
		return conversation.listener
	else:
		return conversation.speaker

# Start movement tracking to detect when the character reaches the target
func _start_movement_tracking(moving_character: CharacterBody2D, target_character: CharacterBody2D, current_task):
	var tracking_data = {
		"moving_character": moving_character,
		"target_character": target_character,
		"current_task": current_task,
		"start_time": Time.get_unix_time_from_system(),
		"last_position": moving_character.global_position,
		"stuck_time": 0.0,
		"check_count": 0
	}
	
	# Create a timer for periodic checks
	var tracking_timer = Timer.new()
	tracking_timer.wait_time = 0.5  # Check every 0.5 seconds
	tracking_timer.timeout.connect(func(): _check_movement_progress(tracking_data, tracking_timer))
	moving_character.add_child(tracking_timer)
	tracking_timer.start()
	
	print("[AIAgent] Started tracking %s's progress moving to %s" % [moving_character.name, target_character.name])

# Check movement progress
func _check_movement_progress(tracking_data: Dictionary, tracking_timer: Timer):
	var moving_char = tracking_data["moving_character"]
	var target_char = tracking_data["target_character"]
	var current_task = tracking_data["current_task"]
	var start_time = tracking_data["start_time"]
	var last_pos = tracking_data["last_position"]
	
	tracking_data["check_count"] += 1
	var current_time = Time.get_unix_time_from_system()
	var elapsed_time = current_time - start_time
	var current_pos = moving_char.global_position
	var distance_to_target = current_pos.distance_to(target_char.global_position)
	
	# Check whether the target has been reached (within talking distance)
	if distance_to_target <= 150:
		print("[AIAgent] %s reached %s, starting conversation" % [moving_char.name, target_char.name])
		initiate_conversation(target_char, moving_char)
		_add_memory(moving_char, "To complete the task '%s', you found %s and talked with them." % [current_task.description, target_char.name])
		_cleanup_tracking_timer(tracking_timer)
		return
	
	# Check whether stuck (position hasn't changed noticeably)
	var movement_distance = current_pos.distance_to(last_pos)
	if movement_distance < 10:  # Moving less than 10 pixels likely means stuck
		tracking_data["stuck_time"] += tracking_timer.wait_time
	else:
		tracking_data["stuck_time"] = 0.0
		tracking_data["last_position"] = current_pos
	
	# Timed out or stuck too long; give up moving
	if elapsed_time > 15.0 or tracking_data["stuck_time"] > 5.0:
		var reason = "timed out" if elapsed_time > 15.0 else "stuck"
		print("[AIAgent] %s failed to move to %s: %s (distance: %.0f)" % [moving_char.name, target_char.name, reason, distance_to_target])
		_add_memory(moving_char, "You tried to find %s and talk to them to complete the task '%s', but ran into a problem while moving (%s)." % [target_char.name, current_task.description, reason])
		_cleanup_tracking_timer(tracking_timer)
		return
	
	# Print progress every 10 checks
	if tracking_data["check_count"] % 10 == 0:
		print("[AIAgent] %s movement progress: %.0f pixels from %s" % [moving_char.name, distance_to_target, target_char.name])

# Clean up the tracking timer
func _cleanup_tracking_timer(tracking_timer: Timer):
	if tracking_timer and is_instance_valid(tracking_timer):
		tracking_timer.stop()
		tracking_timer.queue_free()
