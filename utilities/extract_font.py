import os
from datetime import datetime

with open("bin/BIGFONT#060C00", "rb") as fp:
    data = fp.read()

cnt = 0
s = "* Imported from BIGFONT binary file\n"
s += f"* Date: {datetime.now().isoformat()}\n"
s += "* Images for 128 characters\n\n"    
for i in range(0,len(data),8):
    if cnt//8 % 32 == 0:
        s += f"* Char block start: {cnt//8:02X}\n"
    s += "        hex   "
    for b in data[i:i+8]:
        s += f"{b:02X}"
    s += f"   ; {cnt//8:02X}\n"
    cnt += 8


with open(os.path.join("src", "FONTSRC.S"), "w") as fp:
    fp.write(s)
