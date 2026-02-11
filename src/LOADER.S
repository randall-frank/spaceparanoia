        org    $2000
        dsk    ../bin/LOADER#062000
        typ    $06

ProgStart =    $4000

* Loader starts at $2000
* relocates some pages to $800
* jumps to $4000 to start the app

        lda    #$28       ; $2800-$3fff
        ldy    #$08       ; $0800-$1fff -> DRAWING.S
        ldx    #$18       ; $1800 bytes
        jsr    MemMove
        jmp    ProgStart

* A=src MSB, Y=dst MSB, X=# pages
MemMove sta    Fetch+2
        sty    Store+2
]page   ldy    #$00
Fetch   lda    $ff00,Y
Store   sta    $ff00,Y
        dey
        bne    Fetch
        inc    Fetch+2
        inc    Store+2
        dex
        bne    ]page
        rts
