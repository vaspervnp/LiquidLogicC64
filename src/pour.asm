; pour.asm — μετάγγιση: κανόνες, ενημέρωση στρώσεων, πτήση της πηγής,
; τροχιά του πίδακα

APEX_H          = 6             ; η κορυφή του τόξου, πάνω από το ψηλότερο στόμιο
HOVER_DY        = 12            ; η πηγή, δίπλα στον στόχο: τόσο πιο ψηλά
FLY_N           = 8             ; βήματα της πτήσης (πήγαινε, έλα· ~2 καρέ το καθένα)
MOUTH_X         = 7             ; στόμιο: pixel μέσα στο μπουκάλι
SRC_MOUTH_DY    = -2            ; εκπομπή λίγο πάνω από το χείλος του A
DST_MOUTH_DY    = 3             ; είσοδος στο λαιμό του B

; Y = δείκτης της επάνω στρώσης του μπουκαλιού (ptr) (B_CNT > 0).
top_layer
        ldy #B_CNT
        lda (bptr),y
        clc
        adc #B_LAY-1
        tay
        rts

; Το ίδιο για τον στόχο (dptr).
top_layer_d
        ldy #B_CNT
        lda (dptr),y
        clc
        adc #B_LAY-1
        tay
        rts

; Ξεκινάει τη μετάγγιση sel_src -> sel_dst. out: C = άκυρη.
try_pour
        lda sel_dst
        jsr bottle_ix
        lda bptr
        sta pour_dst
        sta dptr
        lda bptr+1
        sta pour_dst+1
        sta dptr+1
        lda sel_src
        jsr bottle_ix
        lda bptr
        sta pour_src
        lda bptr+1
        sta pour_src+1
        ; κανόνες (plan.md §1, §3)
        lda level_moves         ; όριο κινήσεων
        beq _nolim
        cmp moves
        beq _fail
        bcc _fail
_nolim  ldy #B_CNT
        lda (bptr),y
        beq _fail
        ldy #B_DONE
        lda (dptr),y
        bne _fail
        ldy #B_FREEZE           ; παγωμένος / κλειδωμένος στόχος
        lda (dptr),y
        iny
        ora (dptr),y
        bne _fail
        ldy #B_CAP
        lda (dptr),y
        ldy #B_CNT
        sec
        sbc (dptr),y
        beq _fail
        sta pour_space
        jsr top_layer
        lda (bptr),y
        and #$7f
        sta pour_pen
        ldy #B_CNT
        lda (dptr),y
        beq _ok
        jsr top_layer_d
        lda (dptr),y
        cmp pour_pen
        bne _fail
_ok     jsr top_layer           ; πόσες ίδιες στη σειρά από την κορυφή του A
        ldy #B_CNT
        lda (bptr),y
        tax
        jsr top_layer
        lda #0
        sta tmp0
-       lda (bptr),y
        cmp pour_pen
        bne +
        inc tmp0
        dey
        dex
        bne -
+       ldy #B_FLAGS
        lda (bptr),y
        and #BF_DROPPER
        beq +
        lda #1                  ; σταγονόμετρο: μία στρώση τη φορά
        sta tmp0
+       lda pour_space          ; n = min(run, χώρος)
        cmp tmp0
        bcs +
        sta tmp0
+       lda tmp0
        sta pour_n
        jmp pour_go
_fail   sec
        rts

pour_go
        jsr push_undo           ; η κατάσταση πριν από τη μετάγγιση
        jsr uncurtain           ; η κουρτίνα φεύγει από πηγή και στόχο
        jsr swap_bd
        jsr uncurtain
        jsr swap_bd
        ; η πηγή πετάει δίπλα στον στόχο, από την πλευρά απ' όπου έρχεται
        ; (αν χωράει), με το στόμιο HOVER_DY γραμμές πιο ψηλά, και γέρνει προς
        ; αυτόν. Στη θέση του διπλανού μπουκαλιού (βήμα BOTTLE_PITCH): το
        ; γέρσιμο (ως 4 pixels) μένει στο κενό, έξω από τον στόχο.
        ldy #B_X
        lda (dptr),y
        cmp (bptr),y
        bcc _right
        sec
        sbc #BOTTLE_PITCH       ; αριστερά
        bcc _r
_l      ldx #1
        jmp _hov
