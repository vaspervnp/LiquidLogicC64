"""Παράγει τα δεδομένα ήχου του Liquid Logic για τον SID του C64.

    python3 assets/src/make_sound.py   # -> assets/data/sound_data.asm

Τα ίδια εφέ, η ίδια μελωδία και το ίδιο μπάσο με τον AY του CPC
(../LiquidLogicCPC/assets/src/make_sound.py): εκεί περίοδοι τόνου του AY
(1 MHz / 16P), εδώ συχνότητες του SID (PAL: f * 2^24 / 985248). Η ένταση
ανά καρέ γίνεται sustain του ADSR (sound.asm).

  note_lo/hi   συχνότητες για τις νότες 1..72 (C1..B6, 0 = παύση)
  sfx_*        εφέ για τη φωνή 2: ανά καρέ .byte freq lo, freq hi, ένταση
               (bit 7 της έντασης = θόρυβος)· ένταση $ff = τέλος
  plip_lo/hi   το γουργουρητό: συχνότητα ανά 4 γραμμές της στάθμης
  music_a/c    η μελωδία (φωνή 1) και το μπάσο (φωνή 3): .byte νότα, καρέ;
               $ff = από την αρχή
"""

import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "data", "sound_data.asm")

NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
PAL_CLOCK = 985248
AY_CLOCK = 1_000_000


def note(name):
    """'A4' -> δείκτης 1..72 (C1 = 1)."""
    octave = int(name[-1])
    return (octave - 1) * 12 + NAMES.index(name[:-1]) + 1


def freq(index):
    midi = index + 23                   # C1 = MIDI 24
    return 440.0 * 2 ** ((midi - 69) / 12)


def sid(f):
    return max(1, min(0xFFFF, round(f * 16777216 / PAL_CLOCK)))


def ay_freq(period):
    return AY_CLOCK / (16 * period)


# Μελωδία: (νότα, βήματα)· ένα βήμα = STEP καρέ (όπως στον CPC).
STEP = 7
MELODY = [
    ("E5", 1), ("G5", 1), ("A5", 2), ("G5", 1), ("E5", 1), ("D5", 2),
    ("C5", 1), ("D5", 1), ("E5", 2), ("A4", 4),
    ("C5", 1), ("E5", 1), ("G5", 2), ("A5", 1), ("G5", 1), ("E5", 2),
    ("D5", 1), ("C5", 1), ("D5", 2), ("E5", 4),
    ("A5", 1), ("G5", 1), ("E5", 2), ("G5", 1), ("E5", 1), ("D5", 2),
    ("C5", 1), ("D5", 1), ("E5", 2), ("G4", 4),
    ("A4", 1), ("C5", 1), ("E5", 2), ("D5", 1), ("C5", 1), ("B4", 2),
    ("C5", 2), ("B4", 2), ("A4", 4),
]
BASS = ["A2", "F2", "C3", "G2", "A2", "F2", "G2", "C3",
        "F2", "G2", "C3", "A2", "F2", "G2", "E2", "A2"]


def tone(f, vol):
    return (sid(f), vol)


def noise(p, vol):
    # θόρυβος του AY με περίοδο p: ~ 1 MHz / (16 p) -> ο SID θέλει ~ 4x
    return (sid(min(3900, 4 * ay_freq(p))), vol | 0x80)


def sweep(f0, f1, frames, v0, v1):
    out = []
    for k in range(frames):
        t = k / max(1, frames - 1)
        out.append(tone(f0 * (f1 / f0) ** t, round(v0 + (v1 - v0) * t)))
    return out


def arp(names, frames, v0=13, decay=1):
    out = []
    for n in names:
        for k in range(frames):
            out.append(tone(freq(note(n)), max(0, v0 - k * decay)))
    return out


SFX = {
    "select": sweep(600, 1200, 4, 12, 8),
    "cancel": sweep(900, 450, 4, 10, 5),
    "error": [tone(110 if k % 2 else 104, 13 - k) for k in range(10)],
    "cork": [noise(6, 14), noise(3, 11)] + sweep(1400, 1800, 5, 12, 4),
    "win": arp(["C5", "E5", "G5", "C6"], 5, 13, 1) + arp(["E6"], 12, 13, 1),
    "chime": arp(["G5", "D6"], 6, 12, 2),
    "undo": sweep(1000, 500, 5, 11, 6),
    "extra": sweep(300, 900, 10, 13, 8),
    "timeup": arp(["E4", "D4", "C4", "A3"], 7, 13, 1),
    "tick": [tone(2000, 9), tone(2000, 4)],
}

PLIP_BASE = 320     # περίοδος του AY στον άδειο στόχο, -4 ανά γραμμή


def main():
    L = [
        "; sound_data.asm — ΠΑΡΑΓΕΤΑΙ από το assets/src/make_sound.py, μην το αλλάζεις με το χέρι",
        "",
        f"MUSIC_STEP      = {STEP}",
        "",
        "; συχνότητες του SID για τις νότες 0..72 (0 = παύση, 1 = C1)",
    ]
    table = [0] + [sid(freq(i)) for i in range(1, 73)]
    L.append("note_lo .byte " + ",".join(f"${x & 0xFF:02X}" for x in table))
    L.append("note_hi .byte " + ",".join(f"${x >> 8:02X}" for x in table))
    plip = [sid(ay_freq(PLIP_BASE - 4 * 4 * i)) for i in range(16)]
    L.append("; το γουργουρητό: ανά 4 γραμμές της στάθμης (περίοδος AY 320 - 4 x γραμμές)")
    L.append("plip_lo .byte " + ",".join(f"${x & 0xFF:02X}" for x in plip))
    L.append("plip_hi .byte " + ",".join(f"${x >> 8:02X}" for x in plip))
    for name, frames in SFX.items():
        L.append("")
        L.append(f"sfx_{name}")
        for f, v in frames:
            vol = (v & 0x80) | max(0, min(15, v & 0x7F))
            L.append(f"        .byte ${f & 0xFF:02X},${f >> 8:02X},${vol:02X}")
        L.append("        .byte 0,0,$ff")
    L.append("")
    L.append("; μελωδία του τίτλου (φωνή 1): νότα, καρέ")
    L.append("music_a")
    for n, steps in MELODY:
        L.append(f"        .byte {note(n)},{steps * STEP}    ; {n}")
    L.append("        .byte $ff")
    assert sum(s for _, s in MELODY) == 4 * len(BASS)
    L.append("")
    L.append("; μπάσο (φωνή 3)")
    L.append("music_c")
    for n in BASS:
        L.append(f"        .byte {note(n)},{4 * STEP}    ; {n}")
    L.append("        .byte $ff")
    with open(OUT, "w") as f:
        f.write("\n".join(L) + "\n")
    print(OUT)


if __name__ == "__main__":
    main()
