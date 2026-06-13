# 联机公平验收: 怪/Boss 追"最近的玩家"(含加入的远程玩家), 不再只盯房主。
# 之前 harpy/demon_eye/hell_wasp/imp/mimic/skeleton + 三个 Boss 都写死 players[0](本地玩家),
# 联机里完全无视加入者。现统一改用 PlayersUtil.nearest_player。
extends GutTest

const ImpScene = preload("res://scenes/entities/imp.tscn")

const FIXED_FILES := [
	"res://scripts/entities/harpy.gd", "res://scripts/entities/demon_eye.gd",
	"res://scripts/entities/hell_wasp.gd", "res://scripts/entities/imp.gd",
	"res://scripts/entities/mimic.gd", "res://scripts/entities/skeleton.gd",
	"res://scripts/entities/demon_lord.gd", "res://scripts/entities/skeleton_king.gd",
	"res://scripts/entities/king_slime.gd",
]


class StubPlayer:
	extends Node2D
	func _init(grp: String) -> void:
		add_to_group(grp)


func test_all_fixed_entities_compile() -> void:
	# 编辑后 9 个脚本都该正常编译 (catch preload 路径错/语法坏)
	for path in FIXED_FILES:
		var s = load(path)
		assert_true(s != null, "%s 该能加载 (没被改坏)" % path)


func test_imp_targets_nearest_including_remote() -> void:
	# 远程玩家(加入者)在近处, 本地玩家(房主)在远处 → 怪该追近的远程玩家
	var local := StubPlayer.new("player")
	add_child_autofree(local)
	local.global_position = Vector2(300, 0)
	var remote := StubPlayer.new("remote_player")
	add_child_autofree(remote)
	remote.global_position = Vector2(40, 0)

	var imp = ImpScene.instantiate()
	add_child_autofree(imp)
	imp.global_position = Vector2(0, 0)
	await wait_frames(1)
	var target = imp._find_player()
	assert_eq(target, remote, "怪该追最近的玩家(含加入的远程玩家), 不是只盯房主")


func test_imp_single_player_targets_local() -> void:
	# 单机: 没有 remote_player → 退化成追本地玩家 (行为不变)
	var local := StubPlayer.new("player")
	add_child_autofree(local)
	local.global_position = Vector2(50, 0)
	var imp = ImpScene.instantiate()
	add_child_autofree(imp)
	imp.global_position = Vector2(0, 0)
	await wait_frames(1)
	assert_eq(imp._find_player(), local, "单机仍正常追本地玩家")
