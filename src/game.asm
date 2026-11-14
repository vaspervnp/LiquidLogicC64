; game.asm — η λογική του παιχνιδιού: πίστες, επιλογή πηγής/στόχου,
; μετάγγιση, κινήσεις, undo, restart, αδιέξοδο, νίκη, ειδικοί τύποι
; (πάγος, λουκέτο, όριο κινήσεων, χρονόμετρο, έξτρα μπουκάλι)

ST_IDLE         = 0             ; κέρσορας
ST_SEL          = 1             ; πηγή επιλεγμένη (σηκωμένη)
ST_POUR         = 2             ; ο πίδακας τρέχει
ST_WIN          = 3
ST_FAIL         = 4             ; τέλος χρόνου: R / SPACE, M = μενού
ST_PAUSE        = 5             ; ESC: ESC = συνέχεια, R, M = μενού

UNDO_MAX        = 5             ; undo ανά πίστα
LEVEL_MAX       = 6+MAX_BOTTLES*(4+MAX_CAP)     ; header + μπουκάλια
MAX_LEVELS      = 100
SNAP_SIZE       = MAX_BOTTLES*BOT_SIZE+1        ; στιγμιότυπο: μπουκάλια + κινήσεις
HUD_Y           = 4

; Αντιγράφει την πίστα (level) στο level_buf.
level_load
        ldx level
        lda level_table_lo,x
        sta ptr1
        lda level_table_hi,x
        sta ptr1+1
        ldy #0
-       lda (ptr1),y
        sta level_buf,y
        iny
        cpy #LEVEL_MAX
        bne -
        rts

level_start
        lda #0
        sta shake_cnt
        jsr music_stop
        jsr fly_hide
        jsr jet_hide
        jsr cursor_erase
        jsr cls
        lda relax
        beq _load
        lda relax_new           ; «Χαλάρωση»: καινούργια, ή ξανά η ίδια (R)
        beq +
        jsr relax_gen
+       lda #0
        sta relax_new
        jmp _setup
_load   jsr level_load
_setup  lda #<level_buf
        sta ptr1
        lda #>level_buf
        sta ptr1+1
        jsr level_setup
        lda #0
        sta moves
        sta undo_sp
        sta cursor
        sta state
        sta extra_used
        sta undo_used
        sta time_up
        sta timer_on
        sta src_lines           ; (το liquid_sync δεν έχει τίποτα να κάνει)
        sta src_shown
        sta dst_lines
        sta dst_shown
        jsr part_clear
        lda #UNDO_MAX
        sta undo_left
        lda level_timer         ; χρονόμετρο: header x 4 δευτερόλεπτα
        beq _notime
        asl a
        sta time_left
        lda #0
        rol a
        sta time_left+1
        asl time_left
        rol time_left+1
        lda #50
        sta time_frames
        sta timer_on
_notime jsr card_check          ; κάρτα για νέο ειδικό τύπο: πρώτα αυτή, και
        beq level_show          ; μετά το level_show (help.asm)
        rts
level_show
        jsr draw_all_bottles
        jsr hud_draw
        lda #0
        jmp cursor_draw

game_frame
        lda time_up             ; τέλος χρόνου (αφού τελειώσει η μετάγγιση)
        beq _state
        lda state
        cmp #ST_POUR
        beq _state
        lda #0
        sta time_up
        sta timer_on
        lda state
        beq +
        jsr deselect
+       lda #ST_FAIL
        sta state
        lda #<sfx_timeup
        ldy #>sfx_timeup
        jsr play_sfx
        lda #<str_timeup
        ldy #>str_timeup
        ldx #PEN_LIQUID
        jmp hud_message
_state  lda state
        bne +
        jsr shake_frame
+       lda state
        cmp #ST_POUR
        bne +
        jmp _pour
+       cmp #ST_WIN
        bne +
        jmp _win
+       cmp #ST_FAIL
        bne +
        jmp _fail
+       cmp #ST_PAUSE
        bne +
        jmp _pause
+       lda input_new
        and #IN_RESTART
        beq +
        jmp level_start
+       lda input_new
        and #IN_UNDO
        beq _extra
        lda state
        beq +
        jsr deselect
+       jmp do_undo
_extra  lda input2_new          ; E: έξτρα μπουκάλι
        and #IN2_EXTRA
        beq _move
        lda state
        beq +
        jsr deselect
