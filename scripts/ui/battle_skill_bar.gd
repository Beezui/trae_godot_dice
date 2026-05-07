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

## 3D 骰子缓存
var skill_dice_viewports = {}   # { index: SubViewport }
var skill_dice_sv_containers = {}  # { index: SubViewportContainer }
var skill_dice_containers = {}  # { index: Control } 用于缩放（VBoxContainer）
var skill_dice_content_containers = {}  # { index: VBoxContainer } 内容容器（用于缩放）
var skill_dice_labels = {}  # { index: Label } 技能名称标签（用于调整字体）

## 选中状态
var selected_skill_index: int = -1  # 当前选中的技能索引

## 当前玩家角色列表
var player_characters: Array[BaseCharacter] = []
## 技能骰子列表（隐藏存储，不显示在场景中）
var skill_dices: Array = []
## 物品骰子列表（预留）
var item_dices: Array = []
## 属性骰子列表（str, agi, int）
var attribute_dices: Array = []

## UI 节点引用
@onready var skill_container: HBoxContainer = $SkillContainer
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

	# 创建技能按钮（3D 骰子列表形式）
	var idx = 0
	for skill_dice in skill_dices:
		_create_skill_button(skill_dice, idx)
		idx += 1

	_update_turn_label()
	_update_mp_label()


## 属性骰子初始位置（用于复位）
var attribute_dice_initial_positions: Dictionary = {}
## 原始位置存储（用于震动效果）
var original_positions: Dictionary = {}


## 获取骰子容器（Sandbox 或 GameManager）
func _get_dice_container(scene: Node) -> Node:
	if scene.has_node("Sandbox"):
		return scene.get_node("Sandbox")
	if scene.has_node("GameManager"):
		return scene.get_node("GameManager")
	return null


## 查找战斗场景（统一方法）
func _find_battle_scene() -> Node:
	"""从 LevelStage 或场景树获取当前战斗场景"""
	var tree = Engine.get_main_loop()
	if not tree or not tree.root:
		return null

	# 1. 优先从 LevelStage 获取当前加载的场景（关卡转换后的场景）
	var level_stage = LevelStage.get_instance() if tree.root.has_node("LevelStage") else null
	if level_stage and level_stage.has_method("get_current_scene"):
		var current_scene = level_stage.get_current_scene()
		if current_scene and is_instance_valid(current_scene):
			return current_scene

	# 2. 回退方案：从根节点查找 battle 组或 Sandbox 节点
	for i in range(tree.root.get_child_count()):
		var child = tree.root.get_child(i)
		if child.is_in_group("battle") or child.has_node("Sandbox"):
			return child

	return null


## 查找属性骰子
func _find_attribute_dices():
	var battle_scene = _find_battle_scene()
	if not battle_scene:
		print("【BattleSkillBar】找不到战斗场景")
		return

	# 查找属性骰子（优先 Sandbox，备用 GameManager）
	var container = _get_dice_container(battle_scene)
	if not container:
		print("【BattleSkillBar】找不到骰子容器（Sandbox/GameManager）")
		return

	for child in container.get_children():
		if child.has_method("get_attribute_value") or child.name.contains("Attr"):
			attribute_dices.append(child)
			attribute_dice_initial_positions[child] = child.position
			print("【BattleSkillBar】找到属性骰子：", child.name, ", 初始位置：", child.position)


## 清空按钮
func _clear_buttons():
	if skill_container:
		for child in skill_container.get_children():
			child.queue_free()

	# 清理 3D 视口
	for vp in skill_dice_viewports.values():
		if vp and is_instance_valid(vp):
			vp.queue_free()
	skill_dice_viewports.clear()
	for sv in skill_dice_sv_containers.values():
		if sv and is_instance_valid(sv):
			sv.queue_free()
	skill_dice_sv_containers.clear()
	skill_dice_containers.clear()
	skill_dice_content_containers.clear()
	skill_dice_labels.clear()


