extends GutTest

const Critter = preload("res://scripts/entities/critter.gd")
const World = preload("res://scenes/world/world.tscn")
const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")

func _animal(kind: String) -> CharacterBody2D:
	var animal = load("res://scenes/entities/%s.tscn" % kind).instantiate()
	add_child_autofree(animal)
	animal.process_mode = Node.PROCESS_MODE_DISABLED
	return animal

func test_species_use_their_own_uncropped_source_frames():
	for entry in [["bunny", 46, 48, 40], ["penguin", 148, 28, 42], ["frog", 361, 26, 22]]:
		var animal := _animal(entry[0])
		var source := Pack.source_image("NPC_%d.png" % entry[1]).get_region(Rect2i(0, 0, entry[2], entry[3]))
		source.flip_x()
		assert_eq(animal.sprite.sprite_frames.get_frame_texture("idle", 0).get_image().get_data(), source.get_data(), entry[0])
		assert_eq(animal.sprite.scale, Vector2(0.75, 0.75))
		assert_eq(animal.sprite.modulate, Color.WHITE)
		assert_eq(animal.current_health, 5)
		assert_false(animal.is_in_group("slimes"), "青蛙不能继承史莱姆的攻击、掉落和等级")
		assert_true(animal.drop_table.is_empty())

func test_critter_feet_and_collision_use_the_same_ground_line():
	for kind in ["bunny", "penguin", "frog"]:
		var animal := _animal(kind)
		var sprite: AnimatedSprite2D = animal.sprite
		var img := sprite.sprite_frames.get_frame_texture("idle", 0).get_image()
		var bottom: float = (img.get_used_rect().end.y - img.get_height() / 2.0) * sprite.scale.y + sprite.position.y
		assert_almost_eq(bottom, 0.0, 0.8, kind + " 不能悬空或埋进地面")
		var box: CollisionShape2D = animal.get_node("CollisionShape2D")
		assert_eq(box.position.y + box.shape.size.y / 2.0, 0.0)

func test_injury_does_not_permanently_enlarge_critter():
	var animal := _animal("penguin")
	animal.process_mode = Node.PROCESS_MODE_INHERIT
	animal.set_physics_process(false)
	assert_true(animal.take_damage(1, Vector2(-10, 0)))
	await wait_seconds(0.25)
	assert_eq(animal.sprite.scale, Vector2(0.75, 0.75))
	assert_eq(animal.current_health, 4)

func test_each_biome_selects_only_its_own_critter():
	var world_script = preload("res://scripts/world/world.gd")
	for entry in [[Tiles.GRASS, "bunny"], [Tiles.SNOW, "penguin"], [Tiles.ICE, "penguin"], [Tiles.JUNGLE_GRASS, "frog"]]:
		assert_eq(world_script._critter_scene_for_surface(entry[0]).resource_path, "res://scenes/entities/%s.tscn" % entry[1])
	for tid in [Tiles.SAND, Tiles.CORRUPT_GRASS, Tiles.CRIMSON_GRASS, Tiles.STONE, Tiles.PLANKS, Tiles.AIR]:
		assert_null(world_script._critter_scene_for_surface(tid))

func test_network_rejects_old_farm_animals_and_preserves_penguin_variant():
	var world = World.instantiate()
	world.defer_init = true
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for kind in ["cow", "sheep", "pig", "spider", "skeleton"]:
		assert_null(world._spawn_remote_entity(kind), kind)
	for kind in ["bunny", "penguin", "penguin_black", "frog"]:
		var animal = world._spawn_remote_entity(kind)
		assert_not_null(animal)
		assert_true(animal.has_meta("is_remote"))
		if kind == "penguin_black": assert_eq(animal.variant, 1)
	await get_tree().process_frame

class SurfaceGrid extends "res://scripts/world/chunk_manager.gd":
	var ground := Tiles.SNOW
	var flooded := false
	func get_tile(_x: int, y: int) -> int:
		if y >= 20: return ground
		if flooded and y >= 16: return Tiles.WATER
		return Tiles.AIR

func test_spawn_uses_real_ground_and_rejects_submerged_ground():
	var world = World.instantiate()
	world.defer_init = true
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var grid = autofree(SurfaceGrid.new())
	world.chunk_manager = grid
	world._spawn_at_column(world.PenguinScene, 8)
	assert_eq(world.entities_root.get_child_count(), 1)
	assert_eq(world.entities_root.get_child(0).position.y, 240.0)
	grid.flooded = true
	world._spawn_at_column(world.PenguinScene, 9)
	assert_eq(world.entities_root.get_child_count(), 1, "不能刷在积水中")
	grid.flooded = false
	world._spawn_at_column(world.BunnyScene, 9)
	assert_eq(world.entities_root.get_child_count(), 1, "雪地不能刷草地兔子")
	await get_tree().process_frame

func test_frog_swims_up_without_inheriting_slime_combat():
	var frog := _animal("frog")
	var grid = autofree(SurfaceGrid.new())
	grid.flooded = true
	frog._cached_cm = grid
	frog.position = Vector2(0, 225)
	frog.velocity = Vector2.ZERO
	frog._wander_dir = 1.0
	frog._wander_timer = 10.0
	for tick in 10: frog._physics_process(1.0 / 60.0)
	assert_lt(frog.velocity.y, 0.0)
	assert_eq(frog.sprite.animation, &"swim")
	grid.flooded = false
	frog._physics_process(0.1)
	assert_gt(frog.velocity.y, 0.0, "离水后恢复重力")
	assert_false(frog.has_method("_check_player_contact"))
