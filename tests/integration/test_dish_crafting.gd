extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const BuffHudClass = preload("res://scripts/ui/buff_hud.gd")
const HealthClass = preload("res://scripts/player/player_health.gd")
const BuffsClass = preload("res://scripts/player/player_buffs.gd")

# 在玩家旁边摆口锅 (料理配方现在要 requires "pot" 工作站才匹配)
func _place_pot_near_player(main) -> void:
	var world = main.get_node("World")
	var pa: Node = world.get_player().get_node("PlayerAction")
	var terrain: TileMapLayer = get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer
	var pt: Vector2i = pa.player_tile()
	var pot: Vector2i = pt + Vector2i(1, 0)
	world._set_tile(pot.x, pot.y, Tiles.COOKING_POT)
	terrain.set_cell(pot, Tiles.COOKING_POT, Vector2i.ZERO)

# 在合成面板里真摆材料 → 能合出料理 (验证配方图案/旋转匹配真能用)
func test_craft_bread_from_wheat():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	_place_pot_near_player(main)
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	cp.open(3)
	# 面包 = 一排 3 小麦
	cp.place_in_cell(0, 0, "wheat", 1)
	cp.place_in_cell(0, 1, "wheat", 1)
	cp.place_in_cell(0, 2, "wheat", 1)
	var preview = cp.get_output_preview()
	assert_not_null(preview, "3 小麦应合出面包")
	assert_eq(preview.output_id, "bread")
	cp.close()

func test_craft_apple_pie():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	_place_pot_near_player(main)
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	cp.open(3)
	# 苹果派 = 苹果 苹果 小麦
	cp.place_in_cell(0, 0, "apple", 1)
	cp.place_in_cell(0, 1, "apple", 1)
	cp.place_in_cell(0, 2, "wheat", 1)
	var preview = cp.get_output_preview()
	assert_not_null(preview, "苹果+苹果+小麦应合出苹果派")
	assert_eq(preview.output_id, "apple_pie")
	cp.close()

func test_craft_mushroom_soup():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	_place_pot_near_player(main)
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	cp.open(2)
	# 蘑菇汤 = 2 蘑菇 (2x1)
	cp.place_in_cell(0, 0, "mushroom", 1)
	cp.place_in_cell(0, 1, "mushroom", 1)
	var preview = cp.get_output_preview()
	assert_not_null(preview, "2 蘑菇应合出蘑菇汤")
	assert_eq(preview.output_id, "mushroom_soup")
	cp.close()

# regen buff (蘑菇汤/苹果酱) 真的每秒帮玩家回血
func test_regen_buff_heals_player():
	var parent := Node.new()
	add_child_autofree(parent)
	var hp = HealthClass.new()
	hp.name = "PlayerHealth"
	parent.add_child(hp)
	var buffs = BuffsClass.new()
	buffs.name = "PlayerBuffs"
	parent.add_child(buffs)
	hp.current_health = 50
	buffs.apply("regen", 10.0)
	buffs._process(1.1)   # > BUFF_REGEN_INTERVAL(1.0) → 回 BUFF_REGEN_AMOUNT(2)
	assert_eq(hp.current_health, 52, "regen buff 应回 2 血")

# buff HUD 像素字形完整性 (防 _draw 里 s[c] 越界崩)
func test_buff_glyphs_well_formed():
	for kind in ["speed", "jump", "mining", "regen"]:
		assert_true(BuffHudClass.KIND_COLOR.has(kind), "%s 应有颜色" % kind)
		var glyph = BuffHudClass.KIND_GLYPH.get(kind, [])
		assert_eq(glyph.size(), 8, "%s 字形应 8 行" % kind)
		for row in glyph:
			assert_eq((row as String).length(), 8, "%s 每行应 8 列" % kind)
