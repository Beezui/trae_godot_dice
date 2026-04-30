extends Control
## 技能装配 UI - 新版
## 支持 3D 骰子展示、拖拽配置技能

# 信号
signal on_equip_confirmed  # 确认分配
signal on_ui_closed        # 关闭 UI

# UI 组件引用
var dice_list_container: VBoxContainer = null
var dice_info_label: Label = null
var effect_label: Label = null
var skill_grid_container: GridContainer = null
var selected_face_label: Label = null
var face_grid_container: VBoxContainer = null

# 骰子面插槽 (6 个)
var face_slots = []

# 状态
var selected_instance_id: int = -1  # 当前选中的骰子实例 ID
var selected_face_index: int = -1   # 当前选中的骰子面 (0-5)

# 缓存
var dice_buttons = {}      # { instance_id: Button }
var skill_buttons = {}     # { skill_id: Button }
var dice_viewports = {}    # { instance_id: SubViewport }


func _ready():
	# 节点引用
	dice_list_container = $MainContainer/LeftPanel/DiceListScroll/DiceListContainer as VBoxContainer
	if not dice_list_container:
		push_error("【技能穿戴 UI】dice_list_container 未找到！")
		print_tree()
		return

	dice_info_label = $MainContainer/CenterPanel/DiceInfoLabel as Label
	effect_label = $MainContainer/CenterPanel/EffectLabel as Label
	skill_grid_container = $MainContainer/RightPanel/SkillScrollContainer/SkillGridContainer as GridContainer
	selected_face_label = $MainContainer/RightPanel/SelectedFaceLabel as Label
	face_grid_container = $MainContainer/CenterPanel/FaceGridContainer as VBoxContainer

	_init_face_slots()
	_setup_ui()
	_load_data()


## 初始化骰子面插槽
func _init_face_slots():
	face_slots.clear()

	if not face_grid_container:
		push_error("【技能穿戴 UI】FaceGridContainer 未初始化")
		return

	for i in range(6):
		var slot_name = "FaceSlot_%d" % i
		var slot = null

		# 从 TopRow 或 BottomRow 查找
		if i < 3:
			slot = face_grid_container.get_node_or_null("TopRow/" + slot_name)
		else:
			slot = face_grid_container.get_node_or_null("BottomRow/" + slot_name)

		if slot:
			# 设置插槽背景色（绿色占位）
			slot.color = Color(0.2, 0.5, 0.2, 0.3)
			# 启用拖拽接收
			slot.set_drag_forwarding(Callable(_can_drop_data_fw), Callable(_get_drag_data_fw), Callable(_drop_data_fw))
			face_slots.append(slot)
		else:
			push_error("未找到插槽：%s" % slot_name)


## 初始化 UI
func _setup_ui():
	# ESC 关闭
	var hint_label = get_node_or_null("BottomBar/HintLabel")
	if hint_label:
		hint_label.text = "拖拽技能到绿色骰面 | 点击骰子查看 | ESC 关闭"


## 加载数据
func _load_data():
	if not PlayerData:
		push_error("【技能穿戴 UI】PlayerData 不可用")
		return

	_refresh_dice_list()
	_refresh_skill_list()


## 刷新骰子列表
func _refresh_dice_list():
	if not dice_list_container:
		push_error("【技能穿戴 UI】dice_list_container 未初始化")
		print_tree()
		return

	# 清理旧按钮和 viewport
	for btn in dice_buttons.values():
		if btn and is_instance_valid(btn):
			btn.queue_free()
	for vp in dice_viewports.values():
		if vp and is_instance_valid(vp):
			vp.queue_free()
	dice_buttons.clear()
	dice_viewports.clear()

	var all_ids = PlayerData.get_all_dice_instance_ids()
	if all_ids.is_empty():
		dice_info_label.text = "没有骰子数据"
		return

	# 创建骰子按钮（带 3D 预览）
	for instance_id in all_ids:
		var instance = PlayerData.get_dice_instance(instance_id)
		var btn = _create_dice_button(instance_id, instance)
		dice_list_container.add_child(btn)
		dice_buttons[instance_id] = btn

	# 默认选中第一个骰子
	if selected_instance_id == -1 and all_ids.size() > 0:
		selected_instance_id = all_ids[0]

	_update_dice_selection_highlight()
	_refresh_center_panel()


