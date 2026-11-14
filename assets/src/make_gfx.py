"""Παράγει τα γραφικά και τους πίνακες φυσικής του Liquid Logic για τον C64.

    python3 assets/src/make_gfx.py

Γράφει:
  assets/data/gfx.asm       χρώματα, font, μπουκάλι (cells του bitmap και
                            sprite), σημάνσεις, κέρσορας
  assets/data/physics.asm   πίνακες βαλλιστικής για τα σωματίδια (ίδιοι με
                            του CPC: ίδια φυσική, καρέ προς καρέ)
  assets/preview/*.png      προεπισκόπηση

Multicolor bitmap: 160 x 200, όσο και το mode 0 του CPC. Ένα byte = 4 pixels
(pixel 0 στα bits 7-6), μία cell = 4 pixels x 8 γραμμές, με 4 χρώματα:
  %00 φόντο ($D021), %01 high nibble της screen RAM, %10 low nibble,
  %11 color RAM.
Το μπουκάλι (16 x 70, όπως στον CPC) πιάνει 4 cells σε πλάτος, με το πάνω
του στη γραμμή 2 μιας cell (y = 8k + 2): ο λαιμός (γρ. 0-5) έχει δική του
σειρά cells, και κάθε σειρά του σώματος (8 γραμμές) χωράει το πολύ δύο
στρώσεις (στρώση >= 10 γραμμές). Η «θέση» (slot) κάθε χρώματος ανά σειρά:
  λαιμός (σειρά 0):    %01 γυαλί, %10 φελλός (ή το υγρό της ροής), %11 λευκό
  σώμα (σειρές 1-7):   %01, %10 τα (ως δύο) υγρά, %11 γυαλί (cells 0, 3) ή
                       λευκό (cells 1, 2: η λάμψη)
  πάτος (σειρά 8):     %01 υγρό, %10 γυαλί (cells 1, 2), %11 γυαλί / λευκό
"""

import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "assets", "data")
PREVIEW = os.path.join(ROOT, "assets", "preview")

# Χρώματα του C64 (pepto PAL, για την προεπισκόπηση)
RGB = [
    (0x00, 0x00, 0x00), (0xFF, 0xFF, 0xFF), (0x68, 0x37, 0x2B), (0x70, 0xA4, 0xB2),
    (0x6F, 0x3D, 0x86), (0x58, 0x8D, 0x43), (0x35, 0x28, 0x79), (0xB8, 0xC7, 0x6F),
    (0x6F, 0x4F, 0x25), (0x43, 0x39, 0x00), (0x9A, 0x67, 0x59), (0x44, 0x44, 0x44),
    (0x6C, 0x6C, 0x6C), (0x9A, 0xD2, 0x84), (0x6C, 0x5E, 0xB5), (0x95, 0x95, 0x95),
]
BLACK, WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW = range(8)
ORANGE, BROWN, LIGHT_RED, DARK_GREY, GREY, LIGHT_GREEN, LIGHT_BLUE, LIGHT_GREY = range(8, 16)

# Τα 16 pens του CPC (plan.md §4) -> χρώματα του C64. Ο C64 έχει 16 χρώματα
# συνολικά: 12 υγρά + κρυμμένη + γυαλί + λευκό + μαύρο. Γι' αυτό το φόντο
# μένει μαύρο, και η διαβάθμιση του CPC (μαύρο-μπλε-ματζέντα) πάει στο border.
PEN_COLOUR = [
    BLACK,          # 0 φόντο
    GREY,           # 1 γυαλί
    WHITE,          # 2 λάμψη, κείμενο, κέρσορας
    DARK_GREY,      # 3 κρυμμένη στρώση «?»
    # τα 12 υγρά: τα πιο διακριτά χρώματα στα pens που μπαίνουν πρώτα στις
    # πίστες (5, 10, 14 στην 1, 4, 11, 13 στη 2, 7, 12 στην 3, ...)
    LIGHT_GREEN,    # 4
    YELLOW,         # 5
    LIGHT_RED,      # 6
    ORANGE,         # 7
    GREEN,          # 8
    BLUE,           # 9
    LIGHT_BLUE,     # 10
    PURPLE,         # 11
    LIGHT_GREY,     # 12
    CYAN,           # 13
    RED,            # 14
    BROWN,          # 15
]
NEON_GLASS = LIGHT_RED
CORK_COLOUR = BROWN
PEN_BG, PEN_GLASS, PEN_WHITE, PEN_HIDDEN, PEN_LIQUID = 0, 1, 2, 3, 4

