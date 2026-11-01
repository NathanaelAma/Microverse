extends Control

func _ready():
	# Connect map selection button signals
	$MarginContainer/ScrollContainer/GridContainer/PanelContainer/VBoxContainer/OfficeButton.pressed.connect(_on_office_selected)
	$BackButton.pressed.connect(_on_back_pressed)

func _on_office_selected():
	# Set the office story background
	BackgroundStoryManager.set_background("Office")
	# Load the office scene
	SceneRoutes.change_to(get_tree(), SceneRoutes.OFFICE)

func _on_back_pressed():
	# Return to the main menu
	SceneRoutes.change_to(get_tree(), SceneRoutes.MAIN_MENU)
