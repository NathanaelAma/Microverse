extends RefCounted
class_name ConversationManager

# Conversation participants
var speaker: CharacterBody2D
var listener: CharacterBody2D
var conversation_id: String
var is_active: bool = false

# Scene references used by the conversation
var dialog_bubble_scene = preload("res://scene/ui/DialogBubble.tscn")
var chat_history_scene = preload("res://scene/ChatHistory.tscn")

# AI-related script references
var MemoryManager = preload("res://script/ai/memory/MemoryManager.gd")
var BackgroundStoryManager = preload("res://script/ai/background_story/BackgroundStoryManager.gd")

# HTTP request object
var http_request: HTTPRequest
# Name of the character that sent the current request (the response must be parsed with that character's AI settings)
var request_character_name: String = ""

# Signals
signal conversation_ended(conversation_id: String)
signal dialog_generated(speaker_name: String, dialog_text: String)

func _init(p_speaker: CharacterBody2D, p_listener: CharacterBody2D):
	speaker = p_speaker
	listener = p_listener
	conversation_id = generate_conversation_id()
	is_active = true
	
	# Make sure the speaker has a ChatHistory node
	if not speaker.has_node("ChatHistory"):
		var chat_history = chat_history_scene.instantiate()
		speaker.add_child(chat_history)
	
	# Make sure the listener has a ChatHistory node too
	if not listener.has_node("ChatHistory"):
		var chat_history = chat_history_scene.instantiate()
		listener.add_child(chat_history)

func generate_conversation_id() -> String:
	return "%s_%s_%d" % [speaker.name, listener.name, Time.get_unix_time_from_system()]

# Start the conversation
func start_conversation():
	if not is_active:
		return
	
	print("[ConversationManager] Starting conversation: %s <-> %s" % [speaker.name, listener.name])
	await generate_dialog()

# End the conversation
func end_conversation():
	if not is_active:
		return
	
	print("[ConversationManager] Ending conversation: %s" % conversation_id)
	
	# Save chat history
	if speaker and speaker.has_node("ChatHistory"):
		var history_node = speaker.get_node("ChatHistory")
		history_node.save_history()
	
	if listener and listener.has_node("ChatHistory"):
		var history_node = listener.get_node("ChatHistory")
		history_node.save_history()
	
	# Clean up the HTTP request
	if http_request and is_instance_valid(http_request):
		http_request.queue_free()
	
	is_active = false
	conversation_ended.emit(conversation_id)

# Generate dialog content
func generate_dialog():
	if not is_active:
		return
	
	print("\n[Dialog System] Starting dialog generation")
	print("[Dialog System] Speaker: ", speaker.name)
	print("[Dialog System] Listener: ", listener.name)
	
	# Get the speaker's and listener's personas
	var speaker_personality = CharacterPersonality.get_personality(speaker.name)
	var listener_personality = CharacterPersonality.get_personality(listener.name)
	
	# Get the speaker's detailed status info (including memories)
	var speaker_status = get_character_status_info(speaker)
	
	# Get company background and the employee roster
	var company_basic_info = get_company_basic_info()
	var company_info = get_company_employees_info()
	
	# Get the speaker's current tasks
	var speaker_tasks = get_character_tasks(speaker)
	
	# Get previous chat history
	var chat_history = ""
	if speaker.has_node("ChatHistory"):
		var history_node = speaker.get_node("ChatHistory")
		chat_history = history_node.get_recent_conversation_with(listener.name, 5)
	
	# Build the dialog prompt (without the listener's memories)
	var prompt = build_dialog_prompt(speaker_personality, listener_personality, 
									 speaker_status, "", company_basic_info, company_info, 
									 speaker_tasks, chat_history)
	
	print("[Dialog System] Generated prompt:\n", prompt)
	
	# Use APIManager to generate the dialog
	var api_manager = null
	var main_loop = Engine.get_main_loop() as SceneTree
	if main_loop and main_loop.root:
		api_manager = main_loop.root.get_node("APIManager")
	
	if not api_manager:
		print("[ConversationManager] Could not get APIManager")
		return
	
	# Use the speaker's AI settings (supports per-character AI settings)
	request_character_name = speaker.name
	http_request = await api_manager.generate_dialog(prompt, request_character_name)
	
	# Connect the callback
	if http_request and not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

# Build the dialog prompt
func build_dialog_prompt(speaker_personality: Dictionary, listener_personality: Dictionary,
						 speaker_status: String, listener_status: String, 
						 company_basic_info: String, company_info: String, speaker_tasks: String, 
						 chat_history: String) -> String:
	
	# Get the background story and social rules
	var background_prompt = BackgroundStoryManager.generate_background_prompt()
	
	var prompt = "You are an employee named %s. Your position is: %s. Your personality: %s. Your speaking style: %s." % [
		speaker.name,
		speaker_personality["position"],
		speaker_personality["personality"],
		speaker_personality["speaking_style"]
	]
	
	# Add the background story and social rules
	if not background_prompt.is_empty():
		prompt += "\n\n" + background_prompt
	
	# Add company background and the employee roster
	prompt += company_basic_info
	prompt += company_info
	
	# Add the speaker's status info (including their own memories)
	prompt += speaker_status
	
	# Add current task info
	prompt += speaker_tasks
	
	# Add basic listener info (excluding their memories and detailed status)
	prompt += "\n\nYou are talking with %s. %s's position is: %s. %s's personality: %s." % [
		listener.name,
		listener.name,
		listener_personality["position"],
		listener.name,
		listener_personality["personality"]
	]
	
	# Note: the listener's detailed status (including memories) is no longer added, since that is the other person's private information
	
	# Add chat history
	if chat_history != "":
		prompt += "\n\nYour previous conversation:\n" + chat_history
	
	# Add dialog guidelines
	prompt += "\n\nBased on your personality, current status, mood, tasks, and relationship with the other person, write a natural line of dialog."
	prompt += "\nNotes:"
	prompt += "\n- Reflect your personality traits and speaking style"
	prompt += "\n- Take your current mood and health into account"
	prompt += "\n- Adjust how familiar you are based on your relationship"
	prompt += "\n- Mention relevant memories if there are any"
	prompt += "\n- You can chat about your current task; recent unexpected memories take priority over tasks."
	prompt += "\n- Keep the conversation natural and flowing, not too formal"
	prompt += "\n- Keep it to 1-3 sentences, under 30 words"
	prompt += "\n- Return only what you would say, without any descriptions, actions, or anything else"
	prompt += "\n- Speak directly like a real person, without a prefix like 'You say:'"
	
	return prompt

