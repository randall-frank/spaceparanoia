
Initialize  = $800
JoyUpdate   = $803
Random      = $806
DrawChar    = $809
DrawStr     = $80c
DrawSprite  = $80f
DrawPoint   = $812
DrawRect    = $815
DrawBlock   = $818
DrawDither  = $81b
DrawHLine   = $81e
PlaySnd     = $821

LO          = $26
HI          = $27

* SCANLINE_TBL.S

* ScanlineTblHI = ~$800
* ScanlineTblLO = $900

* XPOS_TABLES.S

* XPosByte    = $a00
* XPosShift   = $b00

* FontBase    = $c00

gr_idx      = $f9
gr_xpos     = $fa
gr_ypos     = $fb
gr_addr_lo  = $fc
gr_addr_hi  = $fd
gr_width    = $fe
gr_height   = $ff

* I/O reuses the gr_ interface
io_src_addr_hi = $f9
io_src_count_hi = $fa
io_tgt_addr_hi = $fb

* Joystick state (0,1,2) "low","center","high"
* call JoyUpdate to update the values
joy_x       = $06
joy_y       = $07

tmp0        = $08
tmp1        = $09

* ProDOS entry point
MLI           equ $bf00

* MLI functions
MLI_GETPREFIX equ $2b
MLI_SETPREFIX equ $2c
MLI_OPENFILE  equ $c8
MLI_READFILE  equ $ca
MLI_SETMARK   equ $ce
MLI_CLOSEFILE equ $cc

* Soft switches
KBD         equ   $c000      ;R last key pressed + 128
KBDSTRB     equ   $c010      ;RW keyboard strobe
SPKR        equ   $c030      ;RW toggle speaker
TXTCLR      equ   $c050      ;RW display graphics
MIXCLR      equ   $c052      ;RW display full screen
TXTPAGE1    equ   $c054      ;RW display page 1
HIRES       equ   $c057      ;RW display hi-res graphics
BUTN0       equ   $c061      ;R switch input 0 / open-apple
BUTN1       equ   $c062      ;R switch input 1 / closed-apple
PADDL0      equ   $C064      ; Read paddle 0 soft switch
PADDL1      equ   $C065      ; Read paddle 1 soft switch
PTRIG       equ   $C070      ; Trigger (start) paddle measurement

* monitor entry points
WAIT        equ   $FCA8
MONITOR     equ   $FF69
