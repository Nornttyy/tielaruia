extends GutTest

func test_artcache_player_frames_for_returns_frames():
	var ap = {
		"gender": 0, "hair_style": 0, "shirt_style": 0, "pants_style": 0,
		"cape_style": 0, "chest_size": 1,
		"skin_color": Color8(255, 218, 185), "hair_color": Color8(121, 85, 72),
		"shirt_color": Color8(10, 200, 30), "pants_color": Color8(38, 70, 130),
		"cape_color": Color8(150, 40, 50), "eye_color": Color8(60, 110, 70),
	}
	var sf = ArtCache.player_frames_for(ap)
	assert_true(sf is SpriteFrames, "返回 SpriteFrames")
	assert_eq(sf.get_frame_texture("idle", 0).get_width(), 32, "原片固定裁框 32 宽")

func test_player_scene_sprite_scaled():
	var p = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(p)
	var spr: AnimatedSprite2D = p.get_node("AnimatedSprite2D")
	assert_almost_eq(spr.scale.x, 0.75, 0.01, "16 像素素材对应现有 12 像素世界")
	assert_almost_eq(spr.scale.y, 0.75, 0.01, "横纵比例保持一致")
	assert_eq(spr.offset, Vector2(-16, 0), "固定裁框水平居中")
