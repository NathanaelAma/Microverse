extends Control

# Script references
var BackgroundStoryManager = preload("res://script/ai/background_story/BackgroundStoryManager.gd")

# Panel references
@onready var left_panel = $HBoxContainer/LeftPanel
@onready var right_panel = $HBoxContainer/RightPanel
@onready var character_list = $HBoxContainer/LeftPanel/VBoxContainer/CharacterList
@onready var character_detail = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail
@onready var toggle_ui_button = $HBoxContainer/RightPanel/VBoxContainer/ToggleUIButton

# Popup references
@onready var implant_memory_popup = $Popups/ImplantMemoryPopup
@onready var disease_popup = $Popups/DiseasePopup
@onready var money_popup = $Popups/MoneyPopup
@onready var emotion_popup = $Popups/EmotionPopup
@onready var task_popup = $Popups/TaskPopup
@onready var background_popup = $Popups/BackgroundPopup

# Character detail panel references
@onready var task_detail_list = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/Tasks/TaskDetailList
@onready var ai_settings_container = $"HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/TabContainer/AI Settings/AISettingsContainer"
@onready var avatar_sprite = $HBoxContainer/LeftPanel/VBoxContainer/CharacterDetail/HBoxContainer/Avatar/AnimatedSprite2D

# Currently selected character
var selected_character = null
var all_characters = []
var ui_visible = true

func _ready():
	# Hide the avatar animation node initially
	if avatar_sprite:
		avatar_sprite.visible = false
	
	# Connect button signals
	$HBoxContainer/RightPanel/VBoxContainer/ImplantMemoryButton.pressed.connect(_on_implant_memory_pressed)
	$HBoxContainer/RightPanel/VBoxContainer/DiseaseButton.pressed.connect(_on_disease_pressed)
	$HBoxContainer/RightPanel/VBoxContainer/MoneyButton.pressed.connect(_on_money_pressed)
	$HBoxContainer/RightPanel/VBoxContainer/EmotionButton.pressed.connect(_on_emotion_pressed)
	$HBoxContainer/RightPanel/VBoxContainer/TaskButton.pressed.connect(_on_task_pressed)
	$HBoxContainer/RightPanel/VBoxContainer/BackgroundButton.pressed.connect(_on_background_pressed)
	toggle_ui_button.pressed.connect(_on_toggle_ui_pressed)
	
	# Connect character list signals
	character_list.item_selected.connect(_on_character_selected)
	
	# Connect popup button signals
	implant_memory_popup.get_node("VBoxContainer/HBoxContainer/CancelButton").pressed.connect(func(): implant_memory_popup.hide())
	implant_memory_popup.get_node("VBoxContainer/HBoxContainer/ConfirmButton").pressed.connect(_on_implant_memory_confirm)
	
	disease_popup.get_node("VBoxContainer/HBoxContainer/CancelButton").pressed.connect(func(): disease_popup.hide())
	disease_popup.get_node("VBoxContainer/HBoxContainer/ConfirmButton").pressed.connect(_on_disease_confirm)
	
	money_popup.get_node("VBoxContainer/HBoxContainer/CancelButton").pressed.connect(func(): money_popup.hide())
	money_popup.get_node("VBoxContainer/HBoxContainer/ConfirmButton").pressed.connect(_on_money_confirm)
	
	emotion_popup.get_node("VBoxContainer/HBoxContainer/CancelButton").pressed.connect(func(): emotion_popup.hide())
	emotion_popup.get_node("VBoxContainer/HBoxContainer/ConfirmButton").pressed.connect(_on_emotion_confirm)
	
	task_popup.get_node("VBoxContainer/ButtonContainer/CloseButton").pressed.connect(func(): task_popup.hide())
	task_popup.get_node("VBoxContainer/ButtonContainer/RefreshButton").pressed.connect(_on_refresh_tasks)
	task_popup.get_node("VBoxContainer/AddTaskContainer/AddTaskButton").pressed.connect(_on_add_task)
	task_popup.get_node("VBoxContainer/AddTaskContainer/PriorityContainer/PrioritySlider").value_changed.connect(_on_priority_changed)
	
	# Connect each popup's close_requested signal (fired when the X button in the top-right corner is clicked)
	implant_memory_popup.close_requested.connect(func(): implant_memory_popup.hide())
	disease_popup.close_requested.connect(func(): disease_popup.hide())
	money_popup.close_requested.connect(func(): money_popup.hide())
	emotion_popup.close_requested.connect(func(): emotion_popup.hide())
	task_popup.close_requested.connect(func(): task_popup.hide())
	background_popup.close_requested.connect(func(): background_popup.hide())
	
	# Connect slider signals
	disease_popup.get_node("VBoxContainer/SeveritySlider").value_changed.connect(_on_disease_severity_changed)
	emotion_popup.get_node("VBoxContainer/EmotionStrength").value_changed.connect(_on_emotion_strength_changed)
	
	# Initialize the task system
	_init_task_system()
	
	# Initialize illness options
	var disease_selector = disease_popup.get_node("VBoxContainer/DiseaseSelector")
	disease_selector.add_item("Cold")
	disease_selector.add_item("Fever")
	disease_selector.add_item("Allergy")
	disease_selector.add_item("Depression")
	disease_selector.add_item("Anxiety")
	disease_selector.add_item("Injury")
	
	# Initialize emotion type options
	var emotion_selector = emotion_popup.get_node("VBoxContainer/EmotionType")
	emotion_selector.add_item("Like")
	emotion_selector.add_item("Respect")
	emotion_selector.add_item("Jealousy")
	emotion_selector.add_item("Anger")
	emotion_selector.add_item("Trust")
	emotion_selector.add_item("Suspicion")
	emotion_selector.add_item("Admiration")
	
	# Get the characters in the scene
	_update_character_lists()
	
	# Close the UI initially
	_toggle_ui(true)

