#!/usr/bin/env python3
"""Αυτόματο test του Liquid Logic στον C64, σε headless VICE (x64sc), μέσα από
το binary monitor (tools/vice.py).

    python3 tools/c64test.py shot          # build/shots/*.png: τίτλος, οθόνες, πίστα 1
    python3 tools/c64test.py test          # λύνει ΟΛΕΣ τις πίστες με τα πλήκτρα
                                           # (λύσεις του solver, tools/levels.py) και
                                           # ελέγχει στρώσεις, κινήσεις, νίκη, ειδικούς τύπους
    python3 tools/c64test.py test 7        # μόνο η πίστα 7
    python3 tools/c64test.py relax 5       # «Χαλάρωση»: 5 τυχαίες πίστες

Το παιχνίδι τρέχει με test_mode = 1 (γράφεται πριν από την πρώτη εντολή):
διαβάζει τα πλήκτρα από το test_keys (8 στήλες του matrix, joystick 2, 1)
αντί για το υλικό. Ένα «καρέ» = ένας γύρος του κύριου βρόχου (frame_done).
Βγαίνει με 1 αν κάποιος έλεγχος αποτύχει.
"""

import os
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import vice  # noqa: E402

PRG = os.path.join(ROOT, "build", "liquidlogic.prg")
LABELS = os.path.join(ROOT, "build", "labels.txt")
SHOTS = os.path.join(ROOT, "build", "shots")

BOT_SIZE = 24
B_X, B_Y, B_CAP, B_CNT, B_LH, B_RAISE, B_DONE, B_ROW, B_LAY = 0, 1, 2, 3, 4, 5, 6, 7, 8
B_FLAGS, B_FREEZE, B_LOCK = 14, 15, 16
BF_CURTAIN = 16
ST_IDLE, ST_SEL, ST_POUR, ST_WIN, ST_FAIL, ST_PAUSE = range(6)
(MODE_TITLE, MODE_SELECT, MODE_GAME, MODE_CARD, MODE_OPTIONS, MODE_HELP, MODE_STATS,
 MODE_END, MODE_SEED) = range(9)
UNDO_MAX = 5

# πλήκτρο -> (στήλη του test_keys, bit)
KEYS = {
    "up": (8, 0x01), "down": (8, 0x02), "left": (8, 0x04), "right": (8, 0x08), "fire": (8, 0x10),
    "space": (7, 0x10), "esc": (7, 0x80), "r": (2, 0x02), "u": (3, 0x40), "e": (1, 0x40),
    "m": (4, 0x10), "o": (4, 0x40), "h": (3, 0x20), "s": (1, 0x20), "d": (2, 0x04),
    "del": (0, 0x01), "ret": (0, 0x02), "i": (4, 0x02), "j": (4, 0x04), "k": (4, 0x20),
    "l": (5, 0x04), "crsr_r": (0, 0x04), "crsr_d": (0, 0x80), "shift": (1, 0x80),
    "0": (4, 0x08), "1": (7, 0x01), "2": (7, 0x08), "3": (1, 0x01), "4": (1, 0x08),
    "5": (2, 0x01), "6": (2, 0x08), "7": (3, 0x01), "8": (3, 0x08), "9": (4, 0x01),
}


