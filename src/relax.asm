; relax.asm — «Χαλάρωση»: ατελείωτες τυχαίες πίστες, χωρίς αστέρια και
; αποθήκευση. 5-8 χρώματα (τυχαία από τα 12), 4 στρώσεις, δύο άδεια
; μπουκάλια και το έξτρα (E). Ανακατεύονται όλες οι στρώσεις μαζί· όσες
; ανακατωσιές αφήνουν μπουκάλι ήδη μονόχρωμο απορρίπτονται. Ίδιος αλγόριθμος
; και ίδιοι ψευδοτυχαίοι αριθμοί με τον CPC: ίδιο seed, ίδιες πίστες.

; Γράφει μια καινούργια πίστα στο level_buf (μορφή levels.asm). Με seed
; (relax_seed): η πίστα relax_num του last_seed, με δικό της seed στο rnd (το
; κανονικό συνεχίζει μετά όπως ήταν).
relax_gen
        lda relax_seed
        beq relax_make
        lda rnd_seed
        pha
        lda rnd_seed+1
        pha
        inc relax_num
        lda last_seed+1         ; seed + αριθμός * 257 (ίδιος αριθμός: άλλο
        clc                     ; seed, άλλο αποτέλεσμα), ποτέ 0
        adc relax_num
        sta rnd_seed+1
        lda last_seed
        clc
        adc relax_num
        sta rnd_seed
        ora rnd_seed+1
        bne +
        inc rnd_seed
+       ldx #8                  ; ανακάτεμα του seed
-       jsr rnd
        dex
        bne -
        jsr relax_make
        pla
        sta rnd_seed+1
        pla
        sta rnd_seed
        rts

relax_make
        ldx #11                 ; τα χρώματα: 12 pens, ανακατεμένα
-       txa
        clc
        adc #PEN_LIQUID
        sta relax_cols,x
        dex
        bpl -
        lda #<relax_cols
        ldy #>relax_cols
        ldx #12
        jsr shuffle
        jsr rnd
        and #3
        clc
        adc #5
        sta relax_ncol
        ldx #0                  ; κάθε χρώμα 4 φορές
        ldy #0
-       lda relax_cols,x
        sta relax_pool,y
        sta relax_pool+1,y
        sta relax_pool+2,y
        sta relax_pool+3,y
        iny
        iny
        iny
        iny
        inx
        cpx relax_ncol
        bne -
_again  lda relax_ncol
        asl a
        asl a
        tax
        lda #<relax_pool
        ldy #>relax_pool
        jsr shuffle
        ldy #0                  ; κανένα μπουκάλι μονόχρωμο από την αρχή
        ldx relax_ncol
-       lda relax_pool,y
        cmp relax_pool+1,y
        bne +
        cmp relax_pool+2,y
        bne +
        cmp relax_pool+3,y
        beq _again
+       iny
        iny
        iny
        iny
        dex
        bne -

        ldy #0                  ; header: flags, μπουκάλια, cap, όριο, χρόνος, par
        lda #LF_EXTRA
        jsr _put
        lda relax_ncol
        clc
        adc #2
        jsr _put
        lda #4
        jsr _put
        lda #0
        jsr _put
        jsr _put
        jsr _put
        ldx #0                  ; στρώσεις
_bot    jsr _head               ; bflags (cap), πάγος, λουκέτο, πλήθος
        lda #4
        jsr _put
        lda relax_pool,x
        jsr _put
        lda relax_pool+1,x
        jsr _put
        lda relax_pool+2,x
        jsr _put
        lda relax_pool+3,x
        jsr _put
        inx
        inx
        inx
        inx
        txa
        lsr a
        lsr a
        cmp relax_ncol
        bne _bot
        jsr _head               ; και δύο άδεια
        lda #0
        jsr _put
        jsr _head
        lda #0
_put    sta level_buf,y
        iny
        rts
_head   lda #4
        jsr _put
        lda #0
        jsr _put
        jmp _put

; Ανακάτεμα Fisher-Yates. in: A/Y = πίνακας, X = μήκος (2..255).
shuffle
        sta ptr3
        sty ptr3+1
        dex
        stx tmp4                ; i = μήκος - 1 .. 1
_i      jsr rnd
        ldx tmp4
        inx
        stx tmp5
-       sec
        sbc tmp5
        bcs -
        adc tmp5
        sta tmp6                ; j
        tay                     ; a[i] <-> a[j]
        lda (ptr3),y
        pha
        ldy tmp4
        lda (ptr3),y
        ldy tmp6
        sta (ptr3),y
        pla
        ldy tmp4
        sta (ptr3),y
        dec tmp4
        bne _i
        rts
