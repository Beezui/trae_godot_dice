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
var selected_face_index: int = -1   
# 当前选中的骰子面 (0-5)

# 缓存
var dice_buttons = {}      # { instance_id: VBoxContainer }
var skill_buttons = {}     # { skill_id: Button }
var dice_viewports = {}    # { instance_id: SubViewport }
var dice_sv_containers = {}  # { instance_id: SubViewportContainer }
var dice_content_containers = {}  # { instance_id: VBoxContainer }
var dice_labels = {}       # { instance_id: Label }


func _ready():
	# 节点引用
	dice_list_container = $MainContainer/LeftPanel/DiceListScroll/DiceListContainer as VBoxContainer
	if not dice_list_container:
		push_error("【技能穿戴 UI】dice_list_container 未找到！")
		print_tree()
		return

	# 设置 DiceListContainer 宽度与父节点一致
	dice_list_container.custom_minimum_size.x = $MainContainer/LeftPanel/DiceListScroll.size.x
	dice_list_container.custom_minimum_size.y = 0  # 垂直方向不限制

	# 强制设置 separation
	dice_list_container.add_theme_constant_override("separation", 1)

	dice_info_label = $MainContainer/RightPanel/FaceGridContainer/DiceInfoLabel as Label
	effect_label = $MainContainer/RightPanel/FaceGridContainer/EffectLabel as Label
	skill_grid_container = $MainContainer/RightPanel/SkillPanel/SkillScrollContainer/SkillGridContainer as GridContainer
	selected_face_label = $MainContainer/RightPanel/SkillPanel/SelectedFaceLabel as Label
	face_grid_container = $MainContainer/RightPanel/FaceGridContainer as VBoxContainer

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
	container.add_theme_constant_override("separation", 0)  # 缩小间距
	# 设置对齐方式为居中
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	# 创建内容容器（包裹 label 和 sv_container，用于缩放）
	var content_container = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(content_container)

	# 名称标签
	var label = Label.new()
	label.text = instance.get("name", "未知骰子")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 缩放时保持清晰
	content_container.add_child(label)  # 添加到 content_container

	# 保存 label 引用以便后续调整字体
	dice_labels[instance_id] = label

	# 创建 SubViewport（渲染 3D 内容）
	var viewport = SubViewport.new()
	viewport.name = "DiceViewport"
	viewport.size = Vector2(160, 100)  # 视窗尺寸（缩减高度）
	viewport.transparent_bg = true
	viewport.canvas_item_default_texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS

	# 创建 3D 骰子场景
	_create_dice_3d_viewport(instance_id, viewport)

	# 使用 SubViewportContainer 包裹 SubViewport
	var sv_container = SubViewportContainer.new()
	sv_container.name = "DiceSubViewportContainer"
	sv_container.custom_minimum_size = Vector2(160, 100)  # 与视口尺寸一致
	sv_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sv_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sv_container.stretch = true
	sv_container.mouse_filter = Control.MOUSE_FILTER_STOP
	sv_container.add_child(viewport)

	content_container.add_child(sv_container)  # 添加到 content_container

	# 保存引用
	dice_viewports[instance_id] = viewport
	dice_sv_containers[instance_id] = sv_container
	dice_content_containers[instance_id] = content_container  # 保存 content_container 引用

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
	camera.position = Vector3(5.95, 0.7, 2.5)
	camera.rotation = Vector3(-0.4, 0, 0)
	camera.fov = 45.0
	camera.current = true
	root.add_child(camera)

	# 瞄准骰子中心
	camera.look_at(Vector3(5.95, 0, 0))

	# 灯光 - 多方向光源
	var light1 = DirectionalLight3D.new()
	light1.position = Vector3(2, 2, 2)
	light1.rotation = Vector3(-0.5, -0.5, 0)
	root.add_child(light1)

	var light2 = DirectionalLight3D.new()
	light2.position = Vector3(-1, 1, -1)
	light2.rotation = Vector3(0.3, 0.3, 0)
	root.add_child(light2)

	# 创建骰子网格（6个独立表面的 ArrayMesh，与 dice_6.gd 一致）
	var mesh = _create_dice_array_mesh()

	# 加载空白骰子的真实贴图
	var texture_path = ""
	var instance_data = PlayerData.get_dice_instance(instance_id)
	if not instance_data.is_empty():
		var template_id = instance_data.get("template_id", "")
		if not template_id.is_empty():
			var reader = preload("res://scripts/blank_dice_csv_reader.gd").new()
			var config = reader.get_blank_dice_config(template_id)
			if config.has("texture"):
				var texture_name = config["texture"]
				texture_path = "res://textures/dice/blank_dice/" + texture_name + ".png"

	# 为每个面创建材质（6个面都用同一张贴图）
	var materials = []
	if texture_path and FileAccess.file_exists(texture_path):
		var texture = load(texture_path)
		print("【技能穿戴 UI】加载骰子贴图：", texture_path)
		for i in range(6):
			var material = StandardMaterial3D.new()
			material.albedo_texture = texture
			material.roughness = 0.8
			material.metallic = 0.0
			materials.append(material)
	else:
		# 回退：根据骰子名称设置颜色
		var dice_color = Color(0.95, 0.95, 0.95, 1.0)  # 默认白色
		if not instance_data.is_empty():
			var dice_name = instance_data.get("name", "")
			if "基础" in dice_name:
				dice_color = Color(0.95, 0.95, 0.95, 1.0)
			elif "回响" in dice_name:
				dice_color = Color(0.6, 0.8, 1.0, 1.0)
			elif "连击" in dice_name:
				dice_color = Color(1.0, 0.9, 0.6, 1.0)
			elif "暴击" in dice_name:
				dice_color = Color(1.0, 0.6, 0.6, 1.0)
			elif "元素" in dice_name:
				dice_color = Color(0.6, 1.0, 0.8, 1.0)
			elif "吸血" in dice_name:
				dice_color = Color(0.9, 0.6, 0.9, 1.0)
		for i in range(6):
			var material = StandardMaterial3D.new()
			material.albedo_color = dice_color
			material.roughness = 0.8
			material.metallic = 0.0
			materials.append(material)

	# 创建 MeshInstance3D 并应用网格和材质
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(6.05, 0, 0)
	mesh_instance.rotation = Vector3(deg_to_rad(10), deg_to_rad(-30), 0)

	# 将材质设置到每个表面
	for i in range(6):
		mesh_instance.mesh.surface_set_material(i, materials[i])

	root.add_child(mesh_instance)

	return root


