extends VBoxContainer

# UI control references
@onready var use_default_checkbox = $UseDefaultCheckBox
@onready var api_type_option = $APITypeContainer/APITypeOption
@onready var model_option = $ModelContainer/ModelOption
@onready var api_key_input = $APIKeyContainer/APIKeyInput
@onready var save_button = $ButtonContainer/SaveButton
@onready var reset_button = $ButtonContainer/ResetButton

# Name of the currently selected character
var current_character_name: String = ""

# API type mapping (from SettingsManager)
var api_types: Array[String] = []

func _ready():
	# Get the API type list from SettingsManager
	api_types = SettingsManager.api_types
	
	# Initialize API type options
	for api_type in api_types:
		api_type_option.add_item(api_type)
	
	# Connect signals
	use_default_checkbox.toggled.connect(_on_use_default_toggled)
	api_type_option.item_selected.connect(_on_api_type_selected)
	save_button.pressed.connect(_on_save_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	
	# Connect the settings changed signal
	SettingsManager.settings_changed.connect(_on_settings_changed)
	
	# Initialize the UI
	_update_ui_state()

func set_character(character_name: String):
	"""Set the current character"""
	# If there was a previous character, save its current state first
	if not current_character_name.is_empty() and current_character_name != character_name:
		_auto_save_current_settings()
	
	current_character_name = character_name
	_load_character_settings()

func _auto_save_current_settings():
	"""Auto-save the current settings state"""
	if current_character_name.is_empty():
		return
	
	if use_default_checkbox.button_pressed:
		# If "use default settings" is checked, delete the character's own settings
		SettingsManager.remove_character_ai_settings(current_character_name)
		print("[CharacterAISettings] Auto-save: character ", current_character_name, " uses the default AI settings")
	else:
		# If unchecked, save the current UI settings as the character's own settings
		var settings = {
			"api_type": api_types[api_type_option.selected] if api_type_option.selected >= 0 else "Ollama",
			"model": model_option.get_item_text(model_option.selected) if model_option.selected >= 0 else "",
			"api_key": api_key_input.text
		}
		
		SettingsManager.set_character_ai_settings(current_character_name, settings)
		print("[CharacterAISettings] Auto-save: custom AI settings for character ", current_character_name, " - API type: ", settings.api_type, ", model: ", settings.model)

func _load_character_settings():
	"""Load the character's settings"""
	if current_character_name.is_empty():
		return
	
	# Check whether the character has its own settings
	var has_independent_settings = SettingsManager.has_character_ai_settings(current_character_name)
	use_default_checkbox.button_pressed = not has_independent_settings
	
	if has_independent_settings:
		# Load the character's own settings
		var character_settings = SettingsManager.get_character_ai_settings(current_character_name)
		_apply_settings_to_ui(character_settings)
	else:
		# Load the default settings
		var default_settings = SettingsManager.current_settings
		_apply_settings_to_ui(default_settings)
	
	_update_ui_state()

func _apply_settings_to_ui(settings: Dictionary):
	"""Apply settings to the UI"""
	# Set the API type
	var api_type = settings.get("api_type", "Ollama")
	var api_type_index = api_types.find(api_type)
	if api_type_index >= 0:
		api_type_option.selected = api_type_index
	
	# Update the model list
	_update_model_list(api_type)
	
	# Set the model
	var model = settings.get("model", "")
	if not model.is_empty():
		for i in range(model_option.get_item_count()):
			if model_option.get_item_text(i) == model:
				model_option.selected = i
				break
	
	# Set the API key
	var api_key = settings.get("api_key", "")
	api_key_input.text = api_key

func _update_model_list(api_type: String):
	"""Update the model list"""
	model_option.clear()
	
	var models = SettingsManager.get_available_models(api_type)
	for model in models:
		model_option.add_item(model)

func _update_ui_state():
	"""Update the UI state"""
	var use_default = use_default_checkbox.button_pressed
	
	# Disable/enable the settings controls
	api_type_option.disabled = use_default
	model_option.disabled = use_default
	api_key_input.editable = not use_default
	save_button.disabled = use_default
	reset_button.disabled = use_default or not SettingsManager.has_character_ai_settings(current_character_name)

func _on_use_default_toggled(button_pressed: bool):
	"""Use-default-settings checkbox toggled"""
	if button_pressed:
		# Switch to using the default settings
		var default_settings = SettingsManager.current_settings
		_apply_settings_to_ui(default_settings)
	else:
		# Switch to custom settings
		if SettingsManager.has_character_ai_settings(current_character_name):
			# If custom settings exist, load them
			var character_settings = SettingsManager.character_ai_settings.get(current_character_name, {})
			_apply_settings_to_ui(character_settings)
		else:
			# If there are no custom settings, start from the current default settings
			var default_settings = SettingsManager.current_settings
			_apply_settings_to_ui(default_settings)
	
	_update_ui_state()

func _on_api_type_selected(index: int):
	"""API type selection changed"""
	var api_type = api_types[index]
	_update_model_list(api_type)
	
	# Clear the API key (different API types may need different keys)
	if api_type == "Ollama":
		api_key_input.text = ""
		api_key_input.placeholder_text = "Ollama doesn't need an API key"
	else:
		api_key_input.placeholder_text = "Enter your " + api_type + " API key"

func _on_save_pressed():
	"""Save settings"""
	if current_character_name.is_empty():
		print("Error: no character selected")
		return
	
	if use_default_checkbox.button_pressed:
		# Delete the character's own settings
		SettingsManager.remove_character_ai_settings(current_character_name)
		print("Deleted the custom AI settings for character ", current_character_name)
	else:
		# Save the character's own settings
		var settings = {
			"api_type": api_types[api_type_option.selected],
			"model": model_option.get_item_text(model_option.selected) if model_option.selected >= 0 else "",
			"api_key": api_key_input.text
		}
		
		SettingsManager.set_character_ai_settings(current_character_name, settings)
		print("Saved AI settings for character ", current_character_name, " - API type: ", settings.api_type, ", model: ", settings.model)
	
	_update_ui_state()

func _on_reset_pressed():
	"""Reset to default settings"""
	if current_character_name.is_empty():
		return
	
	# Delete the character's own settings
	SettingsManager.remove_character_ai_settings(current_character_name)
	
	# Switch to using the default settings
	use_default_checkbox.button_pressed = true
	_on_use_default_toggled(true)
	
	print("Reset AI settings for character ", current_character_name, " to default")

func _on_settings_changed(new_settings = null):
	"""Update the UI when global settings change"""
	if use_default_checkbox.button_pressed:
		# If currently using the default settings, update the UI
		var default_settings = new_settings if new_settings else SettingsManager.current_settings
		_apply_settings_to_ui(default_settings)