# Update the character list periodically to catch dynamically added characters
func _process(_delta):
	# Update the character list at intervals
	if Engine.get_process_frames() % 60 == 0:  # Check roughly once per second
		_update_character_lists()

func _update_character_lists():
	# Get all characters
	var new_characters = get_tree().get_nodes_in_group("controllable_characters")
	
	# Check for changes
	var has_changes = false
	if new_characters.size() != all_characters.size():
		has_changes = true
	else:
		for i in range(new_characters.size()):
			if not (i < all_characters.size() and new_characters[i] == all_characters[i]):
				has_changes = true
				break
	
	if not has_changes:
		return
		
	# Update the character list
	all_characters = new_characters
	
	# Clear the character list
	character_list.clear()
	
	# Update the character selectors in all popups
	var popup_selectors = [
		implant_memory_popup.get_node("VBoxContainer/CharacterSelector"),
		disease_popup.get_node("VBoxContainer/CharacterSelector"),
		money_popup.get_node("VBoxContainer/CharacterSelector"),
		emotion_popup.get_node("VBoxContainer/CharacterSelectorA"),
		emotion_popup.get_node("VBoxContainer/CharacterSelectorB"),
		task_popup.get_node("VBoxContainer/CharacterSelector")
	]
	
	for selector in popup_selectors:
		selector.clear()
	
	# Add characters to the list and selectors
	for character in all_characters:
		var name = character.name
		character_list.add_item(name)
		
		for selector in popup_selectors:
			selector.add_item(name)
	
	# If a character was selected before, try to keep it selected
	if selected_character:
		var index = all_characters.find(selected_character)
		if index >= 0:
			character_list.select(index)
		else:
			selected_character = null
			_update_character_detail() # Clear the details

func _on_character_selected(index):
	if index >= 0 and index < all_characters.size():
		selected_character = all_characters[index]
		_update_character_detail()

