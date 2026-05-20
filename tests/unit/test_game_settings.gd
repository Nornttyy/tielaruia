extends GutTest

# GameSettings 是 autoload，直接用名字访问
func test_default_master_volume_is_one():
	assert_eq(GameSettings.master_volume, 1.0, "默认满音量")


func test_set_master_volume_applies_to_audio_server():
	GameSettings.master_volume = 0.5
	var db = AudioServer.get_bus_volume_db(0)
	# linear_to_db(0.5) ≈ -6.02
	assert_almost_eq(db, linear_to_db(0.5), 0.1, "0.5 线性 → -6 dB")
	# 还原避免污染其他测试
	GameSettings.master_volume = 1.0


func test_set_master_volume_zero_mutes():
	GameSettings.master_volume = 0.0
	var db = AudioServer.get_bus_volume_db(0)
	assert_eq(db, -80.0, "0 线性 → -80 dB (静音)")
	GameSettings.master_volume = 1.0


func test_set_master_volume_clamps():
	GameSettings.master_volume = 1.5
	assert_eq(GameSettings.master_volume, 1.0, "上限 1.0")
	GameSettings.master_volume = -0.3
	assert_eq(GameSettings.master_volume, 0.0, "下限 0.0")
	GameSettings.master_volume = 1.0