## 创建技能按钮（3D 骰子预览）— 水平排列
func _create_skill_button(skill_dice, index: int):
	if not skill_dice:
		print("【BattleSkillBar】技能骰子为空，跳过创建")
		return

	print("【BattleSkillBar】创建技能按钮，skill_dice=", skill_dice)

	# 容器（VBox：技能名 + 3D 骰子）
	var container = VBoxContainer.new()
	container.name = "SkillButton_%d" % index
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 0)  # 缩小间距
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 创建内容容器（包裹 label 和 sv_container，用于缩放）
	var content_container = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(content_container)

	# 获取技能名称
	var skill_name = _get_skill_name_for_dice(skill_dice)
	var name_label = Label.new()
	name_label.text = skill_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 缩放时保持清晰
	content_container.add_child(name_label)  # 添加到 content_container

	# 保存 label 引用以便后续调整字体
	skill_dice_labels[index] = name_label

	# 获取技能图标路径
	var icon_path = _get_skill_icon_path_for_dice(skill_dice)

	# 创建 SubViewport 渲染 3D 骰子
	var viewport = SubViewport.new()
	viewport.name = "DiceViewport"
	viewport.size = Vector2(480, 300)  # 高分辨率渲染
	viewport.transparent_bg = true
	viewport.canvas_item_default_texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS

	_create_dice_3d_scene(viewport, icon_path)

	# SubViewportContainer 包裹
	var sv_container = SubViewportContainer.new()
	sv_container.name = "DiceSubViewportContainer"
	sv_container.custom_minimum_size = Vector2(160, 100)  # UI 显示尺寸（参考技能装配 UI）
	sv_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sv_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sv_container.stretch = true
	sv_container.mouse_filter = Control.MOUSE_FILTER_STOP
	sv_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 缩放时保持清晰
	sv_container.add_child(viewport)

	content_container.add_child(sv_container)  # 添加到 content_container

	# 保存引用
	skill_dice_containers[index] = container
	skill_dice_sv_containers[index] = sv_container
	skill_dice_viewports[index] = viewport
	skill_dice_content_containers[index] = content_container  # 保存 content_container 引用

	# 绑定点击事件
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_skill_button_pressed(skill_dice, index)
	)
	sv_container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_skill_button_pressed(skill_dice, index)
	)

	# 存储技能骰子引用
	container.set_meta("skill_dice", skill_dice)
	container.set_meta("index", index)

	skill_container.add_child(container)
	print("【BattleSkillBar】创建技能按钮完成，容器子节点数=", skill_container.get_child_count())


## 创建 3D 骰子场景（SubViewport 内）
func _create_dice_3d_scene(viewport: SubViewport, icon_path: String):
	var root = Node3D.new()
	viewport.add_child(root)

	# 独立世界空间
	var world = World3D.new()
	viewport.world_3d = world

	# 相机 — 右上方向下看（与 skill_equip_ui_new 一致）
	var camera = Camera3D.new()
	camera.position = Vector3(5.95, 0.7, 2.5)
	camera.rotation = Vector3(-0.4, 0, 0)
	camera.fov = 45.0
	camera.current = true
	root.add_child(camera)
	camera.look_at(Vector3(5.95, 0, 0))

	# 灯光
	var light1 = DirectionalLight3D.new()
	light1.position = Vector3(2, 2, 2)
	light1.rotation = Vector3(-0.5, -0.5, 0)
	root.add_child(light1)

	var light2 = DirectionalLight3D.new()
	light2.position = Vector3(-1, 1, -1)
	light2.rotation = Vector3(0.3, 0.3, 0)
	root.add_child(light2)

	# 创建骰子网格
	var mesh = _create_dice_array_mesh()

	# 为每个面创建材质
	var materials = []
	for i in range(6):
		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		material.metallic = 0.0
		if icon_path and FileAccess.file_exists(icon_path):
			material.albedo_texture = load(icon_path)
		else:
			material.albedo_color = Color(0.8, 0.8, 0.8, 1.0)
		materials.append(material)

	# MeshInstance3D
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(6.05, 0, 0)
	mesh_instance.rotation = Vector3(deg_to_rad(10), deg_to_rad(-30), 0)
	for i in range(6):
		mesh_instance.mesh.surface_set_material(i, materials[i])

	root.add_child(mesh_instance)


