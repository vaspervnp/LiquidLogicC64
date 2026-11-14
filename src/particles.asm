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
        stx tmp0
        clc
        adc tmp0
        sta tmp0                ; τέλος
        ldy #0
-       lda dl_lo,x
        sta ptr3
        lda dl_hi,x
        sta ptr3+1
        lda (ptr3),y
        eor dl_val,x
        sta (ptr3),y
        iny
        lda (ptr3),y
        eor dl_val,x
        sta (ptr3),y
        dey
        inx
        cpx tmp0
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
        lda src_shown           ; η γραμμή του sprite (2 γραμμές του
        lsr a                   ; μπουκαλιού: αλλάζει όταν αδειάσει η
        bcs _src                ; κάτω, δηλαδή σε ζυγό src_shown)
        lda src_shown
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
; Οι πίνακες του στόχου για τα σωματίδια μέσα του (μετά το draw_bottle_p,
; που βάζει το t_fill): ανά γραμμή από το dst_top - 2 (72 γραμμές) η
; διεύθυνση της στήλης 0 στο bitmap και το pattern της ροής.
target_tables
        lda dst_top
        sec
        sbc #2
        sta ti_base
        ldy #B_X
        lda (dptr),y
        sta tmp4
        asl a
        asl a
        sta dst_px
        ldx #0
-       txa
        clc
        adc ti_base
        tay
        lda ytab_lo,y
        ldy tmp4
        clc
        adc col8_lo,y
        sta ti_lo,x
        txa
        clc
        adc ti_base
        tay
        lda ytab_hi,y
        ldy tmp4
        adc col8_hi,y
        sta ti_hi,x
        txa
        lsr a
        lsr a
        lsr a
        tay
        lda t_fill,y
        sta ti_fill,x
        inx
        cpx #9*8
        bne -
        rts

ti_base .byte 0
dst_px  .byte 0

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
; νέος buffer του πίδακα (για όσα πετάνε). X = σωματίδιο· όταν σβήνει, το
; τελευταίο (ακόμα όχι ενημερωμένο) μπαίνει στη θέση του και ενημερώνεται.
part_update
        lda dlist               ; η νέα λίστα στον άλλο buffer
        eor #MAX_PART
        sta plist
        sta pl_end
        jsr jet_clear           ; (ptr2 = ο buffer του πίδακα)
        ldx #0
        cpx p_alive
        bcc _p
        jmp _fin
_p      lda p_vyl,x             ; vy += g, ως VY_MAX
        clc
        adc #GRAVITY
        sta p_vyl,x
        lda p_vyh,x
        adc #0
        bmi _vy                 ; αρνητικό: ανεβαίνει
        cmp #VY_MAX
        bcc _vy
        lda #0
        sta p_vyl,x
        lda #VY_MAX
_vy     sta p_vyh,x
        tay
        lda p_yl,x              ; y += vy
        clc
        adc p_vyl,x
        sta p_yl,x
        tya
        adc p_yh,x
        sta p_yh,x
        sta pc_y
        lda p_xl,x              ; x += vx
        clc
        adc p_vxl,x
        sta p_xl,x
        lda p_xh,x
        adc p_vxh,x
        sta p_xh,x
        sta pc_x
        ldy p_st,x
        dey
        beq +
        jmp _inside

        ; πτήση (A = x)
+       cmp #160
        bcc +
        jmp _kill               ; έξω αριστερά/δεξιά
+       lda pc_y
        cmp #240
        bcs _next               ; αρνητικό y: πάνω από την οθόνη
        cmp #200
        bcc +
        jmp _kill
+       ldy p_vyh,x
        bmi _plot               ; ανεβαίνει ακόμα
        cmp dst_entry
        bcs _enter
_plot   ldy pc_y                ; στα sprites του πίδακα (jet_tables)
        lda jy_off,y
        bmi _next
        ldy pc_x
        clc
        adc jx_off,y            ; ($ff έξω: carry)
        bcs _next
        sta tmp0
        lda jx_mask,y
        ldy tmp0
        ora (ptr2),y
        sta (ptr2),y
        tya                     ; για το σβήσιμο
        ldy jet_n
        sta (ptr1),y
        inc jet_n
_next   inx
        cpx p_alive
        bcc _p
        jmp _fin

_enter  lda #2                  ; μπαίνει στο λαιμό του B
        sta p_st,x
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
        ldy #0
        cmp #$80
        bcc +
        dey
+       tya
        sta p_vxh,x
        jmp _draw

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
        bcc _draw
        lda p_st,x              ; στην επιφάνεια
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
        ldy #0
        cmp #$80
        bcc +
        dey
+       tya
        sta p_vxh,x
        jmp _draw
_absorb jsr absorb
_kill   dec p_alive             ; το τελευταίο (ακόμα όχι ενημερωμένο) στη θέση του
        ldy p_alive
        sty tmp7
        cpx tmp7
        bcs _fin
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
_draw   lda pc_y                ; στη λίστα XOR (μέσα στο B: ti_*)
        and #$fe
        sec
        sbc ti_base
        cmp #9*8
        bcs _dn
        tay                     ; γραμμή μέσα στις σειρές cells του στόχου
        lda pc_x
        sec
        sbc dst_px
        cmp #16
        bcs _dn
        sta tmp2                ; pixel μέσα στο μπουκάλι
        stx pc_cur
        and #3
        tax
        lda xor_pix,x
        and ti_fill,y
        beq _dn2
        ldx pl_end
        sta dl_val,x
        lda tmp2                ; (pixel / 4) * 8
        and #$0c
        asl a
        adc ti_lo,y
        sta dl_lo,x
        lda ti_hi,y
        adc #0
        sta dl_hi,x
        inc pl_end
_dn2    ldx pc_cur
_dn     jmp _next
_fin    lda pl_end
        sec
        sbc plist
        sta plist_n
        ldx jet_buf
        lda jet_n
        sta jet_cnt,x
        lda #1                  ; ο νέος buffer του πίδακα, για το interrupt
        sta jet_flip
        rts

pl_end  .byte 0
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