## 创建有 6 个独立表面的骰子网格（与 dice_6.gd create_fallback_mesh 一致）
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


## 骰子按钮点击
func _on_dice_button_pressed(instance_id: int):
	# 保存当前滚动位置
	var scroll_container = $MainContainer/LeftPanel/DiceListScroll as ScrollContainer
	var old_scroll_pos = scroll_container.scroll_vertical

	selected_instance_id = instance_id
	selected_face_index = -1

	# 更新选中状态（高亮）
	_update_dice_selection_highlight()

	# 刷新中间面板
	_refresh_center_panel()

	# 延迟恢复滚动位置（等待布局完成）
	if scroll_container:
		scroll_container.call_deferred("set", "scroll_vertical", old_scroll_pos)


## 更新骰子选中高亮
func _update_dice_selection_highlight():
	var scroll_container = $MainContainer/LeftPanel/DiceListScroll as ScrollContainer
	var first_instance_id = -1
	if dice_content_containers.size() > 0:
		first_instance_id = dice_content_containers.keys()[0]

	# 计算是否需要向上偏移（选中的是第一个骰子时）
	# 放大 50% 时，120 高度的骰子变为 180，上半部分增加 30
	var offset_y = 30.0 if selected_instance_id == first_instance_id else 0.0

	# 缩放 content_container（包含 label 和 sv_container）
	for instance_id in dice_content_containers:
		var content_container = dice_content_containers[instance_id]
		if not content_container or not is_instance_valid(content_container):
			continue

		if instance_id == selected_instance_id:
			# 选中状态：放大 50%，设置 pivot 为中心
			content_container.pivot_offset = content_container.size / 2.0
			content_container.scale = Vector2(1.5, 1.5)
			# 同步放大字体，避免模糊
			var label = dice_labels.get(instance_id)
			if label and is_instance_valid(label):
				label.add_theme_font_size_override("font_size", 21)  # 14 * 1.5 = 21
		else:
			# 未选中：恢复原始尺寸
			content_container.pivot_offset = content_container.size / 2.0
			content_container.scale = Vector2(1.0, 1.0)
			# 恢复字体大小
			var label = dice_labels.get(instance_id)
			if label and is_instance_valid(label):
				label.add_theme_font_size_override("font_size", 14)

	# 在缩放完成后调整滚动位置，补偿第一个骰子的高度增加
	if offset_y > 0 and scroll_container:
		scroll_container.call_deferred("set", "scroll_vertical", max(0, scroll_container.scroll_vertical - offset_y))


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
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # 保持_aspect_居中
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.size = Vector2(96, 96)  # 与插槽尺寸一致
	texture_rect.position = Vector2.ZERO
	slot.add_child(texture_rect)

	# 调试输出：检查插槽和图标尺寸
	print("【技能 UI】设置插槽纹理：slot size=", slot.size, " custom_min_size=", slot.custom_minimum_size, " texture size=", texture_rect.size)


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
func _create_skill_button(skill_id: String) -> Button:
	var button = Button.new()
	button.name = "SkillBtn_%s" % skill_id
	button.custom_minimum_size = Vector2(85, 90)
	button.text = ""
	button.flat = true  # 移除按钮默认背景

	# 布局：VBoxContainer（图标在上，名字在下）
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)  # 减小间距
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER  # 子节点水平居中
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡点击
	button.add_child(vbox)

	# 图标容器（固定高度 50）
	var icon_container = Control.new()
	icon_container.name = "IconContainer"
	icon_container.custom_minimum_size = Vector2(60, 60)
	icon_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_container.size_flags_vertical = 0  # 不垂直扩展
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡点击
	vbox.add_child(icon_container)

	# 图标
	var icon_tex = null
	var icon_path = _get_skill_icon_path(skill_id)
	if icon_path and FileAccess.file_exists(icon_path):
		icon_tex = load(icon_path)
	if icon_tex:
		var icon_rect = TextureRect.new()
		icon_rect.name = "SkillIcon"
		icon_rect.texture = icon_tex
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.size = Vector2(60, 60)
		icon_rect.position = Vector2.ZERO
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡点击
		icon_container.add_child(icon_rect)

	# 技能名
	var name_label = Label.new()
	name_label.name = "SkillName"
	name_label.text = _get_skill_name(skill_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF  # 禁用自动换行
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡点击
	vbox.add_child(name_label)

	button.tooltip_text = "%s\n(ID: %s)\n点击或拖拽到骰面配置" % [_get_skill_name(skill_id), skill_id]

	# 启用拖拽
	button.set_drag_forwarding(Callable(_can_drop_data_fw_skill), Callable(_get_drag_data_fw_skill), Callable(_drop_data_fw_skill))

	# 连接点击事件
	button.pressed.connect(_on_skill_button_pressed.bind(skill_id))

	return button


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

	# 查找点击的技能按钮（使用局部坐标）
	for skill_id in skill_buttons:
		var btn = skill_buttons[skill_id]
		if btn and btn.visible and btn.get_rect().has_point(at_position):
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
func _on_skill_button_pressed(skill_id: String):
	print("【技能 UI】点击技能：", skill_id, " 选中骰子：", selected_instance_id, " 选中面：", selected_face_index)
	if selected_instance_id == -1:
		print("【技能 UI】未选择骰子，请先点击左侧骰子列表")
		return
	if selected_face_index == -1:
		print("【技能 UI】未选择骰子面，请先点击绿色骰面")
		return
	print("【技能 UI】装配技能：", skill_id, " -> 面 ", selected_face_index + 1)
	PlayerData.assign_skill_to_face(selected_instance_id, selected_face_index, skill_id)
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
