# 程序生成 SFX (autoload). 启动时合成所有音效为 AudioStreamWAV.
# 用法: SfxBank.play("jump") / SfxBank.play("break", 0.15)
#
# 设计原则:
#   - 频率压低 (80-250 Hz 主导), 避免高频刺耳
#   - 白噪声 → 棕噪声 (低频为主, 像"沙土感"而非"嘶"声)
#   - 多级低通 (3 阶) 让声音"厚"
#   - 慢 attack 消除起始 click
#   - sine + 噪声混合, 不用 sawtooth/square
extends Node

const SAMPLE_RATE := 22050
const POOL_SIZE := 8
const GLOBAL_ATTEN_DB := -4.0

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_all()


func play(sfx_name: String, pitch_variation: float = 0.05, volume_db: float = 0.0) -> void:
	var s: AudioStreamWAV = _sfx.get(sfx_name)
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = clampf(1.0 + randf_range(-pitch_variation, pitch_variation), 0.5, 2.0)
			p.volume_db = volume_db + _master_db() + GLOBAL_ATTEN_DB
			p.play()
			return


# 空间音效: 按距离衰减. world_pos 是发声体世界坐标; max_dist 像素 (一般 240 = 15 tile);
# 超过 max_dist 直接不播; 二次衰减 (近处饱满, 远处快速变小).
func play_at(sfx_name: String, world_pos: Vector2, max_dist: float = 240.0,
		pitch_variation: float = 0.05) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var dist: float = (player.global_position as Vector2).distance_to(world_pos)
	if dist > max_dist:
		return
	var factor: float = 1.0 - (dist / max_dist)
	factor = factor * factor  # 二次衰减
	var atten_db: float = linear_to_db(maxf(factor, 0.001))
	play(sfx_name, pitch_variation, atten_db)


func _master_db() -> float:
	var v: float = clampf(GameSettings.master_volume, 0.0, 1.0)
	if v <= 0.001:
		return -80.0
	return linear_to_db(v)


# ===== 音效合成 =====

func _build_all() -> void:
	# 挖完: 低沉"咚", 不是噪声爆破. 80Hz sine + 棕噪声短爆
	_sfx["break"] = _thunk(0.18, 75.0, 0.35)
	# 放方块: 比挖更短更清脆, 120Hz
	_sfx["place"] = _thunk(0.10, 130.0, 0.30)
	# 跳: 短促 whoosh, 棕噪声 + 上升 LFO 调制
	_sfx["jump"] = _whoosh(0.12, 200.0, 350.0, 0.25)
	# 落地: 厚实 thud, 60Hz 主导
	_sfx["land"] = _thunk(0.13, 55.0, 0.35)
	# 捡物: 人类啵嘴 — 极短气流噪声爆破 + 腔体共鸣 sine 下滑
	_sfx["pickup"] = _lip_pop(0.32)
	# 挥剑: 短 whoosh 下降
	_sfx["swing"] = _whoosh(0.13, 350.0, 150.0, 0.22)
	# 击中: 低频 thud + 短噪声
	_sfx["hit"] = _thunk(0.14, 90.0, 0.32)
	# 受伤: 低 sine 短下滑 + 厚低通
	_sfx["hurt"] = _moan(0.22, 220.0, 110.0, 0.25)
	# 吃: 2 次低噪声咬, 强低通
	_sfx["eat"] = _chomp(0.20, 0.22)
	# 史莱姆跳: 弹性"boing", 200→130 chirp, 加抖动
	# 史莱姆跳: 湿润胶体"波丁" — 棕噪声 splat + 低 sine 下沉, 三阶低通超湿
	_sfx["slime_hop"] = _glop(0.30)


# 棕色噪声生成器: 每次返回积分的随机值, 频谱偏低频. -1..1 范围.
class BrownNoise:
	var _state: float = 0.0
	func sample() -> float:
		_state = clampf(_state * 0.95 + (randf() * 2.0 - 1.0) * 0.1, -1.0, 1.0)
		return _state


# 多级单极低通: 调用 N 次单极得到 N 阶低通, 削高频更狠
func _lpf(prev: float, raw: float, alpha: float) -> float:
	return prev * (1.0 - alpha) + raw * alpha


