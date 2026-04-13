extends "res://scenes/游戏场景/关卡模板.gd"

## 熔火之窟场景脚本
## 继承自关卡模板，仅配置差异化参数


func _ready():
	# 配置熔火之窟的视觉参数
	ground_color = Color(0.4, 0.2, 0.2, 1)  # 暗红熔岩地面
	wall_north_color = Color(0.8, 0.3, 0.2, 1)  # 熔岩红北墙
	wall_south_color = Color(0.8, 0.3, 0.2, 1)  # 熔岩红南墙
	wall_east_color = Color(0.8, 0.3, 0.2, 1)  # 熔岩红东墙
	wall_west_color = Color(0.8, 0.3, 0.2, 1)  # 熔岩红西墙
	light_color = Color(1.0, 0.6, 0.4, 1)  # 橙红光
	
	# 调用父类初始化
	super._ready()
	
	print("【熔火之窟】场景配置完成")


## 输入处理（可扩展）
func _input(event):
	# 可在此添加熔火之窟特有的输入处理
	super._input(event)


## 重置场景
func reset_scene():
	super.reset_scene()
	print("【熔火之窟】场景已重置")
