# 普通状态摔落规则：25 格安全，超出每格 10，按整格结算。
extends GutTest

const PlayerController = preload("res://scripts/player/player_controller.gd")


func test_safe_height_no_damage() -> void:
	assert_eq(PlayerController.fall_damage_for_height(0.0), 0, "站着不动不摔伤")
	assert_eq(PlayerController.fall_damage_for_height(5.0), 0, "摔 5 格不疼")
	assert_eq(PlayerController.fall_damage_for_height(20.0), 0)
	assert_eq(PlayerController.fall_damage_for_height(25.0), 0)


func test_reference_falls_without_defense() -> void:
	assert_eq(PlayerController.fall_damage_for_height(26.0), 10)
	assert_eq(PlayerController.fall_damage_for_height(32.0), 70)
	assert_eq(PlayerController.fall_damage_for_height(64.0), 390)


func test_fractional_distance_is_not_fractional_damage() -> void:
	assert_eq(PlayerController.fall_damage_for_height(25.9), 0)
	assert_eq(PlayerController.fall_damage_for_height(26.9), 10)
	assert_eq(PlayerController.fall_damage_for_height(-1.0), 0)
