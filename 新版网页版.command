#!/bin/bash
cd "$(dirname "$0")"
python3 -u - <<'PY'
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
from pathlib import Path
import webbrowser
folder=Path.cwd()/'build/web-publish'
if not (folder/'index.html').exists():
    input('没有找到新版网页文件，请让 Codex 重新导出。按回车关闭。')
    raise SystemExit(1)
server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=str(folder)))
url='http://127.0.0.1:'+str(server.server_port)
print('新版游戏：'+url+'\n玩的时候保留此窗口；关闭窗口即停止网页。')
webbrowser.open(url)
try: server.serve_forever()
except KeyboardInterrupt: server.server_close()
PY
