class_name WorldlineSystem

var current_worldline = "normal"
var worldlines = {
	"normal": {
		"name": "正常世界",
		"description": "普通的游戏世界",
		"enemies": [" Goblin", "Orc"],
		"events": ["forest_encounter", "village_trade"]
	},
	"dark": {
		"name": "黑暗世界",
		"description": "被黑暗力量侵蚀的世界",
		"enemies": ["Dark Goblin", "Shadow Orc", "Demon"],
		"events": ["dark_forest", "cursed_village"]
	},
	"light": {
		"name": "光明世界",
		"description": "充满光明力量的世界",
		"enemies": ["Holy Goblin", "Light Orc"],
		"events": ["sacred_forest", "blessed_village"]
	},
	"steampunk": {
		"name": "蒸汽朋克世界",
		"description": "机械与蒸汽的世界",
		"enemies": ["Steam Goblin", "Clockwork Orc"],
		"events": ["steam_factory", "mechanical_village"]
	}
}

var worldline_changes = {
	"forest_encounter": {
		"required_value": 5,
		"target_worldline": "dark",
		"description": "在森林中遇到黑暗生物"
	},
	"village_trade": {
		"required_value": 4,
		"target_worldline": "light",
		"description": "与村庄的光明牧师交易"
	},
	"dark_forest": {
		"required_value": 3,
		"target_worldline": "normal",
		"description": "找到光明之泉，净化世界"
	},
	"cursed_village": {
		"required_value": 6,
		"target_worldline": "steampunk",
		"description": "发现古代机械遗迹"
	}
}

func get_current_worldline() -> Dictionary:
	return worldlines.get(current_worldline, worldlines["normal"])

func change_worldline(worldline_id: String) -> bool:
	if worldlines.has(worldline_id):
		current_worldline = worldline_id
		print("Worldline changed to: ", worldlines[worldline_id]["name"])
		return true
	return false

func check_worldline_change(event_id: String, dice_value: int) -> bool:
	var change_data = worldline_changes.get(event_id)
	if change_data and dice_value >= change_data["required_value"]:
		return change_worldline(change_data["target_worldline"])
	return false

func get_worldline_events() -> Array:
	var worldline_data = get_current_worldline()
	return worldline_data.get("events", [])

func get_worldline_enemies() -> Array:
	var worldline_data = get_current_worldline()
	return worldline_data.get("enemies", [])
