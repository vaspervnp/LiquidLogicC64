; screen.asm — το multicolor bitmap ($e000, 160 x 200): πίνακες διευθύνσεων,
; καθάρισμα, κείμενο, μεγάλα γράμματα
;
; Ένα byte = 4 pixels, μία cell = 4 pixels x 8 γραμμές· οι 40 cells μιας
; σειράς είναι συνεχόμενες (8 bytes η καθεμία). Τα χρώματα ανά cell: %01 στο
; high nibble της screen RAM ($cc00), %10 στο low, %11 στη color RAM ($d800).
; Το κείμενο του CPC (font 3x5, κάθε γραμμή διπλή, 2 bytes = 4 pixels ανά
; χαρακτήρα) εδώ πιάνει ακριβώς μία cell σε πλάτος: x = στήλη 0-39.

; γραμμή y -> διεύθυνση στο bitmap (στήλη 0)
ytab_lo .byte <(BITMAP + 320 * (range(200) / 8) + range(200) % 8)
ytab_hi .byte >(BITMAP + 320 * (range(200) / 8) + range(200) % 8)
; στήλη -> στήλη * 8
col8_lo .byte <(range(40) * 8)
col8_hi .byte >(range(40) * 8)
; σειρά cells -> screen RAM (η color RAM: + $0c00 στο high byte)
vrow_lo .byte <(SCREEN + range(25) * 40)
vrow_hi .byte >(SCREEN + range(25) * 40)
COLRAM_OFS      = >(COLOR_RAM - SCREEN)

slot_fill .byte $00,$55,$aa,$ff ; byte γεμάτο με το slot 0-3

; scr = διεύθυνση της γραμμής Y, στήλη X. Κρατάει X, Y.
scr_addr
        clc
        lda ytab_lo,y
        adc col8_lo,x
        sta scr
        lda ytab_hi,y
        adc col8_hi,x
        sta scr+1
        rts

; vram / cram = cell στη στήλη X, σειρά A. Κρατάει X, Y.
cell_addr
        sty tmp7
        tay
        txa
        clc
        adc vrow_lo,y
        sta vram
        sta cram
        lda vrow_hi,y
        adc #0
        sta vram+1
        adc #COLRAM_OFS
        sta cram+1
        ldy tmp7
        rts

; A = χρώμα του C64 για το pen A. Κρατάει X, Y.
pen_col
        cmp #PEN_GLASS
        beq +
        sty tmp7
        tay
        lda pen_colour,y
        ldy tmp7
        rts
+       lda glass_col
        rts

; Χρώμα A στο slot txt_slot (1-3) της cell (vram/cram). Κρατάει X, Y.
set_slot
        sty tmp7
        ldy #0
        pha
        lda txt_slot
        cmp #2
        beq _lo
        bcs _cram
        pla                     ; %01: high nibble
        asl a
        asl a
        asl a
        asl a
        sta tmp6
        lda (vram),y
        and #$0f
        ora tmp6
        sta (vram),y
        ldy tmp7
        rts
_lo     pla                     ; %10: low nibble
        sta tmp6
        lda (vram),y
        and #$f0
        ora tmp6
        sta (vram),y
        ldy tmp7
        rts
_cram   pla
        sta (cram),y
        ldy tmp7
        rts

; Όλη η οθόνη μαύρη: bitmap, screen RAM, color RAM.
cls
        lda #0
        tax
-
        .for pg := $e0, pg < $ff, pg += 1
        sta pg*256,x
        .endfor
        sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$2e8,x
        sta COLOR_RAM,x
        sta COLOR_RAM+$100,x
        sta COLOR_RAM+$200,x
        sta COLOR_RAM+$2e8,x
        inx
        bne -
        ldx #$3f
-       sta $ff00,x
        dex
        bpl -
        rts

; Μηδενίζει (pen 0) ορθογώνιο: X = στήλη, Y = πρώτη γραμμή, tmp0 = πλάτος
; (cells), tmp1 = ύψος (γραμμές).
clear_rect
        stx tmp2
_ln     ldx tmp2
        jsr scr_addr
        ldx tmp0
        sty tmp3
        ldy #0
        lda #0
-       sta (scr),y
        pha
        tya
        clc
        adc #8
        tay
        pla
        dex
        bne -
        ldy tmp3
        iny
        dec tmp1
        bne _ln
        rts

; Σβήνει μια γραμμή κειμένου: X = στήλη, Y = y, A = χαρακτήρες.
clear_text
        sta tmp0
        lda #10
        sta tmp1
        jmp clear_rect

;------------------------------------------------------------------
; Κείμενο με το font 3x5 (κάθε γραμμή διπλή): μία cell x 10 γραμμές ανά
; χαρακτήρα. in: ptr0 = κείμενο (0 στο τέλος, ASCII 32-95), X = στήλη,
; Y = y, A = pen ($ff: χωρίς αλλαγή χρωμάτων, π.χ. πάνω στο μπουκάλι).
; print_str γράφει στο slot %11 (color RAM)· print_slot στο txt_slot.
; out: X = η στήλη μετά το κείμενο (txt_x).
print_str
        pha
        lda #3
        sta txt_slot
        pla
