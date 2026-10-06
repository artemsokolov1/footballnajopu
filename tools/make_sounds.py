"""Генерирует простые процедурные звуки прототипа (audio/*.wav).

Запуск: python3 tools/make_sounds.py  (нужен numpy)
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(7)


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def save(name, data, peak=0.9):
    data = data / (np.max(np.abs(data)) + 1e-9) * peak
    pcm = (data * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def sweep(t, f0, f1, k):
    freq = f1 + (f0 - f1) * np.exp(-t * k)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def kick():
    # Глухой «бум» по мячу: низкий тон с падением частоты + короткий щелчок.
    t = t_axis(0.3)
    body = sweep(t, 190, 70, 35) * np.exp(-t * 22)
    pok = np.sin(2 * np.pi * 420 * t) * np.exp(-t * 60) * 0.5
    click = lowpass(rng.standard_normal(len(t)), 0.35) * np.exp(-t * 300) * 0.8
    return body + pok + click


def bounce():
    # Отскок мяча от асфальта: короткий упругий «ток».
    t = t_axis(0.18)
    body = sweep(t, 260, 120, 40) * np.exp(-t * 38)
    slap = lowpass(rng.standard_normal(len(t)), 0.25) * np.exp(-t * 180) * 0.6
    return body + slap


def post():
    # Металлический звон штанги: негармонические обертоны с разным затуханием.
    t = t_axis(1.4)
    partials = [(520, 3.0, 1.0), (1347, 4.0, 0.6), (2211, 5.5, 0.4), (3170, 7.0, 0.25), (4420, 9.0, 0.15)]
    ring = sum(a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t * d) for f, d, a in partials)
    hit = lowpass(rng.standard_normal(len(t)), 0.5) * np.exp(-t * 120) * 0.7
    return ring + hit


def whistle():
    # Свисток: тон ~2.9 кГц с трелью шарика, два коротких и один длинный.
    out = []
    for dur, gap in ((0.16, 0.08), (0.16, 0.08), (0.75, 0.0)):
        t = t_axis(dur)
        trill = 1 + 0.5 * np.sin(2 * np.pi * 34 * t)
        freq = 2900 + 120 * np.sin(2 * np.pi * 34 * t)
        tone = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * trill
        tone += 0.15 * lowpass(rng.standard_normal(len(t)), 0.6)
        env = np.minimum(1, t / 0.015) * np.minimum(1, (dur - t) / 0.04)
        out.append(tone * env)
        out.append(np.zeros(int(RATE * gap)))
    return np.concatenate(out)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("kick.wav", kick())
    save("bounce.wav", bounce(), 0.8)
    save("post.wav", post(), 0.7)
    save("whistle.wav", whistle(), 0.6)
    print("ok")
