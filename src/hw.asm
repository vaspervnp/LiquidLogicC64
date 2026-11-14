; hw.asm — υλικό: VIC (bitmap, sprites, raster interrupt), πληκτρολόγιο/joystick,
; ψευδοτυχαίοι αριθμοί

FRAME_LINE      = 251           ; το interrupt του καρέ: αμέσως μετά την εικόνα
RASTER_Y0       = 51            ; raster της γραμμής 0 του bitmap

; Multicolor bitmap στο $e000, χρώματα στο $cc00 (VIC bank 3), sprites.
video_init
        lda #0
        sta VIC_CTRL1           ; οθόνη σβηστή όσο στήνεται
        lda CIA2_DDRA
        ora #3
        sta CIA2_DDRA
        lda CIA2_PRA
        and #$fc                ; bank 3: $c000-$ffff
        sta CIA2_PRA
        lda #$38                ; screen $cc00 (3 x $400), bitmap $e000 ($2000)
        sta VIC_MEM
        lda #$18                ; multicolor, 40 στήλες
        sta VIC_CTRL2
        lda #0
        sta VIC_BORDER
        sta VIC_BG0
        sta bord_col
        jsr cls
        ; sprites: 0-2 ο πίδακας (hires, διπλό ύψος), 3-6 η πηγή (multicolor,
        ; διπλό ύψος), 7 ο κέρσορας (hires)
        lda #%01111000
        sta VIC_SPR_MC
        lda #%01111111
        sta VIC_SPR_YEXP
        lda #0
        sta VIC_SPR_XEXP
        sta VIC_SPR_PRIO
        sta VIC_SPR_ENA
        sta sh_spr_ena
        sta VIC_SPR_MC1         ; %11: το άδειο εσωτερικό, μαύρο
        lda glass_col
        sta VIC_SPR_MC0
        ldx #7
-       lda spr_ptr_init,x
        sta sh_spr_ptr,x
        sta SPR_PTRS,x
        lda #WHITE
        sta sh_spr_col,x
        lda #0
        sta sh_spr_x,x
        sta sh_spr_y,x
        dex
        bpl -
        ldx #63                 ; ο κέρσορας
-       lda cursor_spr,x
        sta SPR_BASE+SPR_BLK_CURSOR*64,x
        dex
        bpl -
        lda #$3b                ; bitmap, οθόνη αναμμένη, 25 γραμμές
        sta VIC_CTRL1
        rts

spr_ptr_init
        .byte (SPR_BASE&$3fff)/64+SPR_BLK_JET, (SPR_BASE&$3fff)/64+SPR_BLK_JET+1
        .byte (SPR_BASE&$3fff)/64+SPR_BLK_JET+2
        .byte (SPR_BASE&$3fff)/64+SPR_BLK_SRC, (SPR_BASE&$3fff)/64+SPR_BLK_SRC+1
        .byte (SPR_BASE&$3fff)/64+SPR_BLK_SRC+2, (SPR_BASE&$3fff)/64+SPR_BLK_SRC+3
        .byte (SPR_BASE&$3fff)/64+SPR_BLK_CURSOR

irq_init
        sei
        lda #<irq
        sta IRQ_VEC
        lda #>irq
        sta IRQ_VEC+1
        lda #0
        sta ec_n
        sta ec_i
        lda VIC_CTRL1
        and #$7f
        sta VIC_CTRL1
        lda #FRAME_LINE
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ_MASK
        sta VIC_IRQ
        rts

;------------------------------------------------------------------
; Raster interrupt. Στη γραμμή FRAME_LINE (κάτω από την εικόνα): sprites από
; τις σκιές, νέα λίστα γεγονότων, ήχος. Μετά, ένα interrupt ανά γεγονός της
; λίστας (ec_*): χρώμα του border (η διαβάθμιση του CPC) και χρώμα του υγρού
; στα sprites της πηγής (μία αλλαγή ανά στρώση). Το interrupt έρχεται μία
; γραμμή νωρίτερα και περιμένει την αρχή της γραμμής του γεγονότος.
irq
        pha
        txa
        pha
        tya
        pha
        lda #1
        sta VIC_IRQ
        ldx ec_i
        cpx ec_n
        bcs irq_frame
_event  lda ec_line,x           ; ως την αρχή της γραμμής
-       cmp VIC_RASTER
        beq +
        bcs -