BOTTLE_W, BOTTLE_H = 16, 70
BODY_TOP, BODY_LINES = 6, 60
BODY_BOTTOM = BODY_TOP + BODY_LINES - 1
TILT_PX = 4
HIGHLIGHT_PX = 4            # η λάμψη του γυαλιού (στον CPC στο pixel 3)

# Μπουκάλι 16 x 70. '.' φόντο, '#' γυαλί, 'o' λευκό, '-' γυαλί (λάμψη στο
# άδειο), '_' εσωτερικό (υγρό ή άδειο), 'h' η λάμψη πάνω στο υγρό.
NECK = [
    "...##########...",     # 0 χείλος
    "...#o.......#...",     # 1
    "....#o.....#....",     # 2 λαιμός
    "....#-.....#....",     # 3
    "...#-.......#...",     # 4 ώμος
    "..#-.........#..",     # 5
]
BODY = ".#__h_________#."      # 6-65
BOTTOM = [
    ".#............#.",     # 66
    ".##..........##.",     # 67
    "..############..",     # 68
    "................",     # 69
]


def bottle_art():
    rows = NECK + [BODY] * BODY_LINES + BOTTOM
    assert len(rows) == BOTTLE_H and all(len(r) == BOTTLE_W for r in rows)
    return rows


def cell_row(line):
    """Σειρά cells (0-8) της γραμμής του μπουκαλιού (το πάνω στη γρ. 2 της cell)."""
    return (line + 2) // 8


def slot_of(line, cell, ch):
    """Slot (0-3) για ένα σταθερό pixel του μπουκαλιού."""
    if ch == ".":
        return 0
    k = cell_row(line)
    inner = cell in (1, 2)
    if ch in "#-":                      # γυαλί
        if k == 0:
            return 1
        if k == 8 and inner:
            return 2
        return 3
    if ch in "oh":                      # λευκό
        return 3
    raise ValueError(ch)


def pack4(slots):
    """4 slots (pixel 0 πρώτο) -> byte."""
    b = 0
    for s in slots:
        b = b << 2 | s
    return b


def mask4(bits):
    """4 x bool -> μάσκα των pixels."""
    return pack4([3 if x else 0 for x in bits])


def bottle_cells():
    """tmpl[γραμμή][cell]: τα σταθερά pixels, imask: τα pixels του υγρού."""
    art = bottle_art()
    tmpl, imask = [], []
    for y, row in enumerate(art):
        t, m = [], []
        for c in range(4):
            px = row[c * 4:c * 4 + 4]
            t.append(pack4([0 if ch == "_" else slot_of(y, c, ch) for ch in px]))
            m.append(mask4([ch == "_" for ch in px]))
        tmpl.append(t)
        imask.append(m)
    return tmpl, imask


# Sprite της πηγής στην πτήση (multicolor, διπλό ύψος: μια γραμμή του sprite =
# 2 του μπουκαλιού): %01 γυαλί ($D025), %10 το υγρό / λευκό στο λαιμό (το
# χρώμα του sprite, αλλάζει από στρώση σε στρώση με raster interrupt), %11
# μαύρο ($D026): το άδειο εσωτερικό και το φόντο του ορθογωνίου 16 x 70, που
# σκεπάζει ό,τι είναι από κάτω, όπως στον CPC.
def sprite_line(y):
    row = bottle_art()[y]
    base, liq = [], []
    for i, ch in enumerate(row):
        if ch in "#-":
            base.append(1)
        elif ch == "o":
            base.append(2)
        elif ch == "h":
            base.append(1)              # λάμψη: γκρι στην πτήση
        elif ch == "_":
            base.append(3)              # άδειο (το υγρό το βάζει ο κώδικας)
        else:
            base.append(3)              # φόντο: αδιαφανές, όπως στον CPC
        liq.append(ch == "_")
    return base, liq


