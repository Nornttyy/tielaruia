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
	assert_eq(sf.get_frame_texture("idle", 0).get_width(), 16, "16 宽 (侧面版)")

func test_player_scene_sprite_scaled():
	var p = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(p)
	var spr: AnimatedSprite2D = p.get_node("AnimatedSprite2D")
	assert_almost_eq(spr.scale.x, 1.0, 0.01, "scale.x 1:1 不缩糊")
	assert_almost_eq(spr.scale.y, 1.0, 0.01, "scale.y 1:1 不缩糊")
	assert_eq(spr.offset, Vector2(-8, 0), "offset = -W/2 水平居中 (16 宽)")
