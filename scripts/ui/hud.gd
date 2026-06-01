# 游戏 HUD: hotbar + 血条 + 小地图. 饱食度已删, 食物直接回血.
extends CanvasLayer

@onready var hotbar: HBoxContainer = $HotbarAnchor/Hotbar
@onready var health_hud: Control = $HealthHUD
@onready var mana_hud: Control = $ManaHUD
@onready var minimap: Control = $Minimap
@onready var buff_hud: Control = $BuffHUD


func bind_player(player: Node2D) -> void:
	var inv: Node = player.get_node_or_null("PlayerInventory")
	if inv != null:
		hotbar.bind(inv)
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null:
		health_hud.bind(hp)
	var mana: Node = player.get_node_or_null("PlayerMana")
	if mana != null and mana_hud != null:
		mana_hud.bind(mana)
	if minimap != null and minimap.has_method("bind_player"):
		minimap.bind_player(player)
	var buffs: Node = player.get_node_or_null("PlayerBuffs")
	if buffs != null and buff_hud != null and buff_hud.has_method("bind"):
		buff_hud.bind(buffs)
