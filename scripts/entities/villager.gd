# 村民 NPC: 站在原地, 不移动. 玩家近距按 E 触发 dialogue.
# 加入 "villagers" group 让 player_action 能查到附近村民.
extends Node2D

const VillagerArt = preload("res://scripts/art/villager_art.gd")

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("villagers")
	_anim.sprite_frames = VillagerArt.build_sprite_frames()
	_anim.animation = "idle"
	_anim.play()