+       jmp extra_bottle
_move   lda input_new
        and #IN_LEFT|IN_RIGHT|IN_UP|IN_DOWN
        beq +
        jsr move_cursor
+       lda input_new
        and #IN_ESC
        beq _fire
        lda state
        beq +
        jmp deselect
+       lda #ST_PAUSE           ; ESC χωρίς επιλογή: παύση (σταματάει ο χρόνος)
        sta state
        lda timer_on
        sta paused_timer
        lda #0
        sta timer_on
        lda #<str_pause
        ldy #>str_pause
        ldx #PEN_WHITE
        jmp hud_message
_fire   lda input_new
        and #IN_FIRE
        bne +
        rts
+       lda state
        bne _second
        lda cursor              ; 1η επιλογή: από εδώ αδειάζει
        jsr bottle_ix
        ldy #B_CNT
        lda (bptr),y
        bne +
        rts
+       ldy #B_DONE             ; ολοκληρωμένο: όχι
        lda (bptr),y
        beq +
        rts
+       ldy #B_FREEZE           ; παγωμένο, κλειδωμένο: χοροπηδάει
        lda (bptr),y
        iny
        ora (bptr),y
        beq +
        lda cursor
        jmp shake_start
+       jsr shake_stop
        lda cursor
        sta sel_src
        jsr bottle_ix
        ldy #B_RAISE
        lda #RAISE_H
        sta (bptr),y
        jsr redraw_bottle
        lda #<sfx_select
        ldy #>sfx_select
        jsr play_sfx
        lda #ST_SEL
        sta state
        rts
_second lda cursor              ; 2η επιλογή: εδώ γεμίζει
        cmp sel_src
        bne +
        jmp deselect
+       sta sel_dst
        jsr try_pour
        bcs _bad
        inc moves               ; ως 255
        bne +
        dec moves
+       jsr hud_draw            ; κανένα σωματίδιο ακόμα στην οθόνη
        lda #ST_POUR
        sta state
        rts
_bad    jsr deselect            ; άκυρη: ακύρωση, βουητό, ο στόχος χοροπηδάει
        lda sel_dst
        jmp shake_start
_pour   lda pour_phase          ; πτήση, πίδακας, επιστροφή
        bne _jet
        jsr fly_step
        beq +
        rts
+       lda #1
        sta pour_phase
        jmp pour_aim
_jet    cmp #1
        bne _back
        jsr particles_frame
        beq +
        rts
+       lda #2
        sta pour_phase
        jmp pour_finish
_back   jsr fly_step
        beq +
        rts
+       jsr pour_land
        jsr after_move
        lda #0
        sta state
        jsr check_win
        bne _limit
        sta timer_on            ; A = 0
        lda #ST_WIN
        sta state
        lda #<sfx_win
        ldy #>sfx_win
        jsr play_sfx
        jmp win_message
_limit  lda level_moves         ; όριο κινήσεων
        beq _stuck
        cmp moves
        beq _out
        bcs _stuck
_out    lda #<sfx_timeup
        ldy #>sfx_timeup
        jsr play_sfx
        lda #<str_nomoves
        ldy #>str_nomoves
        ldx #PEN_LIQUID
        jmp hud_message
_stuck  jsr check_stuck
        beq +
        rts
+       lda #<sfx_error
        ldy #>sfx_error
        jsr play_sfx
        jsr extra_allowed
        bne +
        lda #<str_stuck
        ldy #>str_stuck
        jmp ++
+       lda #<str_stuck_e
        ldy #>str_stuck_e
+       ldx #PEN_LIQUID
        jmp hud_message
_fail   jsr game_menu
        lda input_new
        and #IN_RESTART|IN_FIRE
        bne +
        rts
+       jmp level_start
_pause  jsr game_menu
        lda input_new
        and #IN_RESTART
        beq +
        jmp level_start
+       lda relax               ; «Χαλάρωση»: SPACE = άλλη πίστα
        beq _resume
        lda input_new
        and #IN_FIRE
        bne _relax_next
_resume lda input_new
        and #IN_ESC
        bne +
        rts
+       lda #0                  ; συνέχεια
        sta state
        lda paused_timer
        sta timer_on
        jmp hud_draw
