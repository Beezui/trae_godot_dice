extends Node
## 战斗 UI 管理器 (Autoload 单例)
## 负责创建和管理持久化的战斗 UI，独立于美术场景
## UI 不随场景切换而销毁，由 BattleManager 按需显示/隐藏

## 技能栏脚本
var _skill_bar_script = null

## UI 根节点
var _ui_root: Control = null
## 技能栏节点（挂载 BattleSkillBar 脚本）
var _skill_bar = null

## UI 是否已创建
var _ui_created: bool = false


func _ready():
	print("【BattleUIManager】战斗 UI 管理器已就绪")


## 获取单例
static func get_instance() -> Node:
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		var node = tree.root.get_node_or_null("BattleUIManager")
		if node:
			return node
	return null


## 显示技能栏
## @param characters 玩家角色列表
## @param skill_dices 技能骰子列表
## @param items 物品骰子列表（预留）
func show_skill_bar(characters: Array, skill_dices: Array, items: Array = []) -> bool:
	# 如果 UI 不存在则创建
	if not _ui_created:
		if not _create_ui():
			return false

	# 显示 UI
	if _ui_root:
		_ui_root.visible = true
		print("【BattleUIManager】UI 根节点可见: ", _ui_root.visible, ", 尺寸: ", _ui_root.size)

	# 初始化技能栏
	if _skill_bar and _skill_bar.has_method("initialize"):
		_skill_bar.initialize(characters, skill_dices, items)
		print("【BattleUIManager】技能栏可见: ", _skill_bar.visible, ", 尺寸: ", _skill_bar.size, ", 位置: ", _skill_bar.position)
		print("【BattleUIManager】技能栏已初始化并显示")
		return true

	print("【BattleUIManager】技能栏初始化失败")
	return false


## 隐藏技能栏
func hide_skill_bar():
	if _ui_root and _ui_root.visible:
		_ui_root.visible = false
		print("【BattleUIManager】技能栏已隐藏")


## 获取技能栏引用（供 BattleManager 等外部调用者使用）
func get_skill_bar():
	return _skill_bar


## 创建 UI 结构
func _create_ui() -> bool:
	if _ui_created:
		return true

	print("【BattleUIManager】创建战斗 UI...")

	# 加载 BattleSkillBar 脚本
	_skill_bar_script = load("res://scripts/ui/battle_skill_bar.gd")
	if not _skill_bar_script:
		push_error("【BattleUIManager】无法加载 battle_skill_bar.gd")
		return false

	# 创建 UI 根容器（不拦截鼠标事件，让事件透传到 3D 场景）
	_ui_root = Control.new()
	_ui_root.name = "BattleUIRoot"
	_ui_root.anchors_preset = Control.PRESET_FULL_RECT
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 创建 SkillBar 容器（Control 作为根，子节点通过 anchors 控制布局）
	var skill_bar = Control.new()
	skill_bar.name = "SkillBar"
	skill_bar.anchors_preset = Control.PRESET_BOTTOM_WIDE
	skill_bar.offset_top = -80
	skill_bar.offset_bottom = -2
	skill_bar.offset_left = 20
	skill_bar.offset_right = -20

	# 创建半透明背景（填满 skill_bar 作为底层）
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.1, 0.1, 0.15, 0.85)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_bar.add_child(bg)

	# 创建 SkillContainer（技能按钮容器）
	var skill_container = VBoxContainer.new()
	skill_container.name = "SkillContainer"
	skill_container.anchors_preset = Control.PRESET_LEFT_WIDE
	skill_container.offset_left = 10
	skill_container.offset_right = 0.5
	skill_container.offset_top = 5
	skill_container.offset_bottom = -5
	skill_bar.add_child(skill_container)

	# 创建 ItemContainer
	var item_container = HBoxContainer.new()
	item_container.name = "ItemContainer"
	item_container.anchors_preset = Control.PRESET_RIGHT_WIDE
	item_container.offset_left = 0.5
	item_container.offset_right = -10
	item_container.offset_top = 5
	item_container.offset_bottom = -5
	skill_bar.add_child(item_container)

	# 创建 EndTurnButton
	var end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = "结束回合"
	end_turn_button.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	end_turn_button.offset_left = 0.5
	end_turn_button.offset_top = -40
	end_turn_button.offset_right = -10
	end_turn_button.offset_bottom = -5
	skill_bar.add_child(end_turn_button)

	# 创建 TurnLabel
	var turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.anchors_preset = Control.PRESET_TOP_LEFT
	turn_label.offset_top = 5
	turn_label.offset_left = 10
	turn_label.offset_right = 0.5
	skill_bar.add_child(turn_label)

	# 创建 MPLabel
	var mp_label = Label.new()
	mp_label.name = "MPLabel"
	mp_label.anchors_preset = Control.PRESET_TOP_RIGHT
	mp_label.offset_top = 5
	mp_label.offset_left = 0.5
	mp_label.offset_right = -10
	skill_bar.add_child(mp_label)

	# 创建 ThrowHintLabel（居中）
	var throw_hint_label = Label.new()
	throw_hint_label.name = "ThrowHintLabel"
	throw_hint_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
	throw_hint_label.offset_top = -25
	throw_hint_label.offset_bottom = -5
	throw_hint_label.visible = false
	skill_bar.add_child(throw_hint_label)

	# 现在赋脚本（@onready 变量会正确找到子节点）
	skill_bar.set_script(_skill_bar_script)

	# 保存引用
	_skill_bar = skill_bar

	# 组装
	_ui_root.add_child(skill_bar)

	# 添加到场景树根
	var root = Engine.get_main_loop().root
	root.add_child(_ui_root)

	_ui_created = true
	print("【BattleUIManager】战斗 UI 已创建")
	return true


## 销毁 UI
func _destroy_ui():
	if _ui_root and is_instance_valid(_ui_root):
		_ui_root.queue_free()
	_ui_root = null
	_skill_bar = null
	_ui_created = false
	print("【BattleUIManager】战斗 UI 已销毁")


## 释放资源
func _exit_tree():
	_destroy_ui()
