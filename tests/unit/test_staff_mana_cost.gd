# 法杖魔力消耗调低 (用户: 太费魔力). 正常局减半, 对战房减 80%, 至少 1 点。
extends GutTest

const PA = preload("res://scripts/player/player_action.gd")


func test_normal_game_halves_cost() -> void:
	# 木杖 5→3 (round 2.5), 铁杖 12→6, 地狱杖 20→10
	assert_eq(PA.staff_mana_cost(5, false), 3, "木杖正常局减半→3")
	assert_eq(PA.staff_mana_cost(12, false), 6, "铁杖正常局减半→6")
	assert_eq(PA.staff_mana_cost(20, false), 10, "地狱杖正常局减半→10")


func test_combat_room_cuts_80_percent() -> void:
	# ×0.2: 木杖 5→1, 铁杖 12→2 (round 2.4), 地狱杖 20→4
	assert_eq(PA.staff_mana_cost(5, true), 1, "木杖对战房减80%→1")
	assert_eq(PA.staff_mana_cost(12, true), 2, "铁杖对战房减80%→2")
	assert_eq(PA.staff_mana_cost(20, true), 4, "地狱杖对战房减80%→4")


func test_cost_never_below_one() -> void:
	assert_eq(PA.staff_mana_cost(1, true), 1, "再便宜也至少花 1 点 mana")
	assert_eq(PA.staff_mana_cost(2, true), 1, "2×0.2=0.4 也保底 1")
