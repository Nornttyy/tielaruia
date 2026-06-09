// PeerJS bridge for teilaruia multiplayer.
// 用 PeerJS 免费公共 broker 信令, 建立 WebRTC P2P 数据通道.
// Godot 通过 JavaScriptBridge.eval / get_interface() 访问 window.MultiplayerBridge.
//
// 接口 (Godot 调用):
//   host()               -> 启动 host, 异步获取 6 位房间码
//   join(roomCode)       -> 加入指定房间码
//   send(jsonStr)        -> 发字符串到对方
//   pop_messages()       -> 返回收到的消息 JSON 数组字符串 (取走清空)
//   get_status()         -> 'idle' / 'hosting' / 'joining' / 'connected' / 'disconnected' / 'error'
//   get_my_id()          -> 当前 peer 的 6 位房间码 (host 用)
//   get_last_error()     -> 最近的错误字符串 (status='error' 时有效)
//   is_host()            -> 是 host 还是 client
//   disconnect()         -> 断开连接, 回到 idle
(function() {
    'use strict';

    var bridge = {
        _peer: null,
        _conn: null,
        _status: 'idle',
        _myId: '',
        _isHost: false,
        _messages: [],
        _lastError: '',
    };

    // ⚙️ 联机服务器配置 ⚙️
    // 填上你自己的 PeerJS 服务器域名 (在 Render 免费部署后拿到, 不含 "https://" 和末尾的 "/")。
    // 留空 "" = 用 PeerJS 免费公共服务器 (大家都在蹭, 经常连不上 — 只当临时兜底)。
    // 部署教程见 docs/multiplayer-server-setup.md
    var PEER_HOST = "tielaruia.onrender.com";   // 自己的 Render 服务器 (稳, 只给自己人用)

    // 生成连服务器的参数: 填了 PEER_HOST 就连自己的服务器, 否则连公共的。
    function _peerOpts() {
        var o = { debug: 1 };
        if (PEER_HOST) {
            o.host = PEER_HOST;
            o.port = 443;
            o.secure = true;     // Render 是 https → 443 + secure
            o.path = "/peerjs";  // 跟服务器 index.js 里挂的路径一致
        }
        return o;
    }

    // 把 6 位字母+数字的 peer id 当 "房间码", 用户友好
    function _genRoomCode() {
        var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        var s = '';
        for (var i = 0; i < 6; i++) {
            s += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return s;
    }

    function _setupConn(conn) {
        bridge._conn = conn;
        conn.on('open', function() {
            bridge._status = 'connected';
        });
        conn.on('data', function(data) {
            // data 是字符串 (Godot 发什么收什么). 简单 push 到队列.
            bridge._messages.push(String(data));
        });
        conn.on('close', function() {
            bridge._status = 'disconnected';
        });
        conn.on('error', function(err) {
            bridge._lastError = 'conn error: ' + (err.type || err.message || err);
            bridge._status = 'error';
        });
    }

    // ---- 联机健壮性参数 ----
    bridge._gen = 0;            // "代次": host/join/disconnect 每次 +1, 作废上一轮挂着的重试/超时回调
    bridge._hostRetries = 0;
    bridge._joinRetries = 0;
    bridge._joinCode = '';
    var MAX_RETRIES = 4;        // 抽风时最多自动重试几次
    var RETRY_DELAY_MS = 1500;  // 每次重试间隔
    var JOIN_TIMEOUT_MS = 12000; // join 后这么久还没连上 host → 重试
    // 这些错误是"服务器/网络一时抽风", 该自动重试 (而不是直接报错)
    var _RETRYABLE = {'network': 1, 'server-error': 1, 'socket-error': 1, 'socket-closed': 1, 'unavailable-id': 1};

    // PeerJS 错误码 → 人话提示
    function _friendlyError(et) {
        switch (et) {
            case 'peer-unavailable': return '找不到房间 — 检查房间码对不对、房主开房间了没';
            case 'unavailable-id': return '房间码被占用了, 正在换一个…';
            case 'network': case 'server-error': case 'socket-error': case 'socket-closed':
                return '联机服务器忙, 正在重试… (免费服务器有时要等一下)';
            case 'connect-timeout': return '连不上房主, 正在重试…';
            case 'browser-incompatible': return '这个浏览器不支持联机, 换 Chrome 试试';
            case 'ssl-unavailable': return '联机需要 https';
            default: return '联机出错: ' + et;
        }
    }

    bridge.host = function() {
        bridge.disconnect();
        bridge._gen++;
        bridge._isHost = true;
        bridge._status = 'hosting';
        bridge._lastError = '';
        bridge._hostRetries = 0;
        _hostAttempt(bridge._gen);
    };

    function _hostAttempt(gen) {
        if (gen !== bridge._gen) return;   // 已被新的 host/disconnect 作废
        var code = _genRoomCode();
        var fullId = 'teilaruia-' + code;
        try {
            bridge._peer = new Peer(fullId, _peerOpts());
        } catch (e) {
            bridge._lastError = 'PeerJS 没加载好, 刷新页面再试';
            bridge._status = 'error';
            return;
        }
        bridge._peer.on('open', function() {
            if (gen !== bridge._gen) return;
            bridge._myId = code;
            bridge._hostRetries = 0;   // 成功开房 → 重置重试计数
        });
        bridge._peer.on('connection', function(conn) {
            if (gen !== bridge._gen) return;
            _setupConn(conn);
        });
        bridge._peer.on('disconnected', function() {
            // broker 连接掉了但 peer 没销毁 → 重连 broker, 保住已分享的房间码
            if (gen !== bridge._gen) return;
            try { if (bridge._peer && !bridge._peer.destroyed) bridge._peer.reconnect(); } catch (e) {}
        });
        bridge._peer.on('error', function(err) {
            if (gen !== bridge._gen) return;
            var et = err.type || err.message || err;
            if (_RETRYABLE[et]) {
                if (bridge._myId) {
                    // 已开房、码已分享 → 别换码, 重连 broker 即可
                    bridge._lastError = _friendlyError(et);
                    try { if (bridge._peer && !bridge._peer.destroyed) bridge._peer.reconnect(); } catch (e) {}
                    return;
                }
                if (bridge._hostRetries < MAX_RETRIES) {
                    bridge._hostRetries++;
                    bridge._lastError = _friendlyError(et);
                    bridge._status = 'hosting';   // 还在试, 别变 error
                    try { bridge._peer.destroy(); } catch (e) {}
                    setTimeout(function() { _hostAttempt(gen); }, RETRY_DELAY_MS);
                    return;
                }
            }
            bridge._lastError = _friendlyError(et);
            bridge._status = 'error';
        });
    }

    bridge.join = function(code) {
        if (!code || code.length !== 6) {
            bridge._lastError = '房间码必须是 6 位';
            bridge._status = 'error';
            return;
        }
        bridge.disconnect();
        bridge._gen++;
        bridge._isHost = false;
        bridge._status = 'joining';
        bridge._lastError = '';
        bridge._joinCode = code.toUpperCase();
        bridge._joinRetries = 0;
        _joinAttempt(bridge._gen);
    };

    function _joinAttempt(gen) {
        if (gen !== bridge._gen) return;
        var fullId = 'teilaruia-' + bridge._joinCode;
        try {
            bridge._peer = new Peer(null, _peerOpts());
        } catch (e) {
            bridge._lastError = 'PeerJS 没加载好, 刷新页面再试';
            bridge._status = 'error';
            return;
        }
        bridge._peer.on('open', function() {
            if (gen !== bridge._gen) return;
            var conn = bridge._peer.connect(fullId, { reliable: true });
            _setupConn(conn);
            // 连接开启超时: 一段时间还没连上 host (房主没开/码错/broker 慢) → 重试
            setTimeout(function() {
                if (gen !== bridge._gen) return;
                if (bridge._status === 'joining' && (!bridge._conn || !bridge._conn.open)) {
                    _joinRetryOrFail(gen, 'connect-timeout');
                }
            }, JOIN_TIMEOUT_MS);
        });
        bridge._peer.on('error', function(err) {
            if (gen !== bridge._gen) return;
            _joinRetryOrFail(gen, err.type || err.message || err);
        });
    }

    function _joinRetryOrFail(gen, et) {
        if (gen !== bridge._gen) return;
        if (bridge._joinRetries < MAX_RETRIES &&
                (_RETRYABLE[et] || et === 'peer-unavailable' || et === 'connect-timeout')) {
            bridge._joinRetries++;
            bridge._lastError = _friendlyError(et);
            bridge._status = 'joining';   // 还在试
            try { if (bridge._peer) bridge._peer.destroy(); } catch (e) {}
            setTimeout(function() { _joinAttempt(gen); }, RETRY_DELAY_MS);
            return;
        }
        bridge._lastError = _friendlyError(et);
        bridge._status = 'error';
    }

    bridge.send = function(jsonStr) {
        if (bridge._conn && bridge._conn.open) {
            bridge._conn.send(jsonStr);
            return true;
        }
        return false;
    };

    bridge.pop_messages = function() {
        var msgs = bridge._messages;
        bridge._messages = [];
        // Return as JSON string array — Godot will parse
        return JSON.stringify(msgs);
    };

    bridge.get_status = function() { return bridge._status; };
    bridge.get_my_id = function() { return bridge._myId; };
    bridge.get_last_error = function() { return bridge._lastError; };
    bridge.is_host = function() { return bridge._isHost; };

    bridge.disconnect = function() {
        bridge._gen = (bridge._gen || 0) + 1;   // 作废所有挂着的重试/超时回调
        if (bridge._conn) {
            try { bridge._conn.close(); } catch (e) {}
        }
        if (bridge._peer) {
            try { bridge._peer.destroy(); } catch (e) {}
        }
        bridge._peer = null;
        bridge._conn = null;
        bridge._status = 'idle';
        bridge._myId = '';
        bridge._isHost = false;
        bridge._messages = [];
        bridge._lastError = '';
    };

    window.MultiplayerBridge = bridge;
    console.log('[MultiplayerBridge] loaded');
})();
