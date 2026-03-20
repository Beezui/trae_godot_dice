extends Node

## 统一摄像机管理器（Autoload 单例）
## 所有场景的摄像机配置都通过此管理器统一管理

## 摄像机标准配置参数
@export var camera_position: Vector3 = Vector3(0, 60, 0)  ## 摄像机位置（正上方俯视）
@export var camera_fov: float = 15.0  ## 摄像机视野（15 度，接近平视效果）
@export var camera_rotation: Vector3 = Vector3(-PI/2, 0, 0)  ## 摄像机旋转（-90 度俯视）

## 单例实例
static var _instance: CameraManager = null

## 已注册的摄像机列表
var registered_cameras: Array = []


func _ready():
	# 注册为单例
	_instance = self
	print("CameraManager 初始化完成")
	print("【摄像机配置】位置：%s, FOV: %.1f" % [camera_position, camera_fov])


## 获取单例实例
static func get_instance() -> CameraManager:
	return _instance


## 注册摄像机并应用配置
## @param camera Camera3D 摄像机实例
func register_camera(camera: Camera3D):
	if not camera or not is_instance_valid(camera):
		print("【摄像机管理器】错误：摄像机实例无效")
		return
	
	# 添加到注册列表
	if not registered_cameras.has(camera):
		registered_cameras.append(camera)
		print("【摄像机管理器】注册摄像机：%s" % camera.name)
	
	# 应用配置
	apply_camera_config(camera)


## 应用配置到单个摄像机
## @param camera Camera3D 摄像机实例
func apply_camera_config(camera: Camera3D):
	if not camera or not is_instance_valid(camera):
		return
	
	camera.position = camera_position
	camera.fov = camera_fov
	camera.rotation = camera_rotation
	
	print("【摄像机管理器】已更新摄像机：%s" % camera.name)


## 应用配置到所有已注册的摄像机
func apply_to_all_cameras():
	print("【摄像机管理器】更新所有已注册的摄像机（%d 个）" % registered_cameras.size())
	
	for camera in registered_cameras:
		if camera and is_instance_valid(camera):
			apply_camera_config(camera)


## 更新摄像机位置
## @param new_position Vector3 新的位置
func update_position(new_position: Vector3):
	camera_position = new_position
	print("【摄像机管理器】更新位置：%s" % new_position)
	apply_to_all_cameras()


## 更新摄像机 FOV
## @param new_fov float 新的 FOV 值
func update_fov(new_fov: float):
	camera_fov = new_fov
	print("【摄像机管理器】更新 FOV：%.1f" % new_fov)
	apply_to_all_cameras()


## 更新摄像机旋转
## @param new_rotation Vector3 新的旋转
func update_rotation(new_rotation: Vector3):
	camera_rotation = new_rotation
	print("【摄像机管理器】更新旋转：%s" % new_rotation)
	apply_to_all_cameras()


## 设置标准配置（预设）
## @param preset String 预设名称："default", "high", "low", "wide"
func set_preset(preset: String):
	match preset:
		"default":
			camera_position = Vector3(0, 60, 0)
			camera_fov = 15.0
			camera_rotation = Vector3(-PI/2, 0, 0)
		"high":
			# 更高的摄像机位置
			camera_position = Vector3(0, 80, 0)
			camera_fov = 12.0
			camera_rotation = Vector3(-PI/2, 0, 0)
		"low":
			# 更低的摄像机位置
			camera_position = Vector3(0, 40, 0)
			camera_fov = 20.0
			camera_rotation = Vector3(-PI/2, 0, 0)
		"wide":
			# 更宽的视野
			camera_position = Vector3(0, 60, 0)
			camera_fov = 25.0
			camera_rotation = Vector3(-PI/2, 0, 0)
		_:
			print("【摄像机管理器】未知预设：%s" % preset)
			return
	
	print("【摄像机管理器】应用预设：%s" % preset)
	apply_to_all_cameras()


## 移除已注销的摄像机（清理无效实例）
func cleanup_invalid_cameras():
	var valid_cameras = []
	for camera in registered_cameras:
		if camera and is_instance_valid(camera):
			valid_cameras.append(camera)
	registered_cameras = valid_cameras
	print("【摄像机管理器】清理完成，剩余有效摄像机：%d" % registered_cameras.size())


## 获取已注册摄像机数量
func get_camera_count() -> int:
	return registered_cameras.size()


## 列出所有已注册的摄像机
func list_cameras():
	print("【摄像机管理器】已注册的摄像机列表：")
	for i in range(registered_cameras.size()):
		var camera = registered_cameras[i]
		if camera and is_instance_valid(camera):
			print("  %d: %s (位置：%s, FOV: %.1f)" % [i, camera.name, camera.position, camera.fov])
		else:
			print("  %d: (无效)" % i)


## 重置为默认配置
func reset_to_default():
	camera_position = Vector3(0, 60, 0)
	camera_fov = 15.0
	camera_rotation = Vector3(-PI/2, 0, 0)
	print("【摄像机管理器】重置为默认配置")
	apply_to_all_cameras()
