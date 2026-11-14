; stats.asm — στατιστικά και μετάλλια (S στον τίτλο), ό,τι γίνεται σε κάθε
; νίκη (win_stats, medal_toast), και η «Χαλάρωση» με seed (D στον τίτλο).

MEDAL_COUNT     = 12
MD_NO_UNDO      = 8             ; μετάλλια-γεγονότα (τα άλλα από την πρόοδο)
MD_CLOSE        = 9
MD_SEED         = 11
TOAST_FRAMES    = 100           ; κάθε γραμμή στο HUD της νίκης

;------------------------------------------------------------------
; Σε κάθε νίκη, πριν από τη γραμμή της νίκης: αστέρια (win_stars), μετρητής
; της «Χαλάρωσης», μετάλλια-γεγονότα, θέμα μετά την πίστα 100, νέα μετάλλια
; (medal_new) για το medal_toast.
win_stats
        lda medals
        sta medal_old
        lda medals+1
        sta medal_old+1
        lda relax
        beq _lv
        inc stat_relax          ; «Χαλάρωση»: ως 65535
        bne +
        inc stat_relax+1
        bne +
        dec stat_relax
        dec stat_relax+1
+       lda #1                  ; (αποθήκευση όταν φύγεις από τη «Χαλάρωση»)
        sta relax_dirty
        lda relax_seed
        beq _medals
        lda medals+1
        ora #1<<(MD_SEED-8)
        sta medals+1
        jmp _medals
_lv     jsr award_stars
        sta win_stars
        lda undo_used           ; από την πίστα 30 χωρίς undo
        bne _time
        lda level
        cmp #29
        bcc _time
        lda medals+1
        ora #1<<(MD_NO_UNDO-8)
        sta medals+1
_time   lda level_timer         ; με το πολύ 10 δευτερόλεπτα
        beq _last
        lda time_left+1
        bne _last
        lda time_left
        cmp #11
        bcs _last
        lda medals+1
        ora #1<<(MD_CLOSE-8)
        sta medals+1
_last   lda level               ; η πίστα 100: ξεκλειδώνει το θέμα NEON
        cmp #LEVEL_COUNT-1
        bne _medals
        lda #1
        sta theme_open
        sta save_dirty
_medals jsr medals_update
        lda medal_old           ; νέα = medals & ~παλιά
        eor #$ff
        and medals
        sta medal_new
        lda medal_old+1
        eor #$ff
        and medals+1
        sta medal_new+1
        ora medal_new
        beq _t
        lda #1
        ldx relax
        beq +
        sta relax_dirty
        jmp _t
+       sta save_dirty
_t      lda #60
        sta toast_t
        lda #MEDAL_COUNT
        sta toast_i
        rts

; Τα μετάλλια της προόδου (πίστες, αστέρια, «Χαλάρωση», μεταγγίσεις), στο
; medals. Τα άλλα (γεγονότα) μένουν όπως είναι.
medals_update
        ldx #0                  ; tmp0 = λυμένες, tmp1 = με 3 αστέρια
        stx tmp0
        stx tmp1
-       lda stars,x
        beq +
        inc tmp0
        cmp #3
        bne +
        inc tmp1
+       inx
        cpx #MAX_LEVELS
        bne -
        lda medals
        ldx tmp0
        cpx #1
        bcc _m
        ora #1
        cpx #10
        bcc _m
        ora #2
        cpx #50
        bcc _m
        ora #4
        cpx #100
        bcc _m
        ora #8
_m      ldx tmp1
        cpx #10
        bcc _r
        ora #16
        cpx #100
        bcc _r
        ora #32
_r      ldx stat_relax+1
        bne _r10
        ldx stat_relax
        cpx #10
        bcc _p
_r10    ora #64
        ldx stat_relax+1
        bne _r100
        ldx stat_relax
        cpx #100
        bcc _p
_r100   ora #128
_p      sta medals
        lda stat_pours+1        ; 1000 = $03e8
        cmp #>1000
        bcc _done
        bne +
        lda stat_pours
        cmp #<1000
        bcc _done
+       lda medals+1
        ora #1<<(10-8)
        sta medals+1
_done   rts

