extends Control
## 主 HUD 工具栏
## 位于屏幕顶部，提供地图和技能装配入口
## 后续可在此处替换美术素材

## 信号
signal on_map_toggled()
signal on_skill_equip_toggled()


func _on_map_button_pressed():
	on_map_toggled.emit()


func _on_skill_equip_button_pressed():
	if not BattleManager.can_equip_skills:
		print("【HUD】战斗中无法进行技能装配")
		return
	on_skill_equip_toggled.emit()
