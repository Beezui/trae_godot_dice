extends Node
## 骰子管理器 (Autoload 单例)
## 统一负责所有类型骰子的创建和管理
## 提供统一的创建接口，简化骰子创建流程
## 注意：通过 DiceManager 全局变量访问，不要使用 class_name

## 单例实例
static var _instance = null

## 骰子场景路径
const DICE_6_SCENE_PATH = "res://scenes/dice_6.tscn"
const ATTR_DICE_SCENE_PATH = "res://scenes/attr_dice.tscn"

## 数据读取器
var dice_csv_reader: RefCounted
var skill_reader: RefCounted
var hero_reader: RefCounted
var hero_data: Dictionary = {}


func _ready():
	# 初始化骰子管理器
	_instance = self
	print("【DiceManager】骰子管理器已就绪")

	# 初始化数据读取器
	dice_csv_reader = preload("res://scripts/dice_csv_reader.gd").new()
	skill_reader = preload("res://scripts/skill_csv_reader.gd").new()
	hero_reader = preload("res://scripts/hero_csv_reader.gd").new()
	hero_data = hero_reader.get_all_heroes()


## 获取单例实例
static func get_instance():
	return _instance


# ============================================================================
# 角色骰子创建
# ============================================================================

## 创建角色骰子
## @param character 角色实例 (BaseCharacter)
## @param parent 父节点（通常是场景的 Sandbox）
## @param position 位置 (可选，默认 Vector3.ZERO)
## @return RigidBody3D 角色骰子实例
func create_character_dice(character: BaseCharacter, parent: Node, position: Vector3 = Vector3.ZERO) -> RigidBody3D:
	if not character:
		push_error("【DiceManager】角色不能为空")
		return null

	if not parent:
		push_error("【DiceManager】父节点不能为空")
		return null

	var dice_scene = load(DICE_6_SCENE_PATH)
	if not dice_scene:
		push_error("【DiceManager】无法加载骰子场景")
		return null

	var dice = dice_scene.instantiate()
	if not dice:
		push_error("【DiceManager】无法实例化骰子场景")
		return null

	# 设置骰子类型
	dice.dice_type = "character"
	dice.skip_skill_trigger = true

	# 应用角色贴图：使用 hero.json 中的 hero_texture 字段
	var texture_config = _build_character_texture_config(character)

	if dice.has_method("set_dice_face_config"):
		dice.set_dice_face_config(texture_config, {})

	# 设置位置并添加到场景
	dice.position = position
	parent.add_child(dice)

	# 存储到角色
	character.character_dice = dice

	# 设置骰子与角色的关联（用于血条更新）
	if dice.has_method("set_character"):
		dice.set_character(character)

	# 自动应用角色骰子缩放（从 CharacterManager 获取配置）
	# 如果角色有特殊缩放配置，使用它；否则使用默认缩放 1.5
	var dice_scale = character.get_dice_scale() if character.has_method("get_dice_scale") else Vector3(1.5, 1.5, 1.5)

	# 使用骰子自身的 set_dice_scale 方法（优先）或通过 BaseCharacter 设置
	if dice.has_method("set_dice_scale"):
		dice.set_dice_scale(dice_scale)
		print("【DiceManager】使用 dice.set_dice_scale() 设置缩放：", dice_scale)
	elif dice.has_method("set_character_dice_scale"):
		# 备用方案：通过 BaseCharacter 的方法设置（已废弃，保留兼容性）
		dice.set_character_dice_scale(dice_scale)
		print("【DiceManager】使用 dice.set_character_dice_scale() 设置缩放：", dice_scale)

	print("【DiceManager】角色骰子已创建：", character.name, " 位置：", position, " 缩放：", dice_scale)
	return dice


## 构建角色骰子贴图配置
## @param character 角色实例
## @return Dictionary 贴图配置字典
func _build_character_texture_config(character: BaseCharacter) -> Dictionary:
	var texture_config = {}
	var hero_id = character.hero_id
	var hero_texture_states = character.hero_textures

	for i in range(6):
		if i < hero_texture_states.size():
			var texture_state = hero_texture_states[i]
			var texture_path = "res://textures/hero/hero_" + str(hero_id) + "_" + texture_state + ".png"
			texture_config[i] = texture_path
		else:
			# 默认使用 idle 状态
			texture_config[i] = "res://textures/hero/hero_" + str(hero_id) + "_idle.png"

	return texture_config


