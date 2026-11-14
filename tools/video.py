#!/usr/bin/env python3
"""Βίντεο 4 λεπτών του Liquid Logic από τον headless VICE.

    python3 tools/video.py          # -> build/liquidlogic.mp4 (χρειάζεται ffmpeg)

Παίζει σαν παίκτης με τα πλήκτρα (tools/c64test.py): τίτλος, οδηγίες,
επιλογές, η πίστα 1 (άκυρη κίνηση, undo, λύση), η πίστα 6 ολόκληρη, κομμάτια
από πίστες με κάρτες ειδικών τύπων (κρυμμένες, πάγος, λουκέτο, σταγονόμετρο,
κουρτίνα, χρονόμετρο), η 100 με το έξτρα μπουκάλι, η «Χαλάρωση» με seed, τα
στατιστικά, το τέλος και η πίστα 100 με το θέμα NEON.

Κάθε καρέ του VIC (checkpoint στο irq_frame, 50,12 το δευτερόλεπτο) πάει στο
ffmpeg, μαζί με τους καταχωρητές του SID (ο monitor δίνει ό,τι γράφτηκε
τελευταίο). Ο ήχος βγαίνει από αυτούς με έναν απλό SID (render_sid): ο
driver (sound.asm) χρησιμοποιεί μόνο παλμό 50 %, θόρυβο και το sustain ως
ένταση, με attack/decay/release στο ελάχιστο. (Ο VICE χωρίς παράθυρο δεν
γράφει δείγματα στο -sounddev wav.)
"""
import math
import os
import struct
import subprocess
import sys
import wave

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import c64palette  # noqa: E402
import c64test as t  # noqa: E402
import levels  # noqa: E402
import vice  # noqa: E402

OUT = os.path.join(t.ROOT, "build")
MP4 = os.path.join(OUT, "liquidlogic.mp4")
WAV = os.path.join(OUT, "video_sound.wav")
SILENT = os.path.join(OUT, "video_silent.mp4")

CLOCK = 985248                      # PAL
FRAME_CYCLES = 312 * 63
FPS = CLOCK / FRAME_CYCLES          # 50,1246
SECONDS = float(os.environ.get("VIDEO_SECONDS", 240))   # (για δοκιμές)
FRAMES = round(SECONDS * FPS)
RATE = 44100
W, H = 352, 232                     # όπως το screenshot του c64test: 16 pixels border γύρω


class Done(Exception):
    pass


class Recorder(t.Player):
    """Player που γράφει κάθε καρέ του VIC (εικόνα και SID)."""

    def __init__(self, ff):
        super().__init__()
        self.ff = ff
        self.sid = []
        self.cp_irq = self.vm.checkpoint("irq_frame")
        self.cp_done = self.vm.checkpoint("frame_done")
        self.pal = c64palette.flat_palette()

    @property
    def video_frames(self):
        return len(self.sid)

    def left(self):
        return FRAMES - len(self.sid)

    def capture(self):
        if len(self.sid) >= FRAMES:
            raise Done
        dw, dh, xo, yo, iw, ih, pix = self.vm.display()
        rows = len(pix) // dw
        im = Image.frombytes("P", (dw, rows), bytes(pix[:rows * dw]))
        im.putpalette(self.pal)
        im = im.crop((xo - 16, yo - 16, xo + 336, yo + 216)).convert("RGB")
        self.ff.stdin.write(im.tobytes())
        self.sid.append(self.vm.peek(0xD400, 25, bank="io"))

    def run(self, n=1, keys=()):
        self.keys(list(keys))
        done = 0
        vm = self.vm
        while done < n:
            vm._pending.clear()
            vm.cont()
            _, body = vm.wait_event((vice.EV_CHECKPOINT,), 30)
            cp = struct.unpack("<I", body[:4])[0]
            vm.wait_event((vice.EV_STOPPED,), 30)
            if cp == self.cp_irq:
                self.capture()
            elif cp == self.cp_done:
                done += 1
        self.frames += n

    def wait(self, seconds):
        """Τόσα δευτερόλεπτα βίντεο (όχι γύροι του βρόχου)."""
        end = len(self.sid) + round(seconds * FPS)
        while len(self.sid) < end:
            self.run(1)

    def key(self, k):
        self.press(k, hold=2, after=6)          # με ρυθμό ανθρώπου


# -- σενάριο ----------------------------------------------------------------

def human(g, moves, gap=0.3, keep=0.0):
    """Μεταγγίσεις με μικρή ανάσα ανάμεσα· σταματάει όταν μένουν λιγότερα
    από keep δευτερόλεπτα."""
    for i, j, *_ in moves:
        if g.left() < keep * FPS:
            return False
        g.wait(gap)
        g.pour(i, j)
    return True


