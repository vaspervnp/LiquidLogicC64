; particles.asm — η ροή του υγρού ως σωματίδια με βαρύτητα (plan.md §5)
;
; Ίδια φυσική με τον CPC (8.8 fixed point, ίδιοι πίνακες, ίδια σειρά των
; rnd). Τα σωματίδια είναι πίνακες των 64 (p_*, ένας ανά πεδίο: ο 6502 τα
; προσπελάζει με X), πυκνά στην αρχή: νέο στο τέλος, και στη θέση ενός που
; σβήνει μπαίνει το τελευταίο.
;
; Στην πτήση (ST 1) σχεδιάζονται στα sprites του πίδακα (sprites.asm). Μέσα
; στο B (ST 2, ST 3) με XOR στο bitmap, όπως στον CPC: το pattern του
; χρώματος της ροής σε κάθε σειρά cells του στόχου είναι στο t_fill (το
; render_row το βάζει σε κάθε σειρά του στόχου όσο κρατάει η μετάγγιση).
; Μετά το interrupt του καρέ (main.asm), όσο η δέσμη είναι στο κάτω border:
;   part_erase   σβήσιμο όσων σχεδιάστηκαν
;   liquid_sync  οι γραμμές υγρού του A/B φτάνουν τη λογική στάθμη
;   part_draw    σχεδίαση της λίστας που έχτισε η φυσική στο προηγούμενο καρέ

PPL             = 2             ; σωματίδια ανά γραμμή υγρού
EMIT_RATE       = 2             ; εκπομπές ανά καρέ
SPLASH_MASK     = 3             ; rnd & 3 = 0: πιτσίλισμα
VY_MAX          = 4             ; γραμμές/καρέ, τελική ταχύτητα πτώσης

; Ανά καρέ της μετάγγισης, μετά το part_draw. out: Z = τελείωσε.
particles_frame
        jsr part_emit
        jsr part_update
        lda emit_left
        ora emit_left+1
        bne +
        lda p_alive
+       rts

part_clear
        lda #0
        sta p_alive
        sta dlist_n             ; καμία λίστα
        sta plist_n
        sta dlist
        lda #MAX_PART
        sta plist
        rts

;------------------------------------------------------------------
; XOR της λίστας (X = αρχή στα dl_*, A = πλήθος) στο bitmap: δύο γραμμές
; (y ζυγό: η y+1 είναι το επόμενο byte της cell).
xor_list
        cmp #0
        beq _r
        sta tmp0
-       lda dl_lo,x
        sta ptr3
        lda dl_hi,x
        sta ptr3+1
        ldy #0
        lda (ptr3),y
        eor dl_val,x
        sta (ptr3),y
        iny
        lda (ptr3),y
        eor dl_val,x
        sta (ptr3),y
        inx
        dec tmp0
        bne -
_r      rts

part_erase
        ldx dlist
        lda dlist_n
        jsr xor_list
        lda #0
        sta dlist_n
        rts

; Σχεδιάζει τη λίστα του plist, που γίνεται η dlist (για το επόμενο σβήσιμο).
part_draw
        lda plist
        sta dlist
        lda plist_n
        sta dlist_n
        ldx #0
        stx plist_n             ; τίποτα εκκρεμές ως την επόμενη φυσική
        ldx dlist
        jmp xor_list

; Οι γραμμές υγρού φτάνουν τις src_lines (η πηγή, στα sprites) και
; dst_lines (ο στόχος, στο bitmap).
liquid_sync
_src    lda src_shown
        cmp src_lines
        beq _dst
        bcc _dst
        dec src_shown
        lda src_shown           ; η γραμμή του sprite: (BODY_BOTTOM - b) / 2
        eor #$ff
        sec
        adc #BODY_BOTTOM
        lsr a
        sta rf_r
        jsr render_fly_row
        jmp _src
_dst    lda dst_shown
        cmp dst_lines
        bcs _r
        inc dst_shown
        lda pour_dst
        sta bptr
        lda pour_dst+1
        sta bptr+1
        lda #1
        sta rb_pour
        jsr rb_setup
        lda dst_shown
        sec
        sbc #1
        jsr liquid_row
        jmp _dst
_r      rts

;------------------------------------------------------------------
part_emit
        lda #EMIT_RATE
        sta tmp_t
_emit   lda emit_left
        ora emit_left+1
        beq _r
        ldx p_alive             ; γεμάτο: περιμένει το επόμενο καρέ
        cpx #MAX_PART
        bcs _r
        lda emit_left
        bne +
        dec emit_left+1
