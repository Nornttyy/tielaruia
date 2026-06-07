# 三根发射法杖的魔法弹元素各不相同 (绿/蓝/红), 不再全是同一个火球.
extends GutTest

func test_staffs_have_distinct_elements() -> void:
	var wood = ItemDB.get_def("wood_staff")
	var iron = ItemDB.get_def("iron_staff")
	var hell = ItemDB.get_def("hell_staff")
	assert_eq(wood.get("spell_element", ""), "nature", "木法杖 = 自然(绿)")
	assert_eq(iron.get("spell_element", ""), "ice", "铁法杖 = 冰霜(蓝)")
	assert_eq(hell.get("spell_element", ""), "fire", "地狱法杖 = 火(红)")
