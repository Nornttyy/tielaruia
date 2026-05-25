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

    bridge.host = function() {
        bridge.disconnect();
        bridge._isHost = true;
        bridge._status = 'hosting';
        bridge._lastError = '';
        // PeerJS 公共 broker. 自定义 id = 房间码 (用户分享给朋友的代码)
        var code = _genRoomCode();
        // teilaruia- 前缀避免跟其他 PeerJS 项目撞 id
        var fullId = 'teilaruia-' + code;
        try {
            bridge._peer = new Peer(fullId, { debug: 1 });
        } catch (e) {
            bridge._lastError = 'PeerJS not loaded';
            bridge._status = 'error';
            return;
        }
        bridge._peer.on('open', function(id) {
            // id 是 broker 给的实际 id (= fullId)
            bridge._myId = code;  // 展示给用户的是 6 位
        });
        bridge._peer.on('connection', function(conn) {
            _setupConn(conn);
        });
        bridge._peer.on('error', function(err) {
            // id 冲突或 broker 失败. 重试一次用不同 code.
            bridge._lastError = 'peer error: ' + (err.type || err.message || err);
            bridge._status = 'error';
        });
    };

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
            bridge._peer = new Peer(null, { debug: 1 });
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
