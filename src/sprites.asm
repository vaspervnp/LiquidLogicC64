; sprites.asm — η πηγή στην πτήση και ο πίδακας, σε hardware sprites
;
; Στον CPC η πηγή πετάει πάνω από τα άλλα μπουκάλια με το φόντο σε buffers.
; Στο bitmap του C64 αυτό θα χαλούσε τα χρώματα των cells, οπότε η πηγή,
; όσο πετάει και γέρνει, είναι 4 multicolor sprites με διπλό ύψος (3-6: δύο
; στήλες των 12 pixels, δύο σειρές των 42 γραμμών): %01 γυαλί ($D025), %11 το
; άδειο εσωτερικό ($D026, μαύρο), %10 το υγρό, με το χρώμα των sprites να
; αλλάζει από στρώση σε στρώση με raster interrupts (fly_events, hw.asm).
; Γέρνει γραμμή-γραμμή κατά tilt_table pixels, όπως στον CPC.
;
; Ο πίδακας στον αέρα (σωματίδια σε πτήση) είναι 3 hires sprites με διπλό
; ύψος (0-2: 36 pixels x 42 γραμμές), με δύο buffers: η φυσική γράφει τον
; ένα όσο φαίνεται ο άλλος. Μέσα στον στόχο τα σωματίδια σχεδιάζονται με
; XOR στο bitmap, όπως στον CPC (particles.asm).

SPR_SRC_N       = 3             ; πρώτο sprite της πηγής
JET_W           = 36            ; pixels
JET_ROWS        = 21            ; γραμμές του sprite (x 2 στην οθόνη)

; Ολόκληρη η πηγή στα sprites (35 γραμμές του sprite).
render_fly
        lda #0
        sta rf_r
-       jsr render_fly_row
        inc rf_r
        lda rf_r
        cmp #SPR_ROWS
        bne -
        rts

; Οι γραμμές 14-20 των κάτω sprites (κάτω από το μπουκάλι): διάφανες.
clear_fly_tail
        lda #0
        ldx #3*(21-14)-1
-       sta SPR_BASE+(SPR_BLK_SRC+2)*64+14*3,x
        sta SPR_BASE+(SPR_BLK_SRC+3)*64+14*3,x
        dex
        bpl -
        rts

; Η γραμμή rf_r του sprite (γραμμές 2r, 2r+1 του μπουκαλιού).
render_fly_row
        lda rf_r
        asl a
        asl a
        tax
        lda spr_base,x
        sta buf0
        lda spr_base+1,x
        sta buf1
        lda spr_base+2,x
        sta buf2
        lda spr_base+3,x
        sta buf3
        lda rf_r                ; b = BODY_BOTTOM - (2r + 1): υγρό αν b < src_shown
        asl a
        eor #$ff
        sec
        adc #BODY_BOTTOM-1
        cmp src_shown
        bcs _bulb               ; (και οι γραμμές έξω από το σώμα: b >= 128 ή > 59)
        ldy #0
-       lda spr_liq,x           ; %11 -> %10 στα pixels του υγρού
        and #$55
        eor #$ff
        and buf0,y
        sta buf0,y
        inx
        iny
        cpy #4
        bne -
_bulb   lda src_drop
        beq _shift
        lda rf_r
        cmp #3
        bcs _shift
        asl a                   ; x 8
        asl a
        asl a
        tax
        ldy #0
-       lda spr_bulb,x
        eor #$ff
        and buf0,y
        ora spr_bulb+4,x
        sta buf0,y
        inx
        iny
        cpy #4
        bne -
_shift  lda #0
        sta tmp4
        sta tmp5
        lda fly_tilt            ; μετατόπιση = fly_shift ± tilt_table[2r]
        beq _o
        lda rf_r
        asl a
        tax
        lda tilt_table,x
        ldx fly_tilt
        bpl +
        eor #$ff
        sec
        adc #0
+
_o      clc
        adc fly_shift
        sta tmp0                ; pixels δεξιά (0-8)
        cmp #4                  ; ολόκληρο byte
        bcc _bits
        sbc #4
        sta tmp0
        lda buf3
        sta tmp4
        lda buf2
        sta buf3
        lda buf1
        sta buf2
        lda buf0
        sta buf1
        lda #0
        sta buf0
        lda tmp0
        cmp #4
        bcc _bits
        sbc #4
        sta tmp0
        lda tmp4
        sta tmp5
        lda buf3
        sta tmp4
        lda buf2
        sta buf3
        lda buf1
        sta buf2
        lda #0
        sta buf1
_bits   ldx tmp0
        beq _store
-       .rept 2
        lsr buf0
        ror buf1
        ror buf2
        ror buf3
        ror tmp4
        ror tmp5
        .endrept
        dex
        bne -
_store  lda rf_r                ; στο sprite: πάνω (0-20) ή κάτω (21-34)
        ldx #<(SPR_BASE+SPR_BLK_SRC*64)
        cmp #21
        bcc +
        sbc #21
        ldx #<(SPR_BASE+(SPR_BLK_SRC+2)*64)
