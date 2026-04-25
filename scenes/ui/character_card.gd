extends PanelContainer
## 角色卡片预制
## 由 character_select.gd 实例化后填充数据

# 组件引用
@onready var name_label = $VBoxContainer/NameLabel
@onready var hp_label = $VBoxContainer/StatsGrid/HPLabel
@onready var mp_label = $VBoxContainer/StatsGrid/MPLabel
@onready var select_indicator = $VBoxContainer/SelectIndicator


## 初始化卡片数据
## @param hero_data hero.json 中的角色数据字典
func setup(hero_data: Dictionary):
	if name_label:
		name_label.text = str(hero_data.get("name", "未知角色"))
	if hp_label:
		hp_label.text = "HP: " + str(hero_data.get("attr_hp", "100"))
	if mp_label:
		mp_label.text = "MP: " + str(hero_data.get("attr_mp", "50"))


## 设置选中状态
## @param selected 是否选中
## @param indicator 引用 select_indicator Label
func set_selected(selected: bool):
	if select_indicator:
		if selected:
			select_indicator.text = "已选择"
			select_indicator.modulate = Color(0.3, 1.0, 0.5)
		else:
			select_indicator.text = "未选择"
			select_indicator.modulate = Color(0.7, 0.7, 0.7)

	_update_style(selected)


## 更新卡片样式
func _update_style(selected: bool):
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10

	if selected:
		style.bg_color = Color(0.3, 0.5, 0.3, 1)
		style.border_color = Color(0.5, 1.0, 0.5)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.25, 0.25, 0.3, 1)

	add_theme_stylebox_override("panel", style)
