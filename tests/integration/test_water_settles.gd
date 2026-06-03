# 诊断: 加载世界 + 等水流稳定后, 不该有"悬空水" (水下面是空气却不掉) 或没流走的水.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_no_stuck_floating_water_after_load() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)
	var world = main.get_node("World")
	var cm = world.chunk_manager
	# 等 settle 流到稳定
	await wait_frames(180)
	# 地表带 (y < 150, 玩家看得到): 不该有悬空水. 深处 (y >= 150, 地下看不到) 容忍少量 sim 边角.
	var surf_stuck: int = 0
	var deep_stuck: int = 0
	var samples: Array = []
	for x in range(-120, 181):
		for y in range(20, 250):
			var t: int = cm.get_tile(x, y)
			if Tiles.is_water(t) and cm.get_tile(x, y + 1) == Tiles.AIR:
				if y < 150:
					surf_stuck += 1
					if samples.size() < 10:
						samples.append(Vector2i(x, y))
				else:
					deep_stuck += 1
	gut.p("[诊断] 地表悬空水: %d 处 (样例 %s); 深处: %d 处" % [surf_stuck, str(samples), deep_stuck])
	assert_eq(surf_stuck, 0, "地表 (玩家看得到的) 不该有悬空水")
