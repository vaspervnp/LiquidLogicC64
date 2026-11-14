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

    def __init__(self, image=None, extra_args=()):
        self.vm = vice.Vice(image or PRG, extra_args=("-initbreak", "0x080d", *extra_args), labels=LABELS)
        self.lab = self.vm.labels
        self.vm.wait_event((vice.EV_STOPPED,), 60)
        self.poke("test_mode", 1)
        self.keys([])
        self.frames = 0
        self.vm.run_to("frame_done", timeout=180)  # από δισκέτα, με πολλά VICE μαζί

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
        try:
            self.vm.run_to("frame_done", n, timeout=20)
        except TimeoutError:
            raise TimeoutError("κόλλησε: " + self.where()) from None
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

    def where(self):
        """PC και η κοντινότερη ετικέτα (για τα κολλήματα)."""
        r = self.vm.registers()
        lab = {v: k for k, v in self.lab.items()}
        pc = r["PC"]
        best = max((a for a in lab if a <= pc), default=0)
        return f"PC ${pc:04x} ({lab.get(best)}+{pc - best}) raster {r.get('LIN')}"

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


def ui_checks():
    """Τίτλος -> επιλογή -> πίστα 1, κλειδωμένες, παύση, άκυρη κίνηση, αστέρια,
    ξεκλείδωμα, αποθήκευση στη δισκέτα και φόρτωμα σε νέα εκκίνηση."""
    import shutil
    import subprocess
    import tempfile
    levs = levels.levels()
    tmp = tempfile.mkdtemp()
    d64 = os.path.join(tmp, "ll.d64")
    shutil.copy(os.path.join(ROOT, "build", "liquidlogic.d64"), d64)
    drive = ("-drive8type", "1541", "-drive8truedrive")
    g = Player(image=d64, extra_args=drive)
    try:
        g.run(30)
        g.check(g.peek("mode") == MODE_TITLE, "η εκκίνηση δεν είναι στον τίτλο")
        g.key("fire")
        g.run(10)
        g.check(g.peek("mode") == MODE_SELECT, "SPACE στον τίτλο: όχι επιλογή πίστας")
        g.key("right")                  # η 2 είναι κλειδωμένη
        g.key("fire")
        g.run(3)
        g.check(g.peek("mode") == MODE_SELECT and g.peek("sel_level") == 1, "μπήκε σε κλειδωμένη πίστα")
        g.key("left")
        g.key("fire")
        g.run(10)
        g.check(g.peek("mode") == MODE_GAME and g.peek("level") == 0, "η πίστα 1 δεν ξεκίνησε")
        g.key("esc")
        g.run(3)
        g.check(g.peek("state") == ST_PAUSE, "ESC: όχι παύση")
        g.key("esc")
        g.run(3)
        g.check(g.peek("state") == ST_IDLE, "ESC στην παύση: δεν συνέχισε")
        # άκυρη μετάγγιση: ο στόχος χοροπηδάει και ξανακάθεται
        b = levs[0]["bottles"]
        bad = next((a, d) for a in range(len(b)) for d in range(len(b))
                   if a != d and b[a]["layers"] and b[d]["layers"] and
                   b[a]["layers"][-1] != b[d]["layers"][-1])
        g.select(bad[0])
        g.goto(bad[1])
        g.run(1, ["fire"])
        g.run(2)
        g.check(g.peek("shake_cnt") > 0, "άκυρη μετάγγιση: κανένα χοροπηδητό")
        g.run(30)
        g.check(g.peek("shake_cnt") == 0 and g.bot(bad[1], B_RAISE) == 0, "το χοροπηδητό δεν τελείωσε")
        # λύση στο par -> 3 αστέρια, ξεκλείδωμα της 2
        g.play(levs[0], "πίστα 1 (μενού)")
        g.check(g.peek("stars") == 3, f"αστέρια {g.peek('stars')}, όχι 3")
        g.check(g.peek("unlocked") == 2, f"ξεκλείδωτες {g.peek('unlocked')}, όχι 2")
        g.key("m")                      # φεύγοντας από τη νίκη: αποθήκευση
        g.run(20)
        g.check(g.peek("mode") == MODE_SELECT, "M στη νίκη: όχι μενού")
        g.check(g.peek("save_ok") == 1, "η αποθήκευση απέτυχε")
    finally:
        g.close()
    lst = subprocess.run(["c1541", d64, "-list"], capture_output=True, text=True).stdout
    g.check('"liquid.sav"' in lst, "το LIQUID.SAV δεν γράφτηκε στη δισκέτα")
    g2 = Player(image=d64, extra_args=drive)
    try:
        g2.run(30)
        g.check(g2.peek("unlocked") == 2 and g2.peek("stars") == 3 and g2.peek("mode") == MODE_TITLE,
                "η πρόοδος δεν φορτώθηκε μετά από επανεκκίνηση")
        g2.key("fire")
        g2.run(10)
        g2.key("right")
        g2.key("fire")
        g2.run(10)
        while g2.peek("mode") == MODE_CARD:
            g2.key("fire")
            g2.run(3)
        g.check(g2.peek("mode") == MODE_GAME and g2.peek("level") == 1, "η ξεκλείδωτη πίστα 2 δεν ξεκίνησε")
    finally:
        g2.close()
    shutil.rmtree(tmp)
    g.say("οθόνες, αστέρια, δισκέτα: " + ("OK" if not g.fails else "ΑΠΟΤΥΧΙΑ"))
    return g.fails, g.log, g.frames