print_slot
        sta txt_pen
        stx txt_x
        sty txt_y
        ldx txt_slot
        lda slot_fill,x
        sta txt_mask
        lda txt_pen             ; το χρώμα
        cmp #$ff
        beq +
        jsr pen_col
+       sta txt_col
        ldy #0
_ch     lda (ptr0),y
        bne +
        ldx txt_x
        rts
+       iny
        sty txt_i
        sec
        sbc #32
        tax
        lda font_map,x
        sta txt_g
        ; 5 γραμμές του γλύφου, η καθεμία δύο φορές
        lda txt_y
        sta txt_l
        lda #5
        sta txt_r
_row    ldx txt_g
        lda font_gfx,x
        and txt_mask
        sta tmp4
        inc txt_g
        ldx txt_x
        ldy txt_l
        jsr scr_addr
        ldy #0
        lda tmp4
        sta (scr),y
        ldy txt_l
        iny
        jsr scr_addr
        ldy #0
        lda tmp4
        sta (scr),y
        inc txt_l
        inc txt_l
        dec txt_r
        bne _row
        ; τα χρώματα των cells που πιάνει (2 ή 3 σειρές)
        lda txt_col
        cmp #$ff
        beq _next
        lda txt_y
        lsr a
        lsr a
        lsr a
        sta txt_r
        lda txt_y
        clc
        adc #9
        lsr a
        lsr a
        lsr a
        sta txt_l
-       ldx txt_x
        lda txt_r
        jsr cell_addr
        lda txt_col
        jsr set_slot
        inc txt_r
        lda txt_l
        cmp txt_r
        bcs -
_next   inc txt_x
        ldy txt_i
        jmp _ch

txt_x   .byte 0
txt_y   .byte 0
txt_i   .byte 0
txt_g   .byte 0
txt_l   .byte 0
txt_r   .byte 0
txt_mask .byte 0
txt_col .byte 0

; ptr0 = κείμενο A/Y (low, high). Κρατάει X.
set_text
        sta ptr0
        sty ptr0+1
        rts

;------------------------------------------------------------------
; Μεγάλα γράμματα: κάθε pixel του font 3x5 γίνεται 2 pixels x 4 γραμμές, και
; κάθε γραμμή του γλύφου έχει το δικό της pen (big_pens): οι ζυγές στο slot
; %01, οι μονές στο %10, ώστε δύο γραμμές του γλύφου να μοιράζονται μια cell.
; Ένας χαρακτήρας = 2 cells. in: ptr0 = κείμενο, X = στήλη, Y = y (y % 4 = 0).
print_big
        stx txt_x
        sty txt_y
        ldy #0
_ch     lda (ptr0),y
        bne +
        rts
+       iny
        sty txt_i
        sec
        sbc #32
        tax
        lda font_map,x
        sta txt_g
        lda txt_y
        sta txt_l
        lda #0
        sta txt_r               ; γραμμή του γλύφου 0-4
_row    ldx txt_g
        lda font_gfx,x
        inc txt_g
        pha
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        lda big_dbl,x           ; pixels 0, 1 -> cell 0
        sta tmp4
        pla
        and #$0f
        tax
        lda big_dbl,x           ; pixels 2, 3 -> cell 1
        sta tmp5
        lda txt_r
        and #1
        tax
        lda big_mask,x
        and tmp4
        sta tmp4
        lda big_mask,x
        and tmp5
        sta tmp5
        lda #4
        sta tmp3
-       ldx txt_x
        ldy txt_l
        jsr scr_addr
        ldy #0
        lda tmp4
        sta (scr),y
        ldy #8
        lda tmp5
        sta (scr),y
        inc txt_l
        dec tmp3
        bne -
        ; χρώμα της γραμμής στις δύο cells
        lda txt_r
        and #1
        clc
        adc #1
        sta txt_slot
        ldx txt_r
        lda big_cols,x
        sta txt_col
        lda txt_l
        sec
        sbc #1
        lsr a
        lsr a
        lsr a
        ldx txt_x
        jsr cell_addr
        lda txt_col
        jsr set_slot
        inc vram
        inc cram
        lda txt_col
        jsr set_slot
        inc txt_r
        lda txt_r
        cmp #5
        bne _row
        inc txt_x
        inc txt_x
        ldy txt_i
        jmp _ch

; 2 pixels του font (bits 3-0 του nibble: %11 ή %00 ο καθένας) -> 4 pixels
big_dbl .byte $00,$00,$00,$0f,$00,$00,$00,$00,$00,$00,$00,$00,$f0,$00,$00,$ff
big_mask .byte $55,$aa
big_cols .byte LIGHT_RED,RED,ORANGE,YELLOW,LIGHT_GREEN
