from datetime import datetime

def generate_hgr_offsets(base_addr=0x2000):
    offsets = []
    for y in range(192):
        addr = (y % 8)*1024
        addr += ((y // 8) % 8) * 128
        addr += ((y//64)*40)
        addr += (y % 8)//8
        offsets.append(addr+base_addr)
    return offsets
        

offsets = generate_hgr_offsets(base_addr=0)

with open("bin/TITLE.PIC", "rb") as f:
    img = f.read()
    
# 22 bytes wide, 122 tall
out = bytearray([22, 122])
for y in range(122):
    for x in range(22):
        addr = offsets[y] + x
        out.append(img[addr])

s = "* Imported from TITLE.PIC binary file\n"
s += f"* Date: {datetime.now().isoformat()}\n"
s += f"* MASSDRAW format image: {out[0]} cols {out[1]} rows, {len(out)} bytes\n\n"    
for i in range(0,len(out),16):
    s += "        hex   "
    for b in out[i:i+16]:
        s += f"{b:02X}"
    s += "\n"

with open("src/TITLE.S", "w") as f:
    f.write(s)

with open("bin/TITLE.MAS#064000", "wb") as f:
    f.write(out)
