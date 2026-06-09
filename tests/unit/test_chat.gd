# 联机聊天: 消息路由 → 信号 + 头顶气泡生成。
# (打字输入/门控靠真机验收; UI 实例化靠 smoke 启动覆盖。)
extends GutTest


func test_chat_message_routes_to_signal() -> void:
	# 收到 {"type":"chat","m":"你好"} → 该 emit chat_received(peer_id, "你好")
	var got := {"pid": "", "text": ""}
	var cb := func(pid: String, t: String): got.pid = pid; got.text = t
	NetworkManager.chat_received.connect(cb)
	NetworkManager._route_message('{"type":"chat","m":"你好"}', "P7")
	NetworkManager.chat_received.disconnect(cb)
	assert_eq(got.text, "你好", "chat 消息该路由到 chat_received 信号")
	assert_eq(got.pid, "P7", "chat 信号带来源 peer_id")


func test_chat_truncates_overlong() -> void:
	# 超长 (>120) 该被截断, 防刷屏/卡
	var got := {"text": ""}
	var cb := func(_pid: String, t: String): got.text = t
	NetworkManager.chat_received.connect(cb)
	var long_text := ""
	for i in 200:
		long_text += "a"
	NetworkManager._route_message(JSON.stringify({"type": "chat", "m": long_text}), "P7")
	NetworkManager.chat_received.disconnect(cb)
	assert_eq(got.text.length(), 120, "超长聊天该截到 120 字")


func test_speech_bubble_spawns_a_node() -> void:
	var root: Node = Effects._root()
	var before: int = root.get_child_count()
	Effects.spawn_speech_bubble(Vector2(40, 40), "hi there")
	assert_eq(root.get_child_count(), before + 1, "气泡该生成一个节点")


func test_speech_bubble_skips_empty() -> void:
	var root: Node = Effects._root()
	var before: int = root.get_child_count()
	Effects.spawn_speech_bubble(Vector2(0, 0), "")
	assert_eq(root.get_child_count(), before, "空文本不该冒泡")