# 低沉敲击: 短 sine 主体 + 棕噪声短爆 + 厚低通. 用于 break/place/land/hit.
func _thunk(duration: float, base_freq: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	var bn := BrownNoise.new()
	var lp1 := 0.0
	var lp2 := 0.0
	# 慢 attack 5ms 消 click
	var attack_n: int = int(0.005 * SAMPLE_RATE)
	for i in samples:
		var t: float = float(i) / float(samples)
		# sine 主体降频 (敲击的"实心感")
		var freq: float = base_freq * (1.0 - t * 0.4)
		phase += freq * TAU / SAMPLE_RATE
		var env: float
		if i < attack_n:
			env = float(i) / float(attack_n)
		else:
			env = 1.0 - t
			env = env * env  # 指数衰减
		var sine_s: float = sin(phase) * 0.7
		var noise_s: float = bn.sample() * 0.4  # 棕噪声给"质感"
		var raw: float = (sine_s + noise_s) * amp * env
		# 2 阶低通
		lp1 = _lpf(lp1, raw, 0.4)
		lp2 = _lpf(lp2, lp1, 0.4)
		_write_sample(data, i, lp2)
	return _wrap_stream(data)


# Whoosh: 棕噪声 + 频率扫描调制 (虚拟扫频, 噪声本身就低频)
func _whoosh(duration: float, _f0: float, _f1: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var bn := BrownNoise.new()
	var lp1 := 0.0
	var lp2 := 0.0
	for i in samples:
		var t: float = float(i) / float(samples)
		var env: float = sin(t * PI)  # 钟形 (柔起柔收)
		var noise_s: float = bn.sample()
		var raw: float = noise_s * amp * env
		lp1 = _lpf(lp1, raw, 0.5)
		lp2 = _lpf(lp2, lp1, 0.5)
		_write_sample(data, i, lp2)
	return _wrap_stream(data)


# 铃声: 基频 + 八度倍频, 缓慢衰减, 弱低通保留一些泛音
func _bell(duration: float, base_freq: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var ph1 := 0.0
	var ph2 := 0.0
	var lp1 := 0.0
	var attack_n: int = int(0.008 * SAMPLE_RATE)
	for i in samples:
		var t: float = float(i) / float(samples)
		ph1 += base_freq * TAU / SAMPLE_RATE
		ph2 += base_freq * 2.0 * TAU / SAMPLE_RATE
		var env: float
		if i < attack_n:
			env = float(i) / float(attack_n)
		else:
			env = 1.0 - t * 0.9
		var raw: float = (sin(ph1) * 0.7 + sin(ph2) * 0.3) * amp * env
		lp1 = _lpf(lp1, raw, 0.6)
		_write_sample(data, i, lp1)
	return _wrap_stream(data)


# 呻吟: sine 下降, 厚低通
func _moan(duration: float, f0: float, f1: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	var lp1 := 0.0
	var lp2 := 0.0
	var attack_n: int = int(0.01 * SAMPLE_RATE)
	for i in samples:
		var t: float = float(i) / float(samples)
		var freq: float = lerp(f0, f1, t)
		phase += freq * TAU / SAMPLE_RATE
		var env: float
		if i < attack_n:
			env = float(i) / float(attack_n)
		else:
			env = 1.0 - t * 0.85
		var raw: float = sin(phase) * amp * env
		lp1 = _lpf(lp1, raw, 0.4)
		lp2 = _lpf(lp2, lp1, 0.4)
		_write_sample(data, i, lp2)
	return _wrap_stream(data)


# 吃: 2 次低棕噪声咬, 强低通
func _chomp(duration: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var bn := BrownNoise.new()
	var lp1 := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	for i in samples:
		var t: float = float(i) / float(samples)
		var env: float = 0.0
		for bite_t in [0.0, 0.5]:
			var d: float = t - bite_t
			if d >= 0.0 and d < 0.15:
				var be: float = 1.0 - d / 0.15
				env = max(env, be * be)
		var noise_s: float = bn.sample()
		var raw: float = noise_s * amp * env
		# 3 阶低通超厚
		lp1 = _lpf(lp1, raw, 0.3)
		lp2 = _lpf(lp2, lp1, 0.3)
		lp3 = _lpf(lp3, lp2, 0.3)
		_write_sample(data, i, lp3)
	return _wrap_stream(data)


# 啵嘴: 极短气流爆破 + 腔体下沉
#   - 前 6ms 强噪声 (双唇分开瞬间的气流), 厚低通让它"湿"
#   - 整体 50ms, sine 320→160Hz 下滑 (口腔共鸣), 锐衰减
#   - 强随机变调 (调用时 ±20%) 让每次都不一样
func _lip_pop(amp: float) -> AudioStreamWAV:
	var duration: float = 0.05
	var samples: int = int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase: float = 0.0
	var bn := BrownNoise.new()
	var lp1: float = 0.0
	var lp2: float = 0.0
	var attack_n: int = int(0.0008 * SAMPLE_RATE)  # 0.8ms 超快 attack 给清脆"啵"感
	var burst_n: int = int(0.006 * SAMPLE_RATE)    # 6ms 气流噪声爆破
	for i in samples:
		var t: float = float(i) / float(samples)
		# 320→160 Hz sine 下滑, 模拟口腔共鸣往下收
		var freq: float = lerp(320.0, 160.0, t)
		phase += freq * TAU / SAMPLE_RATE
		var env: float
		if i < attack_n:
			env = float(i) / float(attack_n)
		else:
			var n: float = float(i - attack_n) / float(samples - attack_n)
			env = pow(1.0 - n, 4.0)  # 四次方锐衰减
		# 气流噪声 (只在前 6ms)
		var noise_env: float = 0.0
		if i < burst_n:
			var ne: float = 1.0 - float(i) / float(burst_n)
			noise_env = ne * ne
		var sine_s: float = sin(phase) * 0.55
		var noise_s: float = bn.sample() * 0.6 * noise_env
		var raw: float = (sine_s + noise_s) * amp * env
		# 双低通 → "湿"感
		lp1 = _lpf(lp1, raw, 0.5)
		lp2 = _lpf(lp2, lp1, 0.5)
		_write_sample(data, i, lp2)
	return _wrap_stream(data)


# 史莱姆 boing: chirp 下降 + 轻微 vibrato + 低通
func _boing(duration: float, f0: float, f1: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	var lp1 := 0.0
	var attack_n: int = int(0.008 * SAMPLE_RATE)
	for i in samples:
		var t: float = float(i) / float(samples)
		# 加 vibrato (6Hz, ±10%) 让它"弹"
		var vib: float = 1.0 + sin(t * TAU * 6.0) * 0.10
		var freq: float = lerp(f0, f1, t) * vib
		phase += freq * TAU / SAMPLE_RATE
		var env: float
		if i < attack_n:
			env = float(i) / float(attack_n)
		else:
			env = 1.0 - t
			env = env * env
		var raw: float = sin(phase) * amp * env
		lp1 = _lpf(lp1, raw, 0.5)
		_write_sample(data, i, lp1)
	return _wrap_stream(data)


# 史莱姆"波丁": 胶体落地, 有湿渎但听得清是个"音"
#   - 前 8ms 棕噪声爆破 (胶体落地"啪嗒")
#   - 整体 110ms, sine 320→180Hz 下沉 (中频, 耳朵能识别音高)
#   - 2 阶低通 alpha=0.5 (轻一点保留质感)
func _glop(amp: float) -> AudioStreamWAV:
	var duration: float = 0.11
	var samples: int = int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase: float = 0.0
	var bn := BrownNoise.new()
	var lp1: float = 0.0
	var lp2: float = 0.0
	var attack_n: int = int(0.002 * SAMPLE_RATE)
	var burst_n: int = int(0.008 * SAMPLE_RATE)
	for i in samples:
		var t: float = float(i) / float(samples)
		var freq: float = lerp(320.0, 180.0, t)
		phase += freq * TAU / SAMPLE_RATE
		var env: float
		if i < attack_n:
			env = float(i) / float(attack_n)
		else:
			var n: float = float(i - attack_n) / float(samples - attack_n)
			env = pow(1.0 - n, 2.5)
		var noise_env: float = 0.0
		if i < burst_n:
			var ne: float = 1.0 - float(i) / float(burst_n)
			noise_env = ne * ne
		var sine_s: float = sin(phase) * 0.65   # sine 主导, 突出音高
		var noise_s: float = bn.sample() * 0.45 * noise_env
		var raw: float = (sine_s + noise_s) * amp * env
		# 2 阶低通 (alpha 拉大, 高频留更多)
		lp1 = _lpf(lp1, raw, 0.5)
		lp2 = _lpf(lp2, lp1, 0.5)
		_write_sample(data, i, lp2)
	return _wrap_stream(data)


func _write_sample(data: PackedByteArray, idx: int, sample: float) -> void:
	var v: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
	if v < 0:
		v += 65536
	data[idx * 2] = v & 0xFF
	data[idx * 2 + 1] = (v >> 8) & 0xFF


func _wrap_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
