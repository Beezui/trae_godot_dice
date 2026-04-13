extends Node2D
## 关卡地图测试场景脚本

@onready var level_map_display = $LevelMapDisplay


func _ready():
	print("====================")
	print("[LevelMapTest] 测试场景启动")
	
	# 等待 LevelGenerator 初始化
	await get_tree().create_timer(0.5).timeout
	
	# 验证 LevelGenerator 是否可用
	var level_gen = LevelGenerator.get_instance()
	if level_gen:
		print("[LevelMapTest] LevelGenerator 已初始化")
		print("  - 当前关卡数据：", "有" if level_gen.current_level_data else "无")
	else:
		print("[LevelMapTest] LevelGenerator 未找到")
	
	print("====================")
	print("[LevelMapTest] LevelMapDisplay 会在 _ready 后自动生成关卡")


func _input(event):
	# 按 R 键重新生成
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		print("[LevelMapTest] 重新生成关卡...")
		if level_map_display:
			level_map_display.generate_and_display()
