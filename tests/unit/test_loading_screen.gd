extends GutTest

const LoadingScreenScene = preload("res://scenes/ui/loading_screen.tscn")


func _make() -> CanvasLayer:
	var ls: CanvasLayer = LoadingScreenScene.instantiate()
	add_child_autofree(ls)
	return ls


func test_instantiate_does_not_crash():
	var ls = _make()
	await get_tree().process_frame
	assert_not_null(ls)
	assert_true(ls.visible)


func test_layer_is_50():
	var ls = _make()
	await get_tree().process_frame
	assert_eq(ls.layer, 50, "LoadingScreen layer 应为 50 (在 world 与 HUD 之上)")


func test_setup_creates_sky_gradient():
	var ls = _make()
	await get_tree().process_frame
	var sky: ColorRect = ls.get_node_or_null("Sky")
	assert_not_null(sky, "Sky ColorRect 应存在")
	var grad: TextureRect = sky.get_node_or_null("SkyGradient")
	assert_not_null(grad, "SkyGradient TextureRect 应存在")
	assert_not_null(grad.texture, "SkyGradient 应有 GradientTexture2D")


func test_setup_creates_14_stars():
	var ls = _make()
	await get_tree().process_frame
	var stars_root: Control = ls.get_node_or_null("Stars")
	assert_not_null(stars_root, "Stars 容器应存在")
	assert_eq(stars_root.get_child_count(), 14, "应有 14 颗星")


func test_setup_creates_player_runner_playing_walk():
	var ls = _make()
	await get_tree().process_frame
	var runner: AnimatedSprite2D = ls.get_node_or_null("PlayerRunner")
	assert_not_null(runner, "PlayerRunner AnimatedSprite2D 应存在")
	assert_eq(runner.animation, "walk", "应播 walk 动画")
	assert_true(runner.is_playing(), "动画应在播")


func test_progress_nodes_exist():
	var ls = _make()
	await get_tree().process_frame
	assert_not_null(ls.get_node_or_null("ProgressBg"), "ProgressBg 应存在")
	assert_not_null(ls.get_node_or_null("ProgressBg/ProgressFill"), "ProgressFill 应存在")
	assert_not_null(ls.get_node_or_null("StageLabel"), "StageLabel 应存在")
	assert_not_null(ls.get_node_or_null("PercentLabel"), "PercentLabel 应存在")


func test_set_progress_updates_text():
	var ls = _make()
	await get_tree().process_frame
	ls.set_progress(0.37, "正在生成地形...")
	await get_tree().create_timer(0.3).timeout
	var stage_label: Label = ls.get_node("StageLabel")
	var percent_label: Label = ls.get_node("PercentLabel")
	assert_eq(stage_label.text, "正在生成地形...")
	assert_eq(percent_label.text, "37%")


func test_set_progress_fill_width_proportional():
	var ls = _make()
	await get_tree().process_frame
	ls.set_progress(0.5, "x")
	await get_tree().create_timer(0.3).timeout
	var bg: Panel = ls.get_node("ProgressBg")
	var fill: ColorRect = ls.get_node("ProgressBg/ProgressFill")
	# fill.size.x ≈ (bg.size.x - 4) * 0.5 (留 2px 内边距, 允许 1px 误差)
	assert_almost_eq(fill.size.x, (bg.size.x - 4.0) * 0.5, 1.0)


func test_tip_button_exists_with_label():
	var ls = _make()
	await get_tree().process_frame
	var btn: Button = ls.get_node_or_null("TipButton")
	assert_not_null(btn, "TipButton 应存在")
	var tip_label: Label = btn.get_node_or_null("TipLabel")
	assert_not_null(tip_label, "TipLabel 应存在")
	assert_true(tip_label.text.length() > 0, "初始就应有一条贴士")


func test_clicking_tip_button_advances_to_next_tip():
	var ls = _make()
	await get_tree().process_frame
	var tip_label: Label = ls.get_node("TipButton/TipLabel")
	var first: String = tip_label.text
	ls._on_tip_pressed()
	await get_tree().process_frame
	var second: String = tip_label.text
	assert_ne(first, second, "点击后应换贴士")


func test_tips_pool_has_20_entries():
	var ls = _make()
	await get_tree().process_frame
	assert_eq(ls.TIPS.size(), 20, "贴士池应 20 条")