# ============================================================================
# 技能骰子创建
# ============================================================================

## 创建技能骰子
## @param skill_dice_id 技能骰子 ID (如 "4001")
## @param parent 父节点（通常是场景的 Sandbox，传 null 则不添加到场景）
## @param position 位置 (可选，默认 Vector3.ZERO)
## @param add_to_scene 是否添加到场景 (默认 true，parent 为 null 时强制为 false)
## @return RigidBody3D 技能骰子实例
func create_skill_dice(skill_dice_id: String, parent: Node, position: Vector3 = Vector3.ZERO, add_to_scene: bool = true) -> RigidBody3D:
	if not skill_dice_id:
		push_error("【DiceManager】技能骰子 ID 不能为空")
		return null

	# 从 SkillDices.json 读取配置
	var dice_config = dice_csv_reader.get_skill_dice_config(skill_dice_id)
	if dice_config.is_empty():
		push_error("【DiceManager】未找到技能骰子配置：", skill_dice_id)
		return null

	# 加载技能骰子场景
	var dice_scene = load(DICE_6_SCENE_PATH)
	if not dice_scene:
		push_error("【DiceManager】无法加载骰子场景")
		return null

	var dice = dice_scene.instantiate()
	if not dice:
		push_error("【DiceManager】无法实例化骰子场景")
		return null

	# 设置骰子类型
	dice.dice_type = "skill"

	# 存储技能骰子 ID 到元数据，方便后续获取配置
	dice.set_meta("skill_dice_id", skill_dice_id)

	# 构建贴图配置和值配置
	var texture_config = _build_skill_texture_config(dice_config)
	var value_config = _build_skill_value_config()

	if dice.has_method("set_dice_face_config"):
		dice.set_dice_face_config(texture_config, value_config)

	# 设置位置
	dice.position = position

	# 根据参数决定是否添加到场景
	if add_to_scene and parent:
		parent.add_child(dice)
		print("【DiceManager】技能骰子已添加到场景：", skill_dice_id)
	else:
		# 不添加到场景，仅返回实例
		print("【DiceManager】技能骰子已创建（未添加到场景）：", skill_dice_id)

	# 初始状态设置为悬浮
	if dice.has_method("set_freeze"):
		dice.set_freeze(true)
	elif "freeze" in dice:
		dice.freeze = true

	dice.gravity_scale = 0.0
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO

	return dice


## 构建技能骰子贴图配置
## @param dice_config 技能骰子配置（来自 SkillDices.json）
## @return Dictionary 贴图配置字典
func _build_skill_texture_config(dice_config: Dictionary) -> Dictionary:
	var texture_config = {}
	var skill_ids = dice_config.get("skill_ids", [])

	for i in range(6):
		if i < skill_ids.size():
			var skill_id = skill_ids[i]
			if skill_id and skill_id != "0":
				var skill_data = skill_reader.get_skill(skill_id)
				if skill_data and skill_data.has("icon"):
					texture_config[i] = "res://textures/skill/skill_" + skill_data["icon"] + ".png"
				else:
					texture_config[i] = ""
			else:
				texture_config[i] = ""
		else:
			texture_config[i] = ""

	return texture_config


## 构建技能骰子值配置
## @return Dictionary 值配置字典（面索引 0-5 对应骰子点数 1-6）
func _build_skill_value_config() -> Dictionary:
	var value_config = {}
	for i in range(6):
		value_config[i] = i + 1  # 1-6
	return value_config


## 批量创建技能骰子
## @param skill_dice_ids 技能骰子 ID 数组
## @param parent 父节点
## @param positions 位置数组（可选，如果为空则使用默认位置）
## @return Array<RigidBody3D> 创建的技能骰子数组
func create_skill_dices(skill_dice_ids: Array, parent: Node, positions: Array = []) -> Array:
	var skill_dices = []

	for i in range(skill_dice_ids.size()):
		var skill_dice_id = skill_dice_ids[i]
		var position = positions[i] if i < positions.size() else Vector3.ZERO
		var dice = create_skill_dice(skill_dice_id, parent, position)
		if dice:
			skill_dices.append(dice)

	return skill_dices


# ============================================================================
# 属性骰子创建
# ============================================================================