func _update_character_detail():
	if not selected_character:
		# Clear the detail display
		character_detail.get_node("NameLabel").text = "Name:"
		character_detail.get_node("HBoxContainer/VBoxContainer/MoneyLabel").text = "Savings: 0"
		character_detail.get_node("HBoxContainer/VBoxContainer/MoodLabel").text = "Mood: Normal"
		character_detail.get_node("HBoxContainer/VBoxContainer/HealthLabel").text = "Health: Good"
		character_detail.get_node("TabContainer/Persona/PersonalityText").text = "Select a character to view their persona..."
		_clear_children(character_detail.get_node("TabContainer/Memories/MemoryList"))
		_clear_children(character_detail.get_node("TabContainer/Relationships/RelationList"))
		
		# Hide the avatar animation node
		if avatar_sprite:
			avatar_sprite.stop()
			avatar_sprite.visible = false
		
		# Clear the AI settings UI
		if ai_settings_container and ai_settings_container.has_method("set_character"):
			ai_settings_container.set_character("")
		
		return
	
	# Basic info
	character_detail.get_node("NameLabel").text = "Name: " + selected_character.name
	
	# Try to read character attributes, falling back to defaults if missing
	var money = selected_character.get_meta("money", 0)
	var mood = selected_character.get_meta("mood", "Normal")
	var health = selected_character.get_meta("health", "Good")
	
	character_detail.get_node("HBoxContainer/VBoxContainer/MoneyLabel").text = "Savings: " + str(money)
	character_detail.get_node("HBoxContainer/VBoxContainer/MoodLabel").text = "Mood: " + str(mood)
	character_detail.get_node("HBoxContainer/VBoxContainer/HealthLabel").text = "Health: " + str(health)
	
	# Persona
	var personality_data = CharacterPersonality.get_personality(selected_character.name)
	var personality_text = ""
	if personality_data.has("personality"):
		personality_text = "Persona: " + personality_data["personality"] + "\n\n"
	if personality_data.has("position"):
		personality_text += "Position: " + personality_data["position"] + "\n\n"
	if personality_data.has("speaking_style"):
		personality_text += "Speaking style: " + personality_data["speaking_style"] + "\n\n"
	if personality_data.has("work_duties"):
		personality_text += "Job duties: " + personality_data["work_duties"] + "\n\n"
	if personality_data.has("work_habits"):
		personality_text += "Work habits: " + personality_data["work_habits"]
	
	if personality_text.is_empty():
		personality_text = "No persona set"
	
	character_detail.get_node("TabContainer/Persona/PersonalityText").text = personality_text
	
	# Memories - fetched through MemoryManager
	var memory_list = character_detail.get_node("TabContainer/Memories/MemoryList")
	_clear_children(memory_list)
	
	
	var memories = MemoryManager.get_character_memories(selected_character)
	for memory in memories:
		var memory_label = Label.new()
		# Handle different memory data formats
		var memory_text = ""
		if typeof(memory) == TYPE_DICTIONARY:
			# Use MemoryManager's formatter for Dictionary-format memories
			memory_text = MemoryManager._format_memory_for_display(memory)
		elif typeof(memory) == TYPE_STRING:
			# Use String-format memories as-is
			memory_text = memory
		else:
			# Convert other types to strings
			memory_text = str(memory)
		
		memory_label.text = memory_text
		memory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		memory_list.add_child(memory_label)
		memory_list.add_child(HSeparator.new())
	
	# Relationships
	var relation_list = character_detail.get_node("TabContainer/Relationships/RelationList")
	_clear_children(relation_list)
	
	var relations = selected_character.get_meta("relations", {})
	for target_name in relations:
		var relation = relations[target_name]
		var relation_label = Label.new()
		var emotion_text = relation["type"] if relation.has("type") else "Unknown"
		var strength = relation["strength"] if relation.has("strength") else 0
		relation_label.text = "Feeling toward " + target_name + ": " + emotion_text + " (strength: " + str(strength) + ")"
		relation_list.add_child(relation_label)
	
	# Update the avatar animation
	_update_avatar_animation()
	
	# Update task info
	_update_task_detail()
	
	# Update the AI settings UI
	if ai_settings_container and ai_settings_container.has_method("set_character"):
		ai_settings_container.set_character(selected_character.name)

# Update the avatar animation
func _update_avatar_animation():
	if not avatar_sprite or not selected_character:
		return
	
	# Show the avatar animation node
	avatar_sprite.visible = true
	
	# Set the animation for this character's name
	# Animation names are assumed to follow the format "charactername_idle" (all lowercase)
	var animation_name = selected_character.name.to_lower() + "_idle"
	
	# Check whether the animation exists
	if avatar_sprite.sprite_frames and avatar_sprite.sprite_frames.has_animation(animation_name):
		avatar_sprite.play(animation_name)
	else:
		# If no character-specific animation is found, try the default animation
		if avatar_sprite.sprite_frames and avatar_sprite.sprite_frames.has_animation("default"):
			avatar_sprite.play("default")
		else:
			# If there's no default animation either, try the first available animation
			var animations = avatar_sprite.sprite_frames.get_animation_names()
			if animations.size() > 0:
				avatar_sprite.play(animations[0])
			else:
				print("Warning: no available animation found")

func _clear_children(node):
	for child in node.get_children():
		child.queue_free()

func _on_toggle_ui_pressed():
	_toggle_ui(!ui_visible)

func _toggle_ui(show):
	ui_visible = show
	left_panel.visible = show
	right_panel.visible = show # Make sure the right panel toggles too
	toggle_ui_button.visible = true # Always keep visible
	toggle_ui_button.text = "Hide UI" if show else "Show UI"

func _on_implant_memory_pressed():
	implant_memory_popup.popup_centered()

func _on_disease_pressed():
	disease_popup.popup_centered()

func _on_money_pressed():
	money_popup.popup_centered()

func _on_emotion_pressed():
	emotion_popup.popup_centered()
	
func _on_task_pressed():
	task_popup.popup_centered()
	_update_task_list()

func _on_implant_memory_confirm():
	var character_selector = implant_memory_popup.get_node("VBoxContainer/CharacterSelector")
	var memory_input = implant_memory_popup.get_node("VBoxContainer/MemoryInput")
	
	if character_selector.selected < 0 or all_characters.size() <= character_selector.selected:
		return
	
	var character = all_characters[character_selector.selected]
	var memory_text = memory_input.text
	
	if memory_text.strip_edges().is_empty():
		return
	
	# Add the memory through MemoryManager with high importance (player-implanted memories should take priority)
	MemoryManager.add_memory(character, memory_text, MemoryManager.MemoryType.PERSONAL, MemoryManager.MemoryImportance.HIGH)
	print("Memory saved through MemoryManager: ", memory_text)
	
	# Update character details
	if selected_character == character:
		_update_character_detail()
	
	memory_input.text = ""
	implant_memory_popup.hide()

