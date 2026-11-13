# The small sounds of the use spots (design/plans/next-lanes.md section 4.4), synthesised from noise and decaying
# tones: nothing on disk was close enough and Freesound needs a login. audio/make.sh calls this, then trims,
# normalises, bakes the Mars `_out` copy and encodes each one.
# Usage: nice -n 10 python3 -I audio/make_sfx.py <outdir>   (numpy only; fixed seed, so the files rebuild the same)
# Licence: Apache-2.0, original work of the Outpost Gale team (written with AI help).
import os
import sys
import wave

import numpy as np

SR = 32000
RNG = np.random.default_rng(13)


def secs(d: float) -> np.ndarray:
    return np.arange(int(SR * d)) / SR


def band(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """Band-pass by FFT with soft edges (an octave-wide roll-off), good enough for noise."""
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = 1 / (1 + (lo / np.maximum(f, 1)) ** 4) / (1 + (f / hi) ** 4)
    return np.fft.irfft(np.fft.rfft(x) * g, len(x))


def sweep(x: np.ndarray, fc: np.ndarray, q: float) -> np.ndarray:
    """A band-pass biquad whose centre follows fc sample by sample (cloth folds move the colour of a swish)."""
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        w = 2 * np.pi * fc[i] / SR
        a = np.sin(w) / (2 * q)
        a0 = 1 + a
        y[i] = (a * x[i] - a * x2 - (-2 * np.cos(w)) * y1 - (1 - a) * y2) / a0
        x2, x1, y2, y1 = x1, x[i], y1, y[i]
    return y


def slow(n: int, hz: float) -> np.ndarray:
    """Noise that wanders at about `hz`, from -1 to 1: the hand that is never quite steady."""
    k = max(2, int(n / SR * hz) + 2)
    return np.interp(np.arange(n), np.linspace(0, n, k), RNG.uniform(-1, 1, k))


def ping(freqs: tuple, decay: float, dur: float = 0.08) -> np.ndarray:
    """A small hard thing struck: a few resonances that die in `decay` seconds, on a 1 ms noise tick."""
    t = secs(dur)
    out = sum(np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28)) / (k + 1) for k, f in enumerate(freqs))
    out = out * np.exp(-t / decay)
    tick = RNG.standard_normal(len(t)) * np.exp(-t / 0.001)
    return out + 0.5 * tick


def at(buf: np.ndarray, t0: float, sig: np.ndarray, gain: float = 1.0) -> None:
    i = int(t0 * SR)
    j = min(len(buf), i + len(sig))
    buf[i:j] += gain * sig[: j - i]


def grains(dur: float, rate: np.ndarray | float, lo: float, hi: float, tail: float = 1.5) -> np.ndarray:
    """Many tiny clicks at `rate` a second (a number, or one per sample), loudness from a heavy tail so a few stand
    out, then band-passed: crackles, seeds, bristles, zip teeth."""
    n = int(SR * dur)
    r = np.broadcast_to(np.asarray(rate, float), (n,))
    hits = RNG.random(n) < r / SR
    x = np.zeros(n)
    x[hits] = RNG.pareto(tail, hits.sum()) * RNG.choice([-1, 1], hits.sum())
    x = np.convolve(x, np.exp(-secs(0.004) / 0.0007) * RNG.standard_normal(len(secs(0.004))), "same")
    return band(x, lo, hi)


def env(n: int, rise: float, fall: float) -> np.ndarray:
    t = np.arange(n) / SR
    return np.minimum(t / rise, 1) * np.clip((n / SR - t) / fall, 0, 1)


def curtain() -> np.ndarray:
    # cloth drawn along a rail: a swish whose colour moves with the folds, and the rings ticking on the rail
    t = secs(0.75)
    fc = 1500 + 700 * np.sin(np.pi * t / 0.75) + 250 * slow(len(t), 12)
    x = sweep(RNG.standard_normal(len(t)), fc, 1.1) * (0.75 + 0.25 * slow(len(t), 18))
    x *= env(len(t), 0.12, 0.35)
    for s in np.sort(RNG.uniform(0.05, 0.55, 7)):
        at(x, s, ping((3600, 5300, 7100), 0.012), RNG.uniform(0.04, 0.08))
    return x


