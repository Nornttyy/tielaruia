extends GutTest
const Metrics = preload("res://scripts/art/world_metrics.gd")
const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
const Building = preload("res://scripts/art/building_art.gd")
const DropScene = preload("res://scenes/items/item_drop.tscn")

func test_original_enemies_share_stable_ground_anchor_without_transparent_foot_gap():
	for kind in ["zombie", "mummy", "harpy", "imp", "hell_wasp", "mimic", "demon_eye", "slime"]:
		var mob = load("res://scenes/entities/" + kind + ".tscn").instantiate()
		add_child_autofree(mob)
		mob.set_physics_process(false)
		var sprite: AnimatedSprite2D = mob.get_node("AnimatedSprite2D")
		var lowest := -INF
		for animation in sprite.sprite_frames.get_animation_names():
			for i in sprite.sprite_frames.get_frame_count(animation):
				if kind == "harpy" and i != 0: continue # 翼尖可以低于脚，身体不能因此整体上移。
				var tex := sprite.sprite_frames.get_frame_texture(animation, i)
				var feet := float(tex.get_image().get_used_rect().end.y) - tex.get_height() / 2.0
				lowest = maxf(lowest, sprite.position.y + feet * sprite.scale.y)
		assert_almost_eq(lowest, 0.0, 0.01, kind + " 可见脚底应贴合实体脚底")
		assert_almost_eq(Metrics.body_rect(mob).end.y, mob.global_position.y, 0.01)

func test_projectiles_hit_upper_body_and_miss_clear_space():
	var mob = preload("res://scenes/entities/zombie.tscn").instantiate()
	add_child_autofree(mob)
	mob.set_physics_process(false)
	mob.global_position = Vector2(100, 100)
	assert_true(Metrics.segment_hits(mob, Vector2(70, 75), Vector2(130, 75)))
	assert_false(Metrics.segment_hits(mob, Vector2(70, 62), Vector2(130, 62)))
	assert_false(Metrics.segment_hits(mob, Vector2(70, 108), Vector2(130, 108)))
	var arrow = preload("res://scenes/entities/arrow.tscn").instantiate()
	add_child_autofree(arrow)
	arrow.set_physics_process(false)
	arrow.global_position = Vector2(130,75)
	var before: int = mob.current_health
	arrow._check_enemy_hit(Vector2(70,75))
	assert_lt(mob.current_health, before, "箭穿过上半身应造成伤害")

func test_large_and_small_drops_land_on_visible_bottom_and_keep_relative_sizes():
	var terrain := TileMapLayer.new()
	terrain.tile_set = preload("res://scripts/world/tileset_builder.gd").build()
	terrain.add_to_group("terrain_layer")
	add_child_autofree(terrain)
	for x in range(-5,30): terrain.set_cell(Vector2i(x,10), Tiles.STONE, Vector2i.ZERO)
	for item in ["wood_sword", "iron_sword", "mushroom", "bed", "wood_bow", "dirt"]:
		var drop = DropScene.instantiate()
		drop.item_id = item
		drop.position = Vector2(100, 60)
		add_child_autofree(drop)
		drop.set_physics_process(false)
		drop._cached_terrain = terrain
		drop.velocity = Vector2(0, 300)
		drop._move_axis(100, true)
		var image_rect: Rect2i = drop.sprite.texture.get_image().get_used_rect()
		var bottom: float = drop.global_position.y + drop._half_size.y
		assert_almost_eq(bottom, 119.99, 0.02, item + " 不能插进地面")
		assert_eq(drop._half_size * 2.0, Vector2(image_rect.size) * 0.75, "不将长剑/家具压成一个图标格")

func test_slime_boss_body_and_feet_scale_together():
	var king = preload("res://scenes/entities/king_slime.tscn").instantiate()
	add_child_autofree(king)
	king.set_physics_process(false)
	for hp in [1000, 500, 100]:
		king.current_health = hp
		king._apply_scale()
		var box := Metrics.body_rect(king)
		assert_almost_eq(box.end.y, king.global_position.y, 0.01, "变小时不能悬空或沉进地面")
		assert_almost_eq(box.size.x, 24.0 * king.sprite.scale.x, 0.01)

func test_bed_uses_world_sheet_and_four_by_two_footprint_with_one_drop():
	var base: int = ItemDB.get_def("bed").placeable_tile_id
	assert_eq(Building.multi_footprint(base), Vector2i(4,2))
	assert_eq(Building.multi_image(base).get_size(), Vector2i(64,32))
	assert_eq(Building.multi_parts(base).size(), 8)
	assert_eq(Tiles.drops_for(base, "pickaxe"), {"bed": 1})
	for part in Building.multi_parts(base):
		assert_true(Tiles.is_mineable(part))
		if part != base: assert_eq(Tiles.drops_for(part,"pickaxe"), {})
	assert_eq(Building.multi_footprint(Tiles.BED), Vector2i(2,2), "保留旧存档床的锚点")

func test_tree_crowns_keep_source_width_instead_of_uniform_stretch():
	for style in 5:
		var sheet := Pack.source_image("Tree_Tops_%d.png" % [0,4,2,1,5][style])
		var frame := sheet.get_region(Rect2i(0,0,sheet.get_width()/3-2,sheet.get_height()-2))
		frame.resize(roundi(frame.get_width()*0.75),roundi(frame.get_height()*0.75),Image.INTERPOLATE_NEAREST)
		assert_eq(Pack.crown(0,style).get_image().get_used_rect().size, frame.get_used_rect().size)

func test_full_bed_placement_obstruction_sleep_and_break():
	var main = preload("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	main._start_world_preview()
	await wait_frames(2)
	var world = main.world
	var player = world.get_player()
	player.set_physics_process(false)
	var action = player.get_node("PlayerAction")
	action.set_physics_process(false)
	var inv = player.get_node("PlayerInventory")
	inv.inventory.slots[0] = {"item_id": "bed", "count": 1}
	inv.set_hotbar_selection(0)
	var anchor: Vector2i = action.player_tile() + Vector2i(1,-1)
	for x in 4:
		for y in 2: world._set_tile(anchor.x+x, anchor.y-y, Tiles.AIR)
		world._set_tile(anchor.x+x, anchor.y+1, Tiles.DIRT)
	world._set_tile(anchor.x+3,anchor.y-1,Tiles.STONE)
	assert_false(action.try_place(anchor), "第四格被挡时不能挤进小空间")
	world._set_tile(anchor.x+3,anchor.y-1,Tiles.AIR)
	assert_true(action.try_place(anchor), "四格底边有支撑后应完整放置")
	for part in Building.BED_WIDE_PARTS:
		var cell: Vector2i = anchor + Building.part_offset(part)
		assert_eq(world.chunk_manager.get_tile(cell.x,cell.y), part)
	world.sleep_in_bed(anchor)
	assert_almost_eq(player.global_position.x, (anchor.x+2.0)*12.0, 0.01)
	world._wake_up()
	player.set_physics_process(false)
	action.set_physics_process(false)
	var before := get_tree().get_nodes_in_group("item_drops").size()
	var corner: int = Building.BED_WIDE_PARTS[-1]
	action._finish_mine(anchor+Building.part_offset(corner),corner,"pickaxe",world.get_node("TerrainLayer"))
	for part in Building.BED_WIDE_PARTS:
		var cell: Vector2i = anchor + Building.part_offset(part)
		assert_eq(world.chunk_manager.get_tile(cell.x,cell.y), Tiles.AIR)
	assert_eq(get_tree().get_nodes_in_group("item_drops").size(), before+1, "整床只返还一个物品")
