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
    var PEER_HOST = "";   // 例: "teilaruia-peer.onrender.com"

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

    bridge._hostRetries = 0;

    bridge.host = function() {
        bridge.disconnect();
        bridge._isHost = true;
        bridge._status = 'hosting';
        bridge._lastError = '';
        bridge._hostRetries = 0;
        _hostAttempt();
    };

    function _hostAttempt() {
        // PeerJS 公共 broker. 自定义 id = 房间码 (用户分享给朋友的代码)
        var code = _genRoomCode();
        var fullId = 'teilaruia-' + code;
        try {
            bridge._peer = new Peer(fullId, _peerOpts());
        } catch (e) {
            bridge._lastError = 'PeerJS not loaded';
            bridge._status = 'error';
            return;
        }
        bridge._peer.on('open', function(id) {
            bridge._myId = code;
        });
        bridge._peer.on('connection', function(conn) {
            _setupConn(conn);
        });
        bridge._peer.on('error', function(err) {
            var et = err.type || err.message || err;
            // id 冲突: 换 code 重试 (最多 5 次)
            if (et === 'unavailable-id' && bridge._hostRetries < 5) {
                bridge._hostRetries++;
                try { bridge._peer.destroy(); } catch (e) {}
                _hostAttempt();
                return;
            }
            bridge._lastError = 'peer error: ' + et;
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
        bridge._isHost = false;
        bridge._status = 'joining';
        bridge._lastError = '';
        var fullId = 'teilaruia-' + code.toUpperCase();
        try {
            bridge._peer = new Peer(null, _peerOpts());
        } catch (e) {
            bridge._lastError = 'PeerJS not loaded';
            bridge._status = 'error';
            return;
        }
        bridge._peer.on('open', function(myId) {
            // 现在尝试连 host
            var conn = bridge._peer.connect(fullId, { reliable: true });
            _setupConn(conn);
        });
        bridge._peer.on('error', function(err) {
            bridge._lastError = 'peer error: ' + (err.type || err.message || err);
            bridge._status = 'error';
        });
    };

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
