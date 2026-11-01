extends Control

func _ready():
	# 连接地图选择按钮信号
	$MarginContainer/ScrollContainer/GridContainer/PanelContainer/VBoxContainer/OfficeButton.pressed.connect(_on_office_selected)
	$BackButton.pressed.connect(_on_back_pressed)

func _on_office_selected():
	# 设置办公室故事背景
	BackgroundStoryManager.set_background("Office")
	# 加载办公室场景
	SceneRoutes.change_to(get_tree(), SceneRoutes.OFFICE)

func _on_back_pressed():
	# 返回主菜单
	SceneRoutes.change_to(get_tree(), SceneRoutes.MAIN_MENU)
