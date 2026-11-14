; bottles.asm — μπουκάλια: διάταξη στην οθόνη, σχεδίαση σειρά-σειρά cells,
; σημάνσεις των ειδικών τύπων (κρυμμένες, πάγος, λουκέτο, κουρτίνα,
; σταγονόμετρο, εγκοπές), κέρσορας
;
; Το μπουκάλι (16 x 70) πιάνει 4 cells σε πλάτος και 9 σειρές cells: το
; πάνω του είναι στη γραμμή 2 μιας cell (B_Y = 8k + 2), οπότε ο λαιμός (γρ.
; 0-5) έχει τη δική του σειρά (k = 0) και κάθε σειρά του σώματος έχει το πολύ
; δύο στρώσεις (στρώση >= 10 γραμμές). Χρώματα (gfx.asm, make_gfx.py):
;   k = 0    %01 γυαλί, %10 φελλός (ή το υγρό της ροής), %11 λευκό
;   k = 1-7  %01, %10 τα υγρά της σειράς (από κάτω προς τα πάνω), %11 γυαλί
;            (cells 0, 3) ή λευκό (cells 1, 2: η λάμψη)
;   k = 8    %01 υγρό, %10 γυαλί, %11 γυαλί / λευκό
; Η κουρτίνα: %01 το χρώμα της, %10 γυαλί. Το λουκέτο πιάνει ολόκληρες τις
; cells 1, 2 των σειρών 4-5: %01 το χρώμα του.

; Εγγραφή μπουκαλιού (BOT_SIZE bytes, στο bottles), όπως στον CPC
B_X             = 0             ; στήλη (cell)
B_Y             = 1             ; πρώτη γραμμή, όταν δεν είναι σηκωμένο
B_CAP           = 2             ; χωρητικότητα (στρώσεις)
B_CNT           = 3             ; στρώσεις μέσα
B_LH            = 4             ; γραμμές ανά στρώση (60 / cap)
B_RAISE         = 5             ; 0 ή RAISE_H όταν είναι επιλεγμένο
B_DONE          = 6             ; 1 = ολοκληρωμένο (ένα χρώμα, γεμάτο)
B_ROW           = 7             ; 0 / 1
B_LAY           = 8             ; στρώσεις από κάτω: pen, bit 7 = κρυμμένη
B_FLAGS         = 14            ; BF_*
B_FREEZE        = 15            ; κινήσεις ως το ξεπάγωμα (0 = όχι πάγος)
B_LOCK          = 16            ; pen του λουκέτου (0 = όχι)
B_TILT          = 17            ; (στον C64 γέρνει μόνο το sprite της πηγής)
BOT_SIZE        = 24
MAX_BOTTLES     = 14
MAX_CAP         = 6

BF_CAP          = 7             ; bflags της πίστας: χωρητικότητα (0 = της πίστας)
BF_DROPPER      = 8             ; μία στρώση τη φορά
BF_CURTAIN      = 16            ; κρυμμένο ως την πρώτη μετάγγιση

LF_HIDDEN       = 1             ; flags της πίστας
LF_MOVES        = 2
LF_TIMER        = 4
LF_EXTRA        = 8

ROW_Y1          = 26            ; δύο σειρές (y = 8k + 2)
ROW_Y2          = 114
ONE_ROW_Y       = 66            ; ως ROW_MAX μπουκάλια: μία σειρά
ROW_MAX         = 5
BOTTLE_PITCH    = 5             ; cells
RAISE_H         = 8
CURSOR_DY       = BOTTLE_H+2    ; ο κέρσορας κάτω από το μπουκάλι
CURTAIN_PEN     = 11            ; ρίγες με γκρι
ICE_NUM_DY      = BODY_TOP+25

bot_lo  .byte <(bottles + range(MAX_BOTTLES) * BOT_SIZE)
bot_hi  .byte >(bottles + range(MAX_BOTTLES) * BOT_SIZE)

; bptr = μπουκάλι A. Κρατάει A, X, Y.
bottle_ix
        pha
        stx tmp7
        tax
        lda bot_lo,x
        sta bptr
        lda bot_hi,x
        sta bptr+1
        ldx tmp7
        pla
        rts

; A = πρώτη γραμμή του μπουκαλιού bptr στην οθόνη. Αλλάζει Y.
bottle_top
        ldy #B_Y
        lda (bptr),y
        ldy #B_RAISE
        sec
        sbc (bptr),y
        rts

