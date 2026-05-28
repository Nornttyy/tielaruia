extends GutTest

# Locale autoload 测试. 直接用 /root/Locale (项目里已注册 autoload).


func _reset_to_zh() -> void:
	# 每个测试开始前回到中文 (避免上一个 test 留状态)
	Locale.set_language("zh")


func test_default_language_is_zh():
	_reset_to_zh()
	assert_eq(Locale.current_language(), "zh", "默认语言应是中文")


func test_t_returns_zh_string_by_default():
	_reset_to_zh()
	assert_eq(Locale.t("menu_new_game"), "开始游戏", "中文 menu_new_game = 开始游戏")


func test_set_language_changes_lookup():
	_reset_to_zh()
	Locale.set_language("en")
	assert_eq(Locale.t("menu_new_game"), "New Game", "英文 menu_new_game = New Game")
	Locale.set_language("ja")
	assert_eq(Locale.t("menu_new_game"), "ゲーム開始", "日文 menu_new_game = ゲーム開始")
	Locale.set_language("ko")
	assert_eq(Locale.t("menu_new_game"), "게임 시작", "韩文 menu_new_game = 게임 시작")


func test_set_language_emits_signal():
	_reset_to_zh()
	watch_signals(Locale)
	Locale.set_language("en")
	assert_signal_emitted_with_parameters(Locale, "language_changed", ["en"],
		"切语言应发 language_changed(\"en\") 信号")


func test_set_language_noop_when_same():
	_reset_to_zh()
	watch_signals(Locale)
	Locale.set_language("zh")
	assert_signal_emit_count(Locale, "language_changed", 0,
		"切到当前语言不应发信号")


func test_set_language_rejects_unsupported():
	_reset_to_zh()
	Locale.set_language("fr")  # 不支持
	assert_eq(Locale.current_language(), "zh", "不支持的语言应被忽略")


func test_t_returns_key_when_missing_everywhere():
	_reset_to_zh()
	assert_eq(Locale.t("__nonexistent_key_xyz"), "__nonexistent_key_xyz",
		"所有语言都没的 key 应返回 key 本身 (定位漏翻)")


func test_t_uses_default_when_provided_and_missing():
	_reset_to_zh()
	assert_eq(Locale.t("__missing_key", "兜底"), "兜底",
		"key 缺失但调用方给了 default 应用 default")


func test_persisted_language_loads_from_game_settings():
	# GameSettings.current_language 改了, Locale 这个 session 不会自动跟 (只在 _ready 读一次).
	# 这个测试验证 GameSettings.current_language 至少能存 + 读.
	_reset_to_zh()
	GameSettings.current_language = "ja"
	assert_eq(GameSettings.current_language, "ja", "GameSettings 应能存 ja")
	GameSettings.current_language = "zh"
	_reset_to_zh()


func test_language_display_name():
	# 每个语言的 lang_name 显示原文 (用于下拉里看)
	assert_eq(Locale.language_display_name("zh"), "中文")
	assert_eq(Locale.language_display_name("en"), "English")
	assert_eq(Locale.language_display_name("ja"), "日本語")
	assert_eq(Locale.language_display_name("ko"), "한국어")


func test_all_languages_have_same_keys():
	# 防漏翻: 中文有的 key, 其他 3 个语言都得有
	var zh_keys: Array = Locale._tables["zh"].keys()
	for lang in ["en", "ja", "ko"]:
		var missing: Array = []
		for k in zh_keys:
			if not Locale._tables[lang].has(k):
				missing.append(k)
		assert_eq(missing.size(), 0,
			"%s 缺以下 key: %s" % [lang, str(missing)])