+       lda ec_spr,x
        sta VIC_SPR_COL+3
        sta VIC_SPR_COL+4
        sta VIC_SPR_COL+5
        sta VIC_SPR_COL+6
        lda ec_bord,x
        sta VIC_BORDER
        inx
        stx ec_i
        cpx ec_n
        bcs _last
        lda ec_line,x           ; το επόμενο: αν είναι ήδη κοντά, τώρα
        sec
        sbc #1
        cmp VIC_RASTER
        bcc _event
        beq _event
        sta VIC_RASTER
        jmp irq_out
_last   lda #FRAME_LINE
        sta VIC_RASTER
irq_out
        pla
        tay
        pla
        tax
        pla
        rti

irq_frame
        ldx bord_col            ; στην αρχή της επόμενης γραμμής (όχι μισή γραμμή)
        lda VIC_RASTER
-       cmp VIC_RASTER
        beq -
        stx VIC_BORDER
        ldx #7                  ; sprites
-       lda sh_spr_col,x
        sta VIC_SPR_COL,x
        dex
        bpl -
        ldy #14
        ldx #7
-       lda sh_spr_x,x
        sta VIC_SPR_X,y
        lda sh_spr_y,x
        sta VIC_SPR_Y,y
        dey
        dey
        dex
        bpl -
        lda sh_spr_msb
        sta VIC_SPR_XMSB
        lda sh_spr_ena
        sta VIC_SPR_ENA
        lda glass_col
        sta VIC_SPR_MC0
        lda jet_flip            ; ο πίδακας: ο buffer που μόλις γράφτηκε
        beq _ptrs
        lda #0
        sta jet_flip
        lda jet_buf
        eor #1
        sta jet_buf
        jsr jet_ptrs            ; (στον buffer που φαίνεται)
_ptrs   ldx #7
-       lda sh_spr_ptr,x
        sta SPR_PTRS,x
        dex
        bpl -
        lda ev_ready            ; γεγονότα του καρέ που ξεκινάει
        beq _ev
        ldx ev_n
        stx ec_n
        dex
        bmi _evd
-       lda ev_line,x
        sta ec_line,x
        lda ev_bord,x
        sta ec_bord,x
        lda ev_spr,x
        sta ec_spr,x
        dex
        bpl -
_evd    lda #0
        sta ev_ready
_ev     lda #0
        sta ec_i
        lda ec_n
        beq +
        lda ec_line
        sec
        sbc #1
        sta VIC_RASTER
+       inc frames_int
        lda #1
        sta frame_flag
        cli                     ; ο ήχος με ανοιχτά interrupts: το πρώτο
        jsr sound_frame         ; γεγονός μπορεί να έρθει στο μεταξύ
        jmp irq_out

; Περιμένει το interrupt του καρέ (τέλος της εικόνας).
wait_frame
        lda #0
        sta frame_flag
-       lda frame_flag
        beq -
        rts

;------------------------------------------------------------------
; Πληκτρολόγιο: οι 8 στήλες του matrix στο keymap (0 = πατημένο), το joystick
; 2 στο keymap+8 και το 1 στο keymap+9 (bits 0-4: πάνω, κάτω, αριστερά,
; δεξιά, fire). Στα tests (test_on) από το test_keys.
read_keys
        ldx #9
        lda test_on
        beq _hw
-       lda test_keys,x
        sta keymap,x
        dex
        bpl -
        rts
_hw     lda #$ff
        sta CIA1_DDRA
        lda #0
        sta CIA1_DDRB
        lda #$ff                ; joystick 2: καμία στήλη επιλεγμένη
        sta CIA1_PRA
        lda CIA1_PRA
        ora #$e0
        sta keymap+8
        lda CIA1_PRB            ; joystick 1
        ora #$e0
        sta keymap+9
        lda #0                  ; κανένα πλήκτρο: όλες οι στήλες $ff
        sta CIA1_PRA
        lda CIA1_PRB
        cmp #$ff
        bne _scan
        ldx #7
-       sta keymap,x
        dex
        bpl -
        rts
_scan   ldx #7
        lda #$7f
-       sta CIA1_PRA
        pha
        lda CIA1_PRB
        sta keymap,x
        pla
        sec
        ror a
        dex
        bpl -
        lda #$ff
        sta CIA1_PRA
        rts

; Ενέργειες του παίκτη, ένα bit η καθεμία.
IN_UP           = 1
IN_DOWN         = 2
IN_LEFT         = 4
IN_RIGHT        = 8
IN_FIRE         = 16
IN_ESC          = 32
IN_RESTART      = 64
IN_UNDO         = 128

