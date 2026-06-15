extends GutTest

const HostSuccession = preload("res://scripts/net/host_succession.gd")

var succ

func before_each() -> void:
	succ = HostSuccession.new()

func test_join_order_preserved() -> void:
	succ.on_join("A")
	succ.on_join("B")
	succ.on_join("C")
	assert_eq(succ.ordered(), ["A", "B", "C"], "应按加入顺序")

func test_rank_is_index() -> void:
	succ.on_join("A")
	succ.on_join("B")
	assert_eq(succ.rank_of("A"), 0, "最早进的 rank=0")
	assert_eq(succ.rank_of("B"), 1)
	assert_eq(succ.rank_of("Z"), -1, "没进过的返回 -1")

func test_join_idempotent() -> void:
	succ.on_join("A")
	succ.on_join("A")
	assert_eq(succ.ordered().size(), 1, "重复 join 不重复加")

func test_leave_removes_but_keeps_order() -> void:
	succ.on_join("A")
	succ.on_join("B")
	succ.on_join("C")
	succ.on_leave("B")
	assert_eq(succ.ordered(), ["A", "C"], "B 走了, A/C 保持相对顺序")
	assert_eq(succ.rank_of("A"), 0)
	assert_eq(succ.rank_of("C"), 1, "B 走后 C 的 rank 紧凑到 1")

func test_wait_seconds_by_rank() -> void:
	succ.on_join("A")
	succ.on_join("B")
	succ.on_join("C")
	assert_almost_eq(succ.wait_for("A", 3.0), 0.0, 0.001, "rank0 立刻")
	assert_almost_eq(succ.wait_for("B", 3.0), 3.0, 0.001)
	assert_almost_eq(succ.wait_for("C", 3.0), 6.0, 0.001)

func test_wait_for_unknown_waits_after_everyone() -> void:
	succ.on_join("A")
	succ.on_join("B")
	# 不在表里 (名单过期 / 还没分到号) → 排在所有已知接班人之后, 不会 0 秒抢房主
	assert_almost_eq(succ.wait_for("Z", 3.0), 9.0, 0.001, "(size+1)*stagger = 3*3")

func test_clear() -> void:
	succ.on_join("A")
	succ.clear()
	assert_eq(succ.ordered().size(), 0)
