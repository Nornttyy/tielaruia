# 游戏 HUD 容器。本 P 只承载 hotbar；后续 (P3) 加血条等。
extends CanvasLayer

@onready var hotbar: HBoxContainer = $HotbarAnchor/Hotbar


func bind_player(player: Node2D) -> void:
	var inv: Node = player.get_node_or_null("PlayerInventory")
	if inv == null:
		return
	hotbar.bind(inv)
