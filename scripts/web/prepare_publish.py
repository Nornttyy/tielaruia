"""从 Godot 导出目录生成干净的发布包；文件名带内容版本，避免浏览器混用旧缓存。"""
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

root = Path(__file__).resolve().parents[2]
source = root / 'build/web'
target = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'build/web-publish'
target.mkdir(parents=True, exist_ok=True)
version = hashlib.sha256((source / 'index.pck').read_bytes() + (source / 'index.wasm').read_bytes()).hexdigest()[:12]
prefix = 'game-' + version
files = {}
for suffix in ['js', 'wasm', 'audio.worklet.js', 'audio.position.worklet.js']:
    old = source / ('index.' + suffix)
    new = target / (prefix + '.' + suffix)
    shutil.copy2(old, new)
    files[new.name] = new.stat().st_size
# Godot mainPack 支持任意扩展名，沿用原站的 .bin 资源包格式。
pack = target / (prefix + '.bin')
shutil.copy2(source / 'index.pck', pack)
files[pack.name] = pack.stat().st_size
for name in ['index.png', 'index.icon.png', 'index.apple-touch-icon.png']:
    shutil.copy2(source / name, target / name)
for name in ['peerjs_bridge.js', 'mobile_opt.js']:
    shutil.copy2(root / 'scripts/web' / name, target / name)
html = (source / 'index.html').read_text()
match = re.search(r'const GODOT_CONFIG = (.*?);', html)
config = json.loads(match.group(1))
config.update(executable=prefix, mainPack=pack.name, fileSizes=files)
html = html[:match.start()] + 'const GODOT_CONFIG = ' + json.dumps(config, separators=(',', ':')) + ';' + html[match.end():]
html = html.replace('src="index.js"', 'src="' + prefix + '.js"')
# 独立美术验收场景不创建或改写玩家存档。
html = html.replace('const engine = new Engine(GODOT_CONFIG);', 'if (new URLSearchParams(location.search).get("preview") === "art") GODOT_CONFIG.args = ["--", "--art-preview"];\nconst engine = new Engine(GODOT_CONFIG);')
if 'mobile_opt.js' not in html:
    html = html.replace('<head>', '<head>\n<script src="mobile_opt.js?v=' + version + '"></script>')
if 'peerjs_bridge.js' not in html:
    html = html.replace('</head>', '<script src="https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js"></script>\n<script src="peerjs_bridge.js?v=' + version + '"></script>\n</head>')
html = html.replace('<html lang="en">', '<html lang="zh-CN">')
(target / 'index.html').write_text(html)
shutil.copy2(root / 'assets/music/CREDITS.txt', target / 'MUSIC-CREDITS.txt')
(target / 'build-info.json').write_text(json.dumps({'build': version, 'music': 'CC0 replacement soundtrack', 'files': files}, indent=2))
print(json.dumps({'directory': str(target), 'version': version, 'files': len(list(target.iterdir()))}, ensure_ascii=False))
