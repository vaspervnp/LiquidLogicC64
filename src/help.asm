; help.asm — οδηγίες (4 σελίδες, H στον τίτλο) και κάρτες: την πρώτη φορά
; που μια πίστα έχει έναν ειδικό τύπο, πριν από την πίστα, μια σελίδα που
; τον εξηγεί με ένα μπουκάλι-παράδειγμα (seen_cards στο LIQUID.SAV).

HELP_PAGES      = 4

help_start
        lda #<sfx_select
        ldy #>sfx_select
        jsr play_sfx
        lda #0
        sta help_page
help_show
        lda help_page
        asl a
        tax
        lda help_table,x
        ldy help_table+1,x
        ldx #MODE_HELP
        jsr text_screen
        lda #<page_help_foot
        ldy #>page_help_foot
        jsr print_page
        lda help_page           ; «1/4»
        clc
        adc #"1"
        sta str_pageno
        lda #<str_pageno
        ldy #>str_pageno
        jsr set_text
        ldx #36
        ldy #186
        lda #PEN_GLASS
        jmp print_str

help_frame
        lda input_new
        and #IN_ESC
        beq +
        jmp title_start
+       lda input_new
        and #IN_FIRE|IN_RIGHT|IN_DOWN
        beq _back
        lda help_page
        clc
        adc #1
        cmp #HELP_PAGES
        bcc _go
        jmp title_start
_back   lda input_new
        and #IN_LEFT|IN_UP
        bne +
        rts
+       lda help_page
        bne +
        rts
+       sec
        sbc #1
_go     sta help_page
        lda #<sfx_tick
        ldy #>sfx_tick
        jsr play_sfx
        jmp help_show

help_page       .byte 0
str_pageno      .null "1/4"
help_table      .word page_help1,page_help2,page_help3,page_help4

page_help_foot
        .byte 186,2,PEN_GLASS
        .null "SPACE NEXT   STOP BACK"
        .byte $ff

page_help1
        .byte 10,CENTER,PEN_LIQUID+2
        .null "HOW TO PLAY"
        .byte 30,2,PEN_WHITE
        .null "SORT THE LIQUIDS SO THAT EVERY"
        .byte 42,2,PEN_WHITE
        .null "BOTTLE HOLDS A SINGLE COLOUR."
        .byte 64,2,PEN_LIQUID+5
        .null "CURSOR KEYS / IJKL / JOYSTICK"
        .byte 76,4,PEN_WHITE
        .null "MOVE BETWEEN THE BOTTLES"
        .byte 92,2,PEN_LIQUID+5
        .null "SPACE / FIRE"
        .byte 104,4,PEN_WHITE
        .null "PICK THE BOTTLE TO POUR FROM"
        .byte 120,2,PEN_LIQUID+5
        .null "SPACE AGAIN"
        .byte 132,4,PEN_WHITE
        .null "PICK THE BOTTLE TO FILL"
        .byte 150,2,PEN_WHITE
        .null "POUR ONTO THE SAME COLOUR OR INTO"
        .byte 162,2,PEN_WHITE
        .null "AN EMPTY BOTTLE. THE MATCHING TOP"
        .byte 174,2,PEN_WHITE
        .null "LAYERS FLOW WHILE THERE IS ROOM."
        .byte $ff

page_help2
        .byte 10,CENTER,PEN_LIQUID+2
        .null "KEYS AND STARS"
        .byte 32,2,PEN_LIQUID+5
        .null "U"
        .byte 32,8,PEN_WHITE
        .null "UNDO - 5 PER LEVEL"
        .byte 46,2,PEN_LIQUID+5
        .null "R"
        .byte 46,8,PEN_WHITE
        .null "RESTART THE LEVEL"
        .byte 60,2,PEN_LIQUID+5
        .null "E"
        .byte 60,8,PEN_WHITE
        .null "EXTRA BOTTLE - WHEN E+"
        .byte 74,2,PEN_LIQUID+5
        .null "STOP"
        .byte 74,8,PEN_WHITE
        .null "CANCEL OR PAUSE"
        .byte 88,2,PEN_LIQUID+5
        .null "M"
        .byte 88,8,PEN_WHITE
        .null "MENU - PAUSED OR SOLVED"
        .byte 112,2,PEN_WHITE
        .null "SOLVE A LEVEL IN THE FEWEST MOVES"
        .byte 124,2,PEN_WHITE
        .null "- PAR - FOR 3 STARS. EACH SOLVED"
        .byte 136,2,PEN_WHITE
        .null "LEVEL UNLOCKS THE NEXT ONE."
        .byte 156,2,PEN_WHITE
        .null "KEYS, MUSIC AND SPEED: O ON THE"
        .byte 168,2,PEN_WHITE
        .null "TITLE SCREEN."
        .byte $ff

