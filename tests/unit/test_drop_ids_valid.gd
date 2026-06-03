# 防回归: 怪掉落的 item_id 必须真存在于 ItemDB。
# 否则掉了也捡不起来 (max_stack 返回 0 → inventory.add 直接放弃) + 图标空白。
# 起因: imp/宝箱怪曾掉 "diamond_ore" 但 ItemDB 只有 "diamond"。
extends GutTest

const MimicScript = preload("res://scripts/entities/mimic.gd")


func test_diamond_ore_does_not_exist_use_diamond() -> void:
	assert_null(ItemDB.get_def("diamond_ore"), "没有 diamond_ore 这个物品 (该用 diamond)")
	assert_not_null(ItemDB.get_def("diamond"), "diamond 才是正确的物品 id")


func test_mimic_drop_pool_all_valid() -> void:
	for item_id in MimicScript.DROP_POOL:
		assert_not_null(ItemDB.get_def(item_id),
			"宝箱怪掉落 '%s' 必须在 ItemDB 里 (否则掉了捡不起来)" % item_id)
		assert_gt(ItemDB.max_stack(item_id), 0, "'%s' max_stack 要 > 0, 否则 inventory.add 拒收" % item_id)
