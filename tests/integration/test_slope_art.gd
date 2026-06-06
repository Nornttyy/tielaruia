# 斜砖贴图形状: ◢ 左上角透明(被削掉) + 右下角实心; ◣ 镜像.
extends GutTest
const BlocksArt = preload("res://scripts/art/blocks_art.gd")

func test_slope_r_shape() -> void:
	var img: Image = BlocksArt.get_texture(BlocksArt.GRASS_SLOPE_R).get_image()
	var w := img.get_width()
	# 左上角 (被削掉的三角) 透明; 右下角 实心
	assert_lt(img.get_pixel(1, 1).a, 0.5, "◢ 左上角该透明")
	assert_gt(img.get_pixel(w - 2, w - 2).a, 0.5, "◢ 右下角该实心")

func test_slope_l_shape() -> void:
	var img: Image = BlocksArt.get_texture(BlocksArt.GRASS_SLOPE_L).get_image()
	var w := img.get_width()
	assert_lt(img.get_pixel(w - 2, 1).a, 0.5, "◣ 右上角该透明")
	assert_gt(img.get_pixel(1, w - 2).a, 0.5, "◣ 左下角该实心")
