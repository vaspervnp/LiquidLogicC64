; options.asm — επιλογές (μουσική, εφέ, ταχύτητα, θέμα, πλήκτρα), που
; αποθηκεύονται στο LIQUID.SAV, και κοινά για τις οθόνες κειμένου.

; Πλήκτρα του matrix (στήλη, bit) για τις οθόνες.
KR_D            = 2
KB_D            = %00000100
KR_O            = 4
KB_O            = %01000000
KR_H            = 3
KB_H            = %00100000
KR_S            = 1
KB_S            = %00100000
KR_DEL          = 0
KB_DEL          = %00000001
KR_RET          = 0
KB_RET          = %00000010
KR_ESC          = 7             ; RUN/STOP
KB_ESC          = %10000000
KEY_COLS        = 9             ; 8 στήλες + το joystick 2

OPT_ITEMS       = 6             ; μουσική, εφέ, ταχύτητα, θέμα, πλήκτρα, πίσω
OPT_Y           = 40
OPT_DY          = 18
OPT_VX          = 23            ; στήλη της τιμής

;------------------------------------------------------------------
; Στην εκκίνηση (μετά το load_progress): έλεγχος των τιμών του LIQUID.SAV,
; τα πλήκτρα στο key_bindings, το θέμα.
apply_settings
        ldx #3                  ; opt_music..opt_theme: 0/1
-       lda opt_music,x
        cmp #2
        bcc +
        lda #0
        sta opt_music,x
+       dex
        bpl -
        lda theme_open          ; το θέμα μόνο αν έχει ξεκλειδώσει
        bne +
        sta opt_theme
+       ldx #0                  ; στήλη < KEY_COLS και ακριβώς ένα bit
-       lda opt_keys,x
        cmp #KEY_COLS
        bcs _bad
        lda opt_keys+1,x
        beq _bad
        sta tmp0
        sec
        sbc #1
        and tmp0
        bne _bad
        inx
        inx
        cpx #10
        bne -
        jmp _apply
_bad    ldx #9
-       lda default_keys,x
        sta opt_keys,x
        dex
        bpl -
_apply  jsr apply_keys
        jmp apply_theme

default_keys    .byte 4,%00000100, 5,%00000100, 4,%00000010, 4,%00100000, 7,%00010000

; opt_keys (αριστερά, δεξιά, πάνω, κάτω, fire) -> key_bindings (πάνω, κάτω,
; αριστερά, δεξιά, fire: 3 bytes η καθεμία).
apply_keys
        ldx #0
-       ldy key_order,x
        txa
        asl a
        sta tmp0
        stx tmp1
        tax
        lda opt_keys,x
        sta key_bindings,y
        lda opt_keys+1,x
        sta key_bindings+1,y
        ldx tmp1
        inx
        cpx #5
        bne -
        rts

key_order       .byte 6,9,0,3,12

; Το θέμα: CLASSIC (border μαύρο-μπλε-ματζέντα, γκρι γυαλί) ή NEON (όλα
; μαύρα, ροζ γυαλί). (Η διαβάθμιση: fly_events, sprites.asm.)
apply_theme
        lda #CLASSIC_GLASS
        ldx opt_theme
        beq +
        lda #NEON_GLASS
+       sta glass_col
        rts

;------------------------------------------------------------------
; Κείμενο: σελίδες από εγγραφές «.byte y, x, pen / .null "ΚΕΙΜΕΝΟ"», με $ff
; στο τέλος (x = CENTER: στο κέντρο). Κάθε νέα γραμμή (άλλο y) γράφεται στο
; άλλο slot (%11 / %10): γραμμές 12 γραμμές μακριά μοιράζονται σειρά cells,
; και έτσι η καθεμία κρατάει το χρώμα της.
CENTER          = $ff

print_page
        sta ptr1
        sty ptr1+1
_line   ldy #0
        lda (ptr1),y
        cmp #$ff
        bne +
        rts
