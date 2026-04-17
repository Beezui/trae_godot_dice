extends Node
## 战斗管理器 (Autoload 单例)
## 负责管理整个战斗流程，包括入场、回合制战斗、胜负判定等

## 信号：战斗开始
signal on_battle_started()
## 信号：战斗结束
signal on_battle_finished(winner: String)  # winner: "player" 或 "enemy"
## 信号：回合开始
signal on_turn_started(turn_owner: String)  # "player" 或 "enemy"
## 信号：回合结束
signal on_turn_ended(turn_owner: String)
## 信号：角色行动完成
signal on_character_action_completed(character: BaseCharacter)
## 信号：战斗阶段变更
signal on_battle_phase_changed(old_phase: String, new_phase: String)

## 战斗状态枚举
enum BattleState {
	NONE,       # 无状态
	ENTERING,   # 入场中
	PLAYER_TURN,# 玩家回合
	ENEMY_TURN, # 敌方回合
	RESOLVING,  # 结算中
	FINISHED    # 战斗结束
}

## 战斗阶段
enum BattlePhase {
	PHASE_ENTER,      # 入场阶段
	PHASE_SETUP,      # 准备阶段（生成骰子）
	PHASE_BATTLE,     # 战斗阶段
	PHASE_RESOLVE,    # 结算阶段
	PHASE_TRANSITION  # 转换阶段（投掷命运骰子）
}

## 当前战斗状态
var current_state: BattleState = BattleState.NONE
## 当前战斗阶段
var current_phase: BattlePhase = BattlePhase.PHASE_ENTER

## 玩家角色列表
var player_characters: Array[BaseCharacter] = []
## 敌方角色列表
var enemy_characters: Array[BaseCharacter] = []
## 所有角色骰子（战斗中生成的）
var character_dices: Array = []
## 技能骰子列表
var skill_dices: Array = []
## 物品骰子列表（预留）
var item_dices: Array = []

## 当前回合数
var current_turn: int = 0
## 当前行动角色
var current_actor: BaseCharacter = null
## 行动点消耗倍率（可根据技能调整）
var mp_cost_multiplier: float = 1.0

## 战斗配置
var battle_config: Dictionary = {
	"player_first": true,  # 玩家先手
	"auto_end_turn": false,  # 是否自动结束回合
	"show_turn_indicator": true,  # 是否显示回合提示
}

## 战斗数据（用于结算）
var battle_data: Dictionary = {
	"damage_dealt": 0,  # 造成伤害
	"damage_received": 0,  # 受到伤害
	"skills_used": [],  # 使用的技能
	"turns_count": 0,  # 回合数
}


func _ready():
	print("【BattleManager】战斗管理器已就绪")


## 初始化战斗
## @param level_node 关卡节点数据
## @param player_party 玩家队伍（英雄 ID 列表）
func initialize_battle(level_node: LevelNode, player_party: Array[int]) -> bool:
	print("【BattleManager】初始化战斗...")
	print("  - 关卡节点：", level_node.name if level_node else "未知")
	print("  - 玩家队伍：", player_party)

	current_state = BattleState.ENTERING
	current_phase = BattlePhase.PHASE_ENTER

	# 清空之前的战斗数据
	_clear_battle_data()

	# 加载玩家角色
	_load_player_characters(player_party)

	# 加载敌方角色（从关卡节点配置）
	_load_enemy_characters(level_node)

	if player_characters.is_empty() or enemy_characters.is_empty():
		push_error("【BattleManager】玩家或敌方角色为空，无法开始战斗")
		return false

	on_battle_started.emit()
	_change_phase(BattlePhase.PHASE_ENTER)

	return true


## 开始战斗流程
func start_battle():
	print("【BattleManager】开始战斗流程")
	_change_phase(BattlePhase.PHASE_ENTER)
	await _enter_phase()

	_change_phase(BattlePhase.PHASE_SETUP)
	await _setup_phase()

	_change_phase(BattlePhase.PHASE_BATTLE)
	await _battle_phase()


## 入场阶段
func _enter_phase():
	print("【BattleManager】进入入场阶段")
	current_state = BattleState.ENTERING
	_change_phase(BattlePhase.PHASE_ENTER)

	# 1. 敌方角色入场
	print("【BattleManager】敌方角色入场...")
	await _character_enter(enemy_characters, "enemy")

	# 2. 玩家角色入场
	print("【BattleManager】玩家角色入场...")
	await _character_enter(player_characters, "player")

	print("【BattleManager】入场阶段完成")