; A = A * B (8 bit, χωρίς υπερχείλιση). Αλλάζει tmp6.
mul8
        sta tmp6
        lda #0
        cpx #0
        beq +
-       clc
        adc tmp6
        dex
        bne -
+       rts

; Φορτώνει μια πίστα (plan.md §6, assets/data/levels.asm). in: ptr1 =
;   header:   .byte flags, μπουκάλια, χωρητικότητα, κινήσεις, χρονόμετρο, par
;   μπουκάλι: .byte bflags, freeze, lock, πλήθος, pens από κάτω...
level_setup
        ldy #0
        lda (ptr1),y
        sta level_flags
        iny
        lda (ptr1),y
        sta nbottles
        iny
        lda (ptr1),y
        sta level_cap
        iny
        lda (ptr1),y
        sta level_moves
        iny
        lda (ptr1),y
        sta level_timer
        iny
        lda (ptr1),y
        sta level_par
        iny
        sty tmp_y               ; θέση στα δεδομένα
        lda #0
        sta tmp_row             ; μπουκάλι
_bot    lda tmp_row
        jsr bottle_ix
        ldy tmp_y
        lda (ptr1),y            ; bflags
        sta tmp4
        and #BF_CAP
        bne +
        lda level_cap
+       jsr bottle_init
        lda tmp4
        and #$ff-BF_CAP
        ldy #B_FLAGS
        sta (bptr),y
        ldy tmp_y
        iny
        lda (ptr1),y            ; freeze
        sta tmp4
        iny
        lda (ptr1),y            ; lock
        sta tmp5
        iny
        lda (ptr1),y            ; στρώσεις
        iny
        sty tmp_y
        ldy #B_FREEZE
        pha
        lda tmp4
        sta (bptr),y
        iny
        lda tmp5
        sta (bptr),y
        pla
        ldy #B_CNT
        sta (bptr),y
        tax
        beq _empty
        lda #B_LAY
        sta tmp5
-       ldy tmp_y
        lda (ptr1),y
        iny
        sty tmp_y
        ldy tmp5
        sta (bptr),y
        inc tmp5
        dex
        bne -
_empty  jsr check_done
        inc tmp_row
        lda tmp_row
        cmp nbottles
        bne _bot
        jmp layout

; Άδειο μπουκάλι bptr χωρητικότητας A (χωρίς θέση· layout).
bottle_init
        ldy #B_CAP
        sta (bptr),y
        sta tmp6                ; B_LH = BODY_LINES / cap
        ldx #$ff
        lda #BODY_LINES
        sec
-       inx
        sbc tmp6
        bcs -
        txa
        ldy #B_LH
        sta (bptr),y
        lda #0
        ldy #B_RAISE
        sta (bptr),y
        ldy #B_DONE
        sta (bptr),y
        ldy #B_CNT
        sta (bptr),y
        ldy #B_FREEZE
        sta (bptr),y
        iny
        sta (bptr),y            ; B_LOCK
        iny
        sta (bptr),y            ; B_TILT
        rts

; Μοιράζει τα nbottles μπουκάλια σε σειρές και τα κεντράρει (B_X, B_Y, B_ROW).
; Με ίσες σειρές η επάνω πάει μία cell αριστερά και η κάτω μία δεξιά.
layout
        lda nbottles
        cmp #ROW_MAX+1
        bcc _one
        clc
        adc #1
        lsr a                   ; (n+1)/2 στην επάνω σειρά
        sta row_len
        sta tmp0
        lda nbottles
        sec
        sbc tmp0
        sta row_len+1
        lda #2
        bne _rows
_one    sta row_len
        lda #0
        sta row_len+1
        lda #1
_rows   sta nrows
        lda #0
        sta row_start
        lda row_len
        sta row_start+1
        lda #0
        sta tmp_row             ; σειρά
        sta tmp4                ; μπουκάλι
_row    ldx tmp_row
        lda row_len,x
        sta tmp1                ; μπουκάλια στη σειρά
        tax                     ; x0 = (41 - n * PITCH) / 2
        lda #41
        sec
-       sbc #BOTTLE_PITCH
        dex
        bne -
        lsr a
        sta tmp0
        lda row_len
        cmp row_len+1
        bne _xok
        ldx tmp_row             ; ίσες σειρές: ±1
        dec tmp0
        cpx #0
        beq _xok
        inc tmp0
        inc tmp0