_right  cmp #40-BOTTLE_W-BOTTLE_PITCH+1
        bcc _r
        sbc #BOTTLE_PITCH
        jmp _l
_r      lda (dptr),y            ; δεξιά
        clc
        adc #BOTTLE_PITCH
        ldx #$ff
_hov    sta hover_x
        stx hover_tilt
        ldy #B_Y
        lda (dptr),y
        sec
        sbc #HOVER_DY
        sta hover_y
        ; η πηγή φεύγει από το bitmap και γίνεται sprites, σηκωμένη
        jsr clear_bottle
        ldy #B_X
        lda (bptr),y
        sta home_x
        asl a
        asl a
        sta fly_x+1
        lda #$80
        sta fly_x
        sta fly_y
        ldy #B_Y
        lda (bptr),y
        sta home_y
        ldy #B_RAISE
        sec
        sbc (bptr),y
        sta fly_y+1
        lda #0
        sta (bptr),y
        ; τα δεδομένα της πηγής για τα sprites: στρώσεις όπως φαίνονται τώρα
        ldy #B_CNT
        lda (bptr),y
        sta src_n
        tax
        beq _nolay
        ldy #B_LAY
-       lda (bptr),y
        bpl +
        lda #PEN_HIDDEN
+       sta src_pens-B_LAY,y
        iny
        dex
        bne -
_nolay  ldy #B_LH
        lda (bptr),y
        sta src_lh
        ldy #B_FLAGS
        lda (bptr),y
        and #BF_DROPPER
        sta src_drop
        lda #0                  ; όρθιο· με γέρσιμο αριστερά, 4 pixels περιθώριο
        sta fly_tilt
        ldx hover_tilt
        bpl +
        lda #4
+       sta fly_shift

        ; γραμμές οθόνης πριν
        ldy #B_CNT
        lda (bptr),y
        ldy #B_LH
        jsr mul_lh
        sta src_lines
        sta src_shown
        ldy #B_CNT
        lda (dptr),y
        ldy #B_LH
        jsr mul_lh_d
        sta dst_lines
        sta dst_shown
        lda #1
        sta fe_dirty
        jsr render_fly
        jsr clear_fly_tail
        jsr fly_place
        jsr fly_show
        ldx hover_x
        ldy hover_y
        jsr fly_start
        lda #0
        sta pour_phase

        ; λογική: n στρώσεις από το A στο B
        ldx pour_n
-       ldy #B_CNT
        lda (dptr),y
        clc
        adc #B_LAY
        tay
        lda pour_pen
        sta (dptr),y
        ldy #B_CNT
        lda (dptr),y
        clc
        adc #1
        sta (dptr),y
        lda (bptr),y
        sec
        sbc #1
        sta (bptr),y
        dex
        bne -
        ldy #B_CNT              ; η νέα κορυφή της πηγής αποκαλύπτεται (φαίνεται
        lda (bptr),y            ; όταν ξανασχεδιαστεί, στο τέλος)
        beq +
        jsr top_layer
        lda (bptr),y
        and #$7f
        sta (bptr),y
+
        ; γραμμές οθόνης μετά
        ldy #B_CNT
        lda (bptr),y
        ldy #B_LH
        jsr mul_lh
        sta src_final
        ldy #B_CNT
        lda (dptr),y
        ldy #B_LH
        jsr mul_lh_d
        sta dst_target

        ; σωματίδια: n * lhA * PPL, ανά dst_thresh = lhA*PPL μια γραμμή του B
        ldy #B_LH
        lda (bptr),y
        asl a                   ; PPL = 2
        sta dst_thresh
        ldx pour_n
        jsr mul8
        sta emit_left
        lda #0
        sta emit_left+1
        ldy #B_LH
        lda (dptr),y
        sta dst_add
        lda #0
        sta src_acc
        sta dst_acc

        ; όρια του B (pixels)
        ldy #B_X
        lda (dptr),y
        asl a
        asl a
        sta tmp0                ; x του B σε pixels
        clc
        adc #2
        sta dst_xl
        adc #11
        sta dst_xr
        lda tmp0
        clc
        adc #5
        sta dst_nl
        adc #5
        sta dst_nr
        ldy #B_Y
        lda (dptr),y
        sta dst_top
        clc
        adc #BODY_BOTTOM
        sta dst_bottom
        jsr set_dst_surf
        ; ο στόχος ξανά, με το χρώμα της ροής σε κάθε σειρά (t_fill)
        lda #0
        ldx #8
