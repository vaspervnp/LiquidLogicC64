#!/usr/bin/env python3
"""Εικόνες και PDF των εγχειριδίων.

    python3 tools/manual.py shots   # docs/imgs/*.png από τον headless VICE
    python3 tools/manual.py pdf     # docs/manual-el.pdf, docs/manual-en.pdf
    python3 tools/manual.py         # και τα δύο

Οι εικόνες παίζονται σαν παίκτης με τα πλήκτρα (tools/c64test.py).
Το PDF: markdown -> HTML (με CSS για A4) -> LibreOffice χωρίς παράθυρο.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import c64test as t  # noqa: E402
import levels  # noqa: E402

DOCS = os.path.join(t.ROOT, "docs")
IMGS = os.path.join(DOCS, "imgs")


def shots():
    os.makedirs(IMGS, exist_ok=True)
    t.SHOTS = IMGS
    levs = levels.levels()
    g = t.Player()
    try:
        g.run(60)
        g.shot("title")
        for key, name in (("o", "options"), ("d", "seed"), ("h", "help")):
            g.key(key)
            g.run(10)
            g.shot(name)
            g.key("esc")
            g.run(10)
        while g.peek("mode") != t.MODE_TITLE:
            g.key("fire")
            g.run(5)

        # επιλογή πίστας, με μερικές λυμένες
        g.poke("unlocked", 24)
        for k in range(23):
            g.poke(g.lab["stars"] + k, (3, 3, 2, 3, 1, 3, 2)[k % 7])
        g.key("fire")
        g.run(10)
        g.shot("select")
        g.key("esc")
        g.run(10)

        # πίστα 1 ως τη νίκη
        g.start_game()
        g.play(levs[0], "1")
        g.run(30)
        g.shot("win")

        # πίστα 12: επιλεγμένη πηγή, μετά ο πίδακας στη μέση
        idx = 11
        g.load_level(idx)
        i, j, _ = levs[idx]["solution"][0]
        g.select(i)
        g.run(5)
        g.shot("select_source")
        g.goto(j)
        g.run(1, ["fire"])
        g.until(lambda: g.peek("p_alive") >= 24, 400)
        g.run(20)
        g.shot("pour")
        g.until(lambda: g.peek("state") != t.ST_POUR, 600)

        # κάρτα: η πρώτη πίστα με κρυμμένες στρώσεις
        hidden = next(k for k, lv in enumerate(levs) if any(x & 0x80 for b in lv["bottles"] for x in b["layers"]))
        g.poke("seen_cards", 0)
        g.poke("seen_cards+1", 0)
        g.poke("level", hidden)
        g.key("r")
        g.until(lambda: g.peek("mode") == t.MODE_CARD, 300)
        g.run(10)
        g.shot("card")
        while g.peek("mode") == t.MODE_CARD:
            g.key("fire")
            g.run(3)

        # πίστα 100, μετά λυμένη: το τέλος
        g.load_level(99)
        g.run(10)
        g.shot("specials")
        g.play(levs[99], "100")
        g.run(30)
        g.key("fire")
        g.run(150)
        g.shot("ending")
        t.to_title(g)

        # στατιστικά
        g.key("s")
        g.run(10)
        g.shot("stats")
        g.key("esc")
        g.run(10)

        # «Χαλάρωση» με seed
        g.key("d")
        g.run(5)
        for k in "2026":
            g.key(k)
        g.key("fire")
        g.run(20)
        g.shot("relax")
        t.to_title(g)

        # θέμα NEON (ξεκλείδωσε με την 100)
        g.key("o")
        g.run(5)
        for _ in range(3):
            g.key("down")
        g.key("fire")
        g.check(g.peek("opt_theme") == 1, "NEON: δεν άλλαξε το θέμα")
        g.key("esc")
        g.run(20)
        g.key("fire")
        g.run(10)
        g.key("fire")
        g.run(5)
        while g.peek("mode") == t.MODE_CARD:
            g.key("fire")
        g.load_level(14)
        g.select(levs[14]["solution"][0][0])
        g.run(5)
        g.shot("neon")
    finally:
        g.close()
    for line in g.log:
        print(line)
    print(IMGS)
    return g.fails


CSS = """
@page { size: A4; margin: 18mm 18mm 18mm 18mm; }
body { font-family: 'Noto Sans', 'DejaVu Sans', sans-serif; font-size: 10.5pt;
       line-height: 1.4; color: #222; }
h1 { font-size: 22pt; color: #40318d; border-bottom: 2px solid #40318d;
     padding-bottom: 4pt; margin-bottom: 2pt; }
h2 { font-size: 15pt; color: #40318d; margin-top: 16pt; }
h3 { font-size: 12pt; color: #333; }
table { border-collapse: collapse; width: 100%; margin: 6pt 0; }
th, td { border: 1px solid #bbb; padding: 3pt 6pt; vertical-align: top; }
th { background: #e4e0f2; }
code { font-family: 'DejaVu Sans Mono', monospace; font-size: 9.5pt; }
pre { background: #f2f2f2; padding: 6pt; }
p.img { text-align: center; margin: 8pt 0; }
table.figs, table.figs td { border: none; padding: 0 4pt; text-align: center; }
table.figs td { width: 50%; }
p.cap { margin: 2pt 0 8pt 0; font-size: 9pt; }
em { color: #555; }
"""


def figures(body):
    """Εικόνα + λεζάντα (<p><img></p><p><em></em></p>): οι συνεχόμενες ανά δύο
    σε πίνακα, δίπλα-δίπλα. Μέγεθος με width και height στο <img> (το
    LibreOffice δεν κοιτάει το CSS, ούτε μόνο το width). Οι εικόνες του VICE
    είναι 704 x 464."""
    fig = re.compile(r'<p><img alt="[^"]*" src="([^"]+)" /></p>\s*<p><em>(.*?)</em></p>')
    group = re.compile(r'(?:' + fig.pattern + r'\s*)+')

    def cell(m):
        return f'<td align="center"><img src="{m.group(1)}" width="300" height="198" /><p class="cap" align="center"><em>{m.group(2)}</em></p></td>'

    def table(m):
        cells = [cell(f) for f in fig.finditer(m.group(0))]
        if len(cells) == 1:
            f = fig.search(m.group(0))
            return f'<p class="img" align="center"><img src="{f.group(1)}" width="420" height="277" /></p><p class="cap" align="center"><em>{f.group(2)}</em></p>\n'
        rows = ["<tr>" + "".join(cells[i:i + 2]) + "</tr>" for i in range(0, len(cells), 2)]
        return '<table class="figs">' + "".join(rows) + "</table>\n"

    return group.sub(table, body)


def pdf():
    import markdown
    for lang in ("el", "en"):
        src = os.path.join(DOCS, f"manual-{lang}.md")
        with open(src, encoding="utf-8") as f:
            md = f.read()
        body = markdown.markdown(md, extensions=["tables", "fenced_code"])
        body = figures(body)
        tmp = tempfile.mkdtemp()
        html = os.path.join(tmp, f"manual-{lang}.html")
        with open(html, "w", encoding="utf-8") as f:
            f.write(f'<!doctype html><html lang="{lang}"><head><meta charset="utf-8">'
                    f"<style>{CSS}</style></head><body>{body}</body></html>")
        shutil.copytree(IMGS, os.path.join(tmp, "imgs"))
        subprocess.run(["libreoffice", "--headless", "--convert-to", "pdf:writer_web_pdf_Export",
                        "--outdir", tmp, html], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        shutil.copy(os.path.join(tmp, f"manual-{lang}.pdf"), os.path.join(DOCS, f"manual-{lang}.pdf"))
        shutil.rmtree(tmp)
        print(os.path.join(DOCS, f"manual-{lang}.pdf"))


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    fails = 0
    if what in ("shots", "all"):
        fails = shots()
    if what in ("pdf", "all"):
        pdf()
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
