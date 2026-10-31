extends GutTest
const Player = preload("res://scenes/player/player.tscn")
const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
var p: CharacterBody2D
var inv: Node
var held: Sprite2D

func before_each():
	p = Player.instantiate()
	add_child_autofree(p)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	inv = p.get_node("PlayerInventory")
	held = p.get_node("HeldItem")
	inv.inventory.slots.fill(null)
	inv.pickup("copper_pickaxe", 1)
	inv.set_hotbar_selection(0)

func test_swing_moves_original_arms_while_walk_keeps_playing():
	p.sprite.play("walk")
	p.sprite.frame = 4
	held.play_pickaxe_attack(0.0)
	assert_eq(p._action_anim, "swing")
	assert_true(p.get_node("UsePose").visible)
	assert_eq(held.position, p.action_hand_position, "挥击起手握柄对准原片手掌")
	assert_eq(p.sprite.animation, &"walk", "腿部不被攻击覆盖成站姿")
	var start: Image = p.get_node("UsePose").texture.get_image()
	p._action_timer = p._action_duration * 0.45
	p._update_action_visual()
	held._process(0.0)
	assert_eq(held.position, p.action_hand_position, "挥击中握柄跟随手臂帧")
	assert_ne(start.get_data(), p.get_node("UsePose").texture.get_image().get_data(), "抬手与落手必须是不同的原片姿势")
	p._action_timer = 0.0
	p._update_action_visual()
	assert_false(p.get_node("UsePose").visible)
	assert_eq(p.sprite.self_modulate.a, 1.0)

func test_thrust_place_and_bow_face_target_on_both_sides():
	for angle in [0.2, PI - 0.2]:
		for action in ["play_thrust", "play_place", "play_bow_shoot"]:
			held.call(action, angle)
			assert_gt(p._action_timer, 0.0)
			assert_eq(p.get_node("UsePose").flip_h, cos(angle) < 0.0)
			assert_eq(held._facing_right, cos(angle) >= 0.0)

func test_picking_up_material_does_not_cancel_use_but_switching_does():
	held.play_pickaxe_attack(0.0)
	inv.pickup("stone", 1)
	assert_gt(p._action_timer, 0.0)
	inv.set_hotbar_selection(1)
	assert_eq(p._action_timer, 0.0)
	assert_false(held.visible)
	assert_eq(held.rotation, 0.0)

func test_original_tool_scale_grip_and_bow_orientation():
	assert_eq(held.scale.abs(), Vector2(0.75, 0.75))
	assert_eq(held.offset.x, -2.0, "原始斜向贴图握柄在左下角")
	inv.inventory.slots[0] = {"item_id": "wood_bow", "count": 1}
	inv.inventory_changed.emit()
	held.aim_bow(0.0)
	assert_almost_eq(held.rotation, 0.0, 0.001, "原始木弓凸面向右")
	inv.pickup("stone", 1)
	assert_eq(held.offset, Vector2.ZERO, "射箭时捡材料仍保持弓的中心支点")
	held.aim_bow(PI)
	assert_almost_eq(held.rotation, 0.0, 0.001)
	assert_lt(held.scale.x, 0.0)

func test_poses_keep_stable_bounds_and_directional_variants():
	var idle := Pack.player_frame({}, 0).get_image()
	var samples := {}
	for pose in ["swing", "thrust", "place", "bow", "eat"]:
		for step in [-3, 0, 3]:
			var img := Pack.action_frame({}, 0, pose, 1, step).get_image()
			assert_eq(img.get_size(), idle.get_size())
			assert_ne(img.get_data(), idle.get_data())
			samples[hash(img.get_data())] = true
	assert_gt(samples.size(), 5)

func test_tools_also_swing_when_using_them_in_empty_air():
	var action = p.get_node("PlayerAction")
	for id in ["copper_pickaxe", "copper_axe"]:
		inv.inventory.slots[0] = {"item_id": id, "count": 1}
		inv.inventory_changed.emit()
		action.primary_override = true
		action._attack_cooldown = 0.0
		action._physics_process(0.016)
		assert_eq(p._action_anim, "swing", id)
		assert_true(held.visible, "空挥不要求旁边必须有怪")