class Game:
    """Ένας C64 με το παιχνίδι, σταματημένος στο frame_done."""

    def __init__(self, extra_args=()):
        self.vm = vice.Vice(PRG, extra_args=("-initbreak", "0x080d", *extra_args), labels=LABELS)
        self.lab = self.vm.labels
        self.vm.wait_event((vice.EV_STOPPED,), 60)
        self.poke("test_mode", 1)
        self.keys([])
        self.frames = 0
        self.vm.run_to("frame_done")

    def close(self):
        self.vm.close()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def a(self, name):
        if isinstance(name, int):
            return name
        base, _, off = name.partition("+")
        return self.lab[base] + (int(off) if off else 0)

    def peek(self, name, n=1):
        data = self.vm.peek(self.a(name), n)
        return data[0] if n == 1 else list(data)

    def peek16(self, name):
        lo, hi = self.peek(name, 2)
        return lo | hi << 8

    def poke(self, name, value):
        self.vm.poke(self.a(name), bytes(value) if isinstance(value, (list, bytes)) else bytes([value & 0xFF]))

    def keys(self, names):
        row = [0xFF] * 10
        for n in names:
            col, bit = KEYS[n]
            row[col] &= ~bit & 0xFF
        self.poke("test_keys", row)

    def run(self, n=1, keys=()):
        self.keys(list(keys))
        self.vm.run_to("frame_done", n)
        self.frames += n

    def press(self, *keys, hold=2, after=2):
        """Πατάει (για hold καρέ) και αφήνει (για after καρέ)."""
        self.run(hold, keys)
        self.run(after)

    def until(self, cond, limit=3000, keys=()):
        for k in range(limit):
            if cond():
                return k
            self.run(1, keys)
        raise TimeoutError(f"μετά από {limit} καρέ")

    def shot(self, name):
        os.makedirs(SHOTS, exist_ok=True)
        path = os.path.join(SHOTS, name + ".png")
        self.vm.screenshot(path)
        return path

    # -- πίστα -------------------------------------------------------------
    def bottle(self, i):
        return self.peek(self.lab["bottles"] + i * BOT_SIZE, BOT_SIZE)

    def layers(self, i):
        b = self.bottle(i)
        return b[B_LAY:B_LAY + b[B_CNT]]


import levels  # noqa: E402


class Player(Game):
    """Παίζει σαν παίκτης (βελάκια, SPACE) και ελέγχει (μεταφορά του
    tools/headless.py του CPC)."""

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.fails = 0
        self.cards = 0
        self.log = []

    def say(self, msg):
        self.log.append(msg)

    def check(self, ok, msg):
        if not ok:
            self.say("ΑΠΟΤΥΧΙΑ: " + msg)
            self.fails += 1
        return ok

    def raw_layers(self):
        n = self.peek("nbottles")
        raw = self.peek("bottles", n * BOT_SIZE)
        return [raw[i * BOT_SIZE + B_LAY:i * BOT_SIZE + B_LAY + raw[i * BOT_SIZE + B_CNT]] for i in range(n)]

    def layers(self):
        return [[x & 0x7F for x in b] for b in self.raw_layers()]

    def bot(self, i, field):
        return self.peek(self.lab["bottles"] + i * BOT_SIZE + field)

    def key(self, k):
        self.press(k, hold=1, after=1)

    def goto(self, target):
        """Κέρσορας στο μπουκάλι target με βελάκια (όπως ο παίκτης)."""
        row = self.bot(target, B_ROW)
        for _ in range(4):
            cur = self.bot(self.peek("cursor"), B_ROW)
            if cur == row:
                break
            self.key("down" if row > cur else "up")
        for _ in range(16):
            if self.peek("cursor") == target:
                return
            self.key("right" if self.peek("cursor") < target else "left")
        self.check(False, f"ο κέρσορας δεν έφτασε στο {target}")

    def select(self, i):
        self.goto(i)
        self.key("fire")
        return self.peek("state") == ST_SEL

    def pour(self, src, dst, frames=None):
        """Επιλογή src, μετά dst, και αναμονή ως το τέλος του πίδακα."""
        if not self.select(src):
            return False
        self.goto(dst)
        self.run(1, ["fire"])
        for _ in range(10):
            if self.peek("state") != ST_SEL:
                break
            self.run(1)
        for k in range(600):
            if self.peek("state") != ST_POUR:
                break
            self.run(1)
            if frames is not None:
                frames.append(k)
        self.run(2)
        return True

    def load_level(self, index):
        """Πίστα index (από 0): γράφεται στο level και R."""
        self.poke("level", index)
        self.key("r")
        for _ in range(300):
            if self.peek("mode") == MODE_CARD:  # κάρτες νέων ειδικών τύπων
                self.cards += 1
                self.key("fire")
                continue
            if (self.peek("level") == index and self.peek("moves") == 0 and
                    self.peek("state") == ST_IDLE and self.peek("undo_left") == UNDO_MAX and
                    self.peek("mode") == MODE_GAME):
                break
            self.run(1)
        self.run(2)
        self.check(self.peek("level") == index and self.peek("moves") == 0 and
                   self.peek("undo_left") == UNDO_MAX, f"φόρτωμα πίστας {index + 1}")

    def play(self, lv, name, upto=None):
        state = levels.state_of(lv)
        masked = lambda st: [[x & 0x7F for x in b[-1]] for b in st]  # noqa: E731
        if not self.check(self.layers() == masked(state), f"{name}: αρχικές στρώσεις {self.layers()}"):
            return False
        sol = lv["solution"] if upto is None else lv["solution"][:upto]
        for k, (i, j, n) in enumerate(sol):
            if not self.check(self.pour(i, j), f"{name}, κίνηση {k + 1}: το {i} δεν επιλέγεται"):
                return False
            state = levels.apply(state, (i, j, n))
            got = self.layers()
            if not self.check(got == masked(state) and self.raw_layers() == [list(b[-1]) for b in state],
                              f"{name}, κίνηση {k + 1} ({i}->{j}): {got}"):
                return False
        if upto is None:
            self.check(self.peek("moves") == lv["par"], f"{name}: κινήσεις {self.peek('moves')}, par {lv['par']}")
            self.check(self.peek("state") == ST_WIN, f"{name}: δεν δηλώθηκε νίκη")
            self.check(self.peek("p_alive") == 0, f"{name}: ζωντανά σωματίδια στο τέλος")
        return True

    def start_game(self):
        """Από τον τίτλο στην πίστα 1."""
        self.run(30)
        self.key("fire")
        self.run(5)
        self.key("fire")
        self.run(5)
        while self.peek("mode") == MODE_CARD:
            self.key("fire")
            self.run(2)


