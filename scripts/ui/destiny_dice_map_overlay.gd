extends Control
## 命运骰子地图覆盖层 UI
## 显示关卡地图和当前节点位置
## 使用 Control 直接绘制，拖动时更新 offset 并重绘

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
var canvas: Control  # 画布

# 拖动相关
var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var canvas_offset: Vector2 = Vector2.ZERO

# 地图尺寸
var map_width: float = 0.0
var map_height: float = 0.0

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


func _ready():
	# 设置覆盖层布局（Godot 4.x 使用锚点预设）
	anchors_preset = Control.PRESET_FULL_RECT
	grow_horizontal = 2  # GROW_BOTH_ENDS
	grow_vertical = 2  # GROW_BOTH_ENDS

	# 设置 clip_contents 为 false，允许绘制内容超出边界
	clip_contents = false

	# 延迟初始化（确保场景树完全加载）
	call_deferred("_initialize_deferred")


## 延迟初始化
func _initialize_deferred():
	_create_ui()
	# 连接 canvas 拖动事件
	if canvas:
		canvas.gui_input.connect(_on_canvas_gui_input)
		if not canvas.is_connected("draw", _on_canvas_draw):
			canvas.connect("draw", _on_canvas_draw)


## 初始化地图
func initialize(p_level_data: LevelData, p_current_node: LevelNode):
	level_data = p_level_data
	current_node = p_current_node

	# 确保 UI 已经创建
	if not canvas:
		_create_ui()
		# 连接 canvas 拖动事件
		if canvas:
			canvas.gui_input.connect(_on_canvas_gui_input)
		if not canvas.is_connected("draw", _on_canvas_draw):
			canvas.connect("draw", _on_canvas_draw)

	# 计算节点位置
	if level_data:
		_calculate_node_positions()
		_update_canvas_size()
		# 重绘地图
		if canvas:
			canvas.queue_redraw()
		# 设置初始位置（让当前节点显示在屏幕偏左）
		_center_map()

	print("[MapOverlay] 初始化完成")


## 创建 UI 组件
func _create_ui():
	# 获取屏幕尺寸，用于居中计算
	var screen_size = get_viewport_rect().size

	# 创建信息标签
	info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.position = Vector2(20, 15)
	info_label.size = Vector2(380, 40)
	info_label.text = "命运骰子测试 - 按 M 键切换地图"
	info_label.add_theme_font_size_override("font_size", 14)
	add_child(info_label)

	# 创建蓄力标签
	charge_label = Label.new()
	charge_label.name = "ChargeLabel"
	charge_label.position = Vector2(20, 370)
	charge_label.size = Vector2(380, 30)
	charge_label.text = "蓄力：0%"
	charge_label.add_theme_font_size_override("font_size", 16)
	add_child(charge_label)

	# 创建画布（直接绘制地图）
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.position = Vector2.ZERO
	canvas.custom_minimum_size = Vector2(400, 300)  # 初始尺寸，后续会更新
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP  # 捕获鼠标事件进行拖动
	canvas.anchors_preset = Control.PRESET_TOP_LEFT  # 不跟随父节点调整
	add_child(canvas)

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

	print("[MapOverlay] 地图边界：[", min_x, ", ", max_x, "] x [", min_y, ", ", max_y, "]")


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

	# 应用 offset
	if canvas:
		canvas.queue_redraw()

	print("[MapOverlay] 地图已居中，地图尺寸：", map_width, "x", map_height)
	print("[MapOverlay] canvas_offset：", canvas_offset)
	print("[MapOverlay] 屏幕尺寸：", screen_size)


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
	# 节点坐标可能有负值（min_y 可能是负数）
	# 所以地图总高度是 max_y - min_y + padding
	map_width = max_x - min_x + layer_padding * 2
	map_height = max_y - min_y + layer_padding * 2

	# 设置 canvas 尺寸
	if canvas:
		canvas.custom_minimum_size = Vector2(map_width, map_height)
		canvas.size = Vector2(map_width, map_height)

	print("[MapOverlay] 画布尺寸设置为：", Vector2(map_width, map_height))
	print("[MapOverlay] 地图边界：[", min_x, ", ", max_x, "] x [", min_y, ", ", max_y, "]")


