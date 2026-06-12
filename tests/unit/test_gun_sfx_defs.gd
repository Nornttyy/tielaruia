# T2 验收: 新音效已注册; 每把枪 def 里的 gun_sfx 都是真实存在的音效名 (防手滑写错).
extends GutTest


func test_new_sounds_registered() -> void:
	for name in ["gunshot_heavy", "gunshot_laser", "gunshot_ice", "gunshot_magic", "gunshot_rapid", "gunshot_flame", "cast"]:
		assert_true(SfxBank.has_sound(name), name + " 该已注册")


func test_all_gun_sfx_values_exist() -> void:
	var checked := 0
	for id in ItemDB._DEFS:
		var def: Dictionary = ItemDB._DEFS[id]
		if String(def.get("tool_kind", "")) != "gun":
			continue
		if def.has("gun_sfx"):
			assert_true(SfxBank.has_sound(String(def["gun_sfx"])), id + " 的 gun_sfx 没注册: " + String(def["gun_sfx"]))
			checked += 1
	assert_gt(checked, 5, "至少该有 6 把枪配了专属音效")
