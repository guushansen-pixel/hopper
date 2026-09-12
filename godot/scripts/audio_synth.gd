# Phase 5: reine Wellenform-Synthese, kein Audiofile im Projekt - wortgleiches
# Prinzip zu web/index.html (tone()/noise() ueber WebAudio-Oszillatoren/
# gefiltertes Rauschen), hier als vorab generierte AudioStreamWAV-Clips statt
# Echtzeit-Oszillatoren (Godots AudioStreamGenerator waere die "live"-
# Variante, aber fuer kurze, feste SFX/Noten ist ein einmal generierter
# Clip einfacher und braucht keinen Callback pro Audio-Frame).
#
# Lautstaerke wird HIER bewusst NICHT gebacken (immer Spitzenamplitude ~1.0) -
# das eigentliche Sound-Design (welche Lautstaerke welcher Sound hat, siehe
# web/index.html SFX-Objekt) legt sfx.gd beim Abspielen ueber
# AudioStreamPlayer.volume_db fest. Trennt Klangfarbe (hier) von Lautstaerke-
# Mischung (dort), wie bei einem echten Synthesizer.
extends RefCounted
class_name AudioSynth

const MIX_RATE := 22050

static func _waveform(kind: String, frac: float) -> float:
    match kind:
        "sine":
            return sin(frac * TAU)
        "square":
            return 1.0 if frac < 0.5 else -1.0
        "sawtooth":
            return 2.0 * frac - 1.0
        "triangle":
            return (-1.0 + 4.0 * frac) if frac < 0.5 else (3.0 - 4.0 * frac)
        _:
            return sin(frac * TAU)

# Schneller linearer Attack, dann exponentieller Ausklang - entspricht der
# in web/index.html ueberall verwendeten "exponentieller Gain-Verlauf"-
# Huellkurve fuer tone().
static func _envelope(t: float, attack: float = 0.06, decay_rate: float = 5.0) -> float:
    if t < attack:
        return t / attack
    var dt: float = (t - attack) / max(0.0001, 1.0 - attack)
    return exp(-dt * decay_rate)

# type: "sine"|"square"|"sawtooth"|"triangle". f0->f1: exponentieller
# Frequenz-Sweep (wie AudioParam.exponentialRampToValueAtTime im Original).
static func make_tone(wave_type: String, f0: float, f1: float, dur: float) -> AudioStreamWAV:
    var n: int = max(1, int(dur * MIX_RATE))
    var data := PackedByteArray()
    data.resize(n * 2)
    var phase := 0.0
    var use_ramp := f0 > 0.0 and f1 > 0.0 and f0 != f1
    for i in range(n):
        var t := float(i) / float(n)
        var freq := (f0 * pow(f1 / f0, t)) if use_ramp else f1
        phase += freq / MIX_RATE
        var frac := fmod(phase, 1.0)
        var s := _waveform(wave_type, frac) * _envelope(t)
        data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = MIX_RATE
    stream.stereo = false
    stream.data = data
    return stream

# Gefiltertes Rauschen (Bandpass um "freq", Guete "q") - Biquad-Bandpass mit
# konstanter Skirt-Verstaerkung (Standardformel, "Audio EQ Cookbook"). Nicht
# bit-exakt zu web/index.html (das nutzt WebAudios eingebauten BiquadFilter),
# aber derselbe Filtertyp - rein kosmetisch, nicht fairness-relevant.
static func make_noise(dur: float, freq: float, q: float) -> AudioStreamWAV:
    var n: int = max(1, int(dur * MIX_RATE))
    var rng := RandomNumberGenerator.new()
    var w0 := TAU * freq / MIX_RATE
    var alpha := sin(w0) / (2.0 * q)
    var a0 := 1.0 + alpha
    var b0 := (q * alpha) / a0
    var b2 := (-q * alpha) / a0
    var a1 := (-2.0 * cos(w0)) / a0
    var a2 := (1.0 - alpha) / a0
    var x1 := 0.0
    var x2 := 0.0
    var y1 := 0.0
    var y2 := 0.0
    var data := PackedByteArray()
    data.resize(n * 2)
    for i in range(n):
        var t := float(i) / float(n)
        var x := rng.randf_range(-1.0, 1.0)
        var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = x
        y2 = y1
        y1 = y
        var s := y * _envelope(t, 0.01, 6.0)
        data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = MIX_RATE
    stream.stereo = false
    stream.data = data
    return stream
