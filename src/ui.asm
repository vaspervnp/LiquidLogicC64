; ui.asm — οθόνες: τίτλος, επιλογή πίστας, αστέρια και πρόοδος

MODE_TITLE      = 0
MODE_SELECT     = 1
MODE_GAME       = 2
MODE_CARD       = 3             ; κάρτα νέου ειδικού τύπου (help.asm)
MODE_OPTIONS    = 4
MODE_HELP       = 5
MODE_STATS      = 6
MODE_END        = 7             ; μετά την πίστα 100 (ending.asm)
MODE_SEED       = 8             ; «Χαλάρωση» με seed (stats.asm)

GRID_Y          = 22            ; επιλογή πίστας: 10 x 10 κελιά
GRID_DY         = 18
CELL_W          = 4             ; cells (16 pixels)

; Ανά καρέ, ανάλογα με την οθόνη.
mode_frame
        ldx #9                  ; keyprev = το keymap του προηγούμενου καρέ
-       lda keymap_old,x        ; (για τα key_new)
        sta keyprev,x
        lda keymap,x
        sta keymap_old,x
        dex
        bpl -
        lda mode
        asl a
        tax
        lda mode_table+1,x
        pha
        lda mode_table,x
        pha
        rts

mode_table
        .word title_frame-1,select_frame-1,game_frame-1,card_frame-1,options_frame-1
        .word help_frame-1,stats_frame-1,ending_frame-1,seed_frame-1

; NZ = το πλήκτρο (A = στήλη του matrix, X = bit) πατήθηκε σε αυτό το καρέ.
key_new
        tay
        txa
        and keyprev,y           ; όχι στο προηγούμενο καρέ (1 = όχι πατημένο)
        sta tmp7
        lda keymap,y            ; ... και πατημένο τώρα
        eor #$ff
        and tmp7
        rts

;------------------------------------------------------------------
; Τίτλος: «LIQUID LOGIC» με μεγάλα γράμματα που κάθε γραμμή τους έχει άλλο
; υγρό, πέντε γεμάτα μπουκάλια, «SPACE PLAY».
title_start
        lda #0
        sta mode
        sta relax
        sta relax_seed
        jsr fly_hide
        jsr jet_hide
        jsr cursor_erase
        jsr music_start
        jsr cls
        lda #<title_bottles
        sta ptr1
        lda #>title_bottles
        sta ptr1+1
        jsr level_setup
        jsr draw_all_bottles
        lda #<str_title1
        ldy #>str_title1
        jsr set_text
        ldx #14
        ldy #8
        jsr print_big
        lda #<str_title2
        ldy #>str_title2
        jsr set_text
        ldx #15
        ldy #32
        jsr print_big
        lda #<page_title
        ldy #>page_title
        jmp print_page

title_frame
        lda input_new           ; R: «Χαλάρωση»
        and #IN_RESTART
        beq _fire
        lda #0
        sta relax_seed
        jmp relax_go
_fire   lda input_new
        and #IN_FIRE
        beq _keys
        lda #<sfx_select
        ldy #>sfx_select
        jsr play_sfx
        jmp select_start
_keys   lda #KR_O
        ldx #KB_O
        jsr key_new
        beq +
        jmp options_start
+       lda #KR_H
        ldx #KB_H
        jsr key_new
        beq +
        jmp help_start
+       lda #KR_S
        ldx #KB_S
        jsr key_new
        beq +
        jmp stats_start
+       lda #KR_D
        ldx #KB_D
        jsr key_new
        beq +
        jmp seed_start
+       rts

; «Χαλάρωση» (relax_seed: με seed ή όχι): η πρώτη πίστα.
relax_go
        lda #1
        sta relax
        sta relax_new
        lda #0
        sta relax_num
        lda #<sfx_select
        ldy #>sfx_select
        jsr play_sfx
        lda #MODE_GAME
        sta mode
        jmp level_start

; Πέντε ολοκληρωμένα μπουκάλια (μορφή πίστας, levels.asm).
title_bottles
        .byte 0,5,4,0,0,0
        .byte 0,0,0,4, 5,5,5,5          ; κόκκινο, πορτοκαλί, κίτρινο,
        .byte 0,0,0,4, 4,4,4,4          ; πράσινο, κυανό
        .byte 0,0,0,4, 6,6,6,6
        .byte 0,0,0,4, 14,14,14,14
        .byte 0,0,0,4, 9,9,9,9