+       sta tmp1
        asl a
        adc tmp1                ; x 3
        sta tmp1
        txa
        clc
        adc tmp1
        tay                     ; (τα blocks είναι στη σελίδα $c0 / $c1)
        lda #>(SPR_BASE+SPR_BLK_SRC*64)
        cpx #<(SPR_BASE+SPR_BLK_SRC*64)
        beq +
        lda #>(SPR_BASE+(SPR_BLK_SRC+2)*64)
+       sta ptr2+1
        lda #0
        sta ptr2
        lda buf0
        sta (ptr2),y
        iny
        lda buf1
        sta (ptr2),y
        iny
        lda buf2
        sta (ptr2),y
        tya                     ; το δεξί sprite: +64 - 2
        clc
        adc #62
        tay
        lda buf3
        sta (ptr2),y
        iny
        lda tmp4
        sta (ptr2),y
        iny
        lda tmp5
        sta (ptr2),y
        rts

rf_r    .byte 0
        .cerror (SPR_BASE+SPR_BLK_SRC*64)/256 != (SPR_BASE+SPR_BLK_SRC*64+127)/256, "sprite blocks cross a page"
        .cerror (SPR_BASE+(SPR_BLK_SRC+2)*64)/256 != (SPR_BASE+(SPR_BLK_SRC+2)*64+127)/256, "sprite blocks cross a page"

; Οι θέσεις των 4 sprites της πηγής από τα fly_x, fly_y (σκιές).
fly_place
        lda fly_x+1             ; X = SPR_X0 + 2 * (x - fly_shift)
        sec
        sbc fly_shift
        sta tmp0
        lda #0
        sbc #0
        sta tmp1
        asl tmp0
        rol tmp1
        lda tmp0
        clc
        adc #SPR_X0
        sta tmp0
        lda tmp1
        adc #0
        sta tmp1
        ldx #SPR_SRC_N
        jsr _setx
        ldx #SPR_SRC_N+2
        jsr _setx
        lda tmp0                ; η δεξιά στήλη: +24
        clc
        adc #24
        sta tmp0
        lda tmp1
        adc #0
        sta tmp1
        ldx #SPR_SRC_N+1
        jsr _setx
        ldx #SPR_SRC_N+3
        jsr _setx
        lda fly_y+1
        clc
        adc #SPR_Y0
        sta sh_spr_y+SPR_SRC_N
        sta sh_spr_y+SPR_SRC_N+1
        clc
        adc #42
        sta sh_spr_y+SPR_SRC_N+2
        sta sh_spr_y+SPR_SRC_N+3
        rts
_setx   lda tmp0
        sta sh_spr_x,x
        lda tmp1
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

fly_show
        lda #1
        sta fly_on
        lda sh_spr_ena
        ora #%01111000
        sta sh_spr_ena
        rts

fly_hide
        lda #0
        sta fly_on
        lda sh_spr_ena
        and #%10000111
        sta sh_spr_ena
        rts

;------------------------------------------------------------------
; Raster: τα γεγονότα του επόμενου καρέ (ev_*). Η διαβάθμιση του CPC (μαύρο,
; μπλε από τη γρ. 86, ματζέντα από τη 138) στο border, και, όσο πετάει η
; πηγή, το χρώμα κάθε στρώσης της στα sprites της.
BAND1_Y         = 86
BAND2_Y         = 138

fly_events
        lda ev_ready            ; (το interrupt δεν το πήρε ακόμα)
        bne _r
        lda #0
        sta ev_n
        lda opt_theme
        bne _fly
        lda #RASTER_Y0+BAND1_Y
        ldx #1
        ldy #BLUE
        jsr ev_add
        lda #RASTER_Y0+BAND2_Y
        ldx #1
        ldy #PURPLE
        jsr ev_add
_fly    lda fly_on
        beq _fill
        ldx src_n
        beq _fill
        dex
        stx tmp4                ; στρώση k (η επάνω πρώτα)
        lda src_pens,x
        jsr pen_col
        tay
        lda fly_y+1             ; από τη γρ. BODY_TOP: το χρώμα της επάνω
        clc
        adc #RASTER_Y0+BODY_TOP
        ldx #2
        jsr ev_add
        lda fly_y+1             ; tmp5 = raster του πάτου του υγρού + 1
        clc
        adc #RASTER_Y0+BODY_BOTTOM+1
        sta tmp5
_lay    ldx tmp4
        beq _fill
        lda src_pens-1,x        ; αλλάζει χρώμα: από τη γρ. του ορίου
        cmp src_pens,x
        beq _same
        jsr pen_col
        tay
        lda tmp4                ; όριο = πάτος + 1 - k * LH
        ldx src_lh
        jsr mul8
        sta tmp6
        lda tmp5
        sec
        sbc tmp6
        ldx #2
        jsr ev_add
