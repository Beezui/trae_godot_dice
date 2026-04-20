extends Control
## 命运骰子地图覆盖层 UI
## 显示关卡地图和当前节点位置

# 配置
var level_data: LevelData = null
var current_node: LevelNode = null
var node_radius: float = 25.0
var node_spacing_x: float = 150.0
var node_spacing_y: float = 100.0
var layer_padding: float = 80.0

# UI 组件
var canvas: Control
var info_label: Label
var map_panel: Panel
var charge_label: Label  # 蓄力标签

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
const CURRENT_NODE_BORDER_WIDTH = 4.0


func _ready():
	# 设置覆盖层布局（Godot 4.x 使用锚点预设）
	anchors_preset = Control.PRESET_FULL_RECT
	grow_horizontal = 2  # GROW_BOTH_ENDS
	grow_vertical = 2  # GROW_BOTH_ENDS


## 初始化地图
func initialize(p_level_data: LevelData, p_current_node: LevelNode):
	level_data = p_level_data
	current_node = p_current_node

	# 创建 UI 组件
	_create_ui()

	# 计算节点位置
	if level_data:
		_calculate_node_positions()
		_update_canvas_size()

	# 强制重绘
	if canvas:
		canvas.queue_redraw()

	print("[MapOverlay] 初始化完成")


## 创建 UI 组件
func _create_ui():
	# 创建背景面板
	map_panel = Panel.new()
	map_panel.name = "MapPanel"
	map_panel.position = Vector2(10, 60)
	map_panel.size = Vector2(400, 300)
	add_child(map_panel)

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

	# 创建画布用于绘制
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.position = map_panel.position + Vector2(10, 10)
	canvas.size = map_panel.size - Vector2(20, 20)
	add_child(canvas)

	# 连接绘制信号（Godot 4.x 方式）
	canvas.connect("draw", _on_canvas_draw)

	print("[MapOverlay] 画布已创建，尺寸：", canvas.size)


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

		# 计算该层节点的 X 位置
		var x_pos = layer_idx * node_spacing_x + layer_padding
		var total_height = (layer_nodes.size() - 1) * node_spacing_y
		var start_y = -total_height / 2.0

		for node_idx in range(layer_nodes.size()):
			var node = layer_nodes[node_idx]
			var y_pos = start_y + node_idx * node_spacing_y
			node.position = Vector2(x_pos, y_pos)


## 更新画布大小
func _update_canvas_size():
	if not level_data or level_data.nodes.size() == 0:
		return

	var max_x = 0.0
	var max_y = 0.0

	for node in level_data.nodes:
		if node.position.x > max_x:
			max_x = node.position.x
		if node.position.y > max_y:
			max_y = node.position.y

	canvas.custom_minimum_size = Vector2(
		max_x + layer_padding * 2,
		max_y + layer_padding * 2
	)


## 绘制地图
func _on_canvas_draw():
	if not level_data:
		return

	# 绘制连接线
	_draw_connections()

	# 绘制节点
	_draw_nodes()


## 绘制连接线
func _draw_connections():
	for node in level_data.nodes:
		for next_id in node.connections:
			var next_node = level_data.get_node(next_id)
			if next_node:
				var start_pos = node.position
				var end_pos = next_node.position

				# 绘制线条
				canvas.draw_line(start_pos, end_pos, Color.WHITE, 2)

				# 绘制箭头
				_draw_arrow(start_pos, end_pos)


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


## 绘制节点
func _draw_nodes():
	for node in level_data.nodes:
		var pos = node.position
		var color = TYPE_COLORS.get(node.type, Color.WHITE)

		# 检查是否是当前节点
		var is_current = (current_node != null and current_node.id == node.id)

		# 计算节点区域（圆角矩形）
		var rect_size = Vector2(node_radius * 2.5, node_radius * 1.8)
		var rect_pos = pos - rect_size / 2

		# 绘制节点背景
		var rect = Rect2(rect_pos, rect_size)

		if is_current:
			# 当前节点：特殊高亮
			canvas.draw_rect(rect, CURRENT_NODE_COLOR, true)
			canvas.draw_rect(rect, Color(1, 0.8, 0), false, CURRENT_NODE_BORDER_WIDTH)
		else:
			# 普通节点
			canvas.draw_rect(rect, Color.BLACK, false, 2)
			canvas.draw_rect(rect, color, true)

		# 绘制节点 ID 和类型名称
		var id_text = "#" + str(node.id)
		var type_name = node.get_type_name()

		var font = ThemeDB.fallback_font
		if font:
			var type_text_size = font.get_string_size(type_name)
			var id_text_size = font.get_string_size(id_text)
			var total_height = font.get_height() * 2 + 2
			var max_width = maxf(type_text_size.x, id_text_size.x)

			var text_start_x = pos.x - max_width / 2
			var text_start_y = pos.y - total_height / 2 + font.get_ascent()

			# 绘制类型名称
			var type_pos = Vector2(text_start_x, text_start_y)
			canvas.draw_string(font, type_pos, type_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.BLACK)

			# 绘制节点 ID
			var id_pos = Vector2(text_start_x, text_start_y + font.get_height() + 2)
			canvas.draw_string(font, id_pos, id_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.BLACK)


## 更新当前节点
func update_current_node(new_current_node: LevelNode):
	current_node = new_current_node

	# 更新信息标签
	if info_label:
		info_label.text = "当前节点：" + current_node.name + " (类型：" + current_node.get_type_name() + ")"

	# 重绘
	if canvas:
		canvas.queue_redraw()

	print("[MapOverlay] 更新当前节点：", current_node.id)


## 更新蓄力显示
func update_charge(charge_ratio: float):
	if charge_label:
		charge_label.text = "蓄力：%d%%" % int(charge_ratio * 100)
