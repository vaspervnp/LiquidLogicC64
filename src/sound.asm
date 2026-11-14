; sound.asm — ο SID: εφέ (φωνή 2), γουργουρητό της μετάγγισης (φωνή 1, στο
; παιχνίδι) και η μουσική του τίτλου/μενού (φωνή 1 μελωδία, φωνή 3 μπάσο):
; οι φωνές A, B, C του AY στον CPC. Δεδομένα: assets/data/sound_data.asm.
;
; Το sound_frame τρέχει από το interrupt του καρέ (hw.asm). Ο κύριος κώδικας
; μόνο αφήνει αιτήματα (play_sfx, pour_plip, music_start/stop). Ο AY έχει
; ένταση ανά κανάλι· ο SID μόνο ADSR: η ένταση κάθε καρέ γίνεται το sustain
; (attack και decay στο ελάχιστο), και μια νότα που δυναμώνει ξαναπατάει το
; gate. Παλμός 50% όπως ο τετραγωνικός του AY, θόρυβος για τον φελλό.

SID_V1          = $d400
WAVE_PULSE      = $40
WAVE_NOISE      = $80
PLIP_LOUD       = 12

sound_init
        ldx #$18
        lda #0
-       sta SID,x
        dex
        bpl -
        ldx #14                 ; παλμός 50% και ADSR στις τρεις φωνές
-       lda #$00
        sta SID+2,x
        lda #$08
        sta SID+3,x
        lda #$00
        sta SID+5,x
        sta SID+6,x
        txa
        sec
        sbc #7
        tax
        bpl -
        lda #15
        sta SID_VOLUME
        lda #0
        sta sfx_ptr+1
        sta plip_vol
        sta music_on
        sta v_vol
        sta v_vol+1
        sta v_vol+2
        rts

; Εφέ στη φωνή 2 (κόβει ό,τι έπαιζε εκεί). A/Y = sfx_*.
play_sfx
        pha
        lda opt_sfx
        bne +
        pla
        rts
+       pla
        php
        sei
        sta sfx_ptr
        sty sfx_ptr+1
        plp
        rts

; Γουργουρητό: κάθε 4 γραμμές υγρού στον στόχο ένα «πλιπ», που ψηλώνει όσο
; ανεβαίνει η στάθμη. A = γραμμές του στόχου. Κρατάει X.
pour_plip
        tay
        and #3
        bne _r
        tya
        lsr a
        lsr a
        and #15
        sta plip_idx
        lda opt_sfx
        beq _r
        lda #PLIP_LOUD
        sta plip_vol
_r      rts

sound_frame
        inc snd_frame
        ; φωνή 2: εφέ
        lda sfx_ptr+1
        beq _silent
        sta irq_p0+1
        lda sfx_ptr
        sta irq_p0
        ldy #2
        lda (irq_p0),y
        cmp #$ff
        bne _play
        lda #0
        sta sfx_ptr+1
_silent ldx #7
        lda #0
        jsr voice_off
        jmp _mus
_play   pha
        ldy #0
        lda (irq_p0),y
        sta SID+7
        iny
        lda (irq_p0),y
        sta SID+8
        lda sfx_ptr
        clc
        adc #3
        sta sfx_ptr
        bcc +
        inc sfx_ptr+1
+       pla
        ldx #7
        jsr voice_vol
_mus    lda music_on
        bne music_frame
        ; φωνή 1: γουργουρητό· 3 σιωπηλή
        ldx plip_idx
        lda plip_lo,x
        sta SID+0
        lda plip_hi,x
        sta SID+1
        lda plip_vol
        ldx #0
        jsr voice_vol
        lda plip_vol
        sec
        sbc #2
        bcs +
        lda #0
+       sta plip_vol
        ldx #14
        jmp voice_off

; Ένταση A (bit 7: θόρυβος) στη φωνή X (0, 7, 14). 0 = σιγή.
voice_vol
        and #$8f
        beq voice_off
        sta tmp_sv
        and #15
        asl a
        asl a
        asl a
        asl a
        sta SID+6,x             ; sustain = ένταση, release γρήγορο
        lda #WAVE_PULSE
        bit tmp_sv
        bpl +
        lda #WAVE_NOISE
