# 对战房竞技场生成: 地面/平台/中央塔在位 + 左右对称.
extends GutTest

const PvpArena = preload("res://scripts/world/pvp_arena.gd")


func test_arena_builds_floor_platforms_symmetric() -> void:
	var main = preload("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var cm = world.chunk_manager
	var spawn: Vector2 = PvpArena.build(world)
	await wait_frames(1)

	var cx := PvpArena.CENTER_X
	var fy := PvpArena.FLOOR_Y
	# 地面: 中心 2 行实心石
	assert_eq(cm.get_tile(cx, fy), Tiles.STONE, "地面行该是石头")
	assert_eq(cm.get_tile(cx, fy + 1), Tiles.STONE, "地面下一行也实心")
	# 中央不该有石柱"墙"了 (用户要求删掉) → 中心高处是空气
	assert_eq(cm.get_tile(cx, fy - 10), Tiles.AIR, "中央石柱已删, 该是空气")
	# 第一层矮平台 (dy=4, from=18): 左右镜像都该是木平台
	assert_eq(cm.get_tile(cx - 18, fy - 4), Tiles.WOOD_PLATFORM, "左侧平台在位")
	assert_eq(cm.get_tile(cx + 18, fy - 4), Tiles.WOOD_PLATFORM, "右侧平台在位")
	# 对称: 抽几个点, 中线两侧同 tile
	for d in [18, 30, 44]:
		assert_eq(cm.get_tile(cx - d, fy - 4), cm.get_tile(cx + d, fy - 4), "平台关于中心对称 (d=%d)" % d)
	# 空气墙节点已建 (防逃出)
	assert_not_null(world.get_node_or_null("ArenaWalls"), "该有看不见的空气墙 ArenaWalls")
	# 出生点返回非零
	assert_ne(spawn, Vector2.ZERO, "该返回出生点坐标")
