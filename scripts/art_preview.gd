# 美术预览场景的脚本。
# 把所有方块/物品/实体动画排在屏幕上，方便目视检查像素画质量。
# 由 scenes/art_preview.tscn 加载。运行方式：godot --path /workspace/teilaruia
extends Node2D

const BlocksArt = preload("res://scripts/art/blocks_art.gd")

const SCALE := 4              # 放大显示 (16px → 64px)
const LABEL_FONT_SIZE := 14
const MARGIN := 16
const TILE_BOX := 16 * SCALE  # 单格显示宽


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color8(40, 44, 52))
	_draw_section_title("方块 (10)", Vector2(MARGIN, MARGIN))
	_draw_blocks(Vector2(MARGIN, MARGIN + 32))

	var items_y := MARGIN + 32 + TILE_BOX + 48
	_draw_section_title("物品 (8)", Vector2(MARGIN, items_y))
	_draw_items(Vector2(MARGIN, items_y + 32))

	var entities_y := items_y + 32 + TILE_BOX + 48
	_draw_section_title("实体 (3 — 帧动画)", Vector2(MARGIN, entities_y))
	_draw_entities(Vector2(MARGIN, entities_y + 32))

	var doors_y := entities_y + 32 + 24 * SCALE + 48
	_draw_section_title("门 (16×32, 关 / 开)", Vector2(MARGIN, doors_y))
	_draw_doors(Vector2(MARGIN, doors_y + 32))


func _draw_section_title(text: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", LABEL_FONT_SIZE + 4)
	lbl.add_theme_color_override("font_color", Color8(220, 220, 220))
	add_child(lbl)


func _draw_blocks(origin: Vector2) -> void:
	var names := {
		BlocksArt.GRASS: "草",
		BlocksArt.DIRT: "泥土",
		BlocksArt.STONE: "石头",
		BlocksArt.SAND: "沙子",
		BlocksArt.LOG: "原木",
		BlocksArt.LEAVES: "树叶",
		BlocksArt.PLANKS: "木板",
		BlocksArt.WORKBENCH: "工作台",
		BlocksArt.DOOR: "门(图标)",
		BlocksArt.BEDROCK: "基岩",
	}
	var i := 0
	for tile_id in names.keys():
		var spr := Sprite2D.new()
		spr.texture = ArtCache.block_textures[tile_id]
		spr.scale = Vector2(SCALE, SCALE)
		spr.centered = false
		spr.position = origin + Vector2(i * (TILE_BOX + 16), 0)
		add_child(spr)
		_add_caption(names[tile_id], spr.position + Vector2(0, TILE_BOX + 4))
		i += 1


func _draw_items(origin: Vector2) -> void:
	var item_ids := ["wood_sword", "wood_pickaxe", "wood_axe", "slime_ball", "stone_sword", "stone_pickaxe", "stone_axe", "slime_torch"]
	var names := {
		"wood_sword": "木剑",
		"wood_pickaxe": "木镐",
		"wood_axe": "木斧",
		"slime_ball": "史莱姆球",
		"stone_sword": "石剑",
		"stone_pickaxe": "石镐",
		"stone_axe": "石斧",
		"slime_torch": "史莱姆火把",
	}
	for i in item_ids.size():
		var spr := Sprite2D.new()
		spr.texture = ArtCache.item_icons[item_ids[i]]
		spr.scale = Vector2(SCALE, SCALE)
		spr.centered = false
		spr.position = origin + Vector2(i * (TILE_BOX + 16), 0)
		add_child(spr)
		_add_caption(names[item_ids[i]], spr.position + Vector2(0, TILE_BOX + 4))


func _draw_entities(origin: Vector2) -> void:
	# 玩家：4 种动画并排
	var player_anims := ["idle", "walk", "jump", "fall"]
	for i in player_anims.size():
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = ArtCache.player_frames
		anim.animation = player_anims[i]
		anim.scale = Vector2(SCALE, SCALE)
		anim.centered = false
		anim.position = origin + Vector2(i * (12 * SCALE + 24), 0)
		anim.play(player_anims[i])
		add_child(anim)
		_add_caption("玩家 " + player_anims[i], anim.position + Vector2(0, 24 * SCALE + 4))

	# 史莱姆：2 种动画
	var slime_x := origin.x + 4 * (12 * SCALE + 24) + 32
	var slime_anims := ["idle", "hop"]
	for i in slime_anims.size():
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = ArtCache.slime_frames
		anim.animation = slime_anims[i]
		anim.scale = Vector2(SCALE, SCALE)
		anim.centered = false
		anim.position = Vector2(slime_x + i * (16 * SCALE + 24), origin.y + 12 * SCALE)
		anim.play(slime_anims[i])
		add_child(anim)
		_add_caption("史莱姆 " + slime_anims[i], anim.position + Vector2(0, 12 * SCALE + 4))

	# 村民
	var villager_x := slime_x + 2 * (16 * SCALE + 24) + 32
	var v := AnimatedSprite2D.new()
	v.sprite_frames = ArtCache.villager_frames
	v.animation = "idle"
	v.scale = Vector2(SCALE, SCALE)
	v.centered = false
	v.position = Vector2(villager_x, origin.y)
	v.play("idle")
	add_child(v)
	_add_caption("村民 idle", v.position + Vector2(0, 24 * SCALE + 4))


func _draw_doors(origin: Vector2) -> void:
	var closed := Sprite2D.new()
	closed.texture = ArtCache.door_closed_texture
	closed.scale = Vector2(SCALE, SCALE)
	closed.centered = false
	closed.position = origin
	add_child(closed)
	_add_caption("门 (关)", closed.position + Vector2(0, 32 * SCALE + 4))

	var open := Sprite2D.new()
	open.texture = ArtCache.door_open_texture
	open.scale = Vector2(SCALE, SCALE)
	open.centered = false
	open.position = origin + Vector2(16 * SCALE + 32, 0)
	add_child(open)
	_add_caption("门 (开)", open.position + Vector2(0, 32 * SCALE + 4))


func _add_caption(text: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color8(180, 180, 180))
	add_child(lbl)