-       sta t_fill,x
        dex
        bpl -
        jsr swap_bd
        lda #1
        sta rb_pour
        jsr draw_bottle_p
        jsr swap_bd
        jsr target_tables
        jsr part_clear
        clc                     ; NC = εντάξει
        rts

; A = A * (bptr),Y / (dptr),Y.
mul_lh
        pha
        lda (bptr),y
        tax
        pla
        jmp mul8
mul_lh_d
        pha
        lda (dptr),y
        tax
        pla
        jmp mul8

; bptr <-> dptr.
swap_bd
        ldx #1
-       lda bptr,x
        ldy dptr,x
        sta dptr,x
        sty bptr,x
        dex
        bpl -
        rts

; Η πηγή έφτασε δίπλα στον στόχο: γέρνει, και η τροχιά του πίδακα.
pour_aim
        lda pour_src
        sta bptr
        lda pour_src+1
        sta bptr+1
        lda pour_dst
        sta dptr
        lda pour_dst+1
        sta dptr+1
        lda hover_tilt
        sta fly_tilt
        jsr render_fly

        ; τροχιά: κορυφή APEX_H πάνω από το ψηλότερο στόμιο
        lda fly_y+1
        sec
        sbc #-SRC_MOUTH_DY
        sta tmp_ys
        ldy #B_Y
        lda (dptr),y
        clc
        adc #DST_MOUTH_DY
        sta dst_entry
        cmp tmp_ys              ; apex = min(ys, yd) - APEX_H
        bcc +
        lda tmp_ys
+       sec
        sbc #APEX_H
        sta tmp2                ; tmp2 = apex
        ; T = t(yd - apex) + t(ys - apex) (χωρίς ζώνη: δίπλα στον στόχο)
        lda dst_entry
        sec
        sbc tmp2
        tax
        lda phys_t,x
        sta tmp_t
        lda tmp_ys
        sec
        sbc tmp2
        tax
        lda phys_t,x
        clc
        adc tmp_t
        cmp #128
        bcc +
        lda #127
+       sta tmp_t
        lda tmp_ys              ; vy0 = -v(ys - apex)
        sec
        sbc tmp2
        tax
        lda #0
        sec
        sbc phys_v_lo,x
        sta base_vy
        lda #0
        sbc phys_v_hi,x
        sta base_vy+1
        lda tmp_ys
        sta emit_y+1
        lda #0
        sta emit_y
        ; vx = dx * (65536/T) / 256
        lda hover_tilt          ; το στόμιο, μετατοπισμένο από το γέρσιμο (x4 pixels)
        asl a
        asl a
        clc
        adc fly_x+1
        clc
        adc #MOUTH_X
        sta emit_x+1
        sta tmp3                ; xs
        lda #$80
        sta emit_x
        ldy #B_X
        lda (dptr),y
        asl a
        asl a
        clc
        adc #MOUTH_X
        sec
        sbc tmp3                ; A = dx (με πρόσημο)
        php
        bcs +
        eor #$ff
        adc #1
+       sta tmp4                ; |dx|
        ldx tmp_t
        lda phys_recip_lo,x
        sta tmp0
        lda phys_recip_hi,x
        sta tmp1
        jsr mul8x16             ; tmp5:tmp6:tmp7 = |dx| * recip (24 bit)
        lda tmp6                ; / 256
        sta base_vx
        lda tmp7
        sta base_vx+1
        plp
        bcs +
        lda #0
        sec
        sbc base_vx
        sta base_vx
        lda #0
        sbc base_vx+1
        sta base_vx+1
+
        ; ο πίδακας στα sprites: από 6 pixels πριν από το στόμιο / το λαιμό,
        ; και 6 γραμμές πάνω από την κορυφή του τόξου
        lda emit_x+1
        cmp dst_nl
        bcc +
        lda dst_nl
+       sec
        sbc #6
        bcs +
        lda #0
+       cmp #160-JET_W
        bcc +
        lda #160-JET_W
+       sta jet_x0
        lda tmp2
        sec
        sbc #6
        and #$fe
        sta jet_y0
        jmp jet_show