# HTTP request completed callback
func _on_request_completed(result, response_code, headers, body):
	if not is_active:
		return
	
	print("\n[Dialog System] Received API response")
	print("[Dialog System] Response status code: ", response_code)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[Dialog System] HTTP request failed, error code: ", result)
		return
	

	
	var response = JSON.parse_string(body.get_string_from_utf8())
	var dialog_text = ""
	if not response is Dictionary:
		print("[Dialog System] Failed to parse response JSON")
		return
	
	# Get APIManager
	var api_manager = null
	var main_loop = Engine.get_main_loop() as SceneTree
	if main_loop and main_loop.root:
		api_manager = main_loop.root.get_node_or_null("APIManager")
	
	if not api_manager:
		print("[ConversationManager] Could not get APIManager")
		return
	
	# Parse the response with the API type of the character that sent the request (consistent with the request settings)
	var api_type = api_manager.get_api_type_for(request_character_name)
	dialog_text = APIConfig.parse_response(api_type, response, request_character_name)
	if dialog_text == "":
		print("[Dialog System] Failed to parse response")
		return
	
	# Create a dialog bubble and show the dialog content
	var dialog_bubble = dialog_bubble_scene.instantiate()
	Engine.get_main_loop().root.add_child(dialog_bubble)
	# Target the speaking character so the bubble follows it automatically
	dialog_bubble.target_node = speaker
	dialog_bubble.show_dialog(dialog_text)
	print("[Dialog System] Generated dialog: ", dialog_text)
	
	# Save the dialog to both participants' ChatHistory
	# Message format: "Speaker: message content"
	var formatted_message = speaker.name + ": " + dialog_text
	
	if speaker.has_node("ChatHistory"):
		var speaker_history = speaker.get_node("ChatHistory")
		speaker_history.add_message(listener.name, formatted_message)
		print("Speaker chat history saved")
	
	if listener.has_node("ChatHistory"):
		var listener_history = listener.get_node("ChatHistory")
		listener_history.add_message(speaker.name, formatted_message)
		print("Listener chat history saved")
	
	# Emit the dialog generated signal
	dialog_generated.emit(speaker.name, dialog_text)
	
	# Let the other character reply
	if listener and is_active:
		# Swap speaker and listener
		var temp = speaker
		speaker = listener
		listener = temp
		# Generate the other character's reply
		await generate_dialog()

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

# Get detailed character status info
func get_character_status_info(character: CharacterBody2D) -> String:
	if not character:
		return "\nCurrent status information is unavailable."
	
	# Read data from the character node
	var money = character.get_meta("money", 0)
	var mood = character.get_meta("mood", "Normal")
	var health = character.get_meta("health", "Good")
	var relations = character.get_meta("relations", {})
	
	var status_info = "\n\n[Current personal status]"
	status_info += "\n💰 Money: %d yuan" % money
	status_info += "\n😊 Mood: %s" % mood
	status_info += "\n❤️ Health: %s" % health
	
	# Use MemoryManager to get formatted memories
	status_info += "\n\n[Memories]"
	var memory_manager = MemoryManager.new()
	var memory_text = memory_manager.get_formatted_memories_for_prompt(character)
	# Strip the leading header, since a section title has already been added above
	if memory_text.begins_with("\n\nMemories:"):
		memory_text = memory_text.trim_prefix("\n\nMemories:")  # Must match the header produced by MemoryManager.get_formatted_memories_for_prompt()
	status_info += memory_text
	
	status_info += "\n\n[Relationships]"
	if relations.size() > 0:
		for person_name in relations:
			var relation = relations[person_name]
			var emotion_type = relation["type"] if relation.has("type") else "Unknown"
			var strength = relation["strength"] if relation.has("strength") else 0
			status_info += "\n- With %s: %s (strength: %d)" % [person_name, emotion_type, strength]
	else:
		status_info += "\n- No special relationships yet"
	
	return status_info

# Get character task info
func get_character_tasks(character: CharacterBody2D) -> String:
	var speaker_tasks = ""
	var speaker_metadata = character.get_meta("character_data", {})
	var tasks = speaker_metadata.get("tasks", [])
	if tasks.size() > 0:
		# Get incomplete tasks
		var active_tasks = []
		for task in tasks:
			if not task.get("completed", false):
				active_tasks.append(task)
		
		if active_tasks.size() > 0:
			# Sort by priority and get the most important task
			active_tasks.sort_custom(func(a, b): return a.priority > b.priority)
			var current_task = active_tasks[0]
			speaker_tasks = "\n\nYour current most important task is: %s (desire level: %d)" % [current_task.description, current_task.priority]
			if active_tasks.size() > 1:
				speaker_tasks += "\nYou have %d other pending tasks." % (active_tasks.size() - 1)
	
	return speaker_tasks
