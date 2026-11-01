class_name SceneRoutes

# SceneRoutes - 场景路径的统一定义与安全切换
# 所有场景跳转都应通过此处，避免路径分散硬编码、大小写不一致或指向不存在的场景。

# 主菜单与地图选择场景（尚未加入仓库；加入后相关按钮会自动生效）
const MAIN_MENU := "res://scene/MainMenu.tscn"
const MAP_SELECTION := "res://scene/MapSelection.tscn"

# 地图场景
const OFFICE := "res://scene/maps/Office.tscn"

# 检查场景是否存在（导出包中同样有效）
static func is_available(path: String) -> bool:
	return ResourceLoader.exists(path)

# 安全切换场景：目标不存在时给出警告并返回false，而不是静默失败
static func change_to(tree: SceneTree, path: String) -> bool:
	if not is_available(path):
		push_warning("[SceneRoutes] 场景不存在，无法切换：%s" % path)
		return false
	var err := tree.change_scene_to_file(path)
	if err != OK:
		push_error("[SceneRoutes] 切换场景失败（%s）：%s" % [error_string(err), path])
		return false
	return true

# 开始游戏：有地图选择界面则进入，否则直接进入默认地图
static func start_game(tree: SceneTree) -> bool:
	if is_available(MAP_SELECTION):
		return change_to(tree, MAP_SELECTION)
	return change_to(tree, OFFICE)
