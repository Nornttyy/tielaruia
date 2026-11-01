extends GutTest
const PlayerScene = preload("res://scenes/player/player.tscn")
class WaterMap extends Node:
	func get_tile(x: int, y: int) -> int:
		return Tiles.WATER if x < 4 and y >= 4 and y < 9 else Tiles.AIR
	func get_chunk(_x: int):
		return null
var player: CharacterBody2D
var old_creative: bool
func _box(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = pos
	add_child_autofree(body)
func before_each():
	old_creative = GameSettings.creative_mode
	GameSettings.creative_mode = false
	_box(Vector2(0, 106), Vector2(800, 12))
	player = PlayerScene.instantiate()
	player.position = Vector2(0, 95)
	add_child_autofree(player)
	var water := WaterMap.new()
	add_child_autofree(water)
	player._cached_chunk_manager = water
	for i in 20: await get_tree().physics_frame
func after_each():
	for action in ["jump", "move_right", "move_left"]: Input.action_release(action)
	GameSettings.creative_mode = old_creative
func test_water_ground_jump_can_clear_two_tile_shore():
	_box(Vector2(124, 100), Vector2(152, 48))
	Input.action_press("jump")
	Input.action_press("move_right")
	for i in 75: await get_tree().physics_frame
	Input.action_release("jump")
	for i in 40: await get_tree().physics_frame
	assert_gt(player.position.x, 90.0, "应当越过 x=48 的水岸，不粘在侧壁")
	assert_lt(player.position.y, 77.0, "应当站到高两格的岸上")
func test_holding_jump_in_midwater_does_not_create_free_swimming():
	player.position = Vector2(0, 83)
	player.velocity = Vector2.ZERO
	for i in 2: await get_tree().physics_frame
	Input.action_press("jump")
	for i in 4: await get_tree().physics_frame
	assert_gt(player.velocity.y, 0.0, "没有游泳装备时悬水中按跳跃仍应下沉")
func test_one_tile_bank_can_be_walked_up():
	_box(Vector2(124, 100), Vector2(152, 24))
	Input.action_press("move_right")
	for i in 120: await get_tree().physics_frame
	assert_gt(player.position.x, 75.0)
	assert_between(player.position.y, 87.0, 89.0)
func test_two_tile_wall_is_not_stepped_through():
	_box(Vector2(124, 100), Vector2(152, 48))
	Input.action_press("move_right")
	for i in 90: await get_tree().physics_frame
	assert_lt(player.position.x, 42.0)
