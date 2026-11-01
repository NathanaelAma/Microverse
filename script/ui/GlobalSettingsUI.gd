extends CanvasLayer

# GlobalSettingsUI - game settings UI manager
# All settings are now managed centrally by SettingsManager

# Current settings (from SettingsManager)
var current_settings = {}

@onready var settings_ui = $SettingsUI
@onready var api_type_option = $"SettingsUI/NinePatchRect/VBoxContainer/TabContainer/API Settings/APITypeContainer/APITypeOption"
@onready var model_option = $"SettingsUI/NinePatchRect/VBoxContainer/TabContainer/API Settings/ModelContainer/ModelOption"
@onready var api_key_input = $"SettingsUI/NinePatchRect/VBoxContainer/TabContainer/API Settings/APIKeyContainer/APIKeyInput"
@onready var ai_label_checkbox = $"SettingsUI/NinePatchRect/VBoxContainer/TabContainer/API Settings/AILabelContainer/AILabelCheckBox"
@onready var save_button = $SettingsUI/NinePatchRect/VBoxContainer/ButtonContainer/SaveButton
@onready var cancel_button = $SettingsUI/NinePatchRect/VBoxContainer/ButtonContainer/CancelButton
@onready var map_button = $SettingsUI/NinePatchRect/VBoxContainer/TabContainer/Game/MapButton
@onready var main_menu_button = $SettingsUI/NinePatchRect/VBoxContainer/TabContainer/Game/MainMenuButton
@onready var quit_button = $SettingsUI/NinePatchRect/VBoxContainer/TabContainer/Game/QuitButton
@onready var window_mode_option = $SettingsUI/NinePatchRect/VBoxContainer/TabContainer/Game/WindowModeContainer/WindowModeOption
@onready var resolution_option = $SettingsUI/NinePatchRect/VBoxContainer/TabContainer/Game/ResolutionContainer/ResolutionOption

func _ready():
	hide_settings()
	
	# Initialize API type options
	for type in SettingsManager.api_types:
		api_type_option.add_item(type)
	
	# Connect to the settings manager
	SettingsManager.settings_changed.connect(_on_settings_changed)
	current_settings = SettingsManager.get_settings()
	update_ui()
	print("[GlobalSettingsUI] Connected to settings manager")
	
	# Connect signals
	api_type_option.item_selected.connect(_on_api_type_selected)
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	map_button.pressed.connect(_on_map_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# Hide buttons whose target scene doesn't exist, so clicking them can't fail to navigate
	map_button.visible = SceneRoutes.is_available(SceneRoutes.MAP_SELECTION)
	main_menu_button.visible = SceneRoutes.is_available(SceneRoutes.MAIN_MENU)
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	
	# Make this a singleton so it isn't destroyed on scene changes
	set_process_input(true)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if settings_ui.visible:
			hide_settings()
		else:
			show_settings()

# Settings changed callback
func _on_settings_changed(new_settings: Dictionary):
	current_settings = new_settings.duplicate()
	update_ui()
	print("[GlobalSettingsUI] Settings updated, UI refreshed")

# Update the UI display
func update_ui():
	# Set the API type
	var api_index = SettingsManager.api_types.find(current_settings.api_type)
	if api_index >= 0:
		api_type_option.selected = api_index
	
	# Update model options
	model_option.clear()
	var models = SettingsManager.get_models_for_api(current_settings.api_type)
	for model in models:
		model_option.add_item(model)
	
	# Select the current model
	var model_index = models.find(current_settings.model)
	if model_index >= 0:
		model_option.select(model_index)
	
	# Set the API key
	api_key_input.text = current_settings.api_key
	
	# Set the AI label checkbox
	ai_label_checkbox.button_pressed = current_settings.get("show_ai_model_label", true)
	
	# Show/hide the API key input based on API type
	api_key_input.get_parent().visible = current_settings.api_type != "Ollama"

	# Initialize resolution/window mode UI
	_init_display_options()
	_sync_display_options()

# API type selected callback
func _on_api_type_selected(index):
	current_settings.api_type = SettingsManager.api_types[index]
	# Reset model selection
	var models = SettingsManager.get_models_for_api(current_settings.api_type)
	current_settings.model = models[0]
	update_ui()

# Initialize window mode and resolution options
func _init_display_options():
	if window_mode_option.get_item_count() == 0:
		window_mode_option.add_item("Windowed")
		window_mode_option.add_item("Fullscreen")
		window_mode_option.add_item("Exclusive Fullscreen")
	if resolution_option.get_item_count() == 0:
		for r in ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440", "2880 x 1800", "3840 x 2160"]:
			resolution_option.add_item(r)

func _sync_display_options():
	var mode = str(current_settings.get("window_mode", "windowed"))
	var idx = 0
	match mode:
		"windowed": idx = 0
		"fullscreen": idx = 1
		"exclusive_fullscreen": idx = 2
	window_mode_option.select(idx)

	var w = int(current_settings.get("screen_width", 1280))
	var h = int(current_settings.get("screen_height", 720))
	var target = "%d x %d" % [w, h]
	var found = false
	for i in range(resolution_option.get_item_count()):
		if resolution_option.get_item_text(i) == target:
			resolution_option.select(i)
			found = true
			break
	if not found:
		resolution_option.add_item(target)
		resolution_option.select(resolution_option.get_item_count() - 1)
	resolution_option.disabled = (current_settings.get("window_mode", "windowed") == "fullscreen")

func _on_window_mode_selected(_i):
	var t = window_mode_option.get_item_text(window_mode_option.selected)
	match t:
		"Windowed":
			current_settings.window_mode = "windowed"
		"Fullscreen":
			current_settings.window_mode = "fullscreen"
		"Exclusive Fullscreen":
			current_settings.window_mode = "exclusive_fullscreen"
	resolution_option.disabled = current_settings.window_mode == "fullscreen"

func _on_resolution_selected(_i):
	var txt = resolution_option.get_item_text(resolution_option.selected)
	var parts = txt.split("x")
	if parts.size() == 2:
		current_settings.screen_width = int(parts[0].strip_edges())
		current_settings.screen_height = int(parts[1].strip_edges())

# Save button callback
func _on_save_pressed():
	current_settings.model = model_option.get_item_text(model_option.selected)
	if current_settings.api_type != "Ollama":
		current_settings.api_key = api_key_input.text
	
	# Save the AI label display setting
	current_settings.show_ai_model_label = ai_label_checkbox.button_pressed
	
	# Update settings through SettingsManager
	SettingsManager.update_settings(current_settings)
	hide_settings()
	print("[GlobalSettingsUI] Settings saved and all components notified")

# Cancel button callback
func _on_cancel_pressed():
	current_settings = SettingsManager.get_settings()
	update_ui()
	hide_settings()

# Map button callback
func _on_map_pressed():
	if SceneRoutes.change_to(get_tree(), SceneRoutes.MAP_SELECTION):
		hide_settings()

# Main menu button callback
func _on_main_menu_pressed():
	if SceneRoutes.change_to(get_tree(), SceneRoutes.MAIN_MENU):
		hide_settings()

# Quit button callback
func _on_quit_pressed():
	get_tree().quit()

# Show the settings UI
func show_settings():
	settings_ui.visible = true

# Hide the settings UI
func hide_settings():
	settings_ui.visible = false

# Check whether the settings UI is visible
func is_settings_visible() -> bool:
	return settings_ui.visible