; tmp5:tmp6:tmp7 = tmp4 * tmp1:tmp0 (8 x 16 -> 24 bit).
mul8x16
        lda #0
        sta tmp5
        sta tmp6
        sta tmp7
        ldx #8
-       asl tmp5
        rol tmp6
        rol tmp7
        asl tmp4
        bcc +
        clc
        lda tmp5
        adc tmp0
        sta tmp5
        lda tmp6
        adc tmp1
        sta tmp6
        bcc +
        inc tmp7
+       dex
        bne -
        rts

; Βγάζει την κουρτίνα του bptr (και το ξανασχεδιάζει).
uncurtain
        ldy #B_FLAGS
        lda (bptr),y
        and #BF_CURTAIN
        beq +
        lda (bptr),y
        and #$ff-BF_CURTAIN
        sta (bptr),y
        jmp redraw_bottle
+       rts

; Τέλος: όσες γραμμές δεν έφτασαν (σωματίδια που χάθηκαν), η πηγή όρθια
; ξανά, ο πίδακας κρύβεται, και η πηγή πετάει πίσω.
pour_finish
        jsr part_erase          ; ό,τι σχεδιάστηκε σε αυτό το καρέ
        lda dst_target
        sta dst_lines
        lda src_final
        sta src_lines
        jsr liquid_sync
        jsr part_clear
        jsr jet_hide
        lda #0                  ; όρθιο ξανά (και η νέα κορυφή, αν ήταν κρυμμένη)
        sta fly_tilt
        lda pour_src
        sta bptr
        lda pour_src+1
        sta bptr+1
        ldy #B_CNT
        lda (bptr),y
        sta src_n
        tax
        beq _nolay
        ldy #B_LAY
-       lda (bptr),y
        bpl +
        lda #PEN_HIDDEN
+       sta src_pens-B_LAY,y
        iny
        dex
        bne -
_nolay  lda #1
        sta fe_dirty
        jsr render_fly
        ldx home_x
        ldy home_y
        jsr fly_start
        lda pour_dst            ; ο στόχος: φελλός αν ολοκληρώθηκε (και τα
        sta bptr                ; χρώματα του λαιμού όπως πριν)
        lda pour_dst+1
        sta bptr+1
        jsr check_done
        ldy #B_DONE
        lda (bptr),y
        beq +
        lda #<sfx_cork
        ldy #>sfx_cork
        jsr play_sfx
+       jmp draw_bottle

; Η πηγή έφτασε πίσω: από τα sprites ξανά στο bitmap.
pour_land
        jsr fly_hide
        lda pour_src
        sta bptr
        lda pour_src+1
        sta bptr+1
        jmp draw_bottle

;------------------------------------------------------------------
; Πτήση της πηγής (όρθιας) σε FLY_N καρέ, σε ευθεία, με 8.8 βήματα.
; in: X = cell (x 4 = pixels), Y = y προορισμού· από (fly_x, fly_y).
fly_start
        sty tmp_y
        txa
        asl a
        asl a
        tax
        lda #FLY_N              ; γρήγορη: μισά βήματα, διπλά μεγάλα
        ldy opt_speed
        beq +
        lda #FLY_N/2
+       sta fly_cnt
        ldy tmp_y
        txa
        sec
        sbc fly_x+1
        jsr _step
        sta fly_sx
        stx fly_sx+1
        tya
        sec
        sbc fly_y+1
        jsr _step
        sta fly_sy
        stx fly_sy+1
        rts
_step   ldx #0                  ; X:A = A (με πρόσημο) * 256 / FLY_N
        cmp #$80
        bcc +
        dex
+       stx tmp1
        sta tmp0
        ldx #5                  ; x 32 (γρήγορη: x 64)
        lda opt_speed
        beq _sh
        inx
_sh     asl tmp0
        rol tmp1
        dex
        bne _sh
        lda tmp0
        ldx tmp1
        rts
        .cerror FLY_N != 8

; Ένα καρέ της πτήσης. out: Z = έφτασε.
fly_step
        clc
        lda fly_x
        adc fly_sx
        sta fly_x
        lda fly_x+1
        adc fly_sx+1
        sta fly_x+1
        clc
        lda fly_y
        adc fly_sy
        sta fly_y
        lda fly_y+1
        adc fly_sy+1
        sta fly_y+1
        jsr fly_place
        dec fly_cnt
        rts
