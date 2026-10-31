# 1.4.4.9 经典界面原图与共同排版参数。来源和哈希见 ui/source-manifest.json。
extends RefCounted
const BASE := "res://assets/terraria_1449/ui/"
const SLOT := 44
const STEP := 48
static var _textures: Dictionary = {}

static func texture(name: String) -> Texture2D:
	if not _textures.has(name): _textures[name] = load(BASE + name + ".png")
	return _textures[name]

static func slot(kind: String = "inventory") -> StyleBoxTexture:
	var names := {"inventory": "Inventory_Back", "hotbar": "Inventory_Back",
		"selected": "Inventory_Back14", "armor": "Inventory_Back8",
		"chest": "Inventory_Back5", "trash": "Inventory_Back7"}
	var style := StyleBoxTexture.new()
	style.texture = texture(names.get(kind, "Inventory_Back"))
	# 整张 52px 贴图等比缩放，保留像素边缘；不拉伸九宫格的圆角。
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 0.0)
	return style

static func label(node: Label, font_size: int = 16) -> void:
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color.WHITE)
	node.add_theme_color_override("font_outline_color", Color.BLACK)
	node.add_theme_constant_override("outline_size", 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
