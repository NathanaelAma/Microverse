extends Node

# Dialog service instance
var dialog_service: DialogService

# Current settings (from SettingsManager)
var current_settings = {}

# Compatibility variables (kept for compatibility with existing code)
var current_speaker: CharacterBody2D = null
var current_listener: CharacterBody2D = null
var is_in_conversation = false

func _ready():
	# Create the dialog service
	dialog_service = DialogService.new()
	add_child(dialog_service)
	
	# Connect dialog service signals
	dialog_service.conversation_started.connect(_on_conversation_started)
	dialog_service.conversation_ended.connect(_on_conversation_ended)
	dialog_service.dialog_generated.connect(_on_dialog_generated)
	
	set_process_input(true)
	
	# Connect to the settings manager
	SettingsManager.settings_changed.connect(_on_settings_changed)
	current_settings = SettingsManager.get_settings()
	print("[DialogManager] Connected to settings manager and dialog service")

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
	var memories = character.get_meta("memories", [])
	var relations = character.get_meta("relations", {})
	
	var status_info = "\n\n[Current personal status]"
	status_info += "\n💰 Money: %d yuan" % money
	status_info += "\n😊 Mood: %s" % mood
	status_info += "\n❤️ Health: %s" % health
	
	status_info += "\n\n[Memories]"
	if memories.size() > 0:
		for i in range(min(3, memories.size())):
			status_info += "\n- " + memories[i]
	else:
		status_info += "\n- No important memories yet"
	
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

# Handle input events
func _input(event):
	if event.is_action_pressed("start_dialog"):  # T key
		# Multiple conversations may run at once, so is_in_conversation is no longer checked
		_try_start_conversation()
	elif event.is_action_pressed("end_dialog"):  # L key
		# End the conversations the current character is in, not all conversations
		_end_current_character_conversation()
	elif event.is_action_pressed("ui_cancel"):  # ESC key
		# Show the settings UI
		var settings_ui = get_node_or_null("/root/Office/SettingsUI")
		if settings_ui:
			settings_ui.toggle_settings_ui()

# Try to start a conversation
func _try_start_conversation():
	# Get the currently selected character
	var character_manager = get_node("/root/CharacterManager")
	if not character_manager or not character_manager.current_character:
		return
	
	# Get another character near the selected character
	var nearby_character = character_manager.get_nearby_character(character_manager.current_character)
	if nearby_character:
		# Start the conversation with the new dialog service
		var success = dialog_service.try_start_conversation(character_manager.current_character, nearby_character)
		if success:
			print("[DialogManager] Conversation started successfully")
			# Add a memory for the character who started the conversation
			_add_memory_to_current_character(character_manager.current_character, "You started a conversation with %s." % nearby_character.name)
			# Add a memory for the other character as well
			_add_memory_to_current_character(nearby_character, "%s started a conversation with you." % character_manager.current_character.name)
		else:
			print("[DialogManager] Could not start conversation")

# End the conversations the current character is in
func _end_current_character_conversation():
	var character_manager = get_node("/root/CharacterManager")
	if not character_manager or not character_manager.current_character:
		print("[DialogManager] No character selected")
		return
	# Before ending, add an end-of-conversation memory for every conversation the current character is in
	var current_character = character_manager.current_character
	var active_conversations = dialog_service.get_active_conversations_info()
	
	for conversation_info in active_conversations:
		var speaker_name = conversation_info["speaker"]
		var listener_name = conversation_info["listener"]
		
		# If the current character is in this conversation, add an end memory for both participants
		if speaker_name == current_character.name or listener_name == current_character.name:
			_add_conversation_memory_to_participants(speaker_name, listener_name, "ended the conversation")
   
	# End all conversations the current character is in
	dialog_service.end_character_conversations(current_character)
	print("[DialogManager] Ended the current character's conversations")

# End all conversations (original function kept for other callers)
func _end_conversation():
	# If there are active conversations, end them all
	if dialog_service.get_active_conversation_count() > 0:
		dialog_service.cleanup_all_conversations()
		print("[DialogManager] Ended all conversations")
	else:
		print("[DialogManager] No active conversations")