func _on_disease_confirm():
	var character_selector = disease_popup.get_node("VBoxContainer/CharacterSelector")
	var disease_selector = disease_popup.get_node("VBoxContainer/DiseaseSelector")
	var severity_slider = disease_popup.get_node("VBoxContainer/SeveritySlider")
	
	if character_selector.selected < 0 or all_characters.size() <= character_selector.selected:
		return
	
	var character = all_characters[character_selector.selected]
	var disease_type = disease_selector.get_item_text(disease_selector.selected)
	var severity = int(severity_slider.value)
	
	# Set the illness
	var health_info = disease_type + " (severity: " + str(severity) + "/10)"
	character.set_meta("health", health_info)
	
	# Add an illness-related memory
	var character_data = character.get_meta("character_data", {})
	if not character_data.has("memories"):
		character_data["memories"] = []
	
	var current_time = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d" % [
		current_time.year, current_time.month, current_time.day,
		current_time.hour, current_time.minute
	]
	
	var severity_text = "mild"
	if severity > 3 and severity <= 7:
		severity_text = "moderate"
	elif severity > 7:
		severity_text = "severe"
		
	# Add the illness memory through MemoryManager
	var memory_text = "You feel unwell: you have come down with %s (%s)" % [disease_type, severity_text]
	MemoryManager.add_memory(character, memory_text, MemoryManager.MemoryType.PERSONAL, MemoryManager.MemoryImportance.HIGH)
	
	# Update character details
	if selected_character == character:
		_update_character_detail()
	
	disease_popup.hide()

func _on_money_confirm():
	var character_selector = money_popup.get_node("VBoxContainer/CharacterSelector")
	var money_input = money_popup.get_node("VBoxContainer/MoneyInput")
	var reason_input = money_popup.get_node("VBoxContainer/ReasonInput")
	
	if character_selector.selected < 0 or all_characters.size() <= character_selector.selected:
		return
	
	var character = all_characters[character_selector.selected]
	var amount = int(money_input.value)
	var reason = reason_input.text
	
	# Debug info: print the reason input
	print("Reason input content: '", reason, "'")
	print("Reason input length: ", reason.length())
	print("Reason after trimming whitespace: '", reason.strip_edges(), "'")
	
	if reason.strip_edges().is_empty():
		reason = "Unknown reason"
		print("Reason is empty, set to: ", reason)
	else:
		print("Using the reason entered by the user: ", reason)
	
	# Change money
	if not character.has_meta("money"):
		character.set_meta("money", 0)
	
	var current_money = character.get_meta("money", 0)
	current_money += amount
	character.set_meta("money", current_money)
	
	# Add a money-related memory
	var character_data = character.get_meta("character_data", {})
	if not character_data.has("memories"):
		character_data["memories"] = []
	
	var current_time = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d" % [
		current_time.year, current_time.month, current_time.day,
		current_time.hour, current_time.minute
	]
	
	var memory_text = ""
	if amount > 0:
		memory_text = "You gained " + str(amount) + " yuan, because: " + reason
	else:
		memory_text = "You lost " + str(abs(amount)) + " yuan, because: " + reason
	
	# Add the money memory through MemoryManager
	MemoryManager.add_memory(character, memory_text, MemoryManager.MemoryType.PERSONAL, MemoryManager.MemoryImportance.NORMAL)
	print("Memory saved through MemoryManager: ", memory_text)
	
	# Update character details
	if selected_character == character:
		_update_character_detail()
	
	money_input.value = 0
	reason_input.text = ""
	money_popup.hide()

func _on_emotion_confirm():
	var selector_a = emotion_popup.get_node("VBoxContainer/CharacterSelectorA")
	var selector_b = emotion_popup.get_node("VBoxContainer/CharacterSelectorB")
	var emotion_type = emotion_popup.get_node("VBoxContainer/EmotionType")
	var emotion_strength = emotion_popup.get_node("VBoxContainer/EmotionStrength")
	
	if selector_a.selected < 0 or selector_b.selected < 0 or all_characters.size() <= selector_a.selected or all_characters.size() <= selector_b.selected:
		return
	
	var character_a = all_characters[selector_a.selected]
	var character_b = all_characters[selector_b.selected]
	
	if character_a == character_b:
		return
	
	var type = emotion_type.get_item_text(emotion_type.selected)
	var strength = int(emotion_strength.value)
	
	# Set the relationship
	if not character_a.has_meta("relations"):
		character_a.set_meta("relations", {})
	
	var relations = character_a.get_meta("relations", {})
	relations[character_b.name] = {
		"type": type,
		"strength": strength
	}
	character_a.set_meta("relations", relations)
	
	# Add an emotion-related memory
	if not character_a.has_meta("memories"):
		character_a.set_meta("memories", [])
	
	var current_time = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d" % [
		current_time.year, current_time.month, current_time.day,
		current_time.hour, current_time.minute
	]
	
	var strength_text = ""
	if strength < -5:
		strength_text = "strong"
	elif strength < 0:
		strength_text = "slight"
	elif strength == 0:
		strength_text = "neutral"
	elif strength <= 5:
		strength_text = "slight"
	else:
		strength_text = "strong"
	
	var emotion_text = ""
	if strength < 0:
		emotion_text = "You developed a %s negative feeling (%s) toward %s" % [strength_text, type, character_b.name]
	elif strength == 0:
		emotion_text = "Your feeling of %s toward %s became neutral" % [type, character_b.name]
	else:
		emotion_text = "You developed a %s positive feeling (%s) toward %s" % [strength_text, type, character_b.name]
	
	# Add the emotion memory through MemoryManager
	MemoryManager.add_memory(character_a, emotion_text, MemoryManager.MemoryType.EMOTION, MemoryManager.MemoryImportance.NORMAL)
	
	# Update character details
	if selected_character == character_a:
		_update_character_detail()
	
	emotion_popup.hide()

