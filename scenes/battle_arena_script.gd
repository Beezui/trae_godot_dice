extends Node3D

@onready var dice = $Dice6
@onready var player = $Characters/Player
@onready var enemy = $Characters/Enemy

var battle_state = "ready"  # ready, rolling, resolving, ended

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if battle_state == "ready":
			start_roll()

func start_roll():
	battle_state = "rolling"
	
	# 生成随机力向量
	var force = Vector3(
		randf_range(-15, 15),
		randf_range(15, 25),
		randf_range(-10, 10)
	)
	
	# 重置骰子位置
	dice.position = Vector3(0, 3, 0)
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	
	# 投掷骰子
	dice.roll(force)
	
	# 等待骰子停止后处理结果
	timer = Timer.new()
	timer.wait_time = 4.0
	timer.one_shot = true
	timer.timeout.connect(_on_roll_finished)
	add_child(timer)
	timer.start()

func _on_roll_finished():
	battle_state = "resolving"
	
	# 处理骰子结果
	var dice_value = dice.dice_value
	print("Battle dice rolled: ", dice_value)
	
	# 模拟战斗结果
	resolve_battle(dice_value)
	
	# 战斗结束后重置状态
	timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_reset_battle)
	add_child(timer)
	timer.start()

func resolve_battle(dice_value):
	# 根据骰子点数计算伤害
	var damage = dice_value * 5
	print("Player attacks with damage: ", damage)
	
	# 这里可以添加更复杂的战斗逻辑
	# 例如：根据技能类型、目标状态等计算最终伤害

func _reset_battle():
	battle_state = "ready"
	print("Battle reset, ready for next roll")

func _process(delta):
	# 更新战斗状态
	if battle_state == "rolling":
		# 可以添加一些视觉反馈
		pass
