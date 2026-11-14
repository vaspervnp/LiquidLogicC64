; disc.asm — η πρόοδος στη δισκέτα (LIQUID.SAV), μέσα από το KERNAL
;
; Όπως στον CPC από το AMSDOS: από το unlocked ως το save_end (main.asm),
; συνεχόμενα. Ένα LIQUID.SAV πιο σύντομο (παλιότερο) φορτώνεται κι αυτό: τα
; υπόλοιπα μένουν στις αρχικές τιμές, και το apply_settings ελέγχει τις
; τιμές.
;   - στην εκκίνηση (load_progress) το KERNAL είναι ακόμα μέσα
;   - για την αποθήκευση (save_progress) μπαίνει ξανά ($01 = $36), με το
;     raster interrupt κλειστό και SEI· μετά ξαναβγαίνει και το interrupt
;     ξαναστήνεται. Το KERNAL δεν τυπώνει μηνύματα (SETMSG 0): χωρίς drive ή
;     με λάθος απλώς δεν αποθηκεύεται τίποτα.
; Το αρχείο γράφεται ως PRG: πρώτα σβήνεται το παλιό (S0:LIQUID.SAV στο
; κανάλι εντολών), μετά SAVE.

SETMSG          = $ff90
SETLFS          = $ffba
SETNAM          = $ffbd
OPEN            = $ffc0
CLOSE           = $ffc3
CLRCHN          = $ffcc
LOAD            = $ffd5
SAVE            = $ffd8
SAVE_SIZE       = save_end-unlocked
SAVE_BUF        = undo_stack    ; (ελεύθερο στην εκκίνηση)
KERNAL_DEV      = $ba           ; η συσκευή απ' όπου φορτώθηκε το παιχνίδι

; Στην εκκίνηση, με το KERNAL μέσα.
load_progress
        jsr disc_device
        lda #0
        jsr SETMSG
        lda #name_len
        ldx #<save_name
        ldy #>save_name
        jsr SETNAM
        lda #1
        ldx disc_dev
        ldy #0                  ; SA 0: στη διεύθυνση X/Y
        jsr SETLFS
        lda #0                  ; LOAD
        ldx #<SAVE_BUF
        ldy #>SAVE_BUF
        jsr LOAD
        bcs _none
        stx tmp0                ; το τέλος: μήκος = τέλος - αρχή
        sty tmp1
        lda SAVE_BUF            ; έγκυρο unlocked: 1..MAX_LEVELS
        beq _none
        cmp #MAX_LEVELS+1
        bcs _none
        lda tmp0
        sec
        sbc #<SAVE_BUF
        sta tmp0
        lda tmp1
        sbc #>SAVE_BUF
        bne _all                ; > 255: όλο
        lda tmp0
        cmp #SAVE_SIZE
        bcc +
_all    lda #SAVE_SIZE          ; min(μήκος, SAVE_SIZE)
+       tax
        beq _none
        ldy #0
-       lda SAVE_BUF,y
        sta unlocked,y
        iny
        dex
        bne -
        lda #1
        sta save_ok
_none   rts
        .cerror SAVE_SIZE > 255

; Η συσκευή: εκείνη απ' όπου φορτώθηκε το παιχνίδι (8-11), αλλιώς 8.
disc_device
        lda KERNAL_DEV
        cmp #8
        bcc +
        cmp #12
        bcc ++
+       lda #8
+       sta disc_dev
        rts

; Η πρόοδος στη δισκέτα. Η εικόνα μένει όπως είναι όσο γράφει το drive.
save_progress
        sei
        lda #0
        sta VIC_IRQ_MASK
        lda #$ff
        sta VIC_IRQ
        sta SID+4               ; (σιγή στις φωνές)
        lda #0
        sta SID+4
        sta SID+11
        sta SID+18
        lda #$36                ; KERNAL μέσα
        sta $01
        lda #0
        jsr SETMSG
        ; S0:LIQUID.SAV στο κανάλι εντολών (OPEN 15,dev,15,"S0:...")
        lda #scratch_len
        ldx #<scratch_cmd
        ldy #>scratch_cmd
        jsr SETNAM
        lda #15
        ldx disc_dev
        ldy #15
        jsr SETLFS
        jsr OPEN
        lda #15
        jsr CLOSE
        jsr CLRCHN
        ; SAVE
        lda #name_len
        ldx #<save_name
        ldy #>save_name
        jsr SETNAM
        lda #1
        ldx disc_dev
        ldy #0
        jsr SETLFS
        lda #<unlocked
        sta ptr0
        lda #>unlocked
        sta ptr0+1
        lda #ptr0
        ldx #<save_end
        ldy #>save_end
        jsr SAVE
        lda #0
        bcs +
        lda #1
+       sta save_ok
        sei
        lda #$35                ; KERNAL έξω
        sta $01
        lda #$7f
        sta CIA1_ICR
        lda CIA1_ICR
        jsr irq_init
        cli
        rts

disc_dev        .byte 8
save_name       .text "LIQUID.SAV"
name_len        = * - save_name
scratch_cmd     .text "S0:LIQUID.SAV"
scratch_len     = * - scratch_cmd
