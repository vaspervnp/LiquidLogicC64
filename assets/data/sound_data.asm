; sound_data.asm — ΠΑΡΑΓΕΤΑΙ από το assets/src/make_sound.py, μην το αλλάζεις με το χέρι

MUSIC_STEP      = 7

; συχνότητες του SID για τις νότες 0..72 (0 = παύση, 1 = C1)
note_lo .byte $00,$2D,$4E,$71,$96,$BE,$E7,$14,$42,$74,$A9,$E0,$1B,$5A,$9C,$E2,$2D,$7B,$CF,$27,$85,$E8,$51,$C1,$37,$B4,$38,$C4,$59,$F7,$9D,$4E,$0A,$D0,$A2,$81,$6D,$67,$70,$89,$B2,$ED,$3B,$9C,$13,$A0,$45,$02,$DA,$CE,$E0,$11,$64,$DA,$76,$39,$26,$40,$89,$04,$B4,$9C,$C0,$23,$C8,$B4,$EB,$72,$4C,$80,$12,$08,$68
note_hi .byte $00,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08,$08,$09,$09,$0A,$0A,$0B,$0C,$0D,$0D,$0E,$0F,$10,$11,$12,$13,$14,$15,$17,$18,$1A,$1B,$1D,$1F,$20,$22,$24,$27,$29,$2B,$2E,$31,$34,$37,$3A,$3E,$41,$45,$49,$4E,$52,$57,$5C,$62,$68,$6E,$75,$7C,$83
; το γουργουρητό: ανά 4 γραμμές της στάθμης (περίοδος AY 320 - 4 x γραμμές)
plip_lo .byte $FE,$AD,$6F,$49,$3D,$52,$8F,$FD,$A7,$9F,$FC,$DF,$7B,$1E,$4E,$F7
plip_hi .byte $0C,$0D,$0E,$0F,$10,$11,$12,$13,$15,$17,$19,$1C,$20,$25,$2B,$33

sfx_select
        .byte $E9,$27,$0C
        .byte $49,$32,$0B
        .byte $5B,$3F,$09
        .byte $D2,$4F,$08
        .byte 0,0,$ff

sfx_cancel
        .byte $DE,$3B,$0A
        .byte $84,$2F,$08
        .byte $B7,$25,$07
        .byte $EF,$1D,$05
        .byte 0,0,$ff

sfx_error
        .byte $EB,$06,$0D
        .byte $51,$07,$0C
        .byte $EB,$06,$0B
        .byte $51,$07,$0A
        .byte $EB,$06,$09
        .byte $51,$07,$08
        .byte $EB,$06,$07
        .byte $51,$07,$06
        .byte $EB,$06,$05
        .byte $51,$07,$04
        .byte 0,0,$ff

sfx_cork
        .byte $FF,$FF,$8E
        .byte $FF,$FF,$8B
        .byte $20,$5D,$0C
        .byte $2A,$63,$0A
        .byte $98,$69,$08
        .byte $71,$70,$06
        .byte $BB,$77,$04
        .byte 0,0,$ff

sfx_win
        .byte $CE,$22,$0D
        .byte $CE,$22,$0C
        .byte $CE,$22,$0B
        .byte $CE,$22,$0A
        .byte $CE,$22,$09
        .byte $DA,$2B,$0D
        .byte $DA,$2B,$0C
        .byte $DA,$2B,$0B
        .byte $DA,$2B,$0A
        .byte $DA,$2B,$09
        .byte $26,$34,$0D
        .byte $26,$34,$0C
        .byte $26,$34,$0B
        .byte $26,$34,$0A
        .byte $26,$34,$09
        .byte $9C,$45,$0D
        .byte $9C,$45,$0C
        .byte $9C,$45,$0B
        .byte $9C,$45,$0A
        .byte $9C,$45,$09
        .byte $B4,$57,$0D
        .byte $B4,$57,$0C
        .byte $B4,$57,$0B
        .byte $B4,$57,$0A
        .byte $B4,$57,$09
        .byte $B4,$57,$08
        .byte $B4,$57,$07
        .byte $B4,$57,$06
        .byte $B4,$57,$05
        .byte $B4,$57,$04
        .byte $B4,$57,$03
        .byte $B4,$57,$02
        .byte 0,0,$ff

