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


// 移动端: 把 canvas DPR 上限设为 2 (不是压到 1). 让手机画面恢复高清, 又给内存设上限。
// iPhone DPR=3 → backing store 9x 纹理内存会崩; 但压到 1 又太糊 (用户: 不能降质量)。
// 折中 cap 2: 4x 内存 (远低于 9x), 画面 2 倍清晰 (肉眼跟 3 倍几乎无差)。
// 必须在 Godot wasm load 之前注入 (head 顶部) 才生效, 不然 Godot 已读 DPR.
(function() {
	var MAX_DPR = 2.0;   // 手机最高 2 倍渲染 (高清 + 内存有上限)
	// 仅 mobile / 小屏幕限 DPR. 桌面浏览器保留全 Retina (不限)。
	function isMobile() {
		if (/iPhone|iPad|iPod|Android|Mobile/i.test(navigator.userAgent)) return true;
		if (window.innerWidth < 1000) return true;
		return false;
	}
	if (!isMobile()) return;
	var orig = window.devicePixelRatio || 1;
	if (orig <= MAX_DPR) return;   // 本来就 ≤2, 不用动 (保持高清)
	try {
		Object.defineProperty(window, 'devicePixelRatio', {
			get: function () { return MAX_DPR; },
			configurable: true
		});
		console.log('[mobile_opt] devicePixelRatio ' + orig + ' → capped ' + MAX_DPR + ' (高清+内存上限)');
	} catch (e) {
		console.warn('[mobile_opt] failed to cap DPR:', e);
	}
})();