# Find the nearest NPC
func _find_nearest_npc(player: Node2D) -> Node2D:
	var npcs = get_tree().get_nodes_in_group("npc")
	var nearest_distance = INF
	var nearest_npc = null
	
	for npc in npcs:
		var distance = player.global_position.distance_to(npc.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_npc = npc
	
	return nearest_npc

# Check whether within dialog range
func _is_in_range(node1: Node2D, node2: Node2D) -> bool:
	var max_dialog_distance = 100  # Adjust the dialog distance as needed
	return node1.global_position.distance_to(node2.global_position) <= max_dialog_distance

# Settings changed callback
func _on_settings_changed(new_settings: Dictionary):
	current_settings = new_settings.duplicate()
	print("[DialogManager] Settings updated - API type: ", current_settings.api_type, ", model: ", current_settings.model)

# Dialog service signal callbacks
func _on_conversation_started(conversation_id: String, speaker_name: String, listener_name: String):
	print("[DialogManager] Conversation started: %s <-> %s (ID: %s)" % [speaker_name, listener_name, conversation_id])
	
	# Add a conversation-start memory to the participants
	_add_conversation_memory_to_participants(speaker_name, listener_name, "started a conversation")
	
	# Update compatibility variables (using the first active conversation)
	var conversations = dialog_service.get_active_conversations_info()
	if conversations.size() > 0:
		is_in_conversation = true
		# These could be set to the latest conversation participants, but with multiple conversations their meaning has changed
		# Mainly kept for compatibility with existing code

func _on_conversation_ended(conversation_id: String):
	print("[DialogManager] Conversation ended: %s" % conversation_id)
	
	# Get the ended conversation's info and add memories
	_add_conversation_end_memory(conversation_id)
	
	# Update compatibility variables
	if dialog_service.get_active_conversation_count() == 0:
		is_in_conversation = false
		current_speaker = null
		current_listener = null

func _on_dialog_generated(conversation_id: String, speaker_name: String, dialog_text: String):
	print("[DialogManager] Dialog generated: %s said: %s" % [speaker_name, dialog_text])

# Convenience methods for accessing dialog service features
func get_active_conversation_count() -> int:
	return dialog_service.get_active_conversation_count() if dialog_service else 0

func get_active_conversations_info() -> Array:
	return dialog_service.get_active_conversations_info() if dialog_service else []

func is_character_in_conversation(character: CharacterBody2D) -> bool:
	return dialog_service.is_character_in_conversation(character) if dialog_service else false

func end_character_conversations(character: CharacterBody2D):
	if dialog_service:
		dialog_service.end_character_conversations(character)

# Add a conversation memory to the participants
func _add_conversation_memory_to_participants(speaker_name: String, listener_name: String, action: String):
	# Get the character nodes
	var speaker_node = _find_character_by_name(speaker_name)
	var listener_node = _find_character_by_name(listener_name)
	
	# Add a memory for the speaker
	if speaker_node:
		_add_memory_to_character(speaker_node, "You %s with %s." % [action, listener_name])
	
	# Add a memory for the listener
	if listener_node:
		_add_memory_to_character(listener_node, "You %s with %s." % [action, speaker_name])

# Add an end-of-conversation memory
func _add_conversation_end_memory(conversation_id: String):
	# Get conversation info from the dialog service (before the conversation ends)
	var conversations_info = dialog_service.get_active_conversations_info()
	for conversation_info in conversations_info:
		if conversation_info["id"] == conversation_id:
			var speaker_name = conversation_info["speaker"]
			var listener_name = conversation_info["listener"]
			_add_conversation_memory_to_participants(speaker_name, listener_name, "ended the conversation")
			break

# Find a character node by name
func _find_character_by_name(character_name: String) -> CharacterBody2D:
	var characters = get_tree().get_nodes_in_group("controllable_characters")
	for character in characters:
		if character.name == character_name:
			return character
	return null

# Add a memory to a character
func _add_memory_to_character(character_node: CharacterBody2D, content: String):
	if not character_node:
		return
	
	# Get the character_data metadata
	var metadata = character_node.get_meta("character_data", {})
	if not metadata.has("memories"):
		metadata["memories"] = []
	
	# Add the memory (dictionary format, consistent with _add_memory_to_current_character)
	metadata["memories"].append({
		"content": content,
		"timestamp": Time.get_unix_time_from_system()
	})
	character_node.set_meta("character_data", metadata)
	
	# Get the current time for log output
	var current_time = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d" % [
		current_time.year, current_time.month, current_time.day,
		current_time.hour, current_time.minute
	]
	
	print("[DialogManager] Added memory for %s: [%s] %s" % [character_node.name, time_str, content])

# Add a memory to the current character (modeled after AIAgent's _add_memory method)
func _add_memory_to_current_character(target_character, content: String):
	var metadata = target_character.get_meta("character_data", {})
	if not metadata.has("memories"):
		metadata["memories"] = []
	metadata["memories"].append({
		"content": content,
		"timestamp": Time.get_unix_time_from_system()
	})
	target_character.set_meta("character_data", metadata)
	print("[DialogManager] Added memory for %s: %s" % [target_character.name, content])
