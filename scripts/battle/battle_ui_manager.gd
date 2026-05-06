extends Node
## 战斗 UI 管理器 (Autoload 单例)
## 负责创建和管理持久化的战斗 UI，独立于美术场景
## UI 不随场景切换而销毁，由 BattleManager 按需显示/隐藏

## 技能栏场景
const SkillBarScene = preload("res://scenes/ui/battle_skill_bar.tscn")

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
		print("【BattleUIManager】UI 根节点可见：", _ui_root.visible, ", 尺寸：", _ui_root.size)

	# 初始化技能栏
	if _skill_bar and _skill_bar.has_method("initialize"):
		_skill_bar.initialize(characters, skill_dices, items)
		print("【BattleUIManager】技能栏可见：", _skill_bar.visible, ", 尺寸：", _skill_bar.size, ", 位置：", _skill_bar.position)
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

	# 从场景加载技能栏
	var skill_bar = SkillBarScene.instantiate()
	if not skill_bar:
		push_error("【BattleUIManager】无法实例化 battle_skill_bar.tscn")
		return false

	# 创建 UI 根容器（不拦截鼠标事件，让事件透传到 3D 场景）
	_ui_root = Control.new()
	_ui_root.name = "BattleUIRoot"
	_ui_root.anchors_preset = Control.PRESET_FULL_RECT
	_ui_root.anchor_right = 1.0
	_ui_root.anchor_bottom = 1.0
	_ui_root.grow_horizontal = 2
	_ui_root.grow_vertical = 2
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