func _on_disease_severity_changed(value):
	var severity_text = ""
	if value <= 3:
		severity_text = "Mild"
	elif value <= 7:
		severity_text = "Moderate"
	else:
		severity_text = "Severe"
	
	disease_popup.get_node("VBoxContainer/SeverityLabel").text = severity_text + " (" + str(int(value)) + "/10)"

func _on_emotion_strength_changed(value):
	var strength_text = ""
	if value < -5:
		strength_text = "Strong dislike"
	elif value < 0:
		strength_text = "Mild dislike"
	elif value == 0:
		strength_text = "Neutral"
	elif value <= 5:
		strength_text = "Mild liking"
	else:
		strength_text = "Strong liking"
	
	emotion_popup.get_node("VBoxContainer/StrengthLabel").text = strength_text + " (" + str(int(value)) + "/10)"

# Initialize the task system
func _init_task_system():
	# Initialize the task list for each character
	for character in all_characters:
		if not character.has_meta("tasks"):
			character.set_meta("tasks", [])
			
		# Set the daily task refresh timestamp for each character
		if not character.has_meta("last_task_refresh"):
			character.set_meta("last_task_refresh", Time.get_unix_time_from_system())

# Update the task list UI
func _update_task_list():
	var character_selector = task_popup.get_node("VBoxContainer/CharacterSelector")
	if character_selector.selected < 0 or character_selector.selected >= all_characters.size():
		return
		
	var selected_character = all_characters[character_selector.selected]
	
	# Get the task list
	var character_data = selected_character.get_meta("character_data", {})
	var tasks = character_data.get("tasks", [])
	
	# Clear the current task container
	var task_container = task_popup.get_node("VBoxContainer/TaskList/TaskContainer")
	for child in task_container.get_children():
		child.queue_free()
		
	# Sort tasks by desire level (high to low)
	tasks.sort_custom(func(a, b): return a["priority"] > b["priority"])
	
	# Add tasks to the UI
	for i in range(tasks.size()):
		var task = tasks[i]
		
		# Create the task item container
		var task_item = HBoxContainer.new()
		task_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Create the task description label
		var task_label = Label.new()
		task_label.text = "%d. %s (desire level: %d/10)" % [i + 1, task["description"], task["priority"]]
		task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		task_item.add_child(task_label)
		
		# Create the complete button
		var complete_button = Button.new()
		complete_button.text = "Done"
		complete_button.pressed.connect(_on_complete_task.bind(i))
		task_item.add_child(complete_button)
		
		# Create the delete button
		var delete_button = Button.new()
		delete_button.text = "Delete"
		delete_button.pressed.connect(_on_delete_task.bind(i))
		task_item.add_child(delete_button)
		
		# Add the task item to the container
		task_container.add_child(task_item)
		
	# Check whether daily tasks need refreshing
	_check_daily_task_refresh(selected_character)

# Add a new task
func _on_add_task():
	var character_selector = task_popup.get_node("VBoxContainer/CharacterSelector")
	if character_selector.selected < 0 or character_selector.selected >= all_characters.size():
		return
		
	var selected_character = all_characters[character_selector.selected]
	
	# Get the task description and priority
	var task_input = task_popup.get_node("VBoxContainer/AddTaskContainer/TaskInput")
	var priority_slider = task_popup.get_node("VBoxContainer/AddTaskContainer/PriorityContainer/PrioritySlider")
	
	var task_description = task_input.text.strip_edges()
	var priority = int(priority_slider.value)
	
	if task_description.is_empty():
		return
		
	# Create the new task
	var new_task = {
		"description": task_description,
		"priority": priority,
		"created_at": Time.get_unix_time_from_system(),
		"completed": false
	}
	
	# Add it to the character's task list
	var tasks = selected_character.get_meta("tasks", [])
	tasks.append(new_task)
	selected_character.set_meta("tasks", tasks)
	
	# Clear the input field
	task_input.text = ""
	priority_slider.value = 5
	
	# Update the task list UI
	_update_task_list()
	
	# Add a task memory
	var current_time = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d" % [
		current_time.year, current_time.month, current_time.day,
		current_time.hour, current_time.minute
	]
	var memory_text = "You assigned yourself a new task: %s (desire level: %d/10)" % [task_description, priority]
	
	# Add the memory through MemoryManager
	MemoryManager.add_memory(selected_character, memory_text, MemoryManager.MemoryType.TASK, MemoryManager.MemoryImportance.NORMAL)
	
	# If the selected character is the one being viewed, update the detail panel
	if selected_character == selected_character:
		_update_character_detail()

