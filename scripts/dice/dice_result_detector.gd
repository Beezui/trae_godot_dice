extends Node

## 统一骰子结果检测器
## 提供标准化的结果检测接口，使用向量点积法确保所有骰子使用相同的检测算法

## 配置参数
@export var stability_threshold: float = 0.1  ## 稳定阈值 (线速度和角速度)
@export var stable_duration: float = 0.8  ## 稳定持续时间 (秒)
@export var check_interval: float = 0.1  ## 检查间隔 (秒)
@export var max_wait_time: float = 5.0  ## 最大等待时间 (秒)

## 状态变量
var checking_dices: Array = []  ## 正在检测的骰子
var stable_timers: Dictionary = {}  ## 稳定计时器
var results: Dictionary = {}  ## 检测结果

## 单例实例
static var _instance: DiceResultDetector = null


func _ready():
	# 注册为单例
	_instance = self
	print("DiceResultDetector 初始化完成")


## 获取单例实例
static func get_instance() -> DiceResultDetector:
	return _instance


## 检查单个骰子值
func check_dice_value(dice: RigidBody3D) -> int:
	if not is_instance_valid(dice):
		print("DiceResultDetector: 骰子实例无效")
		return 1
	
	# 向量点积法检测
	var up_direction = Vector3.UP
	var dice_transform = dice.global_transform
	var global_directions = []
	
	# 定义 6 个面的局部方向 (前、后、左、右、上、下)
	var local_directions = [
		Vector3(0, 0, -1),  # 面 1 - 前
		Vector3(0, 0, 1),   # 面 2 - 后
		Vector3(-1, 0, 0),  # 面 3 - 左
		Vector3(1, 0, 0),   # 面 4 - 右
		Vector3(0, 1, 0),   # 面 5 - 上
		Vector3(0, -1, 0)   # 面 6 - 下
	]
	
	# 转换为全局方向
	for local_dir in local_directions:
		global_directions.append(dice_transform.basis * local_dir)
	
	# 找到最接近向上的面
	var max_dot = -1.0
	var closest_index = 0
	
	for i in range(global_directions.size()):
		var dot = up_direction.dot(global_directions[i])
		if dot > max_dot:
			max_dot = dot
			closest_index = i
	
	# 计算骰子值 (索引 +1)
	var dice_value = closest_index + 1
	
	print("DiceResultDetector: 检测结果 - 值=%d, 索引=%d, 点积=%.3f" % [dice_value, closest_index, max_dot])
	
	return dice_value


## 批量检测所有骰子
func check_all_dice(dices: Array) -> Dictionary:
	var all_results = {}
	
	for i in range(dices.size()):
		var dice = dices[i]
		if is_instance_valid(dice):
			var value = check_dice_value(dice)
			all_results[i] = {
				"dice": dice,
				"value": value,
				"face_index": value - 1
			}
	
	return all_results


## 等待骰子稳定
func wait_for_dice_stable(dices: Array, timeout: float = 5.0) -> bool:
	var start_time = Time.get_ticks_msec()
	var all_stable = false
	
	while not all_stable:
		all_stable = true
		for dice in dices:
			if is_instance_valid(dice):
				if not _is_dice_stable(dice):
					all_stable = false
					break
		
		if not all_stable:
			var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
			if elapsed >= timeout:
				print("DiceResultDetector: 等待超时，强制返回结果")
				return false
			await get_tree().process_frame
	
	print("DiceResultDetector: 所有骰子已稳定")
	return true


## 检测骰子是否稳定
func _is_dice_stable(dice: RigidBody3D) -> bool:
	if not is_instance_valid(dice):
		return true
	
	# 检查线速度和角速度
	var linear_vel = dice.linear_velocity.length()
	var angular_vel = dice.angular_velocity.length()
	
	if linear_vel < stability_threshold and angular_vel < stability_threshold:
		return true
	
	return false


## 获取骰子面索引
func get_face_index(dice: RigidBody3D) -> int:
	var value = check_dice_value(dice)
	return value - 1


## 开始检测骰子
func start_detection(dice: RigidBody3D):
	if not is_instance_valid(dice):
		return
	
	if not checking_dices.has(dice):
		checking_dices.append(dice)
		print("DiceResultDetector: 开始检测骰子")


## 停止检测骰子
func stop_detection(dice: RigidBody3D):
	if checking_dices.has(dice):
		checking_dices.erase(dice)
		if stable_timers.has(dice):
			stable_timers.erase(dice)
		print("DiceResultDetector: 停止检测骰子")


## 清除所有检测
func clear_all_detection():
	checking_dices.clear()
	stable_timers.clear()
	results.clear()
	print("DiceResultDetector: 清除所有检测")


## 重置状态
func reset():
	clear_all_detection()
	print("DiceResultDetector: 重置状态")


## 获取检测结果
func get_result(dice: RigidBody3D) -> int:
	if results.has(dice):
		return results[dice]
	return check_dice_value(dice)


## 存储结果
func store_result(dice: RigidBody3D, value: int):
	results[dice] = value
	print("DiceResultDetector: 存储结果 - 骰子值=%d" % value)


## 批量存储结果
func store_all_results(dices: Array):
	for dice in dices:
		if is_instance_valid(dice):
			var value = check_dice_value(dice)
			store_result(dice, value)