_xok    lda nrows
        ldx #ONE_ROW_Y
        cmp #1
        beq _y
        ldx #ROW_Y1
        lda tmp_row
        beq _y
        ldx #ROW_Y2
_y      stx tmp2
_bot    lda tmp4
        jsr bottle_ix
        ldy #B_X
        lda tmp0
        sta (bptr),y
        iny
        lda tmp2
        sta (bptr),y            ; B_Y
        ldy #B_ROW
        lda tmp_row
        sta (bptr),y
        lda tmp0
        clc
        adc #BOTTLE_PITCH
        sta tmp0
        inc tmp4
        dec tmp1
        bne _bot
        inc tmp_row
        lda tmp_row
        cmp nrows
        bne _row
        rts

; B_DONE = 1 αν το μπουκάλι είναι γεμάτο με ένα χρώμα (και οι κρυμμένες του
; στρώσεις αποκαλύπτονται). bptr = μπουκάλι. Κρατάει X.
check_done
        stx tmp7
        ldy #B_DONE
        lda #0
        sta (bptr),y
        ldy #B_CNT
        lda (bptr),y
        ldy #B_CAP
        cmp (bptr),y
        bne _no
        tax
        ldy #B_LAY
        lda (bptr),y
        and #$7f
        sta tmp6
-       lda (bptr),y
        and #$7f
        cmp tmp6
        bne _no
        iny
        dex
        bne -
        ldy #B_CNT              ; ολοκληρωμένο: όλο ορατό
        lda (bptr),y
        tax
        ldy #B_LAY
-       lda (bptr),y
        and #$7f
        sta (bptr),y
        iny
        dex
        bne -
        ldy #B_DONE
        lda #1
        sta (bptr),y
_no     ldx tmp7
        rts

;------------------------------------------------------------------
; Ολόκληρο μπουκάλι bptr: οι 9 σειρές cells και ο αριθμός του πάγου.
; rb_pour = 1: είναι ο στόχος της μετάγγισης (rb_shown γραμμές υγρού, και το
; χρώμα της ροής σε κάθε σειρά, για τα σωματίδια: t_fill).
draw_bottle
        lda #0
        sta rb_pour
draw_bottle_p
        jsr rb_setup
        lda #0
        sta rb_k
-       jsr render_row
        inc rb_k
        lda rb_k
        cmp #9
        bne -
        ldy #B_FREEZE           ; ο πάγος: οι κινήσεις ως το ξεπάγωμα
        lda (bptr),y
        beq _done
        jsr num_str
        lda #<num_buf+1
        ldy #>num_buf+1
        jsr set_text
        ldy #B_FREEZE
        lda (bptr),y
        cmp #10
        bcs +
        inc ptr0                ; ένα ψηφίο
+       lda rb_top
        clc
        adc #ICE_NUM_DY
        tay
        ldx rb_col
        inx
        lda #$ff                ; λευκό (το %11 των cells 1, 2)
        jmp print_str
_done   rts

; Τα στοιχεία της σχεδίασης του bptr: rb_top, rb_row0, rb_col, rb_shown,
; rb_lh, rb_flags.
rb_setup
        jsr bottle_top
        sta rb_top
        sec
        sbc #2
        lsr a
        lsr a
        lsr a
        sta rb_row0
        ldy #B_X
        lda (bptr),y
        sta rb_col
        ldy #B_LH
        lda (bptr),y
        sta rb_lh
        lsr a                   ; θέση του «?» μέσα στη στρώση
        clc
        adc #2
        sta rb_qpos
        ldy #B_FLAGS
        lda (bptr),y
        sta rb_flags
        lda rb_pour
        beq +
        lda dst_shown
        sta rb_shown
        rts
+       ldy #B_CNT
        lda (bptr),y
        ldx rb_lh
        jsr mul8
        sta rb_shown
        rts

; Μία σειρά cells (rb_k = 0-8) του μπουκαλιού: χρώματα και 8 γραμμές x 4 cells.
render_row
        lda rb_row0
        clc
        adc rb_k
        sta rb_R
        asl a
        asl a
        asl a
        tay
        ldx rb_col
        jsr scr_addr
        lda rb_R
        ldx rb_col
        jsr cell_addr
        lda rb_k                ; L0 = 8k - 2
        asl a
        asl a
        asl a
        sec
        sbc #2
        sta rb_L0
        ; χρώματα ανά γραμμή (row_col) και στρώση / θέση (row_lay, row_pos)
        ldx #0
