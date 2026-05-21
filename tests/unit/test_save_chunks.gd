extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const SaveData = preload("res://scripts/save/save_data.gd")
const SaveManagerScript = preload("res://scripts/save/save_manager.gd")
const ChunkManagerClass = preload("res://scripts/world/chunk_manager.gd")
const SAVE_PATH := "user://save.tres"


func before_each():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func after_each():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_save_captures_chunk_deltas():
	# 启动游戏 → 修改 1 个 tile → save → 检查 chunk_deltas 含修改
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(3)
	var world = main.get_node("World")
	world.chunk_manager.set_tile(50, 70, Tiles.DIRT)
	SaveManager.save(main)
	var data = SaveManager.load_save()
	assert_not_null(data)
	# chunk_x = 0 (50 / 64 = 0), local_x = 50
	# delta 至少含 (50, 70, DIRT)
	assert_true(data.chunk_deltas.has(0), "chunk 0 应有 delta")
	var arr: PackedInt32Array = data.chunk_deltas[0]
	# 应至少有 (50, 70, DIRT) 这三元组
	var found := false
	var i := 0
	while i + 2 < arr.size():
		if arr[i] == 50 and arr[i + 1] == 70 and arr[i + 2] == Tiles.DIRT:
			found = true
			break
		i += 3
	assert_true(found, "应找到 (50, 70, DIRT) 三元组")


func test_apply_chunk_deltas_restores():
	# 直接测 apply_chunk_deltas: 喂一个 fake serialized dict 给空 chunk_manager
	var cm: ChunkManager = ChunkManagerClass.new()
	add_child_autofree(cm)
	cm.setup(42)
	var serialized: Dictionary = {
		3: PackedInt32Array([10, 20, Tiles.STONE, 11, 20, Tiles.DIRT])
	}
	SaveManagerScript.apply_chunk_deltas(cm, serialized)
	# _deltas[3] 应有 2 个 entry
	assert_true(cm._deltas.has(3))
	assert_eq(cm._deltas[3].size(), 2)
	assert_eq(cm._deltas[3][Vector2i(10, 20)], Tiles.STONE)
	assert_eq(cm._deltas[3][Vector2i(11, 20)], Tiles.DIRT)


# test_village_tiles_in_save 已删除: 村庄 / 村民已停用, 不再写 village delta 到 chunk
