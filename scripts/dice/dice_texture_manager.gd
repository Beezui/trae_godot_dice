extends Node

## 贴图策略字典
var strategies: Dictionary = {}

## 贴图缓存（避免重复加载）
var texture_cache: Dictionary = {}

## 骰子配置缓存
var dice_config_cache: Dictionary = {}

## 单例实例
static var _instance: DiceTextureManager = null


func _ready():
	# 注册为单例
	_instance = self
	print("DiceTextureManager 初始化完成")
	
	# 预加载常用贴图
	_preload_common_textures()


## 获取单例实例
static func get_instance() -> DiceTextureManager:
	return _instance


## 注册贴图策略
func register_strategy(type: BaseDice.DiceType, strategy: RefCounted):
	strategies[type] = strategy
	print("注册贴图策略：", BaseDice.DiceType.keys()[type])


## 预加载常用贴图到缓存
func _preload_common_textures():
	print("【贴图管理器】预加载常用贴图...")
	var common_textures = [
		"res://textures/dice/dice_face_1.png",
		"res://textures/dice/dice_face_2.png",
		"res://textures/dice/dice_face_3.png",
		"res://textures/dice/dice_face_4.png",
		"res://textures/dice/dice_face_5.png",
		"res://textures/dice/dice_face_6.png"
	]

	for path in common_textures:
		if ResourceLoader.exists(path):
			var texture = load(path)
			if texture:
				texture_cache[path] = texture
				print("【贴图管理器】预加载：", path)
		else:
			print("【贴图管理器】贴图不存在：", path)

	# 预加载命运骰子类型贴图
	_preload_destiny_dice_textures()


## 预加载命运骰子类型贴图
func _preload_destiny_dice_textures():
	print("【贴图管理器】预加载命运骰子贴图...")
	var destiny_textures = [
		"res://textures/destiny/combat.png",      # 战斗 (type 1)
		"res://textures/destiny/encounter.png",   # 奇遇 (type 2)
		"res://textures/destiny/trade.png",       # 交易 (type 3)
		"res://textures/destiny/reward.png",      # 奖励 (type 4)
		"res://textures/destiny/elite.png",       # 精英战斗 (type 5)
		"res://textures/destiny/boss.png"         # Boss 专属
	]

	for path in destiny_textures:
		if ResourceLoader.exists(path):
			var texture = load(path)
			if texture:
				texture_cache[path] = texture
				print("【贴图管理器】预加载命运骰子贴图：", path)
		else:
			print("【贴图管理器】命运骰子贴图不存在：", path)


