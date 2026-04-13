extends "res://scenes/游戏场景/关卡模板.gd"

## 神秘商店场景脚本
## 继承自关卡模板，仅配置差异化参数


func _ready():
	# 配置神秘商店的视觉参数
	ground_color = Color(0.6, 0.6, 0.65, 1)  # 灰色石板地面
	wall_north_color = Color(0.6, 0.3, 0.7, 1)  # 紫色北墙
	wall_south_color = Color(0.6, 0.3, 0.7, 1)  # 紫色南墙
	wall_east_color = Color(0.6, 0.3, 0.7, 1)  # 紫色东墙
	wall_west_color = Color(0.6, 0.3, 0.7, 1)  # 紫色西墙
	light_color = Color(1.0, 0.95, 0.8, 1)  # 暖黄光
	
	# 调用父类初始化
	super._ready()
	
	print("【神秘商店】场景配置完成")


## 输入处理（可扩展）
func _input(event):
	# 可在此添加神秘商店特有的输入处理
	super._input(event)


## 重置场景
func reset_scene():
	super.reset_scene()
	print("【神秘商店】场景已重置")
