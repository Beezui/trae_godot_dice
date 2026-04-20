extends Control
## 战斗技能栏 UI
## 显示在屏幕下方，用于选择技能骰子和物品

## 信号：技能被选择
signal on_skill_selected(skill_dice, character)
## 信号：物品被选择（预留）
signal on_item_selected(item_dice, character)
## 信号：结束回合按钮被点击
signal on_end_turn_pressed()
## 信号：投掷开始
signal on_throw_started()
## 信号：投掷结束
signal on_throw_ended()

## 技能按钮场景
@export var skill_button_scene: PackedScene
## 物品按钮场景（预留）
@export var item_button_scene: PackedScene

## 当前玩家角色列表
var player_characters: Array[BaseCharacter] = []
## 技能骰子列表（隐藏存储，不显示在场景中）
var skill_dices: Array = []
## 物品骰子列表（预留）
var item_dices: Array = []
## 属性骰子列表（str, agi, int）
var attribute_dices: Array = []

## UI 节点引用
@onready var skill_container: VBoxContainer = $SkillContainer
@onready var item_container: HBoxContainer = $ItemContainer
@onready var end_turn_button: Button = $EndTurnButton
@onready var turn_label: Label = $TurnLabel
@onready var mp_label: Label = $MPLabel
@onready var throw_hint_label: Label = $ThrowHintLabel

## 当前选择的技能骰子
var selected_skill_dice = null
## 当前选择的角色
var selected_character: BaseCharacter = null
## 是否正在投掷
var is_throw_preparing: bool = false
## 是否正在蓄力
var is_charging: bool = false
## 是否正在释放技能（禁止再次投掷）
var is_releasing_skill: bool = false


func _ready():
	print("【BattleSkillBar】技能栏已就绪")
	_connect_signals()
	# 初始化投掷提示
	if throw_hint_label:
		throw_hint_label.text = "按空格键投掷"
		throw_hint_label.visible = false


func _process(delta):
	# 蓄力期间的提示更新（震动效果由 DiceThrowController._process 自动处理）
	if is_charging and DiceThrowController:
		var charge_percent = int(DiceThrowController.charge_ratio * 100)
		_show_throw_hint("蓄力中... %d%%" % charge_percent)


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

	# 获取属性骰子引用（从场景中查找）
	_find_attribute_dices()


func _setup_ui():
	# 清空现有按钮
	_clear_buttons()

	# 创建技能按钮（列表形式，垂直排列）
	for skill_dice in skill_dices:
		_create_skill_button(skill_dice)

	_update_turn_label()
	_update_mp_label()


## 属性骰子初始位置（用于复位）
var attribute_dice_initial_positions: Dictionary = {}

## 查找场景中的属性骰子
func _find_attribute_dices():
	var battle_scene = _get_battle_scene()
	if battle_scene and battle_scene.has_node("Sandbox"):
		var sandbox = battle_scene.get_node("Sandbox")
		# 查找属性骰子（根据命名或类型）
		for child in sandbox.get_children():
			if child.has_method("get_attribute_value") or child.name.contains("Attr"):
				attribute_dices.append(child)
				# 记录初始位置
				attribute_dice_initial_positions[child] = child.position
				print("【BattleSkillBar】找到属性骰子：", child.name, ", 初始位置：", child.position)


## 获取战斗场景引用
func _get_battle_scene() -> Node:
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		for i in range(tree.root.get_child_count()):
			var child = tree.root.get_child(i)
			if child.is_in_group("battle"):
				return child
	return null


func _clear_buttons():
	if skill_container:
		for child in skill_container.get_children():
			child.queue_free()

	if item_container:
		for child in item_container.get_children():
			child.queue_free()


## 创建技能按钮（显示技能图标）
func _create_skill_button(skill_dice):
	if not skill_dice:
		print("【BattleSkillBar】技能骰子为空，跳过创建")
		return

	print("【BattleSkillBar】创建技能按钮，skill_dice=", skill_dice)

	# 创建 TextureButton 显示技能图标
	var button = TextureButton.new()
	button.name = "SkillButton"
	button.custom_minimum_size = Vector2(80, 80)
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	# 获取技能图标
	var skill_icon = _get_skill_icon(skill_dice)
	if skill_icon:
		button.texture_normal = skill_icon
		print("【BattleSkillBar】成功加载技能图标")
	else:
		# 默认图标
		button.texture_normal = _create_placeholder_texture()
		print("【BattleSkillBar】使用占位贴图")

	# 绑定点击事件
	button.pressed.connect(_on_skill_button_pressed.bind(skill_dice))

	# 存储技能骰子引用到按钮元数据
	button.set_meta("skill_dice", skill_dice)

	skill_container.add_child(button)
	print("【BattleSkillBar】创建技能按钮完成，容器子节点数=", skill_container.get_child_count())


