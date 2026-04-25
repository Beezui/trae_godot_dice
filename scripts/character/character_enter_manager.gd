extends Node
## 角色入场管理器 (Autoload 单例)
## 负责处理所有场景中角色骰子的投掷入场逻辑
## 确保角色骰子在所有场景中都以统一的投掷方式入场

## 信号：角色入场开始
signal on_character_enter_started(character, side: String)
## 信号：角色入场完成
signal on_character_enter_completed(character, side: String)
## 信号：所有角色入场完成
signal on_all_characters_enter_completed()

## 投掷配置
var throw_config: Dictionary = {
	"player_start_z": 6.0,       # 玩家起始 Z 位置（南侧）
	"enemy_start_z": -6.0,       # 敌方的起始 Z 位置（北侧）
	"start_height": 4.0,         # 起始高度
	"throw_force": 8.0,          # 投掷力度
	"throw_direction_y": -0.3,   # 投掷方向 Y 分量
	"stable_wait_time": 2.0,     # 等待骰子稳定时间（秒）
	"lock_delay": 0.5,           # 锁定前的延迟时间（秒）
}


func _ready():
	print("【CharacterEnterManager】角色入场管理器已就绪")


## 获取单例实例
static func get_instance():
	return Engine.get_main_loop().root.get_node_or_null("CharacterEnterManager")


## 玩家角色投掷入场（单个）
## @param character 角色实例
## @param sandbox 场景 Sandbox 节点
## @param x_position X 轴位置（用于排列）
## @return Dictionary 入场结果 {success: bool, dice: RigidBody3D}
func player_enter(character, sandbox: Node, x_position: float = 0.0) -> Dictionary:
	return await _character_enter(character, sandbox, x_position, "player")


## 敌方角色投掷入场（单个）
## @param character 角色实例
## @param sandbox 场景 Sandbox 节点
## @param x_position X 轴位置（用于排列）
## @return Dictionary 入场结果 {success: bool, dice: RigidBody3D}
func enemy_enter(character, sandbox: Node, x_position: float = 0.0) -> Dictionary:
	return await _character_enter(character, sandbox, x_position, "enemy")


## 批量玩家角色投掷入场
## @param characters 角色数组
## @param sandbox 场景 Sandbox 节点
## @return Array 入场结果数组
func player_batch_enter(characters: Array, sandbox: Node) -> Array:
	return await _batch_enter(characters, sandbox, "player")


## 批量敌方角色投掷入场
## @param characters 角色数组
## @param sandbox 场景 Sandbox 节点
## @return Array 入场结果数组
func enemy_batch_enter(characters: Array, sandbox: Node) -> Array:
	return await _batch_enter(characters, sandbox, "enemy")


## 内部方法：角色投掷入场
## @param character 角色实例
## @param sandbox 场景 Sandbox 节点
## @param x_position X 轴位置
## @param side "player" 或 "enemy"
## @return Dictionary 入场结果 {success: bool, dice: RigidBody3D}
func _character_enter(character, sandbox: Node, x_position: float, side: String) -> Dictionary:
	print("【CharacterEnterManager】", side, "角色 ", character.name, " 入场")
	
	on_character_enter_started.emit(character, side)
	
	# 1. 创建角色骰子（如果还没有）
	if not character.character_dice:
		_create_character_dice(character, sandbox)
	
	if not character.character_dice or not is_instance_valid(character.character_dice):
		push_error("【CharacterEnterManager】角色骰子创建失败")
		return {"success": false, "dice": null}
	
	var dice = character.character_dice
	
	# 2. 计算起始位置
	var start_z = throw_config["player_start_z"] if side == "player" else throw_config["enemy_start_z"]
	var start_pos = Vector3(x_position, throw_config["start_height"], start_z)
	dice.position = start_pos
	
	# 3. 启用重力，解除悬浮状态
	dice.gravity_scale = 1.0
	_unlock_dice(dice)
	
	# 4. 投掷骰子（水平方向随机偏转，整体朝向对面半场）
	var horizontal_bias = randf_range(-0.4, 0.4)
	var throw_direction = Vector3(
		horizontal_bias,
		throw_config["throw_direction_y"],
		-1.0 if side == "player" else 1.0
	).normalized()
	var force = throw_direction * throw_config["throw_force"]

	var angular_force = Vector3(
		randf_range(-3, 3),
		randf_range(-3, 3),
		randf_range(-3, 3)
	)

	if dice.has_method("roll"):
		dice.roll(force, angular_force)
		print("【CharacterEnterManager】", side, "角色骰子投掷，位置=", dice.position, ", 方向=", throw_direction)

	# 5. 等待骰子自然停止（带安全超时）
	# 骰子停止后会自动调用 lock_character_dice()（由 dice_6.gd 内部处理）
	# 使用轮询方式等待，确保有安全超时机制
	if dice.has_method("get_is_rolling"):
		var max_wait = 10.0
		var elapsed = 0.0
		var check_interval = 0.2  # 每 0.2 秒检查一次
		var is_stopped = false

		while elapsed < max_wait:
			if not dice.get_is_rolling():
				is_stopped = true
				break
			await get_tree().create_timer(check_interval).timeout
			elapsed += check_interval

		if is_stopped:
			print("【CharacterEnterManager】角色骰子已自然停止，位置=", dice.position)
		else:
			# 超时仍未停止
			push_warning("【CharacterEnterManager】角色骰子停止超时（10秒），强制锁定，位置=", dice.position)
			_lock_dice(dice)
	
	on_character_enter_completed.emit(character, side)
	
	return {"success": true, "dice": dice}


