#!/usr/bin/env python3
"""Builds the app's bundled sounds from Hafid's masters (ADR 0035).

Hafid picked them by ear from ``Assets/Sounds/listen_all.html``
(2026-10-26). This script turns those masters into what the app ships:

- AAC-LC in .m4a, mono, so every target decodes it (ADR 0035's revision);
- matched loudness: effects and songs at -19 LUFS, like the generated
  effects and 4 dB under the Piper narration; music at -20 LUFS, since the
  app also plays it at 0.35 of the master volume;
- music loops made seamless: leading silence trimmed, then the last 250 ms
  crossfaded into the first at equal power, so the wrap has no jump;
- then the loop rotated so the file starts and ends at its quietest moment,
  with 4 ms fades to zero either side. AAC doesn't know a file loops, so it
  doesn't keep the edge samples exact: village-2's wrap measured 0.041 in
  Chrome against a typical step of 0.016, a click, from a 0.008 seam in the
  PCM. At a quiet point with zero on both sides there's nothing for the
  codec to break, and the first play no longer starts mid-signal either;
- trailing silence trimmed from one-shot sounds, so a clip's length is
  what you hear;
- 100 ms of digital silence before the two answer sounds, whose attack
  starts in the first milliseconds: an output that is still waking (a
  Bluetooth headset, PipeWire after idle) drops its first ~100-300 ms, and
  the whole two-note marimba lasts about 0.3 s. Web also keeps the output
  awake (ADR 0043); this is the safety net for native targets.

Usage::

    python3 tools/sounds/build_app_sounds.py [SOUNDS_DIR]

``SOUNDS_DIR`` defaults to ``../../Assets/Sounds`` from the repo root (the
Platforms layout). Writes into ``assets/sounds/``. Needs numpy and ffmpeg.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets" / "sounds"
RATE = 48_000

MUSIC_LUFS = -20.0
FOREGROUND_LUFS = -19.0
SILENCE_DB = -55.0
LOOP_CROSSFADE_S = 0.25
LOOP_EDGE_FADE_S = 0.004
# Digital silence put before a clip, by output path. Only where the attack
# is at the very start: activity-complete already has ~105 ms, and the
# songs open on a quiet fade.
LEAD_IN_S = {
    "sfx/answer-right.m4a": 0.1,
    "sfx/answer-retry.m4a": 0.1,
}

# (source relative to SOUNDS_DIR, output relative to assets/sounds, kind, kbps)
SOUNDS = [
    # Background loops: #4 and #6 of the six, in sorted order.
    (
        "Bg music/ElevenLabs_audio_elevenlabs-music-v2-5_Seamless loopin_"
        "2026-10-25T23_16_40.mp3",
        "music/village-1.m4a",
        "loop",
        64,
    ),
    (
        "Bg music/ElevenLabs_audio_elevenlabs-music-v2-5_Seamless loopin_"
        "2026-10-25T23_35_26.mp3",
        "music/village-2.m4a",
        "loop",
        64,
    ),
    ("generated/right_b.wav", "sfx/answer-right.m4a", "oneshot", 80),
    ("generated/wrong_a.wav", "sfx/answer-retry.m4a", "oneshot", 80),
    # His own winning.mp3, already levelled; not the raw Pixabay file.
    ("generated/hafid_win_matched.wav", "sfx/activity-complete.m4a", "oneshot", 80),
    # The Village mascot's song, one per app language.
    ("Songs/Joue avec TutoLys ! 2n style.mp3", "songs/mascot-fr.m4a", "song", 96),
    ("Songs/Play with TutoLys!.mp3", "songs/mascot-en.m4a", "song", 96),
]


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
         "-f", "f32le", "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, dtype="<f4").astype(np.float64)


def db(x: float) -> float:
    return 20 * np.log10(max(x, 1e-12))


def trim(x: np.ndarray, lead: bool, tail: bool) -> np.ndarray:
    """Cuts samples quieter than SILENCE_DB off either end, at 10 ms grain."""
    thresh = 10 ** (SILENCE_DB / 20)
    loud = np.flatnonzero(np.abs(x) > thresh)
    if loud.size == 0:
        return x
    start = loud[0] if lead else 0
    end = min(len(x), loud[-1] + RATE // 100) if tail else len(x)
    return x[start:end]


def make_seamless(x: np.ndarray) -> np.ndarray:
    """Folds the last LOOP_CROSSFADE_S into the first, at equal power.

    The result is shorter by the fade; its last sample runs straight into
    the original sample that followed it, which is now the first.
    """
    n = int(LOOP_CROSSFADE_S * RATE)
    t = np.linspace(0, np.pi / 2, n, endpoint=False)
    head = x[:n] * np.sin(t) + x[-n:] * np.cos(t)
    return np.concatenate([head, x[n:-n]])


def rotate_to_quiet(x: np.ndarray) -> np.ndarray:
    """Starts a seamless loop at its quietest 20 ms, fading the edges.

    Rotating a seamless loop changes nothing audible: the old wrap is now
    an ordinary interior point. The new one sits where the music is
    quietest (lowest 20 ms RMS), nudged to the nearest zero crossing, and
    the 4 ms fades meet at zero, so the codec's edge error has nothing loud
    to distort.
    """
    win = int(0.02 * RATE)
    power = np.convolve(x**2, np.ones(win) / win, mode="same")
    i = int(np.argmin(power))
    crossings = np.flatnonzero(np.diff(np.signbit(x)))
    if crossings.size:
        i = int(crossings[np.argmin(np.abs(crossings - i))]) + 1
    x = np.roll(x, -i)
    n = int(LOOP_EDGE_FADE_S * RATE)
    ramp = np.sin(np.linspace(0, np.pi / 2, n)) ** 2
    x[:n] *= ramp
    x[-n:] *= ramp[::-1]
    return x


def loudness(path: Path) -> float:
    err = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", str(path), "-af",
         "ebur128=framelog=quiet", "-f", "null", "-"],
        capture_output=True, text=True,
    ).stderr
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", err)[-1])


def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def build(src: Path, out: Path, kind: str, kbps: int, tmp: Path) -> dict:
    x = decode(src)
    if kind == "loop":
        x = rotate_to_quiet(make_seamless(trim(x, lead=True, tail=True)))
    else:
        x = trim(x, lead=False, tail=True)
    # Level by measurement: write, measure, scale. Linear gain keeps a
    # loop's seam as smooth as it was.
    probe = tmp / "probe.wav"
    write_wav(probe, x)
    target = MUSIC_LUFS if kind == "loop" else FOREGROUND_LUFS
    x = x * 10 ** ((target - loudness(probe)) / 20)
    peak = float(np.max(np.abs(x)))
    if peak > 10 ** (-1 / 20):
        x = x * (10 ** (-1 / 20) / peak)
    # After levelling: LUFS is gated, so silence wouldn't move it, but this
    # keeps the measurement about the sound alone.
    lead = int(LEAD_IN_S.get(str(out.relative_to(OUT)), 0) * RATE)
    x = np.concatenate([np.zeros(lead), x])
    final = tmp / "final.wav"
    write_wav(final, x)
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", str(final), "-c:a", "aac",
         "-b:a", f"{kbps}k", "-movflags", "+faststart", str(out)],
        check=True,
    )
    seam = float(abs(x[0] - x[-1])) if kind == "loop" else None
    return {
        "out": str(out.relative_to(REPO)),
        "seconds": round(len(x) / RATE, 3),
        "lead_in_ms": round(lead / RATE * 1000),
        "lufs": loudness(final),
        "peak_dbfs": round(db(float(np.max(np.abs(x)))), 1),
        "seam_jump": None if seam is None else round(seam, 4),
        "bytes": out.stat().st_size,
    }


def main() -> None:
    sounds = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO.parents[1] / "Assets" / "Sounds"
    with tempfile.TemporaryDirectory() as tmp:
        for src, out, kind, kbps in SOUNDS:
            print(json.dumps(build(sounds / src, OUT / out, kind, kbps, Path(tmp))))


if __name__ == "__main__":
    main()