## 角色入场（自动投掷）
## @param characters 角色列表
## @param side "player" 或 "enemy"
func _character_enter(characters: Array[BaseCharacter], side: String):
	var battle_scene = _get_battle_scene()
	var sandbox = null
	if battle_scene and battle_scene.has_node("Sandbox"):
		sandbox = battle_scene.get_node("Sandbox")

	for character in characters:
		print("【BattleManager】", side, "角色 ", character.name, " 入场")

		# 创建角色骰子（如果还没有）
		if not character.character_dice:
			_create_character_dice(character, side)

		# 将骰子添加到场景
		if character.character_dice and sandbox:
			# 设置位置（敌方在左边，玩家在右边）
			var offset = -8.0 if side == "enemy" else 8.0
			var index = characters.find(character)
			character.character_dice.position = Vector3(offset + index * 2.0, 0.5, 0.0)
			sandbox.add_child(character.character_dice)
			print("【BattleManager】角色骰子已添加到场景：", character.character_dice.position)

		# 自动投掷
		if character.character_dice:
			# 暂停物理
			character.character_dice.set_process(false)
			character.character_dice.linear_velocity = Vector3.ZERO
			character.character_dice.angular_velocity = Vector3.ZERO

			# 使用 DiceThrowController 投掷
			if DiceThrowController.get_instance():
				DiceThrowController.throw_normal([character.character_dice], 1.0)

			# 等待骰子稳定
			await get_tree().create_timer(2.0).timeout

			# 锁定骰子
			if character.has_method("lock_character_dice"):
				character.lock_character_dice()

		await get_tree().create_timer(0.5).timeout

	await get_tree().create_timer(1.0).timeout


## 创建角色骰子
## @param character 角色
## @param side "player" 或 "enemy"
func _create_character_dice(character: BaseCharacter, side: String):
	var dice_scene = load("res://scenes/dice_6.tscn")
	if not dice_scene:
		print("【BattleManager】无法加载骰子场景")
		return

	var dice = dice_scene.instantiate()
	if not dice:
		print("【BattleManager】无法实例化骰子场景")
		return

	dice.dice_type = "character"
	dice.skip_skill_trigger = true

	# 应用角色贴图：使用 hero.json 中的 hero_texture 字段
	# 格式：res://textures/hero/hero_{hero_id}_{state}.png
	var texture_config = {}
	var hero_id = character.hero_id
	var hero_texture_states = character.hero_textures  # ["idle", "hit", "attack", "anger", "happy", "die"]

	for i in range(6):
		if i < hero_texture_states.size():
			var texture_state = hero_texture_states[i]
			var texture_path = "res://textures/hero/hero_" + str(hero_id) + "_" + texture_state + ".png"
			texture_config[i] = texture_path
			print("【BattleManager】角色骰子面 ", i, " 贴图：", texture_path)
		else:
			# 默认使用 idle 状态
			var default_path = "res://textures/hero/hero_" + str(hero_id) + "_idle.png"
			texture_config[i] = default_path
			print("【BattleManager】角色骰子面 ", i, " 使用默认贴图：", default_path)

	if dice.has_method("set_dice_face_config"):
		dice.set_dice_face_config(texture_config, {})

	# 存储到角色
	character.character_dice = dice
	print("【BattleManager】角色骰子已创建：", character.name)


## 准备阶段（生成骰子）
func _setup_phase():
	print("【BattleManager】准备阶段：生成骰子")
	_change_phase(BattlePhase.PHASE_SETUP)

	# 为玩家角色生成技能骰子和物品骰子
	for character in player_characters:
		await _generate_character_dices(character)

	# 将技能骰子添加到场景中（如果有场景引用）
	var battle_scene = _get_battle_scene()
	if battle_scene and battle_scene.has_node("Sandbox"):
		var sandbox = battle_scene.get_node("Sandbox")
		for dice in skill_dices:
			if dice and dice is Node:
				# 设置骰子位置（排成一排）
				var index = skill_dices.find(dice)
				dice.position = Vector3(-2.0 + index * 2.0, 4.0, 6.0)
				sandbox.add_child(dice)
				print("【BattleManager】技能骰子已添加到场景：位置=", dice.position)

	# 初始化 UI（如果有技能栏）
	if battle_scene and battle_scene.has_method("get_skill_bar"):
		var skill_bar = battle_scene.get_skill_bar()
		if skill_bar:
			skill_bar.initialize(player_characters, skill_dices, item_dices)
			skill_bar.update_turn_display(current_turn)
			if player_characters.size() > 0:
				skill_bar.update_mp_display(player_characters[0])
			print("【BattleManager】技能栏 UI 已初始化")

	await get_tree().create_timer(1.0).timeout
	print("【BattleManager】准备阶段完成")


