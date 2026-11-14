; ending.asm — μετά την πίστα 100: «BRAVO!», τα αστέρια, το θέμα NEON που
; ξεκλείδωσε (win_stats), και πυροτεχνήματα: σπίθες (2 x 2) με βαρύτητα, XOR
; στο bitmap (σβήνονται ξαναγράφοντάς τες). Κάθε έκρηξη έχει το χρώμα της σε
; ένα από τα δύο slots (%01 / %10) όλων των cells της περιοχής των σπιθών.

SPARK_N         = 32
SP_SIZE         = 12            ; πίνακες των SPARK_N, ένας ανά πεδίο
sp_xl           = sparks
sp_xh           = sparks+SPARK_N
sp_yl           = sparks+2*SPARK_N
sp_yh           = sparks+3*SPARK_N
sp_vxl          = sparks+4*SPARK_N
sp_vxh          = sparks+5*SPARK_N
sp_vyl          = sparks+6*SPARK_N
sp_vyh          = sparks+7*SPARK_N
sp_life         = sparks+8*SPARK_N      ; 0 = σβησμένη
sp_val          = sparks+9*SPARK_N      ; με ποιο byte σχεδιάστηκε (0 = πουθενά)
sp_al           = sparks+10*SPARK_N     ; πού
sp_ah           = sparks+11*SPARK_N
SPARK_TOP       = 30
SPARK_BOT       = 112
SP_GRAV         = 10

ending_start
        lda #<page_end
        ldy #>page_end
        ldx #MODE_END
        jsr text_screen
        jsr music_start
        lda #<str_bravo
        ldy #>str_bravo
        jsr set_text
        ldx #14
        ldy #4
        jsr print_big
        lda #0                  ; «STARS N/300»
        sta tmp0
        sta tmp1
        ldx #0
-       lda stars,x
        clc
        adc tmp0
        sta tmp0
        bcc +
        inc tmp1
+       inx
        cpx #MAX_LEVELS
        bne -
        lda tmp0
        ldx tmp1
        jsr num5_str
        lda #3                  ; (η γραμμή 134 στο print_page: slot 3)
        sta txt_slot
        ldx #21
        ldy #134
        lda #PEN_LIQUID+2
        jsr print_slot
        stx tmp_x0
        lda #<str_of300
        ldy #>str_of300
        jsr set_text
        ldx tmp_x0
        ldy #134
        lda #PEN_GLASS
        jsr print_slot
        ldx #SP_SIZE*SPARK_N/2-1        ; καμία σπίθα
        lda #0
-       sta sparks,x
        sta sparks+SP_SIZE*SPARK_N/2,x
        dex
        bpl -
        lda #10
        sta burst_t
        lda #1
        sta burst_slot
        rts

ending_frame
        lda input_new
        and #IN_FIRE|IN_ESC
        beq +
        jmp title_start
+       dec burst_t
        bne +
        jsr burst
+       ldx #0
_s      lda sp_val,x            ; σβήσιμο από την προηγούμενη θέση
        beq _move
        jsr xor2
        lda #0
        sta sp_val,x
_move   lda sp_life,x
        beq _next
        dec sp_life,x
        beq _next
        clc                     ; vy += g, y += vy
        lda sp_vyl,x
        adc #SP_GRAV
        sta sp_vyl,x
        bcc +
        inc sp_vyh,x
+       clc
        lda sp_yl,x
        adc sp_vyl,x
        sta sp_yl,x
        lda sp_yh,x
        adc sp_vyh,x
        sta sp_yh,x
        cmp #SPARK_TOP
        bcc _kill
        cmp #SPARK_BOT
        bcs _kill
        and #$fe
        sta tmp1
        clc                     ; x += vx
        lda sp_xl,x
        adc sp_vxl,x
        sta sp_xl,x
        lda sp_xh,x
        adc sp_vxh,x
        sta sp_xh,x
        cmp #160
        bcs _kill
        sta tmp0
        stx tmp2                ; διεύθυνση και byte
        lsr a
        lsr a
        tax
        ldy tmp1
        jsr scr_addr
        ldx tmp2
        lda scr
        sta sp_al,x
        lda scr+1
        sta sp_ah,x
        lda tmp0                ; ζεύγος pixels: αριστερό ή δεξί μισό
        and #2
        tay
        lda half_mask,y
        ldy sp_slot,x
        and slot_fill,y
        sta sp_val,x
        jsr xor2
        jmp _next