_win    jsr medal_toast         ; νέα μετάλλια, εναλλάξ με τη γραμμή της νίκης
        lda input2_new          ; φεύγοντας από τη νίκη: αποθήκευση, αν άλλαξε
        and #IN2_MENU           ; κάτι (δεν ξανατρέχει: save_dirty = 0)
        sta tmp0
        lda input_new
        and #IN_RESTART|IN_FIRE|IN_ESC
        ora tmp0
        beq +
        jsr save_if_dirty
+       jsr game_menu
        lda input_new
        and #IN_RESTART
        beq +
        jmp level_start
+       lda input_new
        and #IN_FIRE
        bne +
        rts
+       lda relax
        beq _next
_relax_next
        lda #1
        sta relax_new
        jmp level_start
_next   ldx level               ; επόμενη πίστα (μετά την τελευταία: το τέλος)
        inx
        cpx #LEVEL_COUNT
        bcc +
        jmp ending_start
+       stx level
        jmp level_start

; M (ή ESC στη νίκη / στο τέλος χρόνου): στην επιλογή πίστας. Δεν επιστρέφει
; τότε στον καλούντα.
game_menu
        lda input2_new
        and #IN2_MENU
        bne _tomenu
        lda state
        cmp #ST_PAUSE
        beq _r
        lda input_new
        and #IN_ESC
        beq _r
_tomenu pla                     ; (η διεύθυνση επιστροφής: δεν γυρνάμε εκεί)
        pla
        lda relax               ; από τη «Χαλάρωση»: στον τίτλο
        beq +
        jmp relax_leave
+       jmp select_start
_r      rts

; Η πρόοδος στη δισκέτα, αν άλλαξε από την τελευταία φορά (award_stars).
; Η οθόνη δείχνει SAVING και μένει ακίνητη όσο γράφει το drive.
save_if_dirty
        lda save_dirty
        bne +
        rts
+       lda #0
        sta save_dirty
        lda #<str_saving
        ldy #>str_saving
        ldx #PEN_WHITE
        jsr hud_message
        jmp save_progress

; Νίκη: αστέρια, στατιστικά, μετάλλια (win_stats), και η γραμμή της νίκης.
win_message
        jsr win_stats

; Η γραμμή της νίκης στη θέση του HUD: αστέρια (win_stars) και τι κάνει το
; SPACE / το M.
win_line
        lda #1
        sta hud_msg
        jsr hud_clear
        lda relax
        beq _stars
        lda #<str_solved        ; «Χαλάρωση»: χωρίς αστέρια και αποθήκευση
        ldy #>str_solved
        jsr set_text
        ldx #1
        ldy #HUD_Y
        lda #PEN_WHITE
        jsr print_str
        jsr seed_tag            ; με seed: και ποια πίστα
        jmp _keys
_stars  lda #<str_clear
        ldy #>str_clear
        jsr set_text
        ldx #1
        ldy #HUD_Y
        lda #PEN_WHITE
        jsr print_str
        lda #3                  ; «***» κομμένο στο πλήθος
        sec
        sbc win_stars
        clc
        adc #<str_stars
        sta ptr0
        lda #>str_stars
        adc #0
        sta ptr0+1
        ldx #13
        ldy #HUD_Y
        lda #PEN_LIQUID+2
        jsr print_str
_keys   lda #<str_next
        ldy #>str_next
        jsr set_text
        ldx #18
        ldy #HUD_Y
        lda #PEN_LIQUID+5
        jsr print_str
        lda #<str_menu
        ldy #>str_menu
        jsr set_text
        ldx #30
        ldy #HUD_Y
        lda #PEN_GLASS
        jmp print_str

; Άκυρη κίνηση: το μπουκάλι A χοροπηδάει (B_RAISE RAISE_H/0: μια σειρά
; cells, όσο σηκώνεται και η πηγή) για SHAKE_FRAMES καρέ, με το βουητό.
; Μόνο σε ST_IDLE· πριν από κάθε επιλογή shake_stop.
SHAKE_FRAMES    = 8
shake_start
        pha
        jsr shake_stop
        pla
        sta shake_bot
        lda #SHAKE_FRAMES
        sta shake_cnt
        lda #<sfx_error
        ldy #>sfx_error
        jmp play_sfx

shake_frame
        lda shake_cnt
        beq _r
        dec shake_cnt
        lda shake_cnt
        and #2
        beq +
        lda #RAISE_H
+       pha
        lda shake_bot
        jsr bottle_ix
        pla
        ldy #B_RAISE
        cmp (bptr),y
        beq _r
        sta (bptr),y
        jmp redraw_bottle
