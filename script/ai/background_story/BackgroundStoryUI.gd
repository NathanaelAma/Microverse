extends Control

class_name BackgroundStoryUI

# UI node references
@onready var map_label: Label
@onready var company_label: Label
@onready var preset_rules_list: VBoxContainer
@onready var custom_rules_list: VBoxContainer
@onready var add_rule_input: LineEdit
@onready var add_rule_button: Button
@onready var clear_rules_button: Button
@onready var refresh_button: Button

# Signals
signal rules_changed

func _ready():
	# Find UI nodes
	find_ui_nodes()
	
	# Connect signals
	connect_signals()
	
	# Initialize display
	refresh_display()

func find_ui_nodes():
	# These nodes must be created in the scene beforehand
	map_label = find_child("MapLabel", true, false)
	company_label = find_child("CompanyLabel", true, false)
	preset_rules_list = find_child("PresetRulesList", true, false)
	custom_rules_list = find_child("CustomRulesList", true, false)
	add_rule_input = find_child("AddRuleInput", true, false)
	add_rule_button = find_child("AddRuleButton", true, false)
	clear_rules_button = find_child("ClearRulesButton", true, false)
	refresh_button = find_child("RefreshButton", true, false)

func connect_signals():
	if add_rule_button:
		add_rule_button.pressed.connect(_on_add_rule_pressed)
	
	if clear_rules_button:
		clear_rules_button.pressed.connect(_on_clear_rules_pressed)
	
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)
	
	if add_rule_input:
		add_rule_input.text_submitted.connect(_on_rule_input_submitted)

# Refresh displayed content
func refresh_display():
	update_map_info()
	update_preset_rules()
	update_custom_rules()

# Update map info display
func update_map_info():
	var map_name = BackgroundStoryManager.get_current_map_name()
	var company_name = BackgroundStoryManager.get_current_company_name()
	
	if map_label:
		map_label.text = "Current map: " + map_name
	
	if company_label:
		company_label.text = "Organization: " + company_name

# Update preset rules display
func update_preset_rules():
	if not preset_rules_list:
		return
	
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
		rule_label.add_theme_color_override("font_color", Color.WHITE)
		preset_rules_list.add_child(rule_label)

# Update custom rules display
func update_custom_rules():
	if not custom_rules_list:
		return
	
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
	if not add_rule_input:
		return
	
	var rule_text = add_rule_input.text.strip_edges()
	if rule_text.is_empty():
		return
	
	if BackgroundStoryManager.add_custom_rule(rule_text):
		add_rule_input.text = ""
		update_custom_rules()
		rules_changed.emit()

# Submit on Enter in the input field
func _on_rule_input_submitted(text: String):
	_on_add_rule_pressed()

# Delete rule button pressed
func _on_delete_rule_pressed(index: int):
	if BackgroundStoryManager.remove_custom_rule(index):
		update_custom_rules()
		rules_changed.emit()

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
		update_custom_rules()
		rules_changed.emit()
		dialog.queue_free()
	)
	
	# Connect the canceled signal
	dialog.canceled.connect(func():
		dialog.queue_free()
	)

# Refresh button pressed
func _on_refresh_pressed():
	refresh_display()

# Set the map (called externally)
func set_map(map_name: String):
	BackgroundStoryManager.set_background(map_name)
	refresh_display()
	rules_changed.emit()

# Get the current rule count
func get_total_rules_count() -> int:
	var preset_count = BackgroundStoryManager.get_preset_rules().size()
	var custom_count = BackgroundStoryManager.get_custom_rules().size()
	return preset_count + custom_count

# Create a simple UI layout (if the scene has no preset UI)
func create_simple_ui():
	# Create the main container
	var main_container = VBoxContainer.new()
	add_child(main_container)
	
	# Map info
	var info_container = VBoxContainer.new()
	main_container.add_child(info_container)
	
	map_label = Label.new()
	map_label.name = "MapLabel"
	map_label.text = "Current map: Unknown"
	info_container.add_child(map_label)
	
	company_label = Label.new()
	company_label.name = "CompanyLabel"
	company_label.text = "Organization: Unknown"
	info_container.add_child(company_label)
	
	# Separator
	main_container.add_child(HSeparator.new())
	
	# Preset rules title
	var preset_title = Label.new()
	preset_title.text = "Preset social rules:"
	preset_title.add_theme_color_override("font_color", Color.CYAN)
	main_container.add_child(preset_title)
	
	# Preset rules list
	preset_rules_list = VBoxContainer.new()
	preset_rules_list.name = "PresetRulesList"
	main_container.add_child(preset_rules_list)
	
	# Separator
	main_container.add_child(HSeparator.new())
	
	# Custom rules title
	var custom_title = Label.new()
	custom_title.text = "Custom social rules:"
	custom_title.add_theme_color_override("font_color", Color.YELLOW)
	main_container.add_child(custom_title)
	
	# Custom rules list
	custom_rules_list = VBoxContainer.new()
	custom_rules_list.name = "CustomRulesList"
	main_container.add_child(custom_rules_list)
	
	# Add rule input
	var input_container = HBoxContainer.new()
	main_container.add_child(input_container)
	
	add_rule_input = LineEdit.new()
	add_rule_input.name = "AddRuleInput"
	add_rule_input.placeholder_text = "Enter a new social rule..."
	add_rule_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_container.add_child(add_rule_input)
	
	add_rule_button = Button.new()
	add_rule_button.name = "AddRuleButton"
	add_rule_button.text = "Add"
	input_container.add_child(add_rule_button)
	
	# Action buttons
	var button_container = HBoxContainer.new()
	main_container.add_child(button_container)
	
	clear_rules_button = Button.new()
	clear_rules_button.name = "ClearRulesButton"
	clear_rules_button.text = "Clear Custom Rules"
	button_container.add_child(clear_rules_button)
	
	refresh_button = Button.new()
	refresh_button.name = "RefreshButton"
	refresh_button.text = "Refresh"
	button_container.add_child(refresh_button)
	
	# Reconnect signals
	connect_signals()