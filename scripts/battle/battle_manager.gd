extends Node
## 战斗管理器 (Autoload 单例)
## 负责管理整个战斗流程，包括入场、回合制战斗、胜负判定等

## ========== 骰子位置配置 ==========
const DICE_THROW_Y: float = 8.0   ## 待投掷区域高度（所有骰子悬浮 Y）
const PLAYER_DICE_Z: float = 6.0  ## 玩家侧骰子 Z 坐标
const ENEMY_DICE_Z: float = -6.0  ## 敌方侧骰子 Z 坐标
## ==================================

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
## 是否允许技能装配（进入战斗后锁定，战斗结束后解锁）
var can_equip_skills: bool = true

## 战斗配置
var battle_config: Dictionary = {
	"player_first": true,  # 玩家先手
	"auto_end_turn": false,  # 是否自动结束回合
	"show_turn_indicator": true,  # 是否显示回合提示
	"spawn_skill_dices": true,  # 是否生成技能骰子
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

	can_equip_skills = false  # 进入战斗后锁定技能装配

	current_state = BattleState.ENTERING
	current_phase = BattlePhase.PHASE_ENTER

	# 清空之前的战斗数据
	_clear_battle_data()

	# 加载玩家角色
	_load_player_characters(player_party)

	# 加载敌方角色（从关卡节点配置，传入玩家队伍用于阶段参考）
	_load_enemy_characters(level_node, player_party)

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

	# 获取场景 Sandbox（优先 Sandbox，备用 GameManager）
	var battle_scene = _get_battle_scene()
	var sandbox = _get_sandbox_from_scene(battle_scene)

	# 使用 CharacterEnterManager 统一处理角色入场
	var enter_manager = Engine.get_main_loop().root.get_node_or_null("CharacterEnterManager")
	if enter_manager and sandbox:
		print("【BattleManager】使用 CharacterEnterManager 处理玩家入场")
		await enter_manager.player_batch_enter(player_characters, sandbox)

		print("【BattleManager】使用 CharacterEnterManager 处理敌方入场")
		await enter_manager.enemy_batch_enter(enemy_characters, sandbox)
	else:
		# 备用方案：使用原有逻辑
		print("【BattleManager】CharacterEnterManager 不可用，使用备用方案")
		await _character_enter_fallback(player_characters, "player")
		await _character_enter_fallback(enemy_characters, "enemy")

	print("【BattleManager】入场阶段完成")


## 角色入场（备用方案）
## @param characters 角色列表
## @param side "player" 或 "enemy"
func _character_enter_fallback(characters: Array[BaseCharacter], side: String):
	var battle_scene = _get_battle_scene()
	var sandbox = _get_sandbox_from_scene(battle_scene)

	# 玩家角色从中间入场，敌方角色随机位置入场
	var player_start_x = 0.0  # 玩家从中间 X=0 开始
	var enemy_positions = [-6.0, -2.0, 2.0, 6.0]  # 敌方随机位置选项

	for character in characters:
		print("【BattleManager】【备用方案】", side, "角色 ", character.name, " 入场")

		# 创建角色骰子（如果还没有）
		if not character.character_dice:
			_create_character_dice(character, side)

		# 计算位置
		var index = characters.find(character)
		var x_position: float

		if side == "enemy":
			# 敌方随机位置（从预设位置中随机选择）
			var random_index = randi() % enemy_positions.size()
			x_position = enemy_positions[random_index]
			# 移除已使用的位置，避免重复
			enemy_positions.remove_at(random_index)
			if enemy_positions.is_empty():
				enemy_positions = [-6.0, -2.0, 2.0, 6.0]  # 重置位置池
		else:
			# 玩家从中间向两侧排列
			x_position = player_start_x + index * 2.0 * (1 if index % 2 == 0 else -1)
			if index > 0:
				x_position = x_position * (-1 if index % 2 == 0 else 1)

		# 将骰子添加到场景
		if character.character_dice and sandbox:
			character.character_dice.position = Vector3(x_position, 0.5, 0.0)
			sandbox.add_child(character.character_dice)
			print("【BattleManager】【备用方案】角色骰子已添加到场景：", character.character_dice.position)

		# 自动投掷
		if character.character_dice:
			# 暂停物理
			character.character_dice.set_process(false)
			character.character_dice.linear_velocity = Vector3.ZERO
			character.character_dice.angular_velocity = Vector3.ZERO

			# 敌方角色从北侧入场（与技能投掷方向一致），玩家角色从南侧入场
			if side == "enemy":
				# 敌方角色从北墙附近入场（Z=-6），向南投掷（Z 正方向）
				character.character_dice.position = Vector3(x_position, DICE_THROW_Y, ENEMY_DICE_Z)
				character.character_dice.gravity_scale = 1.0

				# 解除悬浮状态
				if character.character_dice.has_method("set_freeze"):
					character.character_dice.set_freeze(false)
				elif "freeze" in character.character_dice:
					character.character_dice.freeze = false

				# 投掷方向：向后（Z 正方向）+ 稍微向下（Y 负方向）
				var direction = Vector3(0, -0.3, 1).normalized()
				var throw_force = 8.0  # 减小投掷力度（原 12.0）
				var force = direction * throw_force

				# 随机旋转力（减小力度）
				var angular_force = Vector3(
					randf_range(-3, 3),  # 原 -5 到 5
					randf_range(-3, 3),
					randf_range(-3, 3)
				)

				# 调用骰子的 roll 方法
				if character.character_dice.has_method("roll"):
					character.character_dice.roll(force, angular_force)
					print("【BattleManager】【备用方案】敌方角色骰子入场投掷，位置=", character.character_dice.position)
			else:
				# 玩家角色从南侧入场（Z=+6），向北投掷（Z 负方向）
				character.character_dice.position = Vector3(x_position, DICE_THROW_Y, PLAYER_DICE_Z)
				character.character_dice.gravity_scale = 1.0

				# 解除悬浮状态
				if character.character_dice.has_method("set_freeze"):
					character.character_dice.set_freeze(false)
				elif "freeze" in character.character_dice:
					character.character_dice.freeze = false

				# 投掷方向：向前（Z 负方向）+ 稍微向下（Y 负方向）
				var direction = Vector3(0, -0.3, -1).normalized()
				var throw_force = 8.0  # 减小投掷力度（原 12.0）
				var force = direction * throw_force

				# 随机旋转力（减小力度）
				var angular_force = Vector3(
					randf_range(-3, 3),  # 原 -5 到 5
					randf_range(-3, 3),
					randf_range(-3, 3)
				)

				# 调用骰子的 roll 方法
				if character.character_dice.has_method("roll"):
					character.character_dice.roll(force, angular_force)
					print("【BattleManager】【备用方案】玩家角色骰子入场投掷，位置=", character.character_dice.position)

			# 等待骰子稳定
			await get_tree().create_timer(2.0).timeout

			# 锁定骰子
			if character.has_method("lock_character_dice"):
				character.lock_character_dice()

		await get_tree().create_timer(0.5).timeout

	await get_tree().create_timer(1.0).timeout


## 创建角色骰子（使用 DiceManager 统一接口）
## @param character 角色
## @param side "player" 或 "enemy"
## @deprecated 已废弃，使用 CharacterEnterManager 统一处理
func _create_character_dice(character: BaseCharacter, side: String):
	var battle_scene = _get_battle_scene()
	var sandbox = _get_sandbox_from_scene(battle_scene)
	if not battle_scene or not sandbox:
		print("【BattleManager】Sandbox/Gamemanager 节点不存在，无法创建角色骰子")
		return

	# 计算位置：敌方在左边，玩家在右边
	var offset = -8.0 if side == "enemy" else 8.0
	var index = (player_characters.find(character) if side == "player" else enemy_characters.find(character))
	var position = Vector3(offset + index * 2.0, 0.5, 0.0)

	# 使用 DiceManager 统一创建
	if DiceManager:
		character.character_dice = DiceManager.create_character_dice(character, sandbox, position)
	else:
		print("【BattleManager】警告：DiceManager 不可用，使用备用方案")
		_create_character_dice_fallback(character, side, sandbox, position)


## 准备阶段（生成骰子）
func _setup_phase():
	print("【BattleManager】准备阶段：生成骰子")
	_change_phase(BattlePhase.PHASE_SETUP)

	# 1. 生成技能骰子（隐藏，不添加到场景，仅在 UI 中显示）
	if battle_config.get("spawn_skill_dices", true):
		for character in player_characters:
			await _generate_skill_dices_for_character(character)
		print("【BattleManager】技能骰子生成完成，总数：", skill_dices.size())

	# 2. 生成属性骰子（悬浮待命，在场景中但不投掷）
	var battle_scene = _get_battle_scene()
	var sandbox = _get_sandbox_from_scene(battle_scene)
	if sandbox and player_characters.size() > 0:
		await _generate_attribute_dices_for_player(player_characters[0], sandbox)

	# 3. 初始化 UI（通过 BattleUIManager 创建持久化全局 UI）
	print("【BattleManager】通过 BattleUIManager 初始化技能栏 UI")
	print("  - skill_dices 数组：", skill_dices)
	print("  - skill_dices 大小：", skill_dices.size())

	if BattleUIManager:
		var success = BattleUIManager.show_skill_bar(player_characters, skill_dices, [])
		if success:
			var skill_bar = BattleUIManager.get_skill_bar()
			if skill_bar:
				skill_bar.update_turn_display(current_turn)
				if player_characters.size() > 0:
					skill_bar.update_mp_display(player_characters[0])
			print("【BattleManager】技能栏 UI 已初始化")
		else:
			print("【BattleManager】错误：BattleUIManager.show_skill_bar 失败")
	else:
		print("【BattleManager】错误：BattleUIManager 不可用")

	await get_tree().create_timer(1.0).timeout
	print("【BattleManager】准备阶段完成")


## 获取战斗场景引用
func _get_battle_scene() -> Node:
	"""获取当前战斗场景引用"""
	var tree = Engine.get_main_loop()
	if not tree or not tree.root:
		return null

	# 1. 优先从 LevelStage 获取当前加载的场景（关卡转换后的场景）
	var level_stage = LevelStage.get_instance()
	if level_stage and level_stage.has_method("get_current_scene"):
		var current_scene = level_stage.get_current_scene()
		if current_scene and is_instance_valid(current_scene):
			print("【BattleManager】从 LevelStage 获取战斗场景：", current_scene.name)
			return current_scene

	# 2. 尝试从场景树中查找带有"battle"组的节点
	for i in range(tree.root.get_child_count()):
		var child = tree.root.get_child(i)
		if child.is_in_group("battle"):
			return child

	# 3. 回退方案：查找带有 Sandbox 子节点的节点（game_main）
	for i in range(tree.root.get_child_count()):
		var child = tree.root.get_child(i)
		if child.has_node("Sandbox"):
			return child

	return null


## 从战斗场景获取骰子容器（Sandbox 或 GameManager）
func _get_sandbox_from_scene(scene: Node) -> Node:
	"""获取场景中用于存放骰子的容器节点"""
	if not scene:
		return null
	# 优先使用 Sandbox（game_main 和 BattleSceneBase 使用）
	if scene.has_node("Sandbox"):
		return scene.get_node("Sandbox")
	# 备用使用 GameManager（关卡模板场景使用）
	if scene.has_node("GameManager"):
		return scene.get_node("GameManager")
	return null


## 生成角色骰子（使用 DiceManager 统一接口）
## @param character 角色实例
func _generate_character_dices(character: BaseCharacter):
	print("【BattleManager】为 ", character.name, " 生成骰子")

	var battle_scene = _get_battle_scene()
	var sandbox = _get_sandbox_from_scene(battle_scene)

	# 使用角色预设骰子
	print("  - 使用角色预设骰子 ID：", character.skill_dice_ids)
	if character.skill_dice_ids.size() > 0:
		for skill_dice_id in character.skill_dice_ids:
			if DiceManager:
				var dice = DiceManager.create_skill_dice(skill_dice_id, sandbox, Vector3(-2.0, DICE_THROW_Y, PLAYER_DICE_Z))
				if dice:
					skill_dices.append(dice)
					character_dices.append(dice)
					print("  - 生成技能骰子：", skill_dice_id)
			else:
				var dice = _create_skill_dice_fallback(skill_dice_id)
				if dice:
					skill_dices.append(dice)
					character_dices.append(dice)

	print("【BattleManager】", character.name, " 的骰子生成完成")


## 为玩家角色生成技能骰子（隐藏，不添加到场景）
## @param character 角色实例
func _generate_skill_dices_for_character(character: BaseCharacter):
	print("【BattleManager】为 ", character.name, " 生成技能骰子（隐藏）")
	
	# 从 PlayerData 读取用户装配的骰子实例（优先使用玩家装配的数据）
	if PlayerData:
		var all_instance_ids = PlayerData.get_all_dice_instance_ids()
		print("  - PlayerData 骰子实例数量：", all_instance_ids.size())
		
		if all_instance_ids.size() > 0:
			# 使用 DiceManager.create_skill_dice_from_player_data() 创建技能骰子
			for instance_id in all_instance_ids:
				if DiceManager:
					var dice = DiceManager.create_skill_dice_from_player_data(instance_id, null, Vector3.ZERO, false)
					if dice:
						skill_dices.append(dice)
						# 设置为隐藏状态
						dice.visible = false
						# 设置为悬浮状态
						if dice.has_method("set_freeze"):
							dice.set_freeze(true)
						elif "freeze" in dice:
							dice.freeze = true
						dice.gravity_scale = 0.0
						print("  - 生成技能骰子（来自 PlayerData 实例 ", instance_id, "）：", dice)
					else:
						print("  - 错误：技能骰子创建失败（实例 ID：", instance_id, "）")
				else:
					print("  - 错误：DiceManager 不可用")
		else:
			# 如果 PlayerData 中没有骰子实例，回退到使用 character.skill_dice_ids（静态配置）
			push_warning("【BattleManager】PlayerData 中无骰子实例，使用静态配置")
			_generate_skill_dices_from_static_config(character)
	else:
		push_warning("【BattleManager】PlayerData 不可用，使用静态配置")
		_generate_skill_dices_from_static_config(character)
	
	# 生成属性骰子（悬浮待命）


## 为玩家角色生成属性骰子（悬浮待命）
## @param character 角色实例
## @param sandbox 场景节点
func _generate_attribute_dices_for_player(character: BaseCharacter, sandbox: Node):
	print("【BattleManager】为 ", character.name, " 生成属性骰子（悬浮待命）")

	var hero_id = character.hero_id

	# 创建三个属性骰子（str, agi, int）
	var attr_types = ["str", "agi", "int"]
	var positions = [
		Vector3(-2.0, DICE_THROW_Y, PLAYER_DICE_Z),  # 力量骰子位置
		Vector3(0.0, DICE_THROW_Y, PLAYER_DICE_Z),   # 敏捷骰子位置
		Vector3(2.0, DICE_THROW_Y, PLAYER_DICE_Z)    # 智力骰子位置
	]

	for i in range(3):
		var attr_type = attr_types[i]
		var position = positions[i]
		if DiceManager:
			var dice = DiceManager.create_attribute_dice(hero_id, attr_type, sandbox, position)
			if dice:
				# 设置为悬浮状态
				if dice.has_method("set_freeze"):
					dice.set_freeze(true)
				elif "freeze" in dice:
					dice.freeze = true
				dice.gravity_scale = 0.0
				dice.linear_velocity = Vector3.ZERO
				dice.angular_velocity = Vector3.ZERO
				print("  - 生成属性骰子（悬浮）：", attr_type)


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

		# 添加高亮效果（标识当前行动角色）
		_highlight_enemy_character(character)

		# 等待 0.5 秒后再行动（先闪光后行动）
		await get_tree().create_timer(0.5).timeout

		# AI 决策（简单实现：随机行动）
		await _enemy_action(character)

		# 移除高亮效果
		_remove_enemy_character_highlight(character)

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


## 高亮敌方角色骰子
func _highlight_enemy_character(character: BaseCharacter):
	"""给当前行动的敌方角色骰子添加高亮效果"""
	if character.character_dice and is_instance_valid(character.character_dice):
		if character.character_dice.has_method("add_highlight"):
			character.character_dice.add_highlight()
			print("【BattleManager】已高亮敌方角色：", character.name)


## 移除敌方角色骰子高亮
func _remove_enemy_character_highlight(character: BaseCharacter):
	"""移除敌方角色骰子的高亮效果"""
	if character.character_dice and is_instance_valid(character.character_dice):
		if character.character_dice.has_method("remove_highlight"):
			character.character_dice.remove_highlight()
			print("【BattleManager】已移除敌方角色高亮：", character.name)


## 敌方行动（简单 AI）
## @param character 敌方角色
func _enemy_action(character: BaseCharacter):
	print("【BattleManager】", character.name, " 进行行动")

	# 1. 检查是否有技能骰子 ID
	if character.skill_dice_ids.size() == 0:
		print("  - 没有技能骰子，使用普通攻击")
		await _enemy_simple_attack(character)
		return

	# 2. 随机选择一个技能骰子 ID
	var skill_dice_id = character.skill_dice_ids[randi() % character.skill_dice_ids.size()]
	print("  - 选择技能骰子：", skill_dice_id)

	# 3. 执行投掷（显示投掷动画）
	await _enemy_throw_dice(character, skill_dice_id)


## 敌方简单攻击（无技能骰子时）
func _enemy_simple_attack(character: BaseCharacter):
	# 临时实现：直接造成伤害
	var target = _get_first_alive_player()
	if target:
		var damage = 10
		print("  - 对 ", target.name, " 造成 ", damage, " 点伤害")
	await get_tree().create_timer(1.0).timeout


## 获取第一个存活的玩家角色
func _get_first_alive_player() -> BaseCharacter:
	for character in player_characters:
		if character.is_alive():
			return character
	return null


## 敌方投掷骰子
## @param character 敌方角色
## @param skill_dice_id 技能骰子 ID
func _enemy_throw_dice(character: BaseCharacter, skill_dice_id: String):
	print("【BattleManager】敌方投掷骰子：", skill_dice_id)

	var battle_scene = _get_battle_scene()
	var sandbox = _get_sandbox_from_scene(battle_scene)
	if not battle_scene or not sandbox:
		print("  - 场景不存在，跳过投掷")
		return

	# 1. 创建技能骰子（临时）- 从北墙附近进入（与玩家高度相同）
	var skill_start_pos = Vector3(-4.0, DICE_THROW_Y, ENEMY_DICE_Z)  # Z=-6 靠近北墙，Y 与玩家相同
	var skill_dice = DiceManager.create_skill_dice(skill_dice_id, sandbox, skill_start_pos)
	if not skill_dice:
		print("  - 无法创建技能骰子")
		return
	# 设置初始位置为北墙附近，与玩家投掷高度相同
	skill_dice.position = skill_start_pos
	# 启用重力，让骰子自然下落
	skill_dice.gravity_scale = 1.0

	# 2. 创建属性骰子（临时）- 从北墙附近进入（与玩家高度相同）
	var attr_dices = []
	var hero_id = character.hero_id
	var attr_types = ["str", "agi", "int"]
	# 敌方属性骰子位置：Z 轴为负值（北墙附近），比玩家位置更靠前，高度与玩家相同
	var positions = [
		Vector3(-2.0, DICE_THROW_Y, ENEMY_DICE_Z),  # 力量骰子位置
		Vector3(0.0, DICE_THROW_Y, ENEMY_DICE_Z),   # 敏捷骰子位置
		Vector3(2.0, DICE_THROW_Y, ENEMY_DICE_Z)    # 智力骰子位置
	]

	for i in range(3):
		var attr_type = attr_types[i]
		var position = positions[i]
		var dice = DiceManager.create_attribute_dice(hero_id, attr_type, sandbox, Vector3(position.x, DICE_THROW_Y, position.z))
		if dice:
			attr_dices.append(dice)
			# 设置初始位置为北墙附近，与玩家投掷高度相同
			dice.position = position
			# 启用重力，让骰子自然下落
			dice.gravity_scale = 1.0
			# 解除悬浮状态
			if dice.has_method("set_freeze"):
				dice.set_freeze(false)
			elif "freeze" in dice:
				dice.freeze = false

	# 3. 准备投掷（解除 freeze）
	var all_dices = [skill_dice] + attr_dices
	for dice in all_dices:
		if dice.has_method("set_freeze"):
			dice.set_freeze(false)
		elif "freeze" in dice:
			dice.freeze = false
		dice.linear_velocity = Vector3.ZERO
		dice.angular_velocity = Vector3.ZERO
		dice.sleeping = false

	# 4. 敌方投掷：从北墙向南墙投掷（Z 正方向，向后）
	# 投掷方向：向后（Z 正方向）+ 稍微向下（Y 负方向）
	for dice in all_dices:
		if dice and is_instance_valid(dice):
			# 投掷方向：向后（Z 正方向）+ 向下（Y 负方向）
			var direction = Vector3(0, -0.3, 1).normalized()
			var throw_force = 12.0  # 投掷力度

			var force = direction * throw_force

			# 随机旋转力
			var angular_force = Vector3(
				randf_range(-5, 5),
				randf_range(-5, 5),
				randf_range(-5, 5)
			)

			# 调用骰子的 roll 方法
			if dice.has_method("roll"):
				dice.roll(force, angular_force)
				print("【BattleManager】敌方骰子投掷，位置=", dice.position, ", 方向=", direction)

	# 5. 等待骰子停止
	await get_tree().create_timer(2.0).timeout

	# 6. 获取结果
	var skill_result = 1
	if skill_dice.has_method("get_dice_value"):
		skill_result = skill_dice.get_dice_value()

	var attr_results = {}
	for dice in attr_dices:
		if dice.has_method("get_attribute_value"):
			attr_results[dice.attr_type] = dice.get_attribute_value()

	print("  - 投掷结果：技能=", skill_result, ", 属性=", attr_results)

	# 7. 释放技能
	var skill_index = skill_result - 1
	var skill_id = _get_skill_id_from_dice_id(skill_dice_id, skill_index)
	if not skill_id.is_empty():
		await _enemy_release_skill(character, skill_id, attr_results, all_dices)

	# 8. 清理临时骰子
	await get_tree().create_timer(1.5).timeout
	for dice in all_dices:
		if dice and is_instance_valid(dice):
			dice.queue_free()


## 从技能骰子 ID 获取技能 ID
func _get_skill_id_from_dice_id(skill_dice_id: String, skill_index: int) -> String:
	var reader = DiceCSVReader.new()
	var dice_config = reader.get_skill_dice_config(skill_dice_id)
	if dice_config.is_empty():
		return ""

	var skill_ids = dice_config.get("skill_ids", [])
	if skill_index >= 0 and skill_index < skill_ids.size():
		return skill_ids[skill_index]
	return ""


## 敌方释放技能
func _enemy_release_skill(character: BaseCharacter, skill_id: String, attr_results: Dictionary, all_dices: Array):
	print("【BattleManager】敌方释放技能：", skill_id)

	# 获取目标
	var targets = []
	for player in player_characters:
		if player.is_alive():
			targets.append(player)
			break

	if targets.size() == 0:
		return

	# 创建施法者节点
	var caster_marker = Marker3D.new()
	if character.character_dice:
		caster_marker.position = character.character_dice.position
	else:
		caster_marker.position = Vector3(-8.0, 0.5, 0.0)

	get_tree().current_scene.add_child(caster_marker)

	var dice_results = {
		"str": attr_results.get("str", 0),
		"agi": attr_results.get("agi", 0),
		"int": attr_results.get("int", 0)
	}

	var params = {
		"dice_results": dice_results,
		"scene": get_tree().current_scene,
		"caster_position": caster_marker.position
	}

	SkillManager.use_skill(skill_id, caster_marker, targets, params)

	await get_tree().create_timer(3.0).timeout
	caster_marker.queue_free()


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
	can_equip_skills = true  # 战斗结束后解锁技能装配
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
## @param level_node 关卡节点
## @param player_party 玩家队伍（用于获取阶段信息，暂时从关卡节点读取）
func _load_enemy_characters(level_node: LevelNode, player_party: Array[int] = []):
	if not level_node:
		print("【BattleManager】关卡节点为空")
		return

	# 从关卡节点获取阶段信息
	var stage: int = level_node.data.get("stage", 1)
	print("【BattleManager】当前阶段：", stage)

	# 检查是否已经有预设的敌人配置（如 Boss 节点）
	if level_node.data.has("enemies") and level_node.data["enemies"].size() > 0:
		# 使用预设配置
		var enemy_ids = level_node.data["enemies"]
		print("【BattleManager】使用预设敌人配置：", enemy_ids)

		for enemy_id in enemy_ids:
			var enemy_id_int = int(enemy_id) if enemy_id is String else enemy_id
			var character = CharacterManager.create_character(enemy_id_int, "enemy")
			if character:
				enemy_characters.append(character)
				print("【BattleManager】敌人已加载：", character.name, " (ID: ", enemy_id_int, ")")
		return

	# 使用 EnemySelector 根据阶段随机选择敌人
	print("【BattleManager】使用 EnemySelector 选择敌人...")
	var enemy_selector = EnemySelector.get_instance()
	if not enemy_selector:
		push_error("【BattleManager】EnemySelector 不存在")
		return

	# 加载敌人池（根据阶段）
	if not enemy_selector.load_enemy_pool(stage):
		push_error("【BattleManager】阶段 ", stage, " 没有可用敌人")
		return

	# 选择一个敌人（每关卡固定 1 个）
	var enemy_config = enemy_selector.select_enemy(stage)
	if enemy_config.is_empty():
		push_error("【BattleManager】无法选择敌人")
		return

	# 创建敌人角色
	var enemy_id = int(enemy_config.get("id", 0))
	if enemy_id > 0:
		var character = CharacterManager.create_character(enemy_id, "enemy")
		if character:
			enemy_characters.append(character)
			print("【BattleManager】敌人已加载：", character.name,
				  " (type=", enemy_config.get("type"), ", stage=", enemy_config.get("stage"), ")")


## 获取战斗统计
func get_battle_stats() -> Dictionary:
	return {
		"turns": current_turn,
		"damage_dealt": battle_data.damage_dealt,
		"damage_received": battle_data.damage_received,
		"skills_used": battle_data.skills_used.size(),
	}


## 回退方案：从静态配置生成技能骰子（兼容旧逻辑）
## @param character 角色实例
func _generate_skill_dices_from_static_config(character: BaseCharacter):
	print("  - 使用静态配置生成技能骰子：", character.skill_dice_ids)
	
	if character.skill_dice_ids.size() > 0:
		for skill_dice_id in character.skill_dice_ids:
			if DiceManager:
				var dice = DiceManager.create_skill_dice(skill_dice_id, null, Vector3.ZERO, false)
				if dice:
					skill_dices.append(dice)
					dice.visible = false
					if dice.has_method("set_freeze"):
						dice.set_freeze(true)
					elif "freeze" in dice:
						dice.freeze = true
					dice.gravity_scale = 0.0
					print("  - 生成技能骰子（静态配置）：", skill_dice_id, ", dice=", dice)
			else:
				print("  - 错误：DiceManager 不可用")

# ============================================================================
# 备用方案方法（当 DiceManager 不可用时使用）
# ============================================================================

## 备用方案：创建角色骰子
func _create_character_dice_fallback(character: BaseCharacter, side: String, sandbox: Node, position: Vector3):
	var dice_scene = load("res://scenes/dice_6.tscn")
	if not dice_scene:
		return

	var dice = dice_scene.instantiate()
	if not dice:
		return

	dice.dice_type = "character"
	dice.skip_skill_trigger = true

	# 应用角色贴图
	var texture_config = {}
	var hero_id = character.hero_id
	var hero_texture_states = character.hero_textures

	for i in range(6):
		if i < hero_texture_states.size():
			var texture_state = hero_texture_states[i]
			texture_config[i] = "res://textures/hero/hero_" + str(hero_id) + "_" + texture_state + ".png"
		else:
			texture_config[i] = "res://textures/hero/hero_" + str(hero_id) + "_idle.png"

	if dice.has_method("set_dice_face_config"):
		dice.set_dice_face_config(texture_config, {})

	dice.position = position
	sandbox.add_child(dice)
	character.character_dice = dice
	print("【BattleManager】【备用方案】角色骰子已创建：", character.name)


## 备用方案：创建技能骰子
func _create_skill_dice_fallback(skill_dice_id: String) -> RigidBody3D:
	var dice_scene = load("res://scenes/dice_6.tscn")
	if not dice_scene:
		return null

	var dice = dice_scene.instantiate()
	if not dice:
		return null

	dice.dice_type = "skill"

	# 从 SkillDices.json 读取配置
	var reader = DiceCSVReader.new()
	var dice_config = reader.get_skill_dice_config(skill_dice_id)
	var skill_ids = dice_config.get("skill_ids", [])

	# 构建贴图配置
	var texture_config = {}
	for i in range(6):
		if i < skill_ids.size():
			var skill_id = skill_ids[i]
			var skill_data = SkillManager.get_skill(skill_id)
			if not skill_data.is_empty():
				texture_config[i] = "res://textures/skill/skill_" + skill_id + ".png"
			else:
				texture_config[i] = ""
		else:
			texture_config[i] = ""

	var value_config = {}
	for i in range(6):
		value_config[i] = i + 1

	if dice.has_method("set_dice_face_config"):
		dice.set_dice_face_config(texture_config, value_config)

	# 设置为悬浮状态
	if dice.has_method("set_freeze"):
		dice.set_freeze(true)
	dice.gravity_scale = 0.0
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO

	return dice
