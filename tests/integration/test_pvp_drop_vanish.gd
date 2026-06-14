# 对战房: 凋落物不进背包, 碰到直接消失 (用户要求; 资源本来无限)。
extends GutTest
const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

func _fake_player_with(inv_started: bool) -> Node2D:
	var p := Node2D.new()
	p.add_to_group("player")
	var inv = load("res://scripts/player/player_inventory.gd").new()
	inv.name = "PlayerInventory"
	p.add_child(inv)
	add_child_autofree(p)
	return p

func test_drop_vanishes_in_pvp():
	var prev = NetworkManager.room_mode
	var player = _fake_player_with(false)
	var inv = player.get_node("PlayerInventory")
	await wait_frames(1)
	var drop = ItemDropScene.instantiate()
	drop.item_id = "dirt"; drop.count = 5
	add_child_autofree(drop)
	await wait_frames(1)
	drop._pickup_ready = true
	NetworkManager.room_mode = "pvp"
	drop._on_body_entered(player)
	assert_true(drop.is_queued_for_deletion(), "对战房: 碰到该消失")
	assert_false(inv.has_item("dirt"), "对战房: 不进背包")
	NetworkManager.room_mode = prev

func test_drop_pickup_in_survival():
	var prev = NetworkManager.room_mode
	var player = _fake_player_with(false)
	var inv = player.get_node("PlayerInventory")
	await wait_frames(1)
	var drop = ItemDropScene.instantiate()
	drop.item_id = "dirt"; drop.count = 3
	add_child_autofree(drop)
	await wait_frames(1)
	drop._pickup_ready = true
	NetworkManager.room_mode = "survival"
	drop._on_body_entered(player)
	assert_true(inv.has_item("dirt"), "生存: 正常进背包")
	NetworkManager.room_mode = prev
