extends GutTest

const PlayerScene = preload("res://scenes/player/player.tscn")
var player: CharacterBody2D
var _previous_creative: bool

func before_each():
	_previous_creative = GameSettings.creative_mode
	GameSettings.creative_mode = false
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4000, 12)
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position = Vector2(0, 106)
	add_child_autofree(floor_body)
	player = PlayerScene.instantiate()
	player.position = Vector2(0, 95)
	add_child_autofree(player)
	for i in 20:
		await get_tree().physics_frame
	assert_true(player.is_on_floor())

func after_each():
	for action in ["jump", "move_right", "move_left"]:
		Input.action_release(action)
	GameSettings.creative_mode = _previous_creative

func _jump_height(hold_ticks: int) -> float:
	var floor_y := player.position.y
	var peak := floor_y
	Input.action_press("jump")
	for i in 75:
		if i == hold_ticks:
			Input.action_release("jump")
		await get_tree().physics_frame
		peak = minf(peak, player.position.y)
	return (floor_y - peak) / 12.0

func test_full_jump_reaches_reference_six_tiles():
	var height := await _jump_height(30)
	assert_between(height, 6.0, 6.6, "按住跳跃应约 6.27 格；实际 %.3f" % height)

func test_tap_jump_is_lower_than_hold():
	var height := await _jump_height(1)
	assert_between(height, 1.5, 3.0, "点按只做短跳；实际 %.3f" % height)

func test_running_accelerates_then_stops_without_ice_slide():
	Input.action_press("move_right")
	for i in 45:
		await get_tree().physics_frame
	assert_almost_eq(player.velocity.x, 135.0, 0.1)
	var before := player.position.x
	Input.action_release("move_right")
	for i in 18:
		await get_tree().physics_frame
	assert_almost_eq(player.velocity.x, 0.0, 0.1)
	assert_between(player.position.x - before, 10.0, 20.0)
	assert_eq(player.sprite.animation, "idle")

func test_ceiling_ends_held_jump():
	var ceiling := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120, 12)
	collider.shape = shape
	ceiling.add_child(collider)
	ceiling.position = Vector2(0, 40)
	add_child_autofree(ceiling)
	Input.action_press("jump")
	for i in 50:
		await get_tree().physics_frame
	assert_true(player.is_on_floor(), "碰头后应落地，持续按住不能粘在天花板")
