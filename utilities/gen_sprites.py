import os
from datetime import datetime


def gen_byte(s, hb):
    d = hb
    b = 1
    for c in s:
        if c == "@":
            d |= b
        b *= 2
    return f"{d:02X}"


def gen_hex(shift, line):
    highbit = 0x00
    if line[-1:] == "1":
        highbit = 0x80
    scan = "."*shift + line[:-1] + "."*(7-shift)
    s = "hex   "
    s += gen_byte(scan[0:7], highbit)
    s += gen_byte(scan[7:14], highbit)
    s += gen_byte(scan[14:21], highbit)
    s += "    ; " + scan
    return s


sprites = {}

pad = "         "
s = "* Sprite conversion to hex tables\n"
s += f"* Date: {datetime.now().isoformat()}\n\n"

sprite_num = 0
sprite_shift = 0
image = []
in_image = False
name = os.path.join("utilities", "sprites.txt")
with open(name,"r") as fp:
    for line in fp:
        line = line.replace("\n", "")
        if len(line) < 3:
            continue
        if line.startswith("#"):
            continue
        elif line.startswith("sprite:"):
            sprite_num = int(line[7:])
            continue
        elif line.startswith("shift:"):
            sprite_shift = int(line[6:])
            continue
        elif line.startswith("12481241248124"):
            in_image = not in_image
            if in_image:
                # if starting an image, add an empty scanline
                image.append("..............0")
            else:
                # if image is done, add an empty scanline and save it
                image.append("..............0")
                if sprite_num not in sprites:
                    sprites[sprite_num] = {}
                sprites[sprite_num][sprite_shift] = image
                image=[]
        elif in_image:
            image.append(line)

for sprite_num in range(len(sprites)):
    s += f"{pad}ds   \\\n"
    s += f"* Sprite# {sprite_num}\n"
    for sprite_shift in range(len(sprites[sprite_num])):
        s += f"* Shift# {sprite_shift}\n"
        for line in sprites[sprite_num][sprite_shift]:
            s += f"{pad}{gen_hex(sprite_shift,line)}\n"

# TODO: generate mask image

with open(os.path.join("src", "SPRITES.S"), "w") as fp:
    fp.write(s)