+       cmp pp_y
        beq +
        sta pp_y
        lda pp_slot
        eor #1                  ; 3 <-> 2
        sta pp_slot
+       iny
        lda (ptr1),y
        sta tmp4                ; x
        iny
        lda (ptr1),y
        sta tmp5                ; pen
        lda ptr1                ; ptr0 = το κείμενο
        clc
        adc #3
        sta ptr0
        lda ptr1+1
        adc #0
        sta ptr0+1
        lda pp_slot
        sta txt_slot
        ldx tmp4
        cpx #CENTER
        bne +
        jsr str_len
        sta tmp6
        lda #40
        sec
        sbc tmp6
        lsr a
        tax
+       ldy #0
        lda (ptr1),y
        tay
        lda tmp5
        jsr print_slot
        ldy #0                  ; στο επόμενο
-       lda (ptr0),y
        beq +
        iny
        bne -
+       iny
        tya
        clc
        adc ptr0
        sta ptr1
        lda ptr0+1
        adc #0
        sta ptr1+1
        jmp _line

pp_y    .byte 0
pp_slot .byte 3

; Κείμενο ptr0 στο y = Y, x = X (CENTER: στο κέντρο), pen A, slot 3.
print_at
        pha
        cpx #CENTER
        bne +
        jsr str_len
        sta tmp6
        lda #40
        sec
        sbc tmp6
        lsr a
        tax
+       pla
        jmp print_str

; Ολόκληρη οθόνη κειμένου: σβήσιμο, mode X, σελίδα A/Y.
text_screen
        stx mode
        pha
        tya
        pha
        jsr cls
        jsr fly_hide
        jsr jet_hide
        jsr cursor_erase
        lda #$ff
        sta pp_y
        lda #3
        sta pp_slot
        pla
        tay
        pla
        jmp print_page

; num5_buf = X:A σε δεκαδικά, χωρίς μηδενικά μπροστά. out: ptr0 = κείμενο.
num5_str
        sta tmp0
        stx tmp1
        ldy #0
        ldx #0
_dig    lda #"0"
        sta num5_buf,y
-       lda tmp0
        sec
        sbc pow10_lo,x
        sta tmp2
        lda tmp1
        sbc pow10_hi,x
        bcc +
        sta tmp1
        lda tmp2
        sta tmp0
        lda num5_buf,y
        clc
        adc #1
        sta num5_buf,y
        jmp -
+       iny
        inx
        cpx #4
        bne _dig
        lda tmp0
        ora #"0"
        sta num5_buf,y
        lda #0
        sta num5_buf+5
        ldx #0                  ; χωρίς τα μηδενικά μπροστά (ένα μένει)
-       lda num5_buf,x
        cmp #"0"
        bne +
        inx
        cpx #4
        bne -
+       txa
        clc
        adc #<num5_buf
        sta ptr0
        lda #>num5_buf
        adc #0
        sta ptr0+1
        rts

pow10_lo .byte <10000,<1000,<100,<10
pow10_hi .byte >10000,>1000,>100,>10

;------------------------------------------------------------------
; Οθόνη επιλογών: πάνω/κάτω διαλέγει, SPACE/αριστερά/δεξιά αλλάζει, ESC πίσω.
options_start
        lda #<sfx_select
        ldy #>sfx_select
        jsr play_sfx
        lda #0
        sta opt_sel
        lda #$ff
        sta opt_redef
        lda #<page_options
        ldy #>page_options
        ldx #MODE_OPTIONS
        jsr text_screen
        lda #0
-       pha
        jsr opt_draw
        pla
        clc
        adc #1
        cmp #OPT_ITEMS
        bne -
        jmp opt_keys_draw

options_frame
        lda opt_redef           ; ορισμός πλήκτρων σε εξέλιξη
        cmp #$ff
        beq +
        jmp redef_frame
+       lda input_new
        and #IN_ESC
        beq +
        jmp opt_back
