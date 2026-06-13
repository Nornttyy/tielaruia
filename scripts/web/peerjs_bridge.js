// PeerJS bridge for teilaruia multiplayer.
// 星形拓扑 + host 权威: 所有 client 只连 host; host 用连接表 _conns 群发/转发.
// Godot 通过 JavaScriptBridge.eval / get_interface() 访问 window.MultiplayerBridge.
//
// 接口 (Godot 调用):
//   host()                  -> 启动私人 host (6 位房间码)
//   join(roomCode)          -> 加入指定房间码
//   enter_public(tag,maxPeers,maxRooms) -> 进公共房 (谁先到谁当 host, 房满顺延下一号)
//   send(jsonStr)           -> host: 群发所有 client; client: 发给 host
//   send_to(peerId,jsonStr) -> host: 只发给某个 client (转发用)
//   pop_messages()          -> 取走收到的消息: [{from:"<peerId>",data:"<字符串>"}, ...] 的 JSON
//   get_peer_ids()          -> host 当前所有 client peer id 的 JSON 数组
//   get_peer_count()        -> host 当前 client 数
//   get_status()            -> 'idle'/'hosting'/'joining'/'connected'/'disconnected'/'error'
//   get_my_id()             -> host 的房间码 / 公共房号
//   get_last_error()        -> 最近错误字符串
//   is_host()               -> 是 host 还是 client
//   disconnect()            -> 断开, 回 idle
(function() {
    'use strict';

    var bridge = {
        _peer: null,
        _conns: {},        // host 端: peerId -> DataConnection (多 client)
        _hostConn: null,   // client 端: 到 host 的连接
        _status: 'idle',
        _myId: '',
        _isHost: false,
        _messages: [],
        _lastError: '',
    };

    // ⚙️ 联机服务器配置 ⚙️ (自建 Render 服务器, 稳, 只给自己人用)
    var PEER_HOST = "tielaruia.onrender.com";

    function _peerOpts() {
        var o = { debug: 1 };
        if (PEER_HOST) {
            o.host = PEER_HOST;
            o.port = 443;
            o.secure = true;     // Render 是 https → 443 + secure
            o.path = "/peerjs";  // 跟服务器 index.js 里挂的路径一致
        }
        // NAT 穿透: 信令服只负责"互相找到", 真正传数据是两台机直连(WebRTC).
        // 很多家庭路由挡直连 → 只能连上 1-2 个人. 加 STUN(探外网地址) + 免费公共 TURN(直连失败时中转),
        // 连接成功率大幅提高 (= 修"联机最多两人/公共房只有一个人"). 不绑卡, 用现成免费中转.
        o.config = {
            iceServers: [
                { urls: "stun:stun.l.google.com:19302" },
                { urls: "stun:stun1.l.google.com:19302" },
                { urls: "turn:openrelay.metered.ca:80", username: "openrelayproject", credential: "openrelayproject" },
                { urls: "turn:openrelay.metered.ca:443", username: "openrelayproject", credential: "openrelayproject" },
                { urls: "turn:openrelay.metered.ca:443?transport=tcp", username: "openrelayproject", credential: "openrelayproject" }
            ]
        };
        return o;
    }

    function _genRoomCode() {
        var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        var s = '';
        for (var i = 0; i < 6; i++) {
            s += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return s;
    }

    // 一条连接的事件. isIncoming=true: host 端收到的 client 连接 (进 _conns 表);
    // false: client 到 host 的连接.
    function _setupConn(conn, isIncoming) {
        conn.on('open', function() {
            bridge._status = 'connected';
            if (isIncoming) {
                bridge._conns[conn.peer] = conn;
                // 通知 GDScript 有人进来了
                bridge._messages.push({from: '__sys', data: JSON.stringify({type: '__peer_join', id: conn.peer})});
            }
        });
        conn.on('data', function(data) {
            // 进队带来源: host 端 = conn.peer; client 端 = 'HOST'
            bridge._messages.push({from: isIncoming ? conn.peer : 'HOST', data: String(data)});
        });
        conn.on('close', function() {
            if (isIncoming) {
                delete bridge._conns[conn.peer];
                bridge._messages.push({from: '__sys', data: JSON.stringify({type: '__peer_leave', id: conn.peer})});
            } else {
                bridge._status = 'disconnected';   // 到 host 的连接断了 = 房主走了
            }
        });
        conn.on('error', function(err) {
            bridge._lastError = 'conn error: ' + (err.type || err.message || err);
        });
    }

    // host 端收到一个新连接: 房满礼貌拒绝 (client 会自动试下一号房), 否则接纳.
    function _onIncoming(conn, gen) {
        if (gen !== bridge._gen) return;
        var cap = bridge._maxPeers || 8;
        if (Object.keys(bridge._conns).length + 1 >= cap) {   // +1 含 host 自己
            conn.on('open', function() {
                try { conn.send(JSON.stringify({__full: 1})); } catch (e) {}
                setTimeout(function() { try { conn.close(); } catch (e) {} }, 200);
            });
            return;
        }
        _setupConn(conn, true);
    }

    // ---- 联机健壮性参数 ----
    bridge._gen = 0;            // "代次": 每次 host/join/enter/disconnect +1, 作废上一轮挂着的回调
    bridge._hostRetries = 0;
    bridge._joinRetries = 0;
    bridge._joinCode = '';
    bridge._maxPeers = 8;
    var MAX_RETRIES = 4;
    var RETRY_DELAY_MS = 1500;
    var JOIN_TIMEOUT_MS = 12000;
    // 抢号竞争中 (已翻转过) 的重连超时: 短一点, 好快速识破"幽灵房主"(号被占但连不上) → 早点换号房,
    // 不然每次重连都等满 12s, 8 次翻转 = 90s+ 刷屏卡死 (用户报)。首次进房仍用 12s (容忍慢信令)。
    var CONTEST_JOIN_TIMEOUT_MS = 4500;
    // 抢公共房脑裂保护: client 连不上占用者 → 去抢 host → "id taken" → 又退回 client → 无限 ping-pong
    // (零间隔, 刷爆控制台且永远连不上). 每翻转一次 host↔client 计数; 加随机退避打散两端并给 WebRTC
    // 协商时间; 翻转超上限就退一格房号重来, 房号用完才友好报错。
    bridge._pubFlips = 0;
    var MAX_PUB_FLIPS = 4;   // 翻转这么多次还没连上 → 这号房有幽灵, 换下一号 (原 8 太多, 卡太久)
    var _RETRYABLE = {'network': 1, 'server-error': 1, 'socket-error': 1, 'socket-closed': 1, 'unavailable-id': 1};

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

    // ===== 私人房: host (6 位码) =====
    bridge.host = function(maxPeers) {
        bridge.disconnect();
        bridge._gen++;
        bridge._isHost = true;
        bridge._status = 'hosting';
        bridge._lastError = '';
        bridge._hostRetries = 0;
        bridge._maxPeers = maxPeers || 8;   // 私人房用玩家设的"房间最多人数"
        _hostAttempt(bridge._gen);
    };

    function _hostAttempt(gen) {
        if (gen !== bridge._gen) return;
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
            bridge._hostRetries = 0;
        });
        bridge._peer.on('connection', function(conn) { _onIncoming(conn, gen); });
        bridge._peer.on('disconnected', function() {
            if (gen !== bridge._gen) return;
            try { if (bridge._peer && !bridge._peer.destroyed) bridge._peer.reconnect(); } catch (e) {}
        });
        bridge._peer.on('error', function(err) {
            if (gen !== bridge._gen) return;
            var et = err.type || err.message || err;
            if (_RETRYABLE[et]) {
                if (bridge._myId) {
                    bridge._lastError = _friendlyError(et);
                    try { if (bridge._peer && !bridge._peer.destroyed) bridge._peer.reconnect(); } catch (e) {}
                    return;
                }
                if (bridge._hostRetries < MAX_RETRIES) {
                    bridge._hostRetries++;
                    bridge._lastError = _friendlyError(et);
                    bridge._status = 'hosting';
                    try { bridge._peer.destroy(); } catch (e) {}
                    setTimeout(function() { _hostAttempt(gen); }, RETRY_DELAY_MS);
                    return;
                }
            }
            bridge._lastError = _friendlyError(et);
            bridge._status = 'error';
        });
    }

    // ===== 私人房: join (输码) =====
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
            bridge._hostConn = conn;
            _setupConn(conn, false);
            setTimeout(function() {
                if (gen !== bridge._gen) return;
                if (bridge._status === 'joining' && (!conn || !conn.open)) {
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
            bridge._status = 'joining';
            try { if (bridge._peer) bridge._peer.destroy(); } catch (e) {}
            setTimeout(function() { _joinAttempt(gen); }, RETRY_DELAY_MS);
            return;
        }
        bridge._lastError = _friendlyError(et);
        bridge._status = 'error';
    }

    // ===== 公共房: 谁先到谁当 host, 房满顺延下一号 =====
    bridge.enter_public = function(tag, maxPeers, maxRooms) {
        bridge.disconnect();
        bridge._gen++;
        bridge._maxPeers = maxPeers || 8;
        bridge._maxRooms = maxRooms || 20;
        bridge._pubTag = tag;
        bridge._pubIndex = 1;
        bridge._pubFlips = 0;
        bridge._isHost = false;
        bridge._status = 'joining';
        bridge._lastError = '';
        _tryJoinPublic(bridge._gen);
    };

    function _pubId(idx) { return 'teilaruia-PUB-' + bridge._pubTag + '-' + idx; }

    // 先以 client 身份连 idx 号房
    function _tryJoinPublic(gen) {
        if (gen !== bridge._gen) return;
        if (bridge._pubIndex > bridge._maxRooms) {
            bridge._lastError = '现在人太多啦, 等会儿再来';
            bridge._status = 'error';
            return;
        }
        var targetId = _pubId(bridge._pubIndex);
        try {
            bridge._peer = new Peer(null, _peerOpts());
        } catch (e) {
            bridge._lastError = 'PeerJS 没加载好, 刷新页面再试';
            bridge._status = 'error';
            return;
        }
        bridge._peer.on('open', function() {
            if (gen !== bridge._gen) return;
            var conn = bridge._peer.connect(targetId, { reliable: true });
            var settled = false;
            conn.on('open', function() {
                if (gen !== bridge._gen || settled) return;
                settled = true;
                bridge._isHost = false;
                bridge._hostConn = conn;
                bridge._pubFlips = 0;   // 连上 host = 稳了, 翻转计数清零
                _setupConn(conn, false);
                bridge._status = 'connected';
            });
            conn.on('data', function(d) {
                // 被房主拒绝 (房满) → 试下一号房
                try { if (JSON.parse(String(d)).__full) { settled = true; _nextRoom(gen); } } catch (e) {}
            });
            conn.on('error', function() {
                // 连不上这个房主 (ID 被占但连不通 = 幽灵房主/不可入). 能连早就 open 了 →
                // 别在这号房耗着翻转, 直接跳下一号房 (别人也这么跳 → 在干净的新号房汇合)。
                // 区分: 空房 = peer-unavailable(下面 peer.on error → 抢 host); 幽灵 = 这里 conn error → 换号。
                if (gen !== bridge._gen || settled) return;
                settled = true;
                _nextRoom(gen);
            });
            // 一段时间没连上 → 这号房可能没人开 → 去抢占当 host.
            // 注意: 房里"没人"会触发 peer-unavailable 错误 (走上面 on('error') 立刻抢 host),
            // 这个超时只兜底"信令慢/卡住"的情况. 免费信令服首次握手常 >5s, 太短会让第二个人
            // 误判"没人开房"→自己也去抢 host→落单 (= 用户报的"公共房只有一个人"). 放宽到 12s.
            // 首次进房等久点 (慢信令); 已经在抢号翻转中就等短点 (快速识破幽灵房主 → 早换号)
            var joinWait = (bridge._pubFlips > 0) ? CONTEST_JOIN_TIMEOUT_MS : JOIN_TIMEOUT_MS;
            setTimeout(function() {
                if (gen !== bridge._gen || settled) return;
                settled = true;
                try { bridge._peer.destroy(); } catch (e) {}
                _hostPublic(gen);
            }, joinWait);
        });
        bridge._peer.on('error', function(err) {
            if (gen !== bridge._gen) return;
            var et = err.type || err.message || err;
            if (et === 'peer-unavailable') {
                // 没人开这号房(或占用者刚注册还没好) → 退避后抢占当 host (不立刻, 防 ping-pong 刷屏)
                _flipPublic(gen, _hostPublic);
            } else if (_RETRYABLE[et]) {
                bridge._lastError = _friendlyError(et);   // 服务器忙, 保持 joining 等超时
            } else {
                bridge._lastError = _friendlyError(et);
                bridge._status = 'error';
            }
        });
    }

    // 抢占 idx 号房当 host
    function _hostPublic(gen) {
        if (gen !== bridge._gen) return;
        try {
            bridge._peer = new Peer(_pubId(bridge._pubIndex), _peerOpts());
        } catch (e) {
            bridge._lastError = 'PeerJS 没加载好, 刷新页面再试';
            bridge._status = 'error';
            return;
        }
        bridge._peer.on('open', function() {
            if (gen !== bridge._gen) return;
            bridge._isHost = true;
            bridge._myId = _pubId(bridge._pubIndex);
            bridge._pubFlips = 0;           // 当上 host = 稳了, 翻转计数清零
            bridge._status = 'connected';   // host 自己即"连上" (房里就他一个也能玩)
        });
        bridge._peer.on('connection', function(conn) { _onIncoming(conn, gen); });
        bridge._peer.on('error', function(err) {
            if (gen !== bridge._gen) return;
            var et = err.type || err.message || err;
            if (et === 'unavailable-id') {
                // 并发竞争: 别人刚抢到这号房 → 退避后退回当 client 再连它 (不立刻, 防 ping-pong)
                bridge._isHost = false;
                _flipPublic(gen, _tryJoinPublic);
            } else {
                bridge._lastError = _friendlyError(et);
                bridge._status = 'error';
            }
        });
    }

    function _nextRoom(gen) {
        if (gen !== bridge._gen) return;
        try { if (bridge._peer) bridge._peer.destroy(); } catch (e) {}
        bridge._pubIndex++;
        bridge._pubFlips = 0;   // 换了房号, 翻转计数重来
        _tryJoinPublic(gen);
    }

    // host↔client 翻转 (抢房竞态). 加随机退避打散两端 + 给 WebRTC 协商时间; 翻转太多 = 脑裂
    // (双方都连不上对方) → 退一格房号重来, 房号用完才报错。fn = _tryJoinPublic 或 _hostPublic。
    function _flipPublic(gen, fn) {
        if (gen !== bridge._gen) return;
        try { if (bridge._peer) bridge._peer.destroy(); } catch (e) {}
        bridge._pubFlips = (bridge._pubFlips || 0) + 1;
        if (bridge._pubFlips > MAX_PUB_FLIPS) {
            if (bridge._pubIndex < bridge._maxRooms) { _nextRoom(gen); return; }
            bridge._lastError = '连接不太稳, 刷新页面再进一次对战房';
            bridge._status = 'error';
            return;
        }
        var delay = 250 + Math.floor(Math.random() * 600);   // 退避 250~850ms, 打散同时抢的两端
        setTimeout(function() { if (gen === bridge._gen) fn(gen); }, delay);
    }

    // ===== 发送 =====
    bridge.send = function(jsonStr) {
        if (bridge._isHost) {
            var sent = false;
            for (var pid in bridge._conns) {
                var c = bridge._conns[pid];
                if (c && c.open) { c.send(jsonStr); sent = true; }
            }
            return sent;
        }
        if (bridge._hostConn && bridge._hostConn.open) {
            bridge._hostConn.send(jsonStr);
            return true;
        }
        return false;
    };

    bridge.send_to = function(peerId, jsonStr) {
        var c = bridge._conns[peerId];
        if (c && c.open) { c.send(jsonStr); return true; }
        return false;
    };

    // host 踢人: 先告诉那个 client "你被踢了", 稍后关掉它的连接.
    bridge.kick = function(peerId) {
        var c = bridge._conns[peerId];
        if (!c) return false;
        try { c.send(JSON.stringify({type: "__kicked"})); } catch (e) {}
        setTimeout(function() {
            try { c.close(); } catch (e) {}
            delete bridge._conns[peerId];
        }, 200);
        return true;
    };

    bridge.get_peer_ids = function() { return JSON.stringify(Object.keys(bridge._conns)); };
    bridge.get_peer_count = function() { return Object.keys(bridge._conns).length; };

    bridge.pop_messages = function() {
        var msgs = bridge._messages;
        bridge._messages = [];
        return JSON.stringify(msgs);
    };

    bridge.get_status = function() { return bridge._status; };
    bridge.get_my_id = function() { return bridge._myId; };
    bridge.get_last_error = function() { return bridge._lastError; };
    bridge.is_host = function() { return bridge._isHost; };

    bridge.disconnect = function() {
        bridge._gen = (bridge._gen || 0) + 1;   // 作废所有挂着的重试/超时回调
        for (var pid in bridge._conns) {
            try { bridge._conns[pid].close(); } catch (e) {}
        }
        bridge._conns = {};
        if (bridge._hostConn) { try { bridge._hostConn.close(); } catch (e) {} }
        bridge._hostConn = null;
        if (bridge._peer) {
            try { bridge._peer.destroy(); } catch (e) {}
        }
        bridge._peer = null;
        bridge._status = 'idle';
        bridge._myId = '';
        bridge._isHost = false;
        bridge._messages = [];
        bridge._lastError = '';
    };

    window.MultiplayerBridge = bridge;

    // 关页面/刷新/切后台时干净销毁 peer → 信令服务器立刻注销这个房主 ID。
    // 不这么做的话, 关标签页留下"幽灵房主": ID 还挂在服务器(别人当不了房主, 报 "ID is taken"),
    // 但人已经走了(连不上, 报 "Could not connect to peer") → 新玩家进不去房 (用户报)。
    function _cleanupPeer() {
        try { if (bridge._peer && !bridge._peer.destroyed) bridge._peer.destroy(); } catch (e) {}
    }
    window.addEventListener('beforeunload', _cleanupPeer);
    window.addEventListener('pagehide', _cleanupPeer);   // iOS Safari 不可靠触发 beforeunload, 用 pagehide 兜底

    // 保活: 网页开着时每 4 分钟戳一下信令服务器, 别让免费版睡着 (睡醒要 ~50s = "连不进").
    // no-cors + catch: 纯粹叫醒服务器, 不关心返回, 失败也不报错。
    if (PEER_HOST) {
        setInterval(function() {
            try {
                fetch('https://' + PEER_HOST + '/', {mode: 'no-cors', cache: 'no-store'}).catch(function() {});
            } catch (e) {}
        }, 240000);
    }

    console.log('[MultiplayerBridge] loaded');
})();
