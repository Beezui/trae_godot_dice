extends Node3D

## 控制投掷结果测试脚本
## 附加到 dice_demo_simple_final 场景，用于实验性地测试骰子结果控制系统
## 使用方法：按数字键 1-6 设置想要的结果，然后正常蓄力投掷

@onready var dice_manager = $DiceManager
@onready var charge_label = $ChargeLabel
@onready var result_label = $ResultLabel

var start_timer: Timer
var is_charging = false
var original_positions = {}
var base_width = 24.0
var base_height = 13.5
var is_in_initial_state = true
var global_time = 0.0

# 控制结果：0 表示未设置（默认随机）
var controlled_result = 0

func _ready():
	print("=== 控制投掷结果测试场景初始化 ===")

	# 注册摄像机
	var camera = $Camera3D
	if camera:
		CameraManager.register_camera(camera)

	# 调整光照
	var light = $DirectionalLight3D
	if light:
		light.look_at_from_position(light.position, Vector3(0, 0, 0), Vector3(0, 1, 0))

	# 设置沙盘
	var sandbox = $Sandbox
	if sandbox:
		_setup_sandbox(sandbox)

	# 调整重力
	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)

	# 创建启动计时器
	start_timer = Timer.new()
	start_timer.wait_time = 1.0
	start_timer.one_shot = true
	start_timer.timeout.connect(_on_start_timer_timeout)
	add_child(start_timer)
	start_timer.start()

	# 创建结果显示 Label3D（如果不存在）
	if not result_label:
		result_label = Label3D.new()
		result_label.name = "ResultLabel"
		result_label.position = Vector3(0, 12, 0)
		result_label.text = "按 1-6 设置结果"
		result_label.font_size = 24
		add_child(result_label)

	print("=== 初始化完成，按 1-6 选择结果，空格蓄力投掷 ===")


func _setup_sandbox(sandbox: Node3D):
	var base_ratio = 16.0 / 9.0
	var sandbox_width = base_width
	var sandbox_height = sandbox_width / base_ratio

	var ground_collision = sandbox.get_node("Ground")
	if ground_collision:
		var ground_shape = BoxShape3D.new()
		ground_shape.size = Vector3(sandbox_width, 0.1, sandbox_height)
		ground_collision.shape = ground_shape

	var ground_physics_material = PhysicsMaterial.new()
	ground_physics_material.bounce = 0.3
	ground_physics_material.friction = 0.8
	sandbox.physics_material_override = ground_physics_material

	var ground_mesh = sandbox.get_node("GroundMesh")
	if ground_mesh:
		var ground_mesh_resource = BoxMesh.new()
		ground_mesh_resource.size = Vector3(sandbox_width, 0.1, sandbox_height)
		ground_mesh.mesh = ground_mesh_resource
		var ground_material = StandardMaterial3D.new()
		ground_material.albedo_color = Color(0.5, 0.5, 0.5, 1)
		ground_mesh.material_override = ground_material

	# 四面墙
	var wall_configs = [
		{"name": "WallNorth", "pos": Vector3(0, 21, -sandbox_height/2)},
		{"name": "WallSouth", "pos": Vector3(0, 21, sandbox_height/2)},
		{"name": "WallEast", "pos": Vector3(sandbox_width/2, 21, 0)},
		{"name": "WallWest", "pos": Vector3(-sandbox_width/2, 21, 0)},
	]
	for wc in wall_configs:
		var wall = sandbox.get_node(wc["name"])
		if wall:
			var wall_shape = BoxShape3D.new()
			if "East" in wc["name"] or "West" in wc["name"]:
				wall_shape.size = Vector3(0.1, 50, sandbox_height)
			else:
				wall_shape.size = Vector3(sandbox_width, 50, 0.1)
			wall.position = wc["pos"]
			wall.shape = wall_shape


func _on_start_timer_timeout():
	is_in_initial_state = true
	print("Demo 已启动，骰子就绪")