+       lda input_new
        and #IN_UP|IN_DOWN
        beq _chg
        tax
        lda opt_sel
        sta tmp_row
        cpx #IN_UP
        bne _dn
        sec
        sbc #1
        bcs _set
        lda #OPT_ITEMS-1
        bne _set
_dn     clc
        adc #1
        cmp #OPT_ITEMS
        bcc _set
        lda #0
_set    sta opt_sel
        lda #<sfx_tick
        ldy #>sfx_tick
        jsr play_sfx
        lda tmp_row             ; το παλιό χωρίς επισήμανση, το νέο με
        jsr opt_draw
        lda opt_sel
        jmp opt_draw
_chg    lda input_new
        and #IN_FIRE|IN_LEFT|IN_RIGHT
        bne +
        rts
+       lda opt_sel
        bne +
        jmp _music
+       cmp #1
        bne +
        ldx #1                  ; εφέ
        jsr _flip
        jmp _redraw
+       cmp #2
        bne +
        ldx #2                  ; ταχύτητα
        jsr _flip
        jmp _redraw
+       cmp #3
        bne +
        jmp _theme
+       cmp #4
        beq +
        jmp opt_back
+       lda #0                  ; ορισμός: 5 πλήκτρα με τη σειρά
        sta opt_redef
        lda #<sfx_select
        ldy #>sfx_select
        jsr play_sfx
        jmp redef_prompt
_music  ldx #0
        jsr _flip
        lda opt_music
        bne +
        jsr music_stop
        jmp _redraw
+       jsr music_start
        jmp _redraw
_theme  lda theme_open
        bne +
        lda #<sfx_error
        ldy #>sfx_error
        jmp play_sfx
+       ldx #3
        jsr _flip
        jsr apply_theme
        jmp _redraw
_flip   lda opt_music,x         ; X: 0 μουσική, 1 εφέ, 2 ταχύτητα, 3 θέμα
        eor #1
        sta opt_music,x
        lda #1
        sta save_dirty
        rts
_redraw lda #<sfx_select
        ldy #>sfx_select
        jsr play_sfx
        lda opt_sel
        jmp opt_draw

; Πίσω στον τίτλο, με αποθήκευση αν άλλαξε κάτι.
opt_back
        jsr save_if_dirty
        jmp title_start

; Η γραμμή A: όνομα (κίτρινο αν είναι η επιλεγμένη) και τιμή.
opt_draw
        sta tmp_x0
        asl a                   ; y = OPT_Y + A * 18
        sta tmp0
        asl a
        asl a
        asl a
        clc
        adc tmp0
        adc #OPT_Y
        sta tmp_y
        tay                     ; σβήσιμο όλης της γραμμής
        ldx #2
        lda #36
        jsr clear_text
        lda tmp_x0
        asl a
        tax
        lda opt_names,x
        sta ptr0
        lda opt_names+1,x
        sta ptr0+1
        lda #PEN_WHITE
        ldx tmp_x0
        cpx opt_sel
        bne +
        lda #PEN_LIQUID+2
+       ldx #4
        ldy tmp_y
        jsr print_str
        lda #PEN_LIQUID+5       ; τιμή
        sta tmp_pen
        lda tmp_x0
        bne _n1
        lda opt_music
        jmp _onoff
_n1     cmp #1
        bne _n2
        lda opt_sfx
_onoff  ldx #<str_on
        ldy #>str_on
        cmp #0
        bne _val
        ldx #<str_off
        ldy #>str_off
        lda #PEN_GLASS
        sta tmp_pen
        jmp _val
_n2     cmp #2
        bne _n3
        ldx #<str_normal
        ldy #>str_normal
        lda opt_speed
        beq _val
        ldx #<str_fast
        ldy #>str_fast
        jmp _val
