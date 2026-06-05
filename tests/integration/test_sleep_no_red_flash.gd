# 床睡觉无敌 (iframe 设成 999) 不该让玩家红闪 — 那是"受伤无敌"才有的视觉。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _setup() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	return {"main": main, "player": player, "hp": player.get_node("PlayerHealth"),
		"sprite": player.get_node("AnimatedSprite2D")}


func test_sleep_invincibility_no_red_flash() -> void:
	var ctx: Dictionary = await _setup()
	var hp: Node = ctx["hp"]
	hp._iframe_timer = 999.0          # 床睡觉的无敌
	hp._update_iframe_flash()
	assert_eq(ctx["sprite"].modulate, Color.WHITE, "睡觉无敌(iframe 999)不该红闪, 该保持白色")


func test_normal_hit_still_flashes_red() -> void:
	# 没误伤"受伤红闪": 正常受伤无敌 (≤0.6s) 还是会红
	var ctx: Dictionary = await _setup()
	var hp: Node = ctx["hp"]
	hp._iframe_timer = hp.IFRAMES_SEC   # t=0 → 红相
	hp._update_iframe_flash()
	assert_eq(ctx["sprite"].modulate, Color(1.6, 0.6, 0.6), "正常受伤无敌该红闪")