; Στο ST_WIN, ανά καρέ: η γραμμή της νίκης και τα νέα μετάλλια εναλλάξ
; (toast_i = MEDAL_COUNT: η γραμμή της νίκης).
medal_toast
        lda medal_new
        ora medal_new+1
        bne +
        rts
+       dec toast_t
        beq +
        rts
+       lda #TOAST_FRAMES
        sta toast_t
        lda toast_i
_next   clc
        adc #1
        cmp #MEDAL_COUNT+1
        bcc +
        lda #0
+       cmp #MEDAL_COUNT
        beq _line
        jsr medal_bit           ; Z = όχι νέο
        beq _next
        sta toast_i
        ldx #6                  ; «MEDAL: ΟΝΟΜΑ»
-       lda str_medal,x
        sta toast_buf,x
        dex
        bpl -
        lda toast_i
        jsr medal_name
        ldy #0
-       lda (ptr0),y
        sta toast_buf+7,y
        iny
        cmp #0
        bne -
        lda #<sfx_chime
        ldy #>sfx_chime
        jsr play_sfx
        lda #<toast_buf
        ldy #>toast_buf
        ldx #PEN_LIQUID+2
        jmp hud_message
_line   sta toast_i
        jmp win_line

; NZ = το μετάλλιο A έχει κερδηθεί (X = το bit). Κρατάει το A.
medal_has
        pha
        lda medals
        sta tmp6
        lda medals+1
        sta tmp7
        jmp bit_test
; NZ = το bit A του medal_new. Κρατάει το A.
medal_bit
        pha
        lda medal_new
        sta tmp6
        lda medal_new+1
        sta tmp7
bit_test
        pla
        pha
        tax
        cpx #8
        bcc +
        lda tmp7
        sta tmp6
        txa
        sbc #8
        tax
+       lda spr_bit,x
        and tmp6
        tax
        pla
        cpx #0
        rts

; ptr0 = όνομα του μεταλλίου A. Κρατάει X, Y.
medal_name
        pha
        asl a
        tay
        lda medal_names,y
        sta ptr0
        lda medal_names+1,y
        sta ptr0+1
        pla
        rts

medal_old       .word 0
medal_new       .word 0
toast_t         .byte 0
toast_i         .byte 0
win_stars       .byte 0
str_medal       .text "MEDAL: "

medal_names
        .word md0,md1,md2,md3,md4,md5,md6,md7,md8,md9,md10,md11
medal_descs
        .word mdd0,mdd1,mdd2,mdd3,mdd4,mdd5,mdd6,mdd7,mdd8,mdd9,mdd10,mdd11
md0     .null "FIRST DROP"
md1     .null "TEN DOWN"
md2     .null "HALFWAY"
md3     .null "CENTURY"
md4     .null "PERFECT TEN"
md5     .null "PERFECTIONIST"
md6     .null "UNWINDING"
md7     .null "ZEN MASTER"
md8     .null "NO REGRETS"
md9     .null "CLOSE CALL"
md10    .null "BUSY HANDS"
md11    .null "GARDENER"
mdd0    .null "SOLVE YOUR FIRST LEVEL"
mdd1    .null "SOLVE 10 LEVELS"
mdd2    .null "SOLVE 50 LEVELS"
mdd3    .null "SOLVE ALL 100 LEVELS"
mdd4    .null "3 STARS ON 10 LEVELS"
mdd5    .null "3 STARS ON ALL 100 LEVELS"
mdd6    .null "SOLVE 10 RELAX PUZZLES"
mdd7    .null "SOLVE 100 RELAX PUZZLES"
mdd8    .null "LEVEL 30+ WITHOUT ANY UNDO"
mdd9    .null "BEAT THE CLOCK WITH 10 S LEFT"
mdd10   .null "POUR 1000 TIMES"
mdd11   .null "SOLVE A SEEDED PUZZLE"

;------------------------------------------------------------------
; Στατιστικά: αριθμοί, και τα 12 μετάλλια σε δύο στήλες· με τα βελάκια
; διαλέγεις ένα και βλέπεις τι χρειάζεται.
ST_X            = 29            ; στήλη των αριθμών
MD_Y            = 100
MD_DY           = 12

