extends GutTest

const CharacterData = preload("res://scripts/save/character_data.gd")
const TMP_PATH := "user://test_char_data.tres"

func after_each():
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)

func test_defaults():
	var c = CharacterData.new()
	assert_eq(c.version, CharacterData.CURRENT_VERSION, "version 默认 = CURRENT_VERSION")
	assert_eq(c.gender, 0, "默认男")
	assert_eq(c.chest_size, 1, "胸围默认 1")
	assert_eq(c.player_max_hp, 100, "默认上限 100")
	assert_eq(c.inventory_slots.size(), 0, "默认空背包数组")

func test_appearance_dict_has_all_keys():
	var c = CharacterData.new()
	var d = c.appearance_dict()
	for k in ["gender", "hair_style", "shirt_style", "pants_style", "cape_style",
			"chest_size", "skin_color", "hair_color", "shirt_color", "pants_color",
			"cape_color", "eye_color"]:
		assert_true(d.has(k), "appearance_dict 含 key %s" % k)

func test_save_load_round_trip():
	var c = CharacterData.new()
	c.character_name = "小明"
	c.gender = 1
	c.hair_style = 2
	c.shirt_style = 9
	c.pants_style = 10
	c.cape_style = 3
	c.chest_size = 4
	c.hair_color = Color8(10, 20, 30)
	c.eye_color = Color8(40, 50, 60)
	c.player_hp = 77.0
	c.player_max_hp = 220
	c.player_mana = 50
	c.player_max_mana = 180
	c.armor_chest_id = "iron_chestplate"
	c.hotbar_selection = 5
	c.inventory_slots = [{"item_id": "wood", "count": 99}, null, {"item_id": "stone", "count": 3}]
	assert_eq(ResourceSaver.save(c, TMP_PATH), OK, "写盘成功")
	var loaded = ResourceLoader.load(TMP_PATH)
	assert_true(loaded is CharacterData, "读回是 CharacterData")
	assert_eq(loaded.character_name, "小明")
	assert_eq(loaded.gender, 1)
	assert_eq(loaded.hair_style, 2)
	assert_eq(loaded.shirt_style, 9)
	assert_eq(loaded.pants_style, 10)
	assert_eq(loaded.cape_style, 3)
	assert_eq(loaded.chest_size, 4)
	# 颜色经 .tres 文本序列化有极小浮点误差, 用近似比较 (不能 assert_eq 精确相等)
	assert_true(loaded.hair_color.is_equal_approx(Color8(10, 20, 30)), "头发色往返近似相等")
	assert_true(loaded.eye_color.is_equal_approx(Color8(40, 50, 60)), "眼珠色往返近似相等")
	assert_eq(loaded.player_hp, 77.0)
	assert_eq(loaded.player_max_hp, 220)
	assert_eq(loaded.player_mana, 50)
	assert_eq(loaded.player_max_mana, 180)
	assert_eq(loaded.armor_chest_id, "iron_chestplate")
	assert_eq(loaded.hotbar_selection, 5)
	assert_eq(loaded.inventory_slots.size(), 3)
	assert_eq(loaded.inventory_slots[0]["item_id"], "wood")
	assert_eq(loaded.inventory_slots[1], null)
