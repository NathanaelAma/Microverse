# SettingsManager.gd - settings manager singleton
# Centrally manages game settings, using signals for decoupling

extends Node

# Settings changed signal
signal settings_changed(new_settings)

# Settings file paths
const CONFIG_FILE = "user://settings.cfg"
const CHARACTER_AI_CONFIG_FILE = "user://character_ai_settings.cfg"

# Current settings (default AI settings)
var current_settings = {
	"api_type": "Ollama",
	"model": "qwen2.5:1.5b",
	"api_key": "",
	"show_ai_model_label": true,
	# Display settings
	"window_mode": "windowed", # windowed | fullscreen | exclusive_fullscreen
	"screen_width": 1280,
	"screen_height": 720
}

# Per-character AI settings
var character_ai_settings = {}

# Available API types and models (managed centrally by APIConfig)
var api_types: Array[String] = []
var _api_config_loaded: bool = false

func _ready():
	_load_api_config()
	load_settings()
	print("[SettingsManager] Settings manager initialized")

# Load API configuration
func _load_api_config():
	if not _api_config_loaded:
		api_types = APIConfig.get_api_types()
		_api_config_loaded = true

# Get the current settings
func get_settings() -> Dictionary:
	return current_settings.duplicate()

# Update settings and notify all listeners
func update_settings(new_settings: Dictionary):
	current_settings = new_settings.duplicate()
	save_settings()
	settings_changed.emit(current_settings.duplicate())
	print("[SettingsManager] Settings updated and all listeners notified")
	# Apply display settings
	apply_display_settings()

# Get the model list for the given API type
func get_models_for_api(api_type: String) -> Array:
	_load_api_config()
	return APIConfig.get_models_for_api(api_type)

# Get the available model list (for compatibility)
func get_available_models(api_type: String) -> Array:
	return get_models_for_api(api_type)

# Save settings to file
func save_settings():
	var file = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_settings))
		file.close()
		print("[SettingsManager] Settings saved to file")
	else:
		print("[SettingsManager Error] Could not open config file for writing: ", CONFIG_FILE)
	
	# Save per-character AI settings
	save_character_ai_settings()

# Load settings from file
func load_settings():
	if FileAccess.file_exists(CONFIG_FILE):
		var file = FileAccess.open(CONFIG_FILE, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			
			if content.strip_edges() != "":
				var data = JSON.parse_string(content)
				if data:
					current_settings = data
					print("[SettingsManager] Settings loaded from file")
				else:
					print("[SettingsManager Error] JSON parsing failed, using default settings")
			else:
				print("[SettingsManager Warning] Config file is empty, using default settings")
		else:
			print("[SettingsManager Error] Could not open config file for reading: ", CONFIG_FILE)
	else:
		print("[SettingsManager] Config file does not exist, using default settings")
	
	# Load per-character AI settings
	load_character_ai_settings()
	# Apply display settings
	apply_display_settings()

# Get a character's AI settings (its own settings take priority; otherwise returns the defaults)
func get_character_ai_settings(character_name: String) -> Dictionary:
	if character_ai_settings.has(character_name):
		return character_ai_settings[character_name].duplicate()
	else:
		return current_settings.duplicate()

# Set a character's AI config
func set_character_ai_settings(character_name: String, settings: Dictionary):
	character_ai_settings[character_name] = settings.duplicate()
	save_character_ai_settings()
	settings_changed.emit(current_settings.duplicate())
	print("[SettingsManager] AI settings updated for character ", character_name)

# Delete a character's AI settings (revert to the defaults)
func remove_character_ai_settings(character_name: String):
	if character_ai_settings.has(character_name):
		character_ai_settings.erase(character_name)
		save_character_ai_settings()
		settings_changed.emit(current_settings.duplicate())
		print("[SettingsManager] Character ", character_name, " reverted to the default AI settings")

# Check whether a character has its own AI settings
func has_character_ai_settings(character_name: String) -> bool:
	return character_ai_settings.has(character_name)

# Get the list of characters that have their own AI settings
func get_characters_with_ai_settings() -> Array:
	return character_ai_settings.keys()

# Save per-character AI settings to file
func save_character_ai_settings():
	var file = FileAccess.open(CHARACTER_AI_CONFIG_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(character_ai_settings))
		file.close()
		print("[SettingsManager] Per-character AI settings saved to file")
	else:
		print("[SettingsManager Error] Could not open the per-character AI config file for writing: ", CHARACTER_AI_CONFIG_FILE)

# Load per-character AI settings from file
func load_character_ai_settings():
	if FileAccess.file_exists(CHARACTER_AI_CONFIG_FILE):
		var file = FileAccess.open(CHARACTER_AI_CONFIG_FILE, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			
			if content.strip_edges() != "":
				var data = JSON.parse_string(content)
				if data:
					character_ai_settings = data
					print("[SettingsManager] Per-character AI settings loaded from file")
				else:
					print("[SettingsManager Error] Failed to parse per-character AI settings JSON")
			else:
				print("[SettingsManager Warning] Per-character AI config file is empty")
		else:
			print("[SettingsManager Error] Could not open the per-character AI config file for reading: ", CHARACTER_AI_CONFIG_FILE)
	else:
		print("[SettingsManager] Per-character AI config file does not exist, using an empty config")

# Apply display and window mode settings
func apply_display_settings(settings: Dictionary = {}):
	var s = settings if not settings.is_empty() else current_settings
	var win := get_tree().root
	if not win:
		return

	var mode: String = s.get("window_mode", "windowed")
	match mode:
		"exclusive_fullscreen":
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			var w = int(s.get("screen_width", 1920))
			var h = int(s.get("screen_height", 1080))
			win.size = Vector2i(w, h)
		"fullscreen":
			win.mode = Window.MODE_FULLSCREEN
		"windowed":
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
			var w2 = int(s.get("screen_width", 1280))
			var h2 = int(s.get("screen_height", 720))
			win.size = Vector2i(w2, h2)
			var screen = win.current_screen
			var scr = DisplayServer.screen_get_size(screen)
			win.position = (scr - win.size) / 2

	# Fallback scaling setting
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