page_title
        .byte 156,CENTER,PEN_WHITE
        .null "SPACE PLAY   R RELAX"
        .byte 170,CENTER,PEN_LIQUID+5
        .null "D SEED  O OPTIONS  H HELP  S STATS"
        .byte 187,CENTER,PEN_GLASS
        .null "COMMODORE 64"
        .byte $ff

;------------------------------------------------------------------
; Επιλογή πίστας: 10 x 10 κελιά με τον αριθμό και τρία αστέρια. Κλειδωμένες
; (πέρα από το unlocked) σε γκρι, ολοκληρωμένες σε κίτρινο. Χρώματα: ο
; αριθμός στο %11, τα αστέρια στο %01 (ένα ανά cell), το πλαίσιο στο %10
; (λευκό σε όλη την οθόνη).
select_start
        lda #MODE_SELECT
        sta mode
        jsr music_start
        jsr cls
        ldx #0                  ; %10 = λευκό παντού (το πλαίσιο)
        lda #WHITE
-       sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$2e8,x
        inx
        bne -
        lda #<page_select
        ldy #>page_select
        jsr print_page
        lda #0
-       pha
        jsr draw_cell
        pla
        clc
        adc #1
        cmp #LEVEL_COUNT
        bne -
        lda level               ; ο κέρσορας στην τελευταία πίστα
        sta sel_level
        ldx #1
        jmp cell_frame

page_select
        .byte 2,CENTER,PEN_WHITE
        .null "SELECT LEVEL"
        .byte $ff

select_frame
        lda input_new
        and #IN_ESC
        beq +
        jmp title_start
+       lda input_new
        and #IN_FIRE
        beq _move
        lda sel_level           ; μόνο ξεκλείδωτες
        cmp unlocked
        bcc +
        lda #<sfx_error
        ldy #>sfx_error
        jmp play_sfx
+       sta level
        lda #<sfx_select
        ldy #>sfx_select
        jsr play_sfx
        lda #MODE_GAME
        sta mode
        jmp level_start
_move   lda input_new
        and #IN_LEFT|IN_RIGHT|IN_UP|IN_DOWN
        bne +
        rts
+       sta tmp_row
        lda #<sfx_tick
        ldy #>sfx_tick
        jsr play_sfx
        lda sel_level           ; σβήσιμο του πλαισίου
        ldx #0
        jsr cell_frame
        lda sel_level
        ldx tmp_row
        cpx #IN_LEFT
        bne _r
        sec
        sbc #1
        bcs _set
        lda #LEVEL_COUNT-1
        bne _set
_r      cpx #IN_RIGHT
        bne _u
        clc
        adc #1
        cmp #LEVEL_COUNT
        bcc _set
        lda #0
        beq _set
_u      cpx #IN_UP
        bne _d
        sec
        sbc #10
        bcs _set
        adc #LEVEL_COUNT
        bne _set
_d      cpx #IN_DOWN
        bne _set
        clc
        adc #10
        cmp #LEVEL_COUNT
        bcc _set
        sbc #LEVEL_COUNT
_set    sta sel_level
        ldx #1
        jmp cell_frame

; A = πίστα -> X = στήλη (cell), Y = y του κελιού.
cell_xy
        ldy #0
-       cmp #10
        bcc +
        sbc #10
        iny
        bne -
+       asl a                   ; στήλη * 4
        asl a
        tax
        tya                     ; y = GRID_Y + σειρά * 18
        asl a
        sta tmp7
        asl a
        asl a
        asl a
        clc
        adc tmp7
        adc #GRID_Y
        tay
        rts

; Κελί της πίστας A: αριθμός και αστέρια.
draw_cell
        sta tmp_x0
        tax
        lda stars,x
        sta tmp_stars
        lda #PEN_GLASS          ; κλειδωμένη
        cpx unlocked
        bcs +
        lda #PEN_WHITE
        ldy tmp_stars
        beq +
        lda #PEN_LIQUID+2       ; ολοκληρωμένη
