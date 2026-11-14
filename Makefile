# Liquid Logic — Commodore 64 (PAL)
#
#   make            build/liquidlogic.d64 (και build/liquidlogic.prg)
#   make assets     ξαναπαράγει τα assets/data (γραφικά, ήχος, πίστες)
#   make run        x64sc με τη δισκέτα
#   make test       headless VICE: λύνει πίστες με τα πλήκτρα, ειδικοί τύποι
#   make shot       headless VICE: εικόνες όλων των οθονών στο build/shots
#   make manual     εικόνες στο docs/imgs και τα PDF των εγχειριδίων
#   make video      headless VICE: βίντεο 4 λεπτών, build/liquidlogic.mp4 (ffmpeg)
#   make clean

TASS     ?= 64tass
C1541    ?= c1541
X64      ?= x64sc
PYTHON   ?= python3

BUILD    := build
PRG      := $(BUILD)/liquidlogic.prg
D64      := $(BUILD)/liquidlogic.d64
SRC      := $(wildcard src/*.asm src/*.inc)
DATA     := assets/data/gfx.asm assets/data/physics.asm assets/data/levels.asm assets/data/sound_data.asm

# -C labels με κεφαλαία/πεζά, -B μακριά branches όπου χρειάζεται, -Wall
TASSFLAGS := -C -B -Wall -I src -I assets/data

.PHONY: all assets run test shot manual video clean

all: $(D64)

$(PRG): $(SRC) $(DATA) Makefile
	@mkdir -p $(BUILD)
	$(TASS) $(TASSFLAGS) src/main.asm -o $@ --vice-labels -l $(BUILD)/labels.txt -L $(BUILD)/liquidlogic.lst

# Η δισκέτα: ένα αρχείο, LOAD"LIQUID",8,1 και RUN (ή LOAD"*",8 / RUN).
$(D64): $(PRG)
	rm -f $@
	$(C1541) -format "liquid logic,ll" d64 $@ -write $(PRG) liquid >/dev/null

assets/data/gfx.asm assets/data/physics.asm: assets/src/make_gfx.py
	$(PYTHON) assets/src/make_gfx.py

assets/data/sound_data.asm: assets/src/make_sound.py
	$(PYTHON) assets/src/make_sound.py

assets/data/levels.asm: tools/levels.py   # (και levels.json, για τα tests)
	$(PYTHON) tools/levels.py

assets:
	$(PYTHON) assets/src/make_gfx.py
	$(PYTHON) assets/src/make_sound.py
	$(PYTHON) tools/levels.py

run: $(D64)
	$(X64) -autostart $(D64)

test: $(PRG)
	$(PYTHON) tools/c64test.py test

shot: $(PRG)
	$(PYTHON) tools/c64test.py shot

manual: $(PRG)
	$(PYTHON) tools/manual.py

video: $(PRG)
	$(PYTHON) tools/video.py

clean:
	rm -rf $(BUILD)