## 获取战斗场景引用
func _get_battle_scene() -> Node:
	"""获取当前战斗场景引用"""
	# 尝试从场景树中查找带有"battle"组的节点
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		for i in range(tree.root.get_child_count()):
			var child = tree.root.get_child(i)
			if child.is_in_group("battle"):
				return child
	return null


## 为角色生成骰子
## @param character 角色实例
func _generate_character_dices(character: BaseCharacter):
	print("【BattleManager】为 ", character.name, " 生成骰子")

	# 1. 生成技能骰子
	if character.skill_dice_ids.size() > 0:
		for skill_dice_id in character.skill_dice_ids:
			var dice = _create_skill_dice(skill_dice_id)
			if dice:
				skill_dices.append(dice)
				character_dices.append(dice)
				print("  - 生成技能骰子：", skill_dice_id)

	# 2. 生成物品骰子（预留）
	# TODO: 实现物品骰子
	# for item_dice_id in character.item_dice_ids:
	#     var dice = _create_item_dice(item_dice_id)
	#     if dice:
	#         item_dices.append(dice)
	#         character_dices.append(dice)

	print("【BattleManager】", character.name, " 的骰子生成完成")


## 创建技能骰子
## @param skill_dice_id 技能骰子 ID
func _create_skill_dice(skill_dice_id: String) -> RigidBody3D:
	print("【BattleManager】创建技能骰子：", skill_dice_id)

	# 1. 从 SkillDices.json 读取配置
	var dice_config = _load_skill_dice_config(skill_dice_id)
	if dice_config.is_empty():
		push_error("【BattleManager】未找到技能骰子配置：", skill_dice_id)
		return null

	# 2. 加载技能骰子场景
	var dice_scene = load("res://scenes/dice_6.tscn")
	if not dice_scene:
		push_error("【BattleManager】无法加载骰子场景：res://scenes/dice_6.tscn")
		return null

	var dice = dice_scene.instantiate()
	if not dice:
		push_error("【BattleManager】无法实例化骰子场景")
		return null

	# 3. 设置骰子类型
	dice.dice_type = "skill"

	# 4. 应用贴图配置
	var texture_config = _build_skill_texture_config(dice_config)
	var value_config = _build_skill_value_config(dice_config)

	if dice.has_method("set_dice_face_config"):
		dice.set_dice_face_config(texture_config, value_config)

	# 5. 初始状态设置为悬浮
	if dice.has_method("set_freeze"):
		dice.set_freeze(true)
	elif "freeze" in dice:
		dice.freeze = true

	dice.gravity_scale = 0.0
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO

	print("【BattleManager】技能骰子创建完成：", skill_dice_id)
	return dice


## 加载技能骰子配置
## @param dice_id 技能骰子 ID
## @return 配置字典
func _load_skill_dice_config(dice_id: String) -> Dictionary:
	var reader = DiceCSVReader.new()
	return reader.get_skill_dice_config(dice_id)


## 构建技能贴图配置
## @param dice_config 技能骰子配置
## @return 贴图配置字典
func _build_skill_texture_config(dice_config: Dictionary) -> Dictionary:
	var texture_config = {}
	var skill_ids = dice_config.get("skill_ids", [])

	for i in range(6):
		if i < skill_ids.size():
			var skill_id = skill_ids[i]
			var skill_data = SkillManager.get_skill(skill_id)
			if not skill_data.is_empty():
				# 贴图路径：res://textures/skill/skill_{id}.png
				texture_config[i] = "res://textures/skill/skill_" + skill_id + ".png"
			else:
				texture_config[i] = ""  # 空路径会使用备用颜色
		else:
			texture_config[i] = ""

	return texture_config


