import os
import numpy as np
import wave

SR = 32000
OUT = r"d:\flutter_proj\Nova_Token_Drop\nova_token_drop\assets\music"
os.makedirs(OUT, exist_ok=True)


def note(freq, dur, t0, wave_mix=(1.0, 0.0), detune=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for k, w in ((1, wave_mix[0]), (2, wave_mix[1] * 0.5)):
        sig += w * np.sin(2 * np.pi * (freq * k) * t)
    if detune:
        sig += 0.5 * np.sin(2 * np.pi * (freq * (1 + detune)) * t)
    # soft attack/release envelope
    a = int(0.08 * SR)
    r = int(min(0.6, dur * 0.5) * SR)
    env = np.ones(n)
    env[:a] = np.linspace(0, 1, a)
    env[-r:] = np.linspace(1, 0, r)
    return sig * env, int(t0 * SR)


def add(buf, sig, pos, gain):
    end = pos + len(sig)
    if end > len(buf):
        sig = sig[: len(buf) - pos]
        end = len(buf)
    buf[pos:end] += sig * gain


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def reverb(x, decay=0.35, delays=(0.05, 0.11, 0.17, 0.23)):
    out = x.copy()
    for d in delays:
        s = int(d * SR)
        pad = np.zeros(len(x))
        pad[s:] = x[:-s]
        out += pad * decay
        decay *= 0.6
    return out


def normalize(x, peak=0.85):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def write_wav(path, data):
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype(np.int16)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def build_menu():
    # slow dreamy pad progression: Am - F - C - G (relative to A minor), airy
    bars = 8
    bar = 4.0
    total = bars * bar
    buf = np.zeros(int(total * SR))
    # chord roots (midi) with lush voicings
    chords = [
        [57, 60, 64, 67],   # Am7
        [53, 57, 60, 64],   # Fmaj7
        [48, 55, 60, 64],   # C
        [55, 59, 62, 67],   # G
    ]
    for b in range(bars):
        ch = chords[b % len(chords)]
        t0 = b * bar
        for i, nn in enumerate(ch):
            sig, pos = note(midi(nn + 12), bar * 1.02, t0, wave_mix=(0.7, 0.3), detune=0.004)
            add(buf, sig, pos, 0.14 - i * 0.015)
        # low pad
        sig, pos = note(midi(ch[0] - 12), bar * 1.02, t0, wave_mix=(0.9, 0.1))
        add(buf, sig, pos, 0.18)
    # gentle bell arpeggio
    scale = [69, 72, 76, 79, 81, 79, 76, 72]
    step = 0.5
    for i in range(int(total / step)):
        nn = scale[i % len(scale)]
        sig, pos = note(midi(nn + 12), 0.9, i * step, wave_mix=(0.4, 0.6))
        add(buf, sig, pos, 0.05 * (0.6 + 0.4 * np.sin(i * 0.4)))
    buf = reverb(buf, decay=0.4)
    return normalize(buf, 0.8)


def build_game():
    bars = 8
    bar = 3.2
    total = bars * bar
    buf = np.zeros(int(total * SR))
    chords = [
        [45, 52, 57, 60],   # Am
        [43, 50, 55, 59],   # G
        [41, 48, 53, 57],   # F
        [43, 50, 55, 59],   # G
    ]
    beat = bar / 4
    for b in range(bars):
        ch = chords[b % len(chords)]
        t0 = b * bar
        for i, nn in enumerate(ch):
            sig, pos = note(midi(nn + 12), bar, t0, wave_mix=(0.6, 0.4), detune=0.005)
            add(buf, sig, pos, 0.10)
        # pulsing bass on beats
        for k in range(4):
            sig, pos = note(midi(ch[0]), beat * 0.9, t0 + k * beat, wave_mix=(0.95, 0.05))
            add(buf, sig, pos, 0.16)
    # sparkle arpeggio (pentatonic)
    penta = [69, 72, 74, 76, 79, 81]
    step = beat / 2
    for i in range(int(total / step)):
        nn = penta[(i * 2) % len(penta)]
        sig, pos = note(midi(nn + 12), 0.5, i * step, wave_mix=(0.3, 0.7))
        add(buf, sig, pos, 0.045 * (0.5 + 0.5 * np.sin(i * 0.3)))
    buf = reverb(buf, decay=0.3)
    return normalize(buf, 0.82)


write_wav(os.path.join(OUT, "menu_theme.wav"), build_menu())
write_wav(os.path.join(OUT, "game_theme.wav"), build_game())
print("music done")