_r      rts

shake_stop
        lda shake_cnt
        beq _r
        lda #0
        sta shake_cnt
        lda shake_bot
        jsr bottle_ix
        lda #0
        ldy #B_RAISE
        sta (bptr),y
        jmp redraw_bottle
_r      rts

; Μετά από κάθε μετάγγιση (τα σωματίδια έχουν σβηστεί): ξεκλείδωμα όσων
; περιμένουν το χρώμα που μόλις ολοκληρώθηκε, και ο πάγος μετράει μία κίνηση.
after_move
        inc stat_pours          ; στατιστικά: ως 65535
        bne +
        inc stat_pours+1
        bne +
        dec stat_pours
        dec stat_pours+1
+       lda pour_dst
        sta bptr
        lda pour_dst+1
        sta bptr+1
        lda #0
        sta tmp_pen             ; χρώμα που ολοκληρώθηκε
        ldy #B_DONE
        lda (bptr),y
        beq +
        ldy #B_LAY
        lda (bptr),y
        and #$7f
        sta tmp_pen
+       lda #0
        sta tmp_row             ; 1 = κάτι ξεκλείδωσε / ξεπάγωσε
        sta tmp_x0
_bot    lda tmp_x0
        jsr bottle_ix
        lda #0
        sta tmp_y               ; χρειάζεται ξανασχεδίαση
        lda tmp_pen
        beq _ice
        ldy #B_LOCK
        cmp (bptr),y
        bne _ice
        lda #0
        sta (bptr),y
        lda #1
        sta tmp_row
        sta tmp_y
_ice    ldy #B_FREEZE
        lda (bptr),y
        beq _draw
        lda #1
        sta tmp_y
        lda (bptr),y
        sec
        sbc #1
        sta (bptr),y
        bne _draw
        lda #1                  ; ξεπάγωσε
        sta tmp_row
_draw   lda tmp_y
        beq +
        jsr redraw_bottle
+       inc tmp_x0
        lda tmp_x0
        cmp nbottles
        bne _bot
        lda tmp_row
        beq +
        lda #<sfx_chime
        ldy #>sfx_chime
        jmp play_sfx
+       rts

;------------------------------------------------------------------
; Undo: πριν από κάθε μετάγγιση (try_pour) ένα στιγμιότυπο όλων των
; μπουκαλιών και των κινήσεων· έτσι αναιρούνται και πάγος, λουκέτα,
; αποκαλύψεις και κουρτίνες. Κρατάει τα UNDO_MAX τελευταία.
push_undo
        lda undo_sp
        cmp #UNDO_MAX
        bcc _room
        ldx #0                  ; γεμάτο: χάνεται το παλαιότερο
        lda #<undo_stack
        sta ptr2
        lda #>undo_stack
        sta ptr2+1
        lda #<(undo_stack+SNAP_SIZE)
        sta ptr3
        lda #>(undo_stack+SNAP_SIZE)
        sta ptr3+1
        lda #<((UNDO_MAX-1)*SNAP_SIZE)
        ldx #>((UNDO_MAX-1)*SNAP_SIZE)
        jsr copy_mem
        lda #UNDO_MAX-1
_room   pha
        clc
        adc #1
        sta undo_sp
        pla
        jsr snap_ptr            ; ptr2 = στιγμιότυπο
        lda #<bottles
        sta ptr3
        lda #>bottles
        sta ptr3+1
        lda ptr2                ; (copy_mem: από ptr3 στο ptr2)
        pha
        lda ptr2+1
        pha
        lda #<(MAX_BOTTLES*BOT_SIZE)
        ldx #>(MAX_BOTTLES*BOT_SIZE)
        jsr copy_mem
        pla
        sta ptr2+1
        pla
        sta ptr2
        ldy #<(MAX_BOTTLES*BOT_SIZE)
        lda #>(MAX_BOTTLES*BOT_SIZE)
        clc
        adc ptr2+1
        sta ptr2+1
        lda moves
        sta (ptr2),y
        rts

; Αντιγράφει X:A bytes από το ptr3 στο ptr2 (από την αρχή προς το τέλος).
copy_mem
        sta tmp0
        stx tmp1
        ldy #0
-       lda tmp0
        ora tmp1
        beq _r
        lda (ptr3),y
        sta (ptr2),y
        inc ptr3
        bne +
        inc ptr3+1