stats_start
        lda #<sfx_select
        ldy #>sfx_select
        jsr play_sfx
        jsr medals_update       ; (π.χ. από παλιά πρόοδο)
        lda #0
        sta md_sel
        lda #<page_stats
        ldy #>page_stats
        ldx #MODE_STATS
        jsr text_screen
        lda #0                  ; λυμένες, αστέρια, με 3
        sta st_solved
        sta st_stars
        sta st_stars+1
        sta st_perfect
        ldx #0
-       lda stars,x
        beq _n
        inc st_solved
        cmp #3
        bne +
        inc st_perfect
+       clc
        adc st_stars
        sta st_stars
        bcc _n
        inc st_stars+1
_n      inx
        cpx #MAX_LEVELS
        bne -
        lda st_solved           ; «N/100»
        ldx #0
        ldy #22
        jsr _s3
        jsr _num
        lda #<str_of100
        ldy #>str_of100
        jsr _of
        lda st_stars            ; «N/300»
        ldx st_stars+1
        ldy #34
        jsr _s2
        jsr _num
        lda #<str_of300
        ldy #>str_of300
        jsr _of
        lda st_perfect
        ldx #0
        ldy #46
        jsr _s3
        jsr _num
        lda stat_pours
        ldx stat_pours+1
        ldy #58
        jsr _s2
        jsr _num
        lda stat_relax
        ldx stat_relax+1
        ldy #70
        jsr _s3
        jsr _num
        lda #0                  ; μετάλλια «N/12»
        sta tmp_x0
        lda #MEDAL_COUNT-1
-       jsr medal_has
        beq +
        inc tmp_x0
+       sec
        sbc #1
        bpl -
        lda tmp_x0
        ldx #0
        ldy #84
        jsr _s2
        jsr _num
        lda #<str_of12
        ldy #>str_of12
        jsr _of
        lda #0
-       pha
        jsr md_draw
        pla
        clc
        adc #1
        cmp #MEDAL_COUNT
        bne -
        jmp md_desc
; Το slot της γραμμής (όπως το print_page: εναλλάξ ανά y). Κρατάει A, X, Y.
_s3     pha
        lda #3
        sta st_s
        pla
        rts
_s2     pha
        lda #2
        sta st_s
        pla
        rts
; X:A = αριθμός, Y = y: στη στήλη ST_X, κίτρινο, στο slot st_s.
_num    sty tmp_y
        jsr num5_str
        lda st_s
        sta txt_slot
        ldx #ST_X
        ldy tmp_y
        lda #PEN_LIQUID+2
        jmp print_slot
; «/100» κ.λπ. μετά τον αριθμό (X = στήλη μετά από αυτόν).
_of     stx tmp_x0
        jsr set_text
        lda st_s
        sta txt_slot
        ldx tmp_x0
        ldy tmp_y
        lda #PEN_GLASS
        jmp print_slot

st_s    .byte 3

stats_frame
        lda input_new
        and #IN_ESC|IN_FIRE
        beq +
        jmp title_start
+       lda input_new
        and #IN_UP|IN_DOWN|IN_LEFT|IN_RIGHT
        bne +
        rts
+       tax
        lda md_sel
        sta tmp_row
        cpx #IN_UP              ; πάνω/κάτω: ±1, αριστερά/δεξιά: ±6
        bne +
        sec
        sbc #1
+       cpx #IN_DOWN
        bne +
        clc
        adc #1
+       cpx #IN_LEFT
        bne +
        sec
        sbc #6
+       cpx #IN_RIGHT
        bne +
        clc
        adc #6
+       cmp #MEDAL_COUNT        ; κυκλικά (τα αρνητικά: > 127)
        bcc _ok
        cmp #128
        bcs _neg
        sec                     ; (εδώ C = 0: χωρίς sec, 12 -> 255)
        sbc #MEDAL_COUNT
        jmp _ok
_neg    clc
        adc #MEDAL_COUNT
_ok     sta md_sel
        lda #<sfx_tick
        ldy #>sfx_tick
        jsr play_sfx
        lda tmp_row
        jsr md_draw
        lda md_sel
        jsr md_draw
        jmp md_desc

; Μετάλλιο A στη λίστα: κίτρινο αν κερδήθηκε, γκρι αλλιώς, με «*» αν είναι
; το επιλεγμένο. Οι γραμμές 12 γραμμές μακριά: εναλλάξ slots %11 / %10.
md_draw
        sta md_i
        ldx #2                  ; στήλη: 0-5 αριστερά, 6-11 δεξιά
        cmp #6
        bcc +
        sbc #6
        ldx #22
