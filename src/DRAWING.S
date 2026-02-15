
         org   $800
         
         dsk   ../bin/DRAWING#060800
         typ   $06
         cyc
         put   COMMON.S

* The first table is the scanline table which is 192 bytes
* thus there is enough space for a 21 entry jmp table before
* the first table while avoiding cross page access.

         jmp   Initialize_lcl
         jmp   JoyUpdate_lcl
         jmp   Rand_lcl
         jmp   DrawChar_lcl
         jmp   DrawStr_lcl
         jmp   DrawSprite_l
         jmp   DrawPoint_lcl
         jmp   DrawRect_lcl
         jmp   DrawBlock_lcl
         jmp   DrawDither_lcl
         jmp   DrawHLine_lcl
         jmp   PlaySnd_lcl

         put   SCANLINE_TBL.S   ; 192*2 bytes

* page align.  Should be $a00

         ds    \

         put   XPOS_TABLE.S    ; $200 bytes

         ds    \

FontBase
         put   FONTSRC.S        ; $400 bytes

         ds    \

PDOS_io_buffer                  ; ProDOS I/O buffer: 1K, page aligned
         ds    1024

         ds    \                ; this should result in alignment with $1400

* Initialize all game systems
Initialize_lcl
         jsr   InitializeIO
         jmp   RandInit_lcl

tmp_x    = tmp0
tmp_cnt  = tmp1

* draw the string pointed to by gr_addr_hi, gr_addr_lo
* at gr_xpos (bytes), gr_ypos
DrawStr_lcl
         lda   gr_ypos
         sta   tmp_cnt
         lda   gr_xpos
         sta   tmp_x      ; remember the x position for nl
         lda   gr_addr_hi ; set up the byte fetch
         sta   nextchar+2
         lda   gr_addr_lo
         sta   nextchar+1
nextchar lda   $ffff
         inc   nextchar+1
         bne   :isnull
         inc   nextchar+2
:isnull  cmp   #0         ; done?
         bne   :chknl   
         rts
:chknl   cmp   #1         ; 1=skip a char (no painting)
         beq   :skip
         cmp   #10
         bne   :drawc
         lda   tmp_x      ; newline
         sta   gr_xpos    ; restore x_pos
         lda   tmp_cnt    ; increment y_pos by 8
         clc
         adc   #8
         sta   tmp_cnt
         jmp   nextchar
:drawc   sta   gr_idx
         lda   tmp_cnt    ; DrawChar wipes out gr_ypos, so restore it
         sta   gr_ypos
         jsr   DrawChar_lcl
:skip    inc   gr_xpos    ; one char to the right
         jmp   nextchar

* draw the character gr_idx at gr_xpos (bytes), gr_ypos
* characters from [$00,$7f]
DrawChar_lcl
         lda   #>FontBase
         lsr
         lsr
         sta   fth_text+2
         lda   gr_idx
         sta   fth_text+1
         asl   fth_text+1
         asl   fth_text+1
         rol   fth_text+2
         asl   fth_text+1
         rol   fth_text+2
         ldx   #0
         lda   gr_ypos
         sta   gr_idx
]line    ldy   gr_idx
         lda   ScanlineTblHI,y
         sta   sta_text+2
         lda   ScanlineTblLO,y
         sta   sta_text+1
         ldy   gr_xpos
fth_text lda   FontBase,x
sta_text sta   $ffff,y
         inc   gr_idx
         inx   
         cpx   #8
         bne   ]line
         rts

* 7 offsets to pre-shifted image within a page
mult36   dfb   0*36,1*36,2*36,3*36,4*36,5*36,6*36,7*36

* draw sprite gr_idx at gr_xpos (pixels), gr_ypos
* if gr_idx is Sprite_None, fake draw a sprite, taking roughly
* the same amount of time (slightly faster).
DrawSprite_l
         lda   gr_idx
         cmp   #Sprite_None
         bne   :regular
         ldx   #$B1       ; LDA (ZP),Y
         stx   StoreIns
         lda   #0
         sta   gr_xpos
         sta   gr_ypos
         beq   :go
:regular ldx   #$91       ; STA (ZP),Y
         stx   StoreIns