def pour() -> np.ndarray:
    # water into a pouch: bubbles that chirp up as they form (van den Doel's bubble model), higher as it fills
    T = 1.3
    x = 0.05 * band(RNG.standard_normal(int(SR * T)), 400, 2500)
    for s in np.sort(RNG.uniform(0.0, T - 0.1, 60)):
        f0 = RNG.uniform(500, 1400) * (1 + 0.6 * s / T)
        d = RNG.uniform(0.03, 0.08)
        b = secs(d * 4)
        at(x, s, np.sin(2 * np.pi * f0 * (b + 2.0 * b * b)) * np.exp(-b / d), RNG.uniform(0.15, 0.5))
    return x * env(len(x), 0.08, 0.25)


def sip() -> np.ndarray:
    # a short slurp through a straw, a few small bubbles, one soft gulp
    x = band(RNG.standard_normal(int(SR * 0.6)), 900, 3200) * 0.25
    x *= np.clip(np.sin(2 * np.pi * 5 * secs(0.6)), 0, 1) * env(len(x), 0.02, 0.3)
    for s in RNG.uniform(0.02, 0.3, 5):
        b = secs(0.1)
        at(x, s, np.sin(2 * np.pi * RNG.uniform(1500, 2500) * (b + 1.5 * b * b)) * np.exp(-b / 0.025), 0.3)
    g = secs(0.12)
    at(x, 0.4, np.sin(2 * np.pi * (180 * g - 375 * g * g)) * np.exp(-g / 0.035), 0.9)
    return x


def crinkle() -> np.ndarray:
    # a foil food pouch handled: three crumples of sharp crackles over a faint rustle
    x = np.zeros(int(SR * 0.95))
    for s, d in ((0.0, 0.22), (0.3, 0.18), (0.55, 0.3)):
        g = grains(d, 160, 1800, 9000) * env(int(SR * d), 0.03, 0.08)
        at(x, s, g)
    return x + 0.02 * band(RNG.standard_normal(len(x)), 3000, 8000) * env(len(x), 0.05, 0.3)


def latch() -> np.ndarray:
    # a sprung catch: the click as it lets go, then the clack of the lid against its stop
    x = np.zeros(int(SR * 0.3))
    at(x, 0.0, ping((2300, 3700, 5900), 0.012))
    at(x, 0.045, ping((900, 1700, 2600), 0.025, 0.12), 0.8)
    thud = secs(0.12)
    at(x, 0.045, np.sin(2 * np.pi * 140 * thud) * np.exp(-thud / 0.03), 0.6)
    return x


def ratchet() -> np.ndarray:
    # three turns of a ratchet driver: the pawl clicking over the teeth, seven a turn
    x = np.zeros(int(SR * 1.2))
    for k in range(3):
        for i in range(7):
            at(x, 0.42 * k + 0.022 * i, ping((3100, 4700, 6800), 0.006, 0.03), np.sin(np.pi * (i + 0.5) / 7) * 0.9)
    return x


def valve() -> np.ndarray:
    # a stiff valve wheel turned in two grips: metal squeaking as it sticks and slips
    t = secs(0.7)
    f = 780 + 260 * t / 0.7 + 50 * slow(len(t), 9) + 30 * slow(len(t), 70)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = sum(np.sin(n * ph) / n ** 0.8 for n in range(1, 7))
    x *= 0.3 + 0.7 * np.abs(slow(len(t), 40))  # stick and slip
    x += 0.15 * band(RNG.standard_normal(len(t)), 1500, 6000)  # metal rubbing metal
    grip = ((t < 0.3) * np.minimum(t / 0.03, 1) * np.clip((0.3 - t) / 0.05, 0, 1)
            + ((t > 0.38) & (t < 0.66)) * np.clip((t - 0.38) / 0.03, 0, 1) * np.clip((0.66 - t) / 0.06, 0, 1))
    return band(x * grip, 300, 6000)


