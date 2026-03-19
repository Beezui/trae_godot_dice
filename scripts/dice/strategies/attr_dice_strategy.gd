extends RefCounted
class_name AttrDiceStrategy

## 属性骰子贴图策略
## 负责为属性骰子应用动态纹理（SubViewport + 静态贴图 + 动态文字）


## 应用贴图
func apply_textures(mesh_instance: MeshInstance3D, config: Dictionary):
	var textures = config.get("textures", [])
	var values = config.get("values", [])
	var attr_type = config.get("attr_type", "str")
	
	# 尝试加载静态贴图
	var static_texture: Texture2D = null
	if textures.size() > 0 and textures[0] and not textures[0].is_empty():
		var texture_path = "res://textures/hero/hero_" + textures[0] + ".png"
		print("AttrDiceStrategy: 加载贴图路径：", texture_path)
		static_texture = load(texture_path)
		if static_texture:
			print("AttrDiceStrategy: 成功加载贴图：", texture_path)
		else:
			print("AttrDiceStrategy: 加载贴图失败：", texture_path)
	
	# 获取骰面的实际尺寸
	var face_size = Vector2i(512, 512)
	if mesh_instance and mesh_instance.mesh:
		var aabb = mesh_instance.mesh.get_aabb()
		face_size = Vector2i(int(aabb.size.x), int(aabb.size.y))
		print("AttrDiceStrategy: 骰面 AABB 尺寸：", face_size)
	
	# 为每个面创建动态纹理和材质
	var materials = []
	for i in range(6):
		# 获取对应面的属性值
		var attr_value = "0"
		if i < values.size():
			attr_value = format_attribute_value(values[i])
		
		# 创建包含属性文字的动态纹理
		var dynamic_texture = create_face_texture(i, static_texture, attr_value, face_size)
		
		# 创建材质
		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		material.metallic = 0.0
		
		if dynamic_texture:
			# 使用动态纹理
			material.albedo_texture = dynamic_texture
			# 设置 UV 变换为默认值
			material.uv1_scale = Vector3(1, 1, 1)
			material.uv1_offset = Vector3(0, 0, 0)
			# 设置纹理过滤
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		else:
			# 没有贴图，使用彩色材质
			material.albedo_color = get_attr_color(attr_type)
			print("AttrDiceStrategy: 使用备用颜色，面 ", i, ": ", material.albedo_color)
		
		materials.append(material)
	
	# 应用材质到网格
	if mesh_instance and mesh_instance.mesh:
		var surface_count = mesh_instance.mesh.get_surface_count()
		print("AttrDiceStrategy: 应用材质到网格，表面数量：", surface_count)
		
		# 为每个表面应用材质
		for i in range(min(6, surface_count, materials.size())):
			if i < materials.size():
				mesh_instance.mesh.surface_set_material(i, materials[i])
				print("AttrDiceStrategy: 应用材质 ", i, " 到表面 ", i)
		print("AttrDiceStrategy: 属性骰子贴图应用完成")
		
		# 确保网格可见
		mesh_instance.visible = true
	else:
		print("AttrDiceStrategy: 错误：mesh_instance 或 mesh 为空")


## 格式化属性值
func format_attribute_value(value: int) -> String:
	if value >= 100:
		return str(value)
	elif value >= 10:
		return str(value)
	else:
		return str(value)


## 创建面纹理
func create_face_texture(face_index: int, static_texture: Texture2D, dynamic_text: String, face_size: Vector2i) -> Texture2D:
	# 创建一个 SubViewport 用于生成动态纹理
	var viewport = SubViewport.new()
	viewport.name = "DynamicFaceViewport_%d" % face_index
	
	# 根据 AABB 大小设置 viewport 尺寸，最小 512x512 以保证清晰度
	var viewport_size = Vector2i(max(face_size.x, 512), max(face_size.y, 512))
	viewport.size = viewport_size
	
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE  # 只更新一次
	viewport.transparent_bg = true  # 使用透明背景
	
	# 注意：不将 Viewport 添加到场景树，因为它仅用于离屏渲染
	
	# 构建 UI 树，确保填满
	var control = Control.new()
	control.anchors_preset = Control.PRESET_FULL_RECT  # 充满整个 Viewport
	control.size = viewport_size  # 明确设置尺寸
	viewport.add_child(control)
	
	# 添加 TextureRect 用于显示静态贴图
	if static_texture:
		var texture_rect = TextureRect.new()
		texture_rect.texture = static_texture
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE  # 拉伸以完全覆盖
		texture_rect.anchors_preset = Control.PRESET_FULL_RECT
		texture_rect.size = viewport_size  # 明确设置尺寸
		control.add_child(texture_rect)
		print("AttrDiceStrategy: 面 ", face_index, " 添加贴图，尺寸 ", viewport_size)
	
	# 添加 Label 用于显示动态文本
	var label = Label.new()
	label.text = dynamic_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 96)  # 增大字体确保清晰
	label.add_theme_color_override("font_color", Color.BLACK)
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.size = viewport_size  # 明确设置尺寸
	control.add_child(label)
	
	print("AttrDiceStrategy: 创建视口，面 ", face_index, " 尺寸：", viewport_size, " 文字：", dynamic_text)
	
	# 获取 ViewportTexture
	var viewport_texture = viewport.get_texture()
	
	return viewport_texture


## 获取属性颜色
func get_attr_color(attr_type: String) -> Color:
	match attr_type:
		"str":
			return Color(1, 0.3, 0.3, 1)  # 红色 - 力量
		"agi":
			return Color(0.3, 1, 0.3, 1)  # 绿色 - 敏捷
		"int":
			return Color(0.3, 0.3, 1, 1)  # 蓝色 - 智力
		_:
			return Color(1, 1, 1, 1)  # 白色 - 默认
