extends GutTest
const Generator = preload("res://scripts/world/world_generator.gd")
const Features = preload("res://scripts/world/classic_world_features.gd")
const King = preload("res://scenes/entities/king_slime.tscn")
const Player = preload("res://scenes/player/player.tscn")
var old_diff: int
var old_size: int
func before_each():
	old_diff = GameSettings.current_difficulty
	old_size = GameSettings.current_world_size
	GameSettings.current_difficulty = 1
	GameSettings.current_world_size = 0
	Generator.clear_structure_caches()
func after_each():
	GameSettings.current_difficulty = old_diff
	GameSettings.current_world_size = old_size
	Generator.clear_structure_caches()
func test_flyers_use_distinct_frames_and_defense():
	var hashes := []
	for kind in ["eater_of_souls", "crimera"]:
		var mob = load("res://scenes/entities/" + kind + ".tscn").instantiate()
		add_child_autofree(mob)
		mob.set_physics_process(false)
		assert_eq(mob.current_health, 40)
		assert_eq(mob.sprite.sprite_frames.get_frame_count("fly"), 2)
		hashes.append(hash(mob.sprite.sprite_frames.get_frame_texture("fly", 0).get_image().get_data()))
		assert_true(mob.take_damage(20))
		assert_eq(mob.current_health, 24, "8 防御应抵消 4 点")
		assert_false(mob.take_damage(20), "同一挥刀不能每帧连扣")
		mob.apply_network_facing(1090)
		assert_almost_eq(mob._turn, PI / 2.0, 0.001)
	assert_ne(hashes[0], hashes[1])
	for id in ["rotten_chunk", "vertebra"]:
		assert_true(ItemDB.is_available(id))
		assert_not_null(ArtCache.get_inventory_icon(id))
func test_flyer_actually_chases_and_changes_heading():
	var p = Player.instantiate()
	p.position = Vector2(150, 0)
	add_child_autofree(p)
	p.set_physics_process(false)
	var m = load("res://scenes/entities/crimera.tscn").instantiate()
	add_child_autofree(m)
	for i in 18: await get_tree().physics_frame
	assert_gt(m.position.x, 0.0)
	p.position = Vector2(-200, 0)
	for i in 65: await get_tree().physics_frame
	assert_lt(m.velocity.x, 0.0, "目标换边后应真的转向追击")
func test_king_uses_full_body_and_high_fourth_jump():
	var king = King.instantiate()
	add_child_autofree(king)
	king.set_physics_process(false)
	assert_eq(king.current_health, 2000)
	assert_eq(king.sprite.sprite_frames.get_frame_count("idle"), 6)
	assert_eq(king.sprite.sprite_frames.get_frame_texture("idle", 0).get_size(), Vector2(174, 120))
	king.take_damage(25)
	assert_eq(king.current_health, 1980)
	king._attempt_hop()
	var low: float = king.velocity.y
	for i in 3: king._attempt_hop()
	assert_lt(king.velocity.y, low, "第四次跳跃应更高")
func test_dungeon_rooms_connected_with_body_sized_clearance():
	for seed_value in [42, 43, 9876]:
		var plan := Generator.classic_plan(seed_value)
		var anchor: Vector2i = plan.dungeon
		var chunks := {}
		for cx in range(Chunk.chunk_x_of(anchor.x - 66), Chunk.chunk_x_of(anchor.x + 85) + 1):
			chunks[cx] = Generator.generate_chunk(seed_value, cx)
		var start := anchor + Vector2i(4, 61)
		var visited := {start: true}
		var queue := [start]
		var cursor := 0
		while cursor < queue.size() and cursor < 14000:
			var pos: Vector2i = queue[cursor]
			cursor += 1
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = pos + d
				if visited.has(next) or next.y < anchor.y + 59 or next.y > 240 or absi(next.x - anchor.x) > 65: continue
				if not chunks.has(Chunk.chunk_x_of(next.x)): continue
				var clear := true
				for dx in [0, 1]:
					var c = chunks.get(Chunk.chunk_x_of(next.x + dx))
					if c == null: clear = false; continue
					for dy in [0, -1, -2]:
						if Tiles.is_solid(c.get_tile(Chunk.local_x_of(next.x + dx), next.y + dy)): clear = false
				if clear:
					visited[next] = true
					queue.append(next)
		for room in Features.dungeon_rooms(anchor):
			assert_has(visited, room.get_center(), "从样本出口必须能进每间大厅，seed=%d" % seed_value)
			var chest: Vector2i = room.position + Vector2i(4, room.size.y - 2)
			var c = chunks[Chunk.chunk_x_of(chest.x)]
			assert_eq(c.get_tile(Chunk.local_x_of(chest.x), chest.y), Tiles.GOLD_CHEST)
			assert_true(Tiles.is_solid(c.get_tile(Chunk.local_x_of(chest.x), chest.y + 1)))
