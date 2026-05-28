# 5 颗红心: 每颗 20 HP; cur >= (i+1)*20 满, cur >= 2i*10+10 半, 否则空。
extends Control

const HEART_SIZE := 10
const HEART_SCALE := 2          # 渲染放大倍数 (20px 每颗, 保持原来大小)
const HEART_SPACING := 2
const NUM_HEARTS := 5
const HP_PER_HEART := 20
const PAD := 8

var _cur: int = 100
var _max: int = 100


func _ready() -> void:
	custom_minimum_size = Vector2(
		PAD * 2 + (HEART_SIZE * HEART_SCALE + HEART_SPACING) * NUM_HEARTS - HEART_SPACING,
		PAD * 2 + HEART_SIZE * HEART_SCALE
	)


func bind(health_node: Node) -> void:
	if health_node == null:
		return
	if health_node.has_signal("health_changed"):
		health_node.health_changed.connect(_on_changed)
	_on_changed(health_node.current_health, health_node.MAX_HEALTH)


func _on_changed(cur: int, maximum: int) -> void:
	_cur = cur
	_max = maximum
	queue_redraw()


func _draw() -> void:
	# 每颗心 = 一个 20px 槽位. 槽位里:
	#   底色: 空心轮廓 (始终绘制, 让玩家看到血量上限)
	#   叠层: 满心按 "本颗剩余 HP / 20" 缩小绘制 (居中). 5 颗心都按各自范围连续缩.
	var slot_px := HEART_SIZE * HEART_SCALE
	for i in NUM_HEARTS:
		var x: float = PAD + i * (slot_px + HEART_SPACING)
		var y: float = PAD
		# 始终画空心轮廓占位
		if ArtCache.heart_empty != null:
			draw_texture_rect(ArtCache.heart_empty, Rect2(x, y, slot_px, slot_px), false)
		# 本颗心代表 HP 范围 (i*20, (i+1)*20], 算剩余 fraction
		var fill_hp: int = clamp(_cur - i * HP_PER_HEART, 0, HP_PER_HEART)
		if fill_hp <= 0:
			continue
		var fraction: float = float(fill_hp) / float(HP_PER_HEART)
		# 满心按比例缩小 + 居中. 最小给 2px 让贴脸血不要消失 (1 HP 还能看见一点)
		var size: float = max(2.0, slot_px * fraction)
		var offset: float = (slot_px - size) * 0.5
		if ArtCache.heart_full != null:
			draw_texture_rect(ArtCache.heart_full, Rect2(x + offset, y + offset, size, size), false)
