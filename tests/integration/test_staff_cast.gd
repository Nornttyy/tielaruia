# 回归测试: 发射类法杖 (wood/iron/hell) 发火球不应炸到/扣血施法者自己.
# 用户报: "发射类法杖只会攻击到玩家(直接炸开)、会掉血自己炸自己、火球不飞".
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _cast_and_check(staff_id: String) -> void:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	assert_not_null(player, "player 就绪")
	var inv_node = player.get_node("PlayerInventory")
	inv_node.pickup(staff_id, 1)
	inv_node.hotbar_selected = 0          # 法杖进了第 0 格 (boot 背包空)
	var mana = player.get_node("PlayerMana")
	mana.current_mana = 100               # 魔力拉满, 保证能施法
	var hp = player.get_node("PlayerHealth")
	var hp_before: int = hp.current_health
	var px: float = player.global_position.x
	var action = player.get_node("PlayerAction")
	# 朝右上方远处空中施法 (避开地面, 火球应水平飞出)
	action.mouse_world_override = player.global_position + Vector2(240, -12)
	action._try_cast_staff()
	await wait_frames(15)                  # 让火球飞 / 判定若干帧
	gut.p("[staff] %s: hp %d→%d" % [staff_id, hp_before, hp.current_health])
	assert_eq(hp.current_health, hp_before, "%s 发射不应扣施法者自己血 (自己炸自己 bug)" % staff_id)


func test_wood_staff_no_self_damage() -> void:
	await _cast_and_check("wood_staff")


func test_hell_staff_no_self_damage() -> void:
	await _cast_and_check("hell_staff")


# 反向保护: Imp 发的火球 (player_cast=false) 必须仍能撞到玩家扣血 —— 别因为修法杖把怪的火球改哑了.
func test_imp_fireball_still_hits_player() -> void:
	const FireballScene = preload("res://scenes/entities/fireball.tscn")
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	var hp = player.get_node("PlayerHealth")
	var hp_before: int = hp.current_health
	var fb = FireballScene.instantiate()
	player.get_parent().add_child(fb)
	# 朝玩家发, player_cast=false (Imp 式): 火球生成即贴着玩家 → 应撞上扣 10
	fb.setup(player.global_position + Vector2(20, 0), player.global_position, 10, false)
	await wait_frames(10)
	gut.p("[imp-fb] hp %d→%d" % [hp_before, hp.current_health])
	assert_lt(hp.current_health, hp_before, "Imp 火球 (player_cast=false) 仍应撞玩家扣血")
