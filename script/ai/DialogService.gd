extends Node
class_name DialogService

# Dictionary of active conversation managers
var active_conversations: Dictionary = {}

# Dialog range settings
var max_dialog_distance: float = 100.0

# Signals
signal conversation_started(conversation_id: String, speaker_name: String, listener_name: String)
signal conversation_ended(conversation_id: String)
signal dialog_generated(conversation_id: String, speaker_name: String, dialog_text: String)

func _ready():
	print("[DialogService] Dialog service initialized")

# Try to start a conversation
func try_start_conversation(speaker: CharacterBody2D, listener: CharacterBody2D) -> bool:
	if not speaker or not listener:
		print("[DialogService] Invalid conversation participants")
		return false
	
	# Check distance
	if not _is_in_range(speaker, listener):
		print("[DialogService] Characters are too far apart to start a conversation")
		return false
	
	# Check whether either is already in a conversation
	if is_character_in_conversation(speaker) or is_character_in_conversation(listener):
		print("[DialogService] One of the characters is already in a conversation")
		return false
	
	# Create a new conversation manager
	var conversation = ConversationManager.new(speaker, listener)
	active_conversations[conversation.conversation_id] = conversation
	
	# Connect signals
	conversation.conversation_ended.connect(_on_conversation_ended)
	conversation.dialog_generated.connect(_on_dialog_generated)
	
	# Start the conversation
	conversation.start_conversation()
	
	# Emit signal
	conversation_started.emit(conversation.conversation_id, speaker.name, listener.name)
	
	print("[DialogService] Started new conversation: %s <-> %s (ID: %s)" % [speaker.name, listener.name, conversation.conversation_id])
	return true

# End the specified conversation
func end_conversation(conversation_id: String) -> bool:
	if not active_conversations.has(conversation_id):
		print("[DialogService] Conversation does not exist: %s" % conversation_id)
		return false
	
	var conversation = active_conversations[conversation_id]
	conversation.end_conversation()
	return true

# End all conversations a character is in
func end_character_conversations(character: CharacterBody2D):
	var conversations_to_end = []
	
	for conversation_id in active_conversations:
		var conversation = active_conversations[conversation_id]
		if conversation.speaker == character or conversation.listener == character:
			conversations_to_end.append(conversation_id)
	
	for conversation_id in conversations_to_end:
		end_conversation(conversation_id)

# Check whether a character is in a conversation
func is_character_in_conversation(character: CharacterBody2D) -> bool:
	for conversation_id in active_conversations:
		var conversation = active_conversations[conversation_id]
		if conversation.speaker == character or conversation.listener == character:
			return true
	return false

# Get the list of conversation IDs a character is in
func get_character_conversations(character: CharacterBody2D) -> Array:
	var conversation_ids = []
	
	for conversation_id in active_conversations:
		var conversation = active_conversations[conversation_id]
		if conversation.speaker == character or conversation.listener == character:
			conversation_ids.append(conversation_id)
	
	return conversation_ids

# Get the number of active conversations
func get_active_conversation_count() -> int:
	return active_conversations.size()

# Get info for all active conversations
func get_active_conversations_info() -> Array:
	var info = []
	
	for conversation_id in active_conversations:
		var conversation = active_conversations[conversation_id]
		info.append({
			"id": conversation_id,
			"speaker": conversation.speaker.name,
			"listener": conversation.listener.name,
			"is_active": conversation.is_active
		})
	
	return info

# Check whether within dialog range
func _is_in_range(node1: Node2D, node2: Node2D) -> bool:
	return node1.global_position.distance_to(node2.global_position) <= max_dialog_distance

# Conversation ended callback
func _on_conversation_ended(conversation_id: String):
	print("[DialogService] Conversation ended: %s" % conversation_id)
	
	if active_conversations.has(conversation_id):
		active_conversations.erase(conversation_id)
	
	conversation_ended.emit(conversation_id)

# Dialog generated callback
func _on_dialog_generated(speaker_name: String, dialog_text: String):
	# Find the matching conversation ID
	var conversation_id = ""
	for id in active_conversations:
		var conversation = active_conversations[id]
		if conversation.speaker.name == speaker_name:
			conversation_id = id
			break
	
	dialog_generated.emit(conversation_id, speaker_name, dialog_text)

# Clean up all conversations
func cleanup_all_conversations():
	print("[DialogService] Cleaning up all conversations")
	
	for conversation_id in active_conversations:
		var conversation = active_conversations[conversation_id]
		conversation.end_conversation()
	
	active_conversations.clear()

# Debug info
func print_debug_info():
	print("[DialogService] Active conversations: %d" % active_conversations.size())
	for conversation_id in active_conversations:
		var conversation = active_conversations[conversation_id]
		print("  - %s: %s <-> %s (active: %s)" % [conversation_id, conversation.speaker.name, conversation.listener.name, conversation.is_active])
