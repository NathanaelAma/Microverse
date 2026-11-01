extends Label

# Character name (used to look up the character's own AI settings)
var character_name: String = ""

# Current settings
var current_settings = {
	"api_type": "Ollama",
	"model": "qwen2.5:1.5b",
	"api_key": ""
}

func _ready():
	# Get the character name
	var parent_character = get_parent()
	if parent_character:
		character_name = parent_character.name
	
	# Load and display the current settings
	load_and_update_display()
	
	# Set the label style
	setup_label_style()
	
	# Connect to SettingsManager's settings updated signal
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.has_signal("settings_changed"):
		settings_manager.settings_changed.connect(_on_settings_updated)

func setup_label_style():
	# Set the font color to white
	modulate = Color.WHITE  # White
	
	# Set the font size
	add_theme_font_size_override("font_size", 16)
	
	# Set a white outline effect
	add_theme_color_override("font_outline_color", Color.NAVY_BLUE)
	add_theme_constant_override("outline_size", 1)

func load_and_update_display():
	# Load settings
	load_settings()
	
	# Check whether the AI model label should be shown (from global settings)
	var settings_manager = get_node_or_null("/root/SettingsManager")
	var should_show = true
	if settings_manager:
		var global_settings = settings_manager.get_settings()
		should_show = global_settings.get("show_ai_model_label", true)
	visible = should_show
	
	# Update the display text
	update_display_text()

func load_settings():
	# Use SettingsManager to get the character's AI settings
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager:
		if character_name != "":
			current_settings = settings_manager.get_character_ai_settings(character_name)
			print("[AIModelLabel] Character ", character_name, " uses AI settings - API type: ", current_settings.api_type, ", model: ", current_settings.model)
		else:
			current_settings = settings_manager.get_settings()
			print("[AIModelLabel] Using default AI settings - API type: ", current_settings.api_type, ", model: ", current_settings.model)
	else:
		print("[AIModelLabel] Could not find SettingsManager, using default settings")

func update_display_text():
	# Format the display text
	# var display_text = current_settings.api_type + ": " + current_settings.model
	var display_text = current_settings.model
	text = display_text
	
	# Dynamically adjust the offset to keep the text centered
	adjust_offset_for_text()

func _on_settings_updated(new_settings):
	# Reload and update the display when settings change
	load_settings()
	update_display_text()
	
	# Check whether the AI model label should be shown (always from global settings)
	var should_show = new_settings.get("show_ai_model_label", true)
	visible = should_show

# Dynamically adjust the offset to keep the text center-aligned
func adjust_offset_for_text():
	# Wait one frame to make sure the text has updated
	await get_tree().process_frame
	
	# Get the actual rendered size of the text
	var text_size = get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size"))
	
	# Compute the required width (text width + some padding)
	var required_width = text_size.x + 10  # 5 pixels of padding on each side
	var half_width = required_width / 2.0
	
	# Dynamically adjust the offset to keep the label centered
	offset_left = -half_width
	offset_right = half_width

# Public method: manually refresh the display (for external callers)
func refresh_display():
	load_and_update_display()
