# 程序生成背景音乐和环境声 (autoload).
#
# 用法:
#   MusicBank.set_context("day" / "night" / "cave")
#   切换有 1s crossfade.
#
# 设计:
#   - 3 首 chiptune 循环 (sine + pentatonic), ~10s 一首
#   - 3 种环境声层 (wind 永远, cricket 夜, drip 地下), 独立循环 + 独立音量
#   - 双 BGM player (A/B) 实现淡入淡出, 不会硬切
extends Node

const SAMPLE_RATE := 22050
const TAU_F := TAU
const BGM_FADE_SEC := 1.0
const BGM_VOLUME_DB := -30.0      # BGM ~3% 响度, 用户偏好背景音几乎听不到但有就好
const AMBIENT_VOLUME_DB := -30.0  # 环境声跟 BGM 同档
const DB_SILENT := -80.0

# 五声音阶频率 (Hz)
const C2 := 65.41
const G2 := 98.00
const F2 := 87.31
const A2 := 110.0
const E2 := 82.41
const C4 := 261.63
const D4 := 293.66
const E4 := 329.63
const G4 := 392.00
const A4 := 440.00

var _tracks: Dictionary = {}    # name -> AudioStreamWAV
var _ambient: Dictionary = {}   # name -> AudioStreamWAV
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _ambient_wind: AudioStreamPlayer
var _ambient_cricket: AudioStreamPlayer
var _ambient_drip: AudioStreamPlayer
var _current_track: String = ""
var _active_bgm: AudioStreamPlayer
var _fade_t: float = 0.0
var _fading: bool = false
# BGM 目标音量缓存, 避免每帧重算
var _bgm_target_db: float = 0.0
# 环境声目标音量 (lerp 用)
var _amb_target_wind: float = DB_SILENT
var _amb_target_cricket: float = DB_SILENT
var _amb_target_drip: float = DB_SILENT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[MusicBank] _ready 开始合成 (master_volume=", GameSettings.master_volume, ")")
	# 合成所有曲目
	_tracks["day"] = _build_day_track()
	_tracks["night"] = _build_night_track()
	_tracks["cave"] = _build_cave_track()
	print("[MusicBank] 3 首音乐合成完 day=", _tracks["day"].data.size(), " bytes")
	_ambient["wind"] = _build_wind(8.0)
	_ambient["cricket"] = _build_cricket(8.0)
	_ambient["drip"] = _build_drip(10.0)
	print("[MusicBank] 3 种环境声合成完")
	# 双 BGM player 给 crossfade 用
	_bgm_a = _new_loop_player()
	_bgm_b = _new_loop_player()
	_active_bgm = _bgm_a
	# 环境声常驻播放
	_ambient_wind = _new_loop_player()
	_ambient_cricket = _new_loop_player()
	_ambient_drip = _new_loop_player()
	_ambient_wind.stream = _ambient["wind"]
	_ambient_cricket.stream = _ambient["cricket"]
	_ambient_drip.stream = _ambient["drip"]
	_ambient_wind.volume_db = DB_SILENT
	_ambient_cricket.volume_db = DB_SILENT
	_ambient_drip.volume_db = DB_SILENT
	_ambient_wind.play()
	_ambient_cricket.play()
	_ambient_drip.play()
	print("[MusicBank] 5 个 player 创建+ambient 已 play (volume=-80)")
	# 第一首 (day) 不做 fade, 直接到 target — 进游戏立刻有音乐
	_play_initial_track("day")
	print("[MusicBank] day track 已启动, bgm.playing=", _active_bgm.playing,
		" volume_db=", _active_bgm.volume_db, " target=", _bgm_target_db)


func _process(delta: float) -> void:
	# BGM crossfade lerp
	if _fading:
		_fade_t = clamp(_fade_t + delta / BGM_FADE_SEC, 0.0, 1.0)
		var fade_in: AudioStreamPlayer = _active_bgm
		var fade_out: AudioStreamPlayer = _bgm_b if _active_bgm == _bgm_a else _bgm_a
		fade_in.volume_db = lerp(DB_SILENT, _bgm_target_db, _fade_t)
		fade_out.volume_db = lerp(_bgm_target_db, DB_SILENT, _fade_t)
		if _fade_t >= 1.0:
			_fading = false
			fade_out.stop()
	# 环境声 lerp 跟随 target (每帧逼近, 1s 内基本到位)
	var step: float = clamp(delta * 3.0, 0.0, 1.0)
	_ambient_wind.volume_db = lerp(_ambient_wind.volume_db, _amb_target_wind, step)
	_ambient_cricket.volume_db = lerp(_ambient_cricket.volume_db, _amb_target_cricket, step)
	_ambient_drip.volume_db = lerp(_ambient_drip.volume_db, _amb_target_drip, step)