_n3     cmp #3
        bne _n4
        ldx #<str_locked
        ldy #>str_locked
        lda #PEN_GLASS
        sta tmp_pen
        lda theme_open
        beq _val
        lda #PEN_LIQUID+5
        sta tmp_pen
        ldx #<str_classic
        ldy #>str_classic
        lda opt_theme
        beq _val
        ldx #<str_neon
        ldy #>str_neon
        jmp _val
_n4     cmp #4
        beq +
        rts                     ; (πίσω: χωρίς τιμή)
+       ldx #<str_redefine
        ldy #>str_redefine
_val    stx ptr0
        sty ptr0+1
        ldx #OPT_VX
        ldy tmp_y
        lda tmp_pen
        jmp print_str

opt_names       .word str_o_music,str_o_sfx,str_o_speed,str_o_theme,str_o_keys,str_o_back

; Τα 5 πλήκτρα κάτω από τις επιλογές: «L:J R:L ...».
KEYS_Y          = OPT_Y+OPT_ITEMS*OPT_DY+4
opt_keys_draw
        ldx #0
        ldy #KEYS_Y
        lda #40
        jsr clear_text
        lda #0
        sta kidx
_k      ldx kidx
        lda str_klet,x
        sta kbuf
        txa                     ; στήλη = 2 + 7k
        asl a
        asl a
        asl a
        sec
        sbc kidx
        clc
        adc #2
        tax
        lda #<kbuf
        ldy #>kbuf
        jsr set_text
        ldy #KEYS_Y
        lda #PEN_GLASS
        jsr print_str           ; «L:» (X += 2)
        stx tmp_x0
        lda kidx
        asl a
        tax
        lda opt_keys,x
        ldy opt_keys+1,x
        jsr key_name
        ldx tmp_x0
        ldy #KEYS_Y
        lda #PEN_WHITE
        jsr print_str
        inc kidx
        lda kidx
        cmp #5
        bne _k
        rts

str_klet        .text "LRUDF"
kbuf            .null "L:"
kidx            .byte 0

; ptr0 = όνομα του πλήκτρου (A = στήλη, Y = bit).
key_name
        sta tmp0
        tya
        ldx #$ff                ; αριθμός του bit
-       inx
        lsr a
        bne -
        lda tmp0                ; (στήλη * 8 + bit) * 5
        asl a
        asl a
        asl a
        stx tmp0
        ora tmp0
        sta tmp0
        lda #0
        sta tmp1
        lda tmp0
        asl a
        rol tmp1
        asl a
        rol tmp1
        clc
        adc tmp0
        sta ptr0
        lda tmp1
        adc #0
        sta ptr0+1
        clc
        lda ptr0
        adc #<key_names
        sta ptr0
        lda ptr0+1
        adc #>key_names
        sta ptr0+1
        rts

; Ορισμός πλήκτρων: opt_redef = ποιο από τα 5 περιμένει.
redef_prompt
        ldx #0
        ldy #KEYS_Y+14
        lda #40
        jsr clear_text
        lda #<str_press_key
        ldy #>str_press_key
        jsr set_text
        ldx #4
        ldy #KEYS_Y+14
        lda #PEN_LIQUID+2
        jsr print_str
        stx tmp_x0
        lda opt_redef
        asl a
        tay
        lda redef_names,y
        sta ptr0
        lda redef_names+1,y
        sta ptr0+1
        ldx tmp_x0              ; (συνεχίζει από τη στήλη του προηγούμενου)
        ldy #KEYS_Y+14
        lda #PEN_WHITE
        jmp print_str

redef_names     .word str_k_left,str_k_right,str_k_up,str_k_down,str_k_fire

redef_frame
        ldx #0                  ; πρώτο πλήκτρο που πατήθηκε τώρα (όχι STOP)
-       lda keymap,x
        eor #$ff
        and keyprev,x
        bne _got
        inx
        cpx #KEY_COLS
        bne -
        rts