## 创建骰子按钮（带 3D Viewport）
func _create_dice_button(instance_id: int, instance: Dictionary) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.name = "DiceBtn_%d" % instance_id
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_FILL
	container.add_theme_constant_override("separation", 4)

	# 名称标签
	var label = Label.new()
	label.text = instance.get("name", "未知骰子")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(label)

	# 创建 SubViewport（渲染 3D 内容）
	var viewport = SubViewport.new()
	viewport.name = "DiceViewport"
	viewport.size = Vector2(180, 180)  # 增大尺寸，容纳偏移的骰子
	viewport.transparent_bg = true
	viewport.canvas_item_default_texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS

	# 创建 3D 骰子场景
	_create_dice_3d_viewport(instance_id, viewport)

	# 使用 SubViewportContainer 包裹 SubViewport
	var sv_container = SubViewportContainer.new()
	sv_container.name = "DiceSubViewportContainer"
	sv_container.custom_minimum_size = Vector2(180, 180)
	sv_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sv_container.size_flags_vertical = Control.SIZE_FILL
	sv_container.stretch = true
	sv_container.mouse_filter = Control.MOUSE_FILTER_STOP
	sv_container.add_child(viewport)

	container.add_child(sv_container)

	dice_viewports[instance_id] = viewport

	# 容器接收点击
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_dice_button_pressed(instance_id)
	)
	sv_container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_dice_button_pressed(instance_id)
	)

	return container


## 创建 3D 骰子 Viewport 内容
func _create_dice_3d_viewport(instance_id: int, viewport: SubViewport) -> Node3D:
	var root = Node3D.new()
	viewport.add_child(root)

	# 创建独立的世界空间，隔离渲染
	var world = World3D.new()
	viewport.world_3d = world

	# 相机 — 右上方向下看
	var camera = Camera3D.new()
	camera.position = Vector3(5.95, 0.7, 2.5)  # 相机向右对齐骰子
	camera.rotation = Vector3(-0.4, 0, 0)  # 镜头向下旋转
	camera.fov = 45.0
	camera.current = true
	root.add_child(camera)

	# 瞄准骰子中心
	camera.look_at(Vector3(5.95, 0, 0))  # 瞄准点随骰子偏移

	# 灯光 - 多方向光源
	var light1 = DirectionalLight3D.new()
	light1.position = Vector3(2, 2, 2)
	light1.rotation = Vector3(-0.5, -0.5, 0)
	root.add_child(light1)

	var light2 = DirectionalLight3D.new()
	light2.position = Vector3(-1, 1, -1)
	light2.rotation = Vector3(0.3, 0.3, 0)
	root.add_child(light2)

	# 创建骰子网格（立方体）
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1, 1, 1)
	mesh_instance.mesh = box_mesh
	mesh_instance.position = Vector3(6.45, 0, 0)  # 骰子向右偏移
	mesh_instance.rotation = Vector3(deg_to_rad(10), deg_to_rad(-30), 0)  # 骰子向下 10°，向左 30°

	# 创建材质 - 根据骰子类型设置颜色
	var material = StandardMaterial3D.new()
	var instance_data = PlayerData.get_dice_instance(instance_id)
	if not instance_data.is_empty():
		# 根据骰子名称设置不同颜色
		var dice_name = instance_data.get("name", "")
		if "基础" in dice_name:
			material.albedo_color = Color(0.95, 0.95, 0.95, 1.0)
		elif "回响" in dice_name:
			material.albedo_color = Color(0.6, 0.8, 1.0, 1.0)
		elif "连击" in dice_name:
			material.albedo_color = Color(1.0, 0.9, 0.6, 1.0)
		elif "暴击" in dice_name:
			material.albedo_color = Color(1.0, 0.6, 0.6, 1.0)
		elif "元素" in dice_name:
			material.albedo_color = Color(0.6, 1.0, 0.8, 1.0)
		elif "吸血" in dice_name:
			material.albedo_color = Color(0.9, 0.6, 0.9, 1.0)
		else:
			material.albedo_color = Color(0.95, 0.95, 0.9, 1.0)
	material.roughness = 0.4
	material.metallic = 0.2
	mesh_instance.material_override = material

	root.add_child(mesh_instance)

	return root


## 骰子按钮点击
func _on_dice_button_pressed(instance_id: int):
	selected_instance_id = instance_id
	selected_face_index = -1

	# 更新选中状态（高亮）
	_update_dice_selection_highlight()

	# 刷新中间面板
	_refresh_center_panel()


## 更新骰子选中高亮
func _update_dice_selection_highlight():
	for instance_id in dice_buttons:
		var btn = dice_buttons[instance_id]
		if btn and is_instance_valid(btn):
			if instance_id == selected_instance_id:
				# 添加顶部色条表示选中
				if not btn.has_node("SelectedIndicator"):
					var indicator = ColorRect.new()
					indicator.name = "SelectedIndicator"
					indicator.custom_minimum_size = Vector2(0, 3)
					indicator.color = Color(1.0, 0.85, 0.3, 0.9)
					# 插入到最前面（顶部）
					btn.add_child(indicator)
					btn.move_child(indicator, 0)
			else:
				var indicator = btn.get_node_or_null("SelectedIndicator")
				if indicator:
					indicator.queue_free()


