extends GutTest
const PlayerScene = preload("res://scenes/player/player.tscn")
var player
var action
func before_each():
	player = PlayerScene.instantiate()
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	action = player.get_node("PlayerAction")
func target_at(point: Vector2, body_size: Vector2) -> Node2D:
	var body := Node2D.new()
	body.position = point
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = body_size
	collider.shape = shape
	collider.position.y = -body_size.y / 2.0
	body.add_child(collider)
	add_child_autofree(body)
	return body
func test_blade_hits_body_above_feet_but_not_nearby_enemy_behind_player():
	var ahead := target_at(Vector2(27, 0), Vector2(15, 30))
	var behind := target_at(Vector2(-20, 0), Vector2(15, 30))
	assert_true(action._blade_intersects_body(ahead, Vector2(4, -15), Vector2(30, -15), 5.0))
	assert_false(action._blade_intersects_body(behind, Vector2(4, -15), Vector2(30, -15), 5.0))
func test_large_target_edge_can_be_hit_without_reaching_its_center():
	var large := target_at(Vector2(65, 0), Vector2(80, 60))
	assert_true(action._blade_intersects_body(large, Vector2(4, -15), Vector2(30, -15), 5.0))
	assert_false(action._blade_intersects_body(large, Vector2(4, -15), Vector2(18, -15), 5.0))
func test_dagger_segment_follows_visible_weapon_and_mirrors():
	var inv = player.get_node("PlayerInventory")
	inv.inventory.slots[0] = {"item_id": "copper_dagger", "count": 1}
	inv.set_hotbar_selection(0)
	inv.inventory_changed.emit()
	var held = player.get_node("HeldItem")
	held.play_thrust(0.0)
	held.advance_use_anim(0.05)
	var right: PackedVector2Array = held.blade_world_segment()
	assert_gt(right[1].x, right[0].x + 10.0)
	held.play_thrust(PI)
	held.advance_use_anim(0.05)
	var left: PackedVector2Array = held.blade_world_segment()
	assert_lt(left[1].x, left[0].x - 10.0)
	assert_almost_eq(right[0].distance_to(right[1]), left[0].distance_to(left[1]), 0.01)