_lc     lda #0
        sta row_col,x
        lda #$ff
        sta row_lay,x
        txa
        clc
        adc rb_L0
        cmp #BODY_TOP
        bcc _lnext              ; (και οι αρνητικές: >= 128)
        cmp #BODY_BOTTOM+1
        bcs _lnext
        eor #$ff                ; b = BODY_BOTTOM - L
        sec
        adc #BODY_BOTTOM
        sta tmp0
        ldy #$ff                ; στρώση = b / LH, θέση = b % LH
        sec
-       iny
        sbc rb_lh
        bcs -
        adc rb_lh
        sta row_pos,x
        tya
        sta row_lay,x
        lda tmp0
        cmp rb_shown
        bcs _lnext              ; πάνω από το υγρό: άδειο
        tya
        clc
        adc #B_LAY
        tay
        lda (bptr),y
        bpl +
        lda #PEN_HIDDEN
+       sta row_col,x
_lnext  inx
        cpx #8
        bne _lc
        ; slots: τα χρώματα από κάτω προς τα πάνω
        lda #0
        sta rb_s1
        sta rb_s2
        ldx #7
-       lda row_col,x
        beq _sn
        cmp rb_s1
        beq _sn
        ldy rb_s1
        bne +
        sta rb_s1
        bne _sn
+       sta rb_s2
_sn     dex
        bpl -
        lda rb_pour             ; ο στόχος: και το χρώμα της ροής
        beq _sd
        lda pour_pen
        cmp rb_s1
        beq _sd
        cmp rb_s2
        beq _sd
        ldy rb_s1
        bne +
        sta rb_s1
        bne _sd
+       ldy rb_k
        cpy #8
        beq _sd
        ldy rb_s2
        bne _sd
        sta rb_s2
_sd     lda rb_pour             ; t_fill: το pattern της ροής σε αυτή τη σειρά
        beq _cols
        ldx #$aa
        lda rb_k
        beq +
        ldx #$55
        lda pour_pen
        cmp rb_s1
        beq +
        ldx #$aa
        cmp rb_s2
        beq +
        ldx #0
+       txa
        ldx rb_k
        sta t_fill,x
_cols   jsr row_colours
        ; οι 8 γραμμές
        lda #0
        sta rb_i
_line   lda rb_i
        clc
        adc rb_L0
        sta rb_L
        bpl +
        lda #0                  ; πάνω από το μπουκάλι
        sta buf0
        sta buf1
        sta buf2
        sta buf3
        jmp _store
+       asl a                   ; tp = bottle_tmpl + L * 4
        asl a
        sta tmp0
        lda #0
        rol a
        sta tmp1
        clc
        lda tmp0
        adc #<bottle_tmpl
        sta tp
        lda tmp1
        adc #>bottle_tmpl
        sta tp+1
        clc
        lda tmp0
        adc #<bottle_imask
        sta mp
        lda tmp1
        adc #>bottle_imask
        sta mp+1
        ldx rb_i                ; fill του χρώματος της γραμμής
        lda row_col,x
        beq _fz
        ldy #$55
        cmp rb_s1
        beq +
        ldy #$aa
+       sty tmp2
        jmp _comp
_fz     sta tmp2
_comp   ldy #0
        lda (mp),y
        and tmp2
        ora (tp),y
        sta buf0
        iny
        lda (mp),y
        and tmp2
        ora (tp),y
        sta buf1
        iny
        lda (mp),y
        and tmp2
        ora (tp),y
        sta buf2
        iny
        lda (mp),y
        and tmp2
        ora (tp),y
        sta buf3
        jsr row_marks
_store  ldy rb_i
        lda buf0
        sta (scr),y
        tya
        clc
        adc #8
        tay
        lda buf1
        sta (scr),y
        tya
        adc #8
        tay
        lda buf2
        sta (scr),y
        tya
        adc #8
        tay
        lda buf3
        sta (scr),y
        inc rb_i
        lda rb_i
        cmp #8
        beq +
        jmp _line
+       rts

