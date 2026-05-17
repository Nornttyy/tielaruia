extends GutTest

func test_one_plus_one_equals_two():
	assert_eq(1 + 1, 2, "数学还活着")

func test_godot_runtime_exists():
	assert_not_null(Engine.get_version_info(), "Godot 引擎可访问")
