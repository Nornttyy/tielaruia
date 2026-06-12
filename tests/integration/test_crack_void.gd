# 地裂法杖: 瞄到虚空 (下方没地面) 不放裂缝 + 退还魔力 (用户: 地裂不能放在虚空)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const PlayerMana = preload("res://scripts/player/player_mana.gd")

var _crack_def := {"ground_crack": true, "spell_damage": 7}


func _boot() -> Node:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	return main


func test_crack_on_ground_returns_true() -> void:
	var main = _boot()
	await wait_frames(3)
	var player = main.get_node("World").get_player()
	var pa: Node = player.get_node("PlayerAction")
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = player.get_parent()
	# 瞄玩家脚下 (出生就站在地面上) → 下方有地面 → 该放成功
	var ok: bool = pa._cast_ground_crack(_crack_def, player.global_position, player.global_position, player, entities)
	assert_true(ok, "瞄准点下方有地面 → 地裂放成功")


func test_crack_in_void_returns_false() -> void:
	var main = _boot()
	await wait_frames(3)
	var player = main.get_node("World").get_player()
	var pa: Node = player.get_node("PlayerAction")
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = player.get_parent()
	# 瞄玩家头顶老高 (天上) → 下方 20 格还是空 → 不放
	var sky: Vector2 = player.global_position + Vector2(0, -3000)
	var ok: bool = pa._cast_ground_crack(_crack_def, sky, sky, player, entities)
	assert_false(ok, "瞄准点在虚空 → 地裂不放 (返回 false)")


func test_mana_refund_restores() -> void:
	var m = PlayerMana.new()
	add_child_autofree(m)
	m.current_mana = 50
	m.refund(12)
	assert_eq(m.current_mana, 62, "退还魔力该加回去")
	# 不超上限
	m.current_mana = m.MAX_MANA
	m.refund(30)
	assert_eq(m.current_mana, m.MAX_MANA, "退还不超过 MAX")
