class_name BattleTestScene
extends BattleSceneBase
## 测试战斗场景
## 用于验证战斗框架功能

## 测试用英雄 ID
@export var test_hero_id: int = 1
## 测试用敌人 ID
@export var test_enemy_id: int = 2

## 技能装配 UI
var skill_equip_ui: Control = null


func _ready():
	print("【BattleTestScene】测试战斗场景已就绪")
	print("【BattleTestScene】self=", self, ", has_node('BattleUI')=", has_node("BattleUI"))

	super._ready()

	# 加载技能装配 UI
	_setup_skill_equip_ui()

	# 创建测试用 LevelNode
	var test_level_node = _create_test_level_node()
	print("【BattleTestScene】测试关卡节点已创建：", test_level_node.name)

	# 初始化战斗
	print("【BattleTestScene】准备初始化战斗...")
	initialize_battle(test_level_node, [test_hero_id])

	# 连接信号
	on_battle_completed.connect(_on_battle_completed)

	# 开始战斗流程
	await get_tree().create_timer(1.0).timeout
	print("【BattleTestScene】准备开始战斗流程...")
	start_battle_flow()


func _create_test_level_node() -> LevelNode:
	"""创建测试用关卡节点"""
	var level_node = LevelNode.new("test_001", "测试战斗", 1)

	# 配置敌人数据
	level_node.data = {
		"scene_id": "1",
		"scene_path": "res://scenes/battle/battle_scene_base.tscn",
		"enemies": [str(test_enemy_id)],  # 敌人 ID 列表
		"npcs": [],
		"rewards": []
	}

	return level_node


func _on_battle_completed(victory: bool):
	"""战斗完成回调"""
	if victory:
		print("【BattleTestScene】测试胜利！")
	else:
		print("【BattleTestScene】测试失败...")

	# 清理战斗
	await get_tree().create_timer(3.0).timeout
	cleanup_battle()

	# 重新加载场景
	get_tree().reload_current_scene()


func spawn_enemies():
	"""生成敌人（重写基类方法）"""
	print("【BattleTestScene】生成敌人...")
	# 敌人由 BattleManager 在初始化时加载


func spawn_player_dices():
	"""生成玩家骰子（重写基类方法）"""
	print("【BattleTestScene】生成玩家骰子...")
	# 骰子由 BattleManager 在准备阶段生成


## 设置技能装配 UI
func _setup_skill_equip_ui():
	var ui_scene = load("res://scenes/ui/skill_equip_ui.tscn")
	if not ui_scene:
		push_error("【BattleTestScene】无法加载 skill_equip_ui.tscn")
		return

	skill_equip_ui = ui_scene.instantiate()
	if not skill_equip_ui:
		push_error("【BattleTestScene】无法实例化 skill_equip_ui")
		return

	# 默认隐藏
	skill_equip_ui.visible = false

	# 添加到 BattleUI 下
	if has_node("BattleUI"):
		$BattleUI.add_child(skill_equip_ui)
		# 铺满 BattleUI 区域
		skill_equip_ui.anchors_preset = Control.PRESET_FULL_RECT
		skill_equip_ui.anchor_right = 1.0
		skill_equip_ui.anchor_bottom = 1.0
		print("【BattleTestScene】技能装配 UI 已加载到 BattleUI")

	# 连接关闭信号
	if skill_equip_ui.has_signal("on_ui_closed"):
		skill_equip_ui.on_ui_closed.connect(_on_skill_equip_closed)


## 切换技能装配 UI 显示/隐藏
func _toggle_skill_equip_ui():
	if not skill_equip_ui:
		return
	if skill_equip_ui.visible:
		skill_equip_ui.close()
	else:
		skill_equip_ui.open()


func _on_skill_equip_closed():
	print("【BattleTestScene】技能装配 UI 已关闭")


## 处理输入（快捷键触发技能装配 UI）
func _input(event):
	# 按 F 键打开/关闭技能装配 UI
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F:
			_toggle_skill_equip_ui()
			get_viewport().set_input_as_handled()
			return

	# 将输入传递给基类（技能栏等）
	super._input(event)