# 进游戏第一次播 (没 fade, 直接到目标音量)
func _play_initial_track(ctx: String) -> void:
	_current_track = ctx
	var stream: AudioStreamWAV = _tracks.get(ctx)
	if stream == null:
		return
	_bgm_target_db = BGM_VOLUME_DB + _master_db()
	_active_bgm.stream = stream
	_active_bgm.volume_db = _bgm_target_db
	_active_bgm.play()
	_update_ambient_targets(ctx)


# 切换场景音乐. 合法值: "day" / "night" / "cave"
func set_context(ctx: String) -> void:
	_update_ambient_targets(ctx)
	if ctx == _current_track:
		return
	_current_track = ctx
	var stream: AudioStreamWAV = _tracks.get(ctx)
	if stream == null:
		return
	# 把新曲目装到非 active 的 player, 启动 crossfade
	var incoming: AudioStreamPlayer = _bgm_b if _active_bgm == _bgm_a else _bgm_a
	incoming.stream = stream
	incoming.volume_db = DB_SILENT
	incoming.play()
	_active_bgm = incoming
	_bgm_target_db = BGM_VOLUME_DB + _master_db()
	_fade_t = 0.0
	_fading = true


func _update_ambient_targets(ctx: String) -> void:
	var amb_db: float = AMBIENT_VOLUME_DB + _master_db()
	match ctx:
		"day":
			_amb_target_wind = amb_db
			_amb_target_cricket = DB_SILENT
			_amb_target_drip = DB_SILENT
		"night":
			_amb_target_wind = amb_db - 4.0
			_amb_target_cricket = amb_db
			_amb_target_drip = DB_SILENT
		"cave":
			_amb_target_wind = DB_SILENT
			_amb_target_cricket = DB_SILENT
			_amb_target_drip = amb_db


func _new_loop_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p


func _master_db() -> float:
	var v: float = clampf(GameSettings.master_volume, 0.0, 1.0)
	if v <= 0.001:
		return -80.0
	return linear_to_db(v)


# ===== 音乐合成 =====

# 白天: C 大调五声, 100 BPM, 4 小节循环 (~9.6s)
# Bass: C-C-G-G-F-F-G-G (低音根音)  Lead: 简单上行 + 下行
func _build_day_track() -> AudioStreamWAV:
	var bpm: float = 100.0
	var beat: float = 60.0 / bpm  # 0.6s
	var bass_notes: Array = [
		[C2, 2], [C2, 2], [G2, 2], [G2, 2],
		[F2, 2], [F2, 2], [G2, 2], [G2, 2],
	]  # 总 16 拍
	var lead_notes: Array = [
		[E4, 1], [G4, 1], [E4, 0.5], [D4, 0.5], [C4, 1], [E4, 1],
		[G4, 2], [A4, 1], [G4, 1],
		[E4, 1], [D4, 1], [E4, 2], [C4, 2],
	]  # 总 16 拍
	var total_sec: float = 16.0 * beat
	return _mix_two_tracks(bass_notes, lead_notes, beat, total_sec, 0.35, 0.25)


# 夜晚: A 小调五声, 70 BPM, 4 小节循环 (~13.7s)
# Bass: 慢长音 A-A-E-E  Lead: 稀疏点缀
func _build_night_track() -> AudioStreamWAV:
	var bpm: float = 70.0
	var beat: float = 60.0 / bpm
	var bass_notes: Array = [
		[A2, 4], [A2, 4], [E2, 4], [E2, 4],
	]
	var lead_notes: Array = [
		[A4, 2], [0.0, 2], [E4, 1], [G4, 1], [A4, 2],
		[G4, 2], [0.0, 2], [E4, 2], [A4, 2],
	]
	var total_sec: float = 16.0 * beat
	return _mix_two_tracks(bass_notes, lead_notes, beat, total_sec, 0.30, 0.18)


