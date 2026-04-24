extends Control
## 命运骰子地图覆盖层 UI
## 显示关卡地图和当前节点位置
## 使用 ImageTexture 预渲染地图，拖动时只更新 TextureRect 位置

# 配置
var level_data: LevelData = null
var current_node: LevelNode = null
var node_radius: float = 25.0
var node_spacing_x: float = 150.0
var node_spacing_y: float = 100.0
var layer_padding: float = 80.0

# UI 组件
var info_label: Label
var charge_label: Label  # 蓄力标签
var canvas: Control  # 画布（用于接收输入）
var map_texture_rect: TextureRect  # 地图纹理显示

# 初始化标志
var ui_created: bool = false  # 防止重复创建 UI

# 拖动相关
var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var canvas_offset: Vector2 = Vector2.ZERO

# 地图尺寸
var map_width: float = 0.0
var map_height: float = 0.0

# 缓存数据（性能优化）
var map_image: Image = null  # 地图图像缓存
var map_texture: ImageTexture = null  # 地图纹理缓存
var is_map_dirty: bool = true  # 标记地图是否需要重绘
var node_positions_cache: Dictionary = {}  # 节点位置缓存
var node_rects_cache: Dictionary = {}  # 节点区域缓存
var text_size_cache: Dictionary = {}  # 文本大小缓存

# 绘制性能优化
const CACHE_TEXT_MEASUREMENTS = true  # 缓存文本测量结果

# 节点类型颜色
const TYPE_COLORS = {
	1: Color(1, 0.3, 0.3),  # 战斗 - 红色
	2: Color(0.3, 0.6, 1),  # 奇遇 - 蓝色
	3: Color(1, 0.8, 0.3),  # 交易 - 黄色
	4: Color(0.3, 1, 0.5),  # 奖励 - 绿色
	5: Color(0.8, 0.2, 0.2),  # 精英战斗 - 深红色
	99: Color(0.5, 0, 0.8)   # Boss - 紫色
}

# 当前节点高亮颜色
const CURRENT_NODE_COLOR = Color(1, 1, 0.3)  # 亮黄色
const CURRENT_NODE_BORDER_WIDTH = 6.0
const CURRENT_NODE_GLOW_COLOR = Color(1, 0.9, 0, 0.5)  # 外发光颜色

# 图像绘制优化
const TEXTURE_FORMAT = Image.FORMAT_RGBA8  # 纹理格式

# 节点图标配置
var node_icons: Dictionary = {}  # 类型 ID -> Image 映射
const ICON_SIZE = Vector2i(32, 32)  # 图标标准尺寸
const ICON_PATH_PREFIX = "res://textures/map/"  # 图标资源路径前缀


func _ready():
	# 设置覆盖层布局（Godot 4.x 使用锚点预设）
	anchors_preset = Control.PRESET_FULL_RECT
	grow_horizontal = 2  # GROW_BOTH
	grow_vertical = 2  # GROW_BOTH
	# 设置 layout_mode 为 0 (Position)，允许子节点自由定位
	layout_mode = 0

	# 设置 clip_contents 为 false，允许绘制内容超出边界
	clip_contents = false

	# 延迟初始化（确保场景树完全加载）
	call_deferred("_initialize_deferred")


## 延迟初始化
func _initialize_deferred():
	_create_ui()
	_load_node_icons()


## 初始化地图
func initialize(p_level_data: LevelData, p_current_node: LevelNode):
	level_data = p_level_data
	current_node = p_current_node

	# 确保图标已加载
	if node_icons.is_empty():
		_load_node_icons()

	# 确保 UI 已经创建
	if not canvas:
		_create_ui()

	# 设置 map_overlay 尺寸为屏幕尺寸
	var viewport_size = get_viewport_rect().size
	custom_minimum_size = viewport_size
	size = viewport_size

	# 计算节点位置
	if level_data:
		_calculate_node_positions()
		_update_canvas_size()
		# 预渲染地图到纹理
		_render_map_to_texture()
		# 设置初始位置（让当前节点显示在屏幕偏左）
		_center_map()