+       stx md_x
        sta tmp0                ; y = MD_Y + γραμμή * 12
        and #1
        eor #1
        ora #2
        sta md_slot             ; ζυγές 3, μονές 2
        lda tmp0
        asl a
        adc tmp0
        asl a
        asl a
        adc #MD_Y
        sta md_y
        tay
        ldx md_x
        lda #18
        jsr clear_text
        lda md_slot
        sta txt_slot
        lda md_sel
        cmp md_i
        bne +
        lda #<str_star
        ldy #>str_star
        jsr set_text
        ldx md_x
        ldy md_y
        lda #PEN_WHITE
        jsr print_slot
+       lda md_i
        jsr medal_has
        lda #PEN_GLASS
        cpx #0
        beq +
        lda #PEN_LIQUID+2
+       sta md_pen
        lda md_i
        jsr medal_name
        lda md_slot
        sta txt_slot
        ldx md_x
        inx
        ldy md_y
        lda md_pen
        jmp print_slot

md_i            .byte 0
md_pen          .byte 0
md_x            .byte 0
md_y            .byte 0
md_slot         .byte 0

md_desc
        ldx #0
        ldy #MD_Y+6*MD_DY+4
        lda #40
        jsr clear_text
        lda md_sel
        asl a
        tax
        lda medal_descs,x
        sta ptr0
        lda medal_descs+1,x
        sta ptr0+1
        ldx #CENTER
        ldy #MD_Y+6*MD_DY+4
        lda #PEN_LIQUID+5
        jmp print_at

md_sel          .byte 0
st_solved       .byte 0
st_stars        .word 0
st_perfect      .byte 0
str_star        .null "*"
str_of100       .null "/100"
str_of300       .null "/300"
str_of12        .null "/12"

page_stats
        .byte 8,CENTER,PEN_LIQUID+2
        .null "STATISTICS"
        .byte 22,2,PEN_WHITE
        .null "LEVELS SOLVED"
        .byte 34,2,PEN_WHITE
        .null "STARS"
        .byte 46,2,PEN_WHITE
        .null "PERFECT LEVELS"
        .byte 58,2,PEN_WHITE
        .null "POURS"
        .byte 70,2,PEN_WHITE
        .null "RELAX PUZZLES"
        .byte 84,2,PEN_WHITE
        .null "MEDALS"
        .byte 190,CENTER,PEN_GLASS
        .null "ARROWS MEDALS   SPACE BACK"
        .byte $ff

;------------------------------------------------------------------
; Από τη «Χαλάρωση» στον τίτλο: αποθήκευση των μετρητών, μία φορά (όχι σε
; κάθε νίκη, που θα σταματούσε το παιχνίδι).
relax_leave
        lda relax_dirty
        beq +
        lda #0
        sta relax_dirty
        lda #1
        sta save_dirty
        jsr save_if_dirty
+       jmp title_start

relax_dirty     .byte 0

; HUD της «Χαλάρωσης»: RELAX, ή το seed.
relax_label
        lda relax_seed
        bne +
        lda #<str_relax
        ldy #>str_relax
        jsr set_text
        jmp ++
+       jsr seed_str
+       ldx #0
        ldy #HUD_Y
        lda #PEN_LIQUID+2
        jmp print_str

; Στο «SOLVED!» με seed: «SEED-N» (ποια πίστα του seed).
seed_tag
        lda relax_seed
        bne +
        rts
+       jsr seed_str
        ldx #9
        ldy #HUD_Y
        lda #PEN_LIQUID+5
        jsr print_str
        stx tmp_x0
        lda #<str_dash
        ldy #>str_dash
        jsr set_text
        ldx tmp_x0
        ldy #HUD_Y
        lda #PEN_LIQUID+5
        jsr print_str
        stx tmp_x0
        lda relax_num
        ldx #0
        jsr num5_str            ; χωρίς μηδενικά μπροστά
        ldx tmp_x0
        ldy #HUD_Y
        lda #PEN_LIQUID+5
        jmp print_str