# 地下: 柔和五度 drone (A2+E2, 协和) + 偶尔轻柔的高八度 chime, 16s 长循环.
# 设计原则: 不刺耳 (无尖锐高频), 不压抑 (协和音程), 留白多 (chime 6s 一次).
func _build_cave_track() -> AudioStreamWAV:
	var duration: float = 16.0
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var ph_root := 0.0   # A2 = 110Hz, 主音
	var ph_fifth := 0.0  # E3 = 164.8Hz, 五度 (协和), 不用 90Hz 不和谐
	var ph_lfo := 0.0    # 缓慢 LFO 让 drone 有呼吸感
	# Chime 时间点: 6s 一次, 错开
	var chime_times: PackedFloat32Array = [2.0, 8.0, 13.5]
	# Chime 用 A4 (440Hz) 跟 drone 八度协和, sine 主导 + 慢 attack 不锐
	var chime_freq: float = 440.0
	var chime_dur: float = 2.0  # 2 秒 chime 长尾, 像水滴在洞里回响
	for i in samples:
		var t: float = float(i) / float(samples)
		var ts: float = t * duration
		ph_root += 110.0 * TAU_F / SAMPLE_RATE
		ph_fifth += 164.8 * TAU_F / SAMPLE_RATE
		ph_lfo += 0.15 * TAU_F / SAMPLE_RATE  # 0.15 Hz 呼吸
		var breath: float = 0.7 + 0.3 * sin(ph_lfo)  # 0.4..1.0 起伏
		# 主 drone: A2 + 弱 E3, sine 干净
		var drone_s: float = (sin(ph_root) * 0.30 + sin(ph_fifth) * 0.18) * breath
		# Chime: 慢 attack (50ms) + 长 release (1.5s 衰减), 八度协和不刺耳
		var chime_s: float = 0.0
		for ct in chime_times:
			var dt: float = ts - ct
			if dt >= 0.0 and dt < chime_dur:
				var env: float
				if dt < 0.05:
					env = dt / 0.05  # 50ms attack
				else:
					var n: float = (dt - 0.05) / (chime_dur - 0.05)
					env = pow(1.0 - n, 2.0)  # 缓慢平方衰减
				chime_s += sin(dt * chime_freq * TAU_F) * env * 0.18
		var raw: float = drone_s + chime_s
		# 循环边界淡入淡出
		if t < 0.05:
			raw *= t / 0.05
		elif t > 0.95:
			raw *= (1.0 - t) / 0.05
		_write_sample(data, i, raw)
	return _wrap_stream(data)


