# 改名物品兼容: 旧存档里的弹跳枪 (ricochet_gun) 读档自动变史莱姆冲锋枪 (slime_smg).
extends GutTest


func test_canon_id() -> void:
	assert_eq(ItemDB.canon_id("ricochet_gun"), "slime_smg")
	assert_eq(ItemDB.canon_id("pistol"), "pistol", "没改过名的原样返回")


func test_canon_slots_in_place() -> void:
	var slots: Array = [null, {"item_id": "ricochet_gun", "count": 1}, {"item_id": "torch", "count": 5}]
	ItemDB.canon_slots(slots)
	assert_eq(String(slots[1]["item_id"]), "slime_smg", "旧 id 该换成新 id")
	assert_eq(String(slots[2]["item_id"]), "torch", "别的物品不动")
	assert_null(slots[0], "空槽不动")


func test_old_id_gone_new_def_correct() -> void:
	assert_null(ItemDB.get_def("ricochet_gun"), "旧 id 该从 _DEFS 删掉")
	var def = ItemDB.get_def("slime_smg")
	assert_not_null(def, "新 id 该存在")
	assert_eq(String(def.get("gun_visual", "")), "slimeblob", "该喷果冻弹")
	assert_lt(float(def.get("gun_cooldown", 1.0)), 0.12, "冲锋枪该超快连发")
	assert_gt(int(def.get("gun_bounce", 0)), 0, "果冻弹该会弹跳")
