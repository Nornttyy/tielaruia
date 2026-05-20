extends GutTest

const LogoArt = preload("res://scripts/art/logo_art.gd")


func test_text_is_teilaruia():
	assert_eq(LogoArt.TEXT, "teilaruia")


func test_font_size_is_reasonable():
	assert_gt(LogoArt.FONT_SIZE, 32)
	assert_lt(LogoArt.FONT_SIZE, 128)


func test_style_main_label_sets_text_and_size():
	var label = Label.new()
	add_child_autofree(label)
	LogoArt.style_main_label(label)
	assert_eq(label.text, "teilaruia")
	assert_eq(label.get_theme_font_size("font_size"), LogoArt.FONT_SIZE)
	assert_eq(label.get_theme_color("font_color"), LogoArt.COLOR_MAIN)


func test_style_shadow_label_uses_shadow_color():
	var label = Label.new()
	add_child_autofree(label)
	LogoArt.style_shadow_label(label)
	assert_eq(label.text, "teilaruia")
	assert_eq(label.get_theme_color("font_color"), LogoArt.COLOR_SHADOW)