## 加载节点图标
func _load_node_icons():
	# 定义节点类型和图标准文件名
	var icon_files = {
		1: "node_combat.png",    # 战斗
		2: "node_encounter.png", # 奇遇
		3: "node_trade.png",     # 交易
		4: "node_reward.png",    # 奖励
		5: "node_elite.png",     # 精英战斗
		99: "node_boss.png"      # Boss
	}

	for type_id in icon_files:
		var path = ICON_PATH_PREFIX + icon_files[type_id]
		var img = Image.new()
		if ResourceLoader.exists(path):
			img = Image.load_from_file(path)
		else:
			# 创建占位图标（纯色圆）
			img = _create_placeholder_icon(type_id)
		node_icons[type_id] = img


## 创建占位图标（纯色圆）
func _create_placeholder_icon(type_id: int) -> Image:
	var img = Image.create(ICON_SIZE.x, ICON_SIZE.y, false, Image.FORMAT_RGBA8)
	var color = TYPE_COLORS.get(type_id, Color.WHITE)

	# 填充圆形
	for y in range(ICON_SIZE.y):
		for x in range(ICON_SIZE.x):
			var dx = x - ICON_SIZE.x / 2.0
			var dy = y - ICON_SIZE.y / 2.0
			if dx*dx + dy*dy < (ICON_SIZE.x / 2.0 - 1)*(ICON_SIZE.x / 2.0 - 1):
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	return img


## 创建 UI 组件
func _create_ui():
	# 防止重复创建
	if ui_created:
		print("[MapOverlay] UI 已创建，跳过")
		return
	ui_created = true

	# 获取屏幕尺寸，用于居中计算
	var screen_size = get_viewport_rect().size

	# 创建信息标签
	info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.position = Vector2(20, 15)
	info_label.size = Vector2(380, 40)
	info_label.text = "命运骰子测试 - 按 M 键切换地图"
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.layout_mode = 0  # POSITION
	add_child(info_label)

	# 创建蓄力标签
	charge_label = Label.new()
	charge_label.name = "ChargeLabel"
	charge_label.position = Vector2(20, 370)
	charge_label.size = Vector2(380, 30)
	charge_label.text = "蓄力：0%"
	charge_label.add_theme_font_size_override("font_size", 16)
	charge_label.layout_mode = 0  # POSITION
	add_child(charge_label)

	# 创建地图纹理显示（TextureRect）- 直接作为子节点，不使用中间容器
	map_texture_rect = TextureRect.new()
	map_texture_rect.name = "MapTexture"
	map_texture_rect.position = Vector2.ZERO
	# 使用 TOP_LEFT 锚点
	map_texture_rect.anchors_preset = Control.PRESET_TOP_LEFT
	# 设置 layout_mode 为 0 (Position)，允许自由设置位置和尺寸
	map_texture_rect.layout_mode = 0  # POSITION
	map_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP
	map_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不接收鼠标事件
	add_child(map_texture_rect)

	# 创建画布（用于接收鼠标事件）
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.position = Vector2.ZERO
	# 使用 TOP_LEFT 锚点
	canvas.anchors_preset = Control.PRESET_TOP_LEFT
	# 设置 layout_mode 为 0 (Position)，允许自由设置位置和尺寸
	canvas.layout_mode = 0  # POSITION
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP  # 捕获鼠标事件进行拖动
	# 设置初始尺寸（会在 _update_canvas_size 中更新为实际地图尺寸）
	canvas.custom_minimum_size = Vector2(100, 100)
	canvas.size = Vector2(100, 100)
	add_child(canvas)

	# 连接 canvas 拖动事件
	canvas.gui_input.connect(_on_canvas_gui_input)

	# 设置 z_index，确保 map_texture_rect 在 canvas 上方渲染
	map_texture_rect.z_index = 1
	canvas.z_index = 0

	print("[MapOverlay] UI 创建完成")


## 计算节点位置
func _calculate_node_positions():
	if not level_data:
		return

	var layers_dict = {}

	# 按层级分组
	for node in level_data.nodes:
		var layer = node.layer
		if layer not in layers_dict:
			layers_dict[layer] = []
		layers_dict[layer].append(node)

	# 计算每层的位置
	var layers = layers_dict.keys()
	layers.sort()

	for layer_idx in range(layers.size()):
		var layer = layers[layer_idx]
		var layer_nodes = layers_dict[layer]

		# 按 ID 排序
		layer_nodes.sort_custom(func(a, b): return int(a.id) < int(b.id))

		# 计算该层节点的 X 位置（从 layer_padding 开始）
		var x_pos = layer_idx * node_spacing_x + layer_padding
		var total_height = (layer_nodes.size() - 1) * node_spacing_y
		var start_y = -total_height / 2.0

		for node_idx in range(layer_nodes.size()):
			var node = layer_nodes[node_idx]
			var y_pos = start_y + node_idx * node_spacing_y
			var original_pos = Vector2(x_pos, y_pos)
			node.position = original_pos

			# 保存原始位置（用于后续滚动计算）
			node.set_meta("original_position", original_pos)

	# 所有节点位置计算完成后，保存地图边界信息用于绘制转换
	_calculate_map_bounds()