; out: input = κρατημένα, input_new = όσα πατήθηκαν σε αυτό το καρέ· το ίδιο
; για τις ενέργειες IN2_* στο input2 / input2_new.
read_input
        jsr read_keys
        lda #$ff                ; κανένα πλήκτρο, joystick ελεύθερο: γρήγορα
        ldx #9
-       and keymap,x
        dex
        bpl -
        cmp #$ff
        bne _map
        lda #0
        sta input
        sta input_new
        sta input2
        sta input2_new
        rts
_map    lda #<key_bindings2
        ldy #>key_bindings2
        jsr map_keys
        lda input2
        eor #$ff
        and tmp0
        sta input2_new
        lda tmp0
        sta input2
        lda #<key_bindings
        ldy #>key_bindings
        jsr map_keys
        ; τα πλήκτρα του κέρσορα: με SHIFT αριστερά / πάνω
        lda keymap
        and #%10000100          ; CRSR ↓ (bit 7), CRSR → (bit 2)
        cmp #%10000100
        beq _csr
        ldx #0                  ; SHIFT: αριστερό (στήλη 1, bit 7) ή δεξί (6, 4)
        lda keymap+1
        bpl _sh
        lda keymap+6
        and #%00010000
        bne +
_sh     ldx #1
+       lda keymap
        and #%00000100
        bne _cd
        lda #IN_RIGHT
        cpx #0
        beq +
        lda #IN_LEFT
+       ora tmp0
        sta tmp0
_cd     lda keymap
        bmi _csr
        lda #IN_DOWN
        cpx #0
        beq +
        lda #IN_UP
+       ora tmp0
        sta tmp0
_csr    lda input
        eor #$ff
        and tmp0
        sta input_new
        lda tmp0
        sta input
        rts

; A/Y = αντιστοιχίσεις (στήλη, μάσκα, ενέργεια ... $ff). out: tmp0 = ενέργειες.
map_keys
        sta ptr0
        sty ptr0+1
        lda #0
        sta tmp0
        ldy #0
_next   lda (ptr0),y            ; στήλη
        cmp #$ff
        beq _done
        tax
        iny
        lda (ptr0),y            ; bit του πλήκτρου: 0 = πατημένο
        iny
        and keymap,x
        bne _up
        lda (ptr0),y
        ora tmp0
        sta tmp0
_up     iny
        bne _next
_done   rts

; στήλη, bit mask, ενέργεια. Οι πρώτες 5 εγγραφές είναι τα πλήκτρα της
; επιλογής (apply_keys: πάνω, κάτω, αριστερά, δεξιά, fire).
key_bindings
        .byte 4,%00000010,IN_UP         ; I
        .byte 4,%00100000,IN_DOWN       ; K
        .byte 4,%00000100,IN_LEFT       ; J
        .byte 5,%00000100,IN_RIGHT      ; L
        .byte 7,%00010000,IN_FIRE       ; SPACE
        .byte 7,%10000000,IN_ESC        ; RUN/STOP
        .byte 7,%00000010,IN_ESC        ; ←
        .byte 2,%00000010,IN_RESTART    ; R
        .byte 3,%01000000,IN_UNDO       ; U
        .byte 8,%00000001,IN_UP         ; joystick 2
        .byte 8,%00000010,IN_DOWN
        .byte 8,%00000100,IN_LEFT
        .byte 8,%00001000,IN_RIGHT
        .byte 8,%00010000,IN_FIRE
        .byte $ff

IN2_EXTRA       = 1
IN2_MENU        = 2

key_bindings2
        .byte 1,%01000000,IN2_EXTRA     ; E
        .byte 4,%00010000,IN2_MENU      ; M
        .byte $ff

; xorshift 16-bit (John Metcalf), ίδιος με του CPC: ίδιο seed, ίδιοι αριθμοί.
; out: A = τυχαίο byte (το low του νέου seed). Κρατάει X, Y.
rnd
        lda rnd_seed+1          ; h:l = (h:l) ^ ((h:l) << 7) κ.λπ., όπως στο Z80:
        lsr a                   ; ld a,h / rra
        lda rnd_seed            ; ld a,l / rra (με το carry του h)
        ror a
        eor rnd_seed+1          ; xor h
        sta rnd_seed+1          ; ld h,a
        lda rnd_seed            ; ld a,l / rra (carry από το προηγούμενο rra)
        ror a
        lda rnd_seed+1          ; ld a,h / rra
        ror a
        eor rnd_seed            ; xor l
        sta rnd_seed            ; ld l,a
        eor rnd_seed+1          ; xor h
        sta rnd_seed+1          ; ld h,a
        lda rnd_seed
        rts