_got    sta tmp0                ; το χαμηλότερο bit
        eor #$ff
        clc
        adc #1
        and tmp0
        sta tmp0
        cpx #KR_ESC
        bne +
        cmp #KB_ESC
        bne +
        rts
+       lda opt_redef
        asl a
        tay
        txa
        sta opt_keys,y
        lda tmp0
        sta opt_keys+1,y
        lda #<sfx_tick
        ldy #>sfx_tick
        jsr play_sfx
        lda #1
        sta save_dirty
        jsr opt_keys_draw
        inc opt_redef
        lda opt_redef
        cmp #5
        bcs +
        jmp redef_prompt
+       lda #$ff                ; τέλος
        sta opt_redef
        jsr apply_keys
        ldx #0
        ldy #KEYS_Y+14
        lda #40
        jmp clear_text

opt_sel         .byte 0
opt_redef       .byte $ff

page_options
        .byte 14,CENTER,PEN_LIQUID+2
        .null "OPTIONS"
        .byte 186,CENTER,PEN_GLASS
        .null "UP/DOWN CHOOSE  SPACE CHANGE  STOP BACK"
        .byte $ff

str_o_music     .null "MUSIC"
str_o_sfx       .null "SOUND FX"
str_o_speed     .null "SPEED"
str_o_theme     .null "THEME"
str_o_keys      .null "KEYS"
str_o_back      .null "BACK"
str_on          .null "ON"
str_off         .null "OFF"
str_normal      .null "NORMAL"
str_fast        .null "FAST"
str_locked      .null "LOCKED"
str_classic     .null "CLASSIC"
str_neon        .null "NEON"
str_redefine    .null "REDEFINE"
str_press_key   .null "PRESS A KEY FOR "
str_k_left      .null "LEFT"
str_k_right     .null "RIGHT"
str_k_up        .null "UP"
str_k_down      .null "DOWN"
str_k_fire      .null "FIRE"

; Ονόματα των 72 πλήκτρων (στήλη * 8 + bit), 5 bytes το καθένα.
key_names
        .text "DEL",0,0, "RET",0,0, "RGHT",0, "F7",0,0,0,  "F1",0,0,0,  "F3",0,0,0,  "F5",0,0,0,  "DOWN",0
        .text "3",0,0,0,0, "W",0,0,0,0, "A",0,0,0,0, "4",0,0,0,0, "Z",0,0,0,0, "S",0,0,0,0, "E",0,0,0,0, "SHFT",0
        .text "5",0,0,0,0, "R",0,0,0,0, "D",0,0,0,0, "6",0,0,0,0, "C",0,0,0,0, "F",0,0,0,0, "T",0,0,0,0, "X",0,0,0,0
        .text "7",0,0,0,0, "Y",0,0,0,0, "G",0,0,0,0, "8",0,0,0,0, "B",0,0,0,0, "H",0,0,0,0, "U",0,0,0,0, "V",0,0,0,0
        .text "9",0,0,0,0, "I",0,0,0,0, "J",0,0,0,0, "0",0,0,0,0, "M",0,0,0,0, "K",0,0,0,0, "O",0,0,0,0, "N",0,0,0,0
        .text "+",0,0,0,0, "P",0,0,0,0, "L",0,0,0,0, "-",0,0,0,0, ".",0,0,0,0, ":",0,0,0,0, "AT",0,0,0, ",",0,0,0,0
        .text "PND",0,0, "*",0,0,0,0, "SEMI",0, "HOME",0, "RSHF",0, "=",0,0,0,0, "UPAR",0, "/",0,0,0,0
        .text "1",0,0,0,0, "LARR",0, "CTRL",0, "2",0,0,0,0, "SPC",0,0, "CBM",0,0, "Q",0,0,0,0, "STOP",0
        .text "JUP",0,0, "JDN",0,0, "JLT",0,0, "JRT",0,0, "JFIR",0, "?",0,0,0,0, "?",0,0,0,0, "?",0,0,0,0
