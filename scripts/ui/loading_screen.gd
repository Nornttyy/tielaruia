# World entry retains the menu landscape. Generation has the original ornate
# two-pass bar; loading a save has only the centered status and percentage.
extends CanvasLayer

signal finished

const Sprites = preload("res://scripts/art/terraria_sprite_pack.gd")
const WorldgenProgress = preload("res://scripts/ui/worldgen_progress.gd")
const BASE_SIZE := Vector2(1280, 720)
const FADE_DURATION := 0.16
const TIPS := ["火把可以照亮地下。", "更好的镐可以挖掘更坚硬的矿石。", "木材可以制作工作台。"]

var generating: bool = true
var background_source: Node
var _root: Control
var _background: Control
var _title: Control
var _bar: Control
var _stage_label: Label
var _tip: Label
var _progress: float = 0.0
var _shown_progress: float = 0.0
var _stage: String = "正在准备世界"
var _finishing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Content"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_setup_landscape()
	_bar = WorldgenProgress.new()
	_bar.name = "GenerationProgress"
	_bar.visible = generating
	_root.add_child(_bar)
	_stage_label = _label("StageLabel", 24)
	_tip = _label("TipLabel", 20)
	_tip.text = TIPS[randi() % TIPS.size()]
	_tip.visible = generating
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_status()

func _label(node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color8(15, 23, 31))
	label.add_theme_constant_override("outline_size", 4)
	_root.add_child(label)
	return label

func _setup_landscape() -> void:
	# Duplicate only the scenery, never menu buttons, dialogs or the black fade.
	if is_instance_valid(background_source):
		var source_bg := background_source.get_node_or_null("BackgroundLayer")
		var source_title := background_source.get_node_or_null("TitleLayer")
		if source_bg != null and source_title != null:
			_background = source_bg.duplicate(0)
			_title = source_title.duplicate(0)
			_root.add_child(_background)
			_root.add_child(_title)
			return
	# Also usable in a standalone scene (tests and previews).
	_background = Control.new()
	_background.name = "BackgroundLayer"
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_background)
	var sky := ColorRect.new()
	sky.color = Color8(120, 183, 233)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.add_child(sky)
	var trees := Node2D.new()
	trees.name = "Trees"
	_background.add_child(trees)
	for i in 3:
		for copy in 3:
			var sprite := Sprite2D.new()
			sprite.texture = Sprites.texture("Background_%d.png" % [7, 8, 11][i])
			sprite.centered = false
			sprite.position = Vector2(copy * 1024, [255, 345, 440][i])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.set_meta("speed", [4.0, 9.0, 16.0][i])
			trees.add_child(sprite)
	_title = Control.new()
	_title.name = "TitleLayer"
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_title)
	var logo := TextureRect.new()
	logo.name = "OriginalLogo"
	logo.texture = Sprites.texture("Logo.png")
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title.add_child(logo)

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var cover: float = maxf(view.x / BASE_SIZE.x, view.y / BASE_SIZE.y)
	for root_name in ["Trees", "TreesFront"]:
		var trees := _background.get_node_or_null(root_name) as Node2D
		if trees != null:
			trees.scale = Vector2.ONE * cover
			trees.position = (view - BASE_SIZE * cover) * 0.5
	var ui_scale: float = minf(1.0, minf(view.x / 680.0, view.y / 540.0))
	var logo := _title.get_node_or_null("OriginalLogo") as TextureRect
	if logo != null:
		logo.set_anchors_preset(Control.PRESET_TOP_LEFT)
		logo.size = Vector2(486, 142) * ui_scale
		logo.position = Vector2((view.x - logo.size.x) * 0.5, 70.0 * ui_scale)
	_bar.scale = Vector2.ONE * (0.75 * ui_scale)
	_bar.position = Vector2((view.x - WorldgenProgress.FRAME_SIZE.x * _bar.scale.x) * 0.5, view.y * 0.43)
	_stage_label.position = Vector2(16, view.y * (0.35 if generating else 0.47))
	_stage_label.size = Vector2(view.x - 32, 44)
	_tip.position = Vector2(16, view.y * 0.82)
	_tip.size = Vector2(view.x - 32, 40)

# Only actual completed work advances the overall percentage. A new pass may
# restart its own lower bar; overall progress must never go backwards or NaN.
func set_progress(percent: float, stage_text: String, pass_fraction: float = -1.0) -> void:
	if not is_finite(percent):
		return
	_progress = maxf(_progress, clampf(percent, 0.0, 1.0))
	_stage = stage_text.trim_suffix("...").trim_suffix("……")
	if _bar != null:
		_bar.current_pass = clampf(pass_fraction, 0.0, 1.0) if is_finite(pass_fraction) and pass_fraction >= 0.0 else _progress
		_bar.queue_redraw()
	_refresh_status()

func _refresh_status() -> void:
	if _stage_label != null:
		_stage_label.text = "%s……%d%%" % [_stage, int(floorf(_progress * 100.0 + 0.001))]

func _process(delta: float) -> void:
	_shown_progress = move_toward(_shown_progress, _progress, delta * 2.5)
	_bar.overall = _shown_progress
	_bar.queue_redraw()
	for root_name in ["Trees", "Clouds"]:
		var scenery := _background.get_node_or_null(root_name)
		if scenery == null: continue
		for sprite in scenery.get_children():
			if not sprite.has_meta("speed"): continue
			sprite.position.x -= float(sprite.get_meta("speed")) * delta
			if sprite.position.x < -1024: sprite.position.x += 3072

func finish_and_fade() -> void:
	if _finishing or _progress < 1.0:
		return
	_finishing = true
	_shown_progress = 1.0
	_bar.overall = 1.0
	_bar.queue_redraw()
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func(): finished.emit())