sfx_chime
        .byte $26,$34,$0C
        .byte $26,$34,$0A
        .byte $26,$34,$08
        .byte $26,$34,$06
        .byte $26,$34,$04
        .byte $26,$34,$02
        .byte $23,$4E,$0C
        .byte $23,$4E,$0A
        .byte $23,$4E,$08
        .byte $23,$4E,$06
        .byte $23,$4E,$04
        .byte $23,$4E,$02
        .byte 0,0,$ff

sfx_undo
        .byte $84,$42,$0B
        .byte $EF,$37,$0A
        .byte $09,$2F,$08
        .byte $8D,$27,$07
        .byte $42,$21,$06
        .byte 0,0,$ff

sfx_extra
        .byte $F5,$13,$0D
        .byte $8C,$16,$0C
        .byte $79,$19,$0C
        .byte $C8,$1C,$0B
        .byte $84,$20,$0B
        .byte $BD,$24,$0A
        .byte $82,$29,$0A
        .byte $E6,$2E,$09
        .byte $FC,$34,$09
        .byte $DE,$3B,$08
        .byte 0,0,$ff

sfx_timeup
        .byte $ED,$15,$0D
        .byte $ED,$15,$0C
        .byte $ED,$15,$0B
        .byte $ED,$15,$0A
        .byte $ED,$15,$09
        .byte $ED,$15,$08
        .byte $ED,$15,$07
        .byte $89,$13,$0D
        .byte $89,$13,$0C
        .byte $89,$13,$0B
        .byte $89,$13,$0A
        .byte $89,$13,$09
        .byte $89,$13,$08
        .byte $89,$13,$07
        .byte $67,$11,$0D
        .byte $67,$11,$0C
        .byte $67,$11,$0B
        .byte $67,$11,$0A
        .byte $67,$11,$09
        .byte $67,$11,$08
        .byte $67,$11,$07
        .byte $A2,$0E,$0D
        .byte $A2,$0E,$0C
        .byte $A2,$0E,$0B
        .byte $A2,$0E,$0A
        .byte $A2,$0E,$09
        .byte $A2,$0E,$08
        .byte $A2,$0E,$07
        .byte 0,0,$ff

sfx_tick
        .byte $09,$85,$09
        .byte $09,$85,$04
        .byte 0,0,$ff

; μελωδία του τίτλου (φωνή 1): νότα, καρέ
music_a
        .byte 53,7    ; E5
        .byte 56,7    ; G5
        .byte 58,14    ; A5
        .byte 56,7    ; G5
        .byte 53,7    ; E5
        .byte 51,14    ; D5
        .byte 49,7    ; C5
        .byte 51,7    ; D5
        .byte 53,14    ; E5
        .byte 46,28    ; A4
        .byte 49,7    ; C5
        .byte 53,7    ; E5
        .byte 56,14    ; G5
        .byte 58,7    ; A5
        .byte 56,7    ; G5
        .byte 53,14    ; E5
        .byte 51,7    ; D5
        .byte 49,7    ; C5
        .byte 51,14    ; D5
        .byte 53,28    ; E5
        .byte 58,7    ; A5
        .byte 56,7    ; G5
        .byte 53,14    ; E5
        .byte 56,7    ; G5
        .byte 53,7    ; E5
        .byte 51,14    ; D5
        .byte 49,7    ; C5
        .byte 51,7    ; D5
        .byte 53,14    ; E5
        .byte 44,28    ; G4
        .byte 46,7    ; A4
        .byte 49,7    ; C5
        .byte 53,14    ; E5
        .byte 51,7    ; D5
        .byte 49,7    ; C5
        .byte 48,14    ; B4
        .byte 49,14    ; C5
        .byte 48,14    ; B4
        .byte 46,28    ; A4
        .byte $ff

; μπάσο (φωνή 3)
music_c
        .byte 22,28    ; A2
        .byte 18,28    ; F2
        .byte 25,28    ; C3
        .byte 20,28    ; G2
        .byte 22,28    ; A2
        .byte 18,28    ; F2
        .byte 20,28    ; G2
        .byte 25,28    ; C3
        .byte 18,28    ; F2
        .byte 20,28    ; G2
        .byte 25,28    ; C3
        .byte 22,28    ; A2
        .byte 18,28    ; F2
        .byte 20,28    ; G2
        .byte 17,28    ; E2
        .byte 22,28    ; A2
        .byte $ff