def to_title(g):
    for _ in range(6):
        m = g.peek("mode")
        if m == MODE_TITLE:
            return
        if m == MODE_GAME:
            if g.peek("state") not in (ST_PAUSE, ST_WIN, ST_FAIL):
                g.key("esc")
                g.run(3)
            g.key("m")
        else:
            g.key("esc")
        g.run(20)
    g.check(g.peek("mode") == MODE_TITLE, "δεν γύρισε στον τίτλο")


def feature_checks():
    """«Χαλάρωση» (λύνεται, R, SPACE, M), seed ίδιο με τον CPC (relaxsim.py),
    επιλογές, οδηγίες, στατιστικά, βελάκια με SHIFT, πλήκτρα."""
    import relaxsim
    g = Player()
    try:
        g.run(30)
        g.key("r")
        g.run(10)
        for k in range(3):
            name = f"χαλάρωση {k + 1}"
            g.check(g.peek("mode") == MODE_GAME and g.peek("relax") == 1 and g.peek("state") == ST_IDLE,
                    f"{name}: δεν ξεκίνησε")
            lay = g.layers()
            ncol = g.peek("relax_ncol")
            counts = {}
            for b in lay:
                for x in b:
                    counts[x] = counts.get(x, 0) + 1
            g.check(5 <= ncol <= 8 and len(lay) == ncol + 2 and len(counts) == ncol and
                    all(v == 4 for v in counts.values()) and sum(1 for b in lay if not b) == 2 and
                    not any(len(b) == 4 and len(set(b)) == 1 for b in lay), f"{name}: λάθος πίστα {lay}")
            sol = levels.solve(tuple(levels.bottle(4, b) for b in lay))
            if sol is None:
                g.say(f"{name}: χωρίς λύση από τον solver: SPACE στην παύση")
                g.key("esc")
                g.run(3)
                g.key("fire")
                g.run(10)
                continue
            if k == 0:                  # R: ξανά η ίδια
                g.pour(*sol[0][:2])
                g.key("r")
                g.run(10)
                g.check(g.layers() == lay and g.peek("moves") == 0, f"{name}: το R δεν την ξανάστησε")
            lv = dict(bottles=[dict(cap=4, layers=b, dropper=False, lock=0, freeze=0) for b in lay],
                      solution=[list(m) for m in sol], par=len(sol))
            g.play(lv, name)
            g.say(f"{name}: {ncol} χρώματα, λύση σε {len(sol)}")
            g.key("fire")               # άλλη
            g.run(10)
            g.check(g.layers() != lay, f"{name}: το SPACE δεν έφτιαξε καινούργια")
        g.key("esc")
        g.run(3)
        g.key("m")
        g.run(20)
        g.check(g.peek("mode") == MODE_TITLE and g.peek("relax") == 0, "χαλάρωση: το M δεν γύρισε στον τίτλο")
        g.check(g.peek16("stat_relax") >= 3, "χαλάρωση: ο μετρητής δεν μέτρησε")
        # seed: ίδιες πίστες με τον CPC
        g.key("d")
        g.run(5)
        for k in "0042":
            g.key(k)
        g.key("fire")
        g.run(10)
        a = g.layers()
        g.key("esc")
        g.run(3)
        g.key("fire")
        g.run(10)
        b = g.layers()
        g.check(g.peek16("last_seed") == 42, "seed: δεν γράφτηκε το 42")
        g.check(a == relaxsim.seeded(42, 1) and b == relaxsim.seeded(42, 2), f"seed 42: όχι όπως στον CPC: {a}")
        to_title(g)
        # επιλογές
        g.key("o")
        g.run(5)
        g.check(g.peek("mode") == MODE_OPTIONS, "O: όχι επιλογές")
        g.key("down")
        g.key("fire")
        g.check(g.peek("opt_sfx") == 0, "επιλογές: τα εφέ δεν έκλεισαν")
        g.key("fire")
        g.key("down")
        g.key("fire")
        g.check(g.peek("opt_sfx") == 1 and g.peek("opt_speed") == 1, "επιλογές: εφέ/ταχύτητα")
        g.key("fire")
        g.key("down")
        g.key("fire")
        g.check(g.peek("opt_theme") == g.peek("theme_open"), "επιλογές: θέμα χωρίς ξεκλείδωμα")
        g.key("down")                   # ορισμός πλήκτρων: Z X P L SPACE... (εδώ: 1 2 3 4 5)
        g.key("fire")
        for k in "12345":
            g.key(k)
        g.check(g.peek("opt_keys", 10) == [7, 1, 7, 8, 1, 1, 1, 8, 2, 1] and g.peek("opt_redef") == 0xFF,
                f"πλήκτρα: {g.peek('opt_keys', 10)}")
        g.key("esc")
        g.run(20)
        g.check(g.peek("mode") == MODE_TITLE, "επιλογές: ESC όχι τίτλος")
        g.key("fire")
        g.run(5)
        g.key("fire")
        g.run(5)
        while g.peek("mode") == MODE_CARD:
            g.key("fire")
        g.key("2")                      # το νέο «δεξιά»
        g.run(2)
        g.check(g.peek("cursor") == 1, "τα νέα πλήκτρα δεν δουλεύουν")
        g.key("crsr_r")                 # τα βελάκια του C64: → και SHIFT+→
        g.run(2)
        g.check(g.peek("cursor") == 2, "CRSR →")
        g.press("shift", "crsr_r", hold=1, after=1)
        g.run(2)
        g.check(g.peek("cursor") == 1, "SHIFT + CRSR →: όχι αριστερά")
        to_title(g)
        # οδηγίες, στατιστικά
        g.key("h")
        g.run(5)
        g.check(g.peek("mode") == MODE_HELP, "H: όχι οδηγίες")
        for _ in range(4):
            g.key("fire")
            g.run(3)
        g.check(g.peek("mode") == MODE_TITLE, "οδηγίες: δεν γύρισαν στον τίτλο")
        g.key("s")
        g.run(5)
        g.check(g.peek("mode") == MODE_STATS, "S: όχι στατιστικά")
        g.key("right")
        g.check(g.peek("md_sel") == 6, "στατιστικά: επιλογή μεταλλίου")
        sel = []                        # κυκλικά: 6 -> 0 -> 6 -> 5 -> 11 -> 0
        for k in ("right", "left", "up", "right", "down"):
            g.key(k)
            sel.append(g.peek("md_sel"))
        g.check(sel == [0, 6, 5, 11, 0], f"στατιστικά: κυκλική επιλογή {sel}")
        g.key("esc")
        g.run(5)
    except Exception as e:                                  # noqa: BLE001
        g.fails += 1
        g.say(f"ΑΠΟΤΥΧΙΑ: {type(e).__name__}: {e}")
    finally:
        g.close()
    g.say("χαλάρωση, seed, επιλογές, οδηγίες, στατιστικά: " + ("OK" if not g.fails else "ΑΠΟΤΥΧΙΑ"))
    return g.fails, g.log, g.frames