## 创建折扣骰子面纹理（百分比文字）
## @param face_index 面索引（0-5）
## @param percentage_text 百分比文字（如 "0%", "10%"）
## @param face_size 骰面尺寸
## @param mesh_instance 网格实例（用于添加 Viewport）
## @return ViewportTexture 动态生成的贴图
func create_discount_face_texture(
	face_index: int,
	percentage_text: String,
	face_size: Vector2i,
	mesh_instance: MeshInstance3D = null
) -> Texture2D:
	# 创建 SubViewport（渲染目标）
	var viewport = SubViewport.new()
	viewport.name = "DiscountFace_%d" % face_index
	viewport.size = Vector2i(max(face_size.x, 512), max(face_size.y, 512))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.transparent_bg = true

	# 根 Control
	var control = Control.new()
	control.anchors_preset = Control.PRESET_FULL_RECT
	control.size = viewport.size
	viewport.add_child(control)

	# 清爽浅色背景
	var bg = ColorRect.new()
	bg.color = Color(0.96, 0.94, 0.90, 0.97)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.size = viewport.size
	control.add_child(bg)

	# 文字渐变配色（浅粉橙→红→深红）
	var gradient_colors: Array[Color] = [
		Color("#FFB3A6"),  # 浅粉橙
		Color("#FF6E5E"),  # 红
		Color("#CC4A3A"),  # 深红
	]

	# 字号设置
	var font_size = 220
	var text_length = percentage_text.length()
	if text_length <= 2:
		font_size = 240
	elif text_length <= 3:
		font_size = 220
	elif text_length <= 4:
		font_size = 190
	else:
		font_size = 160

	# 获取默认字体用于测量
	var font = ThemeDB.fallback_font

	# 测量每个字符的宽度以计算总宽度和居中位置
	var total_text_width = 0.0
	var char_widths: Array[float] = []
	for i in range(text_length):
		var char_w = font.get_string_size(percentage_text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		char_widths.append(char_w)
		total_text_width += char_w

	# 计算起始 X/Y 位置（居中，使用 get_string_size 获取覆盖字号后的实际尺寸）
	var start_x = (viewport.size.x - total_text_width) / 2.0
	var text_height = font.get_string_size(percentage_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y
	var start_y = (viewport.size.y - text_height) / 2.0

	var current_x = start_x

	# 为每个字符创建独立 Label，应用渐变色，使用显式定位
	for i in range(text_length):
		var char: String = percentage_text[i]
		var t = float(i) / max(text_length - 1, 1)
		var color_index = t * (gradient_colors.size() - 1)
		var ci = int(color_index)
		var cf = color_index - ci
		var ch_color = gradient_colors[ci].lerp(gradient_colors[min(ci + 1, gradient_colors.size() - 1)], cf)

		var main_label = Label.new()
		main_label.text = char
		main_label.add_theme_font_size_override("font_size", font_size)
		main_label.add_theme_color_override("font_color", ch_color)
		main_label.add_theme_constant_override("outline_size", 2)
		main_label.add_theme_color_override("font_outline_color", Color(0.18, 0.35, 0.55, 0.7))
		main_label.add_theme_color_override("font_shadow_color", Color(0.15, 0.25, 0.4, 0.4))
		main_label.add_theme_constant_override("shadow_offset_x", 2)
		main_label.add_theme_constant_override("shadow_offset_y", 2)
		main_label.add_theme_constant_override("shadow_outline_size", 1)
		# 使用 anchors_preset 确保位置不被布局系统干扰
		main_label.anchors_preset = Control.PRESET_TOP_LEFT
		main_label.position = Vector2(current_x, start_y)
		main_label.size = Vector2(char_widths[i], text_height)
		current_x += char_widths[i]
		control.add_child(main_label)

	# 添加到场景树以触发渲染
	if mesh_instance and mesh_instance.get_parent():
		mesh_instance.get_parent().add_child(viewport)
		viewport.set_meta("auto_cleanup", true)
	else:
		var root = get_tree().current_scene
		if root:
			root.add_child(viewport)
			viewport.set_meta("auto_cleanup", true)

	return viewport.get_texture()


## 应用贴图到骰子（统一接口）
func apply_textures_to_dice(dice: RigidBody3D, config: Dictionary):
	"""
	统一的贴图应用接口
	@param dice 骰子实例（RigidBody3D）
	@param config 贴图配置字典
		- 普通骰子：{"0": "res://...", "1": "res://...", ...}
		- 属性骰子（旧）：{"attr_name": "str", "points_color": "#C00000", "values": [5, 11, ...]}
		- 属性骰子（新）：{"hero_id": 1, "attr_type": "str", "values": [10, 20, ...], "textures": ["1001"]}
		- 技能骰子：{"0": "res://textures/skill/skill_10001.png", ...} + value_config 包含 skill_id
	"""
	if not dice or not is_instance_valid(dice):
		print("【贴图管理器】错误：骰子实例无效")
		return
	
	var mesh_instance = dice.get_node("MeshInstance3D")
	if not mesh_instance:
		print("【贴图管理器】错误：骰子没有 MeshInstance3D")
		return
	
	if not mesh_instance.mesh:
		print("【贴图管理器】错误：MeshInstance3D 没有 mesh")
		return
	
	print("【贴图管理器】开始应用贴图到 ", dice.name)
	
	# 判断是否是属性骰子配置（支持新旧两种格式）
	var is_attr_dice = false
	if config.has("hero_id") and config.has("attr_type"):
		# 新格式：使用 hero_id 和 attr_type
		is_attr_dice = true
	elif config.has("attr_name") and config.has("values"):
		# 旧格式：使用 attr_name
		is_attr_dice = true
	
	# 判断是否是技能骰子配置
	var is_skill_dice = false
	# 检查 config 中是否包含技能 ID 格式的值（"10001" 这种格式）
	if config.size() > 0:
		var first_key = config.keys()[0]
		var first_value = config[first_key]
		if typeof(first_value) == TYPE_STRING and first_value.length() >= 5 and first_value.substr(0, 1) == "1":
			# 可能是技能 ID（如 "10001"）
			is_skill_dice = true

	# 判断是否是命运骰子配置
	var is_destiny_dice = false
	# 判断是否是折扣骰子配置
	var is_discount_dice = false
	# 判断是否是奇遇骰子配置
	var is_adventure_dice = false
	# 判断是否是奖励骰子配置
	var is_reward_dice = false
	if config.size() > 0:
		var first_key = config.keys()[0]
		var first_value = config[first_key]
		if typeof(first_value) == TYPE_STRING and first_value.begins_with("destiny_"):
			is_destiny_dice = true
		elif typeof(first_value) == TYPE_STRING and first_value.begins_with("boss_"):
			is_destiny_dice = true

		if typeof(first_value) == TYPE_STRING and first_value.begins_with("discount_"):
			is_discount_dice = true

		# 判断是否是奇遇骰子配置（adventure_ 前缀）
		if typeof(first_value) == TYPE_STRING and first_value.begins_with("adventure_"):
			is_adventure_dice = true

		# 判断是否是奖励骰子配置（reward_ 前缀）
		if typeof(first_value) == TYPE_STRING and first_value.begins_with("reward_"):
			is_reward_dice = true

	if is_discount_dice:
		_apply_discount_dice_textures(mesh_instance, config)
	elif is_adventure_dice:
		_apply_adventure_dice_textures(mesh_instance, config)
	elif is_reward_dice:
		_apply_reward_dice_textures(mesh_instance, config)
	elif is_attr_dice:
		# 属性骰子：动态生成带数值的贴图
		_apply_attr_dice_textures(mesh_instance, config)
	elif is_skill_dice:
		# 技能骰子：使用技能图标贴图
		_apply_skill_dice_textures(mesh_instance, config)
	elif is_destiny_dice:
		# 命运骰子：使用类型贴图或 Boss 专属贴图
		_apply_destiny_dice_textures(mesh_instance, config)
	else:
		# 普通骰子：使用贴图路径
		_apply_normal_dice_textures(mesh_instance, config)


## 应用属性骰子贴图（集成自 attr_dice.gd）
func _apply_attr_dice_textures(mesh_instance: MeshInstance3D, config: Dictionary):
	print("【贴图管理器】应用属性骰子贴图（集成方法）")
	
	# 支持新旧两种配置格式
	var attr_type = ""
	var hero_id = -1
	var values_array = []
	var textures_array = []
	var points_color = Color.BLACK  # 默认文字颜色为黑色
	
	if config.has("hero_id") and config.has("attr_type"):
		# 新格式：使用 hero_id 和 attr_type（hero.json 格式）
		hero_id = config.get("hero_id", 1)
		attr_type = config.get("attr_type", "str")
		values_array = config.get("values", [])
		textures_array = config.get("textures", [])
		# 新格式中也读取文字颜色
		var color_str = config.get("points_color", "#000000")
		if color_str is String:
			points_color = Color(color_str)
		else:
			points_color = color_str
		print("【贴图管理器】使用新格式：hero_id=", hero_id, ", attr_type=", attr_type, ", 文字颜色=", points_color)
	else:
		# 旧格式：使用 attr_name（attr_dices.json 格式）
		attr_type = config.get("attr_name", "str")
		values_array = config.get("values", [1, 2, 3, 4, 5, 6])
		textures_array = config.get("textures", [])
		# 旧格式中读取文字颜色
		var color_str = config.get("points_color", "#000000")
		if color_str is String:
			points_color = Color(color_str)
		else:
			points_color = color_str
		print("【贴图管理器】使用旧格式：attr_type=", attr_type, ", 文字颜色=", points_color)
	
	# 将数组转换为字典
	var values = {}
	for i in range(values_array.size()):
		values[i] = values_array[i]
	
	# 加载英雄贴图（从 textures_array 的第一个元素）
	# 注意：hero.json 中的 texture 是 6 个元素的数组，每个面对应一个
	# 但属性骰子所有面使用相同的英雄贴图，所以只取第一个
	var static_texture = null
	if textures_array.size() > 0:
		var texture_id = textures_array[0]
		if texture_id and not str(texture_id).is_empty():
			var texture_path = "res://textures/hero/hero_" + str(texture_id) + ".png"
			print("【贴图管理器】加载英雄贴图：", texture_path)
			static_texture = load(texture_path)
			if static_texture:
				print("【贴图管理器】英雄贴图加载成功")
			else:
				print("【贴图管理器】英雄贴图加载失败")
	
	# 获取骰面尺寸
	var face_size = Vector2i(512, 512)
	if mesh_instance.mesh:
		var aabb = mesh_instance.mesh.get_aabb()
		face_size = Vector2i(int(aabb.size.x), int(aabb.size.y))
		print("【贴图管理器】骰面尺寸：", face_size)
	
	# 为每个面创建动态纹理和材质
	var materials = []
	for i in range(6):
		# 获取对应面的属性值
		var attr_value = "0"
		if i < values.size():
			var raw_value = values[i]
			# 格式化属性值（支持缩写）
			if typeof(raw_value) == TYPE_INT:
				if raw_value >= 1000:
					var k_value = raw_value / 1000.0
					if k_value.is_integer():
						attr_value = str(int(k_value)) + "k"
					else:
						attr_value = str(round(k_value * 10) / 10) + "k"
				else:
					attr_value = str(raw_value)
			else:
				# 处理字符串类型的值（从 JSON 加载时可能是字符串）
				if typeof(raw_value) == TYPE_STRING:
					attr_value = raw_value
				else:
					attr_value = str(raw_value)
		
		# 创建包含属性文字的动态纹理（使用配置的文字颜色）
		var dynamic_texture = create_attr_face_texture(i, attr_type, attr_value, points_color, static_texture, face_size, mesh_instance)
		
		# 创建材质
		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		material.metallic = 0.0
		
		if dynamic_texture:
			material.albedo_texture = dynamic_texture
			material.uv1_scale = Vector3(1, 1, 1)
			material.uv1_offset = Vector3(0, 0, 0)
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			print("【贴图管理器】属性骰子面 ", i, " 生成动态贴图，数值：", attr_value, ", 文字颜色：", points_color)
		else:
			# 备用方案：使用属性颜色（骰子底色）
			var attr_color = _get_attr_color(attr_type)
			material.albedo_color = attr_color
			print("【贴图管理器】属性骰子面 ", i, " 动态贴图创建失败，使用骰子底色：", attr_color)
		
		materials.append(material)
	
	# 应用材质到网格
	_apply_materials_to_mesh(mesh_instance, materials)


## 根据属性类型返回颜色
func _get_attr_color(attr_type: String) -> Color:
	match attr_type:
		"str":
			return Color(1, 0.2, 0.2, 1)  # 力量 - 红色
		"agi":
			return Color(0.2, 0.8, 0.2, 1)  # 敏捷 - 绿色
		"int":
			return Color(0.2, 0.2, 1, 1)  # 智力 - 蓝色
		_:
			return Color(0.5, 0.5, 0.5, 1)  # 默认 - 灰色


## 创建属性骰子面的动态贴图（集成方法）
func create_attr_face_texture(
	face_index: int, 
	attr_type: String, 
	value_text: String, 
	font_color: Color, 
	static_texture: Texture2D, 
	face_size: Vector2i,
	mesh_instance: MeshInstance3D = null
) -> Texture2D:
	"""
	创建属性骰子动态贴图（集成自 attr_dice.gd 的 create_face_texture）
	@param face_index 面索引（0-5）
	@param attr_type 属性类型（str/agi/int）
	@param value_text 数值文字
	@param font_color 文字颜色
	@param static_texture 静态贴图（英雄贴图）
	@param face_size 骰面尺寸
	@param mesh_instance 网格实例（用于将 Viewport 添加到场景树）
	@return ViewportTexture 动态生成的贴图
	"""
	# 1. 创建 SubViewport（渲染目标）
	var viewport = SubViewport.new()
	viewport.name = "AttrDiceFace_%d" % face_index
	viewport.size = Vector2i(max(face_size.x, 512), max(face_size.y, 512))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.transparent_bg = true
	
	# 2. 创建根 Control 节点（必须充满 Viewport）
	var control = Control.new()
	control.anchors_preset = Control.PRESET_FULL_RECT
	control.size = viewport.size
	viewport.add_child(control)
	
	# 3. 添加静态贴图（英雄贴图）
	if static_texture:
		var texture_rect = TextureRect.new()
		texture_rect.texture = static_texture
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE  # 完全覆盖
		texture_rect.anchors_preset = Control.PRESET_FULL_RECT
		texture_rect.size = viewport.size
		control.add_child(texture_rect)
		print("【动态贴图】加载英雄贴图成功")
	else:
		print("【动态贴图】警告：没有静态贴图")
	
	# 4. 添加动态文本标签（使用配置的颜色）
	# 创建主标签
	var label = Label.new()
	label.name = "TextLabel"
	label.text = value_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 设置字体：288 号（再扩大 100%，原始 96 的 300%）
	label.add_theme_font_size_override("font_size", 288)
	
	# 设置文字颜色
	label.add_theme_color_override("font_color", font_color)
	
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.size = viewport.size
	
	# 添加描边效果：创建一个描边层（使用稍大的深色文字作为背景）
	var outline_label = Label.new()
	outline_label.name = "TextOutline"
	outline_label.text = value_text
	outline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outline_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 描边字号比主文字大 15%，模拟更粗的描边效果
	outline_label.add_theme_font_size_override("font_size", 331)  # 288 * 1.15 ≈ 331
	
	# 描边颜色使用更深的颜色（文字颜色的暗色版本，更深）
	var outline_color = font_color.darkened(0.8)
	outline_label.add_theme_color_override("font_color", outline_color)
	
	outline_label.anchors_preset = Control.PRESET_FULL_RECT
	outline_label.size = viewport.size
	
	# 先添加描边层（在底层），再添加主文字层
	control.add_child(outline_label)
	control.add_child(label)
	
	# 自适应缩小：根据文字长度调整字号
	_adapt_label_font_size(label, value_text, viewport.size)
	_adapt_label_font_size(outline_label, value_text, viewport.size)
	
	# 5. 【关键】将 Viewport 添加到场景树中（必须添加到正在渲染的节点下）
	# 注意：这里不能直接添加到 DiceTextureManager，因为它不是场景节点
	# 所以需要调用者负责将生成的贴图应用到骰子后，再清理 viewport
	# 但为了立即渲染，我们需要临时添加到一个场景节点
	# 使用临时添加到当前正在处理的 mesh_instance 的父节点
	if mesh_instance and mesh_instance.get_parent():
		mesh_instance.get_parent().add_child(viewport)
		# 标记为在处理完后自动清理
		viewport.set_meta("auto_cleanup", true)
		print("【动态贴图】Viewport 已添加到场景树：", viewport.name)
	else:
		# 备用方案：直接添加到当前场景
		var root = get_tree().current_scene
		if root:
			root.add_child(viewport)
			viewport.set_meta("auto_cleanup", true)
			print("【动态贴图】Viewport 已添加到根场景：", viewport.name)
		else:
			print("【动态贴图】警告：无法将 Viewport 添加到场景树")
	
	# 6. 返回 ViewportTexture（动态生成的贴图）
	return viewport.get_texture()


## 自适应调整标签字体大小（根据内容长度）
func _adapt_label_font_size(label: Label, text: String, _viewport_size: Vector2i):
	"""
	根据文字长度自适应缩小字体，避免超出骰面
	策略：
	- 1-3 个字符：保持 288 号
	- 4-5 个字符：缩小到 240 号
	- 6-7 个字符：缩小到 192 号
	- 8-10 个字符：缩小到 144 号
	- 11 个字符以上：缩小到 96 号
	- 包含 "k" 后缀：额外缩小 10%
	"""
	var text_length = text.length()
	var base_font_size = 288  # 基础字号（扩大 300%）
	var final_font_size = base_font_size
	
	# 根据字符长度调整字号
	if text_length <= 3:
		final_font_size = 288  # 短文本，保持最大
	elif text_length <= 5:
		final_font_size = 240  # 中等长度
	elif text_length <= 7:
		final_font_size = 192  # 较长文本
	elif text_length <= 10:
		final_font_size = 144  # 长文本
	else:
		final_font_size = 96   # 超长文本
	
	# 如果包含 "k" 后缀（如 "1.5k"），额外缩小 10%
	if "k" in text or "K" in text:
		final_font_size = int(final_font_size * 0.9)
	
	# 应用最终字号
	label.add_theme_font_size_override("font_size", final_font_size)
	
	print("【字体自适应】文字：", text, ", 长度：", text_length, ", 最终字号：", final_font_size)


## 创建属性骰子面的动态贴图（简化版，使用 dice_face 贴图）
func _create_attr_face_texture(face_index: int, attr_name: String, value_text: String, points_color_str: String, face_size: Vector2i) -> Texture2D:
	# 1. 创建 SubViewport（渲染目标）
	var viewport = SubViewport.new()
	viewport.name = "AttrDiceFace_%d" % face_index
	viewport.size = Vector2i(max(face_size.x, 512), max(face_size.y, 512))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.transparent_bg = true
	
	# 2. 创建根 Control 节点（必须充满 Viewport）
	var control = Control.new()
	control.anchors_preset = Control.PRESET_FULL_RECT
	control.size = viewport.size
	viewport.add_child(control)
	
	# 3. 添加静态贴图（属性骰子使用统一的骰子面贴图）
	# 注意：这里加载 dice_face_X.png 作为底图
	var static_texture_path = "res://textures/dice/dice_face_%d.png" % (face_index + 1)
	if ResourceLoader.exists(static_texture_path):
		var static_texture = load(static_texture_path)
		if static_texture:
			var texture_rect = TextureRect.new()
			texture_rect.texture = static_texture
			texture_rect.stretch_mode = TextureRect.STRETCH_SCALE  # 完全覆盖
			texture_rect.anchors_preset = Control.PRESET_FULL_RECT
			texture_rect.size = viewport.size
			control.add_child(texture_rect)
			print("【动态贴图】加载静态贴图：", static_texture_path)
		else:
			print("【动态贴图】静态贴图加载失败：", static_texture_path)
	else:
		print("【动态贴图】静态贴图不存在：", static_texture_path)
	
	# 4. 添加动态文本标签（使用配置的颜色）
	# 创建主标签
	var label = Label.new()
	label.name = "TextLabel"
	label.text = value_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 设置字体：288 号（再扩大 100%）
	label.add_theme_font_size_override("font_size", 288)
	
	# 解析颜色
	var font_color = Color(points_color_str) if points_color_str is String else points_color_str
	label.add_theme_color_override("font_color", font_color)
	
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.size = viewport.size
	
	# 添加描边效果：创建一个描边层
	var outline_label = Label.new()
	outline_label.name = "TextOutline"
	outline_label.text = value_text
	outline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outline_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 描边字号比主文字大 15%，模拟更粗的描边效果
	outline_label.add_theme_font_size_override("font_size", 331)
	
	# 描边颜色使用更深的颜色
	var outline_color = font_color.darkened(0.8)
	outline_label.add_theme_color_override("font_color", outline_color)
	
	outline_label.anchors_preset = Control.PRESET_FULL_RECT
	outline_label.size = viewport.size
	
	# 先添加描边层（在底层），再添加主文字层
	control.add_child(outline_label)
	control.add_child(label)
	
	# 自适应缩小：根据文字长度调整字号
	_adapt_label_font_size(label, value_text, viewport.size)
	_adapt_label_font_size(outline_label, value_text, viewport.size)
	
	# 5. 返回 ViewportTexture（动态生成的贴图）
	return viewport.get_texture()


## 应用普通骰子贴图（使用贴图路径）
func _apply_normal_dice_textures(mesh_instance: MeshInstance3D, config: Dictionary):
	print("【贴图管理器】应用普通骰子贴图（可能是角色骰子）")
	print("【贴图管理器】贴图配置：", config)

	# 为每个面创建材质
	var materials = []

	# 定义备用颜色
	var id_colors = {
		0: Color(1, 0, 0, 1),   # 红色
		1: Color(0, 1, 0, 1),   # 绿色
		2: Color(0, 0, 1, 1),   # 蓝色
		3: Color(1, 1, 0, 1),   # 黄色
		4: Color(1, 0, 1, 1),   # 紫色
		5: Color(0, 1, 1, 1)    # 青色
	}

	for i in range(6):
		# 支持字符串键和整数键
		var texture_path = ""
		if config.has(str(i)):
			texture_path = config.get(str(i), "")
		elif config.has(i):
			texture_path = config.get(i, "")

		print("【贴图管理器】普通骰子面 ", i, " 贴图路径：", texture_path)

		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		material.metallic = 0.0  # 与属性骰子保持一致

		if texture_path and not texture_path.is_empty():
			# 检查文件是否存在
			if not ResourceLoader.exists(texture_path):
				print("【贴图管理器】警告：贴图文件不存在：", texture_path)
				material.albedo_color = id_colors.get(i, Color(0.5, 0.5, 0.5, 1))
			else:
				# 从缓存获取贴图（或加载）
				var texture = get_texture(texture_path)
				if texture:
					material.albedo_texture = texture
					material.uv1_scale = Vector3(1, 1, 1)  # 确保 UV 缩放正确
					material.uv1_offset = Vector3(0, 0, 0)
					material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
					print("【贴图管理器】面 ", i, " 加载贴图成功：", texture_path)
				else:
					print("【贴图管理器】面 ", i, " 贴图加载失败：", texture_path)
					material.albedo_color = id_colors.get(i, Color(0.5, 0.5, 0.5, 1))
		else:
			print("【贴图管理器】面 ", i, " 无贴图配置，使用颜色")
			material.albedo_color = id_colors.get(i, Color(0.5, 0.5, 0.5, 1))

		materials.append(material)

	# 应用材质到网格
	_apply_materials_to_mesh(mesh_instance, materials)


## 应用技能骰子贴图（使用技能图标）
func _apply_skill_dice_textures(mesh_instance: MeshInstance3D, config: Dictionary):
	print("【贴图管理器】应用技能骰子贴图")
	
	# 为每个面创建材质
	var materials = []
	
	# 定义备用颜色（技能骰子使用紫色）
	var skill_colors = {
		0: Color(0.8, 0.2, 0.8, 1),
		1: Color(0.8, 0.2, 0.8, 1),
		2: Color(0.8, 0.2, 0.8, 1),
		3: Color(0.8, 0.2, 0.8, 1),
		4: Color(0.8, 0.2, 0.8, 1),
		5: Color(0.8, 0.2, 0.8, 1)
	}
	
	for i in range(6):
		# 支持字符串键和整数键
		var texture_path = ""
		if config.has(str(i)):
			texture_path = config.get(str(i), "")
		elif config.has(i):
			texture_path = config.get(i, "")
		
		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		material.metallic = 0.2  # 技能骰子稍微增加金属感
		
		if texture_path and not texture_path.is_empty():
			# 从缓存获取贴图（或加载）
			var texture = get_texture(texture_path)
			if texture:
				material.albedo_texture = texture
				print("【贴图管理器】技能骰子面 ", i, " 加载贴图：", texture_path)
			else:
				print("【贴图管理器】技能骰子面 ", i, " 贴图加载失败：", texture_path)
				material.albedo_color = skill_colors.get(i, Color(0.5, 0.5, 0.5, 1))
		else:
			print("【贴图管理器】技能骰子面 ", i, " 无贴图配置，使用颜色")
			material.albedo_color = skill_colors.get(i, Color(0.5, 0.5, 0.5, 1))
		
		materials.append(material)
	
	# 应用材质到网格
	_apply_materials_to_mesh(mesh_instance, materials)


## 应用命运骰子贴图
## @param mesh_instance 网格实例
## @param config 命运骰子配置字典
##   - 普通命运骰子：{"0": "destiny_type_1", "1": "destiny_type_1", "2": "destiny_type_2", ...}
##   - Boss 专属：{"0": "boss_1001", "1": "boss_1001", ...}
func _apply_destiny_dice_textures(mesh_instance: MeshInstance3D, config: Dictionary):
	print("【贴图管理器】应用命运骰子贴图")

	# 判断是否为 Boss 专属贴图
	var is_boss_battle = false
	if config.size() > 0:
		var first_value = config[config.keys()[0]]
		if typeof(first_value) == TYPE_STRING and first_value.begins_with("boss_"):
			is_boss_battle = true
			print("【贴图管理器】Boss 战命运骰子，贴图前缀：", first_value)

	# 为每个面创建材质
	var materials = []

	# 定义命运骰子类型颜色
	var destiny_colors = {
		"destiny_type_1": Color(1, 0.3, 0.3),  # 红色 - 战斗
		"destiny_type_2": Color(0.3, 0.6, 1),  # 蓝色 - 奇遇
		"destiny_type_3": Color(1, 0.8, 0.3),  # 黄色 - 交易
		"destiny_type_4": Color(0.3, 1, 0.5),  # 绿色 - 奖励
		"destiny_type_5": Color(0.8, 0.2, 0.2),  # 深红色 - 精英战斗
		"destiny_boss": Color(0.5, 0, 0.8)  # 紫色 - Boss
	}

	# Boss 专属颜色
	var boss_color = Color(0.5, 0, 0.8)

	for i in range(6):
		# 支持字符串键和整数键
		var texture_key = str(i)
		var texture_value = ""

		if config.has(texture_key):
			texture_value = config.get(texture_key, "")

		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		material.metallic = 0.2  # 命运骰子稍微增加金属感

		if texture_value and not texture_value.is_empty():
			# 加载贴图
			var texture_path = _get_destiny_texture_path(texture_value)
			if texture_path and ResourceLoader.exists(texture_path):
				var texture = get_texture(texture_path)
				if texture:
					material.albedo_texture = texture
					print("【贴图管理器】命运骰子面 ", i, " 加载贴图：", texture_path)
				else:
					print("【贴图管理器】命运骰子面 ", i, " 贴图加载失败：", texture_path)
					# 使用备用颜色
					material.albedo_color = _get_destiny_color(texture_value, destiny_colors, boss_color)
			else:
				# 贴图不存在，使用备用颜色
				print("【贴图管理器】命运骰子面 ", i, " 贴图不存在：", texture_path)
				material.albedo_color = _get_destiny_color(texture_value, destiny_colors, boss_color)
		else:
			print("【贴图管理器】命运骰子面 ", i, " 无贴图配置，使用颜色")
			material.albedo_color = Color(0.5, 0.5, 0.5)

		materials.append(material)

	# 应用材质到网格
	_apply_materials_to_mesh(mesh_instance, materials)


## 应用折扣骰子贴图（百分比文字）
func _apply_discount_dice_textures(mesh_instance: MeshInstance3D, config: Dictionary):
	print("【贴图管理器】应用折扣骰子贴图")

	# 折扣值固定配置
	var discount_values = ["0%", "10%", "10%", "15%", "20%", "50%"]

	# 获取骰面尺寸
	var face_size = Vector2i(512, 512)
	if mesh_instance.mesh:
		var aabb = mesh_instance.mesh.get_aabb()
		face_size = Vector2i(int(aabb.size.x), int(aabb.size.y))

	# 为每个面创建动态纹理
	var materials = []
	for i in range(6):
		var percentage_text = discount_values[i] if i < discount_values.size() else "0%"
		var dynamic_texture = create_discount_face_texture(i, percentage_text, face_size, mesh_instance)

		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		material.metallic = 0.0

		if dynamic_texture:
			material.albedo_texture = dynamic_texture
			print("【贴图管理器】折扣骰子面 ", i, " 生成动态贴图：", percentage_text)
		else:
			material.albedo_color = Color(0.7, 0.6, 0.0)
			print("【贴图管理器】折扣骰子面 ", i, " 贴图创建失败，使用默认颜色")

		materials.append(material)

	_apply_materials_to_mesh(mesh_instance, materials)


## 应用奇遇骰子贴图（选项编号文字）
func _apply_adventure_dice_textures(mesh_instance: MeshInstance3D, config: Dictionary):
	print("【贴图管理器】应用奇遇骰子贴图")

	# 从 config 读取每个面的选项编号（adventure_1 -> "1"）
	# 注意：config 使用整数键（texture_config[i] = ...），兼容字符串键
	var face_texts: Array = []
	for i in range(6):
		var value = config.get(i, config.get(str(i), ""))
		if typeof(value) == TYPE_STRING and value.begins_with("adventure_"):
			var num = value.substr(10)  # 移除 "adventure_" 前缀
			face_texts.append(num)
		else:
			face_texts.append(str(i + 1))

	# 获取骰面尺寸
	var face_size = Vector2i(512, 512)
	if mesh_instance.mesh:
		var aabb = mesh_instance.mesh.get_aabb()
		face_size = Vector2i(int(aabb.size.x), int(aabb.size.y))

	# 奇遇配色：金色渐变 + 深色背景
	var bg_color = Color(0.12, 0.1, 0.18, 0.95)
	var text_color_start = Color(1.0, 0.85, 0.4)   # 亮金色
	var text_color_end = Color(0.8, 0.55, 0.2)     # 深金色
	var outline_color = Color(0.15, 0.1, 0.05, 0.9)

	# 为每个面创建动态纹理
	var materials = []
	for i in range(6):
		var option_text = face_texts[i] if i < face_texts.size() else "?"
		var dynamic_texture = create_adventure_face_texture(i, option_text, bg_color, text_color_start, text_color_end, outline_color, face_size, mesh_instance)

		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		material.metallic = 0.1

		if dynamic_texture:
			material.albedo_texture = dynamic_texture
			print("【贴图管理器】奇遇骰子面 ", i, " 生成动态贴图：", option_text)
		else:
			material.albedo_color = Color(0.5, 0.4, 0.1)
			print("【贴图管理器】奇遇骰子面 ", i, " 贴图创建失败，使用默认颜色")

		materials.append(material)

	_apply_materials_to_mesh(mesh_instance, materials)


## 创建奇遇骰子面纹理（选项编号）
func create_adventure_face_texture(
	face_index: int,
	option_text: String,
	bg_color: Color,
	color_start: Color,
	color_end: Color,
	outline_color: Color,
	face_size: Vector2i,
	mesh_instance: MeshInstance3D = null
) -> Texture2D:
	# 创建 SubViewport（渲染目标）
	var viewport = SubViewport.new()
	viewport.name = "AdventureFace_%d" % face_index
	viewport.size = Vector2i(max(face_size.x, 512), max(face_size.y, 512))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.transparent_bg = true

	# 根 Control
	var control = Control.new()
	control.anchors_preset = Control.PRESET_FULL_RECT
	control.size = viewport.size
	viewport.add_child(control)

	# 深色半透明背景
	var bg = ColorRect.new()
	bg.color = bg_color
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.size = viewport.size
	control.add_child(bg)

	# 根据文字长度设置字号
	var font_size = 200
	var text_length = option_text.length()
	if text_length <= 1:
		font_size = 240
	elif text_length <= 2:
		font_size = 200
	else:
		font_size = 160

	# 获取默认字体用于测量
	var font = ThemeDB.fallback_font

	# 计算文字居中位置
	var text_size = font.get_string_size(option_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var start_x = (viewport.size.x - text_size.x) / 2.0
	var start_y = (viewport.size.y - text_size.y) / 2.0

	# 为每个字符创建独立 Label，应用渐变色彩，使用显式定位
	var current_x = start_x
	for i in range(text_length):
		var char: String = option_text[i]
		var char_w = font.get_string_size(char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var t = float(i) / max(text_length - 1, 1)
		var char_color = color_start.lerp(color_end, t)

		var main_label = Label.new()
		main_label.text = char
		main_label.add_theme_font_size_override("font_size", font_size)
		main_label.add_theme_color_override("font_color", char_color)
		main_label.add_theme_constant_override("outline_size", 3)
		main_label.add_theme_color_override("font_outline_color", outline_color)
		main_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.05, 0.0, 0.5))
		main_label.add_theme_constant_override("shadow_offset_x", 2)
		main_label.add_theme_constant_override("shadow_offset_y", 2)
		main_label.anchors_preset = Control.PRESET_TOP_LEFT
		main_label.position = Vector2(current_x, start_y)
		main_label.size = Vector2(char_w, text_size.y)
		current_x += char_w
		control.add_child(main_label)

	# 添加到场景树以触发渲染
	if mesh_instance and mesh_instance.get_parent():
		mesh_instance.get_parent().add_child(viewport)
		viewport.set_meta("auto_cleanup", true)
	else:
		var root = get_tree().current_scene
		if root:
			root.add_child(viewport)
			viewport.set_meta("auto_cleanup", true)

	return viewport.get_texture()


## 应用奖励骰子贴图（温暖金色渐变）
func _apply_reward_dice_textures(mesh_instance: MeshInstance3D, config: Dictionary):
	print("【贴图管理器】应用奖励骰子贴图")

	# 从 config 读取每个面的选项编号（reward_1 -> "1"）
	var face_texts: Array = []
	for i in range(6):
		var value = config.get(i, config.get(str(i), ""))
		if typeof(value) == TYPE_STRING and value.begins_with("reward_"):
			var num = value.substr(7)  # 移除 "reward_" 前缀
			face_texts.append(num)
		else:
			face_texts.append(str(i + 1))

	# 获取骰面尺寸
	var face_size = Vector2i(512, 512)
	if mesh_instance.mesh:
		var aabb = mesh_instance.mesh.get_aabb()
		face_size = Vector2i(int(aabb.size.x), int(aabb.size.y))

	# 奖励配色：金色渐变 + 温暖深色背景
	var bg_color = Color(0.14, 0.1, 0.07, 0.95)
	var text_color_start = Color(1.0, 0.84, 0.0)   # 金色 #FFD700
	var text_color_mid = Color(1.0, 0.55, 0.0)     # 橙色 #FF8C00
	var text_color_end = Color(1.0, 0.3, 0.3)      # 珊瑚粉 #FF4D4D
	var outline_color = Color(0.15, 0.1, 0.05, 0.9)

	# 为每个面创建动态纹理
	var materials = []
	for i in range(6):
		var option_text = face_texts[i] if i < face_texts.size() else "?"
		var dynamic_texture = create_reward_face_texture(i, option_text, bg_color, text_color_start, text_color_mid, text_color_end, outline_color, face_size, mesh_instance)

		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		material.metallic = 0.1

		if dynamic_texture:
			material.albedo_texture = dynamic_texture
			print("【贴图管理器】奖励骰子面 ", i, " 生成动态贴图：", option_text)
		else:
			material.albedo_color = Color(1.0, 0.7, 0.2)
			print("【贴图管理器】奖励骰子面 ", i, " 贴图创建失败，使用默认颜色")

		materials.append(material)

	_apply_materials_to_mesh(mesh_instance, materials)


## 创建奖励骰子面纹理（温暖金色渐变，逐字独立色）
func create_reward_face_texture(
	face_index: int,
	option_text: String,
	bg_color: Color,
	color_start: Color,
	color_mid: Color,
	color_end: Color,
	outline_color: Color,
	face_size: Vector2i,
	mesh_instance: MeshInstance3D = null
) -> Texture2D:
	# 创建 SubViewport（渲染目标）
	var viewport = SubViewport.new()
	viewport.name = "RewardFace_%d" % face_index
	viewport.size = Vector2i(max(face_size.x, 512), max(face_size.y, 512))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.transparent_bg = true

	# 根 Control
	var control = Control.new()
	control.anchors_preset = Control.PRESET_FULL_RECT
	control.size = viewport.size
	viewport.add_child(control)

	# 温暖深色背景
	var bg = ColorRect.new()
	bg.color = bg_color
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.size = viewport.size
	control.add_child(bg)

	# 根据文字长度设置字号
	var font_size = 200
	var text_length = option_text.length()
	if text_length <= 1:
		font_size = 240
	elif text_length <= 2:
		font_size = 200
	else:
		font_size = 160

	# 获取默认字体用于测量
	var font = ThemeDB.fallback_font

	# 计算文字居中位置
	var text_size = font.get_string_size(option_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var start_x = (viewport.size.x - text_size.x) / 2.0
	var start_y = (viewport.size.y - text_size.y) / 2.0

	# 为每个字符创建独立 Label，应用暖色渐变，使用显式定位
	var current_x = start_x
	for i in range(text_length):
		var char: String = option_text[i]
		var char_w = font.get_string_size(char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var t = float(i) / max(text_length - 1, 1)

		# 三段渐变插值
		var char_color: Color
		if t < 0.5:
			# 前半段：金色→橙色
			char_color = color_start.lerp(color_mid, t * 2.0)
		else:
			# 后半段：橙色→珊瑚粉
			char_color = color_mid.lerp(color_end, (t - 0.5) * 2.0)

		var main_label = Label.new()
		main_label.text = char
		main_label.add_theme_font_size_override("font_size", font_size)
		main_label.add_theme_color_override("font_color", char_color)
		main_label.add_theme_constant_override("outline_size", 3)
		main_label.add_theme_color_override("font_outline_color", outline_color)
		main_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.05, 0.0, 0.5))
		main_label.add_theme_constant_override("shadow_offset_x", 2)
		main_label.add_theme_constant_override("shadow_offset_y", 2)
		main_label.anchors_preset = Control.PRESET_TOP_LEFT
		main_label.position = Vector2(current_x, start_y)
		main_label.size = Vector2(char_w, text_size.y)
		current_x += char_w
		control.add_child(main_label)

	# 添加到场景树以触发渲染
	if mesh_instance and mesh_instance.get_parent():
		mesh_instance.get_parent().add_child(viewport)
		viewport.set_meta("auto_cleanup", true)
	else:
		var root = get_tree().current_scene
		if root:
			root.add_child(viewport)
			viewport.set_meta("auto_cleanup", true)

	return viewport.get_texture()


## 获取命运骰子贴图路径
func _get_destiny_texture_path(texture_value: String) -> String:
	if texture_value.begins_with("destiny_type_"):
		# 类型贴图：destiny_type_1 -> combat.png 等
		var type_id = int(texture_value.substr(11))
		var texture_name = ""
		match type_id:
			1: texture_name = "combat"
			2: texture_name = "encounter"
			3: texture_name = "trade"
			4: texture_name = "reward"
			5: texture_name = "elite"
			99: texture_name = "boss"
			_: texture_name = "combat"
		return "res://textures/destiny/" + texture_name + ".png"
	elif texture_value.begins_with("boss_"):
		# Boss 贴图：boss_1001 -> res://textures/destiny/boss_1001.png
		# 注意：Boss 贴图可能需要特殊处理，这里使用通用 Boss 贴图或节点 ID
		var boss_id = texture_value.substr(5)  # 移除 "boss_" 前缀
		var specific_boss_path = "res://textures/destiny/boss_" + boss_id + ".png"
		if ResourceLoader.exists(specific_boss_path):
			return specific_boss_path
		# 没有专属贴图时，使用通用 Boss 贴图
		return "res://textures/destiny/boss.png"
	return ""


## 获取命运骰子备用颜色
func _get_destiny_color(texture_value: String, destiny_colors: Dictionary, boss_color: Color) -> Color:
	if texture_value in destiny_colors:
		return destiny_colors[texture_value]
	elif texture_value.begins_with("boss_"):
		return boss_color
	return Color(0.5, 0.5, 0.5)  # 默认灰色


## 应用材质到网格
func _apply_materials_to_mesh(mesh_instance: MeshInstance3D, materials: Array):
	var surface_count = mesh_instance.mesh.get_surface_count()
	print("【贴图管理器】网格表面数：", surface_count, ", 需要材质数：", materials.size())
	print("【贴图管理器】网格类型：", mesh_instance.mesh.get_class())
	
	if surface_count >= 6:
		for i in range(6):
			if i < surface_count:
				mesh_instance.mesh.surface_set_material(i, materials[i])
				print("【贴图管理器】应用材质 ", i, " 到表面 ", i)
		print("【贴图管理器】贴图应用完成，表面数=", surface_count)
	else:
		print("【贴图管理器】警告：网格表面数不足 6，使用第一个材质")
		mesh_instance.material_override = materials[0]


## 获取贴图（带缓存）
func get_texture(path: String) -> Texture2D:
	"""
	从缓存获取贴图，如果缓存中没有则加载
	@param path 贴图路径
	@return Texture2D 贴图对象
	"""
	if texture_cache.has(path):
		return texture_cache[path]
	
	# 缓存中没有，尝试加载
	if ResourceLoader.exists(path):
		var texture = load(path)
		if texture:
			texture_cache[path] = texture
			return texture
	
	return null


## 清除贴图缓存
func clear_cache():
	texture_cache.clear()
	print("【贴图管理器】缓存已清除")


## 应用贴图（旧接口，兼容策略模式）
func apply_textures(dice: BaseDice, config: Dictionary):
	var strategy = strategies.get(dice.dice_type)
	if strategy:
		var mesh_instance = dice.get_node("MeshInstance3D")
		if mesh_instance:
			strategy.apply_textures(mesh_instance, config)
			print("应用贴图策略：", BaseDice.DiceType.keys()[dice.dice_type])
	else:
		print("警告：未找到贴图策略，类型：", BaseDice.DiceType.keys()[dice.dice_type])


## 获取策略
func get_strategy(type: BaseDice.DiceType) -> RefCounted:
	return strategies.get(type)


## 取消注册策略
func unregister_strategy(type: BaseDice.DiceType):
	if strategies.has(type):
		strategies.erase(type)
		print("取消注册贴图策略：", BaseDice.DiceType.keys()[type])