def sprite_rows():
    """Ανά γραμμή του sprite (35, από τις ζυγές γραμμές): 4 bytes βάση + 4 bytes μάσκα υγρού."""
    out = []
    for r in range(BOTTLE_H // 2):
        base, liq = sprite_line(2 * r)
        b = [pack4(base[i:i + 4]) for i in range(0, 16, 4)]
        m = [mask4(liq[i:i + 4]) for i in range(0, 16, 4)]
        out.append((b, m))
    return out


CURSOR = [
    "...oo...",
    "..oooo..",
    ".oooooo.",
    "...oo...",
    "...oo...",
    "...oo...",
]

# Φελλός / βολβός στις γρ. 0-4 του λαιμού, pixels 4-11 (cells 1, 2).
CORK = [
    "..cccc..",
    ".ccccco.",
    ".ccccco.",
    "..cccc..",
    "..cccc..",
]
BULB = [
    "..oooo..",
    ".oooooo.",
    ".oooooo.",
    "..oooo..",
    "...oo...",
]
# «?» της κρυμμένης στρώσης (λευκό πάνω στο σκούρο γκρι), pixels 6-9.
HIDDEN_Q = [
    ".oo.",
    "o..o",
    "..o.",
    "....",
    "..o.",
]
# Λουκέτο: όλες οι γραμμές 30-45 (δύο σειρές cells) στα pixels 4-11, ώστε να
# μη μοιράζεται cell με υγρό. o λευκό, c το χρώμα του λουκέτου, . φόντο.
LOCK = [
    "........",
    "..oooo..",
    ".o....o.",
    ".o....o.",
    ".o....o.",
    ".o....o.",
    "oooooooo",
    "occcccco",
    "occcccco",
    "occ..cco",
    "occ..cco",
    "occcccco",
    "occcccco",
    "oooooooo",
    "........",
    "........",
]
LOCK_TOP = 30

# Font 3x5 (στήλη 4 = κενό), κάθε γραμμή διπλή -> 4 x 10: ένας χαρακτήρας =
# μία cell σε πλάτος (40 στήλες).
FONT = {
    " ": ["...", "...", "...", "...", "..."],
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"],
    "3": ["###", "..#", ".##", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "###"],
    "A": [".#.", "#.#", "###", "#.#", "#.#"],
    "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"],
    "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "J": ["..#", "..#", "..#", "#.#", ".#."],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"],
    "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."],
    "P": ["##.", "#.#", "##.", "#..", "#.."],
    "Q": [".#.", "#.#", "#.#", "##.", ".##"],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#.#", "#.#", "###", "###", "#.#"],
    "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
    "Z": ["###", "..#", ".#.", "#..", "###"],
    ":": ["...", ".#.", "...", ".#.", "..."],
    "-": ["...", "...", "###", "...", "..."],
    "/": ["..#", "..#", ".#.", "#..", "#.."],
    "!": [".#.", ".#.", ".#.", "...", ".#."],
    "+": ["...", ".#.", "###", ".#.", "..."],
    "*": [".#.", "###", ".#.", "#.#", "..."],
    "?": ["##.", "..#", ".#.", "...", ".#."],
    ".": ["...", "...", "...", "...", ".#."],
    ",": ["...", "...", "...", ".#.", "#.."],
    "'": [".#.", ".#.", "...", "...", "..."],
    "(": [".#.", "#..", "#..", "#..", ".#."],
    ")": [".#.", "..#", "..#", "..#", ".#."],
    "=": ["...", "###", "...", "###", "..."],
}
FONT_ORDER = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ:-/!?.+*,'()="


def hexes(seq):
    return ",".join(f"${b:02X}" for b in seq)


def byte_lines(label, data, per=16, comment=None):
    out = []
    if comment:
        out.append(f"; {comment}")
    out.append(label)
    for i in range(0, len(data), per):
        out.append("        .byte " + hexes(data[i:i + per]))
    return out


