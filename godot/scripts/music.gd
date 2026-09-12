# Phase 5: prozeduraler Musik-Sequencer - 100% synthetisiert, kein
# Audiofile. Bewusst nicht notengetreu zum JS-Original (die exakte
# Notenfolge liess sich aus dem archivierten Kommentar nicht rekonstruieren,
# nur der Stil: bpm=126, Akkorde+Bass+Perkussion) - rein kosmetisch, nicht
# fairness-relevant, daher unkritisch. Anders als sfx.gd KEIN Autoload:
# game_view.gd haelt eine eigene Instanz (nur EIN Ort braucht Musik).
extends Node

const AudioSynth = preload("res://scripts/audio_synth.gd")

const BPM := 126.0
const STEP_DUR := 60.0 / BPM / 4.0     # 16tel-Schritte
const STEPS_PER_CHORD := 16             # ein Takt (4/4) pro Akkord

# Einfache Akkordfolge (Am-F-C-G, Moll-Pentatonik-nah) + Basstoene (eine
# Oktave tiefer als der Grundton).
const CHORDS := [
    [220.00, 261.63, 329.63],
    [174.61, 220.00, 261.63],
    [261.63, 329.63, 392.00],
    [196.00, 246.94, 293.66],
]
const BASS := [110.00, 87.31, 130.81, 98.00]

var enabled := false
var _step_timer := 0.0
var _step := 0

const POOL_SIZE := 8
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0

var _chord_clips: Array = []
var _bass_clips: Array = []
var _hat_clip: AudioStreamWAV

func _ready() -> void:
    var bar_len := STEPS_PER_CHORD * STEP_DUR
    for chord in CHORDS:
        var clips := []
        for freq in chord:
            clips.append(AudioSynth.make_tone("square", freq, freq, bar_len * 0.9))
        _chord_clips.append(clips)
    for freq in BASS:
        _bass_clips.append(AudioSynth.make_tone("triangle", freq, freq, bar_len * 0.5))
    _hat_clip = AudioSynth.make_noise(0.035, 7000.0, 0.9)
    for i in range(POOL_SIZE):
        var p := AudioStreamPlayer.new()
        add_child(p)
        _players.append(p)

func _play(stream: AudioStreamWAV, vol: float) -> void:
    var p := _players[_next_player]
    _next_player = (_next_player + 1) % POOL_SIZE
    p.stream = stream
    p.volume_db = linear_to_db(clampf(vol, 0.001, 1.0))
    p.play()

func _process(delta: float) -> void:
    if not enabled:
        return
    _step_timer += delta
    while _step_timer >= STEP_DUR:
        _step_timer -= STEP_DUR
        _fire_step(_step)
        _step = (_step + 1) % (STEPS_PER_CHORD * CHORDS.size())

func _fire_step(step: int) -> void:
    var chord_idx := int(step / STEPS_PER_CHORD) % CHORDS.size()
    var pos := step % STEPS_PER_CHORD
    if pos == 0:
        _play(_bass_clips[chord_idx], 0.24)
        for c in _chord_clips[chord_idx]:
            _play(c, 0.06)
    if pos % 2 == 0:
        _play(_hat_clip, 0.09)
    if pos % 8 == 4:
        var notes: Array = _chord_clips[chord_idx]
        _play(notes[(pos / 4) % notes.size()], 0.10)

func start() -> void:
    enabled = true
    _step = 0
    _step_timer = 0.0

func stop() -> void:
    enabled = false
