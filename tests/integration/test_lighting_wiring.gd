# 结构性验证: 整套光照/火把视觉栈是否正确接上。
# 不检查视觉效果, 只验证节点存在 + 资源已挂 + 关键路径 reachable。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const TILE_SIZE := 12


func _boot() -> Node:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	return main


func test_world_has_darkness_layer() -> void:
	# 旧 TileMapLayer 暗瓦已升级为 Sprite2D + bilinear 平滑光照
	var main = await _boot()
	var world: Node2D = main.get_node("World")
	var dl: Sprite2D = world.get_node_or_null("DarknessLayer")
	assert_not_null(dl, "World 下应有 DarknessLayer (Sprite2D)")
	# 等一帧让 _ready 创建 texture
	await wait_frames(2)
	assert_not_null(dl.texture, "DarknessLayer 应已挂 ImageTexture")
	# 老 CanvasModulate 应该没了
	assert_null(world.get_node_or_null("CanvasModulate"), "CanvasModulate 应已被移除")


func test_world_has_torch_lights_and_world_lighting_nodes() -> void:
	var main = await _boot()
	var world: Node2D = main.get_node("World")
	assert_not_null(world.get_node_or_null("TorchLights"), "TorchLights 容器存在")
	assert_not_null(world.get_node_or_null("WorldLighting"), "WorldLighting 管理节点存在")


func test_player_has_player_aura_and_sun_aura() -> void:
	var main = await _boot()
	var world: Node2D = main.get_node("World")
	var player: CharacterBody2D = world.get_player()
	assert_not_null(player, "玩家实例存在")
	var player_aura: PointLight2D = player.get_node_or_null("PlayerAura")
	var sun_aura: PointLight2D = player.get_node_or_null("SunAura")
	assert_not_null(player_aura, "PlayerAura 节点存在")
	assert_not_null(sun_aura, "SunAura 节点存在")
	# 等几帧让 _ready 跑完 + texture 挂上
	await wait_frames(2)
	assert_not_null(player_aura.texture, "PlayerAura.texture 应被 _ready 赋值")
	assert_not_null(sun_aura.texture, "SunAura.texture 应被 _ready 赋值")


func test_darkness_layer_covers_underground() -> void:
	var main = await _boot()
	var world: Node2D = main.get_node("World")
	var player: CharacterBody2D = world.get_player()
	var dl: Sprite2D = world.get_node("DarknessLayer")
	# 瞬移到地底
	player.global_position = Vector2(player.global_position.x, 200 * TILE_SIZE)
	# 等更新触发
	await wait_frames(15)
	# 读纹理像素: 玩家远端应有暗 alpha (远 > 6 tile, 光衰减完)
	var img: Image = dl.texture.get_image()
	var dark_pixels: int = 0
	for x in img.get_width():
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.5:
				dark_pixels += 1
	assert_gt(dark_pixels, 100, "地底视野内应有大量暗像素 (got %d)" % dark_pixels)


func test_torch_placement_creates_torch_fx_with_children() -> void:
	var main = await _boot()
	var world: Node2D = main.get_node("World")
	var torch_lights: Node2D = world.get_node("TorchLights")
	var initial_count: int = torch_lights.get_child_count()
	# 在 chunk 0 内一个空气位置放火把 (y=0 一定是 AIR)
	world._set_tile(10, 0, Tiles.TORCH)
	await wait_frames(2)
	assert_eq(torch_lights.get_child_count(), initial_count + 1, "TorchLights 应多 1 个子节点")
	var fx: Node2D = torch_lights.get_child(torch_lights.get_child_count() - 1)
	# 验证 TorchFx 结构: Flame / Light / SparkTimer 三个子节点
	assert_not_null(fx.get_node_or_null("Flame"), "TorchFx 应有 Flame 子节点")
	assert_not_null(fx.get_node_or_null("Light"), "TorchFx 应有 Light (兼容场景结构，禁用)")
	assert_not_null(fx.get_node_or_null("SparkTimer"), "TorchFx 应有 SparkTimer")
	# Light 节点保留但已禁用 (改用 DarknessLayer 瓦片光照)
	var light: PointLight2D = fx.get_node("Light")
	assert_false(light.enabled, "TorchFx.Light 应被禁用 (照明由 DarknessLayer 接管)")


func test_torch_removal_frees_torch_fx() -> void:
	var main = await _boot()
	var world: Node2D = main.get_node("World")
	var torch_lights: Node2D = world.get_node("TorchLights")
	world._set_tile(12, 0, Tiles.TORCH)
	await wait_frames(2)
	var after_place: int = torch_lights.get_child_count()
	world._set_tile(12, 0, Tiles.AIR)
	await wait_frames(3)  # queue_free 需要 1-2 帧
	assert_lt(torch_lights.get_child_count(), after_place, "拆掉 TORCH 后 TorchFx 应被 free")


func test_support_change_reorients_and_then_drops_torch_once() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	world._set_tile(15, 4, Tiles.STONE)
	world._set_tile(14, 3, Tiles.STONE)
	world._set_tile(15, 3, Tiles.TORCH)
	var pos := Vector2i(15, 3)
	assert_eq(world.terrain_layer.get_cell_atlas_coords(pos), Vector2i.ZERO)
	world._set_tile(15, 4, Tiles.AIR)
	assert_eq(world.chunk_manager.get_tile(15,3), Tiles.TORCH)
	assert_eq(world.terrain_layer.get_cell_atlas_coords(pos), Vector2i(1,0))
	var fx = world.world_lighting._torches[pos]
	assert_eq(fx.flame.frame, 1, "Flame stays on the reattached handle")
	var before: int = world.entities_root.get_child_count()
	world._set_tile(14, 3, Tiles.AIR)
	assert_eq(world.chunk_manager.get_tile(15,3), Tiles.AIR)
	assert_false(world.world_lighting._torches.has(pos))
	assert_eq(world.entities_root.get_child_count(), before + 1)
	world._refresh_torch_attachment(pos, true)
	assert_eq(world.entities_root.get_child_count(), before + 1, "Only one item is returned")
