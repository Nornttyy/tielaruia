# 游戏 HUD: hotbar + 血条 + 鸡腿条 + 小地图。
extends CanvasLayer

@onready var hotbar: HBoxContainer = $HotbarAnchor/Hotbar
@onready var health_hud: Control = $HealthHUD
@onready var hunger_hud: Control = $HungerHUD
@onready var minimap: Control = $Minimap


func bind_player(player: Node2D) -> void:
	var inv: Node = player.get_node_or_null("PlayerInventory")
	if inv != null:
		hotbar.bind(inv)
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null:
		health_hud.bind(hp)
	var hg: Node = player.get_node_or_null("PlayerHunger")
	if hg != null:
		hunger_hud.bind(hg)
	if minimap != null and minimap.has_method("bind_player"):
		minimap.bind_player(player)
