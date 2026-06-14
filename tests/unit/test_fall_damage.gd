# 坠落伤害公式验收: 按摔落高度 (格) → 扣血。安全 10 格内 0; 超过后每格 +3 (用户规则)。
extends GutTest

const PlayerController = preload("res://scripts/player/player_controller.gd")


func test_safe_height_no_damage() -> void:
	assert_eq(PlayerController.fall_damage_for_height(0.0), 0, "站着不动不摔伤")
	assert_eq(PlayerController.fall_damage_for_height(5.0), 0, "摔 5 格不疼")
	assert_eq(PlayerController.fall_damage_for_height(10.0), 0, "刚好 10 格安全, 不疼")


func test_above_safe_three_per_tile() -> void:
	assert_eq(PlayerController.fall_damage_for_height(11.0), 3, "摔 11 格 → 超 1 格 → 3 点")
	assert_eq(PlayerController.fall_damage_for_height(13.0), 9, "摔 13 格 → 超 3 格 → 9 点")
	assert_eq(PlayerController.fall_damage_for_height(20.0), 30, "摔 20 格 → 超 10 格 → 30 点")
	# 摔得越高越疼
	assert_gt(PlayerController.fall_damage_for_height(25.0),
		PlayerController.fall_damage_for_height(15.0), "摔得越高扣越多")


func test_per_tile_matches_const() -> void:
	# 超安全 1 格 = 每格伤害值 FALL_DMG_PER_TILE
	var d11: int = PlayerController.fall_damage_for_height(PlayerController.FALL_SAFE_TILES + 1.0)
	assert_eq(d11, PlayerController.FALL_DMG_PER_TILE, "超安全 1 格 = 每格伤害值")
