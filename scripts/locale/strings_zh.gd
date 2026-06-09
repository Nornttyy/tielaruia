# 中文 (基准语言). Locale.t(key) 找不到当前语言时 fallback 来这里.
# 加新文字: 先在这里定 key 中文, 然后 strings_en/ja/ko 加同名 key.
extends RefCounted

const S := {
	# ===== 语言选择 (设置面板里的下拉) =====
	"lang_name": "中文",
	"lang_label": "语言",

	# ===== 主菜单 =====
	"menu_subtitle": "2D 沙盒 · Terraria 风",
	"menu_new_game": "开始游戏",
	"menu_multiplayer": "多人游戏",
	"menu_settings": "设置",

	# ===== 设置面板 =====
	"settings_title": "设 置",         # 标题: 中文用宽空字距修饰, 英文/日文/韩文不用
	"settings_master_volume": "主音量",
	"settings_camera_zoom": "镜头",
	"settings_scroll_zoom": "滚轮缩放镜头",
	"settings_player_name": "玩家名",
	"settings_player_name_placeholder": "玩家",
	"settings_enemy_hp_bar": "怪物血条",
	"settings_enemy_hp_number": "怪物血量数字",
	"settings_back": "返回",

	# ===== 世界选择面板 =====
	"world_select_title": "选 择 世 界",
	"world_select_empty": "(没有存档, 创建一个新世界开始游戏)",
	"world_new": "+ 创建新世界",
	"world_enter": "进入",
	"world_delete": "删除",
	"world_back": "返回",
	"save_diff_easy": "简单",
	"save_diff_normal": "普通",
	"save_diff_hard": "困难",

	# ===== 新建世界面板 =====
	"newgame_title": "新 游 戏",
	"newgame_name_label": "世界名",
	"newgame_seed_label": "种子",
	"newgame_seed_random": "随机",
	"newgame_difficulty_label": "难度",
	"newgame_difficulty_easy": "简单",
	"newgame_difficulty_normal": "普通",
	"newgame_difficulty_hard": "困难",
	"newgame_mode_label": "模式",
	"newgame_mode_survival": "生存",
	"newgame_mode_creative": "创造",
	"newgame_cancel": "取消",
	"newgame_start": "开始",
	"newgame_default_world_name": "我的世界",     # 名字输入框留空时的默认 + placeholder
	"newgame_seed_placeholder": "随机",

	# ===== 多人游戏面板 =====
	"mp_title": "多 人 游 戏",
	"mp_rooms_title": "房间",
	"mp_public_survival": "公共生存房",
	"mp_public_pvp": "公共对战房",
	"mp_join_title": "加入房间",
	"mp_entering_public": "正在进入公共房…",
	"mp_room_code_prompt": "输入朋友给的 6 位房间码",
	"mp_room_code_placeholder": "6 位房间码",
	"mp_join_label": "加入",
	"mp_back": "返回",
	"mp_status_idle": "输入朋友给的 6 位房间码",
	"mp_status_joining": "连接中...",
	"mp_status_connected": "已连接, 加载世界...",
	"mp_status_disconnected": "对方断开了",
	"mp_status_error_prefix": "出错: ",
	"mp_room_code_invalid": "房间码必须是 6 位字母数字",
	"mp_module_missing": "联机模块未加载",
	"mp_default_world_name": "联机世界",

	# ===== 删除存档对话框 =====
	"delete_save_title": "删除存档",
	"delete_save_message": "真的要删除存档 \"%s\" 吗? \n这个操作不能撤销!",
	"delete_save_ok": "删除",
	"delete_save_cancel": "取消",

	# ===== 暂停菜单 =====
	"pause_title": "已 暂 停",
	"pause_resume": "继续游戏",
	"pause_multiplayer": "多人游戏",
	"pause_return_menu": "回主菜单",
	"pause_mp_title": "多人游戏",
	"pause_mp_hint": "把房间码发给朋友, 他在主菜单 加入房间 输入即可",
	"pause_mp_generating": "正在生成房间码...",
	"pause_mp_back": "返回",
	"pause_mp_hosting": "已开放, 等朋友加入",
	"pause_mp_connected": "朋友已加入, 联机中",
	"pause_mp_disconnected": "已断开",
	"pause_mp_error": "出错",
	"pause_mp_error_prefix": "出错: ",
	"pause_mp_no_network": "NetworkManager 不在 (非 Web 平台?)",
	"pause_mp_wait_for_join": "等朋友输入此码加入",
	"pause_mp_room_pending": "生成中...",
	"pause_mp_room_wait": "请稍候",
	"pause_mp_already_hosting": "已开放, 等朋友加入",
	"pause_mp_already_connected": "朋友已加入",

	# ===== 死亡屏幕 =====
	"death_title": "你　死　了",
	"death_respawn": "回到出生点",

	# ===== 箱子面板 =====
	"chest_title": "箱子",
	"chest_take_all": "全拿 ⇩",
	"chest_inv_hint": "你的背包 (Shift+左键 转移单槽)",
	"chest_close": "关闭 (ESC / 右键)",
}