# 把 bass + lead 两条音轨合成成一段 PCM
# notes 格式: [[freq_hz, beats], ...]   freq=0 表示休止
func _mix_two_tracks(bass: Array, lead: Array, beat: float, total_sec: float,
		bass_amp: float, lead_amp: float) -> AudioStreamWAV:
	var samples := int(total_sec * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	# 预渲染每个轨道到 float 数组, 然后混合
	var bass_buf: PackedFloat32Array = _render_track(bass, beat, samples, bass_amp, true)
	var lead_buf: PackedFloat32Array = _render_track(lead, beat, samples, lead_amp, false)
	for i in samples:
		var s: float = bass_buf[i] + lead_buf[i]
		# 整体淡入淡出 (循环边界平滑)
		var t: float = float(i) / float(samples)
		if t < 0.02:
			s *= t / 0.02
		elif t > 0.98:
			s *= (1.0 - t) / 0.02
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 把音符列表渲染成 PCM. is_bass 控制 sine 波形 + envelope.
func _render_track(notes: Array, beat: float, total_samples: int, amp: float,
		is_bass: bool) -> PackedFloat32Array:
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(total_samples)
	var cursor: int = 0
	for note in notes:
		var freq: float = float(note[0])
		var beats: float = float(note[1])
		var note_samples: int = int(beats * beat * SAMPLE_RATE)
		if cursor + note_samples > total_samples:
			note_samples = total_samples - cursor
		if note_samples <= 0:
			break
		if freq < 1.0:
			# 休止符: 留空
			cursor += note_samples
			continue
		# 音符 envelope: 短 attack, 长 sustain, 短 release
		var attack_n: int = int(0.01 * SAMPLE_RATE)
		var release_n: int = int(0.05 * SAMPLE_RATE)
		var phase: float = 0.0
		for j in note_samples:
			phase += freq * TAU_F / SAMPLE_RATE
			var env: float = 1.0
			if j < attack_n:
				env = float(j) / float(attack_n)
			elif j > note_samples - release_n:
				env = float(note_samples - j) / float(release_n)
			# Bass 加八度倍频混合 (更厚), Lead 纯 sine
			var s: float = sin(phase)
			if is_bass:
				s = s * 0.7 + sin(phase * 2.0) * 0.3
			buf[cursor + j] = s * amp * env
		cursor += note_samples
	return buf


# ===== 环境声合成 =====

# 风: 长低通棕噪声循环, 缓慢起伏 (LFO 调制音量)
func _build_wind(duration: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var bn := BrownNoise.new()
	var lp1 := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	for i in samples:
		var t: float = float(i) / float(samples)
		# LFO 缓慢起伏 (~0.3Hz)
		var lfo: float = 0.6 + 0.4 * sin(t * duration * 0.3 * TAU_F)
		var raw: float = bn.sample() * 0.7 * lfo
		# 3 阶低通 (alpha 小, 削高频狠)
		lp1 = _lpf(lp1, raw, 0.15)
		lp2 = _lpf(lp2, lp1, 0.15)
		lp3 = _lpf(lp3, lp2, 0.15)
		var s: float = lp3
		# 边界淡入淡出
		if t < 0.05:
			s *= t / 0.05
		elif t > 0.95:
			s *= (1.0 - t) / 0.05
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 蟋蟀: 每 1-2 秒一次 chirp (短促 4kHz sine bursts), 不规则间隔
func _build_cricket(duration: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	# 预定义 chirp 时间点 (秒)
	var chirp_times: PackedFloat32Array = [0.3, 1.5, 2.7, 3.9, 5.1, 6.3, 7.5]
	var chirp_freq: float = 4000.0
	var chirp_dur: float = 0.08
	for i in samples:
		var ts: float = float(i) / SAMPLE_RATE
		var s: float = 0.0
		for ct in chirp_times:
			var dt: float = ts - ct
			if dt >= 0.0 and dt < chirp_dur:
				# 3 短脉冲 chirp (像蟋蟀振翅: ji-ji-ji)
				var pulse_t: float = fmod(dt, chirp_dur / 3.0) / (chirp_dur / 3.0)
				if pulse_t < 0.7:
					var env: float = sin(pulse_t / 0.7 * PI)
					s += sin(dt * chirp_freq * TAU_F) * env * 0.25
		var t: float = float(i) / float(samples)
		if t < 0.02:
			s *= t / 0.02
		elif t > 0.98:
			s *= (1.0 - t) / 0.02
		_write_sample(data, i, s)
	return _wrap_stream(data)


# 水滴: 每 ~3s 一滴金属"叮", 600Hz 短 sine 指数衰减
func _build_drip(duration: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var drip_times: PackedFloat32Array = [0.5, 3.4, 6.8]
	var drip_dur: float = 0.4
	for i in samples:
		var ts: float = float(i) / SAMPLE_RATE
		var s: float = 0.0
		for dt_start in drip_times:
			var dt: float = ts - dt_start
			if dt >= 0.0 and dt < drip_dur:
				var n: float = dt / drip_dur
				var env: float = pow(1.0 - n, 3.0)  # 快速衰减
				var freq: float = 600.0 * (1.0 - n * 0.2)  # 微微下沉
				s += sin(dt * freq * TAU_F) * env * 0.4
		var t: float = float(i) / float(samples)
		if t < 0.02:
			s *= t / 0.02
		elif t > 0.98:
			s *= (1.0 - t) / 0.02
		_write_sample(data, i, s)
	return _wrap_stream(data)


# ===== 共用工具 =====

class BrownNoise:
	var _state: float = 0.0
	func sample() -> float:
		_state = clampf(_state * 0.95 + (randf() * 2.0 - 1.0) * 0.1, -1.0, 1.0)
		return _state


func _lpf(prev: float, raw: float, alpha: float) -> float:
	return prev * (1.0 - alpha) + raw * alpha


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
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = data.size() / 2
	return stream