## 刷新中间面板
func _refresh_center_panel():
	if selected_instance_id == -1:
		dice_info_label.text = "选择一个骰子"
		effect_label.text = ""
		return

	var instance = PlayerData.get_dice_instance(selected_instance_id)
	if instance.is_empty():
		dice_info_label.text = "骰子数据为空"
		return

	dice_info_label.text = instance.get("name", "未知骰子")

	var effect_type = instance.get("effect_type", "")
	if effect_type.is_empty():
		effect_label.text = "无被动效果"
	else:
		effect_label.text = "被动：" + _format_effect_description(instance)

	# 刷新骰子面插槽
	_refresh_face_slots(instance)


## 刷新骰子面插槽
func _refresh_face_slots(instance: Dictionary):
	var faces = instance.get("faces", ["0", "0", "0", "0", "0", "0"])

	for i in range(6):
		var slot = face_slots[i] if i < face_slots.size() else null
		if not slot:
			continue

		var skill_id = faces[i] if i < faces.size() else "0"

		# 重置颜色
		slot.color = Color(1, 1, 1, 1)

		if skill_id == "0" or skill_id.is_empty():
			slot.color = Color(0.2, 0.5, 0.2, 0.3)  # 绿色占位
			slot.tooltip_text = "面 %d - 点击选择，然后选择技能配置" % (i + 1)
			# 移除子节点（如果有纹理）
			_clear_slot_texture(slot)
		else:
			# 加载技能图标
			var icon_path = _get_skill_icon_path(skill_id)
			if icon_path and FileAccess.file_exists(icon_path):
				_set_slot_texture(slot, icon_path)
			slot.color = Color(1, 1, 1, 1)
			slot.tooltip_text = "面 %d - %s\n点击选择" % [i + 1, _get_skill_name(skill_id)]

		# 高亮选中的面
		if i == selected_face_index:
			slot.color = Color(1.0, 0.8, 0.2, 0.6)  # 金色高亮

		# 设置鼠标可点击
		slot.mouse_filter = Control.MOUSE_FILTER_STOP

		# 连接点击事件（如果还没连接）
		if not slot.gui_input.is_connected(_on_face_slot_gui_input):
			slot.gui_input.connect(_on_face_slot_gui_input.bind(i))


## 清空插槽纹理
func _clear_slot_texture(slot: Control):
	for child in slot.get_children():
		child.queue_free()


## 设置插槽纹理（添加 TextureRect 子节点）
func _set_slot_texture(slot: Control, icon_path: String):
	# 先清空
	_clear_slot_texture(slot)

	var texture_rect = TextureRect.new()
	texture_rect.texture = load(icon_path)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.add_child(texture_rect)


## 刷新技能列表
func _refresh_skill_list():
	if not skill_grid_container:
		push_error("【技能穿戴 UI】skill_grid_container 未初始化")
		return

	# 清理旧按钮
	for btn in skill_buttons.values():
		if btn and is_instance_valid(btn):
			btn.queue_free()
	skill_buttons.clear()

	var unlocked = PlayerData.get_all_unlocked_skills()
	if unlocked.is_empty():
		var label = Label.new()
		label.text = "暂无已解锁技能"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_grid_container.add_child(label)
		return

	# 创建技能图标按钮（支持拖拽）
	var skill_reader = preload("res://scripts/skill_csv_reader.gd").new()
	for skill_id in unlocked:
		var sid = str(skill_id)
		var btn = _create_skill_button(sid)
		skill_grid_container.add_child(btn)
		skill_buttons[sid] = btn


## 创建技能按钮（支持拖拽）
func _create_skill_button(skill_id: String) -> TextureRect:
	var texture_rect = TextureRect.new()
	texture_rect.name = "SkillBtn_%s" % skill_id
	texture_rect.custom_minimum_size = Vector2(60, 60)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# 加载技能图标
	var icon_path = _get_skill_icon_path(skill_id)
	if icon_path and FileAccess.file_exists(icon_path):
		texture_rect.texture = load(icon_path)

	texture_rect.tooltip_text = "%s\n(ID: %s)\n点击或拖拽到骰面配置" % [_get_skill_name(skill_id), skill_id]

	# 启用拖拽
	texture_rect.set_drag_forwarding(Callable(_can_drop_data_fw_skill), Callable(_get_drag_data_fw_skill), Callable(_drop_data_fw_skill))

	# 连接点击事件
	texture_rect.gui_input.connect(_on_skill_button_gui_input.bind(skill_id))

	return texture_rect


