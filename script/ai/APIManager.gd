extends Node

# Singleton instance
static var instance = null

# API URLs are now managed centrally by APIConfig

# Current settings (from SettingsManager)
var current_settings = {}

# Get the singleton instance
static func get_instance() -> APIManager:
	if instance == null:
		instance = Engine.get_singleton("APIManager")
		if instance == null:
			print("[APIManager] Creating a new APIManager instance")
			instance = APIManager.new()
	return instance

func _enter_tree():
	# Set the singleton instance
	if instance == null:
		instance = self
	
	add_to_group("api_manager")

# Connect to the settings manager in _ready
func _ready():
	# Connect the settings changed signal
	SettingsManager.settings_changed.connect(_on_settings_changed)
	# Get the current settings
	current_settings = SettingsManager.get_settings()
	print("[APIManager] Connected to settings manager, current settings - API type: ", current_settings.api_type, ", model: ", current_settings.model)

# Settings changed callback
func _on_settings_changed(new_settings: Dictionary):
	current_settings = new_settings.duplicate()
	print("[APIManager] Settings updated - API type: ", current_settings.api_type, ", model: ", current_settings.model)

# Get the AI settings a character actually uses (its own settings if it has them, otherwise the defaults)
# Both sending requests and parsing responses must use this function so their API types match
func get_ai_settings_for(character_name: String = "") -> Dictionary:
	if character_name != "":
		return SettingsManager.get_character_ai_settings(character_name)
	return current_settings

# Get the API type a character actually uses (for parsing responses)
func get_api_type_for(character_name: String = "") -> String:
	return get_ai_settings_for(character_name).get("api_type", "")

# Generate dialog (supports per-character AI settings)
func generate_dialog(prompt: String, character_name: String = "") -> HTTPRequest:
	# Make sure the node is initialized
	if not is_inside_tree():
		push_error("APIManager is not properly initialized!")
		return null
	
	# Wait three frames to ensure full initialization
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Create a new HTTPRequest node without cleaning up previous ones
	var http_request = HTTPRequest.new()
	# Give each request a unique name
	http_request.name = "HTTPRequest_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())
	add_child(http_request)
	
	# Automatically clean up after the request completes
	http_request.request_completed.connect(func(result, response_code, headers, body):
		# Defer cleanup so the callbacks finish running first
		get_tree().create_timer(1.0).timeout.connect(func():
			if http_request and is_instance_valid(http_request):
				remove_child(http_request)
				http_request.queue_free()
		)
	)
	# Get the character's AI settings (the same settings used when parsing the response)
	var ai_settings = get_ai_settings_for(character_name)
	if character_name != "":
		print("[APIManager] Using AI settings for character ", character_name, " - API type: ", ai_settings.api_type, ", model: ", ai_settings.model)
	else:
		print("[APIManager] Using default AI settings - API type: ", ai_settings.api_type, ", model: ", ai_settings.model)
	
	# Build the request with APIConfig
	var headers = APIConfig.build_headers(ai_settings.api_type, ai_settings.api_key)
	var data = JSON.stringify(APIConfig.build_request_data(ai_settings.api_type, ai_settings.model, prompt))
	var url = APIConfig.get_url(ai_settings.api_type, ai_settings.model)
	
	print("[APIManager] Sending request to ", ai_settings.api_type, " API, model: ", ai_settings.model)
	
	print("[APIManager] Request URL: ", url)
	print("[APIManager] Created HTTPRequest node: ", http_request.name)
	http_request.request(url, headers, HTTPClient.METHOD_POST, data)
	return http_request

# Generate an AI decision
func generate_decision(prompt: String, character_name: String = "") -> HTTPRequest:
	return await generate_dialog(prompt, character_name)