+       sta tmp_pen
        txa
        clc
        adc #1
        jsr num_str
        lda tmp_x0
        jsr cell_xy
        stx dc_col                ; στήλη
        sty dc_y                ; y
        lda #<(num_buf+1)       ; 2 ψηφία, 3 από το 100
        ldy #>(num_buf+1)
        jsr set_text
        lda tmp_x0
        cmp #99
        bcc +
        dec ptr0
+       ldx dc_col
        inx
        ldy dc_y
        lda tmp_pen
        jsr print_str
        ; τρία αστεράκια κάτω από τον αριθμό, στα pixels 2-3 των cells 0-2:
        ; κίτρινα όσα έχει κερδίσει, γκρι τα υπόλοιπα
        lda #1
        sta txt_slot
        lda #0
        sta tmp3                ; αστέρι 0..2
_star   lda tmp_pen             ; κλειδωμένη: χωρίς αστέρια
        cmp #PEN_GLASS
        beq _r
        lda #PEN_GLASS
        ldx tmp3
        cpx tmp_stars
        bcs +
        lda #PEN_LIQUID+2
+       jsr pen_col
        pha
        lda dc_y
        clc
        adc #12
        lsr a
        lsr a
        lsr a
        pha
        lda dc_col
        clc
        adc tmp3
        tax
        pla
        jsr cell_addr
        pla
        jsr set_slot
        lda dc_y
        clc
        adc #12
        tay
        lda dc_col
        clc
        adc tmp3
        tax
        jsr scr_addr
        ldy #0
        lda #$05                ; pixels 2, 3 στο %01
        sta (scr),y
        iny
        sta (scr),y
        inc tmp3
        lda tmp3
        cmp #3
        bne _star
_r      rts

dc_col  .byte 0                 ; (το print_str αλλάζει τα tmp*)
dc_y    .byte 0

; Πλαίσιο γύρω από το κελί A (X = 1 σχεδίαση, 0 σβήσιμο): γραμμές στο y-3
; και y+15, πλευρές στα pixels 0 και 15, στο slot %10.
cell_frame
        stx tmp6
        jsr cell_xy
        stx tmp4
        tya
        sec
        sbc #3
        sta tmp5                ; πάνω γραμμή
        tay
        jsr _hline
        lda tmp5
        clc
        adc #18
        tay
        jsr _hline
        lda #18                 ; πλευρές
        sta tmp3
-       ldy tmp5
        ldx tmp4
        jsr scr_addr
        ldy #0
        lda #$c0
        jsr _px
        ldy #24
        lda #$03
        jsr _px
        inc tmp5
        dec tmp3
        bne -
        rts
_hline  cpy #200
        bcs _hr
        ldx tmp4
        jsr scr_addr
        ldy #0
        lda #$ff
        jsr _px
        ldy #8
        jsr _px
        ldy #16
        jsr _px
        ldy #24
_px     sta tmp7                ; μάσκα των pixels: %10 ή 0
        eor #$ff
        and (scr),y
        sta tmp2
        lda tmp6
        beq +
        lda tmp7
        and #$aa
        ora tmp2
        sta tmp2
+       lda tmp2
        sta (scr),y
        lda tmp7
_hr     rts

;------------------------------------------------------------------
; Αστέρια για τη νίκη στην πίστα level με moves κινήσεις: 3 ως το par,
; 2 ως par + par/4 + 1, αλλιώς 1. Κρατάει το καλύτερο και ξεκλειδώνει την
; επόμενη. out: A = αστέρια αυτής της φοράς.
award_stars
        ldx #3
        lda moves
        cmp level_par
        beq _got
        bcc _got
        dex
        lda level_par
        lsr a
        lsr a
        clc
        adc level_par
        adc #1
        cmp moves
        bcs _got
        dex
_got    stx tmp_stars
        ldy level
        txa
        cmp stars,y
        bcc _keep
        beq _keep
        sta stars,y
        lda #1
        sta save_dirty
_keep   lda level               ; ξεκλείδωμα της επόμενης
        clc
        adc #2
        cmp #LEVEL_COUNT+1
        bcc +
        lda #LEVEL_COUNT
+       cmp unlocked
        bcc _done
        beq _done
        sta unlocked
        lda #1
        sta save_dirty
_done   lda tmp_stars
        rts

str_title1      .null "LIQUID"
str_title2      .null "LOGIC"