def overlay(art, x0, mapping, cells=(1, 2)):
    """Τέχνη σε pixels x0.. -> ανά γραμμή, ανά cell: (μάσκα, pattern)."""
    out = []
    for row in art:
        line = []
        for c in cells:
            m, p = [], []
            for i in range(4):
                x = c * 4 + i - x0
                ch = row[x] if 0 <= x < len(row) else "."
                s = mapping.get(ch)
                m.append(s is not None)
                p.append(s or 0)
            line.append((mask4(m), pack4(p)))
        out.append(line)
    return out


def make_gfx():
    tmpl, imask = bottle_cells()
    L = [
        "; gfx.asm — ΠΑΡΑΓΕΤΑΙ από το assets/src/make_gfx.py, μην το αλλάζεις με το χέρι",
        "",
        f"BOTTLE_W        = 4               ; cells (16 pixels)",
        f"BOTTLE_H        = {BOTTLE_H}",
        f"BODY_TOP        = {BODY_TOP}               ; πρώτη γραμμή του σώματος",
        f"BODY_LINES      = {BODY_LINES}",
        f"BODY_BOTTOM     = {BODY_BOTTOM}              ; τελευταία γραμμή υγρού",
        f"PEN_BG          = {PEN_BG}",
        f"PEN_GLASS       = {PEN_GLASS}",
        f"PEN_WHITE       = {PEN_WHITE}",
        f"PEN_HIDDEN      = {PEN_HIDDEN}",
        f"PEN_LIQUID      = {PEN_LIQUID}",
        f"CORK_COLOUR     = {CORK_COLOUR}",
        f"NEON_GLASS      = {NEON_GLASS}",
        f"CLASSIC_GLASS   = {PEN_COLOUR[PEN_GLASS]}",
        f"LOCK_TOP        = {LOCK_TOP}",
        f"LOCK_H          = {len(LOCK)}",
        f"FONT_CHARS      = {len(FONT_ORDER)}",
        f"SPR_ROWS        = {BOTTLE_H // 2}             ; γραμμές του sprite της πηγής",
        "",
        "; χρώμα του C64 για κάθε pen του CPC",
        "pen_colour",
        "        .byte " + ",".join(str(c) for c in PEN_COLOUR),
        "",
    ]
    L += byte_lines("bottle_tmpl", [b for row in tmpl for b in row], 16,
                    "μπουκάλι: ανά γραμμή 4 bytes (cells 0-3), τα σταθερά pixels")
    L.append("")
    L += byte_lines("bottle_imask", [b for row in imask for b in row], 16,
                    "μπουκάλι: ανά γραμμή 4 bytes, τα pixels του υγρού")
    L.append("")
    # σημάνσεις: (μάσκα, pattern) ανά γραμμή για τις cells 1, 2
    cork = overlay(CORK, 4, {"c": 2, "o": 3})
    bulb = overlay(BULB, 4, {"o": 3})
    q = overlay(HIDDEN_Q, 6, {"o": 3})
    lock = overlay(LOCK, 4, {"o": 3, "c": 1, ".": 0})
    for name, ov, comment in (("cork_ov", cork, "φελλός, γρ. 0-4: m1,p1,m2,p2"),
                              ("bulb_ov", bulb, "βολβός, γρ. 0-4"),
                              ("hidden_q_ov", q, "«?», 5 γραμμές"),
                              ("lock_ov", lock, "λουκέτο, γρ. 30-45 (αδιαφανές)")):
        L += byte_lines(name, [x for line in ov for (m, p) in line for x in (m, p)], 16, comment)
        L.append("")
    # πάγος: κουκκίδες στα pixels 2, 6, 10 (ζυγές) ή 4, 8, 12 (μονές)
    for par, pxs in ((0, (2, 6, 10)), (1, (4, 8, 12))):
        data = []
        for c in range(4):
            bits = [c * 4 + i in pxs for i in range(4)]
            data += [mask4(bits), mask4(bits)]      # slot 3 (λευκό / γυαλί)
        L += byte_lines(f"ice_ov{par}", data, 16, f"πάγος, κουκκίδες {pxs}: m,p ανά cell")
    L.append("")
    # κουρτίνα: ζυγά pixels %01 (το χρώμα της), μονά γυαλί (%11 στις άκρες,
    # %10 στις cells 1, 2)
    data = []
    for c in range(4):
        m, p = [], []
        for i in range(4):
            x = c * 4 + i
            if 2 <= x <= 13:
                m.append(True)
                p.append(1 if x % 2 == 0 else (2 if c in (1, 2) else 3))
            else:
                m.append(False)
                p.append(0)
        data += [mask4(m), pack4(p)]
    L += byte_lines("curtain_mask", [data[i] ^ 0xFF for i in range(0, 8, 2)], 16,
                    "κουρτίνα: ό,τι μένει από το byte, ανά cell")
    L += byte_lines("curtain_pat", [data[i] for i in range(1, 8, 2)], 16, "κουρτίνα: pattern ανά cell")
    L.append("")
    # εγκοπές (άλλη χωρητικότητα): γυαλί έξω από τον τοίχο και μέσα του
    tick = []
    for c, pxs in ((0, (0, 2)), (3, (13, 15))):
        bits = [c * 4 + i in pxs for i in range(4)]
        tick += [mask4(bits), mask4(bits)]
    L += byte_lines("tick_ov", tick, 16, "εγκοπές: m,p για τις cells 0 και 3")
    L.append("")
    # sprite της πηγής
    rows = sprite_rows()
    L += byte_lines("spr_base", [b for (b, m) in rows for b in b], 16,
                    "πηγή (sprite): ανά γραμμή του sprite 4 bytes, χωρίς υγρό")
    L.append("")
    L += byte_lines("spr_liq", [x for (b, m) in rows for x in m], 16,
                    "πηγή (sprite): ανά γραμμή 4 bytes, μάσκα του υγρού")
    L.append("")
    bulb_spr = []
    for r in range(3):                              # γραμμές 0, 2, 4 του λαιμού
        row = BULB[2 * r]
        px = ["."] * 4 + list(row) + ["."] * 4
        m = [mask4([px[c * 4 + i] == "o" for i in range(4)]) for c in range(4)]
        p = [pack4([2 if px[c * 4 + i] == "o" else 0 for i in range(4)]) for c in range(4)]
        bulb_spr += m + p
    L += byte_lines("spr_bulb", bulb_spr, 8, "βολβός στο sprite: 3 γραμμές x (4 μάσκα, 4 pattern)")
    L.append("")
    ice = []
    for y in range(BOTTLE_H):
        if BODY_TOP + 1 <= y <= BODY_BOTTOM - 1 and (y - BODY_TOP - 1) % 3 == 0:
            ice.append(1 + ((y - BODY_TOP - 1) // 3) % 2)
        else:
            ice.append(0)
    L += byte_lines("ice_line", ice, 14, "πάγος ανά γραμμή: 0 τίποτα, 1 ice_ov0, 2 ice_ov1")
    L.append("")
    tilt = [round((BOTTLE_H - 1 - r) * TILT_PX / (BOTTLE_H - 1)) for r in range(BOTTLE_H)]
    L.append("; γέρσιμο: μετατόπιση σε pixels ανά γραμμή του μπουκαλιού")
    L.append("tilt_table")
    for i in range(0, BOTTLE_H, 14):
        L.append("        .byte " + ",".join(str(x) for x in tilt[i:i + 14]))
    L.append("")
    # κέρσορας: hires sprite (κάθε pixel του CPC = 2 pixels), 24 x 21
    spr = [0] * 63
    for y, row in enumerate(CURSOR):
        bits = "".join("11" if ch == "o" else "00" for ch in row).ljust(24, "0")
        for i in range(3):
            spr[y * 3 + i] = int(bits[i * 8:i * 8 + 8], 2)
    L += byte_lines("cursor_spr", spr + [0], 16, "κέρσορας: hires sprite")
    L.append("")
    # font: 5 bytes ανά χαρακτήρα, pixels στο slot %11
    L.append("; font 3x5: ανά χαρακτήρα 5 bytes (μία γραμμή του γλύφου, %11 = pixel)")
    L.append(f"; σειρά: \"{FONT_ORDER}\"")
    assert len(FONT_ORDER) * 5 <= 256
    L.append("font_gfx")
    for ch in FONT_ORDER:
        g = [pack4([3 if c == "#" else 0 for c in r + "."]) for r in FONT[ch]]
        L.append("        .byte " + hexes(g) + f"  ; {ch!r}")
    L.append("")
    tab = []
    for c in range(32, 96):
        ch = chr(c)
        tab.append(FONT_ORDER.index(ch) * 5 if ch in FONT_ORDER else 0)
    L.append("; ASCII 32-95 -> θέση του γλύφου στο font_gfx (x 5)")
    L.append("font_map")
    for i in range(0, 64, 16):
        L.append("        .byte " + ",".join(str(x) for x in tab[i:i + 16]))
    return L


# ---------------------------------------------------------------------------
# Φυσική (plan.md §5): ίδιοι πίνακες με τον CPC.
G = 96              # 0.375 γραμμές/καρέ²
H_MAX = 256
T_MAX = 128


def make_physics():
    g = G / 256
    vy0, tt = [], []
    for h in range(H_MAX):
        v = math.sqrt(2 * g * h)
        vy0.append(round(v * 256))
        tt.append(max(1, round(v / g)) if h else 1)
    recip = [0xFFFF] + [min(0xFFFF, round(65536 / t)) for t in range(1, T_MAX)]
    L = [
        "; physics.asm — ΠΑΡΑΓΕΤΑΙ από το assets/src/make_gfx.py, μην το αλλάζεις με το χέρι",
        "",
        f"GRAVITY         = {G}            ; 8.8, γραμμές/καρέ²",
        "",
        "; ταχύτητα (8.8, θετική) για άνοδο/πτώση h γραμμών, h = 0..255: low, high",
    ]
    L += byte_lines("phys_v_lo", [v & 0xFF for v in vy0])
    L += byte_lines("phys_v_hi", [v >> 8 for v in vy0])
    L.append("; χρόνος (καρέ) για άνοδο/πτώση h γραμμών")
    L += byte_lines("phys_t", tt)
    L.append("; 65536/T, T = 0..127")
    L += byte_lines("phys_recip_lo", [v & 0xFF for v in recip])
    L += byte_lines("phys_recip_hi", [v >> 8 for v in recip])
    return L


# ---------------------------------------------------------------------------
def preview():
    """Ένα μπουκάλι με τέσσερις στρώσεις, όπως το ζωγραφίζει ο κώδικας (x4)."""
    tmpl, imask = bottle_cells()
    W, H = 16, 72
    img = Image.new("RGB", (W, H))
    px = img.load()
    layers = [4, 9, 4, 13]
    for y in range(BOTTLE_H):
        k = cell_row(y)
        for c in range(4):
            t, m = tmpl[y][c], imask[y][c]
            for i in range(4):
                sh = 6 - 2 * i
                s = t >> sh & 3
                liquid = m >> sh & 3
                col = BLACK
                if liquid and BODY_TOP <= y <= BODY_BOTTOM:
                    b = BODY_BOTTOM - y
                    col = PEN_COLOUR[layers[b // 15]]
                elif s:
                    if k == 0:
                        col = {1: GREY, 3: WHITE}[s]
                    elif k == 8 and c in (1, 2):
                        col = {2: GREY, 3: WHITE}[s]
                    else:
                        col = GREY if c in (0, 3) else WHITE
                px[c * 4 + i, y + 2] = RGB[col]
    os.makedirs(PREVIEW, exist_ok=True)
    img.resize((W * 8, H * 4), Image.NEAREST).save(os.path.join(PREVIEW, "bottle.png"))


def main():
    os.makedirs(DATA, exist_ok=True)
    with open(os.path.join(DATA, "gfx.asm"), "w") as f:
        f.write("\n".join(make_gfx()) + "\n")
    with open(os.path.join(DATA, "physics.asm"), "w") as f:
        f.write("\n".join(make_physics()) + "\n")
    preview()
    print("assets/data/gfx.asm, assets/data/physics.asm, assets/preview/bottle.png")


if __name__ == "__main__":
    main()
