import os
from datetime import datetime

# This script generates the XPOS_TABLE.S file
# It converts an x position [0-255] (Note only [0,139] are valid)
# into a screen byte offset and a pre-shifted shape number [0-6]

xshift = []
xbyte = []
# this is a two pixel table.  0=first pixel on screen 1=3rd pixel on screen
# matches the Apple II "color" scheme where every 2 pixels pick a color
# thus, we multiply the xpos by 2 and then compute the byte/shift
for i in range(256):
    xshift.append((i*2)%7)
    xbyte.append((i*2)//7)
    
s = "* X Pos conversion to byte,shift tables\n"
s += f"* Date: {datetime.now().isoformat()}\n"
s += "\n"
lead = "         hex   "
s += "XPosByte\n"
for i in range(0,256,8):
    s += lead
    for j in range(i,i+8):
        s += f'{xbyte[j]:02x}'
    s += f"   ; {i}\n"

s += "XPosShift\n"
for i in range(0,256,8):
    s += lead
    for j in range(i,i+8):
        s += f'{xshift[j]:02x}'
    s += f"   ; {i}\n"

with open(os.path.join("src", "XPOS_TABLE.S"), "w") as fp:
    fp.write(s)