:go      asl
         clc
         adc   #>SpriteBase    ; the sprites start at SpriteBase
         sta   fetch_data_hi
         inc
         sta   fetch_mask_hi
         ldx   gr_xpos
         lda   XPosByte,x
         sta   tmp_x
         lda   XPosShift,x
         tax
         lda   mult36,x
         sta   fetch_data_lo
         sta   fetch_mask_lo
         ldx   #0

]line    ldy   gr_ypos
         lda   ScanlineTblHI,y
         sta   HI
         lda   ScanlineTblLO,y
         sta   LO
         lda   #3
         sta   tmp_cnt
         ldy   tmp_x

]byte    lda   (LO),y
fth_data and   fetch_mask_lo,x
fth_mask ora   fetch_data_lo,x
StoreIns sta   (LO),y
         iny
         inx
         dec   tmp_cnt
         bne   ]byte

         inc   gr_ypos
         cpx   #12*3
         blt   ]line

         rts

fetch_data_lo = fth_data+1
fetch_data_hi = fth_data+2
fetch_mask_lo = fth_mask+1
fetch_mask_hi = fth_mask+2

* Draw a block of pixels at gr_xpos (bytes), gr_ypos using
* the color index gr_idx.  The block is gr_width bytes wide
* and gr_height lines tall
DrawRect_lcl
         lda   gr_idx
         asl            ; multi color by 2
         tax              
         lda   gr_xpos  ; if gr_xpos is odd, add one to x
         and   #1
         beq   :skip
         inx
:skip    ldy   gr_ypos  ; First scanline
         lda   ScanlineTblHI,y
         sta   HI
         lda   ScanlineTblLO,y
         sta   LO
         lda   gr_width
         sta   tmp_cnt
         ldy   gr_xpos
:byte    lda   colors,x
         sta   (LO),y   
         txa              ; pick a different color byte
         eor   #1
         tax
         iny
         dec   tmp_cnt
         bne   :byte
         inc   gr_ypos
         dec   gr_height
         bne   DrawRect_lcl
         rts

colors   hex   0000
         hex   7f7f
         hex   552A
         hex   2A55
         hex   8080
         hex   ffff
         hex   D5AA
         hex   AAD5

* 1248124  1248124
* 1010101  0101010  55 2A  D5 AA  
* 0101010  1010101  2A 55  AA D5


* Draw a block of pixels at gr_xpos (bytes), gr_ypos from 
* addr: gr_addr_hi, gr_addr_lo.  The first two bytes of 
* the addr is the width in bytes and the height in lines
DrawBlock_lcl
         lda   gr_addr_hi
         sta   BlockFetch+2
         lda   gr_addr_lo
         sta   BlockFetch+1
         jsr   BlockFetch ; first byte is the block width
         sta   gr_width
         jsr   BlockFetch ; second byte is the block height
         sta   gr_height
:line    ldy   gr_ypos  ; start scanline
         lda   ScanlineTblHI,y
         sta   HI
         lda   ScanlineTblLO,y
         sta   LO
         lda   gr_width
         sta   tmp_cnt
         ldy   gr_xpos
:byte    jsr   BlockFetch
         sta   (LO),y
         iny
         dec   tmp_cnt
         bne   :byte
         inc   gr_ypos
         dec   gr_height
         bne   :line
         rts

BlockFetch
         lda   $ffff
         inc   BlockFetch+1
         bne   :skip
         inc   BlockFetch+2
:skip    rts

dither_idx dfb 0
dither_y dfb   0
dither_table              ; a = list(range(32)) random.shuffle(a)
         hex 031a1c1d09131906001f1e101201040e1b080711020c0d17140b050a1618150f

* Same as DrawBlock, except that the image is drawn in 32
* passes with only 1/64 of the image drawn each time.
DrawDither_lcl
         lda   #$1f
         sta   dither_idx
         lda   gr_ypos
         sta   dither_y
:nextd   lda   gr_addr_hi
         sta   BlockFetch+2
         lda   gr_addr_lo
         sta   BlockFetch+1
         jsr   BlockFetch ; first byte is the block width
         sta   gr_width
         jsr   BlockFetch ; second byte is the block height
         sta   gr_height
         lda   dither_y   ; restart at the top again
         sta   gr_ypos
