extends Node
## Short original synthesized cues. No samples, network calls, plugins or dependencies.
var enabled = true
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var next_voice = 0

func _ready() -> void:
    for kind in ["attack", "hit", "faint"]:
        sounds[kind] = synthesize(kind)
    for i in 4:
        var voice = AudioStreamPlayer.new()
        voice.volume_db = -20
        add_child(voice)
        voices.append(voice)

func synthesize(kind: String) -> AudioStreamWAV:
    var rate = 22050
    var duration = .12 if kind == "attack" else .09 if kind == "hit" else .32
    var count = int(rate * duration)
    var samples = PackedByteArray()
    samples.resize(count * 2)
    var rng = RandomNumberGenerator.new()
    rng.seed = 2718
    var phase = 0.0
    var noise = 0.0
    for i in count:
        var t = float(i) / count
        var frequency = lerpf(740, 300, t) if kind == "attack" else lerpf(220, 95, t) if kind == "hit" else lerpf(520, 150, t)
        phase += TAU * frequency / rate
        noise = lerpf(noise, rng.randf_range(-1, 1), .55)
        var tone = sin(phase) * .55 + noise * (.45 if kind != "faint" else .06)
        var envelope = minf(1, t * 30) * pow(1 - t, 2)
        samples.encode_s16(i * 2, int(clampf(tone * envelope, -1, 1) * 24000))
    var stream = AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.data = samples
    return stream

func cue(kind: String) -> void:
    # Headless simulations have no audible output or audio mixing lifecycle.
    if DisplayServer.get_name() == "headless" or not enabled or not sounds.has(kind) or voices.is_empty():
        return
    var voice = voices[next_voice]
    next_voice = (next_voice + 1) % voices.size()
    voice.stream = sounds[kind]
    voice.play()

func silence() -> void:
    for voice in voices:
        voice.stop()

func toggle() -> void:
    enabled = not enabled
    if not enabled:
        silence()

func _exit_tree() -> void:
    silence()
    for voice in voices:
        voice.stream = null
    sounds.clear()