## 画布绘制回调
func _on_canvas_draw():
	if not level_data:
		return

	var min_x = get_meta("map_min_x")
	var min_y = get_meta("map_min_y")

	# 绘制连接线
	for map_node in level_data.nodes:
		for next_id in map_node.connections:
			var next_node = level_data.get_node(next_id)
			if next_node:
				var start_pos = map_node.get_meta("original_position")
				var end_pos = next_node.get_meta("original_position")

				# 转换为 canvas 坐标（带 offset）
				var start_canvas_x = start_pos.x - min_x + layer_padding + canvas_offset.x
				var start_canvas_y = start_pos.y - min_y + layer_padding + canvas_offset.y
				var end_canvas_x = end_pos.x - min_x + layer_padding + canvas_offset.x
				var end_canvas_y = end_pos.y - min_y + layer_padding + canvas_offset.y

				# 绘制连接线
				canvas.draw_line(
					Vector2(start_canvas_x, start_canvas_y),
					Vector2(end_canvas_x, end_canvas_y),
					Color.WHITE, 2
				)

				# 绘制箭头
				_draw_arrow(
					Vector2(start_canvas_x, start_canvas_y),
					Vector2(end_canvas_x, end_canvas_y)
				)

	# 绘制节点
	for map_node in level_data.nodes:
		var pos = map_node.get_meta("original_position")
		var canvas_x = pos.x - min_x + layer_padding + canvas_offset.x
		var canvas_y = pos.y - min_y + layer_padding + canvas_offset.y

		var color = TYPE_COLORS.get(map_node.type, Color.WHITE)
		var is_current = (current_node != null and current_node.id == map_node.id)

		# 计算节点区域（圆角矩形）
		var rect_size = Vector2(node_radius * 2.5, node_radius * 1.8)
		var rect_pos = Vector2(canvas_x - rect_size.x / 2, canvas_y - rect_size.y / 2)
		var rect = Rect2(rect_pos, rect_size)

		if is_current:
			# 当前节点：多层高亮效果
			var glow_rects = [
				Rect2(rect_pos - Vector2(8, 8), rect_size + Vector2(16, 16)),
				Rect2(rect_pos - Vector2(5, 5), rect_size + Vector2(10, 10)),
				Rect2(rect_pos - Vector2(2, 2), rect_size + Vector2(4, 4))
			]
			var glow_alphas = [0.15, 0.25, 0.4]
			for i in range(glow_rects.size()):
				var glow_rect = glow_rects[i]
				var glow_color = CURRENT_NODE_GLOW_COLOR
				glow_color.a = glow_alphas[i]
				canvas.draw_rect(glow_rect, glow_color, true)

			# 绘制节点底色
			canvas.draw_rect(rect, CURRENT_NODE_COLOR, true)
			# 绘制多层边框
			canvas.draw_rect(rect, Color(1, 0.85, 0), false, CURRENT_NODE_BORDER_WIDTH)
			canvas.draw_rect(rect, Color.WHITE, false, 2)

			# 绘制"当前"标记
			_draw_current_marker(Vector2(canvas_x, canvas_y - rect_size.y / 2 - 10), rect_size)
		else:
			# 普通节点
			canvas.draw_rect(rect, Color.BLACK, false, 2)
			canvas.draw_rect(rect, color, true)

		# 绘制节点 ID 和类型名称
		var font = ThemeDB.fallback_font
		if font:
			var id_text = "#" + str(map_node.id)
			var type_name = map_node.get_type_name()
			var type_text_size = font.get_string_size(type_name)
			var id_text_size = font.get_string_size(id_text)
			var total_height = font.get_height() * 2 + 2
			var max_width = maxf(type_text_size.x, id_text_size.x)

			var text_start_x = canvas_x - max_width / 2
			var text_start_y = canvas_y - total_height / 2 + font.get_ascent()

			# 绘制类型名称
			var type_pos = Vector2(text_start_x, text_start_y)
			canvas.draw_string(font, type_pos, type_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.BLACK)

			# 绘制节点 ID
			var id_pos = Vector2(text_start_x, text_start_y + font.get_height() + 2)
			canvas.draw_string(font, id_pos, id_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.BLACK)


## 绘制箭头
func _draw_arrow(start: Vector2, end: Vector2):
	var dir = (end - start).normalized()
	var arrow_size = 8.0
	var arrow_angle = PI / 6

	var arrow_point = end
	var arrow_left = arrow_point - dir.rotated(arrow_angle) * arrow_size
	var arrow_right = arrow_point - dir.rotated(-arrow_angle) * arrow_size

	canvas.draw_colored_polygon(
		[arrow_point, arrow_left, arrow_right],
		Color.WHITE
	)


## 绘制当前节点标记
func _draw_current_marker(marker_pos: Vector2, rect_size: Vector2):
	var marker_size = 8.0

	# 绘制星形
	var points = []
	for i in range(5):
		var angle = i * 4 * PI / 5 - PI / 2
		var outer_point = Vector2(
			marker_pos.x + cos(angle) * marker_size,
			marker_pos.y + sin(angle) * marker_size
		)
		points.append(outer_point)

		var inner_angle = angle + 2 * PI / 10
		var inner_point = Vector2(
			marker_pos.x + cos(inner_angle) * marker_size * 0.5,
			marker_pos.y + sin(inner_angle) * marker_size * 0.5
		)
		points.append(inner_point)

	# 绘制星形
	canvas.draw_colored_polygon(points, Color(1, 1, 0.5))

	# 绘制"当前"文字
	var font = ThemeDB.fallback_font
	if font:
		var label = "当前"
		var label_size = font.get_string_size(label)
		var label_pos = Vector2(
			marker_pos.x - label_size.x / 2,
			marker_pos.y - marker_size - 8
		)
		canvas.draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1, 1, 0.5))


## Canvas 拖动处理
func _on_canvas_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_position = event.position - canvas_offset
			else:
				is_dragging = false

	elif event is InputEventMouseMotion:
		if is_dragging:
			canvas_offset = event.position - drag_start_position
			if canvas:
				canvas.queue_redraw()


## 更新当前节点（需要重新绘制地图）
func update_current_node(new_current_node: LevelNode):
	current_node = new_current_node

	# 更新信息标签
	if info_label:
		info_label.text = "当前节点：" + current_node.name + " (类型：" + current_node.get_type_name() + ")"

	# 重新绘制地图（因为当前节点的高亮会变化）
	if canvas:
		canvas.queue_redraw()

	print("[MapOverlay] 更新当前节点：", current_node.id)


## 更新蓄力显示
func update_charge(charge_ratio: float):
	if charge_label:
		charge_label.text = "蓄力：%d%%" % int(charge_ratio * 100)
