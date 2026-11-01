extends RefCounted

class_name BackgroundStoryManager

# Story background data structure
class StoryBackground:
	var map_name: String
	var company_name: String
	var background_description: String
	var preset_rules: Array[String]
	
	func _init(name: String, company: String, description: String, rules: Array[String]):
		map_name = name
		company_name = company
		background_description = description
		preset_rules = rules

# Social rule data structure
class SocialRule:
	var rule_text: String
	var is_custom: bool
	
	func _init(text: String, custom: bool = false):
		rule_text = text
		is_custom = custom

# Current state
static var current_map_name: String = "Office"
static var custom_rules: Array[String] = []

# Preset story background configs
static var BACKGROUND_CONFIGS = {
	"Office": {
		"company_name": "CountSheep Game Company",
		"company_description": "An innovative company focused on casual mini-games, whose main product is the mini-game \"CountSheep\". Game slogan: Can't Sleep? Count Sheep. Gameplay: users count the little sheep jumping across their phone screen, then tap a 3x3 grid of number buttons to enter the count and score points. The game is currently very popular, attracting lots of trendy young people who pay for sheep skins and button skins.",
		"environment_description": "This is a modern company with several work areas, meeting rooms, and break areas. The office is bright and minimalist, with large windows overlooking the scenery outside. The work environment is relaxed and pleasant, encouraging innovation and teamwork.",
		"time_period": "Modern day (2024)",
		"cultural_context": "Modern urban office culture that values work-life balance, teamwork, and innovative thinking.",
		"economic_situation": "The company is in a period of rapid growth, game revenue is growing steadily, and employees are well compensated.",
		"social_rules": [
			"Maintain a professional attitude during working hours",
			"Encourage teamwork and knowledge sharing",
			"Respect colleagues' personal space and work habits",
			"Meeting rooms must be booked in advance",
			"Keep work areas tidy",
			"It's fine to relax a bit during the lunch break",
			"Important decisions require team discussion"
		]
	},
	"School": {
		"company_name": "Sunshine Academy",
		"company_description": "A modern school focused on well-rounded development, dedicated to building students' academic ability and overall character. The school has comprehensive teaching facilities and a rich range of extracurricular activities.",
		"environment_description": "The campus is beautiful, with classroom buildings, a library, laboratories, a gymnasium, and other facilities. Tree-lined paths and a strong learning atmosphere.",
		"time_period": "Modern day (2024)",
		"cultural_context": "An educational environment that values passing on knowledge, building character, and teacher-student relationships.",
		"economic_situation": "The school is well funded, has comprehensive facilities, and teachers are paid steadily.",
		"social_rules": [
			"Stay quiet and pay attention during class",
			"Respect teachers and classmates",
			"Finish homework and assignments on time",
			"Keep the campus clean and tidy",
			"Follow school rules and discipline",
			"Participate actively in class discussions",
			"It's fine to rest and chat a bit between classes"
		]
	},
	"Jail": {
		"company_name": "New Hope Prison",
		"company_description": "A modern prison dedicated to rehabilitating offenders and reintegrating them into society. It uses humane management and emphasizes education and vocational training.",
		"environment_description": "The prison is well equipped, with cells, a cafeteria, a library, workshops, and other areas. The environment is relatively closed off but well managed.",
		"time_period": "Modern day (2024)",
		"cultural_context": "A prison rehabilitation culture that emphasizes discipline, order, and personal reform.",
		"economic_situation": "The prison is run by the book, with basic living provisions and work opportunities.",
		"social_rules": [
			"Strictly follow the prison schedule",
			"Obey the instructions of the staff",
			"No conflicts or violence",
			"Participate actively in rehabilitation activities",
			"Maintain personal and environmental hygiene",
			"Respect other inmates",
			"Attend work and study sessions on time"
		]
	}
}

# Currently active story background
static var current_background: StoryBackground

# File path for storing user-defined rules
static var CUSTOM_RULES_FILE = "user://custom_social_rules.json"

# Initialize the background story manager
static func initialize(map_name: String = "Office"):
	set_background(map_name)

# Set the story background for the current map
static func set_background(map_name: String):
	if not BACKGROUND_CONFIGS.has(map_name):
		print("[BackgroundStoryManager] Warning: no background config found for map '%s', using the default Office config" % map_name)
		map_name = "Office"
	
	var config = BACKGROUND_CONFIGS[map_name]
	var social_rules_array: Array[String] = []
	for rule in config["social_rules"]:
		social_rules_array.append(rule)
	
	current_background = StoryBackground.new(
		map_name,
		config["company_name"],
		config["company_description"] + "\n" + config["environment_description"] + "\nTime period: " + config["time_period"] + "\nCultural context: " + config["cultural_context"] + "\nEconomic situation: " + config["economic_situation"],
		social_rules_array
	)
	
	current_map_name = map_name
	
	# Load user-defined rules
	load_custom_rules()
	
	print("[BackgroundStoryManager] Story background set: %s" % map_name)