## 内部方法：批量角色投掷入场
## @param characters 角色数组
## @param sandbox 场景 Sandbox 节点
## @param side "player" 或 "enemy"
## @return Array 入场结果数组
func _batch_enter(characters: Array, sandbox: Node, side: String) -> Array:
	var results = []
	
	# 玩家角色从中间向两侧排列，敌方角色随机位置
	var player_start_x = 0.0
	var enemy_positions = [-6.0, -2.0, 2.0, 6.0]
	
	for character in characters:
		var x_position: float
		
		if side == "enemy":
			# 敌方随机位置
			var random_index = randi() % enemy_positions.size()
			x_position = enemy_positions[random_index]
			enemy_positions.remove_at(random_index)
			if enemy_positions.is_empty():
				enemy_positions = [-6.0, -2.0, 2.0, 6.0]  # 重置位置池
		else:
			# 玩家从中间向两侧排列
			var index = characters.find(character)
			x_position = player_start_x + index * 2.0 * (1 if index % 2 == 0 else -1)
			if index > 0:
				x_position = x_position * (-1 if index % 2 == 0 else 1)
		
		var result = await _character_enter(character, sandbox, x_position, side)
		results.append(result)
		
		# 每个角色之间有短暂间隔
		await get_tree().create_timer(0.5).timeout
	
	await get_tree().create_timer(1.0).timeout
	
	on_all_characters_enter_completed.emit()
	
	return results


## 内部方法：创建角色骰子
## @param character 角色实例
## @param sandbox 场景 Sandbox 节点
func _create_character_dice(character, sandbox: Node):
	if DiceManager:
		# 使用 DiceManager 统一创建（会自动应用缩放配置）
		character.character_dice = DiceManager.create_character_dice(character, sandbox, Vector3.ZERO)
		print("【CharacterEnterManager】使用 DiceManager 创建角色骰子")
	else:
		# 备用方案
		_create_character_dice_fallback(character, sandbox)


## 备用方案：创建角色骰子
## @param character 角色实例
## @param sandbox 场景 Sandbox 节点
func _create_character_dice_fallback(character, sandbox: Node):
	var dice_scene = load("res://scenes/dice_6.tscn")
	if not dice_scene:
		push_error("【CharacterEnterManager】无法加载骰子场景")
		return
	
	var dice = dice_scene.instantiate()
	if not dice:
		push_error("【CharacterEnterManager】无法实例化骰子场景")
		return
	
	# 设置骰子类型
	dice.dice_type = "character"
	dice.skip_skill_trigger = true
	
	# 应用角色贴图
	var texture_config = _build_character_texture_config(character)
	
	if dice.has_method("set_dice_face_config"):
		dice.set_dice_face_config(texture_config, {})
	
	# 设置初始位置（临时，会在 _character_enter 中重新设置）
	dice.position = Vector3.ZERO
	sandbox.add_child(dice)
	
	# 存储到角色
	character.character_dice = dice
	
	# 设置骰子与角色的关联
	if dice.has_method("set_character"):
		dice.set_character(character)
	
	# 应用缩放配置
	var dice_scale = character.get_dice_scale() if character.has_method("get_dice_scale") else Vector3(1.5, 1.5, 1.5)
	if dice.has_method("set_dice_scale"):
		dice.set_dice_scale(dice_scale)
	
	print("【CharacterEnterManager】【备用方案】角色骰子已创建：", character.name)


## 构建角色骰子贴图配置
## @param character 角色实例
## @return Dictionary 贴图配置字典
func _build_character_texture_config(character) -> Dictionary:
	var texture_config = {}
	var hero_id = character.hero_id
	var hero_texture_states = character.hero_textures
	
	for i in range(6):
		if i < hero_texture_states.size():
			var texture_state = hero_texture_states[i]
			texture_config[i] = "res://textures/hero/hero_" + str(hero_id) + "_" + texture_state + ".png"
		else:
			texture_config[i] = "res://textures/hero/hero_" + str(hero_id) + "_idle.png"
	
	return texture_config


## 解锁骰子（解除悬浮状态）
## @param dice 骰子实例
func _unlock_dice(dice: RigidBody3D):
	if dice.has_method("set_freeze"):
		dice.set_freeze(false)
	elif "freeze" in dice:
		dice.freeze = false
	
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.sleeping = false