+       sta tmp_sw
        txa                     ; X -> 0, 1, 2
        ldy #0
        cpx #7
        bcc +
        iny
        cpx #14
        bcc +
        iny
+       lda tmp_sv
        cmp v_vol,y
        sta v_vol,y
        beq _hold
        bcc _hold
        lda tmp_sw              ; δυναμώνει: gate από την αρχή
        sta SID+4,x
_hold   lda tmp_sw
        ora #1
        sta SID+4,x
        rts

; Σιγή στη φωνή X.
voice_off
        lda #0
        sta SID+4,x
        txa
        ldy #0
        cpx #7
        bcc +
        iny
        cpx #14
        bcc +
        iny
+       lda #0
        sta v_vol,y
        rts

tmp_sv  .byte 0
tmp_sw  .byte 0
v_vol   .byte 0,0,0

;------------------------------------------------------------------
; Μουσική: δύο φωνές (1 μελωδία, 3 μπάσο), νότες που σβήνουν σιγά.
MC_PTR          = 0             ; φωνή μουσικής (MC_SIZE bytes)
MC_CNT          = 2
MC_VOL          = 3
MC_START        = 4
MC_REG          = 6             ; φωνή του SID (0 / 14)
MC_SIZE         = 8

music_start
        lda opt_music
        beq _r
        lda music_on
        bne _r
        ldx #2*MC_SIZE-1        ; (με music_on = 0 το interrupt δεν τα διαβάζει)
-       lda music_init,x
        sta mus_a,x
        dex
        bpl -
        lda #1
        sta music_on
_r      rts

music_init
        .word music_a
        .byte 1,0
        .word music_a
        .byte 0,0
        .word music_c
        .byte 1,0
        .word music_c
        .byte 14,0

mus_a   .fill MC_SIZE
mus_c   .fill MC_SIZE

; Ο κύριος κώδικας δεν γράφει ποτέ στον SID (το κάνει μόνο το interrupt):
; με music_on = 0 το sound_frame βάζει το γουργουρητό στη φωνή 1 και σιγή
; στην 3.
music_stop
        lda #0
        sta music_on
        rts

music_frame
        ldx #0
        jsr mus_channel
        ldx #MC_SIZE
mus_channel
        dec mus_a+MC_CNT,x
        bne _env
        lda mus_a+MC_PTR,x
        sta irq_p1
        lda mus_a+MC_PTR+1,x
        sta irq_p1+1
        ldy #0
        lda (irq_p1),y
        cmp #$ff
        bne _note
        lda mus_a+MC_START,x    ; από την αρχή
        sta irq_p1
        lda mus_a+MC_START+1,x
        sta irq_p1+1
        lda (irq_p1),y
_note   pha
        iny
        lda (irq_p1),y          ; καρέ
        sta mus_a+MC_CNT,x
        lda irq_p1
        clc
        adc #2
        sta mus_a+MC_PTR,x
        lda irq_p1+1
        adc #0
        sta mus_a+MC_PTR+1,x
        lda #0
        sta mus_a+MC_VOL,x
        pla
        beq _vol                ; παύση
        tay
        stx tmp_mx
        lda mus_a+MC_REG,x
        tax
        lda note_lo,y
        sta SID+0,x
        lda note_hi,y
        sta SID+1,x
        ldx tmp_mx
        lda #13
        sta mus_a+MC_VOL,x
        jmp _vol
_env    lda snd_frame           ; σβήνει ως το 6, ένα βήμα ανά 4 καρέ
        and #3
        bne _vol
        lda mus_a+MC_VOL,x
        cmp #7
        bcc _vol
        dec mus_a+MC_VOL,x
_vol    stx tmp_mx
        lda mus_a+MC_VOL,x
        pha
        lda mus_a+MC_REG,x
        tax
        pla
        jsr voice_vol
        ldx tmp_mx
        rts

tmp_mx  .byte 0
