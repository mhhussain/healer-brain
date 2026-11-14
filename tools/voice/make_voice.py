"""Makes the game's voice lines with Kokoro, through the Kokoro text-to-speech service.

It reads game/assets/voice/voice_lines.json (id, speaker, text) and writes
game/assets/voice/<id>.wav for every line. A line is only made again if its text or its voice has
changed since last time; voice_built.json keeps what each file was made from.

    python3 tools/voice/make_voice.py                      # make what is new or changed
    python3 tools/voice/make_voice.py --force              # make everything again
    python3 tools/voice/make_voice.py warden_pull_1        # only these lines

It needs nothing installed beyond Python 3.9. The service's address and key are read from the
environment, or from threads.env at the top of the repo (which git ignores):

    KOKORO_API_URL=https://...
    KOKORO_API_KEY=...

To use recordings from somewhere else instead, such as ElevenLabs, put files with the same
names in game/assets/voice/.
"""
import array
import json
import os
import struct
import sys
import urllib.error
import urllib.request
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "game" / "assets" / "voice"

# Who sounds like what: Kokoro voice and speed (1 is the voice's own pace).
# GET <service>/v1/audio/voices lists the voices and how good each is.
CAST = {
    "narrator":    ("bm_george",   0.90),  # the storyteller: unhurried
    "warden":      ("am_fenrir",   0.95),  # Hale Dunmarrow: gruff and steady
    "mender":      ("bf_emma",     0.97),  # Sister Wren: gentle
    "bloomweaver": ("bf_isabella", 0.88),  # Old Maren: slow and fond
    "duelist":     ("bm_fable",    1.05),  # Corvin Ashby: quick and dry
    "ranger":      ("af_bella",    0.95),  # Isolde Fenn: few words
    "pyromancer":  ("am_puck",     1.08),  # Tobias Wick: nervous
}

# Quiet is cut from both ends, and every line is brought to the same loudness at its peak.
SILENCE = 400      # out of 32767
PEAK = 29000
PAD = 0.06         # seconds of quiet kept at each end


def settings() -> tuple:
    """The service's address and key, from the environment or from threads.env."""
    found = {}
    env_file = ROOT / "threads.env"
    if env_file.exists():
        for row in env_file.read_text().splitlines():
            if "=" in row and not row.lstrip().startswith("#"):
                name, value = row.split("=", 1)
                found[name.strip()] = value.strip()
    url = os.environ.get("KOKORO_API_URL") or found.get("KOKORO_API_URL")
    key = os.environ.get("KOKORO_API_KEY") or found.get("KOKORO_API_KEY")
    if not url or not key:
        sys.exit("Set KOKORO_API_URL and KOKORO_API_KEY, in the environment or in threads.env.")
    return url.rstrip("/"), key


def speak(url: str, key: str, text: str, voice: str, speed: float) -> bytes:
    """Asks the service for one line and returns its WAV file."""
    body = json.dumps({"model": "kokoro", "input": text, "voice": voice, "speed": speed, "response_format": "wav"})
    request = urllib.request.Request(url + "/v1/audio/speech", data=body.encode(), method="POST",
                                     headers={"Authorization": "Bearer " + key, "Content-Type": "application/json",
                                              # the service's front door turns away Python's default name
                                              "User-Agent": "fourfold-make-voice/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=120) as answer:
            return answer.read()
    except urllib.error.HTTPError as e:
        # the answer may say why; the key is never printed
        sys.exit(f"The voice service answered {e.code}: {e.read()[:200].decode(errors='replace')}")


def samples_of(wav: bytes) -> tuple:
    """The sample rate and the 16-bit mono samples of a WAV file, whatever else is in it."""
    if wav[:4] != b"RIFF" or wav[8:12] != b"WAVE":
        sys.exit("The voice service did not send a WAV file.")
    at, rate, data = 12, 24000, b""
    while at + 8 <= len(wav):
        name, size = wav[at:at + 4], struct.unpack("<I", wav[at + 4:at + 8])[0]
        start = at + 8
        if name == b"fmt ":
            kind, channels, rate, _, _, bits = struct.unpack("<HHIIHH", wav[start:start + 16])
            if kind != 1 or channels != 1 or bits != 16:
                sys.exit(f"Expected 16-bit mono sound, got {bits}-bit with {channels} channels.")
        elif name == b"data":
            # a streamed file does not know its own length: take what is left
            data = wav[start:] if size > len(wav) - start else wav[start:start + size]
            break
        at = start + size + (size & 1)
    samples = array.array("h")
    samples.frombytes(data[:len(data) // 2 * 2])
    if sys.byteorder == "big":
        samples.byteswap()
    return rate, samples


def tidy(samples: array.array, rate: int) -> array.array:
    loud = [i for i, s in enumerate(samples) if abs(s) > SILENCE]
    if loud:
        pad = int(PAD * rate)
        samples = samples[max(0, loud[0] - pad): loud[-1] + pad]
    top = max((abs(s) for s in samples), default=0)
    if top > 0:
        samples = array.array("h", (int(s * PEAK / top) for s in samples))
    return samples


def main() -> None:
    args = sys.argv[1:]
    force = "--force" in args
    only = [a for a in args if not a.startswith("--")]
    lines = json.loads((OUT / "voice_lines.json").read_text())
    built_file = OUT / "voice_built.json"
    built = json.loads(built_file.read_text()) if built_file.exists() else {}
    known = {line["id"] for line in lines}
    for unknown in [i for i in only if i not in known]:
        sys.exit(f"no line called {unknown} in voice_lines.json")

    url, key = settings()
    made = 0
    for line in lines:
        voice, speed = CAST[line["speaker"]]
        recipe = {"text": line["text"], "voice": voice, "speed": speed}
        target = OUT / f"{line['id']}.wav"
        if only and line["id"] not in only:
            continue
        if not force and not only and target.exists() and built.get(line["id"]) == recipe:
            continue
        rate, samples = samples_of(speak(url, key, line["text"], voice, speed))
        samples = tidy(samples, rate)
        if sys.byteorder == "big":
            samples.byteswap()
        with wave.open(str(target), "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(rate)
            out.writeframes(samples.tobytes())
        built[line["id"]] = recipe
        made += 1
        print(f"{line['id']}: {len(samples) / rate:.1f} s, {voice}")

    # forget files for lines that are no longer in the story
    for gone in [i for i in built if i not in known]:
        (OUT / f"{gone}.wav").unlink(missing_ok=True)
        del built[gone]
        print(f"{gone}: removed, no longer in the story")
    built_file.write_text(json.dumps(built, indent=2, sort_keys=True) + "\n")
    print(f"made {made} of {len(lines)} lines")


if __name__ == "__main__":
    main()
