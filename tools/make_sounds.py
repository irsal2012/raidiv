"""Synthesizes the game's 10 sounds (Config/Audio.luau) into assets/audio/*.ogg.

Everything is generated from noise and oscillators, so we own it outright and it can be
re-tuned here and re-uploaded. Needs numpy, scipy and ffmpeg:

    pip install numpy scipy
    python tools/make_sounds.py
"""

import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)  # fixed seed: same files every run


# --- building blocks -------------------------------------------------------------------

def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def noise(seconds):
    return rng.standard_normal(int(seconds * SR))


def filt(x, kind, freq, order=4):
    sos = butter(order, freq, btype=kind, fs=SR, output="sos")
    return sosfilt(sos, x)


def sweep(f0, f1, seconds, curve="exp"):
    """Sine whose frequency glides from f0 to f1."""
    t = t_axis(seconds)
    if curve == "exp":
        f = f0 * (f1 / f0) ** (t / seconds)
    else:
        f = f0 + (f1 - f0) * t / seconds
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def decay(seconds, tau, attack=0.005):
    t = t_axis(seconds)
    env = np.exp(-t / tau)
    a = int(attack * SR)
    if a > 0:
        env[:a] *= np.linspace(0, 1, a)
    return env


def place(buf, sig, at):
    i = int(at * SR)
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i]


def reverb(x, seconds=1.2, tau=0.35, wet=0.3, cutoff=3500):
    """Murky underwater room: decaying, low-passed noise impulse response."""
    ir = noise(seconds) * np.exp(-t_axis(seconds) / tau)
    ir = filt(ir, "low", cutoff)
    ir /= np.sqrt(np.sum(ir**2))
    tail = fftconvolve(x, ir)  # len(x) + len(ir) - 1
    dry = np.concatenate([x, np.zeros(len(ir) - 1)])
    return (1 - wet) * dry + wet * tail


def bubble(f0=None):
    """One bubble: a short sine that rises in pitch as it pops."""
    f0 = f0 or rng.uniform(350, 1100)
    length = rng.uniform(0.025, 0.07)
    return sweep(f0, f0 * rng.uniform(1.4, 2.2), length) * decay(length, length / 3, 0.002)


def bubbles(seconds, rate, env=None):
    buf = np.zeros(int(seconds * SR))
    count = int(seconds * rate)
    for _ in range(count):
        at = rng.uniform(0, seconds - 0.08)
        weight = 1.0 if env is None else env(at / seconds)
        if rng.random() < weight:
            place(buf, bubble() * rng.uniform(0.3, 1.0), at)
    return buf


def seamless(x, fade):
    """Crossfades the tail into the head so the sound loops without a click."""
    n = int(fade * SR)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    ramp = np.linspace(0, 1, n)
    return np.concatenate([head * ramp + tail * (1 - ramp), body])


def trim_silence(x, threshold=1e-4):
    idx = np.nonzero(np.abs(x) > threshold)[0]
    return x[: idx[-1] + 1] if len(idx) else x


def finish(x, peak_db=-1.0, fade_out=0.02):
    x = x - np.mean(x)
    n = int(fade_out * SR)
    if n:
        x[-n:] *= np.linspace(1, 0, n)
    return x / np.max(np.abs(x)) * 10 ** (peak_db / 20)


# --- the sounds ------------------------------------------------------------------------

def ambience():
    """24 s underwater drone: pressure rumble, slow current, sub hum, far-off creaks."""
    length = 27
    t = t_axis(length)
    rumble = np.cumsum(noise(length))
    rumble = filt(filt(rumble, "high", 20, 2), "low", 220)
    rumble /= np.max(np.abs(rumble))
    rumble *= 0.75 + 0.25 * np.sin(2 * np.pi * t / 12)

    current = filt(noise(length), "band", [350, 900])
    current *= 0.5 + 0.5 * np.sin(2 * np.pi * t / 9 + 1.3) ** 2
    current *= 0.06 / np.std(current)

    hum = 0.12 * (np.sin(2 * np.pi * 55 * t) + np.sin(2 * np.pi * 55.25 * t) + 0.5 * np.sin(2 * np.pi * 82.5 * t))

    creaks = np.zeros(len(t))
    for at, f in [(6.5, 170), (17.0, 140)]:
        c = sweep(f, f * 0.7, 1.8) * (1 + 0.3 * np.sin(2 * np.pi * 7 * t_axis(1.8)))
        c = filt(c * np.sin(np.pi * t_axis(1.8) / 1.8) ** 2, "low", 600)
        place(creaks, c * 0.12, at)
    creaks = reverb(creaks, 2.0, 0.6, 0.6, 1500)[: len(t)]

    far_bubbles = filt(bubbles(length, 3), "low", 1800) * 0.15
    mix = rumble * 0.6 + current + hum + creaks + far_bubbles
    return finish(seamless(mix, 3), -3, 0)


