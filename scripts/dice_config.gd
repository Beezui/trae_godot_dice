class_name DiceConfig

var dice_face_manager

# 不同场景的骰子贴图配置（使用ID）
var scene_configs = {
	"normal": {
		0: 1,  # 1点
		1: 2,  # 2点
		2: 3,  # 3点
		3: 4,  # 4点
		4: 4,  # 5点
		5: 4   # 6点
	},
	"skill": {
		0: 7,  # 临时使用默认贴图，后续替换为技能贴图
		1: 8,
		2: 9,
		3: 7,
		4: 8,
		5: 9
	}
}

func _init():
	# 初始化骰子面管理器
	dice_face_manager = preload("res://scripts/dice_face_manager.gd").new()

# 获取场景配置（返回ID）
func get_scene_config(scene_name: String) -> Dictionary:
	var config = scene_configs.get(scene_name, scene_configs.normal)
	# 直接返回ID配置，不转换为贴图路径
	return config

# 添加或更新场景配置
func add_scene_config(scene_name: String, config: Dictionary):
	scene_configs[scene_name] = config

# 获取所有场景名称
func get_all_scene_names() -> Array:
	return scene_configs.keys()

# 重新加载骰子面数据
func reload_face_data():
	dice_face_manager.reload()