## 计算地图边界（用于绘制坐标转换）
func _calculate_map_bounds():
	if not level_data or level_data.nodes.size() == 0:
		return

	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for node in level_data.nodes:
		var pos = node.get_meta("original_position")
		if not pos:
			pos = node.position
		if pos.x < min_x:
			min_x = pos.x
		if pos.x > max_x:
			max_x = pos.x
		if pos.y < min_y:
			min_y = pos.y
		if pos.y > max_y:
			max_y = pos.y

	# 保存边界信息
	set_meta("map_min_x", min_x)
	set_meta("map_max_x", max_x)
	set_meta("map_min_y", min_y)
	set_meta("map_max_y", max_y)


## 中心地图（使用 canvas_offset 来调整显示位置）
func _center_map():
	if not level_data or level_data.nodes.size() == 0:
		return

	# 计算地图的边界（使用原始位置）
	var min_x = get_meta("map_min_x")
	var max_x = get_meta("map_max_x")
	var min_y = get_meta("map_min_y")
	var max_y = get_meta("map_max_y")

	# 计算地图尺寸
	var map_width = max_x - min_x + layer_padding * 2
	var map_height = max_y - min_y + layer_padding * 2

	# 获取屏幕尺寸
	var screen_size = get_viewport_rect().size

	# 获取当前节点位置（使用原始位置）
	var current_node_pos = Vector2(0, 0)
	if current_node:
		if current_node.has_meta("original_position"):
			current_node_pos = current_node.get_meta("original_position")
		else:
			current_node_pos = current_node.position
			print("[MapOverlay] 当前节点未找到原始位置，使用默认位置：", current_node_pos)

	# 计算当前节点在地图中的位置（相对于地图左上角）
	var node_in_map_x = current_node_pos.x - min_x + layer_padding
	var node_in_map_y = current_node_pos.y - min_y + layer_padding

	# 水平方向：让当前节点显示在屏幕偏左位置（约 1/4 处）
	var target_x_on_screen = screen_size.x * 0.25
	canvas_offset.x = target_x_on_screen - node_in_map_x

	# 垂直方向：让地图中心对齐屏幕中心
	var target_y_on_screen = screen_size.y * 0.6
	canvas_offset.y = target_y_on_screen - (map_height / 2)

	# 应用 offset（更新 TextureRect 位置）
	_update_map_position()


## 更新画布大小
func _update_canvas_size():
	if not level_data or level_data.nodes.size() == 0:
		return

	var max_x = -INF
	var max_y = -INF
	var min_x = INF
	var min_y = INF

	for node in level_data.nodes:
		# 使用原始位置计算边界
		var pos = node.get_meta("original_position")
		if pos:
			if pos.x > max_x:
				max_x = pos.x
			if pos.x < min_x:
				min_x = pos.x
			if pos.y > max_y:
				max_y = pos.y
			if pos.y < min_y:
				min_y = pos.y

	# 计算地图实际尺寸（考虑负坐标和 padding）
	map_width = max_x - min_x + layer_padding * 2
	map_height = max_y - min_y + layer_padding * 2

	# 设置 canvas 尺寸
	if canvas:
		canvas.set_size(Vector2(map_width, map_height))
		canvas.set_position(Vector2.ZERO)
		canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		canvas.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# 设置 map_texture_rect 尺寸
	if map_texture_rect:
		map_texture_rect.set_size(Vector2(map_width, map_height))
		map_texture_rect.set_position(Vector2.ZERO)
		map_texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		map_texture_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


