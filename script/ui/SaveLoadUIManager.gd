# SaveLoadUIManager.gd - save/load UI manager
# A CanvasLayer UI used to show the save screen in-game

extends CanvasLayer

@onready var save_load_ui = $SaveLoadUI

func _ready():
	hide_ui()
	
	# Make this a singleton so it isn't destroyed on scene changes
	set_process_input(true)

# Handle input events
func _input(event):
	if event.is_action_pressed("toggle_save_load"):  # F3 key
		if save_load_ui.visible:
			hide_ui()
		else:
			show_ui()
		get_viewport().set_input_as_handled()
	
	# Close the UI with the ESC key
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if save_load_ui.visible:
			hide_ui()
			get_viewport().set_input_as_handled()

# Show the save screen
func show_ui():
	save_load_ui.show()
	save_load_ui.refresh_save_list()

# Hide the save screen
func hide_ui():
	save_load_ui.hide()