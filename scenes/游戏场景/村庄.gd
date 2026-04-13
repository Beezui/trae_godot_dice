extends "res://scenes/游戏场景/关卡模板.gd"

## 村庄场景脚本
## 继承自关卡模板，仅配置差异化参数


func _ready():
	# 配置村庄的视觉参数
	ground_color = Color(0.7, 0.65, 0.5, 1)  # 土黄色地面
	wall_north_color = Color(0.6, 0.4, 0.3, 1)  # 木质棕北墙
	wall_south_color = Color(0.6, 0.4, 0.3, 1)  # 木质棕南墙
	wall_east_color = Color(0.6, 0.4, 0.3, 1)  # 木质棕东墙
	wall_west_color = Color(0.6, 0.4, 0.3, 1)  # 木质棕西墙
	light_color = Color(1.0, 1.0, 0.95, 1)  # 自然白光
	
	# 调用父类初始化
	super._ready()
	
	print("【村庄】场景配置完成")


## 输入处理（可扩展）
func _input(event):
	# 可在此添加村庄特有的输入处理
	super._input(event)


## 重置场景
func reset_scene():
	super.reset_scene()
	print("【村庄】场景已重置")