page_help3
        .byte 10,CENTER,PEN_LIQUID+2
        .null "SPECIAL BOTTLES"
        .byte 30,2,PEN_LIQUID+5
        .null "?"
        .byte 30,11,PEN_WHITE
        .null "HIDDEN LAYER"
        .byte 44,2,PEN_LIQUID+5
        .null "ICE"
        .byte 44,11,PEN_WHITE
        .null "FROZEN FOR SOME MOVES"
        .byte 58,2,PEN_LIQUID+5
        .null "LOCK"
        .byte 58,11,PEN_WHITE
        .null "OPENS WITH ITS COLOUR"
        .byte 72,2,PEN_LIQUID+5
        .null "BULB"
        .byte 72,11,PEN_WHITE
        .null "DROPPER: ONE LAYER"
        .byte 86,2,PEN_LIQUID+5
        .null "STRIPES"
        .byte 86,11,PEN_WHITE
        .null "CURTAIN: HIDDEN BOTTLE"
        .byte 100,2,PEN_LIQUID+5
        .null "TICKS"
        .byte 100,11,PEN_WHITE
        .null "A BOTTLE OF ANOTHER SIZE"
        .byte 114,2,PEN_LIQUID+5
        .null "LEFT"
        .byte 114,11,PEN_WHITE
        .null "MOVE LIMIT"
        .byte 128,2,PEN_LIQUID+5
        .null "TIME"
        .byte 128,11,PEN_WHITE
        .null "AGAINST THE CLOCK"
        .byte 142,2,PEN_LIQUID+5
        .null "E+"
        .byte 142,11,PEN_WHITE
        .null "EXTRA BOTTLE WITH E"
        .byte 160,2,PEN_WHITE
        .null "EACH ONE IS EXPLAINED THE FIRST"
        .byte 172,2,PEN_WHITE
        .null "TIME YOU MEET IT."
        .byte $ff

page_help4
        .byte 10,CENTER,PEN_LIQUID+2
        .null "RELAX AND SEEDS"
        .byte 30,2,PEN_LIQUID+5
        .null "R ON THE TITLE"
        .byte 42,2,PEN_WHITE
        .null "ENDLESS RANDOM PUZZLES WITHOUT"
        .byte 54,2,PEN_WHITE
        .null "STARS OR LIMITS. SPACE GIVES A"
        .byte 66,2,PEN_WHITE
        .null "NEW ONE WHEN SOLVED."
        .byte 86,2,PEN_LIQUID+5
        .null "D ON THE TITLE"
        .byte 98,2,PEN_WHITE
        .null "TYPE A SEED OF 4 DIGITS. THE SAME"
        .byte 110,2,PEN_WHITE
        .null "SEED GIVES THE SAME PUZZLES ON"
        .byte 122,2,PEN_WHITE
        .null "EVERY C64 AND CPC - PLAY THE SAME"
        .byte 134,2,PEN_WHITE
        .null "ONES AS YOUR FRIENDS!"
        .byte 154,2,PEN_LIQUID+5
        .null "S ON THE TITLE"
        .byte 166,2,PEN_WHITE
        .null "STATISTICS AND MEDALS"
        .byte $ff

;------------------------------------------------------------------
; Κάρτες. Τα bits CD_* (seen_cards, 16 bits).
CD_HIDDEN       = 0
CD_ICE          = 1
CD_LOCK         = 2
CD_MOVES        = 3
CD_TALL         = 4
CD_DROP         = 5
CD_CURTAIN      = 6
CD_TIMER        = 7
CD_EXTRA        = 8
CARD_BOT_X      = 18
CARD_BOT_Y      = 90

; Από το level_start, μετά το level_setup. out: Z = καμία κάρτα (η πίστα
; σχεδιάζεται), NZ = κάρτα στην οθόνη (MODE_CARD· μετά το level_show).
card_check
        lda relax
        beq +
        lda #0
        rts
+       jsr level_types         ; tmp0:tmp1 = τύποι της πίστας
        lda seen_cards          ; νέοι = τύποι & ~seen
        eor #$ff
        and tmp0
        sta card_todo
        lda seen_cards+1
        eor #$ff
        and tmp1
        sta card_todo+1
        ora card_todo
        bne +
        rts
+       lda seen_cards          ; seen |= νέοι
        ora card_todo
        sta seen_cards
        lda seen_cards+1
        ora card_todo+1
        sta seen_cards+1
        lda #1
        sta save_dirty
        lda timer_on            ; ο χρόνος σταματάει όσο φαίνεται η κάρτα
        sta paused_timer
        lda #0
        sta timer_on
        jsr card_next
        lda #1
        rts

; tmp0:tmp1 = CD_* της τρέχουσας πίστας (level_flags, μπουκάλια).
level_types
        lda #0
        sta tmp0
        sta tmp1
        lda level_flags
        lsr a                   ; LF_HIDDEN
        bcc +
        pha
        lda #1<<CD_HIDDEN
        jsr _set
        pla