## 获取技能图标（从技能骰子的第一个技能 ID）
func _get_skill_icon(skill_dice) -> Texture2D:
	# 尝试从技能骰子元数据获取技能骰子 ID
	var skill_id = ""

	# 首先尝试从骰子元数据获取 skill_dice_id
	var dice_id = skill_dice.get_meta("skill_dice_id") if skill_dice.has_meta("skill_dice_id") else ""

	if dice_id.is_empty():
		print("【BattleSkillBar】技能骰子没有存储 skill_dice_id 元数据")
		return _create_placeholder_texture()

	# 从 DiceCSVReader 读取配置
	var reader = DiceCSVReader.new()
	var dice_config = reader.get_skill_dice_config(dice_id)

	print("【BattleSkillBar】获取技能图标，dice_id=", dice_id, ", dice_config=", dice_config)

	if not dice_config.is_empty():
		var skill_ids = dice_config.get("skill_ids", [])
		print("【BattleSkillBar】技能 IDs=", skill_ids)
		if skill_ids.size() > 0:
			skill_id = skill_ids[0]

	if skill_id.is_empty():
		print("【BattleSkillBar】技能 ID 为空，dice_id=", dice_id)
		return _create_placeholder_texture()

	# 加载技能贴图
	var texture_path = "res://textures/skill/skill_" + skill_id + ".png"
	if ResourceLoader.exists(texture_path):
		print("【BattleSkillBar】加载技能贴图：", texture_path)
		return load(texture_path)
	else:
		print("【BattleSkillBar】技能贴图不存在：", texture_path)
	return _create_placeholder_texture()


## 创建占位贴图
func _create_placeholder_texture() -> Texture2D:
	var placeholder = PlaceholderTexture2D.new()
	placeholder.size = Vector2(64, 64)
	return placeholder


func _on_skill_button_pressed(skill_dice):
	print("【BattleSkillBar】技能按钮被点击")

	# 检查是否正在释放技能期间
	if is_releasing_skill:
		print("【BattleSkillBar】技能释放中，忽略点击")
		_show_throw_hint("技能释放中...")
		return

	# 检查是否已经选择了骰子
	if selected_skill_dice:
		print("【BattleSkillBar】已有骰子被选择，忽略")
		return

	# 检查 MP 是否足够（1 点）
	var character = _get_character_for_skill_dice(skill_dice)
	if character and not _can_afford_throw(character):
		print("【BattleSkillBar】MP 不足，无法投掷")
		_show_throw_hint("MP 不足！")
		return

	# 选择技能骰子
	selected_skill_dice = skill_dice
	selected_character = character

	# 将技能骰子添加到场景（悬浮待投掷状态）
	_move_skill_dice_to_scene(skill_dice)

	# 显示投掷提示
	_show_throw_hint("按空格键投掷")

	# 禁用技能栏
	set_skill_bar_enabled(false)

	print("【BattleSkillBar】技能骰子已选择，准备投掷")


## 检查是否有足够 MP 投掷（1 点）
func _can_afford_throw(character: BaseCharacter) -> bool:
	if not character:
		return false
	# 临时设定：每次投掷消耗 1 点 MP
	return character.current_mp >= 1


## 将技能骰子移动到场景（悬浮待投掷状态）
func _move_skill_dice_to_scene(skill_dice):
	var battle_scene = _get_battle_scene()
	if not battle_scene or not battle_scene.has_node("Sandbox"):
		print("【BattleSkillBar】场景或 Sandbox 不存在")
		return

	var sandbox = battle_scene.get_node("Sandbox")

	# 设置骰子为可见
	skill_dice.visible = true

	# 设置位置（与属性骰子一起）
	skill_dice.position = Vector3(-4.0, 4.0, 6.0)

	# 设置为悬浮状态
	if skill_dice.has_method("set_freeze"):
		skill_dice.set_freeze(true)
	elif "freeze" in skill_dice:
		skill_dice.freeze = true
	skill_dice.gravity_scale = 0.0
	skill_dice.linear_velocity = Vector3.ZERO
	skill_dice.angular_velocity = Vector3.ZERO

	# 添加到场景
	sandbox.add_child(skill_dice)
	print("【BattleSkillBar】技能骰子已移动到场景")