_kill   lda #0
        sta sp_life,x
_next   inx
        cpx #SPARK_N
        bne _s
        rts

half_mask .byte $f0,0,$0f
sp_slot .fill SPARK_N

; XOR του sp_val στο (sp_al/ah) και στην από κάτω γραμμή (y ζυγό). Κρατάει X.
xor2
        lda sp_al,x
        sta ptr3
        lda sp_ah,x
        sta ptr3+1
        ldy #0
        lda (ptr3),y
        eor sp_val,x
        sta (ptr3),y
        iny
        lda (ptr3),y
        eor sp_val,x
        sta (ptr3),y
        rts

; Νέα έκρηξη: 16 σπίθες σε κύκλο (όσες είναι ελεύθερες), τυχαίο σημείο και
; χρώμα υγρού, στο άλλο slot από την προηγούμενη.
burst
        jsr rnd
        and #15
        clc
        adc #28
        sta burst_t
        jsr rnd
        and #127
        clc
        adc #16
        sta burst_x
        jsr rnd
        and #31
        clc
        adc #46
        sta burst_y
-       jsr rnd                 ; pen = PEN_LIQUID + (0..11)
        and #15
        cmp #12
        bcs -
        adc #PEN_LIQUID
        sta burst_pen
        lda burst_slot          ; 1 <-> 2
        eor #3
        sta burst_slot
        sta txt_slot
        lda burst_pen           ; το χρώμα σε όλες τις cells της περιοχής
        jsr pen_col
        sta tmp4
        lda #SPARK_TOP/8
        sta tmp5
_row    ldx #39
-       lda tmp5
        jsr cell_addr
        lda tmp4
        jsr set_slot
        dex
        bpl -
        inc tmp5
        lda tmp5
        cmp #SPARK_BOT/8+1
        bne _row
        lda #<sfx_cork
        ldy #>sfx_cork
        jsr play_sfx
        ldx #0
        ldy #0                  ; κατευθύνσεις (x 4 bytes)
_s      lda sp_life,x
        bne _next
        lda #0
        sta sp_xl,x
        sta sp_yl,x
        lda burst_x
        sta sp_xh,x
        lda burst_y
        sta sp_yh,x
        lda spark_dirs,y
        sta sp_vxl,x
        lda spark_dirs+1,y
        sta sp_vxh,x
        lda spark_dirs+2,y
        sta sp_vyl,x
        lda spark_dirs+3,y
        sta sp_vyh,x
        lda burst_slot
        sta sp_slot,x
        jsr rnd
        and #15
        clc
        adc #34
        sta sp_life,x
        iny
        iny
        iny
        iny
        cpy #64
        beq _r
_next   inx
        cpx #SPARK_N
        bne _s
_r      rts

; vx (μισή, γιατί το pixel είναι διπλό σε πλάτος), vy - 128
spark_dirs
        .sint 160,-128,  148,-6,    113,98,   61,168
        .sint 0,192,     -61,168,  -113,98,  -148,-6
        .sint -160,-128, -148,-250, -113,-354, -61,-424
        .sint 0,-448,    61,-424,   113,-354, 148,-250

burst_t         .byte 0
burst_x         .byte 0
burst_y         .byte 0
burst_pen       .byte 0
burst_slot      .byte 1

str_bravo       .null "BRAVO!"

page_end
        .byte 120,CENTER,PEN_WHITE
        .null "ALL 100 LEVELS SOLVED!"
        .byte 134,11,PEN_WHITE
        .null "STARS"
        .byte 150,CENTER,PEN_LIQUID+5
        .null "NEW THEME UNLOCKED: NEON"
        .byte 162,CENTER,PEN_WHITE
        .null "TRY IT IN THE OPTIONS."
        .byte 176,CENTER,PEN_LIQUID+2
        .null "THANK YOU FOR PLAYING!"
        .byte 190,CENTER,PEN_GLASS
        .null "SPACE TITLE"
        .byte $ff
