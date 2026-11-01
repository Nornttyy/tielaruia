extends GutTest

const LoadingScreenScene = preload("res://scenes/ui/loading_screen.tscn")

func _make(generating: bool = true) -> CanvasLayer:
	var screen = LoadingScreenScene.instantiate()
	screen.generating = generating
	add_child_autofree(screen)
	return screen

func test_new_world_uses_original_frame_and_landscape():
	var screen = _make()
	assert_true(screen._bar.visible)
	assert_eq(screen._bar.FRAME.get_size(), Vector2(620, 70))
	assert_not_null(screen.get_node("Content/TitleLayer/OriginalLogo").texture)
	assert_eq(screen.get_node("Content/BackgroundLayer/Trees").get_child_count(), 9)
	assert_null(screen.get_node_or_null("PlayerRunner"))
	assert_eq(screen._root.mouse_filter, Control.MOUSE_FILTER_STOP)

func test_existing_world_has_status_without_generation_bar_or_tips():
	var screen = _make(false)
	screen.set_progress(0.37, "正在读取世界数据...")
	assert_eq(screen._stage_label.text, "正在读取世界数据……37%")
	assert_false(screen._bar.visible)
	assert_false(screen._tip.visible)

func test_overall_progress_cannot_regress_but_current_pass_can_restart():
	var screen = _make()
	screen.set_progress(0.6, "正在生成地形", 1.0)
	screen.set_progress(0.4, "正在准备背景", 0.0)
	assert_eq(screen._progress, 0.6)
	assert_eq(screen._bar.current_pass, 0.0)
	assert_string_contains(screen._stage_label.text, "60%")

func test_invalid_progress_cannot_corrupt_display():
	var screen = _make()
	screen.set_progress(-600.0, "准备")
	assert_eq(screen._progress, 0.0)
	screen.set_progress(0.5, "读取")
	screen.set_progress(NAN, "错误")
	screen.set_progress(INF, "错误")
	assert_eq(screen._stage_label.text, "读取……50%")
	screen.set_progress(6.0, "完成", INF)
	assert_eq(screen._progress, 1.0)
	assert_true(is_finite(screen._bar.current_pass))
	assert_string_contains(screen._stage_label.text, "100%")

func test_displayed_bar_does_not_overtake_completed_work():
	var screen = _make()
	screen.set_progress(0.25, "生成")
	screen._process(0.02)
	assert_gt(screen._bar.overall, 0.0)
	assert_lte(screen._bar.overall, 0.25)
	screen._process(10.0)
	assert_eq(screen._bar.overall, 0.25)

func test_finish_waits_for_ready_and_only_emits_once():
	var screen = _make()
	watch_signals(screen)
	screen.finish_and_fade()
	assert_false(screen._finishing)
	screen.set_progress(1.0, "进入世界")
	screen.finish_and_fade()
	screen.finish_and_fade()
	await screen.finished
	await get_tree().process_frame
	assert_signal_emit_count(screen, "finished", 1)
	assert_almost_eq(screen._root.modulate.a, 0.0, 0.001)

func test_background_keeps_menu_phase_without_copying_buttons():
	var menu := CanvasLayer.new()
	add_child_autofree(menu)
	var bg := Control.new()
	bg.name = "BackgroundLayer"
	menu.add_child(bg)
	var trees := Node2D.new()
	trees.name = "Trees"
	bg.add_child(trees)
	var tree := Sprite2D.new()
	tree.position.x = -125.0
	tree.set_meta("speed", 4.0)
	trees.add_child(tree)
	var title := Control.new()
	title.name = "TitleLayer"
	menu.add_child(title)
	var buttons := Control.new()
	buttons.name = "ButtonLayer"
	menu.add_child(buttons)
	menu.hide()
	var screen = LoadingScreenScene.instantiate()
	screen.background_source = menu
	add_child_autofree(screen)
	assert_null(screen.get_node_or_null("Content/ButtonLayer"))
	var copy: Node2D = screen.get_node("Content/BackgroundLayer/Trees").get_child(0)
	assert_eq(copy.position.x, -125.0)
	screen._process(0.5)
	assert_eq(copy.position.x, -127.0)
	assert_eq(tree.position.x, -125.0, "Menu phase is not modified by the loading clone")