_same   dec tmp4
        jmp _lay
_fill   ldx #0                  ; ταξινομημένα: το καθένα κρατάει και τα δύο χρώματα
        lda bord_col
        sta tmp4
        lda #WHITE
        sta tmp5
-       cpx ev_n
        beq _done
        lda ev_bord,x           ; (στο ev_add: ev_bord = τύπος, ev_spr = χρώμα)
        cmp #1
        bne +
        lda ev_spr,x
        sta tmp4
        jmp ++
+       lda ev_spr,x
        sta tmp5
+       lda tmp4
        sta ev_bord,x
        lda tmp5
        sta ev_spr,x
        inx
        jmp -
_done   lda #1
        sta ev_ready
_r      rts

; Νέο γεγονός: A = raster, X = τύπος (1 border, 2 sprites), Y = χρώμα. Στη
; θέση του κατά raster (insertion sort)· έξω από την εικόνα: τίποτα.
ev_add
        cmp #RASTER_Y0+2
        bcc _r
        cmp #FRAME_LINE-1
        bcs _r
        sta tmp0
        stx tmp1
        sty tmp2
        ldx ev_n
        cpx #16
        bcs _r
-       cpx #0                  ; μετακινεί προς τα πάνω όσα είναι μετά
        beq _put
        lda ev_line-1,x
        cmp tmp0
        bcc _put
        beq _put
        sta ev_line,x
        lda ev_bord-1,x
        sta ev_bord,x
        lda ev_spr-1,x
        sta ev_spr,x
        dex
        jmp -
_put    lda tmp0
        sta ev_line,x
        lda tmp1
        sta ev_bord,x
        lda tmp2
        sta ev_spr,x
        inc ev_n
_r      rts

;------------------------------------------------------------------
; Ο πίδακας: τα 3 sprites στο jet_x0, jet_y0, χρώμα του pour_pen.
jet_show
        lda jet_x0
        ldx #0
        jsr spr_setx
        lda jet_x0
        clc
        adc #12
        ldx #1
        jsr spr_setx
        lda jet_x0
        clc
        adc #24
        ldx #2
        jsr spr_setx
        lda jet_y0
        clc
        adc #SPR_Y0
        sta sh_spr_y
        sta sh_spr_y+1
        sta sh_spr_y+2
        lda pour_pen
        jsr pen_col
        sta sh_spr_col
        sta sh_spr_col+1
        sta sh_spr_col+2
        lda #0                  ; και οι δύο buffers άδειοι
        ldx #191
-       sta SPR_BASE+SPR_BLK_JET*64,x
        sta SPR_BASE+SPR_BLK_JET*64+192,x
        dex
        cpx #$ff
        bne -
        lda #1
        sta jet_on
        lda sh_spr_ena
        ora #%00000111
        sta sh_spr_ena
        rts

jet_hide
        lda #0
        sta jet_on
        lda sh_spr_ena
        and #%11111000
        sta sh_spr_ena
        rts

; Οι pointers των sprites του πίδακα στον buffer που φαίνεται (jet_buf ^ 1:
; η φυσική γράφει στον jet_buf).
jet_ptrs
        lda jet_buf
        eor #1
        sta tmp7
        asl a
        adc tmp7                ; x 3
        adc #(SPR_BASE&$3fff)/64+SPR_BLK_JET
        sta sh_spr_ptr
        adc #1
        sta sh_spr_ptr+1
        adc #1
        sta sh_spr_ptr+2
        rts

; ptr2 = ο buffer που γράφει η φυσική, άδειος.
jet_clear
        lda #<(SPR_BASE+SPR_BLK_JET*64)
        ldx jet_buf
        beq +
        lda #<(SPR_BASE+(SPR_BLK_JET+3)*64)
+       sta ptr2
        lda #>(SPR_BASE+SPR_BLK_JET*64)
        sta ptr2+1
        lda #0
        ldy #191
-       sta (ptr2),y
        dey
        cpy #$ff
        bne -
        rts

; Σωματίδιο στο (pc_x, pc_y) στον buffer ptr2, αν είναι μέσα στην περιοχή.
jet_plot
        lda pc_x
        sec
        sbc jet_x0
        cmp #JET_W
        bcs _r
        tax
        lda pc_y
        and #$fe
        sec
        sbc jet_y0
        cmp #2*JET_ROWS
        bcs _r
        lsr a
        tay
        lda jet_row3,y
        clc
        adc jet_xoff,x
        tay
        lda jet_xmask,x
        ora (ptr2),y
        sta (ptr2),y
_r      rts

; pixel 0-35 -> θέση στον buffer (sprite * 64 + byte) και μάσκα (2 bits hires)
jet_xoff  .byte (range(JET_W) / 12) * 64 + (range(JET_W) % 12) / 4
jet_xmask .byte $c0 >> ((range(JET_W) % 4) * 2)
jet_row3  .byte range(JET_ROWS) * 3