## 预渲染地图到纹理（核心优化）
func _render_map_to_texture():
	if not level_data or level_data.nodes.size() == 0:
		return

	var min_x = get_meta("map_min_x")
	var min_y = get_meta("map_min_y")

	# 创建图像（使用地图尺寸）
	var render_width = int(map_width)
	var render_height = int(map_height)

	if render_width <= 0 or render_height <= 0:
		return

	# 创建 Image 对象
	map_image = Image.create(render_width, render_height, false, TEXTURE_FORMAT)
	map_image.fill(Color(0, 0, 0, 0))  # 透明背景

	# 使用 Image 直接绘制
	_render_map_to_image(map_image, min_x, min_y)

	# 创建纹理（ImageTexture 是 RefCounted，不能用 free()，直接赋 null 释放）
	map_texture = null
	map_texture = ImageTexture.create_from_image(map_image)

	# 应用到 TextureRect
	if map_texture_rect:
		map_texture_rect.texture = map_texture
		# 设置 custom_minimum_size 和 size，确保 TextureRect 正确显示
		map_texture_rect.custom_minimum_size = Vector2(render_width, render_height)
		map_texture_rect.size = Vector2(render_width, render_height)

	is_map_dirty = false


## 渲染地图到 Image
func _render_map_to_image(img: Image, p_min_x: float, p_min_y: float):
	var font = ThemeDB.fallback_font

	# 1. 绘制连接线
	for map_node in level_data.nodes:
		for next_id in map_node.connections:
			var next_node = level_data.get_node(next_id)
			if next_node:
				var start_pos = map_node.get_meta("original_position")
				var end_pos = next_node.get_meta("original_position")

				# 转换为图像坐标
				var start_x = int(start_pos.x - p_min_x + layer_padding)
				var start_y = int(start_pos.y - p_min_y + layer_padding)
				var end_x = int(end_pos.x - p_min_x + layer_padding)
				var end_y = int(end_pos.y - p_min_y + layer_padding)

				# 绘制连线
				_draw_line_on_image(img, start_x, start_y, end_x, end_y, Color.WHITE, 2)

				# 绘制箭头
				_draw_arrow_on_image(img, start_x, start_y, end_x, end_y, font)

	# 2. 缓存节点数据并绘制节点
	node_positions_cache.clear()
	node_rects_cache.clear()

	for map_node in level_data.nodes:
		var pos = map_node.get_meta("original_position")
		var node_x = int(pos.x - p_min_x + layer_padding)
		var node_y = int(pos.y - p_min_y + layer_padding)

		# 缓存位置
		node_positions_cache[map_node.id] = Vector2i(node_x, node_y)

		var color = TYPE_COLORS.get(map_node.type, Color.WHITE)
		var is_current = (current_node != null and current_node.id == map_node.id)

		# 计算节点区域（使用 Vector2i 用于图像绘制）
		var rect_size = Vector2i(int(node_radius * 2.5), int(node_radius * 1.8))
		var rect_pos = Vector2i(node_x - rect_size.x / 2, node_y - rect_size.y / 2)
		var rect = Rect2i(rect_pos, rect_size)

		# 缓存区域
		node_rects_cache[map_node.id] = {"rect": rect, "rect_size": rect_size}

		if is_current:
			# 当前节点：多层高亮效果（外发光）
			for i in range(3):
				var glow_size = [16, 10, 4][i]
				var glow_alpha = [0.15, 0.25, 0.4][i]
				var glow_rect = Rect2i(
					rect_pos - Vector2i(glow_size, glow_size),
					rect_size + Vector2i(glow_size * 2, glow_size * 2)
				)
				var glow_color = CURRENT_NODE_GLOW_COLOR
				glow_color.a = glow_alpha
				_draw_rect_on_image(img, glow_rect, glow_color, true)

			# 绘制多层边框（直接绘制在图标外）
			_draw_rect_on_image(img, rect, Color(1, 0.85, 0), false, CURRENT_NODE_BORDER_WIDTH)
			_draw_rect_on_image(img, rect, Color.WHITE, false, 2)

			# 绘制图标
			var icon = _get_node_icon(map_node.type)
			if icon:
				var icon_rect = _get_icon_rect(rect, icon.get_size())
				img.blit_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), icon_rect.position)

			# 绘制"当前"标记
			_draw_current_marker_on_image(img, Vector2i(node_x, node_y - rect_size.y / 2 - 10), rect_size, font)
		else:
			# 普通节点：只绘制边框和图标，不绘制底色
			_draw_rect_on_image(img, rect, Color.BLACK, false, 2)

			# 绘制图标
			var icon = _get_node_icon(map_node.type)
			if icon:
				var icon_rect = _get_icon_rect(rect, icon.get_size())
				img.blit_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), icon_rect.position)

		# 绘制节点 ID 和类型名称（暂时移除，因为 Font.draw_string 不能直接绘制到 Image）
		# 如需要文本，后续使用 TextureButton 或 Label 覆盖显示