# Complete a task
func _on_complete_task(task_index):
	var character_selector = task_popup.get_node("VBoxContainer/CharacterSelector")
	if character_selector.selected < 0 or character_selector.selected >= all_characters.size():
		return
		
	var selected_character = all_characters[character_selector.selected]
	
	# Get the task list
	var character_data = selected_character.get_meta("character_data", {})
	var tasks = character_data.get("tasks", [])
	
	if task_index < 0 or task_index >= tasks.size():
		return
		
	# Mark the task as completed
	var task = tasks[task_index]
	task["completed"] = true
	task["completed_at"] = Time.get_unix_time_from_system()
	
	# Add a task-completion memory
	var memory_text = "You completed the task: %s" % [task["description"]]
	
	# Add the memory through MemoryManager
	MemoryManager.add_memory(selected_character, memory_text, MemoryManager.MemoryType.TASK, MemoryManager.MemoryImportance.NORMAL)
	
	# Remove the completed task from the list
	tasks.remove_at(task_index)
	character_data["tasks"] = tasks
	selected_character.set_meta("character_data", character_data)
	
	# Update the task list UI
	_update_task_list()
	
	# If the selected character is the one being viewed, update the detail panel
	if selected_character == selected_character:
		_update_character_detail()

# Delete a task
func _on_delete_task(task_index):
	var character_selector = task_popup.get_node("VBoxContainer/CharacterSelector")
	if character_selector.selected < 0 or character_selector.selected >= all_characters.size():
		return
		
	var selected_character = all_characters[character_selector.selected]
	
	# Get the task list
	var character_data = selected_character.get_meta("character_data", {})
	var tasks = character_data.get("tasks", [])
	
	if task_index < 0 or task_index >= tasks.size():
		return
		
	# Remove the task from the list
	tasks.remove_at(task_index)
	character_data["tasks"] = tasks
	selected_character.set_meta("character_data", character_data)
	
	# Update the task list UI
	_update_task_list()

# Refresh the task list
func _on_refresh_tasks():
	var character_selector = task_popup.get_node("VBoxContainer/CharacterSelector")
	if character_selector.selected < 0 or character_selector.selected >= all_characters.size():
		return
		
	var selected_character = all_characters[character_selector.selected]
	
	# Force a task refresh
	_refresh_daily_tasks(selected_character)
	
	# Update the task list UI
	_update_task_list()

# Check whether daily tasks need refreshing
func _check_daily_task_refresh(character_node):
	if not character_node:
		return
		
	# Get character data
	var character_data = character_node.get_meta("character_data", {})
	
	# Get the last refresh time
	var last_refresh = character_data.get("last_task_refresh", 0)
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
		
	# Get character data
	var character_data = character_node.get_meta("character_data", {})
	
	# Get the current task list
	var tasks = character_data.get("tasks", [])
	
	# Keep incomplete tasks
	var incomplete_tasks = []
	for task in tasks:
		if not task.get("completed", false):
			incomplete_tasks.append(task)
			
	# Re-sort tasks (by priority, high to low)
	incomplete_tasks.sort_custom(func(a, b): return a["priority"] > b["priority"])
	
	# If there are fewer than 10 tasks, generate new ones automatically
	while incomplete_tasks.size() < 10:
		# Generate a random task
		var new_task = _generate_random_task(character_node)
		incomplete_tasks.append(new_task)
		
	# Update the task list
	character_data["tasks"] = incomplete_tasks
	
	# Update the refresh time
	character_data["last_task_refresh"] = Time.get_unix_time_from_system()
	character_node.set_meta("character_data", character_data)
	
	# Add a task-refresh memory
	var memory_text = "You reorganized today's task plan; you now have %d pending tasks" % [incomplete_tasks.size()]
	
	# Add the memory through MemoryManager
	MemoryManager.add_memory(character_node, memory_text, MemoryManager.MemoryType.TASK, MemoryManager.MemoryImportance.NORMAL)

# Generate a random task
func _generate_random_task(character_node):
	if not character_node:
		return null
		
	# General task pool
	var tasks_pool = [
		"Check email",
		"Tidy up the workspace",
		"Chat with colleagues",
		"Attend a meeting",
		"Take a short break",
		"Prepare for tomorrow's work",
		"Reply to important emails",
		"Organize documents",
		"Learn a new skill",
		"Think about ways to improve work",
		"Update the boss on work progress",
		"Help a colleague solve a problem",
		"Draw up a work plan",
		"Summarize today's work",
		"Prepare a work report"
	]
	
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

