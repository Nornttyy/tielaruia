# 1.4.4.9 基础制作链。使用材料数量，不再用 Minecraft 九宫格模拟配方。
# 物品旧 ID planks/slime_jelly/*_ingot 分别对应木材/凝胶/金属锭。
extends RefCounted

static func build() -> Array:
	var recipes: Array = []
	_add(recipes, "workbench", {"planks": 10})
	_add(recipes, "torch", {"planks": 1, "slime_jelly": 1}, "", 3)
	_add(recipes, "wood_platform", {"planks": 1}, "", 2)
	_add(recipes, "furnace", {"stone": 20, "planks": 4, "torch": 3}, "workbench")
	_add(recipes, "iron_anvil", {"iron_ingot": 5}, "workbench")
	_add(recipes, "wood_chair", {"planks": 4}, "workbench")
	_add(recipes, "wood_table", {"planks": 8}, "workbench")
	_add(recipes, "glass", {"sand": 2}, "furnace")
	_add(recipes, "glass_wall", {"glass": 1}, "workbench", 4)
	_add(recipes, "gray_brick", {"stone": 2}, "furnace")
	_add(recipes, "red_brick", {"clay": 2}, "furnace")
	_add(recipes, "door", {"planks": 6}, "workbench")
	_add(recipes, "chest", {"planks": 8, "iron_ingot": 2}, "workbench")
	_add(recipes, "wood_sword", {"planks": 7}, "workbench")
	_add(recipes, "wood_bow", {"planks": 10}, "workbench")
	_add(recipes, "wood_hammer", {"planks": 8}, "workbench")
	_add(recipes, "wood_arrow", {"planks": 1, "stone": 1}, "workbench", 25)
	_add(recipes, "fishing_rod", {"planks": 8}, "workbench")
	_add(recipes, "wood_wall", {"planks": 1}, "workbench", 4)
	_add(recipes, "stone_wall", {"stone": 1}, "workbench", 4)
	_add(recipes, "dirt_wall", {"dirt": 1}, "workbench", 4)
	_add(recipes, "cooking_pot", {"iron_ingot": 10, "planks": 2}, "anvil")
	_add(recipes, "chain", {"iron_ingot": 1}, "anvil", 10)
	_add(recipes, "grappling_hook", {"hook": 1, "chain": 3}, "anvil")
	for metal in ["copper", "tin", "iron", "silver", "gold"]:
		var ore_count: int = 4 if metal in ["silver", "gold"] else 3
		_add(recipes, metal + "_ingot", {metal + "_ore": ore_count}, "furnace")
	# 各金属不是同一个价：铜工具较便宜；铁镐只用 3 木，其余为 4 木。
	for metal in ["copper", "iron", "silver", "gold"]:
		var bar: String = metal + "_ingot"
		_add(recipes, metal + "_sword", {bar: 6 if metal == "copper" else 8}, "anvil")
		_add(recipes, metal + "_dagger", {bar: 5 if metal == "copper" else 6}, "anvil")
		_add(recipes, metal + "_pickaxe", {bar: 8 if metal == "copper" else 10, "planks": 3 if metal == "iron" else 4}, "anvil")
		_add(recipes, metal + "_axe", {bar: 6 if metal == "copper" else 8, "planks": 3}, "anvil")
		_add(recipes, metal + "_hammer", {bar: 8, "planks": 3}, "anvil")
		_add(recipes, metal + "_helmet", {bar: 12 if metal == "copper" else (20 if metal == "gold" else 15)}, "anvil")
		_add(recipes, metal + "_chest", {bar: 20 if metal == "copper" else (30 if metal == "gold" else 25)}, "anvil")
		_add(recipes, metal + "_pants", {bar: 16 if metal == "copper" else (25 if metal == "gold" else 20)}, "anvil")
	return recipes


static func _add(recipes: Array, id: String, ingredients: Dictionary, station: String = "", count: int = 1) -> void:
	recipes.append({"id": id, "ingredients": ingredients, "requires": station,
		"output_id": id, "output_count": count,
		# 兼容旧面板结构，但不再允许隐藏的九宫格绕过数量校验。
		"grid_size": Vector2i.ONE, "pattern": [], "mirror_ok": false})
