         org   $4000
         
         dsk   ../bin/SPACEPARA#064000
         typ   $06

         put   COMMON.S

         jsr   Initialize
         lda   #0         ; black
         sta   gr_idx
         sta   gr_xpos    ; left side
         sta   gr_ypos    ; top
         lda   #40
         sta   gr_width   ; full width
         lda   #192
         sta   gr_height
         jsr   DrawRect
         lda   HIRES
         lda   TXTPAGE1
         lda   TXTCLR
         lda   MIXCLR
         jsr   DrawStatus
         jsr   DrawCopyVer
         ldx   #1         ; slow dither draw
         jsr   DrawTitle
         jsr   GetKey
         jsr   DrawFont      
         jmp   MONITOR

DrawFont lda   #0
         sta   c
         sta   gr_ypos
:line    lda   c
         sta   gr_idx
         and   #$0f
         sta   gr_xpos
         jsr   DrawChar
         inc   c
         lda   c
         pha
         and   #$f0
         lsr
         sta   gr_ypos
         pla
         cmp   #128
         bne   :line
         rts
c        dfb   0

GetKey   sta   KBDSTRB
:loop    lda   KBD
         bpl   :loop
         rts

DrawTitle
         lda   #10         ; 22col,122rows 
         sta   gr_xpos     ; gr_xpos should be even
         lda   #10
         sta   gr_ypos
         lda   #>TitleImage
         sta   gr_addr_hi
         lda   #<TitleImage
         sta   gr_addr_lo
         cpx   #1
         beq   :dither
         jsr   DrawBlock
         jmp   :copy
:dither  jsr   DrawDither
:copy    rts

DrawCopyVer
         lda   #6          ; (40-30)/2
         sta   gr_xpos
         lda   #152
         sta   gr_ypos
         lda   #>CopyRight
         sta   gr_addr_hi
         lda   #<CopyRight
         sta   gr_addr_lo
         jsr   DrawStr
         lda   #9          ; (40-22)/2
         sta   gr_xpos
         lda   #140
         sta   gr_ypos
         lda   #>Version
         sta   gr_addr_hi
         lda   #<Version
         sta   gr_addr_lo
         jsr   DrawStr
         rts

CopyRight
         asc   "Copyright "
         hex   13
         asc   " 2026 Randy Frank"
         hex   00

Version
         asc   "Space Paranoia ("
         put   VERSION.S
         asc   ")"
         hex   00         

TitleImage
         put   TITLE.S

DrawStatus
         lda   #0
         sta   gr_xpos
         lda   #184
         sta   gr_ypos
         lda   #>StatusText
         sta   gr_addr_hi
         lda   #<StatusText
         sta   gr_addr_lo
         jsr   DrawStr
         lda   #0
         sta   gr_xpos
         lda   #40
         sta   gr_width
         lda   #180
         sta   gr_ypos
         lda   #1
         sta   gr_height
         lda   #7
         sta   gr_idx
         jsr   DrawRect
         lda   #0
         sta   gr_xpos
         lda   #40
         sta   gr_width
         lda   #181
         sta   gr_ypos
         lda   #1
         sta   gr_height
         lda   #5
         sta   gr_idx
         jsr   DrawRect
         lda   #0
         sta   gr_xpos
         lda   #40
         sta   gr_width
         lda   #182
         sta   gr_ypos
         lda   #1
         sta   gr_height
         lda   #3
         sta   gr_idx
         jsr   DrawRect
         lda   #5
         sta   FuelTmp
         lda   #185
         sta   gr_ypos
:loopb   lda   #1
         sta   gr_idx
         lda   #113
         sta   gr_xpos
         lda   #27
         sta   gr_width
         jsr   DrawHLine
         lda   gr_ypos
         cmp   #185
         beq   :skip
         cmp   #189
         beq   :skip
         lda   #0
         sta   gr_idx
         lda   #114
         sta   gr_xpos
         lda   #25
         sta   gr_width
         jsr   DrawHLine
:skip    inc   gr_ypos
         dec   FuelTmp
         bne   :loopb
         jsr   DrawFuelUp
         rts

* 8 chars left: 56 pixels (28 on the 0-139 scale)
* 25 fuel steps + 1 start + 1 stop 27 "pixels"
* 113,139=white 114-138=colored 
* 184
* 185 ***********
* 186 * * * *   *
* 187 * * * *   *
* 188 * * * *   *
* 189 ***********
* 190
* 191
IncFuel  ldy   FuelLvl
         iny
         cpy   #24
         blt   :nocap
         ldy   #24
:nocap   sty   FuelLvl
         jmp   DrawFuelUp

DecFuel  ldy   FuelLvl
         dey
         cpy   #$ff
         bne   :nocap
         ldy   #0
:nocap   sty   FuelLvl
         jmp   DrawFuelDown

DrawFuelUp
         lda   #2
         sta   gr_idx
         lda   #186
         sta   gr_ypos
         lda   #3
         sta   FuelTmp
:loop    lda   #114
         sta   gr_xpos
         lda   FuelLvl
         sta   gr_width
         jsr   DrawHLine
         inc   gr_ypos
         dec   FuelTmp
         bne   :loop
         rts

DrawFuelDown
         lda   #0
         sta   gr_idx
         lda   #186
         sta   gr_ypos
         lda   #3
         sta   FuelTmp
:loop    ldy   FuelLvl
         iny
         sty   gr_xpos
         lda   #138
         sec   
         sbc   FuelLvl   
         sta   gr_width
         jsr   DrawHLine
         inc   gr_ypos
         dec   FuelTmp
         bne   :loop
         rts

FuelTmp  dfb   0
FuelLvl  dfb  12          ; 0-25

StatusText
         asc   "Score:"
ScoreHI  asc   "0"         
         asc   "0"         
         asc   "0"         
         asc   "0"         
         asc   "0"         
ScoreLO  asc   "0"         
         asc   " Lvl:"
LevelHI  asc   "0"
LevelLO  asc   "0"
         asc   " "
         dfb   12
ShieldHI asc   "0"         
ShieldLo asc   "0"         
         asc   " "
Ship0    dfb   11
Ship1    dfb   11       
Ship2    dfb   11        
         asc   " Fuel"
         hex   00         

         