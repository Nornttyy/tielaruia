extends GutTest

const InventoryClass = preload("res://scripts/items/inventory.gd")
var inv


func before_each():
	inv = InventoryClass.new()


func test_starts_empty():
	for i in 36:
		assert_null(inv.slots[i])


func test_add_into_first_empty():
	assert_eq(inv.add("dirt", 5), 0)
	assert_eq(inv.slots[0].item_id, "dirt")
	assert_eq(inv.slots[0].count, 5)


func test_add_stacks_onto_same_id():
	inv.add("dirt", 5)
	inv.add("dirt", 3)
	assert_eq(inv.slots[0].item_id, "dirt")
	assert_eq(inv.slots[0].count, 8)


func test_add_overflows_to_next_slot_when_max_stack_hit():
	var cap: int = ItemDB.max_stack("dirt")  # 堆叠上限 (现在 9999)
	inv.add("dirt", cap - 4)   # 离满还差 4
	inv.add("dirt", 10)        # 填满第一槽, 多的 6 进第二槽
	assert_eq(inv.slots[0].count, cap)
	assert_eq(inv.slots[1].item_id, "dirt")
	assert_eq(inv.slots[1].count, 6)


func test_add_returns_leftover_when_full():
	# 每槽塞满 dirt → cap * 槽数 刚好填满
	var cap: int = ItemDB.max_stack("dirt")
	var total: int = cap * inv.slots.size()
	assert_eq(inv.add("dirt", total), 0)
	assert_eq(inv.add("dirt", 5), 5, "全满后剩余 5")


func test_add_tool_does_not_stack_beyond_1():
	inv.add("wood_pickaxe", 1)
	inv.add("wood_pickaxe", 1)
	assert_eq(inv.slots[0].count, 1)
	assert_eq(inv.slots[1].count, 1)


func test_remove_partial():
	inv.add("dirt", 10)
	var took = inv.remove(0, 3)
	assert_eq(took, 3)
	assert_eq(inv.slots[0].count, 7)


func test_remove_more_than_available_returns_available():
	inv.add("dirt", 5)
	var took = inv.remove(0, 10)
	assert_eq(took, 5)
	assert_null(inv.slots[0])


func test_remove_empties_slot_when_zero():
	inv.add("dirt", 1)
	inv.remove(0, 1)
	assert_null(inv.slots[0])


func test_swap():
	inv.add("dirt", 5)
	inv.add("stone", 3)
	assert_eq(inv.slots[0].item_id, "dirt")
	assert_eq(inv.slots[1].item_id, "stone")
	inv.swap(0, 1)
	assert_eq(inv.slots[0].item_id, "stone")
	assert_eq(inv.slots[1].item_id, "dirt")


func test_split_half_even_count():
	inv.add("dirt", 10)
	var half = inv.split_half(0)
	assert_eq(half.item_id, "dirt")
	assert_eq(half.count, 5)
	assert_eq(inv.slots[0].count, 5)


func test_split_half_odd_count_leaves_larger():
	inv.add("dirt", 7)
	var half = inv.split_half(0)
	assert_eq(half.count, 3)
	assert_eq(inv.slots[0].count, 4)


func test_split_half_on_empty_returns_null():
	assert_null(inv.split_half(0))


func test_split_half_on_count_1_returns_null():
	inv.add("wood_pickaxe", 1)
	assert_null(inv.split_half(0))
	assert_eq(inv.slots[0].count, 1)
