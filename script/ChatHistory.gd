extends Node

class_name ChatHistory

# Dictionary storing conversation history, grouped by character
var history = {}

# List of characters in the current conversation
var participants = []

# Base path for conversation history files
const HISTORY_DIR = "user://chat_history/"

func _ready():
	# Make sure the history directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("chat_history"):
		dir.make_dir("chat_history")
	
	# Load history
	load_history()

# Add a conversation entry and save it to file
func add_message(speaker_name: String, message: String):
	# Make sure the speaker is in the participant list
	if not speaker_name in participants:
		participants.append(speaker_name)
	
	# Get the other party in the conversation
	var other_participant = ""
	for participant in participants:
		if participant != speaker_name:
			other_participant = participant
			break
	
	# If there are no other participants, use speaker_name as the key
	if other_participant.is_empty():
		other_participant = speaker_name
	
	# Initialize the conversation entry list
	if not other_participant in history:
		history[other_participant] = []
	
	# Use the message as passed in, without adding a speaker prefix
	# because DialogManager.gd has already formatted the message
	var message_data = {
		"message": message,
		"timestamp": Time.get_unix_time_from_system(),
		"participants": participants.duplicate()
	}
	
	# Insert messages in chronological order
	var messages = history[other_participant]
	var insert_index = messages.size()
	for i in range(messages.size()):
		if message_data["timestamp"] < messages[i]["timestamp"]:
			insert_index = i
			break
	
	messages.insert(insert_index, message_data)
	# Save to file
	save_history()

# Get all conversation history
func get_history() -> Dictionary:
	return history

# Get the conversation history for the given character
func get_history_by_participant(participant_name: String) -> Array:
	if participant_name in history:
		return history[participant_name]
	return []

# Get the recent conversation with a specific character
func get_recent_conversation_with(participant_name: String, max_messages: int = 5) -> String:
	var conversation_text = ""
	var messages = get_history_by_participant(participant_name)
	
	if messages.size() == 0:
		return ""
	
	# Get the most recent messages (sorted by timestamp, take the last few)
	messages.sort_custom(func(a, b): return a["timestamp"] < b["timestamp"])
	var recent_messages = messages.slice(max(0, messages.size() - max_messages))
	
	# Format messages - use the stored message content directly without extra parsing
	for message in recent_messages:
		conversation_text += message["message"] + "\n"
	
	return conversation_text.rstrip("\n")

# Get the formatted conversation history text
func get_formatted_history() -> String:
	var formatted_text = ""
	var all_messages = []
	
	# Collect all messages
	for participant in history:
		for message in history[participant]:
			all_messages.append({
				"message": message["message"],
				"timestamp": message["timestamp"]
			})
	
	# Sort by timestamp
	all_messages.sort_custom(func(a, b): return a["timestamp"] < b["timestamp"])
	
	# Format messages - use the stored message content directly without extra parsing
	for message in all_messages:
		formatted_text += message["message"] + "\n"
	
	return formatted_text

# Clear conversation history
func clear_history():
	history.clear()
	participants.clear()
	# Also delete the history file
	var file_path = get_history_file_path()
	if FileAccess.file_exists(file_path):
		var dir = DirAccess.open("user://chat_history")
		dir.remove(file_path)

# Save conversation history to file
func save_history() -> void:
	var file_path = get_history_file_path()
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(history)
		file.store_string(json_string)

# Load conversation history from file
func load_history() -> void:
	var file_path = get_history_file_path()
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			var json = JSON.parse_string(json_string)
			if json:
				history = json

# Get the history file path
func get_history_file_path() -> String:
	# Use the owning node's name as the file name
	var node_name = get_parent().name if get_parent() else "default"
	return HISTORY_DIR + node_name + "_history.json"