:line    ldy   gr_ypos    ; start scanline
         lda   ScanlineTblHI,y
         sta   HI
         lda   ScanlineTblLO,y
         sta   LO
         lda   gr_width
         sta   tmp_cnt
         ldy   gr_xpos
:byte    jsr   BlockFetch
         pha
         ; if the low order src addr matches the table
         ; then draw, otherwise, later pass
         ldx   dither_idx   
         lda   BlockFetch+1
         and   #$1f       ; only 64 char table
         cmp   dither_table,x
         bne   :nodraw
         pla
         sta   (LO),y
         sec
         bcs   :cont
:nodraw  pla         
:cont    iny
         dec   tmp_cnt
         bne   :byte
         inc   gr_ypos
         dec   gr_height
         bne   :line
         dec   dither_idx ; next dither pass
         bpl   :nextd
         rts

* EOR a "dot" at gr_xpos (pixels), gr_ypos
DrawPoint_lcl
         ldx   gr_xpos
         lda   XPosByte,x      ; draw left column
         sta   tmp_cnt
         lda   XPosShift,x       ; offset into pre-shifted images
         tax

         ldy   gr_ypos          ; First scanline
         lda   ScanlineTblHI,y
         sta   HI
         lda   ScanlineTblLO,y
         sta   LO
         lda   PntLeftByte,x   ; two pre-shifted bytes
         ldy   tmp_cnt
         eor   (LO),y
         sta   (LO),y
         iny
         lda   PntRightByte,x
         eor   (LO),y
         sta   (LO),y

         ldy   gr_ypos          ; Second scanline
         iny
         lda   ScanlineTblHI,y
         sta   HI
         lda   ScanlineTblLO,y
         sta   LO
         lda   PntLeftByte,x   ; two pre-shifted bytes
         ldy   tmp_cnt
         eor   (LO),y
         sta   (LO),y
         iny
         lda   PntRightByte,x
         eor   (LO),y
         sta   (LO),y

         rts

* Star pixel image (4 pixels, repeat for 2 scanlines)
* 1248 124    1248
* 1010 000    0000 - 05 00 
* 0101 000    0000 - 0a 00
* 0010 100    0000 - 14 00
* 0001 010    0000 - 28 00
* 0000 101    0000 - 50 00
* 0000 010    1000 - 20 01
* 0000 001    0100 - 40 02

PntLeftByte
         hex   050a1428502040
PntRightByte
         hex   00000000000102

* gr_idx is the "color" black, white, color
* start=gr_xpos,gr_ypos 
* delta=gr_width 
DrawHLine_lcl
         ldy   gr_ypos
         lda   ScanlineTblHI,y
         sta   HI
         lda   ScanlineTblLO,y
         sta   LO
         lda   gr_idx
         bne   :other

:loop0   ldx   gr_xpos
         lda   XPosByte,x
         tay
         lda   XPosShift,x
         tax
         lda   MaskBak,x
         and   (LO),y
         sta   (LO),y
         cpx   #6
         bne   :next
         iny
         lda   #$fe
         and   (LO),y
         sta   (LO),y
:next    dec   gr_width
         bne   :inc
         rts    
:inc     inc   gr_xpos
         bne   :loop0
         rts

:other   cmp   #2
         beq   :color
         lda   #>MaskCol1
         sta   ColMask+2
         lda   #<MaskCol1
         sta   ColMask+1
         jmp   :loop1
:color   lda   #>MaskCol2
         sta   ColMask+2
         lda   #<MaskCol2
         sta   ColMask+1
:loop1   ldx   gr_xpos
         lda   XPosByte,x
         tay
         lda   XPosShift,x
         tax
         lda   MaskBak,x
         and   (LO),y
ColMask  ora   MaskCol1,x
         sta   (LO),y
         cpx   #6
         bne   :next1
         iny
         lda   #$fe
         and   (LO),y
         ora   #$81
         sta   (LO),y
:next1   dec   gr_width
         bne   :inc1
         rts    
:inc1    inc   gr_xpos
         bne   :loop1
         rts

MaskCol1 hex   83868c98b0e0c0
MaskCol2 hex   82848890a0c080
MaskBak  hex   fcf9f3e7cf9fbf