## 显示投掷提示
func _show_throw_hint(text: String):
	if throw_hint_label:
		throw_hint_label.text = text
		throw_hint_label.visible = true


## 获取第一个敌方目标
func _get_first_enemy_target() -> BaseCharacter:
	"""获取第一个存活的敌方角色"""
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


## 输入处理（空格键投掷）
func _input(event):
	if event is InputEventKey:
		# 空格键按下：开始蓄力
		if event.keycode == KEY_SPACE and event.pressed:
			if selected_skill_dice and not is_charging and not is_releasing_skill:
				_start_throw()

		# 空格键松开：投掷
		if event.keycode == KEY_SPACE and not event.pressed:
			if is_charging and not is_releasing_skill:
				_execute_throw()


## 开始投掷（蓄力）
func _start_throw():
	print("【BattleSkillBar】开始投掷...")
	is_charging = true
	is_throw_preparing = true

	# 获取所有要投掷的骰子
	var all_throw_dices = _get_all_throw_dices()

	# 开始蓄力（传入骰子数组，DiceThrowController 会自动处理震动）
	if DiceThrowController:
		DiceThrowController.start_charge(all_throw_dices)

	_show_throw_hint("蓄力中... 0%")


## 执行投掷（松开空格键）
func _execute_throw():
	is_charging = false
	# 设置技能释放中状态，禁止再次投掷
	is_releasing_skill = true

	# 获取所有要投掷的骰子（技能骰子 + 属性骰子）
	var all_throw_dices = _get_all_throw_dices()

	# 解除 freeze 状态
	for dice in all_throw_dices:
		if dice and is_instance_valid(dice):
			if dice.has_method("set_freeze"):
				dice.set_freeze(false)
			elif "freeze" in dice:
				dice.freeze = false
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
			dice.sleeping = false

	# 使用 DiceThrowController 投掷（会自动使用记录的骰子和当前 charge_ratio）
	if DiceThrowController:
		DiceThrowController.end_charge()

	# 扣除 MP（1 点）
	if selected_character:
		selected_character.take_mp_cost(1)
		update_mp_display(selected_character)

	_show_throw_hint("投掷中...")

	# 等待骰子停止
	await _wait_for_dices_stopped(all_throw_dices)

	# 结算结果
	await _resolve_throw_result()

	# 复位骰子
	await _reset_throw_dices()


## 获取所有要投掷的骰子（技能骰子 + 属性骰子）
func _get_all_throw_dices() -> Array:
	var all_dices = []
	if selected_skill_dice and is_instance_valid(selected_skill_dice):
		all_dices.append(selected_skill_dice)

	# 添加属性骰子
	for dice in attribute_dices:
		if dice and is_instance_valid(dice):
			all_dices.append(dice)

	return all_dices


## 等待骰子停止
func _wait_for_dices_stopped(dices: Array):
	print("【BattleSkillBar】等待骰子停止...")

	# 使用 DiceResultDetector 等待骰子稳定
	if DiceResultDetector:
		var is_stable = await DiceResultDetector.wait_for_dice_stable(dices, 5.0)
		if is_stable:
			print("【BattleSkillBar】骰子已稳定")
		else:
			print("【BattleSkillBar】等待骰子稳定超时")
	else:
		# 备用方案：等待 2 秒
		await get_tree().create_timer(2.0).timeout
		print("【BattleSkillBar】骰子已停止（备用方案）")


## 结算投掷结果
func _resolve_throw_result():
	print("【BattleSkillBar】结算投掷结果...")

	# 无需额外等待 result_control_timer，因为 roll() 方法已经处理了结果检测

	# 获取技能骰子结果
	var skill_result = 1
	if selected_skill_dice and selected_skill_dice.has_method("get_dice_value"):
		skill_result = selected_skill_dice.get_dice_value()

	# 获取属性骰子结果
	var attr_results = {}
	for dice in attribute_dices:
		if dice and dice.has_method("get_attribute_value"):
			attr_results[dice.attr_type] = dice.get_attribute_value()

	print("  - 技能骰子结果：", skill_result)
	print("  - 属性骰子结果：", attr_results)

	# 释放技能
	await _release_skill(skill_result, attr_results)



