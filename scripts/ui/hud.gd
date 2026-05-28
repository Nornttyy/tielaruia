# 游戏 HUD: hotbar + 血条 + 小地图. 饱食度已删, 食物直接回血.
extends CanvasLayer

@onready var hotbar: HBoxContainer = $HotbarAnchor/Hotbar
@onready var health_hud: Control = $HealthHUD
@onready var minimap: Control = $Minimap


func bind_player(player: Node2D) -> void:
	var inv: Node = player.get_node_or_null("PlayerInventory")
	if inv != null:
		hotbar.bind(inv)
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null:
		health_hud.bind(hp)
	if minimap != null and minimap.has_method("bind_player"):
		minimap.bind_player(player)
