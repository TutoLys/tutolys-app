#!/usr/bin/env python3
"""The three activity sound effects, synthesised from fixed parameters.

Hafid's rule: the SAME sounds in every engine, for exactly three moments:

- ``right``: VALIDER and the answer is right. A bright, short, happy chime.
- ``wrong``: VALIDER and the answer is wrong. Gentle and non-punishing,
  like the design's amber "retry": never a buzzer, nothing harsh, nothing a
  6-year-old reads as "bad".
- ``end``: the end-of-activity screen. A short celebratory flourish.

Three variants of each (a, b, c) so Hafid can listen and pick. Everything is
generated here from sine partials, envelopes and a small synthetic reverb,
so the sounds are ours (CC0 by construction) and regenerate byte for byte:
no randomness without a fixed seed, no sample files.

Loudness: each clip is set to ``TARGET_LUFS`` (K-weighted, ITU-R BS.1770,
ungated over the clip once its silent tail is trimmed), a little under the
Piper narration (about -15 LUFS measured on the dev-stack's clips). Peaks
are then held under ``PEAK_DBFS`` by a soft limiter on the few loud samples
rather than by turning the whole clip down, so all nine stay equally loud.

Usage::

    python3 tools/sfx/generate_sfx.py [OUT_DIR]

Writes ``<name>.wav`` (16-bit mono, 44.1 kHz; byte-for-byte reproducible)
and, when ffmpeg is present, ``<name>.ogg`` and ``<name>.mp3`` (128 kbps;
those depend on the encoder version). Needs only numpy.
"""

from __future__ import annotations

import math
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
TARGET_LUFS = -19.0
PEAK_DBFS = -3.0
DEFAULT_OUT = Path.home() / "Lab/Tutolys/Assets/Sounds/generated"


# --- notes ---------------------------------------------------------------


def hz(note: str) -> float:
    """'C6' -> 1046.5. Sharps only ('G#5')."""
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    name, octave = note[:-1], int(note[-1])
    semitone = names.index(name) + 12 * (octave + 1)
    return 440.0 * 2 ** ((semitone - 69) / 12)


# --- voices ----------------------------------------------------------------