## 获取节点图标
func _get_node_icon(type_id: int) -> Image:
	return node_icons.get(type_id, null)


## 计算图标在节点矩形中的位置（居中）
func _get_icon_rect(node_rect: Rect2i, icon_size: Vector2i) -> Rect2i:
	var icon_x = node_rect.position.x + (node_rect.size.x - icon_size.x) / 2
	var icon_y = node_rect.position.y + (node_rect.size.y - icon_size.y) / 2
	return Rect2i(Vector2i(icon_x, icon_y), icon_size)


## 在 Image 上绘制线
func _draw_line_on_image(img: Image, x1: int, y1: int, x2: int, y2: int, color: Color, width: int):
	# 使用 Bresenham 算法绘制线
	var dx = abs(x2 - x1)
	var dy = abs(y2 - y1)
	var sx = 1 if x1 < x2 else -1
	var sy = 1 if y1 < y2 else -1
	var err = dx - dy

	while true:
		for wx in range(-width/2, width/2 + 1):
			for wy in range(-width/2, width/2 + 1):
				if wx*wx + wy*wy <= width*width/4:
					img.set_pixel(x1 + int(wx), y1 + int(wy), color)

		if x1 == x2 and y1 == y2:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x1 += sx
		if e2 < dx:
			err += dx
			y1 += sy


## 在 Image 上绘制矩形
func _draw_rect_on_image(img: Image, rect: Rect2i, color: Color, filled: bool, border_width: float = 1.0):
	if filled:
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
					img.set_pixel(x, y, color)
	else:
		# 绘制边框
		var bw = int(border_width)
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				var is_border = (x - rect.position.x < bw or
					rect.position.x + rect.size.x - x <= bw or
					y - rect.position.y < bw or
					rect.position.y + rect.size.y - y <= bw)
				if is_border and x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
					img.set_pixel(x, y, color)


## 在 Image 上绘制箭头
func _draw_arrow_on_image(img: Image, start_x: int, start_y: int, end_x: int, end_y: int, font: Font = null):
	var dir = Vector2(end_x - start_x, end_y - start_y).normalized()
	var arrow_size = 8.0
	var arrow_angle = PI / 6

	var arrow_point = Vector2(end_x, end_y)
	var arrow_left = arrow_point - dir.rotated(arrow_angle) * arrow_size
	var arrow_right = arrow_point - dir.rotated(-arrow_angle) * arrow_size

	# 绘制三角形
	var points = [arrow_point, arrow_left, arrow_right]
	for i in range(3):
		var next_i = (i + 1) % 3
		_fill_triangle_on_image(img, points[i], points[next_i], arrow_point, Color.WHITE)


## 在 Image 上填充三角形
func _fill_triangle_on_image(img: Image, p1: Vector2i, p2: Vector2i, p3: Vector2i, color: Color):
	var points = [p1, p2, p3]
	points.sort_custom(func(a, b): return a.y < b.y)

	var min_y = int(points[0].y)
	var max_y = int(ceil(points[2].y))

	for y in range(min_y, max_y + 1):
		var intersections = []
		for i in range(3):
			var j = (i + 1) % 3
			if (points[i].y <= y and points[j].y > y) or (points[j].y <= y and points[i].y > y):
				var t = (y - points[i].y) / (points[j].y - points[i].y)
				var x = points[i].x + t * (points[j].x - points[i].x)
				intersections.append(x)

		if intersections.size() >= 2:
			intersections.sort()
			for x in range(int(ceil(intersections[0])), int(floor(intersections[-1])) + 1):
				if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
					img.set_pixel(x, y, color)


## 在 Image 上绘制当前节点标记
func _draw_current_marker_on_image(img: Image, marker_pos: Vector2i, rect_size: Vector2i, font: Font):
	var marker_size = 8.0
	var center = marker_pos

	# 生成星形的 10 个顶点
	var vertices = []
	for i in range(5):
		var angle = i * 2 * PI / 5 - PI / 2
		var outer_point = Vector2i(
			int(center.x + cos(angle) * marker_size),
			int(center.y + sin(angle) * marker_size)
		)
		vertices.append(outer_point)

		var inner_angle = angle + PI / 5
		var inner_point = Vector2i(
			int(center.x + cos(inner_angle) * marker_size * 0.5),
			int(center.y + sin(inner_angle) * marker_size * 0.5)
		)
		vertices.append(inner_point)

	# 使用三角形扇绘制星形
	for i in range(vertices.size()):
		var next_i = (i + 1) % vertices.size()
		_fill_triangle_on_image(img,
			center,
			vertices[i],
			vertices[next_i],
			Color(1, 1, 0.5)
		)

	# 绘制"当前"文字暂时移除，因为 Font.draw_string 需要 CanvasItem，不能直接绘制到 Image
	# 后续如需文本，使用 Label 节点 overlay 显示


