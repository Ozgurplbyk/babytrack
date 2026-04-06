#!/usr/bin/env python3
"""
Generate local audio library:
- white noise
- brown noise
- hair dryer style noise
- lullaby instrumental placeholders for each country catalog entry
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def write_wav(path: Path, samples: list[float], sample_rate: int = SAMPLE_RATE) -> None:
    ensure_parent(path)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        data = bytearray()
        for s in samples:
            v = int(clamp(s, -1.0, 1.0) * 32767)
            data.extend(struct.pack("<h", v))
        wf.writeframes(bytes(data))


def generate_white_noise(duration_sec: float, volume: float = 0.18) -> list[float]:
    count = int(SAMPLE_RATE * duration_sec)
    return [random.uniform(-1, 1) * volume for _ in range(count)]


def generate_brown_noise(duration_sec: float, volume: float = 0.22) -> list[float]:
    count = int(SAMPLE_RATE * duration_sec)
    out = []
    last = 0.0
    for _ in range(count):
        white = random.uniform(-1, 1) * 0.035
        last = clamp(last + white, -1.0, 1.0)
        out.append(last * volume)
    return out


def generate_hair_dryer_noise(duration_sec: float) -> list[float]:
    count = int(SAMPLE_RATE * duration_sec)
    out: list[float] = []
    lp = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        white = random.uniform(-1, 1)
        lp = (lp * 0.98) + (white * 0.02)
        hum = 0.12 * math.sin(2 * math.pi * 95 * t)
        hiss = 0.08 * white
        out.append(clamp(hum + hiss + 0.18 * lp, -1.0, 1.0))
    return out


def midi_to_hz(midi: int) -> float:
    return 440.0 * (2 ** ((midi - 69) / 12.0))


def sine(freq: float, t: float) -> float:
    return math.sin(2 * math.pi * freq * t)


def melody_seed(title: str, country_code: str) -> int:
    key = f"{country_code}:{title}".encode("utf-8")
    digest = hashlib.sha256(key).hexdigest()
    return int(digest[:12], 16)


def generate_lullaby_placeholder(title: str, country_code: str, duration_sec: float = 30.0) -> list[float]:
    rnd = random.Random(melody_seed(title, country_code))

    # Soft pentatonic-like pools per country flavor.
    pools = {
        "TR": [57, 59, 60, 62, 64, 67, 69],
        "US": [60, 62, 64, 67, 69, 72],
        "GB": [60, 62, 65, 67, 69, 72],
        "DE": [59, 62, 64, 67, 71, 72]
    }
    notes = pools.get(country_code.upper(), [60, 62, 64, 67, 69, 72])

    beat_sec = 0.5
    steps = int(duration_sec / beat_sec)
    seq = [rnd.choice(notes) for _ in range(steps)]

    samples: list[float] = []
    for step, midi in enumerate(seq):
        freq = midi_to_hz(midi)
        start_t = step * beat_sec
        frames = int(beat_sec * SAMPLE_RATE)

        for i in range(frames):
            t = i / SAMPLE_RATE
            global_t = start_t + t
            env = 1.0
            if t < 0.05:
                env = t / 0.05
            elif t > beat_sec - 0.09:
                env = max(0.0, (beat_sec - t) / 0.09)

            base = 0.16 * sine(freq, global_t)
            over = 0.05 * sine(freq * 2.0, global_t)
            shimmer = 0.02 * sine(freq * 0.5, global_t)
            sample = (base + over + shimmer) * env
            samples.append(sample)

    # subtle reverb tail simulation (simple echo)
    delay = int(0.18 * SAMPLE_RATE)
    out = samples[:]
    for i in range(delay, len(out)):
        out[i] += samples[i - delay] * 0.22
    return [clamp(v, -1.0, 1.0) for v in out]


def load_catalog(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate BabyTrack audio library")
    parser.add_argument("--catalog", required=True, help="Path to lullaby catalog JSON")
    parser.add_argument("--out", required=True, help="Audio output root")
    parser.add_argument("--noise-duration", type=float, default=180.0)
    parser.add_argument("--lullaby-duration", type=float, default=30.0)
    args = parser.parse_args()

    out_root = Path(args.out)
    catalog = load_catalog(Path(args.catalog))

    # Noise assets
    write_wav(out_root / "noise" / "white_noise.wav", generate_white_noise(args.noise_duration))
    write_wav(out_root / "noise" / "brown_noise.wav", generate_brown_noise(args.noise_duration))
    write_wav(out_root / "noise" / "hair_dryer.wav", generate_hair_dryer_noise(args.noise_duration))

    # Lullaby assets
    total = 0
    for country in catalog.get("countries", []):
        cc = country["countryCode"]
        for track in country.get("topLullabies", []):
            rel = track["audioAssetPath"].replace("Audio/", "") + ".wav"
            out_path = out_root / rel
            samples = generate_lullaby_placeholder(track["title"], cc, args.lullaby_duration)
            write_wav(out_path, samples)
            total += 1

    print(f"Generated noise assets: 3")
    print(f"Generated lullaby assets: {total}")
    print(f"Output: {out_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
