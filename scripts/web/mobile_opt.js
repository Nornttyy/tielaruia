// 卸载残留 service worker + 清旧缓存。
// 之前开过 PWA (现已关), 但关 PWA 不会自动卸载浏览器里已注册的旧 SW → 它继续按旧文件列表
// cache.addAll → 报 "Failed to execute 'addAll' on 'Cache': Request failed" (用户报)。
// 主动卸载所有 SW + 删所有缓存, 跑一次就干净 (全平台, 桌面也跑)。
(function() {
	if (!('serviceWorker' in navigator)) return;
	try {
		navigator.serviceWorker.getRegistrations().then(function(regs) {
			regs.forEach(function(r) { try { r.unregister(); } catch (e) {} });
		}).catch(function() {});
	} catch (e) {}
	try {
		if (window.caches && caches.keys) {
			caches.keys().then(function(keys) {
				keys.forEach(function(k) { try { caches.delete(k); } catch (e) {} });
			}).catch(function() {});
		}
	} catch (e) {}
})();


// 移动端内存优化: 把 canvas DPR 强制为 1, 省 iOS Safari WebGL 内存.
// iPhone DPR=3 → canvas backing store 9x 纹理内存. 像素游戏 (本身就 1:N 放大) 无视觉损失.
// 必须在 Godot wasm load 之前注入 (head 顶部) 才生效, 不然 Godot 已读 DPR.
(function() {
	// 仅 mobile / 小屏幕降 DPR. 桌面浏览器保留高 DPR (Retina).
	function shouldCapDPR() {
		// 1. UA 中含 Mobile 类标识
		if (/iPhone|iPad|iPod|Android|Mobile/i.test(navigator.userAgent)) return true;
		// 2. 视口窄
		if (window.innerWidth < 1000) return true;
		return false;
	}
	if (!shouldCapDPR()) return;
	// 覆写 devicePixelRatio. Godot 在 init canvas 时会读这个值算 backing store 大小.
	try {
		Object.defineProperty(window, 'devicePixelRatio', {
			get: function () { return 1; },
			configurable: true
		});
		console.log('[mobile_opt] devicePixelRatio capped to 1 (orig ' +
			(window.screen && window.screen.systemDPR || 'unknown') + ') — saves WebGL memory on iOS Safari');
	} catch (e) {
		console.warn('[mobile_opt] failed to cap DPR:', e);
	}
})();
