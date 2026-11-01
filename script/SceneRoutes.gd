class_name SceneRoutes

# SceneRoutes - central definition of scene paths and safe scene switching
# All scene changes should go through here, to avoid scattered hardcoded paths, inconsistent casing, or paths pointing to missing scenes.

# Main menu and map selection scenes (not yet in the repo; the related buttons activate automatically once they are added)
const MAIN_MENU := "res://scene/MainMenu.tscn"
const MAP_SELECTION := "res://scene/MapSelection.tscn"

# Map scenes
const OFFICE := "res://scene/maps/Office.tscn"

# Check whether a scene exists (also works in exported builds)
static func is_available(path: String) -> bool:
	return ResourceLoader.exists(path)

# Safely switch scenes: if the target doesn't exist, warn and return false instead of failing silently
static func change_to(tree: SceneTree, path: String) -> bool:
	if not is_available(path):
		push_warning("[SceneRoutes] Scene does not exist, cannot switch: %s" % path)
		return false
	var err := tree.change_scene_to_file(path)
	if err != OK:
		push_error("[SceneRoutes] Failed to switch scene (%s): %s" % [error_string(err), path])
		return false
	return true

# Start the game: go to the map selection screen if it exists, otherwise go straight to the default map
static func start_game(tree: SceneTree) -> bool:
	if is_available(MAP_SELECTION):
		return change_to(tree, MAP_SELECTION)
	return change_to(tree, OFFICE)
