import math
import random
import struct
import wave
from pathlib import Path


SAMPLE_RATE = 44100
AMPLITUDE = 0.5
OUT_DIR = Path(__file__).resolve().parent


def clamp16(value: float) -> int:
    value = max(-1.0, min(1.0, value))
    return int(round(value * 32767.0))


def write_stereo_pcm16(path: Path, frames: list[tuple[float, float]]) -> None:
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        data = bytearray()
        for left, right in frames:
            data += struct.pack("<hh", clamp16(left), clamp16(right))
        wav.writeframes(data)


def sine_440hz() -> list[tuple[float, float]]:
    frames = []
    for i in range(SAMPLE_RATE):
        value = math.sin(2.0 * math.pi * 440.0 * i / SAMPLE_RATE) * AMPLITUDE
        frames.append((value, value))
    return frames


def square_440hz() -> list[tuple[float, float]]:
    frames = []
    for i in range(SAMPLE_RATE):
        phase = math.sin(2.0 * math.pi * 440.0 * i / SAMPLE_RATE)
        value = AMPLITUDE if phase >= 0.0 else -AMPLITUDE
        frames.append((value, value))
    return frames


def impulse() -> list[tuple[float, float]]:
    frames = [(0.0, 0.0) for _ in range(SAMPLE_RATE)]
    frames[0] = (1.0, 1.0)
    return frames


def impulse_tail_3s() -> list[tuple[float, float]]:
    frames = [(0.0, 0.0) for _ in range(SAMPLE_RATE * 3)]
    frames[0] = (1.0, 1.0)
    return frames


def stereo_impulse_lr() -> list[tuple[float, float]]:
    frames = [(0.0, 0.0) for _ in range(SAMPLE_RATE)]
    frames[int(SAMPLE_RATE * 0.10)] = (1.0, 0.0)
    frames[int(SAMPLE_RATE * 0.20)] = (0.0, 1.0)
    return frames


def level_steps_3s() -> list[tuple[float, float]]:
    frames = []
    for i in range(SAMPLE_RATE * 3):
        second = i // SAMPLE_RATE
        if second == 0:
            amplitude = 0.1
        elif second == 1:
            amplitude = 0.5
        else:
            amplitude = 0.9

        value = math.sin(2.0 * math.pi * 440.0 * i / SAMPLE_RATE) * amplitude
        frames.append((value, value))
    return frames


def echo_check_3s() -> list[tuple[float, float]]:
    frames = [(0.0, 0.0) for _ in range(SAMPLE_RATE * 3)]
    burst_starts = [
        int(SAMPLE_RATE * 0.05),
        int(SAMPLE_RATE * 0.35),
        int(SAMPLE_RATE * 0.65),
    ]
    burst_len = int(SAMPLE_RATE * 0.08)

    for start in burst_starts:
        for offset in range(burst_len):
            i = start + offset
            if i >= SAMPLE_RATE:
                break

            fade = min(offset / 200.0, (burst_len - offset) / 200.0, 1.0)
            value = math.sin(2.0 * math.pi * 880.0 * i / SAMPLE_RATE) * AMPLITUDE * fade
            frames[i] = (value, value)

    return frames


def echo_tail_silent_noise_3s() -> list[tuple[float, float]]:
    frames = []
    noise_amp = 10 ** (-90.0 / 20.0)
    random.seed(20260707)

    for i in range(SAMPLE_RATE * 3):
        if i < SAMPLE_RATE:
            value = math.sin(2.0 * math.pi * 880.0 * i / SAMPLE_RATE) * AMPLITUDE
            if i < 200:
                value *= i / 200.0
            elif i >= SAMPLE_RATE - 200:
                value *= (SAMPLE_RATE - i) / 200.0
        else:
            value = random.uniform(-noise_amp, noise_amp)

        frames.append((value, value))

    return frames


def main() -> None:
    write_stereo_pcm16(OUT_DIR / "sine_440hz_1s.wav", sine_440hz())
    write_stereo_pcm16(OUT_DIR / "square_440hz_1s.wav", square_440hz())
    write_stereo_pcm16(OUT_DIR / "impulse_1s.wav", impulse())
    write_stereo_pcm16(OUT_DIR / "impulse_tail_3s.wav", impulse_tail_3s())
    write_stereo_pcm16(OUT_DIR / "stereo_impulse_lr_1s.wav", stereo_impulse_lr())
    write_stereo_pcm16(OUT_DIR / "level_steps_3s.wav", level_steps_3s())
    write_stereo_pcm16(OUT_DIR / "echo_check_3s.wav", echo_check_3s())
    write_stereo_pcm16(OUT_DIR / "echo_tail_silent_noise_3s.wav", echo_tail_silent_noise_3s())


if __name__ == "__main__":
    main()
