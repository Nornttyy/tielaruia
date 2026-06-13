// 一次性"自杀" service worker。
// 背景: 本游戏曾开过 PWA (progressive_web_app/enabled=true), 后来关了。但老用户浏览器里
// 残留的那个旧 service worker 还活着, 一直想缓存已删的文件 → 控制台报
//   "Failed to execute 'addAll' on 'Cache'" + "index.manifest.json 404"。
// PWA 关了后 export 不再产生 SW 去替换它, 旧 SW 就成了"僵尸", 自己不会死。
// 部署时把这个文件放到老 SW 的 URL (index.service.worker.js): 浏览器做更新检查时抓到它 →
// 装上 → activate 时清掉所有缓存 + 注销自己 + 刷新页面。僵尸 SW 就死了, 之后干干净净 (无 SW)。
self.addEventListener('install', function () { self.skipWaiting(); });

self.addEventListener('activate', function (e) {
	e.waitUntil((async function () {
		try {
			var keys = await caches.keys();
			await Promise.all(keys.map(function (k) { return caches.delete(k); }));
		} catch (err) {}
		try { await self.registration.unregister(); } catch (err) {}
		try {
			var cs = await self.clients.matchAll();
			cs.forEach(function (c) { c.navigate(c.url); });
		} catch (err) {}
	})());
});

// 不拦截任何请求 — 一律走网络 (僵尸期间可能拦过, 这里彻底放行)。
self.addEventListener('fetch', function () {});