## 创建属性骰子
## @param hero_id 英雄 ID
## @param attr_type 属性类型 ("str"/"agi"/"int")
## @param parent 父节点（通常是场景的 Sandbox）
## @param position 位置 (可选，默认 Vector3.ZERO)
## @return RigidBody3D 属性骰子实例
func create_attribute_dice(hero_id: int, attr_type: String, parent: Node, position: Vector3 = Vector3.ZERO) -> RigidBody3D:
	if not hero_data.has(str(hero_id)):
		push_error("【DiceManager】未找到英雄 ID: ", hero_id)
		return null

	if not parent:
		push_error("【DiceManager】父节点不能为空")
		return null

	var hero_info = hero_data[str(hero_id)]

	# 获取属性值
	var hero_attributes = {
		"attr_str": hero_info.get("attr_str", []),
		"attr_agi": hero_info.get("attr_agi", []),
		"attr_int": hero_info.get("attr_int", [])
	}

	# 获取贴图
	var hero_textures = _parse_array(hero_info.get("texture", []))

	# 创建属性骰子实例
	var attr_dice_scene = load(ATTR_DICE_SCENE_PATH)
	if not attr_dice_scene:
		push_error("【DiceManager】无法加载属性骰子场景")
		return null

	var attr_dice = attr_dice_scene.instantiate()
	if not attr_dice:
		push_error("【DiceManager】无法实例化属性骰子场景")
		return null

	# 设置属性骰子参数
	attr_dice.attr_type = attr_type
	attr_dice.hero_id = hero_id
	attr_dice.update_attributes(hero_attributes, hero_textures)

	# 设置位置并添加到场景
	attr_dice.position = position
	parent.add_child(attr_dice)

	print("【DiceManager】属性骰子已创建：hero=", hero_id, " attr=", attr_type, " 位置：", position)
	return attr_dice


## 创建角色的所有属性骰子
## @param hero_id 英雄 ID
## @param parent 父节点
## @param positions 位置数组（可选，按顺序对应 str/agi/int）
## @return Dictionary 创建的属性骰子字典 {"str": dice, "agi": dice, "int": dice}
func create_all_attribute_dices(hero_id: int, parent: Node, positions: Array = []) -> Dictionary:
	var attribute_dices = {}
	var attr_types = ["str", "agi", "int"]

	for i in range(3):
		var attr_type = attr_types[i]
		var position = positions[i] if i < positions.size() else Vector3.ZERO
		var dice = create_attribute_dice(hero_id, attr_type, parent, position)
		if dice:
			attribute_dices[attr_type] = dice

	return attribute_dices


## 解析数组数据（兼容字符串和数组格式）
## @param data 可能是字符串数组或分号分隔的字符串
## @return Array 字符串数组
func _parse_array(data) -> Array:
	if data is Array:
		return data
	elif data is String:
		if data.contains(";"):
			return data.split(";")
		else:
			return [data]
	else:
		return []


# ============================================================================
# 命运骰子创建（预留）
# ============================================================================

## 创建命运骰子
## @param destiny_type 命运类型 (1=战斗，2=奇遇，3=交易，4=奖励，5=精英战斗)
## @param parent 父节点
## @param position 位置
## @return RigidBody3D 命运骰子实例
func create_destiny_dice(destiny_type: int, parent: Node, position: Vector3 = Vector3.ZERO) -> RigidBody3D:
	# TODO: 实现命运骰子创建
	# 命运骰子可能需要特殊的贴图处理
	push_warning("【DiceManager】命运骰子创建尚未实现")
	return null


# ============================================================================
# 工具方法
# ============================================================================

## 刷新英雄数据
func refresh_hero_data():
	hero_data = hero_reader.get_all_heroes()
	print("【DiceManager】英雄数据已刷新")


## 获取英雄属性值
## @param hero_id 英雄 ID
## @param attr_type 属性类型
## @return Array 属性值数组
func get_hero_attributes(hero_id: int, attr_type: String) -> Array:
	if not hero_data.has(str(hero_id)):
		return []

	var hero_info = hero_data[str(hero_id)]
	match attr_type:
		"str": return hero_info.get("attr_str", [])
		"agi": return hero_info.get("attr_agi", [])
		"int": return hero_info.get("attr_int", [])
		_: return []


## 获取英雄贴图
## @param hero_id 英雄 ID
## @return Array 贴图数组
func get_hero_textures(hero_id: int) -> Array:
	if not hero_data.has(str(hero_id)):
		return []

	var hero_info = hero_data[str(hero_id)]
	return _parse_array(hero_info.get("texture", []))
