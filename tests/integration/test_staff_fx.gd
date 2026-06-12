# 法杖特效验收: 法杖弹命中爆同色火花 (枪不爆, 防快枪刷屏) + 施法颜色按弹色走。
extends GutTest

const BulletScene = preload("res://scenes/entities/bullet.tscn")
const PlayerAction = preload("res://scripts/player/player_action.gd")


func test_spell_fx_color_distinct_per_visual() -> void:
	var pa = PlayerAction.new()
	add_child_autofree(pa)
	var lightning: Color = pa._spell_fx_color("lightning")
	var poison: Color = pa._spell_fx_color("poison")
	var fire: Color = pa._spell_fx_color("fire")
	var ice: Color = pa._spell_fx_color("ice")
	var def_c: Color = pa._spell_fx_color("magic")
	# 都不透明 (a>0 才会喷火花)
	for c in [lightning, poison, fire, ice, def_c]:
		assert_gt(c.a, 0.0, "施法色该不透明")
	# 各不相同 (一眼认出是哪把法杖)
	assert_ne(lightning, poison, "闪电色 ≠ 毒色")
	assert_ne(fire, ice, "火色 ≠ 冰色")


func test_staff_bullet_carries_impact_color() -> void:
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(100, 0), 5, null, 200.0, {"impact_color": Color8(255, 235, 90)})
	assert_gt(b._impact_color.a, 0.0, "法杖弹带 impact_color → 命中会爆火花")


func test_gun_bullet_has_no_impact_color() -> void:
	# 枪走 _proj_opts_from_def, 不塞 impact_color → 子弹不爆 (防 SMG/霰弹刷屏)
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(100, 0), 5, null, 200.0, {})
	assert_eq(b._impact_color.a, 0.0, "普通枪弹不带 impact_color")


func test_bullet_impact_spawns_particles_on_destroy() -> void:
	# 给 Effects 一个落点 (current_scene), 数销毁后冒了粒子
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(100, 0), 5, null, 200.0, {"impact_color": Color8(120, 200, 60)})
	var before: int = get_tree().get_node_count()
	b._destroy()
	await wait_frames(1)
	# spawn_explosion 往树里塞 30 颗粒子 → 全树节点数明显变多 (扣掉销毁的子弹自身也还净增很多)
	assert_gt(get_tree().get_node_count(), before + 10, "法杖弹销毁该冒一片火花粒子")


func test_water_staff_carries_splash_opt() -> void:
	# 水之法杖 def 带 gun_splash → _proj_opts_from_def 转成 opts.splash
	var pa = PlayerAction.new()
	add_child_autofree(pa)
	var def: Variant = ItemDB.get_def("water_staff")
	assert_true(bool(def.get("gun_splash", false)), "水之法杖 def 带 gun_splash")
	var opts: Dictionary = pa._proj_opts_from_def(def)
	assert_true(opts.get("splash", false), "_proj_opts_from_def 把 gun_splash 转成 opts.splash")


func test_water_staff_no_cast_flash_others_yes() -> void:
	# 用户: 水之法杖发射时不该闪 (它的特效是落地溅水); 别的法杖发射闪一下 OK
	var pa = PlayerAction.new()
	add_child_autofree(pa)
	assert_false(pa._staff_has_cast_flash(ItemDB.get_def("water_staff")), "水之法杖发射不闪 (特效在落地)")
	assert_true(pa._staff_has_cast_flash(ItemDB.get_def("lightning_staff")), "闪电法杖发射要闪")
	assert_true(pa._staff_has_cast_flash(ItemDB.get_def("poison_staff")), "毒液法杖发射要闪")


func test_water_bullet_splashes_on_explode() -> void:
	# 水弹炸开 (落地/命中) 该溅一片水花 (spawn_splash 8 颗水滴)
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(100, 0), 5, null, 200.0, {"explode_radius": 22.0, "splash": true})
	var before: int = get_tree().get_node_count()
	b._explode(b.global_position)
	await wait_frames(1)
	assert_gt(get_tree().get_node_count(), before + 3, "水弹炸开该溅水花粒子")