## 释放技能
func _release_skill(skill_index: int, attr_results: Dictionary):
	if not selected_skill_dice or not selected_character:
		return

	# 获取技能 ID（从技能骰子配置）
	var skill_id = _get_skill_id_from_dice(selected_skill_dice, skill_index)
	if skill_id.is_empty():
		print("【BattleSkillBar】无法获取技能 ID")
		return

	# 准备技能参数
	var dice_results = {
		"str": attr_results.get("str", 0),
		"agi": attr_results.get("agi", 0),
		"int": attr_results.get("int", 0)
	}

	# 获取施法者位置
	var caster_position = Vector3.ZERO
	if selected_character.character_dice:
		caster_position = selected_character.character_dice.position

	# 获取目标（第一个敌方角色）
	var targets = []
	for enemy in BattleManager.enemy_characters:
		if enemy.is_alive():
			targets.append(enemy)
			break

	if targets.size() == 0:
		print("【BattleSkillBar】没有可用目标")
		return

	# 创建临时 Marker3D 作为施法者节点
	var caster_marker = Marker3D.new()
	caster_marker.position = caster_position
	get_tree().current_scene.add_child(caster_marker)

	var params = {
		"dice_results": dice_results,
		"scene": get_tree().current_scene,
		"caster_position": caster_position
	}

	print("【BattleSkillBar】释放技能：", skill_id)
	SkillManager.use_skill(skill_id, caster_marker, targets, params)

	# 清理临时节点
	await get_tree().create_timer(3.0).timeout
	caster_marker.queue_free()


## 从技能骰子获取技能 ID
func _get_skill_id_from_dice(skill_dice, skill_index: int) -> String:
	# 从 DiceCSVReader 读取配置
	var reader = DiceCSVReader.new()
	var dice_config = reader.get_skill_dice_config("4001")  # 临时硬编码
	if dice_config.is_empty():
		return ""

	var skill_ids = dice_config.get("skill_ids", [])
	if skill_index >= 0 and skill_index < skill_ids.size():
		return skill_ids[skill_index]
	return ""


## 复位投掷的骰子
func _reset_throw_dices():
	print("【BattleSkillBar】等待 1.0 秒余韵时间...")
	await get_tree().create_timer(1.0).timeout

	# 隐藏技能骰子（从场景移除）
	if selected_skill_dice and is_instance_valid(selected_skill_dice):
		selected_skill_dice.visible = false
		# 从场景移除但保留引用
		if selected_skill_dice.get_parent():
			selected_skill_dice.get_parent().remove_child(selected_skill_dice)

	# 复位属性骰子到各自的初始位置
	for dice in attribute_dices:
		if dice and is_instance_valid(dice):
			# 复位到记录的初始位置
			var initial_pos = attribute_dice_initial_positions.get(dice, Vector3(0, 4, 6))
			dice.position = initial_pos
			if dice.has_method("set_freeze"):
				dice.set_freeze(true)
			elif "freeze" in dice:
				dice.freeze = true
			dice.gravity_scale = 0.0
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO

	# 清空选择
	selected_skill_dice = null
	selected_character = null

	# 重置技能释放状态，允许再次投掷
	is_releasing_skill = false

	# 恢复技能栏
	set_skill_bar_enabled(true)
	_hide_throw_hint()

	print("【BattleSkillBar】投掷完成，骰子已复位")


## 隐藏投掷提示
func _hide_throw_hint():
	if throw_hint_label:
		throw_hint_label.visible = false


## 原始位置存储（用于震动效果）
var original_positions: Dictionary = {}


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
			# 检查属性是否存在
			var mp_name_val = "MP"
			var current_mp_val = 0
			var attr_mp_val = 50
			if "mp_name" in character:
				mp_name_val = character.mp_name
			if "current_mp" in character:
				current_mp_val = character.current_mp
			if "attr_mp" in character:
				attr_mp_val = character.attr_mp
			mp_label.text = "%s: %d/%d" % [mp_name_val, current_mp_val, attr_mp_val]
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
