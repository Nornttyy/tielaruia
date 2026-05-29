#!/bin/bash
# 把 peerjs_bridge.js + mobile_opt.js 复制到 build/web/ + 给 index.html 插入 script tag.
# 在每次 Godot Web export 后调用.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
INDEX_HTML="$PROJECT_DIR/build/web/index.html"
BRIDGE_SRC="$PROJECT_DIR/scripts/web/peerjs_bridge.js"
BRIDGE_DST="$PROJECT_DIR/build/web/peerjs_bridge.js"
MOBILE_OPT_SRC="$PROJECT_DIR/scripts/web/mobile_opt.js"
MOBILE_OPT_DST="$PROJECT_DIR/build/web/mobile_opt.js"

if [ ! -f "$INDEX_HTML" ]; then
	echo "❌ 没找到 $INDEX_HTML, 先 export 再跑这个脚本"
	exit 1
fi

# 1) 复制 bridge js + mobile opt
cp "$BRIDGE_SRC" "$BRIDGE_DST"
echo "✓ 复制 peerjs_bridge.js → build/web/"
cp "$MOBILE_OPT_SRC" "$MOBILE_OPT_DST"
echo "✓ 复制 mobile_opt.js → build/web/"

# 2) 注入 script tag (如果还没注入过).
# 注: mobile_opt.js 要尽早 (head 顶部) 才能在 Godot 读 DPR 前覆写; bridge 在 </head> 前 OK.
if grep -q 'peerjs_bridge.js' "$INDEX_HTML"; then
	echo "✓ index.html 已含 bridge script, 跳过注入"
else
	# 用 awk 处理 (sed 在 mac/linux 行为不同, awk 跨平台稳).
	# - mobile_opt.js: <head> 之后立刻 (最早), 这样 Godot wasm 加载前就改了 DPR
	# - peerjs + bridge: </head> 之前 (其他 head 内容之后)
	TMP_FILE="$(mktemp)"
	awk '
		/<head>/ {
			print
			print "    <script src=\"mobile_opt.js\"></script>"
			next
		}
		/<\/head>/ {
			print "    <script src=\"https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js\"></script>"
			print "    <script src=\"peerjs_bridge.js\"></script>"
		}
		{ print }
	' "$INDEX_HTML" > "$TMP_FILE"
	mv "$TMP_FILE" "$INDEX_HTML"
	echo "✓ 注入 mobile_opt.js (head 顶) + peerjs.min.js + peerjs_bridge.js (</head> 前) 到 index.html"
fi