+       inc ptr2
        bne +
        inc ptr2+1
+       lda tmp0
        bne +
        dec tmp1
+       dec tmp0
        jmp -
_r      rts

; ptr2 = undo_stack + A * SNAP_SIZE
snap_ptr
        tax
        lda #<undo_stack
        sta ptr2
        lda #>undo_stack
        sta ptr2+1
        cpx #0
        beq _r
-       clc
        lda ptr2
        adc #<SNAP_SIZE
        sta ptr2
        lda ptr2+1
        adc #>SNAP_SIZE
        sta ptr2+1
        dex
        bne -
_r      rts

; Ξανασχεδιάζονται μόνο τα μπουκάλια που διαφέρουν από το στιγμιότυπο (όχι όλη
; η οθόνη): λίγα καρέ, ώστε να μη χάνονται πατήματα πλήκτρων.
do_undo
        lda undo_left
        bne +
        rts
+       lda undo_sp
        bne +
        rts
+       sta undo_used           ; (≠ 0) για το μετάλλιο NO REGRETS
        sec
        sbc #1
        sta undo_sp
        jsr snap_ptr
        lda ptr2                ; οι κινήσεις, μετά τα μπουκάλια
        sta ptr3
        lda ptr2+1
        clc
        adc #>(MAX_BOTTLES*BOT_SIZE)
        sta ptr3+1
        ldy #<(MAX_BOTTLES*BOT_SIZE)
        lda (ptr3),y
        sta moves
        lda #0
        sta tmp_x0
_bot    lda tmp_x0
        jsr bottle_ix
        ldy #BOT_SIZE-1
-       lda (ptr2),y
        cmp (bptr),y
        bne _diff
        dey
        bpl -
        jmp _next
_diff   ldy #BOT_SIZE-1         ; διαφέρει: αντιγραφή και ανασχεδίαση
-       lda (ptr2),y
        sta (bptr),y
        dey
        bpl -
        ldy #B_RAISE
        lda #0
        sta (bptr),y
        lda ptr2
        pha
        lda ptr2+1
        pha
        jsr redraw_bottle
        pla
        sta ptr2+1
        pla
        sta ptr2
_next   clc
        lda ptr2
        adc #BOT_SIZE
        sta ptr2
        bcc +
        inc ptr2+1
+       inc tmp_x0
        lda tmp_x0
        cmp nbottles
        bne _bot
        dec undo_left
        lda #<sfx_undo
        ldy #>sfx_undo
        jsr play_sfx
        jmp hud_draw

; Ολόκληρη η οθόνη από την αρχή.
redraw_all
        jsr cls
        jsr draw_all_bottles
        jsr hud_draw
        lda cursor
        jmp cursor_draw

;------------------------------------------------------------------
; NZ = το E επιτρέπεται σε αυτή την πίστα και δεν έχει χρησιμοποιηθεί.
extra_allowed
        lda level_flags
        and #LF_EXTRA
        beq +
        lda extra_used
        eor #1
+       rts

; Ένα άδειο μπουκάλι παραπάνω (μία φορά ανά πίστα). Οι θέσεις αλλάζουν,
; οπότε τα στιγμιότυπα του undo δεν ισχύουν πια.
extra_bottle
        jsr extra_allowed
        bne +
        rts
+       lda nbottles
        cmp #MAX_BOTTLES
        bcc +
        rts
+       lda #1
        sta extra_used
        lda nbottles
        inc nbottles
        jsr bottle_ix
        lda level_cap
        jsr bottle_init
        lda #0
        ldy #B_FLAGS
        sta (bptr),y
        jsr layout
        lda #0
        sta undo_sp
        lda #<sfx_extra
        ldy #>sfx_extra
        jsr play_sfx
        jmp redraw_all

;------------------------------------------------------------------
; Χρονόμετρο (μετά το interrupt του καρέ, main.asm).
timer_tick
        lda timer_on
        beq _r
        dec time_frames
        bne _r
        lda #50
        sta time_frames
        lda time_left
        ora time_left+1
        beq _r
        lda time_left
        bne +
        dec time_left+1
+       dec time_left
        lda time_left
        ora time_left+1
        bne _show
        lda #1
        sta time_up
_show   lda hud_msg
        beq hud_time
