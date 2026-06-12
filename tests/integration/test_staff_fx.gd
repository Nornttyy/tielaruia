# 法杖特效验收: 每把法杖一种"形状"的命中特效 (不再全是同一种爆炸只换色) +
# 发射时不闪 (只飞行弹+命中放特效) + 枪不放特效 (防快枪刷屏)。
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
	for c in [lightning, poison, fire, ice]:
		assert_gt(c.a, 0.0, "施法色该不透明")
	assert_ne(lightning, poison, "闪电色 ≠ 毒色")
	assert_ne(fire, ice, "火色 ≠ 冰色")


func test_spell_impact_fx_distinct_per_visual() -> void:
	# 每把法杖命中特效"形状"不同 (用户: 特效太单一)
	var pa = PlayerAction.new()
	add_child_autofree(pa)
	var kinds := {}
	for vis in ["lightning", "poison", "magic", "fire", "ice", "wind"]:
		kinds[pa._spell_impact_fx(vis)] = true
	# 6 把法杖 → 6 种不同形状
	assert_eq(kinds.size(), 6, "6 把法杖该有 6 种不同特效形状")
	assert_eq(pa._spell_impact_fx("lightning"), "spark", "闪电=星形火花")
	assert_eq(pa._spell_impact_fx("ice"), "splash", "水之=溅水花")
	assert_eq(pa._spell_impact_fx("wind"), "gust", "狂风=横向风条")


func test_staff_bullet_carries_impact_fx() -> void:
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(100, 0), 5, null, 200.0, {"impact_fx": "spark", "impact_color": Color8(255, 235, 90)})
	assert_eq(b._impact_fx, "spark", "法杖弹带 impact_fx → 命中放对应特效")


func test_gun_bullet_has_no_impact_fx() -> void:
	# 枪走 _proj_opts_from_def, 不塞 impact_fx → 子弹命中不放特效 (防 SMG/霰弹刷屏)
	var pa = PlayerAction.new()
	add_child_autofree(pa)
	var opts: Dictionary = pa._proj_opts_from_def(ItemDB.get_def("smg"))
	assert_false(opts.has("impact_fx"), "枪弹 opts 不带 impact_fx")
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(100, 0), 5, null, 200.0, opts)
	assert_eq(b._impact_fx, "", "枪弹不放命中特效")


func test_staff_bullet_has_trail_and_glow() -> void:
	# 法杖弹 (带 impact_fx) → 弹体放大 + 发光光晕 + 拖尾; 普通枪弹没有
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(100, 0), 5, null, 200.0, {"impact_fx": "spark", "impact_color": Color8(255, 235, 90)})
	await wait_frames(2)
	assert_true(b._trail != null, "法杖弹该有拖尾")
	assert_true(b._glow != null, "法杖弹该有发光光晕")
	assert_gt(b._trail.get_point_count(), 0, "拖尾飞几帧后该记下点")

	var g = BulletScene.instantiate()
	add_child_autofree(g)
	g.setup(Vector2(0, 0), Vector2(100, 0), 5, null, 200.0, {})
	await wait_frames(2)
	assert_true(g._trail == null and g._glow == null, "普通枪弹不加拖尾/光晕")


func test_bullet_impact_spawns_particles_on_destroy() -> void:
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(100, 0), 5, null, 200.0, {"impact_fx": "spark", "impact_color": Color8(255, 235, 90)})
	var before: int = get_tree().get_node_count()
	b._destroy()
	await wait_frames(1)
	assert_gt(get_tree().get_node_count(), before + 3, "法杖弹销毁该冒一片火花粒子")


func test_every_impact_kind_spawns_particles() -> void:
	# 6 种特效形状都真能冒粒子 (不崩 + 树节点变多)
	for kind in ["spark", "gas", "sparkle", "gust", "explosion", "splash"]:
		var before: int = get_tree().get_node_count()
		Effects.spawn_spell_impact(kind, Vector2(0, 0), Color8(120, 200, 60))
		await wait_frames(1)
		assert_gt(get_tree().get_node_count(), before + 3, "%s 特效该冒粒子" % kind)


func test_signature_shape_node_draws_each_kind() -> void:
	# 招牌形状节点 (电弧/环/云) 每种都能 _ready + _process + _draw 跑过不崩
	var scene = load("res://scenes/fx/spell_impact_fx.tscn")
	for kind in ["spark", "gas", "sparkle", "gust", "explosion", "splash"]:
		var fx = scene.instantiate()
		add_child_autofree(fx)
		fx.setup(kind, Color8(255, 235, 90))
		await wait_frames(2)
		assert_true(is_instance_valid(fx), "%s 招牌形状节点正常 (画图没崩)" % kind)
