extends GutTest
const Frames = preload("res://scripts/world/torch_frames.gd")
const Sprites = preload("res://scripts/art/terraria_sprite_pack.gd")
const Fx = preload("res://scenes/fx/torch_fx.tscn")
class Grid extends RefCounted:
	var tiles := {}
	var walls := {}
	func get_tile(x: int, y: int) -> int: return tiles.get(Vector2i(x,y), Tiles.AIR)
	func get_wall(x: int, y: int) -> int: return walls.get(Vector2i(x,y), Tiles.AIR)

func test_floor_left_right_wall_and_tree_attachment():
	var grid := Grid.new()
	for sample in [[Vector2i.DOWN, Tiles.STONE, 0], [Vector2i.LEFT, Tiles.STONE, 1],
		[Vector2i.RIGHT, Tiles.STONE, 2], [Vector2i.LEFT, Tiles.LOG, 1],
		[Vector2i.DOWN, Tiles.WOOD_PLATFORM, 0], [Vector2i.RIGHT, Tiles.LOG, 2]]:
		grid.tiles = {sample[0]: sample[1]}
		assert_eq(Frames.attachment(Vector2i.ZERO, grid), sample[2])
	grid.tiles = {Vector2i.UP: Tiles.STONE}
	assert_eq(Frames.attachment(Vector2i.ZERO, grid), -1, "Ceiling alone cannot support a torch")
	grid.walls[Vector2i.ZERO] = Tiles.WOOD_WALL
	assert_eq(Frames.attachment(Vector2i.ZERO, grid), 0)

func test_attachment_falls_back_when_one_support_is_removed():
	var grid := Grid.new()
	grid.tiles = {Vector2i.DOWN: Tiles.STONE, Vector2i.LEFT: Tiles.LOG}
	assert_eq(Frames.attachment(Vector2i.ZERO, grid), 0)
	grid.tiles.erase(Vector2i.DOWN)
	assert_eq(Frames.attachment(Vector2i.ZERO, grid), 1)
	grid.tiles.clear()
	assert_eq(Frames.attachment(Vector2i.ZERO, grid), -1)

func test_complete_original_cell_and_flame_share_pixel_alignment():
	for flame_only in [false, true]:
		var source := Sprites.source_image("Flame_0.png" if flame_only else "Tiles_4.png")
		var atlas := Sprites.torch_atlas(flame_only).get_image()
		assert_eq(atlas.get_size(), Vector2i(54,18))
		for side in 3:
			var expected := Image.create(24,24,false,Image.FORMAT_RGBA8)
			expected.blit_rect(source, Rect2i(side*22,0,20,20), Vector2i(2,0))
			expected.resize(18,18,Image.INTERPOLATE_NEAREST)
			assert_true(atlas.get_region(Rect2i(side*18,0,18,18)).get_data() == expected.get_data(), "Full 20 px source cell is retained")
	var body := Sprites.torch_atlas().get_image()
	var bottom_pixels := 0
	for x in 18:
		if body.get_pixel(x,14).a > 0.0: bottom_pixels += 1
	assert_gt(bottom_pixels, 0, "Upright handle must reach the floor (tile top + 12)")
	assert_eq(body.get_pixel(8,15).a, 0.0, "Handle must not penetrate floor")

func test_flame_uses_matching_orientation_without_size_animation():
	var fx = Fx.instantiate()
	fx.orientation = 2
	add_child_autofree(fx)
	fx.set_process(false)
	assert_eq(fx.flame.frame, 2)
	for i in 24:
		fx._process(0.1)
		assert_eq(fx.flame.scale, Vector2.ONE)
		assert_lte(fx.flame.position.length(), 0.75)
	assert_true(fx.spark_timer.is_stopped())
	fx.set_orientation(1)
	assert_eq(fx.flame.frame, 1)

func test_cooking_pot_does_not_get_a_floating_torch_flame():
	var fx = Fx.instantiate()
	fx.tile_id = Tiles.COOKING_POT
	add_child_autofree(fx)
	assert_false(fx.flame.visible)
	assert_false(fx.is_processing())
