# SaveLoadUI.gd - save/load UI
# Provides saving, loading, and deleting game saves

extends Control

# Node references
@onready var save_list = $Panel/VBoxContainer/SaveList
@onready var save_name_input = $Panel/VBoxContainer/SaveNameContainer/SaveNameInput
@onready var save_button = $Panel/VBoxContainer/ButtonContainer/SaveButton
@onready var load_button = $Panel/VBoxContainer/ButtonContainer/LoadButton
@onready var delete_button = $Panel/VBoxContainer/ButtonContainer/DeleteButton
@onready var close_button = $Panel/VBoxContainer/ButtonContainer/CloseButton
@onready var status_label = $Panel/VBoxContainer/StatusLabel

# Game save manager
var save_manager

# Currently selected save
var selected_save = ""

func _ready():
	# Get the save manager
	save_manager = get_node_or_null("/root/GameSaveManager")
	
	# Connect signals
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	close_button.pressed.connect(_on_close_pressed)
	save_manager.save_completed.connect(_on_save_completed)
	save_manager.load_completed.connect(_on_load_completed)
	
	# Initial state
	load_button.disabled = true
	delete_button.disabled = true
	status_label.text = ""
	
	# Load the save list
	refresh_save_list()
	
	# Hidden by default
	hide()

# Show the UI
func show_ui():
	show()
	refresh_save_list()

# Hide the UI
func hide_ui():
	hide()

# Refresh the save list
func refresh_save_list():
	# Clear the list
	save_list.clear()
	
	# Get all saves
	var saves = save_manager.get_save_files()
	
	# Add to the list
	for save_name in saves:
		var save_info = save_manager.get_save_info(save_name)
		var display_text = save_name
		
		# If there's a timestamp, add the date
		if save_info.has("timestamp") and save_info["timestamp"] > 0:
			var datetime = Time.get_datetime_dict_from_unix_time(save_info["timestamp"])
			display_text += " (%04d-%02d-%02d %02d:%02d)" % [
				datetime["year"], 
				datetime["month"], 
				datetime["day"],
				datetime["hour"],
				datetime["minute"]
			]
		
		# Add scene and character count info
		if save_info.has("scene_name"):
			display_text += " - " + save_info["scene_name"]
		
		if save_info.has("character_count"):
			display_text += " (" + str(save_info["character_count"]) + " characters)"
		
		save_list.add_item(display_text, null, true)
		save_list.set_item_metadata(save_list.get_item_count() - 1, save_name)
	
	# Connect the selection signal
	if not save_list.item_selected.is_connected(_on_save_selected):
		save_list.item_selected.connect(_on_save_selected)

# Save button callback
func _on_save_pressed():
	var save_name = save_name_input.text.strip_edges()
	
	# Check whether a save name was entered
	if save_name.is_empty():
		status_label.text = "Please enter a save name"
		return
	
	# Save the game
	save_manager.save_game(save_name)

# Load button callback
func _on_load_pressed():
	if selected_save.is_empty():
		status_label.text = "Please select a save first"
		return
	
	# Load the game
	save_manager.load_game(selected_save)

# Delete button callback
func _on_delete_pressed():
	if selected_save.is_empty():
		status_label.text = "Please select a save first"
		return
	
	# Delete the save
	if save_manager.delete_save(selected_save):
		refresh_save_list()
		selected_save = ""
		load_button.disabled = true
		delete_button.disabled = true
		status_label.text = "Save deleted"

# Close button callback
func _on_close_pressed():
	hide_ui()

# Save selected callback
func _on_save_selected(index):
	selected_save = save_list.get_item_metadata(index)
	load_button.disabled = false
	delete_button.disabled = false
	save_name_input.text = selected_save

# Save completed callback
func _on_save_completed(success: bool, message: String):
	status_label.text = message
	if success:
		refresh_save_list()

# Load completed callback
func _on_load_completed(success: bool, message: String):
	status_label.text = message
	if success:
		hide_ui()