## 创建 6 面骰子网格
func _create_dice_array_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()

	var vertices = [
		Vector3(-0.5, -0.5, -0.5),
		Vector3(0.5, -0.5, -0.5),
		Vector3(0.5, 0.5, -0.5),
		Vector3(-0.5, 0.5, -0.5),
		Vector3(-0.5, -0.5, 0.5),
		Vector3(0.5, -0.5, 0.5),
		Vector3(0.5, 0.5, 0.5),
		Vector3(-0.5, 0.5, 0.5)
	]

	var faces = [
		[0, 1, 2, 3],
		[5, 4, 7, 6],
		[4, 0, 3, 7],
		[1, 5, 6, 2],
		[3, 2, 6, 7],
		[4, 5, 1, 0]
	]

	for i in range(6):
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		var surface_vertices = []
		for j in faces[i]:
			surface_vertices.append(vertices[j])
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(surface_vertices)

		var normals = []
		var normal = Vector3(0, 0, 0)
		match i:
			0: normal = Vector3(0, 0, -1)
			1: normal = Vector3(0, 0, 1)
			2: normal = Vector3(-1, 0, 0)
			3: normal = Vector3(1, 0, 0)
			4: normal = Vector3(0, 1, 0)
			5: normal = Vector3(0, -1, 0)
		for j in range(4):
			normals.append(normal)
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)

		var uvs = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)

		var indices = [0, 1, 2, 0, 2, 3]
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh


## 获取技能图标路径（从技能骰子的第一个技能 ID）
func _get_skill_icon_path_for_dice(skill_dice) -> String:
	var dice_id = skill_dice.get_meta("skill_dice_id") if skill_dice.has_meta("skill_dice_id") else ""
	if dice_id.is_empty():
		return ""

	var reader = DiceCSVReader.new()
	var dice_config = reader.get_skill_dice_config(dice_id)
	if not dice_config.is_empty():
		var skill_ids = dice_config.get("skill_ids", [])
		if skill_ids.size() > 0:
			var skill_id = skill_ids[0]
			var texture_path = "res://textures/skill/skill_" + skill_id + ".png"
			if ResourceLoader.exists(texture_path):
				return texture_path
	return ""


## 获取技能名称（用于显示在 3D 骰子上方）
func _get_skill_name_for_dice(skill_dice) -> String:
	var dice_id = skill_dice.get_meta("skill_dice_id") if skill_dice.has_meta("skill_dice_id") else ""
	if dice_id.is_empty():
		return "未知技能"

	var reader = DiceCSVReader.new()
	var dice_config = reader.get_skill_dice_config(dice_id)
	if not dice_config.is_empty():
		var skill_ids = dice_config.get("skill_ids", [])
		if skill_ids.size() > 0:
			var skill_reader = preload("res://scripts/skill_csv_reader.gd").new()
			var skill_data = skill_reader.get_skill(skill_ids[0])
			if skill_data and skill_data.has("name"):
				return skill_data["name"]
	return "未知技能"


func _on_skill_button_pressed(skill_dice, index: int):
	print("【BattleSkillBar】技能按钮被点击，index=", index)

	if not skill_dice:
		print("【BattleSkillBar】错误：skill_dice 为空")
		return

	# 检查是否正在释放技能期间
	if is_releasing_skill:
		print("【BattleSkillBar】技能释放中，忽略点击")
		_show_throw_hint("技能释放中...")
		return

	# 更新选中状态
	selected_skill_index = index
	_update_skill_selection_highlight()

	# 选择技能骰子（不立即添加到场景，只是记录选择）
	selected_skill_dice = skill_dice
	selected_character = _get_character_for_skill_dice(skill_dice)

	# 替换场景中的技能骰子（待投掷区域的绿色骰子）
	_replace_skill_dice_in_scene(skill_dice)

	# 显示投掷提示
	_show_throw_hint("按空格键投掷")

	# 禁用技能栏
	set_skill_bar_enabled(false)

	print("【BattleSkillBar】技能骰子已选择，准备投掷")


## 更新技能选中高亮（中间放大，两侧缩小）
func _update_skill_selection_highlight():
	for idx in skill_dice_content_containers:
		var content_container = skill_dice_content_containers[idx]
		var label = skill_dice_labels.get(idx)
		if not content_container or not is_instance_valid(content_container):
			continue

		if idx == selected_skill_index:
			# 选中：放大 1.5 倍
			content_container.pivot_offset = content_container.size / 2.0
			content_container.scale = Vector2(1.5, 1.5)
			# 同步放大字体，避免模糊
			if label and is_instance_valid(label):
				label.add_theme_font_size_override("font_size", 21)  # 14 * 1.5 = 21
		else:
			# 未选中：恢复原始尺寸
			content_container.pivot_offset = content_container.size / 2.0
			content_container.scale = Vector2(1.0, 1.0)
			# 恢复字体大小
			if label and is_instance_valid(label):
				label.add_theme_font_size_override("font_size", 14)


