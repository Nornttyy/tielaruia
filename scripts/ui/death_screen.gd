# 死亡屏幕：黑屏淡入 + "你 死 了" + 回到出生点按钮。
# 玩家死亡时由 main.gd 调 show_death() 显示，按钮按下发 respawn 信号。
# CanvasLayer process_mode = ALWAYS，暂停时仍可点击。
extends CanvasLayer

const UIStyle = preload("res://scripts/ui/ui_style.gd")

signal respawn

const FADE_DURATION := 0.6

@onready var _bg: ColorRect = $Background
@onready var _title: Label = $TitleLabel
@onready var _respawn_button: Button = $RespawnButton

var _tween: Tween = null


func _ready() -> void:
	visible = false
	UIStyle.style_button(_respawn_button)   # 蓝色复活按钮
	_respawn_button.pressed.connect(_on_respawn_pressed)
	# i18n: 切语言时刷文字
	if Locale != null:
		_refresh_i18n("")
		if not Locale.language_changed.is_connected(_refresh_i18n):
			Locale.language_changed.connect(_refresh_i18n)


func _refresh_i18n(_new_lang: String) -> void:
	if _title != null:
		_title.text = Locale.t("death_title")
	if _respawn_button != null:
		_respawn_button.text = Locale.t("death_respawn")


func show_death() -> void:
	visible = true
	_respawn_button.disabled = true
	_bg.modulate.a = 0.0
	_title.modulate.a = 0.0
	_respawn_button.modulate.a = 0.0
	get_tree().paused = true
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_bg, "modulate:a", 1.0, FADE_DURATION)
	_tween.tween_property(_title, "modulate:a", 1.0, FADE_DURATION).set_delay(0.2)
	_tween.tween_property(_respawn_button, "modulate:a", 1.0, FADE_DURATION).set_delay(0.3)
	_tween.chain().tween_callback(func(): _respawn_button.disabled = false)


func hide_death() -> void:
	visible = false
	if _tween != null and _tween.is_running():
		_tween.kill()
	get_tree().paused = false


# 测试用：跳过 tween 直接到末态
func skip_fade_for_test() -> void:
	if _tween != null and _tween.is_running():
		_tween.custom_step(FADE_DURATION * 2)
	_bg.modulate.a = 1.0
	_title.modulate.a = 1.0
	_respawn_button.modulate.a = 1.0
	_respawn_button.disabled = false


func _on_respawn_pressed() -> void:
	respawn.emit()
