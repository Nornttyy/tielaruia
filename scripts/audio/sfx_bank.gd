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


const GLOBAL_ATTEN_DB := -8.0  # 整体衰减, 避免音效刺耳


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


func _master_db() -> float:
	# GameSettings.master_volume ∈ [0, 1] → -60..0 dB
	var v: float = clampf(GameSettings.master_volume, 0.0, 1.0)
	if v <= 0.001:
		return -80.0
	return linear_to_db(v)


# ===== SFX 合成 =====

func _build_all() -> void:
	# 所有振幅压到 ~0.18 (原来 0.3-0.5), 频率下移 + 低通平滑, 避免刺耳
	# 跳: 上升 chirp, 频率降低
	_sfx["jump"] = _chirp(0.10, 240.0, 440.0, 0.18)
	# 落地"扑通"
	_sfx["land"] = _noise_thud(0.10, 0.20)
	# 挖完: 低通过滤后的噪声爆破
	_sfx["break"] = _noise_burst(0.14, 0.22, 0.85)
	# 放方块: 软"啪"
	_sfx["place"] = _noise_burst(0.06, 0.18, 0.3)
	# 捡物: chirp 频率降下来, 不那么尖
	_sfx["pickup"] = _chirp(0.13, 420.0, 660.0, 0.18)
	# 挥剑 swoosh: 低通后柔和很多
	_sfx["swing"] = _swoosh(0.11, 0.18)
	# 击中
	_sfx["hit"] = _thump(0.10, 150.0, 0.22)
	# 受伤: 改用 sine 下降 (sawtooth 太蜂鸣), 频率更低
	_sfx["hurt"] = _chirp(0.18, 200.0, 90.0, 0.20)
	# 吃东西: 单口柔噪声 + 低通
	_sfx["eat"] = _eat_chomp(0.18, 0.18)
	# 史莱姆跳 boing
	_sfx["slime_hop"] = _chirp(0.14, 240.0, 150.0, 0.15)


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


# 噪声 + 低频 sin 混合, 模拟落地"扑通". 加低通让声音更厚
func _noise_thud(duration: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	var prev := 0.0
	for i in samples:
		var t: float = float(i) / float(samples)
		phase += 100.0 * TAU / SAMPLE_RATE
		var env: float = 1.0 - t
		var noise: float = (randf() * 2.0 - 1.0) * 0.5
		var raw: float = (sin(phase) * 0.6 + noise * 0.4) * amp * env * env
		# 单极低通: 0.7 * 上帧 + 0.3 * 当前 → 削高频
		var s: float = prev * 0.7 + raw * 0.3
		prev = s
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 噪声爆破, 模拟挖碎方块. 加低通让噪声不那么"沙"
func _noise_burst(duration: float, amp: float, attack: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var attack_n: int = int(attack * SAMPLE_RATE * 0.02)
	var prev := 0.0
	for i in samples:
		var env: float
		if i < attack_n and attack_n > 0:
			env = float(i) / float(attack_n)
		else:
			env = 1.0 - (float(i - attack_n) / float(samples - attack_n))
			env = env * env
		var raw: float = (randf() * 2.0 - 1.0) * amp * env
		# 强低通: 0.8 * prev + 0.2 * raw → 浑厚不刺耳
		var s: float = prev * 0.8 + raw * 0.2
		prev = s
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 挥剑 swoosh: 噪声 + 低通让 swoosh 不再刺耳
func _swoosh(duration: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var prev := 0.0
	for i in samples:
		var t: float = float(i) / float(samples)
		var env: float = sin(t * PI)
		var noise: float = (randf() * 2.0 - 1.0)
		var raw: float = noise * amp * env
		var s: float = prev * 0.75 + raw * 0.25
		prev = s
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 击中: 短低频 + 低通噪声
func _thump(duration: float, base_freq: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	var prev := 0.0
	for i in samples:
		var t: float = float(i) / float(samples)
		phase += base_freq * TAU / SAMPLE_RATE
		var env: float = 1.0 - t
		env = env * env
		var sine_s: float = sin(phase)
		var noise: float = (randf() * 2.0 - 1.0) * 0.3
		var raw: float = (sine_s * 0.7 + noise * 0.3) * amp * env
		var s: float = prev * 0.7 + raw * 0.3
		prev = s
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 吃东西: 2 次柔咬 (低通后柔和很多)
func _eat_chomp(duration: float, amp: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var prev := 0.0
	for i in samples:
		var t: float = float(i) / float(samples)
		var env: float = 0.0
		for bite_t in [0.0, 0.45]:
			var d: float = t - bite_t
			if d >= 0.0 and d < 0.15:
				var be: float = 1.0 - d / 0.15
				env = max(env, be * be)
		var noise: float = (randf() * 2.0 - 1.0)
		var raw: float = noise * amp * env
		var s: float = prev * 0.8 + raw * 0.2
		prev = s
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
