#!/bin/bash
# 把 peerjs_bridge.js 复制到 build/web/ + 给 index.html 插入 PeerJS + bridge script.
# 在每次 Godot Web export 后调用.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
INDEX_HTML="$PROJECT_DIR/build/web/index.html"
BRIDGE_SRC="$PROJECT_DIR/scripts/web/peerjs_bridge.js"
BRIDGE_DST="$PROJECT_DIR/build/web/peerjs_bridge.js"

if [ ! -f "$INDEX_HTML" ]; then
	echo "❌ 没找到 $INDEX_HTML, 先 export 再跑这个脚本"
	exit 1
fi

# 1) 复制 bridge js
cp "$BRIDGE_SRC" "$BRIDGE_DST"
echo "✓ 复制 peerjs_bridge.js → build/web/"

# 2) 注入 script tag (如果还没注入过)
if grep -q 'peerjs_bridge.js' "$INDEX_HTML"; then
	echo "✓ index.html 已含 bridge script, 跳过注入"
else
	# 在 </head> 前插入 PeerJS CDN + 我们的 bridge
	# 用 awk 处理 (sed 在 mac/linux 行为不同, awk 跨平台稳)
	TMP_FILE="$(mktemp)"
	awk '
		/<\/head>/ {
			print "    <script src=\"https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js\"></script>"
			print "    <script src=\"peerjs_bridge.js\"></script>"
		}
		{ print }
	' "$INDEX_HTML" > "$TMP_FILE"
	mv "$TMP_FILE" "$INDEX_HTML"
	echo "✓ 注入 <script src=peerjs.min.js> + <script src=peerjs_bridge.js> 到 index.html"
fi
