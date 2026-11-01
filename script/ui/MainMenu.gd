extends Control

func _ready():
	# Connect button signals
	$NinePatchRect/VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$NinePatchRect/VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$NinePatchRect/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _on_start_pressed():
	# Switch to the map selection scene (or go straight to the default map if it doesn't exist)
	SceneRoutes.start_game(get_tree())

func _on_settings_pressed():
	# Use the global settings UI (fetched dynamically)
	var settings = get_node_or_null("/root/GlobalSettings")
	if settings and settings.has_method("show_settings"):
		settings.show_settings()
	else:
		# If the global settings can't be found, switch to the GlobalSettingsUI scene
		get_tree().change_scene_to_file("res://scene/ui/GlobalSettingsUI.tscn")

func _on_quit_pressed():
	# Quit the game
	get_tree().quit()
