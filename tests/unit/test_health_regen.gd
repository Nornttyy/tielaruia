extends GutTest

const HealthClass = preload("res://scripts/player/player_health.gd")
var hp

func before_each():
	hp = HealthClass.new()
	add_child_autofree(hp)

# 受伤后 REGEN_DELAY 内不回血
func test_no_regen_right_after_hit():
	hp.current_health = 50
	hp.take_damage(1)            # 触发 _since_hit_t = 0
	hp.current_health = 50       # 复位 (排除这 1 点伤害影响)
	# 模拟 2 秒 (< REGEN_DELAY_AFTER_HIT=4)
	for i in 120:
		hp._physics_process(1.0 / 60.0)
	assert_eq(hp.current_health, 50, "刚受击不该回血")

# 久未受击 → 按 REGEN_INTERVAL 回 REGEN_AMOUNT
func test_regen_after_delay():
	hp.current_health = 50
	hp._since_hit_t = 999.0      # 视为很久没被打
	# 模拟 2.1 秒 (> REGEN_INTERVAL=2.0) → 回 1 点
	for i in 126:
		hp._physics_process(1.0 / 60.0)
	assert_eq(hp.current_health, 51, "应回 1 点")

# 满血不回
func test_no_regen_at_full():
	hp.current_health = hp.MAX_HEALTH
	hp._since_hit_t = 999.0
	for i in 200:
		hp._physics_process(1.0 / 60.0)
	assert_eq(hp.current_health, hp.MAX_HEALTH, "满血不该溢出")