func _process(delta):
	global_time += delta

	if is_charging:
		var charge_ratio = DiceThrowController.update_charge(delta)
		var dices = _get_all_dices()
		DiceThrowController.apply_shake(dices, original_positions, charge_ratio, delta)
		if charge_label:
			charge_label.text = "蓄力：%d%%" % (charge_ratio * 100)
	else:
		original_positions.clear()


func _input(event):
	# 数字键 1-6：设置控制结果
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_set_controlled_result(1)
			KEY_2, KEY_KP_2:
				_set_controlled_result(2)
			KEY_3, KEY_KP_3:
				_set_controlled_result(3)
			KEY_4, KEY_KP_4:
				_set_controlled_result(4)
			KEY_5, KEY_KP_5:
				_set_controlled_result(5)
			KEY_6, KEY_KP_6:
				_set_controlled_result(6)
			KEY_0, KEY_KP_0:
				_set_controlled_result(0)

	# 空格键蓄力/投掷
	if event.is_action_pressed("ui_accept") and is_in_initial_state:
		is_charging = true
		DiceThrowController.start_charge()
		original_positions.clear()
		var dices = _get_all_dices()
		for dice in dices:
			original_positions[dice] = dice.position
		print(">>> 开始蓄力... ", "控制结果=", controlled_result if controlled_result > 0 else "随机")

	elif event.is_action_released("ui_accept") and is_charging:
		is_charging = false
		var dices = _get_all_dices()
		# 如果设置了控制结果，先给每个骰子设置
		if controlled_result > 0:
			for dice in dices:
				if dice and is_instance_valid(dice) and dice.has_method("set_controlled_result"):
					dice.set_controlled_result(controlled_result)
					print(">>> 已设置骰子控制结果 =", controlled_result, ", 骰子=", dice.name)
				elif not dice.has_method("set_controlled_result"):
					print(">>> 警告: 骰子没有 set_controlled_result 方法!")
		DiceThrowController.end_charge(dices)
		original_positions.clear()
		is_in_initial_state = false

	# R 键重置骰子
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset_dice()

	# A 键增加骰子
	if event is InputEventKey and event.pressed and event.keycode == KEY_A:
		if dice_manager:
			dice_manager.add_dice()

	# S 键减少骰子
	if event is InputEventKey and event.pressed and event.keycode == KEY_S:
		if dice_manager:
			dice_manager.remove_dice()

	# 摄像机控制
	if event.is_action_pressed("ui_home"):
		CameraManager.set_preset("high")
	elif event.is_action_pressed("ui_end"):
		CameraManager.set_preset("low")
	elif event.is_action_pressed("ui_page_up"):
		CameraManager.set_preset("wide")
	elif event.is_action_pressed("ui_page_down"):
		CameraManager.reset_to_default()

	# F 键：打印当前骰子结果
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_print_dice_results()


func _set_controlled_result(value: int):
	if value == 0:
		controlled_result = 0
		print(">>> 切换为随机模式")
	else:
		controlled_result = value
		print(">>> 设置控制结果为：", value)

	# 更新结果标签
	if result_label:
		if value > 0:
			result_label.text = "目标结果：%d" % value
		else:
			result_label.text = "随机模式"


func _get_all_dices() -> Array:
	var dices = []
	if dice_manager:
		for i in range(dice_manager.get_dice_count()):
			var dice = dice_manager.get_dice(i)
			if dice and is_instance_valid(dice):
				dices.append(dice)
	return dices


func _reset_dice():
	if dice_manager:
		dice_manager.reset_all_dice()
	is_in_initial_state = true
	# 重置骰子的控制结果
	var dices = _get_all_dices()
	for dice in dices:
		if dice and is_instance_valid(dice) and dice.has_method("set_controlled_result"):
			dice.set_controlled_result(-1)
	print(">>> 骰子已重置")


## 检查并打印当前所有骰子的结果
func _print_dice_results():
	var dices = _get_all_dices()
	var results = []
	for dice in dices:
		if dice and is_instance_valid(dice) and dice.has_method("get_dice_value"):
			var val = dice.get_dice_value()
			results.append(str(val))
			print("骰子 %s: 值=%d, 旋转=%s" % [dice.name, val, dice.rotation])
	print("结果汇总: ", ", ".join(results))