## 检查是否有足够 MP 投掷（1 点）
func _can_afford_throw(character: BaseCharacter) -> bool:
	if not character:
		return false
	# 临时设定：每次投掷消耗 1 点 MP
	return character.current_mp >= 1


## 替换场景中的技能骰子（待投掷区域的绿色骰子）
func _replace_skill_dice_in_scene(new_skill_dice):
	if not new_skill_dice:
		print("【BattleSkillBar】错误：new_skill_dice 为空，跳过")
		return

	var battle_scene = _find_battle_scene()
	if not battle_scene:
		print("【BattleSkillBar】找不到战斗场景")
		return

	var container = _get_dice_container(battle_scene)
	if not container:
		print("【BattleSkillBar】找不到骰子容器（Sandbox/GameManager）")
		return

	# 查找场景中已有的技能骰子并移除（排除同一骰子）
	var existing_skill_dice = _find_skill_dice_in_scene(container)
	if existing_skill_dice and existing_skill_dice != new_skill_dice:
		print("【BattleSkillBar】移除场景中的旧技能骰子: ", existing_skill_dice.name)
		if existing_skill_dice.has_method("set_freeze"):
			existing_skill_dice.set_freeze(false)
		container.remove_child(existing_skill_dice)
		existing_skill_dice.queue_free()

	# 设置新骰子为可见并添加到场景
	new_skill_dice.visible = true
	new_skill_dice.position = Vector3(-4.0, 8.0, 6.0)  # 与属性骰子同高度，横向排列在左侧

	# 设置为悬浮状态
	if new_skill_dice.has_method("set_freeze"):
		new_skill_dice.set_freeze(true)
	elif "freeze" in new_skill_dice:
		new_skill_dice.freeze = true
	new_skill_dice.gravity_scale = 0.0
	new_skill_dice.linear_velocity = Vector3.ZERO
	new_skill_dice.angular_velocity = Vector3.ZERO

	container.add_child(new_skill_dice)
	print("【BattleSkillBar】技能骰子已替换到场景")


## 查找场景中现有的技能骰子（待投掷区域）
func _find_skill_dice_in_scene(container: Node) -> Node:
	# 查找第一个技能骰子（通过 meta 判断）
	for child in container.get_children():
		if child.has_meta("skill_dice_id"):
			return child
	return null


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

	# 检查 MP 是否足够（1 点）
	if selected_character and not _can_afford_throw(selected_character):
		print("【BattleSkillBar】MP 不足，无法投掷")
		_show_throw_hint("MP 不足！")
		return

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

	# 获取战斗场景（3D 场景）来添加 Marker3D
	var battle_scene = _find_battle_scene()
	if battle_scene:
		battle_scene.add_child(caster_marker)
	else:
		get_tree().current_scene.add_child(caster_marker)

	var params = {
		"dice_results": dice_results,
		"scene": battle_scene if battle_scene else get_tree().current_scene,
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

	# 隐藏技能骰子（从场景移除，但保留在 skill_dices 数组中）
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
	selected_skill_index = -1

	# 重置技能释放状态，允许再次投掷
	is_releasing_skill = false

	# 恢复技能栏
	set_skill_bar_enabled(true)
	_hide_throw_hint()

	# 重置选中高亮
	_update_skill_selection_highlight()

	print("【BattleSkillBar】投掷完成，骰子已复位")


## 隐藏投掷提示
func _hide_throw_hint():
	if throw_hint_label:
		throw_hint_label.visible = false



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
	for idx in skill_dice_containers:
		var sv_container = skill_dice_sv_containers[idx]
		var container = skill_dice_containers[idx]
		if sv_container and is_instance_valid(sv_container):
			sv_container.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		# 同步禁用名称标签（半透明效果）
		var name_label = skill_dice_labels.get(idx)
		if name_label and is_instance_valid(name_label):
			name_label.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.4)

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