def cards(g, first=4.0, rest=2.5):
    """Οι κάρτες νέων ειδικών τύπων: η πρώτη πιο πολύ."""
    s = first
    while g.peek("mode") == t.MODE_CARD:
        g.wait(s)
        g.key("space")
        g.run(5)
        s = rest
    g.wait(0.8)


def jump(g, idx, **kw):
    """Πίστα idx (από 0) με R, χωρίς αποθήκευση."""
    g.poke("save_dirty", 0)
    g.poke("level", idx)
    g.key("r")
    g.run(10)
    cards(g, **kw)


def to_title(g):
    g.poke("save_dirty", 0)
    t.to_title(g)
    g.wait(0.5)


def mark(g, name):
    g.say(f"{len(g.sid) / FPS:6.1f} δ  {name}")


def script(g, levs):
    mark(g, "τίτλος")
    g.wait(7)                               # τίτλος με τη μουσική

    mark(g, "οδηγίες")
    g.key("h")                              # οδηγίες, 4 σελίδες
    for _ in range(4):
        g.wait(2.6)
        g.key("space")
    g.wait(0.5)

    mark(g, "επιλογές")
    g.key("o")                              # επιλογές (χωρίς αλλαγές)
    g.wait(1)
    for _ in range(4):
        g.key("down")
        g.wait(0.3)
    g.wait(0.8)
    g.key("esc")
    g.wait(0.5)

    mark(g, "επιλογή πίστας")
    g.key("space")
    g.wait(1.5)
    g.key("space")
    g.wait(1)

    # πίστα 1: άκυρη κίνηση, μια μετάγγιση και undo, μετά όλη η λύση
    mark(g, "πίστα 1")
    lv = levs[0]
    b = lv["bottles"]
    bad = next((a, d) for a in range(len(b)) for d in range(len(b))
               if a != d and b[a]["layers"] and b[d]["layers"] and
               b[a]["layers"][-1] != b[d]["layers"][-1])
    human(g, [bad])
    g.wait(0.5)
    human(g, lv["solution"][:1])
    g.wait(0.3)
    g.key("u")
    g.wait(0.8)
    human(g, lv["solution"], gap=0.15)
    g.wait(3)                               # νίκη, αστέρια, μετάλλιο

    # κάρτες και ειδικοί τύποι: κρυμμένες (10), πάγος (20), λουκέτο (41),
    # σταγονόμετρο (61), κουρτίνα (62)
    g.poke("unlocked", 100)
    for idx, moves in ((9, 2), (19, 2), (40, 1), (60, 1), (61, 2)):
        mark(g, f"πίστα {idx + 1}")
        jump(g, idx, first=3.0, rest=2.0)
        human(g, levs[idx]["solution"][:moves], gap=0.15)
        g.wait(0.5)

    # πίστα 100: κάρτες, χρονόμετρο, και το έξτρα μπουκάλι
    mark(g, "πίστα 100")
    jump(g, 99, first=3.0, rest=2.0)
    human(g, levs[99]["solution"][:2], gap=0.15)
    g.wait(0.3)
    g.key("e")
    g.wait(1.2)
    human(g, levs[99]["solution"][2:3], gap=0.15)
    g.wait(0.5)

    # «Χαλάρωση» με seed: D, 2026, SPACE· όσο μένει χρόνος
    mark(g, "χαλάρωση")
    to_title(g)
    g.key("d")
    g.wait(1)
    for k in "2026":
        g.key(k)
        g.wait(0.15)
    g.wait(0.8)
    g.key("space")
    g.wait(1)
    reserve = 48.0                          # στατιστικά, τέλος, NEON
    while g.left() > (reserve + 10) * FPS:
        lay = g.layers()
        sol = levels.solve(tuple(levels.bottle(4, x) for x in lay))
        if not sol:
            g.key("esc")
            g.wait(0.5)
            g.key("space")
            g.wait(1)
            continue
        if not human(g, sol, gap=0.15, keep=reserve):
            break
        g.wait(2.5)
        g.key("space")                      # άλλη
        g.wait(1)

    # στατιστικά
    mark(g, "στατιστικά")
    to_title(g)
    g.key("s")
    g.wait(2)
    for _ in range(5):
        g.key("right")
        g.wait(0.6)
    g.wait(1)
    g.key("esc")
    g.wait(0.5)

    # το τέλος: πίστα 100 «λυμένη» και SPACE
    mark(g, "τέλος")
    g.key("space")
    g.wait(0.5)
    g.key("space")
    g.run(10)
    cards(g, 0.2, 0.2)
    # (σαν να λύθηκαν όλες: αστέρια, και το NEON ξεκλειδωμένο όπως στο award_stars)
    g.poke("stars", [3 if k % 7 else 2 for k in range(100)])
    g.poke("unlocked", 100)
    for k, v in (("save_dirty", 0), ("level", 99), ("state", t.ST_WIN), ("relax", 0), ("timer_on", 0),
                 ("theme_open", 1)):
        g.poke(k, v)
    g.key("space")
    g.wait(13)
    g.key("space")
    g.wait(1)
    to_title(g)

    # θέμα NEON, και η πίστα 100 με αυτό ως το τέλος του βίντεο
    mark(g, "NEON")
    g.key("o")
    g.wait(1)
    for _ in range(3):
        g.key("down")
        g.wait(0.3)
    g.key("space")
    g.wait(1.5)
    g.key("esc")
    g.wait(0.8)
    g.key("space")
    g.wait(0.8)
    g.key("space")                          # η πίστα 100 (ο κέρσορας είναι εκεί)
    g.run(10)
    cards(g, 0.5, 0.5)
    g.wait(1)
    human(g, levs[99]["solution"], gap=0.15)
    while True:
        g.run(1)


