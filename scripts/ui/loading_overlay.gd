extends CanvasLayer
## 全局加载动画覆盖层
## 用于场景切换时的淡入淡出效果，黑色蒙版
## 注意：通过 autoload 注册为单例，直接使用 LoadingOverlay 访问

# 单例实例
static var _instance = null

# UI 组件
var color_rect: ColorRect

# 动画状态
var is_fading_in: bool = false
var is_fading_out: bool = false
var fade_duration: float = 0.5  # 淡入淡出时长（秒）

# 信号：淡入完成
signal fade_in_completed
# 信号：淡出完成
signal fade_out_completed

# 根容器
var root_control: Control


func _init():
	_instance = self
	layer = 100  # 确保在最上层


func _ready():
	# 创建根容器（使用 Control 来设置布局）
	root_control = Control.new()
	root_control.name = "RootControl"
	root_control.anchors_preset = Control.PRESET_FULL_RECT
	root_control.grow_horizontal = 2  # GROW_BOTH_ENDS
	root_control.grow_vertical = 2  # GROW_BOTH_ENDS
	add_child(root_control)

	# 创建黑色背景
	color_rect = ColorRect.new()
	color_rect.name = "ColorRect"
	color_rect.anchors_preset = Control.PRESET_FULL_RECT
	color_rect.grow_horizontal = 2  # GROW_BOTH_ENDS
	color_rect.grow_vertical = 2  # GROW_BOTH_ENDS
	color_rect.color = Color(0, 0, 0, 1)  # 初始完全不透明
	root_control.add_child(color_rect)

	# 初始隐藏
	visible = false

	print("[LoadingOverlay] 加载动画已就绪")


## 获取单例实例
static func get_instance():
	return _instance


## 显示加载动画（淡入）
## @param duration 淡入时长（秒）
func fade_in(duration: float = 0.5) -> void:
	is_fading_in = true
	is_fading_out = false
	fade_duration = duration

	visible = true
	color_rect.color = Color(0, 0, 0, 0)  # 从透明开始

	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	tween.tween_callback(_on_fade_in_completed)


## 隐藏加载动画（淡出）
## @param duration 淡出时长（秒）
func fade_out(duration: float = 0.5) -> void:
	is_fading_out = true
	is_fading_in = false
	fade_duration = duration

	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	tween.tween_callback(_on_fade_out_completed)


## 快速闪烁效果（用于提示）
func flash(duration: float = 0.2) -> void:
	visible = true
	color_rect.color = Color(0, 0, 0, 1)

	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	tween.tween_callback(func(): visible = false)


## 淡入完成回调
func _on_fade_in_completed():
	is_fading_in = false
	fade_in_completed.emit()


## 淡出完成回调
func _on_fade_out_completed():
	is_fading_out = false
	visible = false  # 完全隐藏
	fade_out_completed.emit()


## 等待淡入完成
func wait_fade_in() -> void:
	if is_fading_in:
		await fade_in_completed


## 等待淡出完成
func wait_fade_out() -> void:
	if is_fading_out:
		await fade_out_completed