# Update the task detail display
func _update_task_detail():
	if not selected_character:
		return
		
	# Clear the current task detail list
	_clear_children(task_detail_list)
	
	# Get the task list
	var character_data = selected_character.get_meta("character_data", {})
	var tasks = character_data.get("tasks", [])
	
	if tasks.is_empty():
		var no_task_label = Label.new()
		no_task_label.text = "No tasks"
		task_detail_list.add_child(no_task_label)
		return
		
	# Sort tasks by desire level (high to low)
	tasks.sort_custom(func(a, b): return a["priority"] > b["priority"])
	
	# Show task statistics
	var stats_label = Label.new()
	stats_label.text = "Total tasks: %d" % tasks.size()
	stats_label.add_theme_font_size_override("font_size", 14)
	task_detail_list.add_child(stats_label)
	
	# Add a separator
	var separator = HSeparator.new()
	task_detail_list.add_child(separator)
	
	# Show the 5 most important tasks
	var display_count = min(5, tasks.size())
	for i in range(display_count):
		var task = tasks[i]
		
		# Create the task container
		var task_container = VBoxContainer.new()
		task_container.add_theme_constant_override("separation", 2)
		
		# Task title
		var task_title = Label.new()
		task_title.text = "%d. %s" % [i + 1, task["description"]]
		task_title.add_theme_font_size_override("font_size", 12)
		task_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		task_container.add_child(task_title)
		
		# Task details
		var task_info = Label.new()
		var priority_text = "Desire level: %d/10" % task["priority"]
		
		# Add the creation time
		var created_time = Time.get_datetime_dict_from_unix_time(task["created_at"])
		var time_str = "%02d-%02d %02d:%02d" % [created_time.month, created_time.day, created_time.hour, created_time.minute]
		priority_text += " | Created: %s" % time_str
		
		task_info.text = priority_text
		task_info.add_theme_font_size_override("font_size", 10)
		task_info.modulate = Color(0.7, 0.7, 0.7)
		task_container.add_child(task_info)
		
		# Add the task container to the list
		task_detail_list.add_child(task_container)
		
		# Add a separator (except after the last one)
		if i < display_count - 1:
			var task_separator = HSeparator.new()
			task_detail_list.add_child(task_separator)
			
	# If there are more tasks, show a hint
	if tasks.size() > display_count:
		var more_label = Label.new()
		more_label.text = "...%d more tasks" % (tasks.size() - display_count)
		more_label.add_theme_font_size_override("font_size", 10)
		more_label.modulate = Color(0.6, 0.6, 0.6)
		more_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		task_detail_list.add_child(more_label)

# Update the priority slider value display
func _on_priority_changed(value):
	var priority_value_label = task_popup.get_node("VBoxContainer/AddTaskContainer/PriorityContainer/PriorityValueLabel")
	priority_value_label.text = "%d/10" % int(value)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			# Check whether any settings UI is visible
			var settings_ui_visible = false
			var settings = get_node_or_null("/root/GlobalSettings")
			if settings != null and settings.has_method("is_settings_visible"):
				settings_ui_visible = settings.is_settings_visible()
			
			if not settings_ui_visible:
				_toggle_ui(!ui_visible)

# Story background button pressed
func _on_background_pressed():
	background_popup.popup_centered()
	_init_background_popup()

# Initialize the story background popup
func _init_background_popup():
	# Initialize the map selector
	var map_selector = background_popup.get_node("VBoxContainer/MapSelectionContainer/MapSelector")
	map_selector.clear()
	var available_maps = BackgroundStoryManager.get_available_maps()
	for map_name in available_maps:
		map_selector.add_item(map_name)
	
	# Set the currently selected map
	var current_map = BackgroundStoryManager.get_current_map_name()
	for i in range(map_selector.get_item_count()):
		if map_selector.get_item_text(i) == current_map:
			map_selector.selected = i
			break
	
	# Connect the map selector signal
	if not map_selector.item_selected.is_connected(_on_map_selected):
		map_selector.item_selected.connect(_on_map_selected)
	
	# Connect popup button signals
	var add_rule_button = background_popup.get_node("VBoxContainer/AddRuleContainer/AddRuleButton")
	var clear_rules_button = background_popup.get_node("VBoxContainer/ButtonContainer/ClearRulesButton")
	var refresh_button = background_popup.get_node("VBoxContainer/ButtonContainer/RefreshButton")
	var close_button = background_popup.get_node("VBoxContainer/ButtonContainer/CloseButton")
	var add_rule_input = background_popup.get_node("VBoxContainer/AddRuleContainer/AddRuleInput")
	
	if not add_rule_button.pressed.is_connected(_on_add_rule_pressed):
		add_rule_button.pressed.connect(_on_add_rule_pressed)
	if not clear_rules_button.pressed.is_connected(_on_clear_rules_pressed):
		clear_rules_button.pressed.connect(_on_clear_rules_pressed)
	if not refresh_button.pressed.is_connected(_on_refresh_background_pressed):
		refresh_button.pressed.connect(_on_refresh_background_pressed)
	if not close_button.pressed.is_connected(func(): background_popup.hide()):
		close_button.pressed.connect(func(): background_popup.hide())
	if not add_rule_input.text_submitted.is_connected(_on_rule_input_submitted):
		add_rule_input.text_submitted.connect(_on_rule_input_submitted)
	
	# Refresh the display
	_refresh_background_display()