+       dec emit_left
        inc p_alive
        lda #1                  ; πτήση
        sta p_st,x
        jsr rnd                 ; vy = base_vy ± 16
        and #31
        sec
        sbc #16
        jsr sext
        clc
        adc base_vy
        sta p_vyl,x
        tya
        adc base_vy+1
        sta p_vyh,x
        lda emit_y
        sta p_yl,x
        lda emit_y+1
        sta p_yh,x
        jsr rnd                 ; vx = base_vx ± 32
        and #63
        sec
        sbc #32
        jsr sext
        clc
        adc base_vx
        sta p_vxl,x
        tya
        adc base_vx+1
        sta p_vxh,x
        lda emit_x
        sta p_xl,x
        lda emit_x+1
        sta p_xh,x
        inc src_acc             ; ανά PPL εκπομπές, μια γραμμή λιγότερη στο A
        lda src_acc
        cmp #PPL
        bcc +
        lda #0
        sta src_acc
        jsr src_line_down
+       dec tmp_t
        bne _emit
_r      rts

; Y = επέκταση προσήμου του A (0 / $ff). Κρατάει A, X.
sext
        ldy #0
        cmp #$80
        bcc +
        dey
+       rts

; Μια γραμμή λιγότερη στο A (αν δεν έφτασε στο src_final)· σχεδιάζεται στο
; liquid_sync.
src_line_down
        lda src_lines
        cmp src_final
        beq +
        bcc +
        dec src_lines
+       rts

; Μία γραμμή υγρού παραπάνω στο B (αν δεν έφτασε στο dst_target).
dst_line_up
        lda dst_lines
        cmp dst_target
        bcs +
        inc dst_lines
        lda dst_lines
        jsr pour_plip           ; γουργουρητό
; dst_surf = η πρώτη άδεια γραμμή του B - 1: εκεί ακουμπάει το σωματίδιο
; (που πιάνει τις γραμμές y, y+1).
set_dst_surf
        lda dst_bottom
        sec
        sbc dst_lines
        sec
        sbc #1
        sta dst_surf
+       rts

;------------------------------------------------------------------
; Φυσική όλων των ζωντανών: η νέα λίστα XOR (για όσα είναι μέσα στο B) και ο
; νέος buffer του πίδακα (για όσα πετάνε).
part_update
        lda dlist               ; η νέα λίστα στον άλλο buffer
        eor #MAX_PART
        sta plist
        lda #0
        sta plist_n
        jsr jet_clear
        lda #1
        sta jet_flip_req
        lda p_alive
        bne +
        jmp _fin
+       sta upd_left
        ldx #0
_p      lda p_st,x
        sta pc_st
        lda p_vyl,x             ; vy += g, ως VY_MAX
        clc
        adc #GRAVITY
        sta tmp0
        lda p_vyh,x
        adc #0
        bmi _vy                 ; αρνητικό: ανεβαίνει
        cmp #VY_MAX
        bcc _vy
        lda #0
        sta tmp0
        lda #VY_MAX
_vy     sta p_vyh,x
        sta pc_vyh
        lda tmp0
        sta p_vyl,x
        clc                     ; y += vy
        adc p_yl,x
        sta p_yl,x
        lda p_yh,x
        adc pc_vyh
        sta p_yh,x
        sta pc_y
        clc                     ; x += vx
        lda p_xl,x
        adc p_vxl,x
        sta p_xl,x
        lda p_xh,x
        adc p_vxh,x
        sta p_xh,x
        sta pc_x
        lda pc_st
        cmp #1
        beq _flight
        jmp _inside

_flight lda pc_x
        cmp #160
        bcc +
        jmp _kill               ; έξω αριστερά/δεξιά
+       lda pc_y
        cmp #240
        bcc +
        jmp _next               ; αρνητικό y: πάνω από την οθόνη
+       cmp #200
        bcc +
        jmp _kill
+       lda pc_vyh
        bmi _fdone              ; ανεβαίνει ακόμα
        lda pc_y
        cmp dst_entry
        bcc _fdone
        lda #2                  ; μπαίνει στο λαιμό του B
        sta p_st,x
        sta pc_st
        lda pc_x
        cmp dst_nl
        bcs +
        lda dst_nl
+       cmp dst_nr
        bcc +
        beq +
        lda dst_nr
