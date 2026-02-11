         org   $4000
         
         dsk   ../bin/SPACEPARA#064000
         typ   $06

         put   COMMON.S

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
         jsr   RandomInit
         ldx   #1         ; slow dither draw
         jsr   DrawTitle
         jsr   GetKey
         jsr   DrawFont      
         jmp   MONITOR

DrawFont
         lda   #0
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
         lda   #35
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
:copy    jsr   DrawCopyVer
         rts

DrawCopyVer
         lda   #6          ; (40-30)/2
         sta   gr_xpos
         lda   #168
         sta   gr_ypos
         lda   #>CopyRight
         sta   gr_addr_hi
         lda   #<CopyRight
         sta   gr_addr_lo
         jsr   DrawStr
         lda   #9          ; (40-22)/2
         sta   gr_xpos
         lda   #160
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

         ds    \
SpriteBase
         put   SPRITES.S