def rattle() -> np.ndarray:
    # a seed packet shaken twice: seeds hitting paper, a little paper rustle
    x = np.zeros(int(SR * 0.6))
    for s in (0.0, 0.28):
        d = 0.18
        at(x, s, grains(d, 450, 2500, 7000, 2.5) * np.sin(np.pi * secs(d) / d) ** 2)
        at(x, s, band(RNG.standard_normal(int(SR * d)), 1500, 5000) * env(int(SR * d), 0.03, 0.08), 0.08)
    return x


def leaf() -> np.ndarray:
    # a lettuce leaf torn off: crisp tearing that thickens, a snap, a wet squeak
    d = 0.45
    t = secs(d)
    x = grains(d, 300 + 600 * t / d, 1000, 6000, 2.0) * np.clip(t / 0.3, 0, 1) * np.clip((d - t) / 0.12, 0, 1)
    at(x, 0.31, ping((1200, 2100, 3900), 0.015, 0.1), 1.5)
    sq = secs(0.06)
    at(x, 0.33, band(RNG.standard_normal(len(sq)), 2200, 2900) * np.sin(np.pi * sq / 0.06), 0.4)
    return x


def suction() -> np.ndarray:
    # the toilet works by air: its fan spins up, pulls with a rushing suction, and spins down
    T = 3.2
    t = secs(T)
    spd = np.clip(t / 0.5, 0, 1) * np.clip((T - t) / 0.8, 0, 1)
    ph = 2 * np.pi * np.cumsum(60 + 130 * spd) / SR
    motor = sum(np.sin(n * ph) / n ** 1.3 for n in range(1, 6)) + 0.3 * np.sin(4 * ph * 2)
    air = band(np.cumsum(RNG.standard_normal(len(t))) * 0.02 + RNG.standard_normal(len(t)) * 0.3, 300, 3000)
    pull = band(RNG.standard_normal(len(t)), 600, 1500) * np.exp(-((t - 1.3) / 0.35) ** 2)
    return 0.25 * motor * spd + air * spd ** 2 * 0.6 + 0.5 * pull


def brush() -> np.ndarray:
    # three strokes of a stiff brush over suit fabric: bristles flicking
    x = np.zeros(int(SR * 1.1))
    for s in (0.0, 0.38, 0.76):
        d = 0.26
        at(x, s, grains(d, 900, 2000, 7000, 3.0) * np.sin(np.pi * secs(d) / d) ** 1.5)
        at(x, s, band(RNG.standard_normal(int(SR * d)), 2500, 6000) * np.sin(np.pi * secs(d) / d), 0.1)
    return x


def zip_() -> np.ndarray:
    # a sample bag zipped shut: teeth clicking faster as the pull speeds up
    d = 0.32
    t = secs(d)
    x = grains(d, 120 + 260 * t / d, 2000, 6000, 3.0)
    x += 0.15 * band(RNG.standard_normal(len(t)), 2500, 5000) * (t / d)
    return x * env(len(t), 0.02, 0.05)


def beep() -> np.ndarray:
    # the food warmer is done: two soft beeps
    x = np.zeros(int(SR * 0.4))
    b = secs(0.12)
    tone = (np.sin(2 * np.pi * 1760 * b) + 0.15 * np.sin(2 * np.pi * 5280 * b)) * env(len(b), 0.005, 0.01)
    at(x, 0.0, tone)
    at(x, 0.2, tone)
    return x


def write(path: str, x: np.ndarray) -> None:
    x = x * (0.7 / np.abs(x).max())
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    out = sys.argv[1]
    for fn in (curtain, pour, sip, crinkle, latch, ratchet, valve, rattle, leaf, suction, brush, zip_, beep):
        x = fn()
        assert 0.2 <= len(x) / SR <= 4 and not np.isnan(x).any() and np.abs(x).max() > 0, fn.__name__
        name = fn.__name__.rstrip("_")  # zip_: the builtin keeps its name
        write(os.path.join(out, name + ".wav"), x)
        print(f"{name}.wav {len(x) / SR:.2f} s")
