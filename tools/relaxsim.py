"""Η «Χαλάρωση» με seed όπως στον CPC (src/relax.asm, src/hw.asm: rnd), σε
Python: για το test ότι C64 και CPC δίνουν τις ίδιες πίστες με το ίδιο seed.

    python3 tools/relaxsim.py 42 3      # οι 3 πρώτες πίστες του seed 42
"""

import sys


def rnd(seed):
    """xorshift 16-bit του CPC (John Metcalf), βήμα προς βήμα όπως στο Z80."""
    h, l = seed >> 8, seed & 0xFF
    c = h & 1                               # ld a,h / rra
    a = (c << 7) | (l >> 1)                 # ld a,l / rra
    c = l & 1
    h = a ^ h                               # xor h / ld h,a (το xor μηδενίζει το carry)
    c = l & 1                               # ld a,l / rra
    a = (c << 7) | (h >> 1)                 # ld a,h / rra
    l = a ^ l
    h = l ^ h
    return (h << 8) | l, l


class Rnd:
    def __init__(self, seed):
        self.seed = seed

    def __call__(self):
        self.seed, a = rnd(self.seed)
        return a


def shuffle(r, arr):
    for i in range(len(arr) - 1, 0, -1):
        j = r() % (i + 1)
        arr[i], arr[j] = arr[j], arr[i]


def relax_make(r):
    cols = list(range(4, 16))
    shuffle(r, cols)
    ncol = (r() & 3) + 5
    pool = [c for c in cols[:ncol] for _ in range(4)]
    while True:
        shuffle(r, pool)
        bots = [pool[k * 4:k * 4 + 4] for k in range(ncol)]
        if not any(len(set(b)) == 1 for b in bots):
            return bots + [[], []]


def seeded(seed, n):
    """Η πίστα n (από 1) του seed: seed + n * 257 (ποτέ 0), 8 γύροι του rnd."""
    h = ((seed >> 8) + n) & 0xFF
    l = ((seed & 0xFF) + n) & 0xFF
    s = (h << 8) | l or 1
    r = Rnd(s)
    for _ in range(8):
        r()
    return relax_make(r)


if __name__ == "__main__":
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 2026
    for n in range(1, (int(sys.argv[2]) if len(sys.argv) > 2 else 3) + 1):
        print(n, seeded(seed, n))
