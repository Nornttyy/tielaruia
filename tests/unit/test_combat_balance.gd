# 武器/怪物数值平衡测试. 锁定 Terraria 风基线 + 难度缩放正确.
extends GutTest

const Slime       = preload("res://scripts/entities/slime.gd")
const Spider      = preload("res://scripts/entities/spider.gd")
const HellWasp    = preload("res://scripts/entities/hell_wasp.gd")
const Imp         = preload("res://scripts/entities/imp.gd")
const Mimic       = preload("res://scripts/entities/mimic.gd")
const Skeleton    = preload("res://scripts/entities/skeleton.gd")
const DemonEye    = preload("res://scripts/entities/demon_eye.gd")
const Zombie      = preload("res://scripts/entities/zombie.gd")


func before_each():
	GameSettings.current_difficulty = 1   # 默认普通难度


func after_all():
	GameSettings.current_difficulty = 1


# ===== Terraria 风基线 (普通难度) =====

func test_baseline_slime_hp_and_damage():
	assert_eq(Slime.BASE_MAX_HEALTH, 25, "史莱姆 HP 基线 25 (木剑 9 击, 钻剑 2 击)")
	assert_eq(Slime.CONTACT_DAMAGE, 6, "史莱姆接触伤 6 (100HP 玩家被打 17 次死)")


func test_baseline_demon_eye():
	assert_eq(DemonEye.BASE_MAX_HEALTH, 20)
	assert_eq(DemonEye.CONTACT_DAMAGE, 8)


func test_baseline_spider():
	# 用户调 v2: HP 20 / 接触 10 / 速度 55. 木剑 7 击死, 玩家 10 击死. 给反应余地.
	assert_eq(Spider.BASE_MAX_HEALTH, 20)
	assert_eq(Spider.CONTACT_DAMAGE, 10)
	assert_almost_eq(Spider.WALK_SPEED, 55.0, 0.01)


func test_baseline_hell_wasp():
	assert_eq(HellWasp.BASE_MAX_HEALTH, 30)
	assert_eq(HellWasp.CONTACT_DAMAGE, 12)


func test_baseline_imp():
	# 注: 火球伤害 (14) 在 fireball.gd, 由于跟法杖功能并发改, 不在这里断言常量名
	assert_eq(Imp.BASE_MAX_HEALTH, 50, "Imp 远程, HP 50 (比近战略多)")


func test_baseline_mimic():
	assert_eq(Mimic.BASE_MAX_HEALTH, 90, "Mimic 血厚陷阱怪")
	assert_eq(Mimic.CONTACT_DAMAGE, 16)


func test_baseline_skeleton():
	assert_eq(Skeleton.BASE_MAX_HEALTH, 80, "地狱骨架 Boss 级")
	assert_eq(Skeleton.CONTACT_DAMAGE, 18, "钻剑也要 4 击, 玩家 6 次被打就死")


# ===== 难度缩放 =====

func test_enemy_hp_multiplier_values():
	GameSettings.current_difficulty = 0
	assert_almost_eq(GameSettings.enemy_hp_multiplier(), 0.7, 0.01, "简单 0.7×")
	GameSettings.current_difficulty = 1
	assert_almost_eq(GameSettings.enemy_hp_multiplier(), 1.0, 0.01, "普通 1.0×")
	GameSettings.current_difficulty = 2
	assert_almost_eq(GameSettings.enemy_hp_multiplier(), 1.4, 0.01, "困难 1.4×")


# slime spawn 时 HP 应按当前难度缩放
func test_slime_hp_scales_easy():
	GameSettings.current_difficulty = 0
	var s := Slime.new()
	add_child_autofree(s)
	# 简单 25 × 0.7 = 17.5 → 18 (round)
	assert_eq(s.max_health, 18, "简单史莱姆 18 HP")
	assert_eq(s.current_health, 18)


func test_slime_hp_scales_normal():
	GameSettings.current_difficulty = 1
	var s := Slime.new()
	add_child_autofree(s)
	assert_eq(s.max_health, 25, "普通史莱姆 25 HP (基线)")


func test_slime_hp_scales_hard():
	GameSettings.current_difficulty = 2
	var s := Slime.new()
	add_child_autofree(s)
	# 困难 25 × 1.4 = 35
	assert_eq(s.max_health, 35, "困难史莱姆 35 HP")
	assert_eq(s.current_health, 35)


func test_skeleton_hp_scales_hard():
	GameSettings.current_difficulty = 2
	var s := Skeleton.new()
	add_child_autofree(s)
	# 困难 80 × 1.4 = 112
	assert_eq(s.max_health, 112, "困难骨架 112 HP")


# ===== 杀几击 (回归保护) =====
# 用直接 take_damage 跳过 i-frame 把 base HP 打到 0, 看几次.

func test_diamond_sword_kills_slime_in_2_hits():
	GameSettings.current_difficulty = 1
	var s := Slime.new()
	add_child_autofree(s)
	# 钻剑 20 dmg vs 25 HP slime → 2 击死
	s.take_damage(20)
	# 等 i-frame 过去 (0.2s) — 用循环时间
	s._iframe_t = 0.0   # 直接清掉 iframe 测试用
	s.take_damage(20)
	assert_eq(s.current_health, 0, "钻剑 20 × 2 击 = 40 > 25 HP slime")


func test_wood_sword_kills_slime_in_9_hits():
	GameSettings.current_difficulty = 1
	var s := Slime.new()
	add_child_autofree(s)
	# 木剑 3 dmg vs 25 HP → 9 击
	for i in 9:
		s._iframe_t = 0.0
		s.take_damage(3)
	assert_eq(s.current_health, 0, "木剑 3 × 9 = 27 ≥ 25 HP slime 死透")


# ===== 武器 tier 表 =====
# 不直接测武器 tier 表 — 它在 player_action 私有. 测怪 HP 跟武器 tier 比是足够间接证据.
