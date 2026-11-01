extends Node

# Memory type enum
enum MemoryType {
	PERSONAL,      # Personal memory
	INTERACTION,   # Interaction memory
	TASK,          # Task memory
	EMOTION,       # Emotional memory
	EVENT          # Event memory
}

# Memory importance levels
enum MemoryImportance {
	LOW = 1,
	NORMAL = 3,
	HIGH = 5,
	CRITICAL = 10
}

# Get all memories of a character
func get_character_memories(character: Node) -> Array:
	if not character:
		return []
	
	# Read memories from character_data
	var character_data = character.get_meta("character_data", {})
	var memories = character_data.get("memories", [])
	
	return memories

# Add a memory to a character
func add_memory(character: Node, memory_content: String, memory_type: MemoryType = MemoryType.PERSONAL, importance: MemoryImportance = MemoryImportance.NORMAL) -> void:
	if not character or memory_content.strip_edges().is_empty():
		return
	
	# Get the current time
	var current_time = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d" % [
		current_time.year, current_time.month, current_time.day,
		current_time.hour, current_time.minute
	]
	
	# Create the memory object
	var memory_obj = {
		"content": memory_content,
		"timestamp": time_str,
		"type": memory_type,
		"importance": importance,
		"created_at": Time.get_unix_time_from_system()
	}
	
	# Get or create character_data
	var character_data = character.get_meta("character_data", {})
	if not character_data.has("memories"):
		character_data["memories"] = []
	
	# Append the memory
	character_data["memories"].append(memory_obj)
	character.set_meta("character_data", character_data)
	
	# Prune old memories to keep the count within a reasonable range
	_cleanup_old_memories(character)

# Get formatted memory text (for AI prompts)
func get_formatted_memories_for_prompt(character: Node, max_count: int = -1) -> String:
	var memories = get_character_memories(character)
	
	if memories.is_empty():
		return "\n\nMemories:\n- No important memories yet"
	
	# Convert memory format and sort by importance and time
	var formatted_memories = []
	for memory in memories:
		var formatted_memory = _format_memory_for_display(memory)
		if not formatted_memory.is_empty():
			formatted_memories.append({
				"text": formatted_memory,
				"importance": _get_memory_importance(memory),
				"timestamp": _get_memory_timestamp(memory)
			})
	
	# Sort by importance; for equal importance sort by time (newest first)
	formatted_memories.sort_custom(func(a, b): 
		if a.importance != b.importance:
			return a.importance > b.importance
		return a.timestamp > b.timestamp
	)
	
	# Build the prompt text
	var prompt_text = "\n\nMemories:"
	var display_count = formatted_memories.size() if max_count == -1 else min(max_count, formatted_memories.size())
	
	for i in range(display_count):
		prompt_text += "\n- " + formatted_memories[i].text
	
	if max_count != -1 and formatted_memories.size() > display_count:
		prompt_text += "\n- ...and %d more memories" % (formatted_memories.size() - display_count)
	
	return prompt_text

# Get recent memories (for conversation history)
func get_recent_memories(character: Node, hours: int = 24) -> Array:
	var memories = get_character_memories(character)
	var recent_memories = []
	var current_time = Time.get_unix_time_from_system()
	var time_threshold = current_time - (hours * 3600)  # Convert to seconds
	
	for memory in memories:
		var memory_time = _get_memory_timestamp(memory)
		if memory_time >= time_threshold:
			recent_memories.append(memory)
	
	return recent_memories

# Search for relevant memories
func search_memories(character: Node, keywords: Array) -> Array:
	var memories = get_character_memories(character)
	var relevant_memories = []
	
	for memory in memories:
		var memory_text = _format_memory_for_display(memory).to_lower()
		for keyword in keywords:
			if memory_text.contains(keyword.to_lower()):
				relevant_memories.append(memory)
				break
	
	return relevant_memories

# Prune old memories to keep the count within a reasonable range
func _cleanup_old_memories(character: Node, max_memories: int = 50) -> void:
	var character_data = character.get_meta("character_data", {})
	var memories = character_data.get("memories", [])
	
	if memories.size() <= max_memories:
		return
	
	# Sort by importance and time, keeping the most important and newest memories
	var sorted_memories = []
	for memory in memories:
		sorted_memories.append({
			"data": memory,
			"importance": _get_memory_importance(memory),
			"timestamp": _get_memory_timestamp(memory)
		})
	
	sorted_memories.sort_custom(func(a, b):
		if a.importance != b.importance:
			return a.importance > b.importance
		return a.timestamp > b.timestamp
	)
	
	# Keep the first max_memories memories
	var kept_memories = []
	for i in range(min(max_memories, sorted_memories.size())):
		kept_memories.append(sorted_memories[i].data)
	
	character_data["memories"] = kept_memories
	character.set_meta("character_data", character_data)

# Format a memory for display
func _format_memory_for_display(memory: Dictionary) -> String:
	var content = memory.get("content", "")
	var timestamp = memory.get("timestamp", "")
	if not timestamp or str(timestamp).strip_edges().is_empty():
		return content
	else:
		return "[%s] %s" % [timestamp, content]

# Get a memory's importance
func _get_memory_importance(memory: Dictionary) -> int:
	return memory.get("importance", MemoryImportance.NORMAL)

# Get a memory's timestamp
func _get_memory_timestamp(memory: Dictionary) -> float:
	return memory.get("created_at", 0.0)