def first(lv, pred):
    return next((i for i, b in enumerate(lv["bottles"]) if pred(b)), None)


def special_checks(g, lv, idx):
    """Έλεγχοι ειδικών τύπων πριν από τη λύση. Αφήνει την πίστα από την αρχή."""
    name = f"πίστα {idx + 1}"
    sol = lv["solution"]
    fz = first(lv, lambda b: b["freeze"])
    if fz is not None:
        k = lv["bottles"][fz]["freeze"]
        g.check(not g.select(fz), f"{name}: το παγωμένο {fz} επιλέχτηκε")
        if g.peek("state") == ST_SEL:
            g.key("fire")
        g.run(20)
        g.play(lv, name, upto=1)
        g.check(g.bot(fz, B_FREEZE) == k - 1, f"{name}: ο πάγος δεν μέτρησε την κίνηση")
        g.key("u")
        g.run(10)
        g.check(g.bot(fz, B_FREEZE) == k and g.peek("moves") == 0, f"{name}: undo δεν επανέφερε τον πάγο")
        g.load_level(idx)
    lk = first(lv, lambda b: b["lock"])
    if lk is not None:
        g.check(not g.select(lk), f"{name}: το κλειδωμένο {lk} επιλέχτηκε")
        if g.peek("state") == ST_SEL:
            g.key("fire")
        g.run(20)
    ct = first(lv, lambda b: b["curtain"])
    if ct is not None:
        g.check(g.bot(ct, B_FLAGS) & BF_CURTAIN, f"{name}: χωρίς κουρτίνα στο {ct}")
        k = next(k for k, (i, j, n) in enumerate(sol) if ct in (i, j))
        g.play(lv, name, upto=k + 1)
        g.check(not g.bot(ct, B_FLAGS) & BF_CURTAIN, f"{name}: η κουρτίνα του {ct} έμεινε")
        g.load_level(idx)
    if lv["flags"] & levels.LF_HIDDEN:
        i, j, n = sol[0]
        g.play(lv, name, upto=1)
        raw = g.raw_layers()[i]
        g.check(not raw or not raw[-1] & 0x80, f"{name}: η κορυφή του {i} έμεινε κρυμμένη")
        g.check(any(x & 0x80 for b in g.raw_layers() for x in b), f"{name}: καμία κρυμμένη στρώση")
        g.load_level(idx)
    if lv["moves"]:
        g.check(g.peek("level_moves") == lv["moves"], f"{name}: όριο κινήσεων")
        g.poke("moves", lv["moves"])
        before = g.layers()
        i, j, n = sol[0]
        g.pour(i, j)
        g.check(g.layers() == before and g.peek("state") == ST_IDLE, f"{name}: μετάγγιση πέρα από το όριο")
        g.run(20)
        g.load_level(idx)
    if lv["timer"]:
        tl = g.peek16("time_left")
        g.check(tl == lv["timer"] * 4, f"{name}: αρχικός χρόνος {tl}, όχι {lv['timer'] * 4}")
        g.poke("time_left", 2)
        g.poke("time_left+1", 0)
        g.run(130)
        g.check(g.peek("state") == ST_FAIL, f"{name}: δεν έληξε ο χρόνος")
        g.shot("test_timeup")
        g.load_level(idx)
    if lv["flags"] & levels.LF_EXTRA:
        n = g.peek("nbottles")
        g.key("e")
        g.run(3)
        g.check(g.peek("nbottles") == n + 1, f"{name}: το E δεν πρόσθεσε μπουκάλι")
        g.key("e")
        g.run(3)
        g.check(g.peek("nbottles") == n + 1, f"{name}: το E δούλεψε δεύτερη φορά")
        g.shot("test_extra")
        g.load_level(idx)
        g.check(g.peek("nbottles") == n, f"{name}: το R δεν έβγαλε το έξτρα μπουκάλι")