; Οι σημάνσεις στη γραμμή rb_L (buf0-3): κουρτίνα, «?», πάγος, εγκοπές,
; λουκέτο, φελλός / βολβός.
row_marks
        lda rb_L
        cmp #BODY_TOP
        bcs _body
        cmp #5                  ; λαιμός, γρ. 0-4: φελλός ή βολβός
        bcs _ret
        asl a
        asl a
        tax
        ldy #B_DONE
        lda (bptr),y
        bne _cork
        lda rb_flags
        and #BF_DROPPER
        beq _ret
        lda bulb_ov,x
        ldy bulb_ov+1,x
        jsr ov1
        lda bulb_ov+2,x
        ldy bulb_ov+3,x
        jmp ov2
_cork   lda cork_ov,x
        ldy cork_ov+1,x
        jsr ov1
        lda cork_ov+2,x
        ldy cork_ov+3,x
        jmp ov2
_ret    rts
_body   cmp #BODY_BOTTOM+1
        bcs _ret
        ldx rb_i
        lda rb_flags
        and #BF_CURTAIN
        beq _q
        ldx #0                  ; κουρτίνα
-       lda buf0,x
        and curtain_mask,x
        ora curtain_pat,x
        sta buf0,x
        inx
        cpx #4
        bne -
        jmp _ice
_q      lda row_col,x           ; «?» στη μέση της κρυμμένης στρώσης
        cmp #PEN_HIDDEN
        bne _ice
        lda rb_qpos
        sec
        sbc row_pos,x
        cmp #5
        bcs _ice
        asl a
        asl a
        tax
        lda hidden_q_ov,x
        ldy hidden_q_ov+1,x
        jsr ov1
        lda hidden_q_ov+2,x
        ldy hidden_q_ov+3,x
        jsr ov2
_ice    ldy #B_FREEZE
        lda (bptr),y
        beq _tick
        ldx rb_L
        lda ice_line,x
        beq _tick
        ldx #0
        cmp #1
        beq +
        ldx #8
+       ldy #0
-       lda ice_ov0,x           ; m, p ανά cell
        eor #$ff
        and buf0,y
        ora ice_ov0+1,x
        sta buf0,y
        inx
        inx
        iny
        cpy #4
        bne -
_tick   ldy #B_CAP              ; άλλη χωρητικότητα από της πίστας: εγκοπές
        lda (bptr),y
        cmp level_cap
        beq _lock
        sec
        sbc #1
        sta tmp0                ; στρώση < cap - 1
        ldx rb_i
        lda row_lay,x
        cmp tmp0
        bcs _lock
        lda rb_lh               ; θέση = LH-1 ή LH-2
        sec
        sbc row_pos,x
        cmp #3
        bcs _lock
        cmp #1
        bcc _lock
        lda tick_ov
        eor #$ff
        and buf0
        ora tick_ov+1
        sta buf0
        lda tick_ov+2
        eor #$ff
        and buf3
        ora tick_ov+3
        sta buf3
_lock   ldy #B_LOCK             ; λουκέτο: οι cells 1, 2 των γρ. 30-45
        lda (bptr),y
        beq _r
        lda rb_L
        sec
        sbc #LOCK_TOP
        cmp #LOCK_H
        bcs _r
        asl a
        asl a
        tax
        lda lock_ov+1,x
        sta buf1
        lda lock_ov+3,x
        sta buf2
_r      rts

; buf1 / buf2 = (buf & ~A) | Y. Κρατάει X.
ov1     eor #$ff
        and buf1
        sta buf1
        tya
        ora buf1
        sta buf1
        rts
ov2     eor #$ff
        and buf2
        sta buf2
        tya
        ora buf2
        sta buf2
        rts

; Τα χρώματα των 4 cells της σειράς rb_k (vram, cram).
row_colours
        lda glass_col
        sta rc_glass
        lda rb_k
        bne _body
        lda pour_pen            ; λαιμός: γυαλί | φελλός (ή η ροή), λευκό
        jsr pen_col
        ldx rb_pour
        bne +
        lda #CORK_COLOUR
+       sta tmp0
        lda rc_glass
        asl a
        asl a
        asl a
        asl a
        ora tmp0
        ldx #WHITE
        ldy #3
-       sta (vram),y
        pha
        txa
        sta (cram),y
        pla
        dey
        bpl -
        rts
_body   lda rb_flags
        and #BF_CURTAIN
        beq _liq
        lda #CURTAIN_PEN
        jsr pen_col
        asl a
        asl a
        asl a
        asl a
        ora rc_glass
        sta tmp0
        jmp _put