## 锁定骰子（停止后固定位置）
## @param dice 骰子实例
func _lock_dice(dice: RigidBody3D):
	if dice.has_method("lock_character_dice"):
		dice.lock_character_dice()
	else:
		# 手动锁定
		dice.gravity_scale = 0.0
		dice.linear_velocity = Vector3.ZERO
		dice.angular_velocity = Vector3.ZERO
		dice.sleeping = true
		# 保持碰撞，通过高质量和阻尼减少碰撞影响
		dice.mass = 100.0
		dice.linear_damp = 10.0
		dice.angular_damp = 10.0
	
	print("【CharacterEnterManager】角色骰子已锁定")


## 配置投掷参数
## @param config 配置字典
func configure_throw(config: Dictionary):
	for key in config:
		throw_config[key] = config[key]
	print("【CharacterEnterManager】投掷配置已更新：", throw_config)


## 获取当前投掷配置
## @return Dictionary 配置字典
func get_throw_config() -> Dictionary:
	return throw_config.duplicate()


## 清理 Sandbox 中的角色骰子
## @param sandbox Sandbox 节点
## @param dice_type 骰子类型（"character"、"skill"、"attribute"、"discount"，清空则清理所有）
## @param side 阵营（"player"、"enemy"，清空则清理所有阵营）
## 清理 Sandbox 中的角色骰子
func cleanup_sandbox(sandbox: Node, dice_type: String = "", side: String = ""):
	if not sandbox or not is_instance_valid(sandbox):
		return

	var dice_to_clean = []
	var health_bars_to_clean = []

	# 先列出所有 Sandbox 子节点（调试用）
	print("【CharacterEnterManager】Sandbox 子节点列表（", sandbox.get_children().size(), " 个）:")
	for child in sandbox.get_children():
		var dtype = ""
		if child is RigidBody3D:
			dtype = str(child.get("dice_type")) if child.get("dice_type") != null else "null"
		print("  - ", child.name, " (", child.get_class(), ", dice_type=", dtype, ")")

	# 加载血条脚本用于识别
	var hb_script = null
	if ResourceLoader.exists("res://scripts/ui/dice_health_bar_2d.gd"):
		hb_script = load("res://scripts/ui/dice_health_bar_2d.gd")

	# 收集所有骰子和血条
	for child in sandbox.get_children():
		if not is_instance_valid(child):
			continue

		# 识别血条节点（通过脚本匹配，比节点名更可靠）
		if hb_script and child.get_script() == hb_script:
			health_bars_to_clean.append(child)
			continue

		# 识别骰子：RigidBody3D + 有 dice_type @export 变量
		if child is RigidBody3D:
			var dtype = child.get("dice_type")
			var dtype_str = str(dtype) if dtype != null else ""
			if dice_type.is_empty() or dtype_str == dice_type:
				if side.is_empty() or _get_property_safe(child, "character_side", "") == side:
					dice_to_clean.append(child)

	# 清理骰子（先停止 timer）
	for dice in dice_to_clean:
		if is_instance_valid(dice):
			_stop_dice_timers(dice)
			dice.queue_free()

	# 清理所有血条
	for hb in health_bars_to_clean:
		if is_instance_valid(hb):
			hb.queue_free()

	print("【CharacterEnterManager】Sandbox 清理完成，清理了 ", dice_to_clean.size(), " 个骰子，", health_bars_to_clean.size(), " 个血条")


## 停止骰子所有 timer（防止清理后残留回调创建血条）
func _stop_dice_timers(dice):
	if not dice:
		return
	# 停止所有子计时器并断开信号
	for child in dice.get_children():
		if child is Timer:
			child.stop()
			# 断开 timer 的所有信号连接
			for conn in child.timeout.get_connections():
				child.timeout.disconnect(conn.callable)
	# 标记为不投掷状态
	dice.set("is_rolling", false)
	dice.set("skip_skill_trigger", true)


## 清理所有角色骰子（玩家和敌人）
func cleanup_all_characters(sandbox: Node):
	cleanup_sandbox(sandbox, "character", "")


## 清理特定阵营的角色骰子
func cleanup_side_characters(sandbox: Node, side: String):
	cleanup_sandbox(sandbox, "character", side)


## 安全获取节点属性值（兼容所有 Godot 对象）
func _get_property_safe(obj: Object, property_name: String, default_value):
	# 优先尝试方法调用（如 get_dice_type()）
	var method_name = "get_" + property_name
	if obj.has_method(method_name):
		return obj.call(method_name)
	# 回退：直接通过 get() 获取 @export 变量
	return obj.get(property_name) if _has_property(obj, property_name) else default_value


## 检查 Godot 对象是否存在指定属性
func _has_property(obj: Object, property_name: String) -> bool:
	for prop in obj.get_property_list():
		if prop.name == property_name:
			return true
	return false