+       lsr a                   ; LF_MOVES
        bcc +
        pha
        lda #1<<CD_MOVES
        jsr _set
        pla
+       lsr a                   ; LF_TIMER
        bcc +
        pha
        lda #1<<CD_TIMER
        jsr _set
        pla
+       lsr a                   ; LF_EXTRA
        bcc +
        lda tmp1
        ora #1<<(CD_EXTRA-8)
        sta tmp1
+       lda level_cap
        cmp #4
        beq +
        lda #1<<CD_TALL
        jsr _set
+       ldx #0
_bot    lda bot_lo,x
        sta bptr
        lda bot_hi,x
        sta bptr+1
        ldy #B_FREEZE
        lda (bptr),y
        beq +
        lda #1<<CD_ICE
        jsr _set
+       ldy #B_LOCK
        lda (bptr),y
        beq +
        lda #1<<CD_LOCK
        jsr _set
+       ldy #B_FLAGS
        lda (bptr),y
        and #BF_DROPPER
        beq +
        lda #1<<CD_DROP
        jsr _set
+       lda (bptr),y
        and #BF_CURTAIN
        beq +
        lda #1<<CD_CURTAIN
        jsr _set
+       ldy #B_CAP
        lda (bptr),y
        cmp level_cap
        beq +
        lda #1<<CD_TALL
        jsr _set
+       inx
        cpx nbottles
        bne _bot
        rts
_set    ora tmp0
        sta tmp0
        rts

; Η κάρτα του χαμηλότερου bit του card_todo (και το σβήνει από εκεί).
card_next
        ldx #0
        lda card_todo
        bne _find
        ldx #8
        lda card_todo+1
_find   lsr a
        bcs _got
        inx
        jmp _find
_got    stx tmp_x0              ; card_todo &= ~(1 << c)
        txa
        and #7
        tay
        lda spr_bit,y
        eor #$ff
        cpx #8
        bcs +
        and card_todo
        sta card_todo
        jmp ++
+       and card_todo+1
        sta card_todo+1
+       lda tmp_x0
        asl a
        tax
        lda card_table,x
        ldy card_table+1,x
        ldx #MODE_CARD
        jsr text_screen
        lda #<page_card_foot
        ldy #>page_card_foot
        jsr print_page
        ldx tmp_x0
        lda card_bots,x
        bne +
        rts
+       ; το παράδειγμα: δείκτης στο card_tpl (από 1)
        sec
        sbc #1
        asl a
        tax
        lda card_tpl,x
        sta ptr1
        lda card_tpl+1,x
        sta ptr1+1              ; cap, flags, freeze, lock, πλήθος, στρώσεις
        lda #<card_bot
        sta bptr
        lda #>card_bot
        sta bptr+1
        ldy #0
        lda (ptr1),y
        jsr bottle_init
        ldy #1
        lda (ptr1),y
        ldy #B_FLAGS
        sta (bptr),y
        ldy #2
        lda (ptr1),y
        ldy #B_FREEZE
        sta (bptr),y
        ldy #3
        lda (ptr1),y
        ldy #B_LOCK
        sta (bptr),y
        ldy #4
        lda (ptr1),y
        ldy #B_CNT
        sta (bptr),y
        tax
        lda #5
        sta tmp4
        lda #B_LAY
        sta tmp5
-       ldy tmp4
        lda (ptr1),y
        ldy tmp5
        sta (bptr),y
        inc tmp4
        inc tmp5
        dex
        bne -
        ldy #B_X
        lda #CARD_BOT_X
        sta (bptr),y
        ldy #B_Y
        lda #CARD_BOT_Y
        sta (bptr),y
        jmp draw_bottle

card_frame
        lda input_new
        and #IN_FIRE|IN_ESC
        bne +
        rts
+       lda #<sfx_tick
        ldy #>sfx_tick
        jsr play_sfx
        lda card_todo
        ora card_todo+1
        beq +
        jmp card_next
+       lda #MODE_GAME          ; στην πίστα
        sta mode
        lda paused_timer
        sta timer_on
        jsr cls
        jmp level_show

card_todo       .word 0

card_table      .word card_hidden,card_ice,card_lock,card_moves,card_tall
                .word card_drop,card_curtain,card_timer,card_extra
card_bots       .byte 1,2,3,0,4,5,6,0,0 ; card_tpl (από 1), 0 = χωρίς

