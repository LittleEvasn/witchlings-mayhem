"""Original sparse music sketches, no samples or third-party music. Reproducible PCM assets."""
from pathlib import Path
import math, struct, wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050

def compose(name, bpm, melody, bass, level):
    beat = 60 / bpm
    seconds = 64 * beat
    samples = [0.0] * int(seconds * RATE)
    def note(start, midi, length, volume, bright=False):
        if midi is None:
            return
        hz = 440 * 2 ** ((midi - 69) / 12)
        begin = int(start * RATE)
        count = int(length * RATE)
        for n in range(min(count, len(samples)-begin)):
            t = n / RATE
            attack = min(1.0, t / .018)
            release = min(1.0, (length-t) / .13)
            env = attack * release * math.exp(-t * (2.5 if bright else 1.2))
            phase = 2 * math.pi * hz * t
            tone = math.sin(phase) + (.22 if bright else .09) * math.sin(phase*2)
            samples[begin+n] += tone * env * volume
    for bar in range(16):
        base = bass[bar % len(bass)]
        note(bar*4*beat, base, beat*3.7, .11)
        for i, interval in enumerate([0, 7, 12, 7]):
            note((bar*4+i)*beat, base+24+interval, beat*.8, .045, True)
        for i in range(4):
            step = melody[(bar*4+i) % len(melody)]
            note((bar*4+i)*beat, step, beat*.7, level, True)
    # Exactly 16 bars; a tiny edge fade avoids clicks at the repeating boundary.
    pcm = bytearray()
    for i, sample in enumerate(samples):
        fade = min(1.0, i/(RATE*.02), (len(samples)-1-i)/(RATE*.05))
        pcm += struct.pack('<h', int(max(-.9,min(.9,sample))*fade*32767))
    folder = ROOT/'assets/audio'
    folder.mkdir(parents=True,exist_ok=True)
    with wave.open(str(folder/(name+'.wav')), 'wb') as out:
        out.setparams((1,2,RATE,0,'NONE','not compressed'))
        out.writeframes(pcm)
    print(name, round(seconds,2), 'seconds')

if __name__ == '__main__':
    compose('prepare', 88, [76,None,79,83,81,None,79,74,76,None,72,74,71,None,74,79], [45,41,48,43], .075)
    compose('combat', 112, [76,79,83,79,81,79,76,None,74,77,81,77,79,76,74,71], [45,41,48,43], .085)
    compose('boss', 132, [76,75,76,83,81,79,77,75,76,79,83,84,83,79,77,75], [45,41,44,40], .09)
