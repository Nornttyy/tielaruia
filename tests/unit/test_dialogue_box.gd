extends GutTest

const DialogueBoxScene = preload("res://scenes/ui/dialogue_box.tscn")
const VillagerLines = preload("res://scripts/npc/villager_lines.gd")


func _make() -> CanvasLayer:
	var db = DialogueBoxScene.instantiate()
	add_child_autofree(db)
	return db


func test_lines_pool_has_10_entries():
	assert_eq(VillagerLines.LINES.size(), 10, "spec 要求 10 句")


func test_random_line_returns_one_of_pool():
	var line = VillagerLines.random_line()
	assert_true(line in VillagerLines.LINES)


func test_initially_hidden():
	var db = _make()
	assert_false(db.visible)
	assert_false(db.is_open())


func test_open_shows_line():
	var db = _make()
	db.open("你好啊")
	assert_true(db.visible)
	assert_true(db.is_open())
	assert_eq(db._line_label.text, "你好啊")


func test_close_hides_and_emits():
	var db = _make()
	db.open("test")
	var emitted := [false]
	db.closed.connect(func(): emitted[0] = true)
	db.close()
	assert_false(db.visible)
	assert_true(emitted[0])


func test_in_dialogue_box_group():
	var db = _make()
	assert_true(db.is_in_group("dialogue_box"))