def solve_levels(todo):
    """Λύνει τις πίστες todo (δείκτες) σε έναν C64."""
    levs = levels.levels()
    g = Player()
    try:
        g.start_game()
        for idx in todo:
            lv = levs[idx]
            g.load_level(idx)
            g.shot(f"test_lv{idx + 1:02d}")
            special_checks(g, lv, idx)
            before = g.fails
            g.play(lv, f"πίστα {idx + 1}")
            g.say(f"πίστα {idx + 1:3d}: {'OK' if g.fails == before else 'ΑΠΟΤΥΧΙΑ'}  (par {lv['par']})")
    except Exception as e:                                  # noqa: BLE001
        g.fails += 1
        g.say(f"ΑΠΟΤΥΧΙΑ: {type(e).__name__}: {e}")
    finally:
        g.close()
    return g.fails, g.log, g.frames


def test(only=None, jobs=None):
    levs = levels.levels()
    todo = list(range(len(levs))) if only is None else [only]
    jobs = jobs or min(len(todo), os.cpu_count() or 4)
    chunks = [todo[k::jobs] for k in range(jobs)]
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        results = list(pool.map(solve_levels, chunks))
    fails = 0
    lines = []
    for f, log, frames in results:
        fails += f
        lines += log
    for ln in sorted(lines, key=lambda s: (not s.startswith("ΑΠΟΤΥΧΙΑ"), s)):
        print(ln)
    print("OK" if not fails else f"{fails} αποτυχίες")
    return 1 if fails else 0


def shots():
    with Game() as g:
        g.run(60)
        g.shot("title")
        g.press("fire")
        g.run(10)
        g.shot("select")
        g.press("fire")
        g.run(20)
        if g.peek("mode") == MODE_CARD:
            g.shot("card")
            g.press("fire")
            g.run(10)
        g.shot("level1")
        g.press("right")
        g.press("fire")
        g.run(5)
        g.shot("level1_sel")
        g.press("right")
        g.press("right")
        g.press("fire")
        for k in range(12):
            g.run(4)
            g.shot(f"pour_{k:02d}")
    print("build/shots/")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "shot"
    if cmd == "shot":
        shots()
    elif cmd == "test":
        only = int(sys.argv[2]) - 1 if len(sys.argv) > 2 else None
        sys.exit(test(only))
    else:
        raise SystemExit(f"άγνωστη εντολή: {cmd}")


if __name__ == "__main__":
    main()