_r      rts
hud_time
        lda time_left
        ldx time_left+1
        jsr num16_str
        lda #<num_buf
        ldy #>num_buf
        jsr set_text
        ldx #30
        ldy #HUD_Y
        lda #PEN_LIQUID+2
        jmp print_str

;------------------------------------------------------------------
; HUD: πίστα, κινήσεις (ή όσες μένουν), undo, χρόνος, E+.
hud_draw
        lda #0
        sta hud_msg
        jsr hud_clear
        lda relax
        beq _lvn
        jsr relax_label
        jmp _lvdone
_lvn    lda #<str_lv
        ldy #>str_lv
        jsr set_text
        ldx #0
        ldy #HUD_Y
        lda #PEN_WHITE
        jsr print_str
        lda level
        clc
        adc #1
        pha
        jsr num_str
        pla
        ldx #<num_buf+1         ; 2 ψηφία, 3 από το 100
        cmp #100
        bcc +
        ldx #<num_buf
+       txa
        ldy #>num_buf
        jsr set_text
        ldx #3
        ldy #HUD_Y
        lda #PEN_LIQUID+2
        jsr print_str
_lvdone lda level_moves
        beq _moves
        lda #<str_left          ; όριο: όσες μένουν
        ldy #>str_left
        jsr set_text
        ldx #7
        ldy #HUD_Y
        lda #PEN_WHITE
        jsr print_str
        lda level_moves
        sec
        sbc moves
        bcs +
        lda #0
+       jsr num_str
        ldx #12
        jmp _mnum
_moves  lda #<str_moves
        ldy #>str_moves
        jsr set_text
        ldx #7
        ldy #HUD_Y
        lda #PEN_WHITE
        jsr print_str
        lda moves
        jsr num_str
        ldx #13
_mnum   lda #<num_buf
        ldy #>num_buf
        jsr set_text
        ldy #HUD_Y
        lda #PEN_LIQUID+2
        jsr print_str
        lda #<str_undo
        ldy #>str_undo
        jsr set_text
        ldx #17
        ldy #HUD_Y
        lda #PEN_WHITE
        jsr print_str
        lda undo_left
        jsr num_str
        lda #<num_buf+2
        ldy #>num_buf+2
        jsr set_text
        ldx #22
        ldy #HUD_Y
        lda #PEN_LIQUID+2
        jsr print_str
        lda level_timer
        beq _extra
        lda #<str_time
        ldy #>str_time
        jsr set_text
        ldx #25
        ldy #HUD_Y
        lda #PEN_WHITE
        jsr print_str
        jsr hud_time
_extra  jsr extra_allowed
        bne +
        rts
+       lda #<str_extra
        ldy #>str_extra
        jsr set_text
        ldx #37
        ldy #HUD_Y
        lda #PEN_LIQUID+5       ; κυανό
        jmp print_str

hud_clear
        ldx #0
        ldy #HUD_Y
        lda #40
        jmp clear_text

; Μήνυμα στη θέση του HUD, στο κέντρο. A/Y = κείμενο, X = pen.
hud_message
        jsr set_text
        stx tmp_pen
        lda #1
        sta hud_msg
        jsr hud_clear
        jsr str_len             ; x = (40 - μήκος) / 2
        sta tmp0
        lda #40
        sec
        sbc tmp0
        lsr a
        tax
        ldy #HUD_Y
        lda tmp_pen
        jmp print_str

; A = μήκος του κειμένου ptr0. Κρατάει X.
str_len
        ldy #0
-       lda (ptr0),y
        beq +
        iny
        bne -
+       tya
        rts

; num_buf = A σε 3 ψηφία.
num_str
        ldx #0
; num_buf = X:A (ως 999) σε 3 ψηφία.
num16_str
        sta tmp0
        stx tmp1
        ldx #0
        ldy #0
-       lda tmp0                ; εκατοντάδες
        sec
        sbc #100
        sta tmp2
        lda tmp1
        sbc #0
        bcc +
        sta tmp1
        lda tmp2
        sta tmp0
        inx
        bne -
+       txa
        ora #"0"
        sta num_buf
        ldx #"0"
        lda tmp0
-       cmp #10
        bcc +
        sbc #10
        inx
        bne -
+       stx num_buf+1
        ora #"0"
        sta num_buf+2
        lda #0
        sta num_buf+3
        rts

;------------------------------------------------------------------
; out: Z = καμία έγκυρη μετάγγιση (αδιέξοδο). Παγωμένα και κλειδωμένα δεν
; μετράνε ούτε ως πηγή ούτε ως στόχος.
check_stuck
        lda #0
        sta tmp_x0              ; πηγή