* White
* 1248 124 8    1248 124 8  col    bak
* 1100 000 1    0000 000 1  83     fc 
* 0110 000 1    0000 000 1  86     f9
* 0011 000 1    0000 000 1  8c     f3
* 0001 100 1    0000 000 1  98     e7
* 0000 110 1    0000 000 1  b0     cf
* 0000 011 1    0000 000 1  e0     9f
* 0000 001 1    1000 000 1  c0 81  bf fe  ; special 2 byte case

* Color
* 1248 124 8    1248 124 8  col    
* 0100 000 1    0000 000 1  82      
* 0010 000 1    0000 000 1  84     
* 0001 000 1    0000 000 1  88     
* 0000 100 1    0000 000 1  90     
* 0000 010 1    0000 000 1  a0     
* 0000 001 1    0000 000 1  c0     
* 0000 000 1    1000 000 1  80 81 


* New random number generator
* Seed with some initial value

* Initialize the random number generator
RandInit_lcl 
         lda $4e          ; seed the random number generator
         sta r1           ; static initializer. not ideal, but it works
         sta r3
         lda $4f
         sta r2
         sta r4
         ldx #$20         ; generate a few random numbers
:loop    jsr Rand_lcl     ; to kick things off
         dex
         bne :loop
         rts

r1       dfb 0
r2       dfb 0
r3       dfb 0
r4       dfb 0

* generate a random byte, return in A 
Rand_lcl   
         ror r4           ; bit 25 to carry
         lda r3           ; shift left 8 bits
         sta r4
         lda r2
         sta r3
         lda r1
         sta r2
         lda r4           ; get original bits 17-24
         ror              ; now bits 18-25 in acc
         rol r1           ; r1 holds bits 1-7
         eor r1           ; seven bits at once
         ror r4           ; shift right by one bit
         ror r3
         ror r2
         ror
         sta r1
         rts

* Read both joystick axes at the same time (and takes 
* a deterministic amount of time).  The effective range
* changes with 0=low, ~51=centered, ~114=high

JoyLowThresh = 25
JoyHighThresh = 90

* Read the joystick and update joy_x, joy_y with the values
* [0,1,2] for low,mid,high
JoyUpdate_lcl
        ldy #$00    ; initialize loop counter to 0 (y acts as the result here)
        sty joy_x   ; clear result storage for X
        sty joy_y   ; clear result storage for Y
        lda PTRIG   ; trigger the paddle timing cycle (starts the measurement)

:loop
        lda PADDL0  ; check the status of paddle 0
        bmi :set0   ; if high bit is set (cap discharged), branch to set value
        nop         ; (padding for consistent timing)
        bpl :nop0   ; branch always (takes consistent time)

:set0
        sty joy_x   ; store the current loop count as the paddle 0 value
:nop0
        ; (padding nops or other instructions to ensure equal cycle count between reads)
        lda PADDL1  ; check the status of paddle 1
        bmi :set1   ; if high bit set, branch to set value
        nop         ; (padding)
        bpl :nop1   ; branch always

:set1
        sty joy_y   ; store current loop count as the paddle 1 value
:nop1
        ; (padding)
        iny         ; increment loop counter
        cpy #$7f    ; check if the loop count has reached the threshold
        bne :loop   ; if not, continue polling
                          ; Map to 0,1,2 for X and Y
        lda joy_x
        cmp #JoyLowThresh
        bge :tryagain0
        lda #0
        jmp :ycheck
:tryagain0    
        cmp #JoyHighThresh
        bge :ishi0
        lda #1
        jmp :ycheck
:ishi0  lda #2
:ycheck sta joy_x
        lda joy_y
        cmp #JoyLowThresh
        bge :tryagain1
        lda #0
        jmp :done
:tryagain1    
        cmp #JoyHighThresh
        bge :ishi1
        lda #1
        jmp :done
:ishi1  lda #2
:done   sta joy_y
        rts   

* Play the sound [0,15] in X register
PlaySnd_lcl       
* Routine from Assembly Cookbook for the Apple II/IIe 
* (Don Lancaster)
* Chapter 4: Obnoxious Sounds
         php 
         pha 
         tya 
         pha 
         txa 
         cmp flngth4 
         bcc lok4 
         lda #$00 