_liq    lda rb_s1
        jsr pen_col
        asl a
        asl a
        asl a
        asl a
        sta tmp0
        lda rb_k
        cmp #8
        bne +
        lda rc_glass            ; ο πάτος: %10 = γυαλί
        bne ++
+       lda rb_s2
        jsr pen_col
+       ora tmp0
        sta tmp0
_put    ldy #0
        lda tmp0
        sta (vram),y
        ldy #3
        sta (vram),y
        lda rc_glass
        sta (cram),y
        ldy #0
        sta (cram),y
        lda #WHITE
        iny
        sta (cram),y
        iny
        sta (cram),y
        ldy #B_LOCK             ; οι cells 1, 2 του λουκέτου
        lda (bptr),y
        beq _nolock
        ldx rb_k
        cpx #4
        bcc _nolock
        cpx #6
        bcs _nolock
        jsr pen_col
        asl a
        asl a
        asl a
        asl a
        ldy #1
        sta (vram),y
        iny
        sta (vram),y
        rts
_nolock lda tmp0
        ldy #1
        sta (vram),y
        iny
        sta (vram),y
        rts

rb_pour  .byte 0
rb_top   .byte 0
rb_row0  .byte 0
rb_col   .byte 0
rb_shown .byte 0
rb_lh    .byte 0
rb_qpos  .byte 0
rb_flags .byte 0
rb_k     .byte 0
rb_R     .byte 0
rb_L0    .byte 0
rb_L     .byte 0
rb_i     .byte 0
rb_s1    .byte 0
rb_s2    .byte 0
rc_glass .byte 0
row_lay  .fill 8
row_pos  .fill 8

; Γραμμή υγρού στον στόχο της μετάγγισης (liquid_sync): ξανασχεδιάζεται η
; σειρά cells της γραμμής. in: A = γραμμή από κάτω (0-59), bptr.
liquid_row
        eor #$ff                ; L = BODY_BOTTOM - A
        sec
        adc #BODY_BOTTOM
        clc
        adc #2
        lsr a
        lsr a
        lsr a
        sta rb_k
        jmp render_row

; Σβήνει το μπουκάλι bptr (και τη σειρά πάνω του, για το σήκωμα).
clear_bottle
        ldy #B_X
        lda (bptr),y
        tax
        ldy #B_Y
        lda (bptr),y
        sec
        sbc #RAISE_H+2
        tay
        lda #BOTTLE_W
        sta tmp0
        lda #BOTTLE_H+RAISE_H+2
        sta tmp1
        jmp clear_rect

; Σβήνει και ξανασχεδιάζει (σήκωμα, κατέβασμα, undo).
redraw_bottle
        jsr clear_bottle
        jmp draw_bottle

draw_all_bottles
        lda #0
        sta tmp_x0
-       lda tmp_x0
        jsr bottle_ix
        jsr draw_bottle
        inc tmp_x0
        lda tmp_x0
        cmp nbottles
        bne -
        rts

;------------------------------------------------------------------
; Κέρσορας (sprite 7) κάτω από το μπουκάλι A.
SPR_Y0          = 50            ; sprite Y της γραμμής 0 του bitmap
SPR_X0          = 24            ; sprite X του pixel 0 (x 2)

cursor_draw
        jsr bottle_ix
        ldy #B_X
        lda (bptr),y
        asl a
        asl a
        clc
        adc #4                  ; pixel 4 του μπουκαλιού
        ldx #7
        jsr spr_setx
        ldy #B_Y
        lda (bptr),y
        clc
        adc #CURSOR_DY+SPR_Y0
        sta sh_spr_y+7
        lda sh_spr_ena
        ora #$80
        sta sh_spr_ena
        rts

cursor_erase
        lda sh_spr_ena
        and #$7f
        sta sh_spr_ena
        rts

; Sprite X: X του pixel A (0-159, multicolor) -> σκιά (με το bit 8).
spr_setx
        sta tmp6
        lda #0
        sta tmp7
        asl tmp6                ; x 2
        rol tmp7
        lda tmp6
        clc
        adc #SPR_X0
        sta sh_spr_x,x
        lda tmp7
        adc #0
        beq +
        lda spr_bit,x
        ora sh_spr_msb
        sta sh_spr_msb
        rts
+       lda spr_bit,x
        eor #$ff
        and sh_spr_msb
        sta sh_spr_msb
        rts

spr_bit .byte 1,2,4,8,16,32,64,128