## 构建技能骰子点数配置
## @param dice_config 技能骰子配置
## @return 点数配置字典
func _build_skill_value_config(dice_config: Dictionary) -> Dictionary:
	var value_config = {}

	# 技能骰子六个面对应六个技能索引
	for i in range(6):
		value_config[i] = i + 1  # 面索引 0-5 对应骰子点数 1-6

	return value_config


## 创建物品骰子（预留）
## @param item_dice_id 物品骰子 ID
func _create_item_dice(item_dice_id: String):
	print("【BattleManager】创建物品骰子：", item_dice_id)
	# TODO: 实现物品骰子
	return null


## 战斗阶段
func _battle_phase():
	print("【BattleManager】进入战斗阶段")
	_change_phase(BattlePhase.PHASE_BATTLE)

	current_turn = 1

	# 开始玩家回合
	if battle_config.player_first:
		_start_player_turn()
	else:
		_start_enemy_turn()


## 开始玩家回合
func _start_player_turn():
	print("【BattleManager】第 ", current_turn, " 回合 - 玩家回合")
	current_state = BattleState.PLAYER_TURN
	on_turn_started.emit("player")

	# 恢复玩家角色 MP（回合开始）
	for character in player_characters:
		if character.is_alive():
			_recover_mp(character)

	# 等待玩家操作
	# UI 会显示技能栏，玩家选择技能骰子


## 开始敌方回合
func _start_enemy_turn():
	print("【BattleManager】第 ", current_turn, " 回合 - 敌方回合")
	current_state = BattleState.ENEMY_TURN
	on_turn_started.emit("enemy")

	# 恢复敌方角色 MP
	for character in enemy_characters:
		if character.is_alive():
			_recover_mp(character)

	# 敌方 AI 行动
	await _enemy_ai_turn()


## 敌方 AI 回合
func _enemy_ai_turn():
	print("【BattleManager】敌方 AI 行动中...")

	for character in enemy_characters:
		if not character.is_alive():
			continue

		current_actor = character

		# AI 决策（简单实现：随机行动）
		await _enemy_action(character)

		current_actor = null
		await get_tree().create_timer(1.0).timeout

	# 敌方回合结束
	on_turn_ended.emit("enemy")

	# 检查胜负
	if _check_battle_end():
		return

	# 进入下一回合（玩家回合）
	current_turn += 1
	_start_player_turn()


## 敌方行动（简单 AI）
## @param character 敌方角色
func _enemy_action(character: BaseCharacter):
	# TODO: 实现 AI 决策
	# 暂时随机选择一个行动
	print("【BattleManager】", character.name, " 进行行动")

	# 1. 检查是否有足够 MP
	if character.current_mp >= 10:
		# 使用技能
		print("  - 使用技能（MP 足够）")
		# TODO: 调用技能
	else:
		# 普通攻击
		print("  - 普通攻击（MP 不足）")
		# TODO: 实现普通攻击

	await get_tree().create_timer(1.0).timeout


## 玩家使用技能
## @param character 玩家角色
## @param skill_dice 技能骰子
## @param target 目标
func player_use_skill(character: BaseCharacter, skill_dice, target: BaseCharacter) -> bool:
	if current_state != BattleState.PLAYER_TURN:
		push_warning("【BattleManager】当前不是玩家回合")
		return false

	if not character.is_alive():
		push_warning("【BattleManager】角色已阵亡")
		return false

	# 计算 MP 消耗
	var mp_cost = _calculate_mp_cost(skill_dice, character)

	if not character.can_afford_mp(mp_cost):
		push_warning("【BattleManager】MP 不足：需要 ", mp_cost, ", 当前 ", character.current_mp)
		return false

	# 消耗 MP
	character.take_mp_cost(mp_cost)

	# 执行技能
	print("【BattleManager】", character.name, " 使用技能，消耗 MP: ", mp_cost)
	_execute_skill(character, skill_dice, target)

	# 记录数据
	battle_data.skills_used.append({
		"character": character.name,
		"skill_dice": skill_dice,
		"target": target.name if target else null,
		"mp_cost": mp_cost
	})

	on_character_action_completed.emit(character)

	return true