def breathing():
    """4.8 s regulator cycle: click, hissing inhale, bubbling exhale, pause. Loops."""
    length = 4.8
    buf = np.zeros(int(length * SR))

    click = filt(noise(0.012), "band", [1500, 4000]) * decay(0.012, 0.003, 0.0005)
    place(buf, click * 0.5, 0.0)

    inhale_len = 1.3
    x = np.linspace(0, 1, int(inhale_len * SR))
    inhale = filt(noise(inhale_len), "band", [900, 5000])
    inhale *= np.sin(np.pi * x) ** 1.5 * (0.7 + 0.3 * x)
    place(buf, inhale * 0.35, 0.02)

    exhale_len = 1.9
    shape = lambda p: np.sin(np.pi * min(p * 1.3, 1)) ** 0.8  # noqa: E731
    exhale = bubbles(exhale_len, 70, shape) * 0.8
    gurgle = filt(noise(exhale_len), "band", [120, 500])
    gurgle *= np.sin(np.pi * np.linspace(0, 1, len(gurgle))) ** 2
    exhale += gurgle * 0.25
    place(buf, exhale, 1.55)

    buf = filt(buf, "low", 6000)
    return finish(reverb(buf, 0.4, 0.08, 0.15)[: len(buf)], -2, 0.05)


def pickup():
    """Bright two-note bubble chime."""
    buf = np.zeros(int(0.9 * SR))
    for at, f in [(0.0, 1318.5), (0.07, 1975.5)]:
        note = sweep(f * 1.02, f, 0.6) + 0.35 * sweep(f * 2.76, f * 2.7, 0.6)
        place(buf, note * decay(0.6, 0.14, 0.003) * 0.5, at)
    for at in (0.02, 0.09, 0.15):
        place(buf, bubble(rng.uniform(600, 1000)) * 0.4, at)
    return finish(trim_silence(reverb(buf, 0.6, 0.15, 0.25)))


def extract():
    """Surfacing splash and a rising major arpeggio: you made it."""
    buf = np.zeros(int(2.0 * SR))
    splash = filt(noise(0.6), "band", [400, 7000]) * decay(0.6, 0.12, 0.004)
    place(buf, splash * 0.5, 0.0)
    place(buf, bubbles(0.5, 50) * 0.3, 0.0)
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        hold = 1.2 if i == 3 else 0.5
        tone = np.sin(2 * np.pi * f * t_axis(hold)) + 0.3 * np.sin(2 * np.pi * 2 * f * t_axis(hold))
        place(buf, tone * decay(hold, hold / 3, 0.01) * 0.35, 0.12 + i * 0.09)
    return finish(trim_silence(reverb(buf, 1.0, 0.25, 0.25)))


def sonar():
    """Classic sonar ping with two fading echoes."""
    buf = np.zeros(int(1.8 * SR))
    ping = sweep(1180, 1120, 0.9) * decay(0.9, 0.22, 0.004)
    ping += 0.2 * sweep(2360, 2240, 0.9) * decay(0.9, 0.08, 0.004)
    place(buf, ping, 0.0)
    for at, gain in [(0.38, 0.3), (0.76, 0.12)]:
        place(buf, filt(ping, "low", 2500) * gain, at)
    return finish(trim_silence(reverb(buf, 1.2, 0.35, 0.3, 2500)))


def stinger():
    """Tutorial scare: boom, noise hit and a screeching dissonant cluster."""
    length = 1.8
    buf = np.zeros(int(length * SR))
    boom = sweep(90, 38, 0.9) * decay(0.9, 0.3, 0.003)
    hit = filt(noise(0.3), "low", 3000) * decay(0.3, 0.05, 0.001)
    t = t_axis(1.4)
    cluster = np.zeros(len(t))
    for f in (311.1, 329.6, 349.2, 466.2, 493.9):
        vib = 1 + 0.012 * np.sin(2 * np.pi * rng.uniform(5, 7) * t)
        phase = 2 * np.pi * np.cumsum(f * vib) / SR
        cluster += 2 * (phase / (2 * np.pi) % 1) - 1  # saw
    cluster = filt(cluster, "low", 3500) * decay(1.4, 0.45, 0.01)
    place(buf, boom * 0.9, 0)
    place(buf, hit * 0.6, 0)
    place(buf, cluster * 0.18, 0.02)
    return finish(trim_silence(reverb(buf, 1.5, 0.4, 0.35)))


