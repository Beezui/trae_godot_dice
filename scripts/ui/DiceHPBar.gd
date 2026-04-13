class_name DiceHPBar
extends Control

## HP 条组件，用于在骰子上显示血量
## 使用方法：将此脚本作为 SubViewport 的子节点添加

@export var max_hp: int = 100
@export var current_hp: int = 100
@export var bar_width: int = 200
@export var bar_height: int = 20

var hp_bar_bg: ColorRect
var hp_bar_fg: ColorRect
var hp_label: Label


func _ready():
	_setup_hp_bar()
	update_hp_display()


func _setup_hp_bar():
	# 设置根节点大小
	custom_minimum_size = Vector2(bar_width, bar_height + 30)
	size = Vector2(bar_width, bar_height + 30)
	
	# 创建背景
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	hp_bar_bg.position = Vector2(0, 0)
	hp_bar_bg.size = Vector2(bar_width, bar_height)
	add_child(hp_bar_bg)
	
	# 创建前景 (当前 HP)
	hp_bar_fg = ColorRect.new()
	hp_bar_fg.color = Color(0.2, 0.8, 0.2, 1.0)  # 绿色
	hp_bar_fg.position = Vector2(0, 0)
	hp_bar_fg.size = Vector2(bar_width, bar_height)
	add_child(hp_bar_fg)
	
	# 创建 HP 标签
	hp_label = Label.new()
	hp_label.position = Vector2(0, bar_height + 5)
	hp_label.size = Vector2(bar_width, 25)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_font_size_override("font_size", 18)
	add_child(hp_label)


func set_hp(current: int, max_val: int):
	current_hp = current
	max_hp = max_val
	update_hp_display()


func update_hp_display():
	if not hp_bar_fg or not hp_label:
		return
	
	# 更新前景宽度
	var percentage = float(current_hp) / float(max_hp) if max_hp > 0 else 0
	hp_bar_fg.size.x = int(bar_width * percentage)
	
	# 更新 HP 标签文本
	hp_label.text = "%d/%d" % [current_hp, max_hp]
	
	# 根据血量百分比改变颜色
	if percentage > 0.6:
		hp_bar_fg.color = Color(0.2, 0.8, 0.2, 1.0)  # 绿色
	elif percentage > 0.3:
		hp_bar_fg.color = Color(0.8, 0.8, 0.2, 1.0)  # 黄色
	else:
		hp_bar_fg.color = Color(0.8, 0.2, 0.2, 1.0)  # 红色