## 执行技能
## @param character 施法角色
## @param skill_dice 技能骰子
## @param target 目标
func _execute_skill(character: BaseCharacter, skill_dice, target: BaseCharacter):
	# 1. 获取技能 ID
	var skill_id = _get_skill_id_from_dice(skill_dice, character)
	if not skill_id:
		print("【BattleManager】无法获取技能 ID")
		return

	# 2. 准备技能参数
	var dice_results = {}
	if skill_dice and skill_dice.has_method("get_dice_value"):
		var dice_value = skill_dice.get_dice_value()
		dice_results["dice_value"] = dice_value

	# 3. 获取属性骰子结果（从角色）
	if character.attribute_dices.size() > 0:
		for attr_name in ["str", "agi", "int"]:
			if character.attribute_dices.has(attr_name):
				var attr_dice = character.attribute_dices[attr_name]
				if attr_dice and attr_dice.has_method("get_attribute_value"):
					dice_results[attr_name] = attr_dice.get_attribute_value()

	# 4. 调用 SkillManager
	var targets = [target] if target else []
	var params = {
		"dice_results": dice_results,
		"scene": _get_battle_scene(),
		"caster_position": character.character_dice.position if character.character_dice else Vector3.ZERO
	}

	# 使用技能（需要 caster 是 Node，所以传递 character_dice）
	var caster_node = character.character_dice if character.character_dice else character
	SkillManager.use_skill(skill_id, caster_node, targets, params)

	print("【BattleManager】技能已执行：", skill_id)


## 计算 MP 消耗
## @param skill_dice 技能骰子
## @param character 角色（用于获取技能骰子面上的技能 ID）
func _calculate_mp_cost(skill_dice, character: BaseCharacter = null) -> int:
	# 1. 获取技能骰子上的技能 ID
	var skill_id = _get_skill_id_from_dice(skill_dice, character)
	if not skill_id:
		# 无法获取技能 ID，返回默认值
		return 10

	# 2. 从 SkillManager 获取技能配置
	var skill_data = SkillManager.get_skill(skill_id)
	if skill_data.is_empty():
		print("【BattleManager】未找到技能配置：", skill_id)
		return 10

	# 3. 读取 mp_cost 字段
	var base_mp_cost = skill_data.get("mp_cost", 10)

	# 4. 应用 MP 消耗倍率（buff/debuff 影响）
	var final_cost = int(base_mp_cost * mp_cost_multiplier)

	print("【BattleManager】计算 MP 消耗：技能=", skill_data.get("name", "未知"),
		  ", 基础消耗=", base_mp_cost, ", 倍率=", mp_cost_multiplier, ", 最终消耗=", final_cost)

	return final_cost


## 从技能骰子获取技能 ID
## @param skill_dice 技能骰子
## @param character 角色（用于确定使用哪个技能）
func _get_skill_id_from_dice(skill_dice, character: BaseCharacter = null) -> String:
	# 1. 获取骰子点数
	var dice_value = 1
	if skill_dice and skill_dice.has_method("get_dice_value"):
		dice_value = skill_dice.get_dice_value()
	elif "dice_value" in skill_dice:
		dice_value = skill_dice.dice_value

	# 2. 从角色配置获取技能骰子 ID
	if character and character.skill_dice_ids.size() > 0:
		var skill_dice_id = character.skill_dice_ids[0]  # 暂时只支持一个技能骰子

		# 3. 从 SkillDices.json 读取技能 ID 列表
		var reader = DiceCSVReader.new()
		var dice_config = reader.get_skill_dice_config(skill_dice_id)
		var skill_ids = dice_config.get("skill_ids", [])

		# 4. 根据骰子点数获取对应的技能 ID（点数 1-6 对应索引 0-5）
		var skill_index = dice_value - 1
		if skill_index >= 0 and skill_index < skill_ids.size():
			return skill_ids[skill_index]

	# 5. 默认返回第一个技能
	if character and character.skill_dice_ids.size() > 0:
		var skill_dice_id = character.skill_dice_ids[0]
		var reader = DiceCSVReader.new()
		var dice_config = reader.get_skill_dice_config(skill_dice_id)
		var skill_ids = dice_config.get("skill_ids", [])
		if skill_ids.size() > 0:
			return skill_ids[0]

	return ""


