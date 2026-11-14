; main.asm — Liquid Logic, Commodore 64 (PAL)
;
; Η έκδοση C64 του παιχνιδιού του Amstrad CPC (../LiquidLogicCPC): ίδιοι
; κανόνες, ίδιες 100 πίστες, ίδια φυσική του πίδακα, καρέ προς καρέ. Τα
; αρχεία src/*.asm αντιστοιχούν σε εκείνα του CPC, ρουτίνα προς ρουτίνα, με τα
; ίδια ονόματα (τα tests διαβάζουν τις μεταβλητές με το όνομά τους).
;
; Βελάκια/joystick = κέρσορας, SPACE/fire = επιλογή του μπουκαλιού από το
; οποίο αδειάζει (σηκώνεται) και μετά εκείνου στο οποίο γεμίζει. RUN/STOP ή
; ← = ESC, U = undo, R = η πίστα από την αρχή.
;
; Μνήμη ($01 = $35: I/O μέσα, BASIC και KERNAL έξω· το KERNAL μπαίνει μόνο
; για τη δισκέτα):
;   $0002-$007f  zero page
;   $0400-$07bf  σωματίδια (πίνακες των 64) και οι δύο λίστες XOR
;   $0801-$bfff  BASIC stub, κώδικας, δεδομένα, πίστες, μεταβλητές
;   $c000-$c2bf  sprites: η πηγή στην πτήση (2 x 4), ο πίδακας (2 x 3), κέρσορας
;   $c2c0-$cbff  BSS: πίστα, μπουκάλια, buffers (και μετά τον κώδικα: undo)
;   $cc00-$cfe7  screen RAM (χρώματα %01/%10 του bitmap), pointers στο $cff8
;   $d800-$dbe7  color RAM (χρώμα %11)
;   $e000-$ff3f  multicolor bitmap 160 x 200 (κάτω από το KERNAL)
;   $fffa-$ffff  vectors (NMI, IRQ: ο δικός μας handler)

        .include "hw.inc"

; ---------------------------------------------------------------------------
; Zero page
; ---------------------------------------------------------------------------
        .virtual $02
ptr0    .word ?                 ; γενικοί δείκτες
ptr1    .word ?
ptr2    .word ?
ptr3    .word ?
bptr    .word ?                 ; το μπουκάλι (το IX του CPC)
dptr    .word ?                 ; ο στόχος (το IY του CPC)
scr     .word ?                 ; bitmap
vram    .word ?                 ; screen RAM
cram    .word ?                 ; color RAM
tp      .word ?                 ; bottle_tmpl / imask της γραμμής
mp      .word ?
tmp0    .byte ?
tmp1    .byte ?
tmp2    .byte ?
tmp3    .byte ?
tmp4    .byte ?
tmp5    .byte ?
tmp6    .byte ?
tmp7    .byte ?
buf0    .byte ?                 ; τα 4 bytes μιας γραμμής του μπουκαλιού
buf1    .byte ?
buf2    .byte ?
buf3    .byte ?
irq_p0  .word ?                 ; δείκτης του ήχου (μόνο στο interrupt)
irq_p1  .word ?
pc_cur  .byte ?                 ; part_update: τρέχον σωματίδιο
pc_x    .byte ?                 ; x, y (ακέραια) του σωματιδίου
pc_y    .byte ?
pc_st   .byte ?
pc_vyh  .byte ?
zp_end
        .endv
        .cerror zp_end > $80, "zero page overflow"

; ---------------------------------------------------------------------------
; Buffers χωρίς αρχική τιμή (BSS)
; ---------------------------------------------------------------------------
MAX_PART        = 64
        .virtual $0400
p_st    .fill MAX_PART          ; σωματίδια: κατάσταση (1 πτήση, 2 στο B, 3 πιτσίλισμα)
p_vyl   .fill MAX_PART          ; vy 8.8
p_vyh   .fill MAX_PART
p_yl    .fill MAX_PART          ; y 8.8
p_yh    .fill MAX_PART
p_vxl   .fill MAX_PART          ; vx 8.8
p_vxh   .fill MAX_PART
p_xl    .fill MAX_PART          ; x 8.8 (pixels 0-159)
p_xh    .fill MAX_PART
dl_lo   .fill 2*MAX_PART        ; δύο λίστες XOR (dlist: σχεδιασμένη, plist: νέα)
dl_hi   .fill 2*MAX_PART
dl_val  .fill 2*MAX_PART
bss0_end
        .endv
        .cerror bss0_end > $07f8, "BSS at $0400 overflows"

SPR_BASE        = $c000         ; sprite blocks (VIC bank 3)
SPR_BLK_SRC     = 0             ; 0-3 η πηγή: πάνω αριστερά, δεξιά, κάτω αριστερά, δεξιά
SPR_BLK_JET     = 4             ; 4-6 και 7-9: ο πίδακας, δύο buffers
SPR_BLK_CURSOR  = 10
SCREEN          = $cc00
SPR_PTRS        = SCREEN+$3f8
BITMAP          = $e000

        .virtual $c2c0
num_buf    .fill 4              ; (στην αρχή: num_buf+0..3 στην ίδια σελίδα)
level_buf  .fill LEVEL_MAX      ; η τρέχουσα πίστα
bottles    .fill MAX_BOTTLES*BOT_SIZE
keymap     .fill 10             ; 8 στήλες του πληκτρολογίου, joystick 2, 1
keymap_old .fill 10
keyprev    .fill 10
relax_cols .fill 12
relax_pool .fill 32
src_pens   .fill MAX_CAP        ; η πηγή όπως φαίνεται στην πτήση (pens)
t_fill     .fill 9              ; ο στόχος: pattern του χρώματος της ροής ανά σειρά cells
row_col    .fill 8              ; render_row: χρώμα ανά γραμμή
ev_line    .fill 16             ; raster: γεγονότα του επόμενου καρέ
ev_bord    .fill 16
ev_spr     .fill 16
ec_line    .fill 16             ; ... και του τρέχοντος (τα διαβάζει το interrupt)
ec_bord    .fill 16
ec_spr     .fill 16
sh_spr_x   .fill 8              ; σκιές των registers των sprites
sh_spr_y   .fill 8
sh_spr_col .fill 8
sh_spr_ptr .fill 8
card_bot   .fill BOT_SIZE
toast_buf  .fill 40
num5_buf   .fill 6
bss1_end
        .endv
        .cerror bss1_end > SCREEN, "BSS at $c2c0 overflows"

; ---------------------------------------------------------------------------
; BASIC stub: 2026 SYS <start>
; ---------------------------------------------------------------------------
        * = $0801
        .word (+), 2026
        .null $9e, format("%d", start)
+       .word 0

start
        sei
        cld
        ldx #$ff
        txs
        lda #$36                ; BASIC έξω, το KERNAL ακόμα μέσα (load_progress)
        sta $01
        jsr load_progress       ; LIQUID.SAV από τη δισκέτα, αν υπάρχει
        sei
        lda #$7f                ; χωρίς interrupts του CIA: μόνο το raster
        sta CIA1_ICR
        sta CIA2_ICR
        lda CIA1_ICR
        lda CIA2_ICR
        lda #0
        sta VIC_IRQ_MASK
        sta VIC_SPR_ENA
        lda #$35                ; KERNAL έξω, I/O μέσα
        sta $01
        lda #<nmi
        sta NMI_VEC
        lda #>nmi
        sta NMI_VEC+1
        lda test_mode           ; (τα tests το γράφουν πριν από την πρώτη εντολή)
        sta test_on
        jsr apply_settings      ; πλήκτρα και θέμα από το LIQUID.SAV
        jsr video_init
        jsr sound_init
        lda $d012               ; seed (≠ 0)
        eor rnd_seed
        ora #1
        sta rnd_seed
        jsr irq_init            ; από εδώ ο ήχος παίζει από το interrupt
        cli
        jsr title_start

main_loop
        jsr wait_frame
        inc frames_main
        jsr part_erase
        jsr liquid_sync
        jsr timer_tick
        jsr part_draw
        jsr read_input
        jsr mode_frame
        jsr fly_events          ; raster: τα χρώματα της πηγής για το επόμενο καρέ
frame_done
        jmp main_loop

nmi     rti                     ; το RESTORE δεν κάνει τίποτα

        .include "hw.asm"
        .include "screen.asm"
        .include "bottles.asm"
        .include "sprites.asm"
        .include "particles.asm"
        .include "pour.asm"
        .include "game.asm"
        .include "sound.asm"
        .include "disc.asm"
        .include "ui.asm"
        .include "relax.asm"
        .include "options.asm"
        .include "help.asm"
        .include "stats.asm"
        .include "ending.asm"
        .include "gfx.asm"
        .include "physics.asm"
        .include "sound_data.asm"
        .include "levels.asm"

;------------------------------------------------------------------
; Μεταβλητές
test_mode       .byte 0         ; τα tests: 1 = πλήκτρα από το test_keys
test_on         .byte 0
test_keys       .fill 10,$ff    ; ό,τι θα έδινε το read_keys (0 = πατημένο)
rnd_seed        .word $ace1
input           .byte 0         ; IN_*, με αυτή τη σειρά
input_new       .byte 0
input2          .byte 0         ; IN2_*, με αυτή τη σειρά
input2_new      .byte 0
txt_pen         .byte 0
txt_slot        .byte 0
tmp_pen         .byte 0
row_n           .byte 0
tmp_row         .byte 0
tmp_y           .byte 0
tmp_x0          .byte 0
tmp_ys          .byte 0
tmp_t           .byte 0

sfx_ptr         .word 0         ; ήχος (sound.asm)
sfx_vol         .byte 0
sfx_req         .word 0         ; αίτημα του κύριου κώδικα (0 = κανένα)
plip_idx        .byte 0
plip_vol        .byte 0
music_on        .byte 0
snd_frame       .byte 0
frames_int      .byte 0         ; καρέ: από το interrupt του καρέ
frames_main     .byte 0         ; γύροι του κύριου βρόχου (διαφορά = late frames)
frame_flag      .byte 0
mode            .byte 0         ; MODE_*: τίτλος, επιλογή, παιχνίδι
sel_level       .byte 0
; LIQUID.SAV: από το unlocked ως το save_end, συνεχόμενα.
unlocked        .byte 1         ; πόσες πίστες παίζονται
stars           .fill MAX_LEVELS,0      ; καλύτερα αστέρια ανά πίστα
opt_music       .byte 1         ; επιλογές (options.asm)
opt_sfx         .byte 1
opt_speed       .byte 0         ; 1 = γρήγορη πτήση
opt_theme       .byte 0         ; 1 = NEON (theme_open: μετά την πίστα 100)
theme_open      .byte 0
opt_keys        .byte 4,%00000100       ; αριστερά (J), δεξιά (L), πάνω (I),
                .byte 5,%00000100       ; κάτω (K), fire (SPACE):
                .byte 4,%00000010       ; στήλη του matrix, bit της γραμμής
                .byte 4,%00100000
                .byte 7,%00010000
stat_pours      .word 0         ; στατιστικά (ως 65535)
stat_relax      .word 0
medals          .word 0         ; MD_* (stats.asm)
seen_cards      .word 0         ; CD_*: κάρτες ειδικών τύπων που έχουν δειχτεί
last_seed       .word 2026
save_end
undo_used       .byte 0         ; στην τρέχουσα πίστα
relax_seed      .byte 0         ; 1 = «Χαλάρωση» με seed (last_seed)
relax_num       .byte 0         ; αριθμός πίστας του seed (από 1)
save_dirty      .byte 0         ; 1 = η πρόοδος άλλαξε (award_stars)
save_ok         .byte 0         ; 1 = το τελευταίο save πέτυχε
tmp_stars       .byte 0
paused_timer    .byte 0
level           .byte 0         ; πίστα (από 0)
relax           .byte 0         ; 1 = «Χαλάρωση»: τυχαίες πίστες (relax.asm)
relax_new       .byte 0         ; 1 = το level_start φτιάχνει καινούργια
relax_ncol      .byte 0
moves           .byte 0
undo_left       .byte 0
undo_sp         .byte 0
undo_ptr        .word 0
extra_used      .byte 0
hud_msg         .byte 0         ; 1 = μήνυμα στη θέση του HUD
timer_on        .byte 0
time_up         .byte 0
time_frames     .byte 0
time_left       .word 0         ; δευτερόλεπτα
level_flags     .byte 0         ; header της πίστας (level_setup)
level_moves     .byte 0         ; με αυτή τη σειρά
level_timer     .byte 0
level_par       .byte 0

nbottles        .byte 0
level_cap       .byte 0
nrows           .byte 0
row_start       .byte 0,0
row_len         .byte 0,0

state           .byte 0
shake_cnt       .byte 0         ; καρέ που μένουν στο χοροπηδητό
shake_bot       .byte 0
cursor          .byte 0
sel_src         .byte 0
sel_dst         .byte 0

pour_src        .word 0         ; τα δύο μπουκάλια (bptr, dptr)
pour_dst        .word 0
pour_pen        .byte 0
pour_space      .byte 0
pour_n          .byte 0
pour_phase      .byte 0         ; 0 πτήση ως τον στόχο, 1 πίδακας, 2 επιστροφή
hover_x         .byte 0         ; δίπλα στον στόχο (cell, γραμμή)
hover_y         .byte 0
hover_tilt      .byte 0
home_x          .byte 0         ; η θέση της πηγής (cell, γραμμή)
home_y          .byte 0
fly_x           .word 0         ; 8.8 pixels: τρέχουσα θέση στην πτήση
fly_y           .word 0         ; 8.8 γραμμές
fly_sx          .word 0         ; βήματα 8.8
fly_sy          .word 0
fly_cnt         .byte 0
fly_on          .byte 0         ; 1 = η πηγή είναι sprites
fly_tilt        .byte 0         ; γέρσιμο του sprite: 1 δεξιά, $ff αριστερά, 0
fly_shift       .byte 0         ; pixels από την αριστερή άκρη των sprites
src_n           .byte 0         ; στρώσεις της πηγής στην πτήση (src_pens)
src_lh          .byte 0
src_drop        .byte 0         ; σταγονόμετρο (βολβός)
src_lines       .byte 0         ; γραμμές υγρού (λογικές)
src_final       .byte 0
src_acc         .byte 0
dst_lines       .byte 0
dst_target      .byte 0
dst_acc         .byte 0
dst_add         .byte 0
dst_thresh      .byte 0
dst_top         .byte 0         ; γραμμή οθόνης του πάνω μέρους του B
dst_bottom      .byte 0         ; γραμμή οθόνης του πάτου του υγρού στο B
dst_surf        .byte 0
dst_entry       .byte 0
dst_xl          .byte 0         ; εσωτερικό του σώματος (pixels)
dst_xr          .byte 0
dst_nl          .byte 0         ; εσωτερικό του λαιμού
dst_nr          .byte 0
emit_left       .word 0
emit_x          .word 0
emit_y          .word 0
base_vx         .word 0
base_vy         .word 0
p_alive         .byte 0
src_shown       .byte 0         ; γραμμές υγρού που φαίνονται
dst_shown       .byte 0
dlist           .byte 0         ; 0 / MAX_PART: η σχεδιασμένη λίστα (για σβήσιμο)
dlist_n         .byte 0
plist           .byte MAX_PART  ; η εκκρεμής λίστα (για σχεδίαση)
plist_n         .byte 0
upd_left        .byte 0
jet_x0          .byte 0         ; ο πίδακας στα sprites: πάνω αριστερή γωνία
jet_y0          .byte 0
jet_buf         .byte 0         ; 0 / 1: ο buffer που γράφει η φυσική
jet_on          .byte 0
jet_flip        .byte 0         ; 1 = νέος buffer έτοιμος για το interrupt
ev_n            .byte 0         ; raster: γεγονότα (επόμενο καρέ)
ev_ready        .byte 0
ec_n            .byte 0         ; ... τρέχον καρέ
ec_i            .byte 0
sh_spr_ena      .byte 0
sh_spr_msb      .byte 0
bord_col        .byte 0         ; χρώμα του border στο πάνω μέρος
glass_col       .byte CLASSIC_GLASS

code_end
        .virtual code_end
undo_stack .fill UNDO_MAX*SNAP_SIZE     ; στιγμιότυπα του undo
sparks     .fill SPARK_N*SP_SIZE        ; τα πυροτεχνήματα του τέλους
bss2_end
        .endv
        .cerror bss2_end > SPR_BASE, "code overflows into the sprites"
