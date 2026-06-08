// teilaruia 私人 PeerJS 信令服务器。
// 作用: 帮两个玩家"牵线"交换连接信息 (WebRTC 信令), 之后两人直接 P2P 传游戏数据。
// 只给自己人用 → 不像公共服务器那样被全世界蹭, 所以稳。
//
// 部署: 挂到 Render 免费 Web Service (见 docs/multiplayer-server-setup.md)。
// Render 会自动设环境变量 PORT, 我们监听它即可。
//
// 客户端 (peerjs_bridge.js) 这样连:
//   new Peer(id, { host: "<你的域名>.onrender.com", port: 443, secure: true, path: "/peerjs" })

const express = require("express");
const { ExpressPeerServer } = require("peer");

const app = express();

// 健康检查页: Render 会定时访问 "/" 确认服务活着; 浏览器打开也能看到这行字 = 部署成功。
app.get("/", function (req, res) {
	res.send("teilaruia peer server OK ✓");
});

const port = process.env.PORT || 9000;
const server = app.listen(port, function () {
	console.log("teilaruia peer server listening on port " + port);
});

// PeerJS 信令挂在 /peerjs 路径 (客户端 path 要一致)。
const peerServer = ExpressPeerServer(server, {
	path: "/",
});
app.use("/peerjs", peerServer);

peerServer.on("connection", function (client) {
	console.log("peer 上线:", client.getId());
});
peerServer.on("disconnect", function (client) {
	console.log("peer 下线:", client.getId());
});