+       sta p_xh,x
        sta pc_x
        jsr rnd                 ; πέφτει σχεδόν ίσια: vx = ±16
        and #31
        sec
        sbc #16
        sta p_vxl,x
        jsr sext
        tya
        sta p_vxh,x
        jmp _done
_fdone  jsr jet_plot
        jmp _next

_inside lda pc_x                ; τοίχοι: vx = -vx/2
        cmp dst_xl
        bcs +
        lda dst_xl
        jmp _wall
+       cmp dst_xr
        bcc _surf
        beq _surf
        lda dst_xr
_wall   sta p_xh,x
        sta pc_x
        lda p_vxh,x
        cmp #$80
        ror a
        sta tmp1
        lda p_vxl,x
        ror a
        eor #$ff                ; αρνητικό: -(vx >> 1)
        clc
        adc #1
        sta p_vxl,x
        lda tmp1
        eor #$ff
        adc #0
        sta p_vxh,x
_surf   lda pc_y
        and #$fe
        cmp dst_surf
        bcc _done
        lda pc_st               ; στην επιφάνεια
        cmp #2
        bne _absorb
        jsr rnd
        and #SPLASH_MASK
        bne _absorb
        lda #3                  ; πιτσίλισμα: vy = -vy/4, πλάγια ταχύτητα
        sta p_st,x
        lda p_vyh,x
        cmp #$80
        ror a
        sta tmp1
        lda p_vyl,x
        ror a
        sta tmp0
        lda tmp1
        cmp #$80
        ror a
        sta tmp1
        lda tmp0
        ror a
        eor #$ff
        clc
        adc #1
        sta p_vyl,x
        lda tmp1
        eor #$ff
        adc #0
        sta p_vyh,x
        lda dst_surf
        sec
        sbc #2
        sta p_yh,x
        sta pc_y
        jsr rnd
        and #127
        sec
        sbc #64
        sta p_vxl,x
        jsr sext
        tya
        sta p_vxh,x
        jmp _done
_absorb jsr absorb
_kill   dec p_alive             ; το τελευταίο (ακόμα όχι ενημερωμένο) στη θέση του
        dec upd_left
        beq _fin
        ldy p_alive
        lda p_st,y
        sta p_st,x
        lda p_vyl,y
        sta p_vyl,x
        lda p_vyh,y
        sta p_vyh,x
        lda p_yl,y
        sta p_yl,x
        lda p_yh,y
        sta p_yh,x
        lda p_vxl,y
        sta p_vxl,x
        lda p_vxh,y
        sta p_vxh,x
        lda p_xl,y
        sta p_xl,x
        lda p_xh,y
        sta p_xh,x
        jmp _p
_done   lda pc_st               ; στη λίστα XOR (μέσα στο B)
        cmp #1
        beq _fdone
        lda pc_x
        cmp #160
        bcs _next
        lda pc_y
        cmp #198
        bcs _next
        and #$fe
        sta tmp1
        sec                     ; σειρά cells του στόχου: (y - top + 2) / 8
        sbc dst_top
        clc
        adc #2
        lsr a
        lsr a
        lsr a
        cmp #9
        bcs _next
        tay
        lda t_fill,y
        sta tmp2
        lda pc_x
        and #3
        tay
        lda xor_pix,y
        and tmp2
        beq _next
        stx pc_cur
        ldx plist
        txa
        clc
        adc plist_n
        tax
        sta tmp3
        lda pc_x
        lsr a
        lsr a
        tay
        sta tmp4
        ldy tmp1
        lda ytab_lo,y
        ldy tmp4
        clc
        adc col8_lo,y
        sta dl_lo,x
        ldy tmp1
        lda ytab_hi,y
        ldy tmp4
        adc col8_hi,y
        sta dl_hi,x
        lda pc_x
        and #3
        tay
        lda xor_pix,y
        and tmp2
        sta dl_val,x
        inc plist_n
        ldx pc_cur
_next   inx
        dec upd_left
        beq _fin
        jmp _p
_fin    lda jet_flip_req        ; ο νέος buffer του πίδακα, για το interrupt
        sta jet_flip
        rts

jet_flip_req .byte 0
xor_pix .byte $c0,$30,$0c,$03

absorb
        lda dst_acc
        clc
        adc dst_add
        sta dst_acc
-       lda dst_acc
        cmp dst_thresh
        bcc +
        sbc dst_thresh
        sta dst_acc
        txa
        pha
        jsr dst_line_up
        pla
        tax
        jmp -
+       rts
