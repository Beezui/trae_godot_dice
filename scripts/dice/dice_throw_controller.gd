extends Node

## 统一骰子投掷控制器
## 提供标准化的投掷接口，保证所有场景使用相同的投掷逻辑和手感

## 配置参数
@export var max_charge_time: float = 2.0  ## 最大蓄力时间 (秒)
@export var max_force: float = 20.0  ## 最大投掷力度
@export var min_force_ratio: float = 0.3  ## 最小力度比例
@export var shake_amplitude: float = 0.05  ## 震动幅度
@export var shake_frequency_base: float = 15.0  ## 震动基础频率
@export var shake_frequency_max: float = 40.0  ## 震动最大频率

## 状态变量
var is_charging: bool = false  ## 是否正在蓄力
var charge_time: float = 0.0  ## 当前蓄力时间
var charge_ratio: float = 0.0  ## 当前蓄力比例 (0-1)
var original_positions: Dictionary = {}  ## 骰子原始位置
var shaken_positions: Dictionary = {}  ## 震动后的位置

## 单例实例
static var _instance: DiceThrowController = null


func _ready():
	# 注册为单例
	_instance = self
	print("DiceThrowController 初始化完成")


## 获取单例实例
static func get_instance() -> DiceThrowController:
	return _instance


## 开始蓄力
func start_charge():
	is_charging = true
	charge_time = 0.0
	charge_ratio = 0.0
	print("开始蓄力")


## 更新蓄力 (在 _process 中调用)
func update_charge(delta: float):
	if is_charging:
		charge_time += delta
		charge_time = min(charge_time, max_charge_time)
		charge_ratio = charge_time / max_charge_time
		return charge_ratio
	return 0.0


## 结束蓄力并投掷
func end_charge(dices: Array):
	is_charging = false
	if charge_ratio > 0:
		throw_with_charge(dices, charge_ratio)
		charge_ratio = 0.0
		charge_time = 0.0


## 蓄力投掷
func throw_with_charge(dices: Array, charge_ratio: float, start_positions: Dictionary = {}):
	if dices.size() == 0:
		print("DiceThrowController: 没有骰子可投掷")
		return
	
	# 计算投掷力度
	var force_ratio = min_force_ratio + (1.0 - min_force_ratio) * charge_ratio
	var throw_force = max_force * force_ratio
	
	print("DiceThrowController: 蓄力投掷，比例=%.2f, 力度=%.2f" % [charge_ratio, throw_force])
	
	# 投掷每个骰子
	for dice in dices:
		if is_instance_valid(dice):
			# 计算投掷方向 (朝向屏幕上方，即 z 轴负方向)
			var direction = Vector3(0, 0, -1)
			direction = direction.rotated(Vector3.RIGHT, deg_to_rad(randf_range(-45, 45)))
			
			# 应用投掷力
			var force = direction * throw_force
			force.y = throw_force * 0.5  # 向上的分力
			
			# 随机旋转力
			var angular_force = Vector3(
				randf_range(-10, 10),
				randf_range(-10, 10),
				randf_range(-10, 10)
			)
			
			# 调用骰子的 roll 方法
			if dice.has_method("roll"):
				dice.roll(force, angular_force)
				print("DiceThrowController: 投掷骰子，位置=", dice.position)
	
	# 重置状态
	charge_ratio = 0.0
	charge_time = 0.0


## 普通投掷
func throw_normal(dices: Array, force_multiplier: float = 1.0):
	if dices.size() == 0:
		print("DiceThrowController: 没有骰子可投掷")
		return
	
	var base_force = 10.0 * force_multiplier
	
	print("DiceThrowController: 普通投掷，力度倍数=%.2f" % [force_multiplier])
	
	for dice in dices:
		if is_instance_valid(dice):
			var direction = Vector3(0, 0, -1)
			var force = direction * base_force
			force.y = base_force * 0.3
			
			var angular_force = Vector3(
				randf_range(-5, 5),
				randf_range(-5, 5),
				randf_range(-5, 5)
			)
			
			if dice.has_method("roll"):
				dice.roll(force, angular_force)


## 应用震动效果
func apply_shake(dices: Array, original_positions: Dictionary, charge_ratio: float, delta: float):
	if charge_ratio <= 0:
		return
	
	# 根据蓄力比例调整震动强度
	var current_amplitude = shake_amplitude * charge_ratio
	var current_frequency = shake_frequency_base + (shake_frequency_max - shake_frequency_base) * charge_ratio
	
	for dice in dices:
		if is_instance_valid(dice) and dice.has_method("get_position"):
			var original_pos = original_positions.get(dice, dice.position)
			
			# 计算震动偏移
			var shake_offset = Vector3(
				sin(Time.get_ticks_msec() * current_frequency * 0.001) * current_amplitude,
				cos(Time.get_ticks_msec() * current_frequency * 0.002) * current_amplitude,
				0
			)
			
			# 应用震动
			dice.position = original_pos + shake_offset


## 重置状态
func reset():
	is_charging = false
	charge_time = 0.0
	charge_ratio = 0.0
	original_positions.clear()
	shaken_positions.clear()
	print("DiceThrowController: 重置状态")


## 获取蓄力比例
func get_charge_ratio() -> float:
	return charge_ratio


## 获取蓄力时间
func get_charge_time() -> float:
	return charge_time


## 是否正在蓄力
func get_is_charging() -> bool:
	return is_charging


## 注册骰子位置
func register_dice_position(dice: RigidBody3D):
	if is_instance_valid(dice):
		original_positions[dice] = dice.position


## 注册所有骰子位置
func register_all_positions(dices: Array):
	original_positions.clear()
	for dice in dices:
		if is_instance_valid(dice):
			original_positions[dice] = dice.position