## 在 Image 上绘制节点文本
func _draw_node_text_on_image(img: Image, map_node: LevelNode, node_x: int, node_y: int, rect_size: Vector2i, font: Font):
	var cache_key = str(map_node.id)

	# 使用缓存或计算文本大小
	var type_text_size = Vector2.ZERO
	var id_text_size = Vector2.ZERO
	if CACHE_TEXT_MEASUREMENTS and text_size_cache.has(cache_key):
		var cached = text_size_cache[cache_key]
		type_text_size = cached.type
		id_text_size = cached.id
	else:
		var id_text = "#" + str(map_node.id)
		var type_name = map_node.get_type_name()
		type_text_size = font.get_string_size(type_name)
		id_text_size = font.get_string_size(id_text)
		if CACHE_TEXT_MEASUREMENTS:
			text_size_cache[cache_key] = {"type": type_text_size, "id": id_text_size}

	var total_height = font.get_height() * 2 + 2
	var max_width = maxf(type_text_size.x, id_text_size.x)

	var text_start_x = int(node_x - max_width / 2)
	var text_start_y = int(node_y - total_height / 2 + font.get_ascent())

	# 绘制类型名称
	var type_pos = Vector2i(text_start_x, text_start_y)
	_draw_text_on_image(img, map_node.get_type_name(), type_pos, font, Color.BLACK, 14)

	# 绘制节点 ID
	var id_pos = Vector2i(text_start_x, text_start_y + font.get_height() + 2)
	_draw_text_on_image(img, "#" + str(map_node.id), id_pos, font, Color.BLACK, 10)


## 在 Image 上绘制文本（简化版，使用 Font）
func _draw_text_on_image(img: Image, text: String, pos: Vector2i, font: Font, color: Color, font_size: int):
	if font == null or text == "":
		return

	# 使用 Godot 的 Font 绘制文本到 Image
	font.draw_string(img, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Canvas 拖动处理
func _on_canvas_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				# 保存鼠标按下时的偏移量（鼠标位置相对于 canvas 左上角的偏移）
				drag_start_position = get_local_mouse_position() - canvas.position
			else:
				is_dragging = false

	elif event is InputEventMouseMotion:
		if is_dragging:
			var mouse_pos = get_local_mouse_position()
			# canvas 位置 = 鼠标位置 - 拖动开始时的偏移量
			canvas_offset = mouse_pos - drag_start_position
			_update_map_position()


## 拖动结束处理
func _on_drag_ended():
	# 拖动结束后，如果需要可以重新渲染高清地图
	# 当前实现使用静态纹理，所以不需要额外操作
	pass


## 更新地图位置（只更新 canvas 和 texture 位置，不重新渲染）
func _update_map_position():
	# 设置 canvas 和 map_texture_rect 的位置
	if canvas:
		canvas.set_position(canvas_offset)
		canvas.layout_mode = 0  # POSITION
	if map_texture_rect:
		map_texture_rect.set_position(canvas_offset)
		map_texture_rect.layout_mode = 0  # POSITION

	# 强制在下一帧再次设置位置，防止布局系统覆盖
	call_deferred("_force_position_after_layout")


## 强制设置位置（在布局完成后调用）
func _force_position_after_layout():
	if canvas:
		canvas.set_position(canvas_offset)
	if map_texture_rect:
		map_texture_rect.set_position(canvas_offset)


## 更新当前节点（需要重新绘制地图）
func update_current_node(new_current_node: LevelNode):
	current_node = new_current_node

	# 更新信息标签
	if info_label:
		info_label.text = "当前节点：" + current_node.name + " (类型：" + current_node.get_type_name() + ")"

	# 重新渲染地图（因为当前节点的高亮会变化）
	_render_map_to_texture()


## 更新蓄力显示
func update_charge(charge_ratio: float):
	if charge_label:
		charge_label.text = "蓄力：%d%%" % int(charge_ratio * 100)
