extends GutTest

const CharacterData = preload("res://scripts/save/character_data.gd")
const CharacterManager = preload("res://scripts/save/character_manager.gd")
const SaveData = preload("res://scripts/save/save_data.gd")

var cm

func before_each():
	cm = CharacterManager.new()
	cm.CHARS_DIR_OVERRIDE = "user://test_chars_mig/"
	_clear_dir(cm.chars_dir())
	if not DirAccess.dir_exists_absolute(cm.chars_dir()):
		DirAccess.make_dir_absolute(cm.chars_dir())

func after_each():
	_clear_dir(cm.chars_dir())
	cm.free()

func _clear_dir(path: String):
	if not DirAccess.dir_exists_absolute(path):
		return
	var d = DirAccess.open(path)
	d.list_dir_begin()
	var f = d.get_next()
	while f != "":
		if not d.current_is_dir():
			DirAccess.remove_absolute(path + f)
		f = d.get_next()
	d.list_dir_end()

func _fake_save(inv: Array, hp: int, max_hp: int) -> SaveData:
	var s = SaveData.new()
	s.world_name = "老世界"
	s.inventory_slots = inv
	s.player_hp = float(hp)
	s.player_max_hp = max_hp
	s.hotbar_selection = 4
	s.armor_chest_id = "gold_chestplate"
	return s

func test_migration_creates_default_character_from_newest_save():
	var save = _fake_save([{"item_id": "emerald", "count": 12}], 73, 240)
	# 注入假存档来源 (最新在前)
	cm.migrate_with_saves([{"name": "老世界", "data": save}], "勇者")
	var chars = cm.list_characters()
	assert_eq(chars.size(), 1, "迁移出 1 个角色")
	var c = chars[0]["data"]
	assert_eq(c.inventory_slots[0]["item_id"], "emerald", "背包搬过来")
	assert_eq(c.player_hp, 73.0, "血量搬过来")
	assert_eq(c.player_max_hp, 240, "上限搬过来")
	assert_eq(c.hotbar_selection, 4)
	assert_eq(c.armor_chest_id, "gold_chestplate")
	assert_eq(c.gender, 0, "外观=默认 (男)")

func test_migration_skips_when_characters_exist():
	var pre = CharacterData.new()
	pre.character_name = "已有"
	cm.save_character(pre)
	cm.migrate_with_saves([{"name": "老世界", "data": _fake_save([], 100, 100)}], "勇者")
	assert_eq(cm.list_characters().size(), 1, "已有角色则不迁移")

func test_migration_noop_when_no_saves():
	cm.migrate_with_saves([], "勇者")
	assert_false(cm.has_any(), "没世界存档 → 不造角色")

func test_ensure_current_picks_existing():
	var c = CharacterData.new()
	c.character_name = "现成"
	cm.save_character(c)
	cm.current = null
	cm.ensure_current()
	assert_not_null(cm.current, "ensure_current 选了一个")
	assert_eq(cm.current.character_name, "现成")

func test_ensure_current_creates_default_when_none():
	cm.current = null
	cm.ensure_current()
	assert_not_null(cm.current, "没角色则造默认")
	assert_true(cm.has_any(), "默认角色写盘了")