## 拖拽相关函数
func _can_drop_data_fw_skill(at_position: Vector2, data: Variant) -> bool:
	return false  # 技能按钮不接受拖拽


func _get_drag_data_fw_skill(at_position: Vector2) -> Variant:
	# 返回拖拽数据（技能 ID）
	var drag_data = {
		"type": "skill",
		"skill_id": null,
		"preview": null
	}

	# 查找点击的技能按钮
	for skill_id in skill_buttons:
		var btn = skill_buttons[skill_id]
		if btn and btn.get_global_rect().has_point(at_position + global_position):
			drag_data["skill_id"] = skill_id

			# 创建拖拽预览（使用 Label 显示技能名称）
			var preview = Label.new()
			preview.text = _get_skill_name(skill_id)
			preview.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			preview.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			preview.add_theme_font_size_override("font_size", 16)
			preview.position = Vector2(-30, -15)
			drag_data["preview"] = preview
			break

	return drag_data if drag_data["skill_id"] else null


func _drop_data_fw_skill(at_position: Vector2, data: Variant) -> void:
	pass  # 技能按钮不接受掉落


## 骰子面插槽拖拽接收
func _can_drop_data_fw(at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("type") == "skill":
		return true
	return false


func _get_drag_data_fw(at_position: Vector2) -> Variant:
	return null  # 插槽本身不提供拖拽


func _drop_data_fw(at_position: Vector2, data: Variant) -> void:
	if data is not Dictionary or data.get("type") != "skill":
		return

	var skill_id = data.get("skill_id")
	if not skill_id:
		return

	# 找到掉落的是哪个插槽
	var slot_index = -1
	for i in range(face_slots.size()):
		var slot = face_slots[i]
		if slot and slot.get_global_rect().has_point(at_position + global_position):
			slot_index = i
			break

	if slot_index == -1 or selected_instance_id == -1:
		return

	# 分配技能
	PlayerData.assign_skill_to_face(selected_instance_id, slot_index, skill_id)

	# 刷新 UI
	_refresh_face_slots(PlayerData.get_dice_instance(selected_instance_id))
	_refresh_dice_list()


## 骰子面插槽点击事件
func _on_face_slot_gui_input(event: InputEvent, face_index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_instance_id == -1:
			return

		# 选中面
		selected_face_index = face_index
		selected_face_label.text = "选中：面 %d" % (face_index + 1)

		# 刷新高亮
		_refresh_face_slots(PlayerData.get_dice_instance(selected_instance_id))


## 技能按钮点击事件
func _on_skill_button_gui_input(event: InputEvent, skill_id: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_instance_id == -1:
			return

		if selected_face_index == -1:
			return

		# 分配技能
		PlayerData.assign_skill_to_face(selected_instance_id, selected_face_index, skill_id)

		# 刷新 UI
		_refresh_face_slots(PlayerData.get_dice_instance(selected_instance_id))
		_refresh_dice_list()


## 格式化效果描述
func _format_effect_description(instance: Dictionary) -> String:
	var desc = instance.get("description", "")
	for p in ["p1", "p2", "p3", "p4"]:
		var val = str(instance.get(p, "0"))
		desc = desc.replace("[%s]" % p, val)
	return desc


## 获取技能图标路径
func _get_skill_icon_path(skill_id: String) -> String:
	var reader = preload("res://scripts/skill_csv_reader.gd").new()
	var skill_data = reader.get_skill(skill_id)
	if skill_data and skill_data.has("icon"):
		var icon_id = skill_data["icon"]
		return "res://textures/skill/skill_%s.png" % icon_id
	return ""


## 获取技能名称
func _get_skill_name(skill_id: String) -> String:
	var reader = preload("res://scripts/skill_csv_reader.gd").new()
	var skill_data = reader.get_skill(skill_id)
	if skill_data and skill_data.has("name"):
		return skill_data["name"]
	return "技能 " + skill_id


## 重置按钮
func _on_reset_pressed():
	if selected_instance_id == -1:
		return

	for i in range(6):
		PlayerData.assign_skill_to_face(selected_instance_id, i, "0")

	_refresh_face_slots(PlayerData.get_dice_instance(selected_instance_id))
	_refresh_dice_list()


## 确认按钮
func _on_confirm_pressed():
	on_equip_confirmed.emit()


## 打开 UI
func open():
	visible = true
	_load_data()


## 关闭 UI
func close():
	visible = false
	on_ui_closed.emit()


## ESC 关闭
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if visible:
			close()
