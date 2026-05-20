#!/usr/bin/env bash
# 部署到 surge.sh —— 自动 export + 改 .pck → .bin (surge 封了 .pck) + 推送
# 用法: bash deploy-surge.sh
set -euo pipefail

cd "$(dirname "$0")"

echo "→ 1/3 godot 重新导出 web..."
godot --headless --export-release "Web" build/web/index.html 2>&1 | tail -2

echo "→ 2/3 .pck → .bin (绕过 surge 封禁) + 改 index.html..."
if [ -f build/web/index.pck ]; then
	mv build/web/index.pck build/web/index.bin
fi
# index.html 里的 GODOT_CONFIG 把 fileSizes/index.pck → index.bin 并加 mainPack
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("build/web/index.html")
s = p.read_text()
s = re.sub(r'"index\.pck"\s*:', '"index.bin":', s)
if '"mainPack":"index.bin"' not in s:
	s = s.replace('"gdextensionLibs":[]', '"gdextensionLibs":[],"mainPack":"index.bin"')
p.write_text(s)
print("  index.html OK")
PY

echo "→ 3/3 surge 推送..."
node -e "
const { spawn } = require('child_process');
const p = spawn('surge', ['build/web', 'teilaruia-demo.surge.sh']);
p.stdout.on('data', d => process.stdout.write(d));
p.stderr.on('data', d => process.stderr.write(d));
p.on('close', code => process.exit(code));
" 2>&1 | grep -E "Success|Aborted|size:" | tail -3

echo ""
echo "✓ 完成。访问 https://teilaruia-demo.surge.sh/"