lok4
         asl 
         tax 
         lda sefo,x 
         sta trpcnt4 
         inx 
         lda sefo,x 
         sta sweep4+1 
sweep4 
         ldy #$00 
nxtswp4 
         tya 
         tax 
nxtcyc4
         tya 
         jsr WAIT 
         bit SPKR 
         cpx #$80 
         beq exit4 
         dex 
         bne nxtcyc4 
         dey 
         bne nxtswp4 
         dec trpcnt4 
         bne sweep4
exit4 
         pla 
         tay 
         pla 
         plp 
         rts

trpcnt4  dfb $01
flngth4  dfb $10
         ; table for sounds that start at '5'
sefo     dfb $01,$08 ; tick
sef1     dfb $01,$18 ; whopidoop
sef2     dfb $ff,$01 ; pip
sef3     dfb $06,$10 ; phasor
sef4     dfb $01,$30 ; music scale (long)
sef5     dfb $20,$06 ; short beep
sef6     dfb $70,$06 ; medium beep
sef7     dfb $ff,$06 ; long beep
sef8     dfb $01,$a0 ; geiger (longish)
sef9     dfb $ff,$02 ; gleep (quick)
sef10    dfb $04,$1c ; glissade (woop,woop,woop,woop)
sefll    dfb $01,$10 ; qwip
sef12    dfb $30,$0b ; oboe (warble?  laser)
sef13    dfb $30,$07 ; french horn (fail buzzer?)
sef14    dfb $01,$15 ; pass beep
sef15    dfb $01,$64 ; time bomb

* ProDOS I/O routines
*
* Get the current prefix and set it, allowing file access
* relative to .SYSTEM file as simple filenames.
InitializeIO
         jsr    MLI
         dfb    MLI_GETPREFIX
         da     PrefixParams
         bcs    :error
         dfb    MLI_SETPREFIX
         da     PrefixParams
:error   rts

* Simple file I/O.
* Note: all I/O is page aligned and can only be complete pages
* carry set on error
* io_file_idx - the file index to read from (0=core)
* io_src_addr_hi - page offset into input file (seek)
* io_src_count_hi - number of pages to read (length)
* io_tgt_addr_hi - page number to store to (addr HI)
* TODO: allow more filenames and write routine
ReadFile_lcl
         lda    io_file_idx
         clc
         adc    #$41      ; Add to "A"
         sta    FileIdx
         jsr    MLI       ; open to read
         dfb    MLI_OPENFILE
         da     OpenParams
         bcs    :error
         lda    RefNum    ; use the file ref number for read and close
         sta    RefNumR
         sta    RefNumC
         sta    RefNumS
         lda    #0        ; all page aligned
         sta    SeekAddr+0
         sta    ReadAddr+0
         sta    ReadLen+0
         lda    io_src_addr_hi ; I/O page numbers/count
         sta    SeekAddr+1
         lda    io_src_count_hi
         sta    ReadLen+1
         lda    io_tgt_addr_hi
         sta    ReadAddr+1
         jsr    MLI       
         dfb    MLI_SETMARK
         da     SeekParams
         jsr    MLI       
         dfb    MLI_READFILE
         da     ReadParams
         jsr    MLI       ; close the file
         dfb    MLI_CLOSEFILE
         da     CloseParams
:error   rts

* Note: filename is SPACEPARA.{X} where {X} is A,B,C,... 
* gr_idx + 'A'
Filename dfb   11         ; length of filename
         asc   'SPACEPARA.A    '
FileIdx  =     Filename+11

PrefixParams
         dfb   1
         dw    PDOS_io_buffer

OpenParams
         dfb   3
         dw    Filename
         dw    PDOS_io_buffer
RefNum   dfb   0

ReadParams
         dfb   4
RefNumR  dfb   0
ReadAddr dw    $0000
ReadLen  dw    $0000
         dw    $0000

SeekParams
         dfb   2
RefNumS  dfb   0
         dfb   0          ; three byte addr limit to 64k
SeekAddr dw    $0000

CloseParams
         dfb   1
RefNumC  dfb   0
