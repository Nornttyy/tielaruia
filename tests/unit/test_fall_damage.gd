# 坠落伤害公式验收: 落地冲击速度 → 扣血 (安全值内 0, 超出线性 + 封顶)。
extends GutTest

const PlayerController = preload("res://scripts/player/player_controller.gd")


func test_safe_speed_no_damage() -> void:
	assert_eq(PlayerController.fall_damage_for(0.0), 0, "站着不动不摔伤")
	assert_eq(PlayerController.fall_damage_for(300.0), 0, "小跳落地不疼")
	assert_eq(PlayerController.fall_damage_for(PlayerController.FALL_DMG_VY_SAFE), 0, "刚好安全速度不疼")


func test_above_safe_takes_damage() -> void:
	var d: int = PlayerController.fall_damage_for(PlayerController.FALL_DMG_VY_SAFE + 200.0)
	assert_gt(d, 0, "超安全速度该摔伤")
	# 摔得越快越疼
	var d_fast: int = PlayerController.fall_damage_for(PlayerController.FALL_DMG_VY_SAFE + 400.0)
	assert_gt(d_fast, d, "摔得越快扣越多")


func test_damage_capped() -> void:
	var huge: int = PlayerController.fall_damage_for(9999.0)
	assert_eq(huge, PlayerController.FALL_DMG_MAX, "超高坠落封顶 (满血摔不死)")
	assert_lt(PlayerController.FALL_DMG_MAX, 100, "封顶 < 满血 100 → 不会一摔就死")