def test(only=None, jobs=None):
    levs = levels.levels()
    todo = list(range(len(levs))) if only is None else [only]
    jobs = jobs or min(len(todo), max(1, (os.cpu_count() or 4) - 2))
    chunks = [todo[k::jobs] for k in range(jobs)]
    tasks = [lambda c=c: solve_levels(c) for c in chunks]
    if only is None:
        tasks += [ui_checks, feature_checks]
    with ThreadPoolExecutor(max_workers=len(tasks)) as pool:
        results = list(pool.map(lambda t: t(), tasks))
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
    """Εικόνες όλων των οθονών στο build/shots."""
    levs = levels.levels()
    with Player() as g:
        g.run(60)
        g.shot("title")
        for key, name, back in (("o", "options", "esc"), ("s", "stats", "esc"), ("d", "seed", "esc")):
            g.key(key)
            g.run(10)
            g.shot(name)
            g.key(back)
            g.run(10)
        g.key("h")
        for k in range(4):
            g.run(5)
            g.shot(f"help{k + 1}")
            g.key("fire")
        g.run(10)
        g.poke("unlocked", 37)
        for k in range(36):
            g.poke(g.lab["stars"] + k, 1 + k % 3)
        g.key("fire")
        g.run(10)
        g.shot("select")
        g.key("left")
        g.key("up")
        g.run(2)
        g.shot("select2")
        g.key("esc")
        g.run(5)
        g.key("fire")
        g.run(5)
        g.key("fire")
        g.run(5)
        g.shot("level1")
        g.key("esc")
        g.run(3)
        g.shot("pause")
        g.key("esc")
        g.run(3)
        g.play(levs[0], "1")
        g.run(5)
        g.shot("win")
        for idx in (10, 20, 40, 41, 60, 61, 62, 63, 22):
            g.load_level(idx)
            g.poke("level", idx)
        # κάρτες: ξανά από την αρχή, χωρίς τις κάρτες που έχουν δειχτεί
        g.poke("seen_cards", 0)
        g.poke("seen_cards+1", 0)
        g.poke("level", 89)
        g.key("r")
        g.run(10)
        k = 0
        while g.peek("mode") == MODE_CARD and k < 12:
            g.shot(f"card{k}")
            g.key("fire")
            g.run(5)
            k += 1
        g.run(5)
        g.shot("level90")
        g.poke("level", 99)
        g.key("esc")
        g.run(2)
        g.key("m")
        g.run(10)
        g.shot("select_after")
        g.poke("level", 99)
        g.poke("mode", MODE_GAME)
        g.run(1)
        g.key("r")
        g.run(10)
        while g.peek("mode") == MODE_CARD:
            g.key("fire")
            g.run(3)
        g.play(levs[99], "100")
        g.run(60)
        g.shot("win100")
        g.key("fire")
        g.run(100)
        g.shot("ending")
        g.run(60)
        g.shot("ending2")
    print("build/shots/")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "shot"
    if cmd == "shot":
        shots()
    elif cmd in ("ui", "features"):
        f, log, _ = (ui_checks if cmd == "ui" else feature_checks)()
        print("\n".join(log))
        sys.exit(1 if f else 0)
    elif cmd == "test":
        only = int(sys.argv[2]) - 1 if len(sys.argv) > 2 else None
        sys.exit(test(only))
    else:
        raise SystemExit(f"άγνωστη εντολή: {cmd}")


if __name__ == "__main__":
    main()
