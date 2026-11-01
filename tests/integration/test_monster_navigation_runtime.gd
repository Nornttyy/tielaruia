extends GutTest
const Nav = preload("res://scripts/entities/mob_nav.gd")
const Pathfinder = preload("res://scripts/entities/mob_pathfinder.gd")
const Fly = preload("res://scripts/entities/flying_nav.gd")
const World = preload("res://scripts/world/world.gd")
class Map extends Node:
	var cells: Dictionary = {}
	var reads := 0
	func get_tile(x: int, y: int) -> int:
		reads += 1
		return cells.get(Vector2i(x,y), Tiles.AIR)
var map: Map
var player: CharacterBody2D

func before_each():
	map = Map.new()
	map.add_to_group("chunk_manager")
	add_child_autofree(map)
	player = CharacterBody2D.new()
	player.add_to_group("player")
	player.collision_layer = 0
	player.collision_mask = 0
	player.position = Vector2(150, 120)
	add_child_autofree(player)

func _floor(from_x: int, to_x: int, y: int):
	for x in range(from_x, to_x + 1): map.cells[Vector2i(x,y)] = Tiles.STONE
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2((to_x - from_x + 1) * 12, 12)
	collider.shape = shape
	body.add_child(collider)
	body.position = Vector2((from_x + to_x + 1) * 6, y * 12 + 6)
	add_child_autofree(body)

func _spawn(kind: String, pos: Vector2) -> CharacterBody2D:
	var mob = load("res://scenes/entities/" + kind + ".tscn").instantiate()
	mob.position = pos
	add_child_autofree(mob)
	return mob

func test_zombie_gets_real_ground_path_and_reverses_when_player_crosses():
	_floor(-10, 25, 10)
	var mob := _spawn("zombie", Vector2(42,119.9))
	for i in 45: await get_tree().physics_frame
	assert_false(mob._nav.path.is_empty(), "真实站地坐标也必须能寻路")
	assert_gt(mob.position.x, 52.0)
	assert_false(mob.sprite.flip_h)
	player.position.x = 12
	for i in 4: await get_tree().physics_frame
	assert_lt(mob.velocity.x, 0.0, "玩家绕背后立即转向")
	assert_true(mob.sprite.flip_h)

func test_mummy_can_climb_two_tile_ledge():
	_floor(-10, 25, 10)
	_floor(7, 25, 9)
	_floor(7, 25, 8)
	player.position = Vector2(150,96)
	var mob := _spawn("mummy", Vector2(66,119.9))
	for i in 180: await get_tree().physics_frame
	assert_gt(mob.position.x, 95.0, "应跳上台阶继续追击，不能卡在侧面")
	assert_lt(mob.position.y, 97.0)

func test_air_route_goes_around_wall_without_cutting_through_it():
	for y in range(2, 9): map.cells[Vector2i(5,y)] = Tiles.STONE
	var path := Fly.find_path(map, Vector2i(2,5), Vector2i(9,5), Vector2(8,8))
	assert_false(path.is_empty())
	var detour := false
	for cell in path:
		assert_true(Fly.clear_at(map, cell, Vector2(8,8)))
		if cell.y < 2 or cell.y > 8: detour = true
	assert_true(detour, "路线必须绕过墙体端部")

func test_tall_monster_does_not_plan_through_low_tunnel():
	_floor(0,12,10)
	map.cells[Vector2i(5,7)] = Tiles.STONE
	assert_false(Pathfinder.find_path(map, Vector2i(2,9), Vector2i(9,9), 2).is_empty())
	assert_true(Pathfinder.find_path(map, Vector2i(2,9), Vector2i(9,9), 3).is_empty())

func test_unreachable_route_is_not_recomputed_every_frame():
	_floor(0,12,10)
	for y in range(0,10): map.cells[Vector2i(5,y)] = Tiles.STONE
	var nav := Nav.new()
	assert_eq(nav.steer(map, Vector2i(2,9), Vector2i(9,9), 0.016), Nav.NO_PATH)
	var before := map.reads
	for i in 10: nav.steer(map, Vector2i(2,9), Vector2i(9,9), 0.016)
	assert_eq(map.reads, before, "无路时也遵守搜索冷却")

func test_skeleton_is_removed_from_spawns_and_remote_messages():
	for depth in [10, 40, 150, 230]:
		for i in 10:
			assert_false(World._night_spawn_scene(depth, i / 10.0).resource_path.contains("skeleton"))
	var world := World.new()
	assert_null(world._spawn_remote_entity("skeleton"))
	assert_null(world._spawn_remote_entity("spider"))
	world.free()
