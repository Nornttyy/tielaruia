# 一次性武器美术预览 (headless). 把所有枪 + 法杖图标放大拼成 PNG, 发给用户过目.
# 跑法: godot --headless --script res://scripts/tools/render_weapons_sheet.gd
# 产出: /tmp/art_preview/guns.png  /tmp/art_preview/staves.png  /tmp/art_preview/projectiles.png
extends SceneTree

const ItemsArt = preload("res://scripts/art/items_art.gd")

const ZOOM := 8
const CELL := 16
const PAD := 6
const COLS := 6
const BG := Color8(48, 52, 60)

const GUNS := [
	"pistol", "smg", "assault_rifle", "shotgun", "sniper", "laser_gun",
	"flamethrower", "freeze_ray", "arcane_gun", "poison_gun", "lightning_gun",
	"star_gun", "slime_gun", "frost_gun", "leaf_gun", "minigun", "twin_magic_gun",
	"rocket_gun", "ricochet_gun", "tesla_gun", "cryo_gun", "venom_gun", "railgun",
]
const STAVES := [
	"wood_staff", "iron_staff", "hell_staff", "skull_staff", "lightning_staff",
	"poison_staff", "multi_staff", "explosive_staff", "water_staff", "wind_staff",
	"heal_staff", "bird_staff", "crack_staff", "homing_staff", "beam_staff",
	"frost_staff", "bounce_star_staff", "meteor_staff", "penta_staff",
	"greater_heal_staff", "shield_staff",
]


func _init() -> void:
	var dir := DirAccess.open("/tmp")
	if dir and not dir.dir_exists("art_preview"):
		dir.make_dir("art_preview")
	_render_icons(GUNS, "/tmp/art_preview/guns.png")
	_render_icons(STAVES, "/tmp/art_preview/staves.png")
	_render_projectiles()
	quit()


func _render_icons(ids: Array, path: String) -> void:
	var pairs: Array = []
	for id in ids:
		if not ItemsArt.has_icon(id):
			print("缺图标: ", id)
			continue
		pairs.append([id, ItemsArt.get_icon(id).get_image()])
	_render_images(pairs, path)


# 投射物首帧预览 (T7)
func _render_projectiles() -> void:
	var projs := {
		"bullet": preload("res://scripts/art/bullet_proj_art.gd").build_sprite_frames(),
		"laser": preload("res://scripts/art/laser_proj_art.gd").build_sprite_frames(),
		"magic": preload("res://scripts/art/magic_proj_art.gd").build_sprite_frames(),
		"lightning": preload("res://scripts/art/lightning_proj_art.gd").build_sprite_frames(),
		"star": preload("res://scripts/art/star_proj_art.gd").build_sprite_frames(),
		"slimeblob": preload("res://scripts/art/slime_blob_proj_art.gd").build_sprite_frames(),
		"leaf": preload("res://scripts/art/leaf_proj_art.gd").build_sprite_frames(),
		"wind": preload("res://scripts/art/wind_proj_art.gd").build_sprite_frames(),
		"fire": preload("res://scripts/art/fireball_art.gd").build_sprite_frames("fire"),
		"ice": preload("res://scripts/art/fireball_art.gd").build_sprite_frames("ice"),
		"nature": preload("res://scripts/art/fireball_art.gd").build_sprite_frames("nature"),
	}
	var pairs: Array = []
	for key in projs:
		var sf: SpriteFrames = projs[key]
		var anim: String = sf.get_animation_names()[0]
		pairs.append([key, sf.get_frame_texture(anim, 0).get_image()])
	_render_images(pairs, "/tmp/art_preview/projectiles.png")


# pairs: [[名字, Image], ...] → 放大拼格子存 PNG, 控制台打印图例
func _render_images(pairs: Array, path: String) -> void:
	var rows: int = int(ceil(float(pairs.size()) / float(COLS)))
	var cw: int = (CELL + PAD) * ZOOM
	var img := Image.create(COLS * cw + PAD * ZOOM, rows * cw + PAD * ZOOM, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	for i in pairs.size():
		var name: String = pairs[i][0]
		var src: Image = pairs[i][1]
		var big: Image = src.duplicate()
		big.resize(big.get_width() * ZOOM, big.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
		var x: int = (i % COLS) * cw + PAD * ZOOM
		var y: int = int(float(i) / float(COLS)) * cw + PAD * ZOOM
		img.blend_rect(big, Rect2i(0, 0, big.get_width(), big.get_height()), Vector2i(x, y))
		print("[%d,%d] %s" % [i % COLS, int(float(i) / float(COLS)), name])
	img.save_png(path)
	print("saved: ", path)
