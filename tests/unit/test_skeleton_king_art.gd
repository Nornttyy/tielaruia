# 骷髅王动画帧: walk/attack 必须各有 2 帧才会动 (之前都只 1 帧 → 不动)。
extends GutTest

const SkeletonKingArt = preload("res://scripts/art/skeleton_king_art.gd")


func test_build_frames_has_animated_walk_and_attack() -> void:
	var sf: SpriteFrames = SkeletonKingArt.build_frames()
	assert_true(sf.has_animation("idle"), "有 idle 动画")
	assert_true(sf.has_animation("walk"), "有 walk 动画")
	assert_true(sf.has_animation("attack"), "有 attack 动画")
	# 走/打要 2 帧才会动 (轮播)
	assert_eq(sf.get_frame_count("walk"), 2, "walk 要 2 帧才迈步")
	assert_eq(sf.get_frame_count("attack"), 2, "attack 要 2 帧才挥刀")
	# 三个动画都循环
	assert_true(sf.get_animation_loop("walk"), "walk 循环")
	assert_true(sf.get_animation_loop("attack"), "attack 循环")