; cap, bflags, πάγος, λουκέτο, πλήθος, στρώσεις
card_tpl        .word tpl_hidden,tpl_ice,tpl_lock,tpl_tall,tpl_drop,tpl_curtain
tpl_hidden      .byte 4,0,0,0,4, 6|$80,9|$80,4|$80,7
tpl_ice         .byte 4,0,3,0,3, 5,8,5
tpl_lock        .byte 4,0,0,9,2, 4,7
tpl_tall        .byte 6,0,0,0,5, 10,10,6,13,4
tpl_drop        .byte 4,BF_DROPPER,0,0,3, 12,7,7
tpl_curtain     .byte 4,BF_CURTAIN,0,0,3, 6,9,4

page_card_foot
        .byte 186,CENTER,PEN_GLASS
        .null "SPACE CONTINUE"
        .byte $ff

card_hidden
        .byte 14,CENTER,PEN_LIQUID+2
        .null "NEW: HIDDEN LAYERS"
        .byte 36,2,PEN_WHITE
        .null "SOME LAYERS ARE HIDDEN AND SHOW A"
        .byte 48,2,PEN_WHITE
        .null "? - A HIDDEN LAYER IS REVEALED"
        .byte 60,2,PEN_WHITE
        .null "WHEN IT REACHES THE TOP."
        .byte $ff
card_ice
        .byte 14,CENTER,PEN_LIQUID+2
        .null "NEW: FROZEN BOTTLE"
        .byte 36,2,PEN_WHITE
        .null "YOU CANNOT POUR FROM OR INTO IT."
        .byte 48,2,PEN_WHITE
        .null "THE NUMBER SHOWS HOW MANY MOVES"
        .byte 60,2,PEN_WHITE
        .null "ARE LEFT UNTIL THE ICE MELTS."
        .byte $ff
card_lock
        .byte 14,CENTER,PEN_LIQUID+2
        .null "NEW: LOCKED BOTTLE"
        .byte 36,2,PEN_WHITE
        .null "IT OPENS WHEN ANOTHER BOTTLE IS"
        .byte 48,2,PEN_WHITE
        .null "COMPLETED IN THE COLOUR OF THE"
        .byte 60,2,PEN_WHITE
        .null "LOCK. UNTIL THEN IT STAYS SHUT."
        .byte $ff
card_moves
        .byte 14,CENTER,PEN_LIQUID+2
        .null "NEW: MOVE LIMIT"
        .byte 36,2,PEN_WHITE
        .null "SOLVE IT BEFORE YOU RUN OUT OF"
        .byte 48,2,PEN_WHITE
        .null "MOVES. LEFT AT THE TOP SHOWS HOW"
        .byte 60,2,PEN_WHITE
        .null "MANY YOU STILL HAVE."
        .byte 84,2,PEN_WHITE
        .null "UNDO GIVES A MOVE BACK."
        .byte $ff
card_tall
        .byte 14,CENTER,PEN_LIQUID+2
        .null "NEW: TALL BOTTLES"
        .byte 36,2,PEN_WHITE
        .null "SOME BOTTLES HOLD MORE LAYERS."
        .byte 48,2,PEN_WHITE
        .null "WHEN SIZES DIFFER, TICKS ON THE"
        .byte 60,2,PEN_WHITE
        .null "GLASS MARK EACH LAYER."
        .byte $ff
card_drop
        .byte 14,CENTER,PEN_LIQUID+2
        .null "NEW: DROPPER"
        .byte 36,2,PEN_WHITE
        .null "A BOTTLE WITH A BULB POURS ONLY"
        .byte 48,2,PEN_WHITE
        .null "ONE LAYER AT A TIME."
        .byte $ff
card_curtain
        .byte 14,CENTER,PEN_LIQUID+2
        .null "NEW: CURTAIN"
        .byte 36,2,PEN_WHITE
        .null "THE BOTTLE HIDES BEHIND A CURTAIN"
        .byte 48,2,PEN_WHITE
        .null "UNTIL YOU POUR FROM OR INTO IT"
        .byte 60,2,PEN_WHITE
        .null "FOR THE FIRST TIME."
        .byte $ff
card_timer
        .byte 14,CENTER,PEN_LIQUID+2
        .null "NEW: AGAINST THE CLOCK"
        .byte 36,2,PEN_WHITE
        .null "SOLVE IT BEFORE THE TIME AT THE"
        .byte 48,2,PEN_WHITE
        .null "TOP RUNS OUT. STOP PAUSES THE"
        .byte 60,2,PEN_WHITE
        .null "CLOCK."
        .byte $ff
card_extra
        .byte 14,CENTER,PEN_LIQUID+2
        .null "NEW: EXTRA BOTTLE"
        .byte 36,2,PEN_WHITE
        .null "STUCK? PRESS E - ONCE PER LEVEL -"
        .byte 48,2,PEN_WHITE
        .null "FOR AN EXTRA EMPTY BOTTLE."
        .byte 60,2,PEN_WHITE
        .null "E+ AT THE TOP SHOWS IT IS THERE."
        .byte $ff