# -- ήχος -------------------------------------------------------------------

def render_sid(regs, path):
    """Οι καταχωρητές του SID ανά καρέ -> WAV 44,1 kHz mono. Τρεις φωνές:
    παλμός (με το πλάτος του) ή θόρυβος, ένταση = sustain όσο το gate είναι
    ανοιχτό, με ράμπα 2 ms για να μην κάνει κλικ, και ένα χαμηλοπερατό στην
    έξοδο (όπως η βαθμίδα εξόδου του C64)."""
    out = bytearray()
    phase = [0.0] * 3
    amp = [0.0] * 3
    noise = [0x7FFFF8] * 3
    nval = [0.0] * 3
    step_amp = 1.0 / (0.002 * RATE)
    lp = 0.0
    alpha = 1 - math.exp(-2 * math.pi * 9000 / RATE)
    acc = 0.0
    per_frame = RATE / FPS
    for r in regs:
        acc += per_frame
        n = int(acc)
        acc -= n
        vol = (r[24] & 15) / 15.0
        voices = []
        for v in range(3):
            b = v * 7
            freq = (r[b] | r[b + 1] << 8) * CLOCK / 16777216.0
            pw = ((r[b + 2] | (r[b + 3] & 15) << 8) or 2048) / 4096.0
            ctrl = r[b + 4]
            target = (r[b + 6] >> 4) / 15.0 if ctrl & 1 else 0.0
            voices.append((freq / RATE, pw, ctrl, target))
        buf = []
        for _ in range(n):
            s = 0.0
            for v in range(3):
                inc, pw, ctrl, target = voices[v]
                a = amp[v]
                if a < target:
                    a = min(target, a + step_amp)
                elif a > target:
                    a = max(target, a - step_amp)
                amp[v] = a
                p = phase[v] + inc
                if p >= 1.0:
                    p -= int(p)
                    if ctrl & 0x80:             # θόρυβος: το LFSR του SID
                        x = noise[v]
                        bit = ((x >> 22) ^ (x >> 17)) & 1
                        x = ((x << 1) | bit) & 0x7FFFFF
                        noise[v] = x
                        nval[v] = (((x >> 22) & 1) << 7 | ((x >> 20) & 1) << 6 | ((x >> 16) & 1) << 5 |
                                   ((x >> 13) & 1) << 4 | ((x >> 11) & 1) << 3 | ((x >> 7) & 1) << 2 |
                                   ((x >> 4) & 1) << 1 | ((x >> 2) & 1)) / 127.5 - 1.0
                phase[v] = p
                if a == 0.0:
                    continue
                if ctrl & 0x80:
                    w = nval[v]
                elif ctrl & 0x40:
                    w = 1.0 if p < pw else -1.0
                else:
                    w = 0.0
                s += w * a
            lp += alpha * (s * vol - lp)
            buf.append(int(max(-1.0, min(1.0, lp * 0.3)) * 32767))
        out += struct.pack(f"<{len(buf)}h", *buf)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(out))


def main():
    levs = levels.levels()
    os.makedirs(OUT, exist_ok=True)
    ff = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{W}x{H}", "-r", f"{FPS:.6f}", "-i", "-",
         "-vf", "scale=iw*3:ih*3:flags=neighbor", "-c:v", "libx264", "-preset", "medium",
         "-crf", "18", "-pix_fmt", "yuv420p", SILENT], stdin=subprocess.PIPE)
    g = Recorder(ff)
    try:
        script(g, levs)
    except Done:
        pass
    finally:
        g.close()
        ff.stdin.close()
        ff.wait()
    for line in g.log:
        print(line)
    render_sid(g.sid, WAV)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", SILENT, "-i", WAV,
                    "-c:v", "copy", "-c:a", "aac", "-b:a", "160k", "-shortest", MP4], check=True)
    os.remove(SILENT)
    print(f"{len(g.sid)} καρέ ({len(g.sid) / FPS:.1f} δ), {g.fails} αποτυχίες")
    print(MP4)
    return 1 if g.fails else 0


if __name__ == "__main__":
    sys.exit(main())
