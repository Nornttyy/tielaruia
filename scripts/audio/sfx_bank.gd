# 程序生成的音效库 (autoload). 启动时合成所有 SFX 为 AudioStreamWAV.
# 用法: SfxBank.play("jump") / SfxBank.play("break", 0.15) (0.15 = ±15% 随机变调)
# 内部维护 8 个 AudioStreamPlayer 池, 允许多个音效同时播放.
extends Node

const SAMPLE_RATE := 22050
const POOL_SIZE := 8

var _sfx: Dictionary = {}            # name → AudioStreamWAV
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
			p.volume_db = volume_db + _master_db()
			p.play()
			return


func _master_db() -> float:
	# GameSettings.master_volume ∈ [0, 1] → -60..0 dB
	var v: float = clampf(GameSettings.master_volume, 0.0, 1.0)
	if v <= 0.001:
		return -80.0
	return linear_to_db(v)


# ===== SFX 合成 =====

func _build_all() -> void:
	# 跳: 短促上升 chirp
	_sfx["jump"] = _chirp(0.10, 320.0, 600.0, 0.35)
	# 落地 / 走路扑通: 低频 + 噪声衰减
	_sfx["land"] = _noise_thud(0.08, 0.4)
	# 挖完 (方块碎): 中频噪声爆破
	_sfx["break"] = _noise_burst(0.12, 0.5, 0.85)
	# 放方块: 短 "啪" 木块感, 用窄带噪声
	_sfx["place"] = _noise_burst(0.06, 0.4, 0.3)
	# 捡物: 上升正弦 + 高音 ding
	_sfx["pickup"] = _chirp(0.12, 600.0, 980.0, 0.30)
	# 挥剑: 短促 swoosh, 噪声扫频
	_sfx["swing"] = _swoosh(0.10, 0.35)
	# 击中怪: 闷打
	_sfx["hit"] = _thump(0.10, 180.0, 0.45)
	# 玩家受击: 低沉 ouch, sawtooth-like
	_sfx["hurt"] = _saw_decay(0.18, 220.0, 90.0, 0.40)
	# 吃东西: 多次小噪声咬
	_sfx["eat"] = _eat_chomp(0.18, 0.35)
	# 史莱姆跳: 弹性 boing
	_sfx["slime_hop"] = _chirp(0.13, 280.0, 180.0, 0.28)


# 频率从 f0 chirp 到 f1, sine 波, 指数 amplitude 衰减
func _chirp(duration: float, f0: float, f1: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in samples:
		var t: float = float(i) / float(samples)
		var freq: float = lerp(f0, f1, t)
		phase += freq * TAU / SAMPLE_RATE
		var env: float = 1.0 - t
		env = env * env  # 指数衰减
		var s: float = sin(phase) * amp * env
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 噪声 + 低频 sin 混合, 模拟落地"扑通"
func _noise_thud(duration: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in samples:
		var t: float = float(i) / float(samples)
		phase += 120.0 * TAU / SAMPLE_RATE
		var env: float = 1.0 - t
		var noise: float = (randf() * 2.0 - 1.0) * 0.6
		var s: float = (sin(phase) * 0.5 + noise * 0.5) * amp * env * env
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 噪声爆破, 模拟挖碎方块
func _noise_burst(duration: float, amp: float, attack: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var attack_n: int = int(attack * SAMPLE_RATE * 0.02)  # 短 attack ramp
	for i in samples:
		var t: float = float(i) / float(samples)
		var env: float
		if i < attack_n and attack_n > 0:
			env = float(i) / float(attack_n)
		else:
			env = 1.0 - (float(i - attack_n) / float(samples - attack_n))
			env = env * env
		var s: float = (randf() * 2.0 - 1.0) * amp * env
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 挥剑 swoosh: 高频噪声扫低
func _swoosh(duration: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t: float = float(i) / float(samples)
		var env: float = sin(t * PI)  # 钟形 envelope
		# "扫频"通过噪声混合一个降频 sine 实现, 总体偏高频感
		var freq: float = lerp(800.0, 200.0, t)
		var sine_part: float = sin(t * freq * 0.02)
		var noise: float = (randf() * 2.0 - 1.0)
		var s: float = (noise * 0.7 + sine_part * 0.3) * amp * env
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 击中: 短低频 + 噪声
func _thump(duration: float, base_freq: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in samples:
		var t: float = float(i) / float(samples)
		phase += base_freq * TAU / SAMPLE_RATE
		var env: float = 1.0 - t
		env = env * env
		var sine_s: float = sin(phase)
		var noise: float = (randf() * 2.0 - 1.0) * 0.4
		var s: float = (sine_s * 0.6 + noise * 0.4) * amp * env
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 受伤 ouch: 锯齿波 chirp 下降
func _saw_decay(duration: float, f0: float, f1: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in samples:
		var t: float = float(i) / float(samples)
		var freq: float = lerp(f0, f1, t)
		phase += freq * TAU / SAMPLE_RATE
		# 锯齿 = phase 取小数 *2-1
		var ph_norm: float = fmod(phase / TAU, 1.0)
		var saw: float = ph_norm * 2.0 - 1.0
		var env: float = 1.0 - t * 0.7
		var s: float = saw * amp * env
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 吃东西: 3 次短噪声咬
func _eat_chomp(duration: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t: float = float(i) / float(samples)
		# 3 个咬, 在 t = 0.0, 0.4, 0.7 处
		var env: float = 0.0
		for bite_t in [0.0, 0.4, 0.7]:
			var d: float = t - bite_t
			if d >= 0.0 and d < 0.12:
				var be: float = 1.0 - d / 0.12
				env = max(env, be * be)
		var noise: float = (randf() * 2.0 - 1.0)
		var s: float = noise * amp * env
		_write_sample(data, i, s)
	return _wrap_stream(data)


func _write_sample(data: PackedByteArray, idx: int, sample: float) -> void:
	var v: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
	if v < 0:
		v += 65536  # 二进制补码
	data[idx * 2] = v & 0xFF
	data[idx * 2 + 1] = (v >> 8) & 0xFF


func _wrap_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
