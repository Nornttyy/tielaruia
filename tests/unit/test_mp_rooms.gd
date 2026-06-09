# 公共房纯逻辑单测 (常量 / peer id 格式 / 转发目标)。无 JS bridge, headless 可跑。
extends GutTest

const MpRooms = preload("res://scripts/net/mp_rooms.gd")


func test_public_peer_id_format() -> void:
	assert_eq(MpRooms.public_peer_id("SV", 1), "teilaruia-PUB-SV-1")
	assert_eq(MpRooms.public_peer_id("SV", 7), "teilaruia-PUB-SV-7")


func test_relay_type_classification() -> void:
	# 玩家个体 + 世界改动 = 要转发
	assert_true(MpRooms.is_relay_type("pos"), "pos 要转发给其它人")
	assert_true(MpRooms.is_relay_type("chat"), "chat 要转发")
	assert_true(MpRooms.is_relay_type("tile"), "挖/放方块要转发")
	# host 权威要先处理的 / host 独有的 = 不直接转发
	assert_false(MpRooms.is_relay_type("ent_dmg"), "伤害要 host 先算, 不直接转发")
	assert_false(MpRooms.is_relay_type("hello"), "hello 是 host 独有")


func test_relay_targets_excludes_origin() -> void:
	# 来自 A 的 pos → 转发给 B、C, 不发回 A (防回声)
	var targets: Array = MpRooms.relay_targets("pos", "A", ["A", "B", "C"])
	assert_eq(targets.size(), 2, "3 人里转给除来源外的 2 人")
	assert_true(targets.has("B") and targets.has("C"), "转给 B 和 C")
	assert_false(targets.has("A"), "不发回来源 A")


func test_relay_targets_empty_for_nonrelay_type() -> void:
	assert_eq(MpRooms.relay_targets("ent_dmg", "A", ["A", "B"]).size(), 0,
		"非转发类型 → 不转发给任何人")


func test_is_player_type() -> void:
	assert_true(MpRooms.is_player_type("pos"), "pos 是玩家个体消息")
	assert_true(MpRooms.is_player_type("chat"))
	assert_false(MpRooms.is_player_type("tile"), "tile 是世界改动不是玩家个体")
