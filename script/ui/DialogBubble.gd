extends Node2D

var target_node: Node2D = null
var text_label: Label
var background: NinePatchRect
var tween: Tween
var is_target_on_right: bool = false

func _ready():
	# Set the display layer
	z_index = 100
	
	# Create the background
	background = NinePatchRect.new()
	background.texture = preload("res://asset/ui/dialog_bubble_bg.png")
	background.patch_margin_left = 8
	background.patch_margin_top = 8
	background.patch_margin_right = 8
	background.patch_margin_bottom = 8
	add_child(background)
	
	# Create the text label
	text_label = Label.new()
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(100, 40)
	# Set a custom font
	var custom_font = preload("res://asset/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
	text_label.add_theme_font_override("font", custom_font)
	text_label.add_theme_font_size_override("font_size", 12) # Set the font size
	text_label.add_theme_color_override("font_color", Color(0, 0, 0, 1)) # Set the font color to black
	background.add_child(text_label)
	
	# Hidden initially
	hide()

# Show dialog content
func show_dialog(text: String, duration: float = 5.0, target_on_right: bool = false):
	text_label.text = text
	is_target_on_right = target_on_right
	
	# Resize the background to fit the text
	await get_tree().process_frame
	var text_size = text_label.size
	background.size = text_size + Vector2(20, 20)
	text_label.position = Vector2(10, 10)
	
	# Show the bubble
	show()
	
	# Create the fade-out animation
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(hide)

# Update position
func _process(_delta):
	if target_node and visible:
		# Horizontal centering: align the bubble center with the character center
		var horizontal_offset = -background.size.x / 2
		# Compute the vertical offset from the bubble height so it never covers the character
		# Bubble height + extra spacing (20 pixels) ensures it doesn't cover the character
		var vertical_offset = -(background.size.y + 20)
		# Position the bubble centered directly above the target node
		global_position = target_node.global_position + Vector2(horizontal_offset, vertical_offset)
