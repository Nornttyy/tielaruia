# chunk_manager: view_radius 实例变量 + preload_around 一次生成一大片 + loaded_count.
extends GutTest

const ChunkManager = preload("res://scripts/world/chunk_manager.gd")


func _make_cm() -> Node:
	var cm = ChunkManager.new()
	add_child_autofree(cm)
	cm.setup(12345)
	return cm


func test_default_radius_loads_5():
	var cm = _make_cm()
	cm.ensure_loaded(0)
	assert_eq(cm.loaded_count(), 5, "默认 view_radius=2 → ±2 = 5 个 chunk")


func test_bigger_radius_loads_more():
	var cm = _make_cm()
	cm.view_radius = 4
	cm.ensure_loaded(0)
	assert_eq(cm.loaded_count(), 9, "view_radius=4 → ±4 = 9 个")


func test_preload_around_generates_span():
	var cm = _make_cm()
	cm.preload_around(0, 6)
	assert_eq(cm.loaded_count(), 13, "preload_around(0,6) → ±6 = 13 个")
	assert_true(cm.is_loaded(0), "出生点 chunk 在")
	assert_true(cm.is_loaded(-6), "最左 chunk 在")
	assert_true(cm.is_loaded(6), "最右 chunk 在")