; ptr0 = το seed (last_seed) σε 4 ψηφία (με μηδενικά).
seed_str
        lda last_seed
        ldx last_seed+1
        jsr num5_str
        lda #<(num5_buf+1)
        sta ptr0
        lda #>(num5_buf+1)
        sta ptr0+1
        rts

str_dash        .null "-"

;------------------------------------------------------------------
; Οθόνη seed: 4 ψηφία (last_seed), DEL σβήνει, SPACE/RETURN ξεκινάει.
SEED_Y          = 84
SEED_X          = 16

seed_start
        lda #<sfx_select
        ldy #>sfx_select
        jsr play_sfx
        lda #<page_seed
        ldy #>page_seed
        ldx #MODE_SEED
        jsr text_screen
seed_draw
        ldx #SEED_X
        ldy #SEED_Y
        lda #8
        sta tmp0
        lda #20
        sta tmp1
        jsr clear_rect
        jsr seed_str
        ldx #SEED_X
        ldy #SEED_Y
        jmp print_big

seed_frame
        lda input_new
        and #IN_ESC
        beq +
        jmp title_start
+       lda input_new
        and #IN_FIRE
        bne _go
        lda #KR_RET
        ldx #KB_RET
        jsr key_new
        bne _go
        lda #KR_DEL
        ldx #KB_DEL
        jsr key_new
        bne _del
        lda #0                  ; ψηφία: στήλη, bit
        sta tmp_x0
-       lda tmp_x0
        asl a
        tay
        lda digit_keys+1,y
        tax
        lda digit_keys,y
        jsr key_new
        bne _got
        inc tmp_x0
        lda tmp_x0
        cmp #10
        bne -
        rts
_got    jsr seed_mod1000        ; seed = (seed mod 1000) * 10 + ψηφίο
        lda tmp0                ; x 10
        asl a
        sta tmp2
        lda tmp1
        rol a
        sta tmp3
        asl tmp0
        rol tmp1
        asl tmp0
        rol tmp1
        asl tmp0
        rol tmp1
        lda tmp0
        clc
        adc tmp2
        sta tmp0
        lda tmp1
        adc tmp3
        sta tmp1
        lda tmp0
        clc
        adc tmp_x0
        sta last_seed
        lda tmp1
        adc #0
        sta last_seed+1
        jmp _set
_del    lda last_seed           ; seed / 10
        sta tmp0
        lda last_seed+1
        sta tmp1
        ldx #0
        stx last_seed
        stx last_seed+1
-       lda tmp0
        sec
        sbc #10
        tay
        lda tmp1
        sbc #0
        bcc _set
        sta tmp1
        sty tmp0
        inc last_seed
        bne -
        inc last_seed+1
        jmp -
_set    lda #<sfx_tick
        ldy #>sfx_tick
        jsr play_sfx
        jmp seed_draw
_go     lda #1
        sta relax_seed
        sta relax_dirty
        jmp relax_go

; tmp1:tmp0 = last_seed mod 1000.
seed_mod1000
        lda last_seed
        sta tmp0
        lda last_seed+1
        sta tmp1
-       lda tmp0
        sec
        sbc #<1000
        tay
        lda tmp1
        sbc #>1000
        bcc +
        sta tmp1
        sty tmp0
        jmp -
+       rts

digit_keys
        .byte 4,%00001000, 7,%00000001, 7,%00001000, 1,%00000001, 1,%00001000
        .byte 2,%00000001, 2,%00001000, 3,%00000001, 3,%00001000, 4,%00000001

page_seed
        .byte 14,CENTER,PEN_LIQUID+2
        .null "RELAX WITH A SEED"
        .byte 36,CENTER,PEN_WHITE
        .null "THE SAME SEED GIVES THE SAME"
        .byte 48,CENTER,PEN_WHITE
        .null "PUZZLES ON EVERY C64 AND CPC."
        .byte 60,CENTER,PEN_WHITE
        .null "SHARE IT WITH YOUR FRIENDS!"
        .byte 120,CENTER,PEN_LIQUID+5
        .null "TYPE 4 DIGITS   DEL ERASES"
        .byte 140,CENTER,PEN_WHITE
        .null "SPACE OR RETURN: PLAY"
        .byte 186,CENTER,PEN_GLASS
        .null "STOP BACK"
        .byte $ff