# Get the current story background info (for prompts)
static func get_background_info_for_prompt() -> String:
	if not current_background:
		initialize()
	
	var info = ""
	info += "\n\n=== Story Background ==="
	info += "\nOrganization name: " + current_background.company_name
	info += "\n" + current_background.background_description
	
	info += "\n\n=== Social Rules ==="
	info += "\nThese are the social rules and code of conduct you must follow:"
	
	# Add preset rules
	for i in range(current_background.preset_rules.size()):
		info += "\n%d. %s" % [i + 1, current_background.preset_rules[i]]
	
	# Add user-defined rules
	if custom_rules.size() > 0:
		info += "\n\n=== Additional Social Rules ==="
		info += "\nThese are additional important rules:"
		for i in range(custom_rules.size()):
			info += "\n%d. %s" % [i + 1, custom_rules[i]]
	
	info += "\n\nNote: all of your behavior and decisions should be consistent with the background and social rules above."
	
	return info



# Add a user-defined rule
static func add_custom_rule(rule: String):
	if rule.strip_edges().is_empty():
		return false
	
	custom_rules.append(rule.strip_edges())
	save_custom_rules()
	print("[BackgroundStoryManager] Added custom rule: %s" % rule)
	return true

# Remove a user-defined rule
static func remove_custom_rule(index: int):
	if index < 0 or index >= custom_rules.size():
		return false
	
	var removed_rule = custom_rules[index]
	custom_rules.remove_at(index)
	save_custom_rules()
	print("[BackgroundStoryManager] Removed custom rule: %s" % removed_rule)
	return true

# Get all custom rules
static func get_custom_rules() -> Array[String]:
	return custom_rules

# Clear all custom rules
static func clear_custom_rules():
	custom_rules.clear()
	save_custom_rules()
	print("[BackgroundStoryManager] Cleared all custom rules")

# Save user-defined rules to file
static func save_custom_rules():
	var save_data = {
		"map_name": current_map_name,
		"custom_rules": custom_rules
	}
	
	var file = FileAccess.open(CUSTOM_RULES_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("[BackgroundStoryManager] Custom rules saved")
	else:
		print("[BackgroundStoryManager] Failed to save custom rules")

# Load user-defined rules from file
static func load_custom_rules():
	if not FileAccess.file_exists(CUSTOM_RULES_FILE):
		return
	
	var file = FileAccess.open(CUSTOM_RULES_FILE, FileAccess.READ)
	if not file:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("[BackgroundStoryManager] Failed to parse custom rules file")
		return
	
	var save_data = json.data
	if save_data.has("map_name") and save_data["map_name"] == current_map_name:
		if save_data.has("custom_rules"):
			custom_rules = save_data["custom_rules"]
			print("[BackgroundStoryManager] Loaded %d custom rules" % custom_rules.size())

# Get the list of available maps
static func get_available_maps() -> Array[String]:
	var maps: Array[String] = []
	for key in BACKGROUND_CONFIGS.keys():
		maps.append(key)
	return maps

# Get the current map name
static func get_current_map_name() -> String:
	return current_map_name

# Get the current company name
static func get_current_company_name() -> String:
	if current_background:
		return current_background.company_name
	return "Unknown organization"

# Get the current background description
static func get_current_background_description() -> String:
	if current_background:
		return current_background.background_description
	return "No background description"

# Get preset rules
static func get_preset_rules() -> Array[String]:
	if current_background:
		return current_background.preset_rules
	return []

# Get all rules (preset + custom)
static func get_all_rules() -> Array[String]:
	var all_rules: Array[String] = []
	all_rules.append_array(get_preset_rules())
	all_rules.append_array(custom_rules)
	return all_rules

# Generate the full background and rules prompt
static func generate_background_prompt() -> String:
	var prompt = ""
	
	# Add the background description
	var background_desc = get_current_background_description()
	if not background_desc.is_empty():
		prompt += "## Story Background\n"
		prompt += background_desc + "\n\n"
	
	# Add social rules
	var all_rules = get_all_rules()
	if all_rules.size() > 0:
		prompt += "## Social Rules\n"
		for i in range(all_rules.size()):
			prompt += "%d. %s\n" % [i + 1, all_rules[i]]
		prompt += "\n"
	
	return prompt

# Generate simplified background info (for UI display)
static func get_background_summary() -> Dictionary:
	return {
		"map_name": current_map_name,
		"company_name": get_current_company_name(),
		"preset_rules_count": get_preset_rules().size(),
		"custom_rules_count": custom_rules.size(),
		"total_rules_count": get_all_rules().size()
	}

# Check whether a map exists
static func is_map_available(map_name: String) -> bool:
	return BACKGROUND_CONFIGS.has(map_name)