## 恢复 MP
## @param character 角色
func _recover_mp(character: BaseCharacter):
	var recover_amount = 10  # 基础恢复量
	# TODO: 根据角色属性计算恢复量
	character.recover_mp(recover_amount)
	print("【BattleManager】", character.name, " 恢复 ", recover_amount, " MP")


## 玩家结束回合
func player_end_turn():
	if current_state != BattleState.PLAYER_TURN:
		return

	print("【BattleManager】玩家结束回合")
	on_turn_ended.emit("player")

	# 检查胜负
	if _check_battle_end():
		return

	# 进入敌方回合
	_start_enemy_turn()


## 检查战斗结束
func _check_battle_end() -> bool:
	# 检查敌方是否全部阵亡
	var enemy_alive = false
	for character in enemy_characters:
		if character.is_alive():
			enemy_alive = true
			break

	if not enemy_alive:
		# 玩家胜利
		_finish_battle("player")
		return true

	# 检查玩家是否全部阵亡
	var player_alive = false
	for character in player_characters:
		if character.is_alive():
			player_alive = true
			break

	if not player_alive:
		# 玩家失败
		_finish_battle("enemy")
		return true

	return false


## 结束战斗
## @param winner "player" 或 "enemy"
func _finish_battle(winner: String):
	print("【BattleManager】战斗结束，胜利者：", winner)
	current_state = BattleState.FINISHED
	_change_phase(BattlePhase.PHASE_RESOLVE)

	on_battle_finished.emit(winner)

	# 结算奖励
	if winner == "player":
		_resolve_rewards()


## 结算奖励
func _resolve_rewards():
	print("【BattleManager】结算奖励...")
	# TODO: 根据关卡节点配置发放奖励

	# 进入转换阶段（投掷命运骰子）
	_change_phase(BattlePhase.PHASE_TRANSITION)
	await _transition_phase()


## 转换阶段（投掷命运骰子）
func _transition_phase():
	print("【BattleManager】进入转换阶段")
	_change_phase(BattlePhase.PHASE_TRANSITION)

	# TODO: 触发命运骰子投掷
	# 这里应该调用 DestinyDiceManager

	await get_tree().create_timer(2.0).timeout


## 切换阶段
func _change_phase(new_phase: BattlePhase):
	var old_phase = current_phase
	current_phase = new_phase
	var old_phase_name = BattlePhase.keys()[old_phase]
	var new_phase_name = BattlePhase.keys()[new_phase]
	print("【BattleManager】阶段变更：", old_phase_name, " -> ", new_phase_name)
	on_battle_phase_changed.emit(old_phase_name, new_phase_name)


## 清空战斗数据
func _clear_battle_data():
	player_characters.clear()
	enemy_characters.clear()
	character_dices.clear()
	skill_dices.clear()
	item_dices.clear()
	current_turn = 0
	current_actor = null
	battle_data = {
		"damage_dealt": 0,
		"damage_received": 0,
		"skills_used": [],
		"turns_count": 0,
	}
	print("【BattleManager】已清空战斗数据")


## 加载玩家角色
func _load_player_characters(player_party: Array[int]):
	for hero_id in player_party:
		var character = CharacterManager.create_character(hero_id, "player")
		if character:
			player_characters.append(character)


## 加载敌方角色
func _load_enemy_characters(level_node: LevelNode):
	if not level_node:
		print("【BattleManager】关卡节点为空")
		return

	if not level_node.data.has("enemies"):
		print("【BattleManager】关卡节点无敌人配置")
		return

	# 从关卡节点配置加载敌人
	var enemy_ids = level_node.data["enemies"]
	print("【BattleManager】加载敌人：", enemy_ids)

	for enemy_id in enemy_ids:
		# 将 String 类型的 ID 转换为 int
		var enemy_id_int = int(enemy_id) if enemy_id is String else enemy_id
		var character = CharacterManager.create_character(enemy_id_int, "enemy")
		if character:
			enemy_characters.append(character)
			print("【BattleManager】敌人已加载：", character.name, " (ID: ", enemy_id_int, ")")


## 获取战斗统计
func get_battle_stats() -> Dictionary:
	return {
		"turns": current_turn,
		"damage_dealt": battle_data.damage_dealt,
		"damage_received": battle_data.damage_received,
		"skills_used": battle_data.skills_used.size(),
	}
