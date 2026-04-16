extends Control
## 战斗技能栏 UI（临时实现）
## 显示在屏幕下方，用于选择技能骰子和物品

## 信号：技能被选择
signal on_skill_selected(skill_dice, character)
## 信号：物品被选择（预留）
signal on_item_selected(item_dice, character)
## 信号：结束回合按钮被点击
signal on_end_turn_pressed()

## 技能按钮场景
@export var skill_button_scene: PackedScene
## 物品按钮场景（预留）
@export var item_button_scene: PackedScene

## 当前玩家角色列表
var player_characters: Array[BaseCharacter] = []
## 技能骰子列表
var skill_dices: Array = []
## 物品骰子列表（预留）
var item_dices: Array = []

## UI 节点引用
@onready var skill_container: HBoxContainer = $SkillContainer
@onready var item_container: HBoxContainer = $ItemContainer
@onready var end_turn_button: Button = $EndTurnButton
@onready var turn_label: Label = $TurnLabel
@onready var mp_label: Label = $MPLabel


func _ready():
	print("【BattleSkillBar】技能栏已就绪")
	_connect_signals()


func _connect_signals():
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)


## 初始化技能栏
## @param characters 玩家角色列表
## @param skills 技能骰子列表
## @param items 物品骰子列表（预留）
func initialize(characters: Array[BaseCharacter], skills: Array = [], items: Array = []):
	player_characters = characters
	skill_dices = skills
	item_dices = items

	print("【BattleSkillBar】初始化...")
	print("  - 玩家角色：", characters.size())
	print("  - 技能骰子：", skills.size())
	print("  - 物品骰子：", items.size())

	_setup_ui()


func _setup_ui():
	# 清空现有按钮
	_clear_buttons()

	# 创建技能按钮
	for skill_dice in skill_dices:
		_create_skill_button(skill_dice)

	# 创建物品按钮（预留）
	# for item_dice in item_dices:
	#     _create_item_button(item_dice)

	_update_turn_label()
	_update_mp_label()


func _clear_buttons():
	if skill_container:
		for child in skill_container.get_children():
			child.queue_free()

	if item_container:
		for child in item_container.get_children():
			child.queue_free()


func _create_skill_button(skill_dice):
	if not skill_button_scene:
		# 使用默认按钮
		var button = Button.new()
		button.text = "技能"
		button.name = "SkillButton"
		button.custom_minimum_size = Vector2(100, 60)

		button.pressed.connect(_on_skill_button_pressed.bind(skill_dice))

		skill_container.add_child(button)
	else:
		var button = skill_button_scene.instantiate()
		button.skill_dice = skill_dice
		skill_container.add_child(button)


func _create_item_button(item_dice):
	if not item_button_scene:
		var button = Button.new()
		button.text = "物品"
		button.name = "ItemButton"
		button.custom_minimum_size = Vector2(100, 60)

		button.pressed.connect(_on_item_button_pressed.bind(item_dice))

		item_container.add_child(button)
	else:
		var button = item_button_scene.instantiate()
		button.item_dice = item_dice
		item_container.add_child(button)


func _on_skill_button_pressed(skill_dice):
	print("【BattleSkillBar】技能按钮被点击")
	# 查找对应的角色
	var character = _get_character_for_skill_dice(skill_dice)
	if character:
		# 自动选择第一个敌方目标
		var target = _get_first_enemy_target()
		if target:
			# 调用 BattleManager 使用技能
			if BattleManager.get_instance():
				var success = BattleManager.player_use_skill(character, skill_dice, target)
				if success:
					print("【BattleSkillBar】技能使用成功")
					# 更新 MP 显示
					update_mp_display(character)
				else:
					print("【BattleSkillBar】技能使用失败")
		else:
			print("【BattleSkillBar】没有可用的目标")


## 获取第一个敌方目标
func _get_first_enemy_target() -> BaseCharacter:
	"""获取第一个存活的敌方角色"""
	if BattleManager.get_instance():
		for character in BattleManager.enemy_characters:
			if character.is_alive():
				return character
	return null


func _on_item_button_pressed(item_dice):
	print("【BattleSkillBar】物品按钮被点击")
	# 预留
	on_item_selected.emit(item_dice, null)


func _on_end_turn_button_pressed():
	print("【BattleSkillBar】结束回合按钮被点击")
	on_end_turn_pressed.emit()


## 获取技能骰子对应的角色
func _get_character_for_skill_dice(skill_dice) -> BaseCharacter:
	# TODO: 根据技能骰子查找对应的角色
	# 暂时返回第一个存活的角色
	for character in player_characters:
		if character.is_alive():
			return character
	return null


## 更新回合显示
func update_turn_display(turn: int):
	_update_turn_label()


func _update_turn_label():
	if turn_label:
		turn_label.text = "回合：%d" % BattleManager.current_turn


## 更新 MP 显示
func update_mp_display(character: BaseCharacter):
	_update_mp_label()


func _update_mp_label():
	if mp_label:
		if player_characters.size() > 0:
			var character = player_characters[0]
			mp_label.text = "%s: %d/%d" % [character.mp_name, character.current_mp, character.attr_mp]
		else:
			mp_label.text = "MP: --"


## 启用/禁用技能栏
func set_skill_bar_enabled(enabled: bool):
	for child in skill_container.get_children():
		if child is Button:
			child.disabled = not enabled

	for child in item_container.get_children():
		if child is Button:
			child.disabled = not enabled

	if end_turn_button:
		end_turn_button.disabled = not enabled


## 显示回合开始提示
func show_turn_start(turn_owner: String):
	var color = Color.GREEN if turn_owner == "player" else Color.RED
	var text = "玩家回合" if turn_owner == "player" else "敌方回合"

	# 可以添加动画或高亮效果
	print("【BattleSkillBar】回合开始：", text)


## 显示回合结束提示
func show_turn_end(turn_owner: String):
	print("【BattleSkillBar】回合结束：", turn_owner)


## 添加技能使用记录
func add_skill_log(character_name: String, skill_name: String, target_name: String):
	# TODO: 实现战斗日志
	print("【BattleSkillBar】", character_name, " 使用 ", skill_name, " 对 ", target_name)


## 显示战斗统计
func show_battle_stats(stats: Dictionary):
	print("【BattleSkillBar】战斗统计:")
	print("  - 回合数：", stats.get("turns", 0))
	print("  - 造成伤害：", stats.get("damage_dealt", 0))
	print("  - 受到伤害：", stats.get("damage_received", 0))
	print("  - 使用技能：", stats.get("skills_used", 0))