def creature_alert():
    """A Drifter's low, questioning groan."""
    length = 1.3
    t = t_axis(length)
    f = 62 + 20 * np.sin(np.pi * t / length) + 4 * np.sin(2 * np.pi * 11 * t)
    phase = 2 * np.pi * np.cumsum(f) / SR
    growl = 2 * (phase / (2 * np.pi) % 1) - 1
    growl += 0.4 * filt(noise(length), "low", 300)
    growl = filt(growl, "low", 700)
    growl *= np.sin(np.pi * np.minimum(t / length * 1.2, 1)) ** 1.2
    return finish(trim_silence(reverb(growl, 1.2, 0.35, 0.35, 1200)))


def creature_chase():
    """3.2 s loop: pounding double heartbeat under a trembling drone."""
    length = 3.2
    t = t_axis(length)
    buf = np.zeros(len(t))
    thump = sweep(95, 45, 0.25) * decay(0.25, 0.07, 0.002)
    for beat in range(4):
        place(buf, thump, beat * 0.8)
        place(buf, thump * 0.6, beat * 0.8 + 0.22)
    drone = np.sin(2 * np.pi * 110 * t) + np.sin(2 * np.pi * 116.25 * t)
    drone += 0.5 * np.sin(2 * np.pi * 220 * t)
    drone *= 0.55 + 0.45 * np.sin(2 * np.pi * 7.5 * t)
    hiss = filt(np.tile(noise(length / 2), 2)[: len(t)], "band", [300, 1200]) * 0.05
    mix = buf + drone * 0.12 + hiss
    return finish(filt(mix, "low", 4000), -2, 0)


def lurker_windup():
    """0.7 s accelerating rattle that ends in a snap: dodge now."""
    length = 0.8
    buf = np.zeros(int(length * SR))
    at, gap = 0.0, 0.075
    click = filt(noise(0.008), "band", [1800, 4500]) * decay(0.008, 0.002, 0.0005)
    while at < 0.66:
        place(buf, click * (0.7 + at), at)
        at += gap
        gap = max(0.014, gap * 0.85)
    rise = filt(noise(0.66), "band", [600, 2500]) * np.linspace(0, 1, int(0.66 * SR)) ** 2
    place(buf, rise * 0.3, 0)
    snap = filt(noise(0.05), "high", 1500) * decay(0.05, 0.01, 0.0005)
    place(buf, snap * 0.5, 0.68)
    return finish(trim_silence(reverb(buf, 0.5, 0.12, 0.2)))


def warden_arrive():
    """A huge, distant moan with a deep boom: something big is coming."""
    length = 4.0
    t = t_axis(length)
    pitch = np.interp(t, [0, 1.2, 2.6, 4.0], [70, 110, 85, 55])
    pitch *= 1 + 0.02 * np.sin(2 * np.pi * 4.5 * t)
    phase = 2 * np.pi * np.cumsum(pitch) / SR
    moan = sum(np.sin(k * phase) / k for k in range(1, 7))
    moan = filt(moan, "band", [60, 900])
    moan *= np.interp(t, [0, 0.6, 3.0, 4.0], [0, 1, 0.8, 0])
    boom = sweep(60, 28, 2.0) * decay(2.0, 0.6, 0.01)
    buf = moan * 0.6
    place(buf, boom, 0)
    return finish(trim_silence(reverb(buf, 3.0, 0.9, 0.5, 1200)))


SOUNDS = {
    "Ambience": ambience,
    "Breathing": breathing,
    "Pickup": pickup,
    "Extract": extract,
    "Sonar": sonar,
    "Stinger": stinger,
    "CreatureAlert": creature_alert,
    "CreatureChase": creature_chase,
    "LurkerWindup": lurker_windup,
    "WardenArrive": warden_arrive,
}


def write_ogg(name, samples):
    pcm = (np.clip(samples, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    out = os.path.join(OUT, f"{name}.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "6", out], check=True)
    os.remove(path)
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, make in SOUNDS.items():
        samples = make()
        print(f"{name:14s} {len(samples) / SR:5.2f}s  {write_ogg(name, samples)}")