def _t(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def _env(t: np.ndarray, attack: float, decay: float) -> np.ndarray:
    """Soft linear attack, then an exponential decay with time constant
    ``decay``. A soft attack is what keeps a chime friendly, not clicky."""
    rise = np.clip(t / max(attack, 1e-4), 0, 1)
    return rise * np.exp(-np.maximum(t - attack, 0) / decay)


def bell(freq: float, seconds: float = 0.6, decay: float = 0.18) -> np.ndarray:
    """A glassy chime: fundamental plus a few slightly inharmonic partials
    that die faster than it does."""
    t = _t(seconds)
    partials = [(1.0, 1.0, 1.0), (2.0, 0.35, 0.6), (3.01, 0.15, 0.4), (4.2, 0.06, 0.25)]
    out = np.zeros_like(t)
    for ratio, amp, life in partials:
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * _env(t, 0.006, decay * life)
    return out


def marimba(freq: float, seconds: float = 0.5, decay: float = 0.12) -> np.ndarray:
    """A woody bar: strong fundamental, a 4x partial that vanishes almost at
    once (the 'tock'), short decay."""
    t = _t(seconds)
    out = np.sin(2 * np.pi * freq * t) * _env(t, 0.003, decay)
    out += 0.25 * np.sin(2 * np.pi * freq * 3.93 * t) * _env(t, 0.001, decay * 0.15)
    return out


def boop(freq: float, seconds: float = 0.3, glide: float = 0.97) -> np.ndarray:
    """A soft rounded sine that sags a little in pitch: the friendly 'boop'."""
    t = _t(seconds)
    f = freq * (1 + (glide - 1) * np.clip(t / seconds, 0, 1))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sin(phase) + 0.12 * np.sin(2 * phase)
    return tone * _env(t, 0.02, seconds * 0.35)


def sparkle(start: float, notes: int, rng: np.random.Generator) -> np.ndarray:
    """A few tiny high bells, quiet, scattered over ``start`` seconds."""
    out = np.zeros(int((start + 0.5) * RATE))
    for _ in range(notes):
        at = int(rng.uniform(0, start) * RATE)
        voice = 0.12 * bell(rng.uniform(2600, 4200), 0.35, 0.05)
        out[at : at + len(voice)] += voice[: len(out) - at]
    return out


# --- mixing ----------------------------------------------------------------


def place(parts: list[tuple[float, np.ndarray, float]], seconds: float) -> np.ndarray:
    """Mix (start time, voice, gain) triples into one clip."""
    out = np.zeros(int(seconds * RATE))
    for start, voice, gain in parts:
        at = int(start * RATE)
        n = min(len(voice), len(out) - at)
        out[at : at + n] += gain * voice[:n]
    return out


def reverb(x: np.ndarray, wet: float, length: float = 0.35, seed: int = 7) -> np.ndarray:
    """A small room: convolve with exponentially decaying noise whose highs
    die first. Seeded, so it is the same every run."""
    rng = np.random.default_rng(seed)
    t = _t(length)
    noise = rng.standard_normal(len(t))
    # Darken over time: a one-pole low-pass whose cut-off falls with t.
    ir = np.empty_like(noise)
    y = 0.0
    for i, (n, ti) in enumerate(zip(noise, t)):
        k = 0.6 * math.exp(-ti / 0.15) + 0.08
        y += k * (n - y)
        ir[i] = y
    ir *= np.exp(-t / (length / 5))
    ir /= np.sqrt(np.sum(ir**2))
    size = len(x) + len(ir) - 1
    n = 1 << (size - 1).bit_length()
    tail = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[:size]
    out = np.zeros(size)
    out[: len(x)] = x
    return (1 - wet) * out + wet * tail


def trim(x: np.ndarray, floor_db: float = -50.0, fade: float = 0.04) -> np.ndarray:
    """Cut the tail once it has fallen ``floor_db`` under the peak, with a
    short fade, so a clip is as long as it sounds."""
    floor = float(np.max(np.abs(x))) * 10 ** (floor_db / 20)
    loud = np.nonzero(np.abs(x) > floor)[0]
    end = min(len(x), int(loud[-1]) + 1 + int(fade * RATE)) if len(loud) else len(x)
    return fade_tail(x[:end], fade)


def fade_tail(x: np.ndarray, seconds: float = 0.05) -> np.ndarray:
    n = min(len(x), int(seconds * RATE))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


# --- loudness (ITU-R BS.1770 K-weighting) ------------------------------------


def _biquad(x: np.ndarray, b: tuple, a: tuple) -> np.ndarray:
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2 = b
    _, a1, a2 = a
    for i, xi in enumerate(x):
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def _shelf_and_highpass() -> list[tuple[tuple, tuple]]:
    """The two K-weighting stages, by the RBJ formulas BS.1770 is usually
    implemented with (as in pyloudnorm), at ``RATE``."""
    filters = []
    # High shelf, +4 dB above ~1.7 kHz.
    gain, fc, q = 4.0, 1681.974450955533, 0.7071752369554196
    a_ = 10 ** (gain / 40)
    w0 = 2 * math.pi * fc / RATE
    alpha = math.sin(w0) / (2 * q)
    cw = math.cos(w0)
    b = (
        a_ * ((a_ + 1) + (a_ - 1) * cw + 2 * math.sqrt(a_) * alpha),
        -2 * a_ * ((a_ - 1) + (a_ + 1) * cw),
        a_ * ((a_ + 1) + (a_ - 1) * cw - 2 * math.sqrt(a_) * alpha),
    )
    a = (
        (a_ + 1) - (a_ - 1) * cw + 2 * math.sqrt(a_) * alpha,
        2 * ((a_ - 1) - (a_ + 1) * cw),
        (a_ + 1) - (a_ - 1) * cw - 2 * math.sqrt(a_) * alpha,
    )
    filters.append((tuple(v / a[0] for v in b), tuple(v / a[0] for v in a)))
    # High-pass at ~38 Hz.
    fc, q = 38.13547087602444, 0.5003270373238773
    w0 = 2 * math.pi * fc / RATE
    alpha = math.sin(w0) / (2 * q)
    cw = math.cos(w0)
    b = ((1 + cw) / 2, -(1 + cw), (1 + cw) / 2)
    a = (1 + alpha, -2 * cw, 1 - alpha)
    filters.append((tuple(v / a[0] for v in b), tuple(v / a[0] for v in a)))
    return filters


def loudness(x: np.ndarray) -> float:
    y = x
    for b, a in _shelf_and_highpass():
        y = _biquad(y, b, a)
    return -0.691 + 10 * math.log10(float(np.mean(y**2)) + 1e-12)


def _soft_limit(x: np.ndarray, ceiling: float) -> np.ndarray:
    """Untouched below 70 % of the ceiling; above it, a tanh knee that
    never exceeds the ceiling. Only the attack transients get there."""
    knee = 0.7 * ceiling
    over = np.abs(x) > knee
    y = x.copy()
    room = ceiling - knee
    y[over] = np.sign(x[over]) * (knee + room * np.tanh((np.abs(x[over]) - knee) / room))
    return y


def normalise(x: np.ndarray) -> tuple[np.ndarray, float, float]:
    x = trim(x)
    ceiling = 10 ** (PEAK_DBFS / 20)
    # Twice: the limiter takes a little loudness off, the second pass
    # gives it back.
    for _ in range(2):
        x = _soft_limit(x * 10 ** ((TARGET_LUFS - loudness(x)) / 20), ceiling)
    return x, loudness(x), 20 * math.log10(float(np.max(np.abs(x))))


# --- the nine sounds -----------------------------------------------------------


def right_a() -> np.ndarray:
    """Rising major third on a glass bell, C6 then E6."""
    return reverb(
        place([(0.0, bell(hz("C6")), 0.8), (0.09, bell(hz("E6")), 1.0)], 0.42), 0.18
    )


def right_b() -> np.ndarray:
    """Rising major third on a warm marimba, G5 then B5."""
    return reverb(
        place([(0.0, marimba(hz("G5"), decay=0.16), 0.8), (0.1, marimba(hz("B5"), decay=0.2), 1.0)], 0.4),
        0.15,
    )


def right_c() -> np.ndarray:
    """Bell third E6 then G#6 with a little sparkle on top."""
    rng = np.random.default_rng(31)
    return reverb(
        place(
            [
                (0.0, bell(hz("E6"), decay=0.15), 0.75),
                (0.08, bell(hz("G#6"), decay=0.2), 1.0),
                (0.1, sparkle(0.25, 3, rng), 1.0),
            ],
            0.45,
        ),
        0.2,
    )


def wrong_a() -> np.ndarray:
    """Soft low 'boop-boop', a gentle step down: A4 then F#4."""
    return reverb(
        place([(0.0, boop(hz("A4"), 0.16), 0.9), (0.15, boop(hz("F#4"), 0.2), 0.8)], 0.36), 0.12
    )


def wrong_b() -> np.ndarray:
    """Two muted woody taps on one low note (D4): 'try again'."""
    return reverb(
        place(
            [(0.0, marimba(hz("D4"), 0.25, 0.06), 0.9), (0.13, marimba(hz("D4"), 0.25, 0.08), 0.75)],
            0.3,
        ),
        0.1,
    )


def wrong_c() -> np.ndarray:
    """A soft rounded 'hmm-mm': G4 sagging gently into E4."""
    return reverb(
        place([(0.0, boop(hz("G4"), 0.2, 0.99), 0.85), (0.17, boop(hz("E4"), 0.22, 0.98), 0.8)], 0.4),
        0.12,
    )


def end_a() -> np.ndarray:
    """Bell arpeggio C5 E5 G5 C6, then a held major chord and sparkle."""
    rng = np.random.default_rng(11)
    notes = ["C5", "E5", "G5", "C6"]
    parts = [(i * 0.09, bell(hz(n), 0.7, 0.2), 0.8) for i, n in enumerate(notes)]
    chord_at = len(notes) * 0.09 + 0.02
    parts += [(chord_at, bell(hz(n), 0.9, 0.35), 0.45) for n in ["C6", "E6", "G6"]]
    parts.append((chord_at, sparkle(0.6, 6, rng), 1.0))
    return reverb(fade_tail(place(parts, 1.3)), 0.22)


def end_b() -> np.ndarray:
    """Marimba run up two octaves of G major, capped with a bell."""
    notes = ["G4", "B4", "D5", "G5", "B5", "D6"]
    parts = [(i * 0.075, marimba(hz(n), 0.4, 0.14), 0.75) for i, n in enumerate(notes)]
    parts.append((len(notes) * 0.075 + 0.03, bell(hz("G6"), 0.8, 0.3), 0.7))
    return reverb(fade_tail(place(parts, 1.2)), 0.18)


def end_c() -> np.ndarray:
    """A bigger flourish: bell arpeggio C-E-G-C-E, a little glissando of
    sparkles, and a soft final chord."""
    rng = np.random.default_rng(23)
    notes = ["C5", "E5", "G5", "C6", "E6"]
    parts = [(i * 0.08, bell(hz(n), 0.7, 0.18), 0.75) for i, n in enumerate(notes)]
    glide_at = len(notes) * 0.08
    for i in range(8):
        f = hz("G6") * 2 ** (i / 12 * 1.5)
        parts.append((glide_at + i * 0.03, bell(f, 0.3, 0.05), 0.18))
    parts += [(glide_at + 0.3, bell(hz(n), 0.9, 0.4), 0.4) for n in ["C6", "E6", "G6"]]
    parts.append((glide_at + 0.3, sparkle(0.5, 5, rng), 1.0))
    return reverb(fade_tail(place(parts, 1.5)), 0.22)


SOUNDS = {
    "right_a": right_a,
    "right_b": right_b,
    "right_c": right_c,
    "wrong_a": wrong_a,
    "wrong_b": wrong_b,
    "wrong_c": wrong_c,
    "end_a": end_a,
    "end_b": end_b,
    "end_c": end_c,
}


def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = np.round(np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    out.mkdir(parents=True, exist_ok=True)
    ffmpeg = shutil.which("ffmpeg")
    for name, make in SOUNDS.items():
        x, lufs, peak = normalise(make())
        wav = out / f"{name}.wav"
        write_wav(wav, x)
        if ffmpeg:
            for ext, args in (("ogg", ["-c:a", "libvorbis", "-b:a", "128k"]), ("mp3", ["-c:a", "libmp3lame", "-b:a", "128k"])):
                subprocess.run(
                    [ffmpeg, "-y", "-loglevel", "error", "-i", str(wav), *args, str(out / f"{name}.{ext}")],
                    check=True,
                )
        print(f"{name:8s} {len(x) / RATE:5.2f} s  {lufs:6.1f} LUFS  peak {peak:5.1f} dBFS")


if __name__ == "__main__":
    main()
