extends GutTest

# 对战房 (combat_enabled) 里消耗品无限: 魔力 (法杖/魔法枪) + 子弹 (枪) 都不扣。
# 箭/血药/方块的无限早有, 这里补魔力 + 子弹 (魔法/枪械对战模式新加的)。
const MainScene = preload("res://scenes/main.tscn")
const PlayerMana = preload("res://scripts/player/player_mana.gd")
const BulletScript = preload("res://scripts/entities/bullet.gd")


func _set_pvp(on: bool) -> void:
	NetworkManager.status = "connected" if on else "idle"
	NetworkManager.room_mode = "pvp" if on else "survival"


func _count_script_in(node: Node, script) -> int:
	var n := 0
	for c in node.get_children():
		if c.get_script() == script:
			n += 1
		n += _count_script_in(c, script)
	return n


func test_mana_infinite_in_pvp():
	var prev_s = NetworkManager.status
	var prev_m = NetworkManager.room_mode
	var m = PlayerMana.new()
	add_child_autofree(m)
	m.current_mana = 0
	_set_pvp(true)
	assert_true(m.try_consume(50), "对战房: 0 魔力也能放 (魔力无限)")
	assert_eq(m.current_mana, 0, "对战房不扣魔力")
	NetworkManager.status = prev_s
	NetworkManager.room_mode = prev_m


func test_mana_consumes_normally_outside_pvp():
	var prev_s = NetworkManager.status
	var prev_m = NetworkManager.room_mode
	var m = PlayerMana.new()
	add_child_autofree(m)
	_set_pvp(false)
	m.current_mana = 30
	assert_true(m.try_consume(20), "够魔力能放")
	assert_eq(m.current_mana, 10, "非对战正常扣 20")
	assert_false(m.try_consume(50), "魔力不够放不了")
	NetworkManager.status = prev_s
	NetworkManager.room_mode = prev_m


func test_gun_infinite_bullets_in_pvp():
	var prev_s = NetworkManager.status
	var prev_m = NetworkManager.room_mode
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv = player.get_node("PlayerInventory")
	inv.pickup("pistol", 1)
	inv.hotbar_selected = 0          # 手枪在第 0 格, 故意不给子弹
	var action = player.get_node("PlayerAction")
	action.mouse_world_override = player.global_position + Vector2(240, -12)
	_set_pvp(true)
	var before := _count_script_in(world, BulletScript)
	action._try_fire_gun()
	await wait_frames(2)
	assert_gt(_count_script_in(world, BulletScript), before, "对战房没子弹也能射 (子弹无限)")
	NetworkManager.status = prev_s
	NetworkManager.room_mode = prev_m