# Map selection changed
func _on_map_selected(index: int):
	var map_selector = background_popup.get_node("VBoxContainer/MapSelectionContainer/MapSelector")
	var selected_map = map_selector.get_item_text(index)
	BackgroundStoryManager.set_background(selected_map)
	_refresh_background_display()

# Refresh the story background display
func _refresh_background_display():
	# Update map info
	var map_info_label = background_popup.get_node("VBoxContainer/BackgroundInfoContainer/MapInfoLabel")
	var company_info_label = background_popup.get_node("VBoxContainer/BackgroundInfoContainer/CompanyInfoLabel")
	
	map_info_label.text = "Current map: " + BackgroundStoryManager.get_current_map_name()
	company_info_label.text = "Organization: " + BackgroundStoryManager.get_current_company_name()
	
	# Update preset rules
	_update_preset_rules_display()
	
	# Update custom rules
	_update_custom_rules_display()

# Update the preset rules display
func _update_preset_rules_display():
	var preset_rules_list = background_popup.get_node("VBoxContainer/PresetRulesContainer/PresetRulesScroll/PresetRulesList")
	
	# Clear existing content
	for child in preset_rules_list.get_children():
		child.queue_free()
	
	# Add preset rules
	var preset_rules = BackgroundStoryManager.get_preset_rules()
	for i in range(preset_rules.size()):
		var rule = preset_rules[i]
		var rule_label = Label.new()
		rule_label.text = "%d. %s" % [i + 1, rule]
		rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule_label.add_theme_color_override("font_color", Color.CYAN)
		preset_rules_list.add_child(rule_label)

# Update the custom rules display
func _update_custom_rules_display():
	var custom_rules_list = background_popup.get_node("VBoxContainer/CustomRulesContainer/CustomRulesScroll/CustomRulesList")
	
	# Clear existing content
	for child in custom_rules_list.get_children():
		child.queue_free()
	
	# Add custom rules
	var custom_rules = BackgroundStoryManager.get_custom_rules()
	for i in range(custom_rules.size()):
		var rule = custom_rules[i]
		
		# Create the rule container
		var rule_container = HBoxContainer.new()
		
		# Rule text
		var rule_label = Label.new()
		rule_label.text = "%d. %s" % [i + 1, rule]
		rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule_label.add_theme_color_override("font_color", Color.YELLOW)
		rule_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Delete button
		var delete_button = Button.new()
		delete_button.text = "Delete"
		delete_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		delete_button.pressed.connect(func(): _on_delete_rule_pressed(i))
		
		rule_container.add_child(rule_label)
		rule_container.add_child(delete_button)
		custom_rules_list.add_child(rule_container)

# Add rule button pressed
func _on_add_rule_pressed():
	var add_rule_input = background_popup.get_node("VBoxContainer/AddRuleContainer/AddRuleInput")
	var rule_text = add_rule_input.text.strip_edges()
	if rule_text.is_empty():
		return
	
	if BackgroundStoryManager.add_custom_rule(rule_text):
		add_rule_input.text = ""
		_update_custom_rules_display()

# Submit on Enter in the input field
func _on_rule_input_submitted(text: String):
	_on_add_rule_pressed()

# Delete rule button pressed
func _on_delete_rule_pressed(index: int):
	if BackgroundStoryManager.remove_custom_rule(index):
		_update_custom_rules_display()

# Clear all custom rules
func _on_clear_rules_pressed():
	# Show a confirmation dialog
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Are you sure you want to clear all custom rules? This cannot be undone."
	dialog.title = "Confirm Clear"
	
	# Add a cancel button
	dialog.add_cancel_button("Cancel")
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()
	
	# Connect the confirmed signal
	dialog.confirmed.connect(func():
		BackgroundStoryManager.clear_custom_rules()
		_update_custom_rules_display()
		dialog.queue_free()
	)
	
	# Connect the canceled signal
	dialog.canceled.connect(func():
		dialog.queue_free()
	)

# Refresh button pressed
func _on_refresh_background_pressed():
	_refresh_background_display()

# Clear the character selection (called by CharacterManager)
func clear_character_selection():
	selected_character = null
	# Clear the character list selection
	if character_list:
		character_list.deselect_all()
	# Update the character detail display
	_update_character_detail()
