# 面板(合成/箱子/创造物品大全)开着时, 滚轮该留给面板里的列表滚, 不该缩放摄像机/切快捷栏.
extends GutTest

const PlayerInventory = preload("res://scripts/player/player_inventory.gd")


class FakePanel:
	extends Node
	var _open: bool = true
	func is_open() -> bool:
		return _open


var _saved_zoom: float
var _saved_mode: bool


func before_each() -> void:
	_saved_zoom = GameSettings.camera_zoom
	_saved_mode = GameSettings.scroll_wheel_zoom
	GameSettings.scroll_wheel_zoom = true   # 滚轮=缩放模式


func after_each() -> void:
	GameSettings.camera_zoom = _saved_zoom
	GameSettings.scroll_wheel_zoom = _saved_mode


func _wheel_up() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	return ev


func test_wheel_skips_zoom_when_panel_open():
	var inv = PlayerInventory.new()
	add_child_autofree(inv)
	var panel = FakePanel.new()
	panel.add_to_group("crafting_panel")
	add_child_autofree(panel)
	await wait_frames(1)
	var before: float = GameSettings.camera_zoom
	inv._unhandled_input(_wheel_up())
	assert_eq(GameSettings.camera_zoom, before, "面板开着时滚轮不该缩放摄像机 (留给列表滚)")


func test_wheel_zooms_when_no_panel():
	var inv = PlayerInventory.new()
	add_child_autofree(inv)
	await wait_frames(1)
	var before: float = GameSettings.camera_zoom
	inv._unhandled_input(_wheel_up())
	assert_ne(GameSettings.camera_zoom, before, "没面板时滚轮正常缩放 (别误伤)")