_src    lda tmp_x0
        jsr bottle_ix
        ldy #B_CNT
        lda (bptr),y
        beq _nsrc
        ldy #B_DONE
        lda (bptr),y
        ldy #B_FREEZE
        ora (bptr),y
        iny
        ora (bptr),y
        bne _nsrc
        jsr top_layer
        lda (bptr),y
        sta tmp_pen             ; χρώμα της κορυφής
        lda #0
        sta tmp_y               ; στόχος
_dst    lda tmp_y
        cmp tmp_x0
        beq _ndst               ; το ίδιο μπουκάλι
        tax
        lda bot_lo,x
        sta dptr
        lda bot_hi,x
        sta dptr+1
        ldy #B_FREEZE
        lda (dptr),y
        iny
        ora (dptr),y
        bne _ndst
        ldy #B_CNT
        lda (dptr),y
        ldy #B_CAP
        cmp (dptr),y
        beq _ndst               ; γεμάτο
        cmp #0
        beq _found              ; άδειο
        jsr top_layer_d
        lda (dptr),y
        cmp tmp_pen
        beq _found
_ndst   inc tmp_y
        lda tmp_y
        cmp nbottles
        bne _dst
_nsrc   inc tmp_x0
        lda tmp_x0
        cmp nbottles
        bne _src
        lda #0
        rts
_found  lda #1
        rts

deselect
        lda #<sfx_cancel
        ldy #>sfx_cancel
        jsr play_sfx
        lda sel_src
        jsr bottle_ix
        ldy #B_RAISE
        lda #0
        sta (bptr),y
        jsr redraw_bottle
        lda #0
        sta state
        rts

; out: Z = όλα τα μπουκάλια άδεια ή ολοκληρωμένα.
check_win
        ldx #0
-       lda bot_lo,x
        sta bptr
        lda bot_hi,x
        sta bptr+1
        ldy #B_CNT
        lda (bptr),y
        beq +
        ldy #B_DONE
        lda (bptr),y
        bne +
        lda #1
        rts
+       inx
        cpx nbottles
        bne -
        lda #0
        rts

; A = πλήκτρα κατεύθυνσης (input_new).
move_cursor
        sta tmp4
        jsr cursor_erase
        lda cursor
        jsr bottle_ix
        ldy #B_ROW
        lda (bptr),y
        sta tmp5                ; σειρά
        tax
        lda row_len,x
        sta tmp2                ; μήκος
        lda cursor
        sec
        sbc row_start,x
        sta tmp3                ; θέση στη σειρά
        lda tmp4
        and #IN_LEFT
        beq _right
        lda tmp3
        bne +
        lda tmp2
        sta tmp3
+       dec tmp3
_right  lda tmp4
        and #IN_RIGHT
        beq _up
        inc tmp3
        lda tmp3
        cmp tmp2
        bne _up
        lda #0
        sta tmp3
_up     lda tmp4
        and #IN_UP
        beq _down
        lda #0
        sta tmp5
_down   lda tmp4
        and #IN_DOWN
        beq _set
        lda nrows
        cmp #2
        bne _set
        lda #1
        sta tmp5
_set    ldx tmp5                ; θέση = min(θέση, μήκος-1)
        lda row_len,x
        sec
        sbc #1
        cmp tmp3
        bcs +
        sta tmp3
+       lda row_start,x
        clc
        adc tmp3
        sta cursor
        jmp cursor_draw

str_lv          .null "LV"
str_relax       .null "RELAX"
str_moves       .null "MOVES"
str_left        .null "LEFT"
str_undo        .null "UNDO"
str_time        .null "TIME"
str_extra       .null "E+"
str_clear       .null "LEVEL CLEAR"
str_solved      .null "SOLVED!"
str_saving      .null "SAVING..."
str_stars       .null "***"
str_next        .null "SPACE NEXT"
str_menu        .null "M MENU"
str_pause       .null "PAUSE  STOP PLAY  R RESTART  M MENU"
str_stuck       .null "NO MOVES! U UNDO  R RESTART"
str_stuck_e     .null "NO MOVES! E EXTRA BOTTLE"
str_nomoves     .null "OUT OF MOVES! U UNDO  R RESTART"
str_timeup      .null "TIME UP! R RESTART"
